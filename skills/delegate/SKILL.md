---
name: delegate
description: Hand a task off to a fresh agent in its own Herdr worktree, briefed with what you already found out and told to /ship it
argument-hint: <task description>
---

The task to hand off: $ARGUMENTS

You don't implement this. You scout it, brief someone else, and stay free.

Requires Herdr: check `test "${HERDR_ENV:-}" = 1` first. If it fails, say so and stop.

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

```bash
git fetch origin --quiet
herdr worktree create --cwd "$PWD" --branch <kebab-branch> --base origin/<base> --label <short> --no-focus
```

Read the workspace and root pane ID from the JSON response — don't guess them.

## 4. Start the agent and brief it

```bash
herdr agent start <kebab-name> --kind claude --pane <root_pane_id> -- --dangerously-skip-permissions
herdr agent prompt <kebab-name> "$(cat <brief-file>)" --wait
```

Write the brief to a file first; long prompts don't survive shell quoting.

It carries, in order: the task; **everything you found while scouting**, so it
doesn't repeat your work; the decisions I made and the ones you defaulted; what it
must not touch; the deliverable. Last line is `/ship`.

> `agent_prompt_stalled` is usually a false alarm — the prompt landed and the agent
> is already working. Check `herdr agent get` / `herdr agent read` before reacting,
> and **never re-send**: you'd queue the brief twice.

## 5. Report and get out of the way

Give me the worktree path, the branch, the agent name, and how to follow it
(`herdr agent read <name> --source recent-unwrapped`). Don't block waiting on it.

Anything scouting surfaced that I should decide but that doesn't block the work —
a rollout step, a cost, a stale assumption — goes here in a line or two, outside
the brief.
