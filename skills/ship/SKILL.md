---
name: ship
description: Implement a task and finalize it (two parallel reviews, QA appropriate to the change — browser + video for UI, otherwise the way it's actually used — a PR, and watching CI until green)
argument-hint: <task description>
---

Your task: $ARGUMENTS

## 0. Clean starting point (before writing any code)

Check `git status` and `git log --oneline @{u}..` / the diff against the base branch:

- **Uncommitted or stashed changes that aren't part of this task**: stop and ask me what to do with them (keep, stash, discard). Don't build on top of them.
- **The branch already has commits that aren't part of this task**: stop and ask whether to branch off the base instead.
- **The branch is behind the base branch**: update it (rebase or merge onto the latest base) before starting.
- **You're on the base branch itself**: create a new branch from the up-to-date base.

Only start implementing from a clean, up-to-date starting point.

Implement it. **Once the implementation is ready, you MUST run this wrap-up in order:**

## 1. Two parallel reviews

Launch two agents **in parallel** (in the same message) over the diff, each running one of these skills:

1. **`technical-review`**: code architecture, bad patterns, consistency with existing conventions and components, and the Fowler code smells.
2. **`product-review`**: side-effects and bugs (what could break) plus whether the change is correct and sensible for the user.

Those skills only report by default; here you **do** act on them: apply the changes you consider reasonable from their findings — use judgment, not every finding warrants a change — and briefly explain what you apply and what you drop, and why.

## 2. QA

Run the **`qa-change`** skill before creating the PR: it decides whether browser QA makes sense, does real browser QA + a recorded video for UI surfaces, or QAs a backend change the way it's actually used (run the command, hit the endpoint, check DB/logs/tests). Any browser it launches runs **headless** unless the test genuinely can't.

## 3. PR

- **Before creating it, review the full diff against the base branch** (`git diff <base>...HEAD`) file by file: every file and hunk must belong to this task. If something unrelated slipped in (leftovers from a previous session, debug prints, formatting churn, generated files, an unrelated fix), revert it or move it to its own branch — and tell me what you removed. Don't open a PR with unrelated changes in it.
- Create the PR (title and description **in English**).
- **Only if QA captured evidence:** reference each file in the body file where it belongs (a video as its bare local path on its own line, a screenshot as `![alt](<local path>)` under its Before/After heading) and pass one `--attach` per file — `gh` replaces each path with the uploaded URL in place:

  ```sh
  gh pr create --title "..." --body-file <body.md> \
    --attach '<before.png>' --attach '<after.png>' --attach '<demo.mp4>'
  ```

  Then check the media actually landed (`gh pr view --json body`). If the upload fails, leave a placeholder and tell me the exact paths so I can drag them in.

## 4. Watch CI

After the PR is created, **stay watching the CI until every required check is green** — don't stop at "PR created". Poll the PR's checks (e.g. `gh pr checks --watch`) until all **required** checks have passed.

- If a required check fails, investigate: fix real failures caused by the change and push, or retry flakes. Then keep watching.
- Only report the task as done once all required checks are green (skipped/optional non-required checks are fine).
