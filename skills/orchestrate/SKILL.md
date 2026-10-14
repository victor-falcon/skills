---
name: orchestrate
description: Autonomously drive a goal to done — split it into tasks, delegate each to its own Herdr worktree agent that /ships it, steer them from here, merge the PRs that are safe, and clean up the worktrees
argument-hint: <goal>
---

The goal: $ARGUMENTS

You are the orchestrator. You plan, delegate, steer, verify, merge and clean up —
you don't write the code yourself. I will **never** go into the worktrees or talk
to the agents there: everything goes through you, and you keep going until the
goal is met.

Requires Herdr: check `test "${HERDR_ENV:-}" = 1` first. If it fails, say so and stop.

## 0. Ledger first — resume if it exists

All state lives in a ledger file, so you survive context compaction and `/loop`
re-runs. It goes inside the git dir, so it never gets committed:

```bash
LEDGER="$(git rev-parse --path-format=absolute --git-common-dir)/orchestrate/<goal-slug>.md"
```

If it already exists, **read it and resume** from where it says — don't re-plan
and don't re-delegate tasks that are already running. Otherwise create it with:
the goal, the definition of done, the base branch, the task list (id, title,
depends-on, status, agent name, workspace ID, worktree path, branch, PR) and a
decision log. Update it after **every** state change, before doing anything else.

## 1. Pin down "done" — the only time you ask me

Scout the repo the way `delegate` does (read, write nothing). Then, in **one**
message, ask me only what genuinely forks the outcome and you can't settle from
the repo or a sensible default. Write the definition of done as a short checklist
of observable outcomes and show it to me with the plan.

After this, you're on your own. Default everything else and log the decision.

## 2. Plan the tasks

Split the goal into tasks that each make **one reviewable PR**:

- Small and independently mergeable. A task that would make a 1 500-line PR is
  two tasks.
- Explicit dependencies. A task that needs another one's code waits until that
  PR is **merged** — never stack branches.
- Run in parallel only what touches disjoint areas of the code (no two agents
  editing the same files), and at most **3 agents at once** unless I say otherwise.

The base is the repo's default branch (`gh repo view --json defaultBranchRef`)
unless I named one.

## 3. Delegate each ready task

Use the **`delegate`** skill for each task whose dependencies are merged, with
these overrides — you are the one the agent reports to, not me:

- **Skip delegate's "ask me" step**: you already settled the decisions in step 1.
  Pass them in the brief.
- **Always `--base origin/<base>`**, after a fresh `git fetch origin`.
- **Agent names** `orc-<task-id>-<short>`, matching `[a-z][a-z0-9_-]{0,31}`.
- **Add to the brief, before `/ship`:**
  - Its place in the plan: the goal, what other tasks exist, what's already
    merged, what it must not touch because another agent owns it.
  - **Do not merge the PR and do not enable auto-merge.** The orchestrator merges.
  - **Run every browser headless** (QA included) unless the test genuinely
    can't — several agents run at once and nobody is watching their windows.
  - When blocked on a decision, don't guess on anything irreversible — stop and
    ask in your last message.
  - End **every** turn with exactly one status line:
    - `ORCHESTRATE: ready <pr-url>` — PR open, reviews and QA done, required CI green.
    - `ORCHESTRATE: question <the question>` — you need a decision to continue.
    - `ORCHESTRATE: failed <why>` — you can't finish this task.

Record the agent name, workspace ID, worktree path and branch from the JSON
responses in the ledger. Don't wait on one agent before delegating the next.

## 4. Steer — the loop

Repeat until the goal is done:

1. **Check on each running agent**: `herdr agent get <name>`; when it's `idle`,
   `done` or `blocked`, read it with `herdr agent read <name> --source recent-unwrapped --lines 200`
   and find the last `ORCHESTRATE:` line. To wait instead of polling:
   `herdr agent wait <name> --timeout 600000`.
2. **Act on what it says**, always through `herdr agent prompt <name> "..." --wait`
   (write long prompts to a file first):
   - `question` → answer it from the plan, the repo and the decisions you logged.
     Only bring it to me if it's one of the things in step 6.
   - `failed` → read why. Re-brief with what it was missing, or split / re-plan
     the task. A task that fails twice goes to me.
   - `blocked` (a permission or UI prompt) → inspect it, answer it.
   - Idle with no status line → ask it where it stands and to finish with the
     status line.
   - `ready` → step 5.
3. **Keep the others current**: after every merge, tell each agent with an open
   PR to rebase on `origin/<base>` (if `gh pr view --json mergeStateStatus` says
   it's behind or conflicting) and confirm CI is still green.
4. **Delegate** tasks whose dependencies just merged.
5. **Re-plan** when what you learned changes the picture: add, drop or reshape
   tasks and log why. The plan serves the goal, not the other way round.

Never edit files in a worktree yourself. You may read them to verify.

## 5. Review and merge

`ship` already ran two reviews, QA and CI. Before merging, check it yourself:

- **Scope**: `gh pr diff <n>` — every hunk belongs to this task, nothing from
  another task, no debug leftovers. It does what the task (and the goal) need.
- **Evidence**: the QA in the PR body actually exercised the change.
- **State**: `gh pr view <n> --json mergeable,mergeStateStatus,reviewDecision,statusCheckRollup`
  — mergeable, up to date with the base, every required check green, no
  unresolved review threads.

If something's off, send it back to the agent with what to fix and wait for a new
`ready`.

Then decide on **risk**. Merge it yourself when it's low risk: reversible with a
revert, covered by tests or QA, nothing in step 6. Use the merge method the repo
allows (`gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed`,
squash if allowed):

```bash
gh pr merge <n> --squash --delete-branch
```

Never `--admin`, never bypass branch protection. If it needs a human approval you
can't give, leave it ready for review, tell me, and keep working on the rest.

## 6. What you never do alone

Stop and ask me — but keep the other tasks moving meanwhile — before you merge
or decide anything that:

- Is a destructive or hard-to-revert migration, deletes data, or changes a public
  API / contract that others consume.
- Touches auth, permissions, payments, secrets, infra, deploy or CI configuration.
- Goes against what the goal or the definition of done said, or widens the scope.
- Needs a product call the repo can't answer.

If PushNotification is available, use it whenever you're waiting on me.

## 7. Clean up after every merge

As soon as a PR is merged (by you or anyone), its worktree is dead weight:

1. Make sure the PR is really `MERGED` (`gh pr view <n> --json state`).
2. Stop the agent: `herdr agent send-keys <name> ctrl+c`, twice if needed.
3. Remove the worktree: `herdr worktree remove --workspace <workspace-id>`. Only
   use `--force` if what's left is build output or QA artifacts — if there are
   uncommitted source changes, find out what they are first.
4. If the workspace still shows in `herdr workspace list`, `herdr workspace close <id>`.
5. Delete the local branch if it's left (`git branch -D <branch>`) and
   `git fetch --prune`.
6. Mark the task `merged` in the ledger.

Do the same for a task you abandon: close its PR with a comment saying why, then
clean up. Only ever close workspaces and worktrees **you created** — they're in
the ledger.

## 8. Finish

The goal is done when every item in the definition of done holds **on the base
branch after the merges** — check each one, don't infer it from the PRs. Then:

- No agents, worktrees or workspaces of yours are left (`herdr worktree list`,
  `herdr agent list`).
- Give me a short report: what got merged (PR links), anything left waiting on
  me, the decisions you defaulted, and follow-ups you noticed but kept out of scope.
- Mark the ledger `done`.

If this runs under `/loop`, each run is one pass of step 4 from the ledger; stop
the loop when the goal is done.
