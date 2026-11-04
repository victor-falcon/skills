---
name: on-new-tab
description: Run one thing in a new tab of the current Herdr workspace or Rex session — starts a fresh Claude Code agent there with a prompt. No worktree, no branch, no /ship. Use when the user wants something launched "in a new tab", "on the side", or "in another tab".
argument-hint: <what the new agent should do>
---

What to run in the new tab: $ARGUMENTS

You open one tab next to this one, start Claude Code in it with a prompt, and
get back to what you were doing. You don't do the work yourself, and you don't
wait for it.

This is not `delegate`: no worktree, no branch, no PR. The new agent works in
the same checkout as you. If the task will edit code while you're also editing,
say so and suggest `delegate` instead.

## 1. Load the helper

Every multiplexer step goes through the helper that ships with `delegate`.
Replace `<skill dir>` with the base directory this skill was loaded from, as an
absolute path, and keep the quotes:

```bash
. "<skill dir>/../delegate/scripts/multiplexer.sh" && mux_backend
```

It must print `herdr` or `rex`. If the file isn't there, or it prints anything
else, say so and stop: this skill needs a Claude Code session running inside
Herdr or Rex, and `delegate` installed next to it.

## 2. Write the prompt

The new agent starts with no context, so the prompt has to stand on its own:

- The task, in the user's words. Don't expand the scope.
- Anything from this conversation it needs: paths, names, an error message, a
  decision already made. Skip what it can find in a few seconds.
- What "done" looks like, if the user said.

Keep it short. If the user gave you the exact prompt, pass it verbatim.

## 3. Open the tab

One Bash call. The prompt goes on stdin through a quoted heredoc, so nothing in
it gets expanded:

```bash
. "<skill dir>/../delegate/scripts/multiplexer.sh" && mux_agent_tab "<title>" "$PWD" <<'PROMPT'
<the prompt>
PROMPT
```

- `<title>` is two or three words naming the task (`fix flaky test`).
- The second argument is where the agent starts; `$PWD` unless the user named
  another directory.
- It runs `claude` by default. If the user has a wrapper (an alias or shell
  function such as `clc`), prefix the call with `MUX_CLAUDE=clc`. The command is
  typed into an interactive shell, so aliases and functions resolve.

The tab opens in the background; the user's focus doesn't move. Run it once: if
it reports a failure, look for the tab before retrying, or the user ends up
with two agents.

## 4. Report

One line: the tab title and what you asked it to do. Then carry on with
whatever you were doing before.
