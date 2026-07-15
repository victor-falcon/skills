---
name: ship
description: Implement a task and finalize it (two parallel reviews, QA appropriate to the change — browser + video for UI, otherwise the way it's actually used — a PR, and watching CI until green)
argument-hint: <task description>
---

Your task: $ARGUMENTS

Implement it. **Once the implementation is ready, you MUST run this wrap-up in order:**

## 1. Two parallel reviews

Launch two agents **in parallel** (in the same message) over the diff, each running one of these skills:

1. **`technical-review`**: code architecture, bad patterns, consistency with existing conventions and components, and the Fowler code smells.
2. **`product-review`**: side-effects and bugs (what could break) plus whether the change is correct and sensible for the user.

Those skills only report by default; here you **do** act on them: apply the changes you consider reasonable from their findings — use judgment, not every finding warrants a change — and briefly explain what you apply and what you drop, and why.

## 2. QA

Run the **`qa-change`** skill before creating the PR: it decides whether browser QA makes sense, does real browser QA + a recorded video for UI surfaces, or QAs a backend change the way it's actually used (run the command, hit the endpoint, check DB/logs/tests).

## 3. PR

- Create the PR (title and description **in English**).
- **Only if you recorded a video:** include a **Demo** section with a clearly marked **placeholder** so I can attach the video manually, and tell me the exact path of the generated video so I can drag it in.

## 4. Watch CI

After the PR is created, **stay watching the CI until every required check is green** — don't stop at "PR created". Poll the PR's checks (e.g. `gh pr checks --watch`) until all **required** checks have passed.

- If a required check fails, investigate: fix real failures caused by the change and push, or retry flakes. Then keep watching.
- Only report the task as done once all required checks are green (skipped/optional non-required checks are fine).
