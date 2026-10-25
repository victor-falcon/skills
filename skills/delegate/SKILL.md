---
name: delegate
description: Hand a task off to a fresh agent in its own worktree (Herdr or Rex), briefed with what you already found out and told to /ship it
argument-hint: <task description>
---

The task to hand off: $ARGUMENTS

You don't implement this. You scout it, brief someone else, and stay free.

Every multiplexer step goes through `scripts/multiplexer.sh`, which ships with this
skill and drives Herdr or Rex, whichever you're running in. Replace `<skill dir>`
below with the base directory this skill was loaded from, as an absolute path, and
keep the quotes. Shell state doesn't survive between Bash calls, so source it at
the start of each one:

```bash
. "<skill dir>/scripts/multiplexer.sh" && mux_backend
```

It must print `herdr` or `rex`. If the file isn't there, or it prints anything
else, say so and stop: this skill needs a Claude Code session running inside Herdr
or Rex.

## 1. Scout before you delegate

Read the repo, write nothing. You're after the things that would cost the other
agent an hour or send it down the wrong path:

- Does the plumbing for this already exist? Point at it by path.
- What's the convention for this kind of change — a sibling file doing the same
  thing? Name it.
- Anything that blocks or reshapes the task: a feature flag that's off, a gate the
  change lands behind, a constraint the task description didn't know about.

Stop as soon as you can brief someone. This is reconnaissance, not implementation.

## 2. Ask me only what changes the work

If scouting turned up a decision that genuinely forks the outcome and you can't
settle it from the repo or a sensible default, ask me **now** — once the agent is
running it can't reach me. Everything else: default it, and say so.

## 3. Create the worktree

First clear out what earlier hand-offs left behind: `mux_worktree_gc` removes every
worktree it created whose PR is merged or closed, with its workspace (Herdr) or
session (Rex) and local branch. It keeps any with uncommitted changes to tracked
files and says so — pass that on to me, don't force it.

```bash
git fetch origin --quiet
. "<skill dir>/scripts/multiplexer.sh" && mux_worktree_gc && mux_worktree_create "$PWD" <kebab-branch> origin/<base> "<label>" ["<group>"]
```

`<label>` is a few plain words naming the task (`dark mode`). Pass
`<group>` only when the caller gave you one (orchestrate does): every worktree with
the same group shares one Rex session. Under Rex the session is named after the
one you're in plus the group, or the label when there's no group:
`myapp / dark mode`. Herdr names the workspace after the label.

It prints `<worktree path><TAB><handle>` — the handle is the Herdr root pane or the
Rex session name, which has spaces, so always quote it. Keep both; don't guess them.

## 4. Start the agent and brief it

Write the brief to a file first; long prompts don't survive shell quoting. Then:

```bash
. "<skill dir>/scripts/multiplexer.sh" && mux_agent_launch <kebab-name> "<handle>" "<worktree path>" <brief-file> --dangerously-skip-permissions
```

The name must match `[a-z][a-z0-9_-]{0,31}`. It returns once the agent has picked
up the brief. Exit status 3 means it's stuck on Claude's folder-trust dialog:
tell me, don't answer it yourself.

The brief carries, in order: the task; **everything you found while scouting**, so
it doesn't repeat your work; the decisions I made and the ones you defaulted; what
it must not touch; the deliverable. Last line is `/ship`.

> A launch or prompt that reports a failure may still have landed. Check
> `mux_agent_status <name>` / `mux_agent_read <name>` before reacting, and
> **never re-send**: you'd queue the brief twice.

## 5. Report and get out of the way

Give me the worktree path, the branch, the agent name, and where to follow it: the
Herdr workspace, or the Rex session (`<current session> / <group or label>`), where
the agent's tab carries its name. Don't block waiting on it.

Anything scouting surfaced that I should decide but that doesn't block the work —
a rollout step, a cost, a stale assumption — goes here in a line or two, outside
the brief.
