---
name: sentry-issues
description: Autonomous loop — triage Sentry issues, fix the code-fixable & user-relevant ones, and open PRs (auto-merge when confident, draft otherwise)
argument-hint: (run with /loop, e.g. `/loop 2h /sentry-issues`)
---

Look at the issues in Sentry, prioritize them, and open a PR for the ones you judge to be **fixable from code** and **relevant** — mainly things that degrade or affect the user's core functionality.

**There is no human in the loop. You are on your own.** I will review the PRs periodically, but I will never watch this loop run. Do not wait for confirmation at any point — act autonomously.

For each bug, **before opening a PR**:

## 1. Two parallel reviews

Launch two agents **in parallel** (in the same message):

1. **Architecture review**: code architecture, duplicated code, untested code, etc.
2. **Product & bug review**: possible user-facing bugs, product-level implementations that aren't right, or changes that could cause wrong behavior or new bugs.

## 2. Apply changes

Apply the changes recommended by these agents that you consider most important. Put **each one in a separate commit** with an appropriate explanation.

## 3. Estimate & ship

Estimate the **safety** of the fix and its **complexity**:

- If it's **not very complex** and you are **very confident** you're fixing the problem without creating new ones → create the PR and **enable auto-merge**.
- Otherwise → create the PR as a **draft**.

PR title and description in **English**.
