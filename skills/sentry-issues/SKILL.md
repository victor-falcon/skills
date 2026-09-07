---
name: sentry-issues
description: Autonomous loop — triage Sentry issues, delegate the fixes worth making, and open PRs (auto-merge when confident, draft otherwise)
argument-hint: (run with /loop, e.g. `/loop 2h /sentry-issues`)
---

Look at the issues in Sentry, prioritize them, and open a PR for the ones you judge to be **fixable from code** and **relevant** — mainly things that degrade or affect the user's core functionality.

**There is no human in the loop. You are on your own.** I will review the PRs periodically, but I will never watch this loop run. Do not wait for confirmation at any point — act autonomously.

## 1. Delegate the hotfix

You don't write the fix yourself. For every issue you decide to act on, hand it off with the **`delegate`** skill — one delegation per issue, so each hotfix gets its own worktree, branch and PR.

The worktree **must start from `origin/main`**: `git fetch origin` first, then base it there (`--base origin/main`), never on whatever branch this loop happens to be sitting on. A hotfix stacked on someone else's in-flight work is worse than no hotfix.

Brief it with the Sentry evidence you already gathered, so it doesn't dig it up again: the issue link, the stack trace, the code path it points at, how often it fires and since when, and the reproduction if you worked one out. Then move on to the next issue — don't sit waiting for the agent.

If Herdr isn't available, `delegate` stops. In that case do the fix yourself, on a branch off `origin/main`, and run **`ship`** on it.

## 2. Tell it how to ship

`ship` — which the brief ends with — already covers the two parallel reviews, the QA and watching CI. What it can't guess is how bold to be, so put that in the brief, from your estimate of the fix's **safety** and **complexity**:

- **Not very complex** and you are **very confident** it fixes the problem without creating new ones → create the PR and **enable auto-merge**, watching CI until it's green.
- Otherwise → create the PR as a **draft**.

PR title and description in **English**.
