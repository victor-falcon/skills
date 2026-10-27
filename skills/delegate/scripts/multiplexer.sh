# Multiplexer abstraction for shell snippets and agent skills: herdr if present,
# else rex, else muxy, else zellij (legacy). POSIX sh, so it also runs under
# `sh -c`. Source once at the top of a snippet:
#   . /path/to/skills/delegate/scripts/multiplexer.sh
# Then drive the current pane / new tabs without caring which backend is live:
#   mux_rename "Backend"                  rename the current (self) pane
#   mux_send   "cd '$repo' && bin/rails s" type a command into self + Enter
#   mux_open_tab "Frontend" "cd … && …"    open a new tab running a command
#   mux_open_pane "Frontend" "cd … && …"   split a pane (default: self) + run it
#   mux_rename_tab "server"               rename the current tab
#   mux_focus  "Backend"                  refocus the self pane's tab
#
# Worktree agents (herdr and rex only; mux_backend tells which one is live):
#   mux_worktree_create <cwd> <branch> <base> <label> [group]   new branch off <base>
#   mux_worktree_open   <cwd> <branch> <label> [group]          existing local branch
#       both print "<checkout path><TAB><handle>"; the handle is what
#       mux_agent_launch and mux_worktree_remove take. herdr: the root pane of
#       a workspace named <label>. rex: the session the agents go in, named
#       "<current session> / <group>" (group defaults to label), so worktrees
#       sharing a group share a session, one tab per agent.
#   mux_agent_launch <name> <handle> <cwd> <brief-file> [claude args...]
#       start Claude Code in the worktree and submit the brief as its prompt
#   mux_agent_status <name>               idle | working | done | blocked | error | unknown
#   mux_agent_wait   <name> [seconds]     block until idle/done/blocked/error (default 600)
#   mux_agent_prompt <name> <text>        submit a follow-up prompt
#   mux_agent_read   <name> [lines]       print recent output (rex: visible screen only)
#   mux_agent_keys   <name> <key>...      press keys, e.g. ctrl+c
#   mux_worktree_remove <handle> <path> [--force]   drop the worktree and close its workspace
#   mux_worktree_gc                       clean up every worktree whose PR is merged or closed

mux_backend() {
  if [ -n "$HERDR_PANE_ID" ]; then echo herdr
  elif [ -n "$REX_BLOCK" ]; then echo rex
  elif [ -n "$MUXY_PANE_ID" ]; then echo muxy
  elif [ -n "$ZELLIJ" ]; then echo zellij
  else echo none
  fi
}

# Pull every "<key>": value out of herdr's JSON wherever it nests.
_mux_jq_first() { jq -r --arg k "$1" '[.. | objects | .[$k]? // empty] | first // empty'; }

if [ -n "$HERDR_PANE_ID" ]; then
  _MUX_SELF="$HERDR_PANE_ID"
  _MUX_TAB="$HERDR_TAB_ID"

  mux_rename() { herdr pane rename "$_MUX_SELF" "$1"; }
  mux_send() { herdr pane send-text "$_MUX_SELF" "$1"; herdr pane send-keys "$_MUX_SELF" Enter; }
  # herdr: label the tab at creation and read back its root pane id to drive it.
  mux_open_tab() {  # $1=title  $2=command
    _p=$(herdr tab create --label "$1" --no-focus | jq -r '.result.root_pane.pane_id')
    herdr pane send-text "$_p" "$2"
    herdr pane send-keys "$_p" Enter
  }
  mux_focus() { herdr tab focus "$_MUX_TAB"; }  # arg ignored; back to self's tab
  mux_rename_tab() { herdr tab rename "$_MUX_TAB" "$1"; }
  # Split a pane and run a command in the new one; echo its id so callers can
  # chain further splits (e.g. build a 2x2 grid).
  mux_open_pane() {  # $1=title $2=command [$3=source pane, default self] [$4=direction, default down]
    # Silence the driving calls' JSON so only the new pane id reaches stdout.
    _np=$(herdr pane split "${3:-$_MUX_SELF}" --direction "${4:-down}" --no-focus | jq -r '.result.pane.pane_id')
    herdr pane rename "$_np" "$1" >/dev/null
    herdr pane send-text "$_np" "$2" >/dev/null
    herdr pane send-keys "$_np" Enter >/dev/null
    printf '%s\n' "$_np"
  }

  _mux_herdr_worktree() {  # stdin: herdr worktree JSON
    _j=$(cat)
    _path=$(printf '%s' "$_j" | _mux_jq_first checkout_path)
    _pane=$(printf '%s' "$_j" | jq -r '[.. | objects | .root_pane? // empty | .pane_id] | first // empty')
    [ -n "$_path" ] && [ -n "$_pane" ] || { printf '%s\n' "$_j" >&2; return 1; }
    printf '%s\t%s\n' "$_path" "$_pane"
  }
  _mux_be_worktree_create() {  # $1=cwd $2=branch $3=base $4=label
    herdr worktree create --cwd "$1" --branch "$2" --base "$3" --label "$4" --no-focus | _mux_herdr_worktree
  }
  _mux_be_worktree_open() {  # $1=cwd $2=branch $3=label
    herdr worktree open --cwd "$1" --branch "$2" --label "$3" --no-focus | _mux_herdr_worktree
  }
  mux_agent_launch() {  # $1=name $2=root pane $3=cwd (unused) $4=brief file, rest = claude args
    _n="$1" _pane="$2" _brief="$4"; shift 4
    # Big repos keep Claude from looking ready within herdr's default 30s.
    herdr agent start "$_n" --kind claude --pane "$_pane" --timeout 90000 -- "$@" >/dev/null || return
    herdr agent prompt "$_n" "$(cat "$_brief")" >/dev/null
  }
  mux_agent_status() { herdr agent get "$1" | _mux_jq_first agent_status; }
  mux_agent_wait() {
    herdr agent wait "$1" --timeout "$(( ${2:-600} * 1000 ))" >/dev/null
    _rc=$?
    mux_agent_status "$1"
    return $_rc
  }
  mux_agent_prompt() { herdr agent prompt "$1" "$2" >/dev/null; }
  mux_agent_read() { herdr agent read "$1" --source recent-unwrapped --lines "${2:-200}"; }
  mux_agent_keys() { _n="$1"; shift; herdr agent send-keys "$_n" "$@" >/dev/null; }
  _mux_be_worktree_remove() {  # $1=root pane $2=path [$3=--force]
    # The handle is the root pane (w9J:p1); its workspace is the part before ':'.
    _ws="${1%%:*}"
    if [ -d "$2" ]; then
      herdr worktree remove --workspace "$_ws" ${3:+"$3"} >/dev/null || return
    fi
    # Removing the worktree leaves its workspace open, so close it ourselves.
    herdr workspace close "$_ws" >/dev/null 2>&1 || :
  }
  # Workspaces left open on a worktree that's already gone, e.g. from before
  # this lib closed them.
  _mux_be_orphans() {
    herdr workspace list 2>/dev/null \
      | jq -r '.. | objects | select(.workspace_id? and .worktree.is_linked_worktree? == true) | "\(.workspace_id)\t\(.worktree.checkout_path)"' \
      | while IFS="$(printf '\t')" read -r _ws _p; do
          [ -d "$_p" ] && continue
          herdr workspace close "$_ws" >/dev/null 2>&1 && echo "mux: closed orphan workspace $_ws ($_p)"
        done
  }
elif [ -n "$REX_BLOCK" ]; then
  _MUX_SELF="$REX_BLOCK"
  _MUX_SESSION="$REX_SESSION"

  # Shells that predate the PATH fix in .zshrc (and agents spawned from them)
  # don't have rex on PATH, but they all inherit REX_BIN_DIR.
  _mux_rex() { "${REX_BIN_DIR:+$REX_BIN_DIR/}rex" "$@"; }
  _mux_self_window() { _mux_rex block inspect -s "$_MUX_SESSION" "$_MUX_SELF" --json | jq -r '.block.window_id'; }
  # Typing into a just-created shell races its startup and the text gets lost,
  # so rex runs the command at creation and drops into a shell afterwards.
  _mux_shell_cmd() { printf '%s; exec %s' "$1" "${SHELL:-zsh}"; }

  mux_rename() { _mux_rex block rename -s "$_MUX_SESSION" "$_MUX_SELF" "$1"; }
  mux_send() { _mux_rex send -s "$_MUX_SESSION" -b "$_MUX_SELF" "$1"; _mux_rex send-key -s "$_MUX_SESSION" -b "$_MUX_SELF" enter; }
  mux_open_tab() {  # $1=title  $2=command
    _mux_rex window new -s "$_MUX_SESSION" "$1" --focus=false --json --shell=none \
      -- "${SHELL:-zsh}" -ic "$(_mux_shell_cmd "$2")" >/dev/null
  }
  mux_focus() { _mux_rex focus -s "$_MUX_SESSION" "$(_mux_self_window)"; }  # arg ignored; back to self's tab
  mux_rename_tab() { _mux_rex window rename -s "$_MUX_SESSION" "$(_mux_self_window)" "$1"; }
  mux_open_pane() {  # $1=title $2=command [$3=source block, default self] [$4=direction, default down]
    case "${4:-down}" in down) _d=below ;; up) _d=above ;; *) _d="$4" ;; esac
    _mux_rex split -s "$_MUX_SESSION" -b "${3:-$_MUX_SELF}" --split="$_d" --label "$1" --focus=false --json --shell=none \
      -- "${SHELL:-zsh}" -ic "$(_mux_shell_cmd "$2")" | jq -r '.block_ids[0]'
  }

  # rex has no worktrees or named agents: git makes the worktree, a rex session
  # stands in for herdr's workspace, and a state file maps agent names to their
  # session, block and worktree.
  _MUX_AGENTS="${XDG_STATE_HOME:-$HOME/.local/state}/mux/rex-agents"
  _mux_agent() {  # $1=name -> sets _s (session), _b (block) and _ap (worktree)
    read -r _s _b _ap < "$_MUX_AGENTS/$1" 2>/dev/null || { echo "mux: unknown agent '$1'" >&2; return 1; }
  }
  # "myapp / dark mode": the session we're in plus the group, so
  # the agents' session sorts next to the one that spawned it. Strip our own
  # suffix so an agent delegating from an agent session doesn't nest names.
  _mux_group() {  # $1=group
    _base=$(_mux_rex session inspect "$_MUX_SESSION" --json 2>/dev/null | jq -r '.label // empty')
    printf '%s / %s\n' "${_base%% / *}" "$1"
  }
  _mux_session_id() {  # $1=label -> id of the live session with that label
    _mux_rex ls --json | jq -r --arg l "$1" '[.sessions[] | select(.label == $l) | .session_id][0] // empty'
  }
  _mux_wt_path() {  # $1=cwd $2=branch -> ~/.worktrees/<repo>/<branch>
    _gd=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir) || return
    printf '%s/.worktrees/%s/%s\n' "$HOME" "$(basename "$(dirname "$_gd")")" "$(printf '%s' "$2" | tr / -)"
  }
  # The session isn't opened here: an empty one would start with a bare shell
  # tab nobody uses. The first agent opens it with its own tab instead.
  _mux_be_worktree_create() {  # $1=cwd $2=branch $3=base $4=label [$5=group]
    _wt=$(_mux_wt_path "$1" "$2") || return
    git -C "$1" worktree add -q -b "$2" "$_wt" "$3" >&2 || return
    printf '%s\t%s\n' "$_wt" "$(_mux_group "${5:-$4}")"
  }
  _mux_be_worktree_open() {  # $1=cwd $2=branch $3=label [$4=group]
    _wt=$(_mux_wt_path "$1" "$2") || return
    git -C "$1" worktree add -q "$_wt" "$2" >&2 || return
    printf '%s\t%s\n' "$_wt" "$(_mux_group "${4:-$3}")"
  }
  mux_agent_launch() {  # $1=name $2=session label $3=cwd $4=brief file, rest = claude args
    _n="$1" _grp="$2" _cwd="$3" _brief="$4"; shift 4
    # The brief rides in as claude's initial prompt: nothing to type, no race.
    _s=$(_mux_session_id "$_grp")
    if [ -n "$_s" ]; then
      _b=$(_mux_rex window new -s "$_s" "$_n" -c "$_cwd" --focus=false --json -- claude "$@" "$(cat "$_brief")" \
        | jq -r '.block_ids[0]') || return
    else
      _out=$(_mux_rex new "$_grp" -c "$_cwd" --window "$_n" --json -- claude "$@" "$(cat "$_brief")") || return
      _s=$(printf '%s' "$_out" | jq -r '.session_id')
      _b=$(printf '%s' "$_out" | jq -r '.initial_windows[0].block_ids[0]')
    fi
    mkdir -p "$_MUX_AGENTS" && printf '%s %s %s\n' "$_s" "$_b" "$_cwd" > "$_MUX_AGENTS/$_n"
    # Claude reports idle at its first prompt before it picks up the brief, so
    # only return once it's busy. Still unknown means it's stuck on a dialog it
    # can't report (folder trust): that's the user's call, so surface it.
    _mux_until_busy "$_n" 30 && return
    mux_agent_read "$_n" | grep -qi 'trust this folder' && echo "mux: $_n is waiting on the folder-trust dialog" >&2
    return 3
  }
  _mux_stamp() {  # $1=name -> "<state> <updated_at>"
    _mux_agent "$1" || return
    _mux_rex block call -s "$_s" -b "$_b" program_status 2>/dev/null | jq -r '.records[0] | "\(.state) \(.updated_at)"'
  }
  _mux_until_busy() {  # $1=name $2=seconds [$3=stamp before]; succeed once it left idle
    _i=0
    while [ "$_i" -lt "$2" ]; do
      _now=$(_mux_stamp "$1")
      # A fresh stamp past idle means it took a turn, even one already done.
      [ "$_now" != "${3:-}" ] && case "$_now" in working*|done*|blocked*|error*) return 0 ;; esac
      _i=$((_i + 1))
      sleep 1
    done
    return 1
  }
  mux_agent_status() {
    _mux_agent "$1" || return
    _st=$(_mux_rex block call -s "$_s" -b "$_b" program_status 2>/dev/null | jq -r '.records[0].state // empty')
    echo "${_st:-unknown}"
  }
  mux_agent_wait() {  # $1=name [$2=seconds, default 600]
    _end=$(( $(date +%s) + ${2:-600} ))
    while :; do
      _st=$(mux_agent_status "$1") || return
      case "$_st" in idle|done|blocked|error) echo "$_st"; return 0 ;; esac
      [ "$(date +%s)" -ge "$_end" ] && { echo "$_st"; return 1; }
      sleep 3
    done
  }
  mux_agent_prompt() {
    # _mux_stamp runs in a subshell, so resolve _s/_b here or the send hits our own block.
    _mux_agent "$1" || return
    _before=$(_mux_stamp "$1") || return
    _mux_rex send -s "$_s" -b "$_b" "$2" && sleep 0.3 && _mux_rex send-key -s "$_s" -b "$_b" enter || return
    # Like herdr's prompt gate: a prompt that never makes it busy didn't land.
    _mux_until_busy "$1" 10 "$_before"
  }
  # ponytail: rex capture only sees the screen, not scrollback; $2 just trims.
  mux_agent_read() { _mux_agent "$1" || return; _mux_rex capture -s "$_s" -b "$_b" --trim --unwrap | tail -n "${2:-200}"; }
  mux_agent_keys() { _n="$1"; shift; _mux_agent "$_n" || return; _mux_rex send-key -s "$_s" -b "$_b" "$@"; }
  _mux_be_worktree_remove() {  # $1=session label $2=path [$3=--force]
    [ -n "${ZSH_VERSION:-}" ] && setopt local_options null_glob  # zsh: an empty dir must not abort the loop
    if [ -d "$2" ]; then
      git -C "$2" worktree remove ${3:+"$3"} "$2" || return
    fi
    # Close the tabs of this worktree's agents, then the session once nothing
    # else lives in it: rex keeps a session around after its last tab closes.
    for _f in "$_MUX_AGENTS"/*; do
      [ -f "$_f" ] || continue
      read -r _s _b _ap < "$_f"
      [ "$_ap" = "$2" ] || continue
      _w=$(_mux_rex block inspect -s "$_s" "$_b" --json 2>/dev/null | jq -r '.block.window_id // empty')
      [ -n "$_w" ] && _mux_rex window close -s "$_s" "$_w" >/dev/null 2>&1
      rm -f "$_f"
    done
    case "$1" in session:*) _s="$1" ;; *) _s=$(_mux_session_id "$1") ;; esac  # ponytail: session:* = handles from before groups
    [ -n "$_s" ] || return 0
    # Only kill a session we have positively counted as empty: a failed or
    # garbled `window ls` must keep it, or other agents' tabs go with it.
    _wls=$(_mux_rex window ls -s "$_s" --json 2>/dev/null) || return 0
    _left=$(printf '%s' "$_wls" | jq '[.. | objects | select(.window_id?)] | length' 2>/dev/null)
    case "$_left" in ''|*[!0-9]*) return 0 ;; esac
    [ "$_left" -eq 0 ] || return 0
    _mux_rex kill "$_s" >/dev/null 2>&1
    # A loop, not `grep -l … | xargs rm`: with no files left, grep would read stdin.
    for _f in "$_MUX_AGENTS"/*; do
      [ -f "$_f" ] && grep -q "^$_s " "$_f" && rm -f "$_f"
    done
    return 0
  }
  _mux_be_orphans() { :; }  # ponytail: every rex workspace came from the registry
elif [ -n "$MUXY_PANE_ID" ]; then
  _MUX_SELF="$MUXY_PANE_ID"

  mux_rename() { muxy rename-pane --pane "$_MUX_SELF" "$1"; }
  mux_send() { muxy send --pane "$_MUX_SELF" "$1"; muxy send-keys --pane "$_MUX_SELF" Enter; }
  # muxy new-tab takes no cmd/cwd and returns a tab id, not a pane id, so open a
  # tab then diff list-panes to find its pane. cd lives inside the command.
  mux_open_tab() {  # $1=title  $2=command
    _tmp=$(mktemp)
    muxy list-panes | cut -f1 > "$_tmp"
    muxy new-tab >/dev/null
    _p=$(muxy list-panes | cut -f1 | grep -vxF -f "$_tmp" | head -1)
    rm -f "$_tmp"
    muxy rename-pane --pane "$_p" "$1"
    muxy send --pane "$_p" "$2"
    muxy send-keys --pane "$_p" Enter
  }
  mux_focus() { muxy switch-tab "$1"; }  # $1=tab name
  mux_rename_tab() { :; }  # ponytail: muxy has no tab-rename; skip
  mux_open_pane() { mux_open_tab "$1" "$2"; }  # ponytail: muxy pane ids untrackable -> tab
elif [ -n "$ZELLIJ" ]; then
  # zellij acts on the focused pane/tab, so there is no self id to capture.
  mux_rename() { zellij action rename-pane "$1"; }
  mux_send() { zellij action write-chars "$1"; zellij action write 10; }  # 10 = Enter
  mux_open_tab() {  # $1=title  $2=command
    zellij action new-tab --name "$1"
    sleep 0.3
    zellij action write-chars "$2"
    zellij action write 10
  }
  mux_focus() { zellij action go-to-tab-name "$1"; }
  mux_rename_tab() { zellij action rename-tab "$1"; }
  mux_open_pane() { mux_open_tab "$1" "$2"; }  # ponytail: zellij pane ids untrackable -> tab
else
  # ponytail: no multiplexer -> no-op so snippets still run their real work.
  mux_rename() { :; }
  mux_send() { :; }
  mux_open_tab() { :; }
  mux_focus() { :; }
  mux_rename_tab() { :; }
  mux_open_pane() { :; }
fi

# Worktree bookkeeping shared by herdr and rex: every worktree we create is
# recorded, so the ones whose PR is done can be cleaned up later, even by a
# different session than the one that delegated them.
if [ -n "$HERDR_PANE_ID" ] || [ -n "$REX_BLOCK" ]; then
  _MUX_WORKTREES="${XDG_STATE_HOME:-$HOME/.local/state}/mux/worktrees"
  _mux_wt_record() { printf '%s' "$1" | shasum | cut -c1-12; }  # $1=path -> registry file name

  _mux_wt_register() {  # $1=cwd $2=branch; stdin/stdout: "<path><TAB><handle>"
    IFS="$(printf '\t')" read -r _p _h || return
    _root=$(dirname "$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)")
    mkdir -p "$_MUX_WORKTREES"
    printf '%s\t%s\t%s\t%s\n' "$_p" "$_h" "$2" "$_root" > "$_MUX_WORKTREES/$(_mux_wt_record "$_p")"
    printf '%s\t%s\n' "$_p" "$_h"
  }
  mux_worktree_create() { _out=$(_mux_be_worktree_create "$@") || return; printf '%s\n' "$_out" | _mux_wt_register "$1" "$2"; }
  mux_worktree_open() { _out=$(_mux_be_worktree_open "$@") || return; printf '%s\n' "$_out" | _mux_wt_register "$1" "$2"; }
  mux_worktree_remove() {  # $1=handle $2=path [$3=--force]
    _mux_be_worktree_remove "$@" || return
    rm -f "$_MUX_WORKTREES/$(_mux_wt_record "$2")"
  }

  mux_worktree_gc() {
    [ -n "${ZSH_VERSION:-}" ] && setopt local_options null_glob  # zsh: an empty dir must not abort the loop
    for _f in "$_MUX_WORKTREES"/*; do
      [ -f "$_f" ] || continue
      IFS="$(printf '\t')" read -r _p _h _br _root < "$_f"
      _state=$(cd "$_root" 2>/dev/null && gh pr view "$_br" --json state -q .state 2>/dev/null)
      if [ -d "$_p" ]; then
        case "$_state" in MERGED|CLOSED) ;; *) continue ;; esac
        # After a merge, untracked leftovers are QA and build output; edits to
        # tracked files are work nobody shipped, so keep those for a human.
        if [ -n "$(git -C "$_p" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
          echo "mux: kept $_p ($_br is $_state but has uncommitted changes)" >&2
          continue
        fi
        mux_worktree_remove "$_h" "$_p" --force || continue
      else
        # Someone already dropped the worktree; its workspace is all that's left.
        mux_worktree_remove "$_h" "$_p" || continue
      fi
      case "$_state" in MERGED|CLOSED) git -C "$_root" branch -D "$_br" >/dev/null 2>&1 ;; esac
      echo "mux: cleaned up $_br ($_p)"
    done
    _mux_be_orphans
  }
fi
