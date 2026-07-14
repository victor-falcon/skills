---
name: pr-ci
description: Watch current PR CI, fix related failures, retry flakes, warn on main-branch issues
argument-hint: "[PR-id]"
---
Check CI for PR `$ARGUMENTS` (if empty, use current branch's PR via `gh pr view --json number -q .number`).

Steps:
1. Run `gh pr checks $ARGUMENTS --watch --fail-fast` (omit arg if empty). Stream output.
2. On failure, identify failing job(s). Fetch logs with `gh run view <run-id> --log-failed` or `gh run view --job <job-id> --log-failed`.
3. Classify root cause:
   - **Related to PR changes**: code/test/lint/type errors caused by this PR's diff. → Fix autonomously: reproduce locally if possible, patch, commit, push, then re-run watch. No confirmation needed.
   - **Flaky** (timeout, network blip, transient infra error, known-flaky test, no logical link to diff): re-run with `gh run rerun <run-id> --failed`. Then re-watch.
   - **Unrelated / main-branch breakage** (failure exists on `main` independent of PR diff): do NOT fix. Warn user clearly: state which job, why it's unrelated, suggest rebasing on fixed main or filing an issue.
4. Loop watch → classify → act autonomously until all checks green, unrelated breakage found, or fix attempts exhausted.
5. Report final status concisely.

Rules:
- DO NOT FORCE PUSH, unless you're doing a rebase from the orgin branch. NEVER DO A MERGE.
- Push fix commits without confirmation when failure is clearly related to PR diff.
- Cite log evidence when classifying.
- Use clear commit messages (e.g. `fix: <ci failure summary>`).
