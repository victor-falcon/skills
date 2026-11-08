# Multiplexer abstraction for shell snippets and agent skills: herdr (the Herdr
# app on herdr-core, driven with `hc` and `herdr-app`) if present, else rex,
# else muxy, else zellij (legacy). POSIX sh, so it also runs under
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
#       mux_agent_launch and mux_worktree_remove take. Worktrees go in
#       ~/.worktrees/<repo>/<branch>, and worktrees sharing a group (default:
#       the label) share a space/session, one tab per agent. herdr: the id of
#       that space (sp…), named <group>. rex: "<current session> / <group>",
#       plain ASCII so an agent can copy it; the session is labelled from it
#       with a Nerd Font icon.
#   mux_agent_launch <name> <handle> <cwd> <brief-file> [claude args...]
#       start Claude Code in the worktree and submit the brief as its prompt
#   mux_agent_status <name>               idle | working | done | blocked | error | unknown
#                                         (herdr also: exited)
#   mux_agent_wait   <name> [seconds]     block until idle/done/blocked/error (default 600)
#   mux_agent_prompt <name> <text>        submit a follow-up prompt
#   mux_agent_read   <name> [lines]       print recent output (rex: visible screen only;
#                                         herdr: screen only while working or blocked)
#   mux_agent_keys   <name> <key>...      press keys, e.g. ctrl+c
#   mux_worktree_remove <handle> <path> [--force]   drop the worktree, end its agents, close their space/session once empty
#   mux_worktree_gc                       clean up every worktree whose PR is merged or closed
#
# One-off agent tab (herdr and rex only), no worktree:
#   mux_agent_tab <title> <cwd> < prompt  new tab in this space/session that
#       starts Claude Code in <cwd> with the prompt read from stdin. The command
#       is typed into an interactive shell, so aliases and shell functions
#       resolve: MUX_CLAUDE picks it (default claude, e.g. MUX_CLAUDE=clc).

# Herdr: a terminal run by herdr-core (hc) that the Herdr app shows. The app
# shows a terminal in a space and tab when it carries their ids as labels, so
# read ours once; a plain hc terminal outside the app has none.
_MUX_HC_SPACE= _MUX_HC_TAB=
if [ -n "$HC_TERMINAL_ID" ] && command -v hc >/dev/null 2>&1; then
  _mux_l=$(hc get "$HC_TERMINAL_ID" --json 2>/dev/null | jq -r '.labels // {} | "\(.["herdr.space"] // "")\t\(.["herdr.tab"] // "")"' 2>/dev/null)
  _MUX_HC_SPACE="${_mux_l%%	*}" _MUX_HC_TAB="${_mux_l#*	}"
fi

mux_backend() {
  if [ -n "$_MUX_HC_SPACE" ]; then echo herdr
  elif [ -n "$REX_BLOCK" ]; then echo rex
  elif [ -n "$MUXY_PANE_ID" ]; then echo muxy
  elif [ -n "$ZELLIJ" ]; then echo zellij
  else echo none
  fi
}

# Worktrees go in ~/.worktrees/<repo>/<branch> under both herdr and rex.
_mux_wt_path() {  # $1=cwd $2=branch
  _gd=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir) || return
  printf '%s/.worktrees/%s/%s\n' "$HOME" "$(basename "$(dirname "$_gd")")" "$(printf '%s' "$2" | tr / -)"
}

if [ -n "$_MUX_HC_SPACE" ]; then
  # hc runs the terminals, herdr-app arranges the window. A terminal started
  # with `hc run --label herdr.space=<id> --label herdr.tab=<id>` shows up in
  # that space and tab; an id the app doesn't know yet becomes a new one, and
  # the space closes by itself once its last terminal ends.
  #
  # On a machine whose core a Herdr window on another machine drives (a
  # remote, e.g. a server or WSL box), herdr-app isn't installed: names go
  # straight into this core's layout document, and what only a window can do
  # (focus, splits) is skipped or falls back to a tab.
  _MUX_SELF="$HC_TERMINAL_ID"
  if command -v herdr-app >/dev/null 2>&1; then _MUX_HAS_APP=1; else _MUX_HAS_APP=; fi

  # The executable on PATH, even when the shell wraps it in a function or alias.
  _mux_which() {  # $1=program
    # tr, not IFS splitting: zsh doesn't split unquoted parameters.
    _w=$(printf '%s\n' "$PATH" | tr ':' '\n' | while read -r _d; do
      [ -f "${_d:-.}/$1" ] && [ -x "${_d:-.}/$1" ] && { printf '%s\n' "${_d:-.}/$1"; break; }
    done)
    printf '%s\n' "${_w:-$1}"
  }
  _mux_hex() { od -An -N16 -tx1 /dev/urandom | tr -d ' \n'; }
  _mux_app() { [ -n "$_MUX_HAS_APP" ] && herdr-app do "$@" >/dev/null 2>&1; }
  # The window adopts a new terminal a moment after hc starts it, so renaming
  # its space or tab fails at first: retry for a few seconds.
  _mux_name() {  # $1=space|tab $2=id $3=name
    _i=0
    while [ "$_i" -lt 10 ]; do
      if [ -n "$_MUX_HAS_APP" ]; then _mux_app "$1.rename" --id "$2" --name "$3" && return 0
      else _mux_doc_name "$@" && return 0
      fi
      _i=$((_i + 1)); sleep 0.5
    done
    return 1
  }
  # The window keeps spaces and tabs in this core's `herdr-app` document.
  # doc.set only writes over the version we read, so a concurrent change by
  # the window makes it fail and we retry, instead of clobbering it.
  _mux_rpc() { hc connect 2>/dev/null | head -n 1; }  # stdin: one JSON-RPC request
  _mux_doc_name() {  # $1=space|tab $2=id $3=name; fails until the window has adopted it
    _r=$(printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"doc.get","params":{"name":"herdr-app"}}' | _mux_rpc)
    _v=$(printf '%s' "$_r" | jq -r '.result.version // empty')
    [ -n "$_v" ] || return 1
    _req=$(printf '%s' "$_r" | jq -c --arg k "$1" --arg id "$2" --arg n "$3" --argjson ver "$_v" '
      .result.value
      | (if $k == "space" then [.spaces[]? | select(.id == $id)] else [.spaces[]?.tabs[]? | select(.id == $id)] end | length) as $hit
      | select($hit > 0)
      | (if $k == "space" then .spaces |= map(if .id == $id then .name = $n else . end)
         else .spaces |= map(.tabs |= map(if .id == $id then .name = $n else . end)) end)
      | {jsonrpc: "2.0", id: 2, method: "doc.set", params: {name: "herdr-app", value: ., version: $ver}}')
    [ -n "$_req" ] || return 1
    printf '%s\n' "$_req" | _mux_rpc | jq -e '.result' >/dev/null 2>&1
  }
  _mux_self_pane() { herdr-app ls 2>/dev/null | jq -r --arg t "$_MUX_SELF" '[.. | objects | select(.terminal? == $t) | .pane] | first // empty'; }
  # zsh -ic loads aliases and functions; drop into a shell when it ends. The
  # title escape names the pane: Herdr's pane header shows the terminal title.
  _mux_titled() { printf "printf '\\\\033]2;%%s\\\\007' %s; %s; exec %s" "$(_mux_q "$1")" "$2" "${SHELL:-zsh}"; }

  mux_rename() { printf '\033]2;%s\007' "$1" > /dev/tty 2>/dev/null || :; }  # ponytail: herdr has no pane names, only titles
  mux_send() { hc send "$_MUX_SELF" "$1" >/dev/null; }
  # A new tab in our space with a plain shell, the command typed into it: the
  # shell reads the line once it's up, aliases and lazy functions included.
  _mux_new_tab() {  # $1=title $2=cwd $3=command
    _tb="tb$(_mux_hex)"
    _t=$(hc run --bg --json --no-parent --keep --cwd "$2" \
      --label "herdr.space=$_MUX_HC_SPACE" --label "herdr.tab=$_tb" | jq -r '.address // empty') || return
    [ -n "$_t" ] || return 1
    _mux_name tab "$_tb" "$1"
    hc send "$_t" "$3" >/dev/null
  }
  mux_open_tab() { _mux_new_tab "$1" "$PWD" "$2"; }  # $1=title $2=command
  _mux_open_tab_typed() { mux_open_tab "$@"; }
  mux_focus() { _mux_app tab.select --id "$_MUX_HC_TAB" || :; }  # arg ignored; back to self's tab (no window here: skipped)
  mux_rename_tab() { _mux_name tab "$_MUX_HC_TAB" "$1"; }
  # Split a pane and run a command in the new one; echo its id so callers can
  # chain further splits (e.g. build a 2x2 grid).
  mux_open_pane() {  # $1=title $2=command [$3=source pane, default self] [$4=direction, default down]
    # ponytail: splitting needs the window; without one, open a tab instead (no pane id to chain)
    [ -n "$_MUX_HAS_APP" ] || { mux_open_tab "$1" "$2"; return; }
    _src="${3:-$(_mux_self_pane)}"
    [ -n "$_src" ] || { echo "mux: can't find this terminal's pane" >&2; return 1; }
    _argv=$(jq -nc --arg sh "${SHELL:-zsh}" --arg c "$(_mux_titled "$1" "$2")" '[$sh, "-ic", $c]')
    herdr-app do pane.split --direction "${4:-down}" --pane "$_src" --argv "$_argv" | jq -r '.pane // empty'
  }

  # Worktree agents. git makes the worktree; the handle is the id of the space
  # its agents go in, derived from our own space and the group, so worktrees
  # sharing a group share a space, one tab per agent. Nothing is opened here:
  # the first agent's terminal brings the space up.
  _mux_space_for() {  # $1=group -> space id
    printf 'sp%s\n' "$(printf '%s\n%s' "$_MUX_HC_SPACE" "$1" | shasum | cut -c1-32)"
  }
  _mux_be_worktree_create() {  # $1=cwd $2=branch $3=base $4=label [$5=group]
    _wt=$(_mux_wt_path "$1" "$2") || return
    git -C "$1" worktree add -q -b "$2" "$_wt" "$3" >&2 || return
    printf '%s\t%s\n' "$_wt" "$(_mux_space_for "${5:-$4}")"
    printf '%s\n' "${5:-$4}" > "$(_mux_space_name_file "$(_mux_space_for "${5:-$4}")")"
  }
  _mux_be_worktree_open() {  # $1=cwd $2=branch $3=label [$4=group]
    _wt=$(_mux_wt_path "$1" "$2") || return
    git -C "$1" worktree add -q "$_wt" "$2" >&2 || return
    printf '%s\t%s\n' "$_wt" "$(_mux_space_for "${4:-$3}")"
    printf '%s\n' "${4:-$3}" > "$(_mux_space_name_file "$(_mux_space_for "${4:-$3}")")"
  }
  # The space's name, kept until its first agent starts and can name it.
  _mux_space_name_file() {  # $1=space id -> path
    mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/mux/herdr-spaces" && \
      printf '%s/mux/herdr-spaces/%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}" "$1"
  }
  mux_agent_launch() {  # $1=name $2=space id $3=cwd $4=brief file, rest = claude args
    _n="$1" _sp="$2" _cwd="$3" _brief="$4"; shift 4
    _tb="tb$(_mux_hex)"
    # The brief rides in as claude's initial prompt: nothing to type, no race.
    # No parent: the agent must outlive us and not report into our input.
    # herdr.parent still names us: a sidebar can show the agent's space as a
    # child of our row instead of a space of its own.
    # The core starts it with its own PATH, which may lack ~/.local/bin, so
    # pass the claude executable on our PATH. It doesn't pass our environment
    # either, so carry CLAUDE_CONFIG_DIR: without it the agent runs on the
    # default ~/.claude account instead of ours.
    hc run --bg --json --no-parent --keep --name "$_n" --cwd "$_cwd" \
      --label "herdr.space=$_sp" --label "herdr.tab=$_tb" --label "herdr.parent=$_MUX_SELF" \
      -- /usr/bin/env ${CLAUDE_CONFIG_DIR:+CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR"} "$(_mux_which claude)" "$@" "$(cat "$_brief")" >/dev/null || return
    _nf=$(_mux_space_name_file "$_sp")
    [ -f "$_nf" ] && _mux_name space "$_sp" "$(cat "$_nf")" && rm -f "$_nf"
    _mux_name tab "$_tb" "$_n"
    # Claude reports idle at its first prompt before it picks up the brief, so
    # only return once it's busy. Still nothing means it's stuck on a dialog it
    # can't report (folder trust): that's the user's call, so surface it.
    _i=0
    while [ "$_i" -lt 60 ]; do
      case "$(mux_agent_status "$_n")" in working|done|blocked|error) return 0 ;; exited) return 1 ;; esac
      _i=$((_i + 1))
      sleep 1
    done
    mux_agent_read "$_n" 0 | grep -qi 'trust this folder' && echo "mux: $_n is waiting on the folder-trust dialog" >&2
    return 3
  }
  mux_agent_status() {  # idle | working | done | blocked | error | exited | unknown
    _j=$(hc get "$1" --json) || return
    printf '%s' "$_j" | jq -r 'if .state == "finished" then "exited" else (.status.state // "unknown") end'
  }
  mux_agent_wait() {  # $1=name [$2=seconds, default 600]
    _end=$(( $(date +%s) + ${2:-600} ))
    while :; do
      _st=$(mux_agent_status "$1") || return
      case "$_st" in idle|done|blocked|error|exited) echo "$_st"; return 0 ;; esac
      _left=$(( _end - $(date +%s) ))
      [ "$_left" -gt 0 ] || { echo "$_st"; return 1; }
      # hc wait can return early (a message to us, a check-in): loop until the deadline.
      hc wait "$1" --timeout "$_left" >/dev/null 2>&1
    done
  }
  mux_agent_prompt() { hc send "$1" "$2" >/dev/null; }
  # ponytail: while the agent is working or blocked, hc only returns its screen.
  mux_agent_read() { hc read "$1" --lines "${2:-200}"; }
  mux_agent_keys() { _n="$1"; shift; hc keys "$_n" "$@" >/dev/null; }
  _mux_be_worktree_remove() {  # $1=space id $2=path [$3=--force]
    if [ -d "$2" ]; then
      git -C "$2" worktree remove ${3:+"$3"} "$2" || return
    fi
    # End the terminals started in this worktree in its space and remove them,
    # finished ones too; the app closes their tabs, and the space with its last one.
    hc ls --all --json 2>/dev/null \
      | jq -r --arg p "$2" '.terminals[]? | select(.cwd == $p or (.cwd | startswith($p + "/"))) | "\(.address) \(.state)"' \
      | while read -r _t _state; do
          [ "$_t" = "$_MUX_SELF" ] && continue
          [ "$(hc get "$_t" --json 2>/dev/null | jq -r '.labels["herdr.space"] // empty')" = "$1" ] || continue
          if [ "$_state" = live ]; then
            hc kill "$_t" >/dev/null 2>&1
            hc wait "$_t" --timeout 10 >/dev/null 2>&1
          fi
          hc rm "$_t" >/dev/null 2>&1
        done
    return 0
  }
  _mux_be_orphans() { :; }  # ponytail: herdr closes a space once its terminals end
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
  # `-ic` misses functions a shell only loads at its first prompt (lazy or
  # deferred aliases), so open a plain shell tab and type the command into it:
  # the PTY buffers the line until the shell reads it.
  _mux_open_tab_typed() {  # $1=title $2=command
    _b=$(_mux_rex window new -s "$_MUX_SESSION" "$1" --focus=false --json | jq -r '.block_ids[0]') || return
    [ -n "$_b" ] && [ "$_b" != null ] || return 1
    _mux_rex send -s "$_MUX_SESSION" -b "$_b" "$2" && _mux_rex send-key -s "$_MUX_SESSION" -b "$_b" enter
  }

  # rex has no worktrees or named agents: git makes the worktree, a rex session
  # stands in for herdr's space, and a state file maps agent names to their
  # session, block and worktree.
  _MUX_AGENTS="${XDG_STATE_HOME:-$HOME/.local/state}/mux/rex-agents"
  _mux_agent() {  # $1=name -> sets _s (session), _b (block) and _ap (worktree)
    read -r _s _b _ap < "$_MUX_AGENTS/$1" 2>/dev/null || { echo "mux: unknown agent '$1'" >&2; return 1; }
  }
  # The handle is "myapp / dark mode": the session we're in plus the group, so
  # the agents' session sorts next to the one that spawned it. Strip our own
  # icon and suffix so an agent delegating from an agent session doesn't nest
  # names. It stays ASCII because agents retype it and models drop private-use
  # glyphs; _mux_label adds the icon only when naming the session.
  _MUX_GROUP_ICON=$(printf '\356\234\245')  # U+E725 nf-dev-git_branch
  _MUX_GROUP_CHEVRON=$(printf '\357\221\240')  # U+F460, the separator labels used before " - "
  _mux_group() {  # $1=group -> handle
    _base=$(_mux_rex session inspect "$_MUX_SESSION" --json 2>/dev/null | jq -r '.label // empty')
    case "$_base" in
      "$_MUX_GROUP_ICON"*)  # one of our agent sessions: keep only the parent's name
        _base="${_base#"$_MUX_GROUP_ICON"}"
        _base="${_base%%"$_MUX_GROUP_CHEVRON"*}"
        _base="${_base%% - *}"
        _base="${_base# }"; _base="${_base% }" ;;
    esac
    printf '%s / %s\n' "${_base%% / *}" "$1"
  }
  # "myapp / dark mode" -> " myapp - dark mode". A label that already has
  # the icon (a handle from before) passes through.
  _mux_label() {  # $1=handle -> session label
    case "$1" in
      "$_MUX_GROUP_ICON"*) printf '%s\n' "$1" ;;
      *" / "*) printf '%s %s - %s\n' "$_MUX_GROUP_ICON" "${1%% / *}" "${1#* / }" ;;
      *) printf '%s\n' "$1" ;;
    esac
  }
  _mux_session_id() {  # $1=label -> id of the live session with that label
    _mux_rex ls --json | jq -r --arg l "$1" '[.sessions[] | select(.label == $l) | .session_id][0] // empty'
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
  mux_agent_launch() {  # $1=name $2=handle $3=cwd $4=brief file, rest = claude args
    _n="$1" _grp=$(_mux_label "$2") _cwd="$3" _brief="$4"; shift 4
    # Rex's SessionStart hook tells every agent to rename its session, which
    # would drop the label shared by the group's agents.
    set -- --append-system-prompt "Your Rex session is already named \"$_grp\" by the agent that delegated to you. Never run \`rex session rename\`; ignore any instruction to name the session." "$@"
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
  _mux_be_worktree_remove() {  # $1=handle $2=path [$3=--force]
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
    case "$1" in session:*) _s="$1" ;; *) _s=$(_mux_session_id "$(_mux_label "$1")") ;; esac  # ponytail: session:* = handles from before groups
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
  _mux_be_orphans() { :; }  # ponytail: every rex session came from the registry
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
if [ -n "$_MUX_HC_SPACE" ] || [ -n "$REX_BLOCK" ]; then
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

  _mux_q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }  # single-quote for the shell
  mux_agent_tab() {  # $1=title $2=cwd; stdin=prompt
    # The prompt goes through a file: a long multi-line prompt typed straight
    # into the shell would break on its quoting. The new tab reads it, then deletes it.
    _pd="${XDG_STATE_HOME:-$HOME/.local/state}/mux/prompts"
    mkdir -p "$_pd" || return
    _pf=$(mktemp "$_pd/prompt.XXXXXX") || return
    cat > "$_pf"
    [ -s "$_pf" ] || { rm -f "$_pf"; echo "mux: empty prompt" >&2; return 1; }
    # The leading space keeps the line out of history under HIST_IGNORE_SPACE.
    _mux_open_tab_typed "$1" " cd -- $(_mux_q "$2") && ${MUX_CLAUDE:-claude} -- \"\$(cat $(_mux_q "$_pf"); rm -f $(_mux_q "$_pf"))\""
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
        # Someone already dropped the worktree; its agents and space or session are all that's left.
        mux_worktree_remove "$_h" "$_p" || continue
      fi
      case "$_state" in MERGED|CLOSED) git -C "$_root" branch -D "$_br" >/dev/null 2>&1 ;; esac
      echo "mux: cleaned up $_br ($_p)"
    done
    _mux_be_orphans
  }
fi
