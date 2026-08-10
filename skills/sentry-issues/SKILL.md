---
name: sentry-issues
description: Autonomous loop — triage Sentry issues, fix the code-fixable & user-relevant ones, and open PRs (auto-merge when confident, draft otherwise)
argument-hint: (run with /loop, e.g. `/loop 2h /sentry-issues`)
---

Look at the issues in Sentry, prioritize them, and open a PR for the ones you judge to be **fixable from code** and **relevant** — mainly things that degrade or affect the user's core functionality.

**There is no human in the loop. You are on your own.** I will review the PRs periodically, but I will never watch this loop run. Do not wait for confirmation at any point — act autonomously.

For each bug, **before opening a PR**:

## 1. Two parallel reviews

Launch two agents **in parallel** (in the same message) over the diff, each running one of these skills:

1. **`technical-review`**: code architecture, bad patterns, consistency with existing conventions and components, and the Fowler code smells.
2. **`product-review`**: side-effects and bugs (what could break) plus whether the change is correct and sensible for the user.

Those skills only report by default; here you **do** act on them: apply the changes you consider reasonable from their findings — use judgment, not every finding warrants a change — and briefly explain what you apply and what you drop, and why.

## 2. Estimate & ship

Estimate the **safety** of the fix and its **complexity**:

- If it's **not very complex** and you are **very confident** you're fixing the problem without creating new ones → create the PR and **enable auto-merge**, and watch the CI.
- Otherwise → create the PR as a **draft**.

PR title and description in **English**.
