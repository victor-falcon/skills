---
name: qa-change
description: QA a change the way it's actually used — browser + recorded video for UI surfaces, or run the command / hit the endpoint / check DB & logs & tests for backend
argument-hint: "[what to focus on — defaults to your working changes]"
---

**Run the QA in a subagent pinned to `model: "sonnet"`.** QA is repetitive work and browser snapshots eat context — don't burn the expensive model on it. Brief the subagent with everything below plus the change under test; its report is the QA result. If you already *are* that subagent, just do the work.

QA the change. **By default** that's your working changes; `$ARGUMENTS` can narrow what to focus on.

**First decide if browser QA makes sense.** For a purely backend task or a terminal command there's no UI to test — skip the browser and the video entirely, and QA it the way it's actually used (run the command, hit the endpoint, check the DB/logs, run the relevant tests).

If the change **has a UI surface**, do real browser QA:

- Launch a browser (Playwright) and **really test the change in the running app**, not just unit tests.
- Confirm everything works as expected, including the relevant edge cases (e.g. cancel/confirm, empty states, mobile vs desktop where it applies).
- Verify the real effect (DB, UI, network) when it makes sense — don't stop at the visual layer.
- **Capture evidence** of what you tested and the result, and pick the format that explains it best (you can mix both):
  - **Video** (mp4/H.264) for flows, interactions, animations, responsive behaviour, or a bug that a still can't show.
  - **Before/after screenshots** (png) when the change is visual and one frame per state says it all.

  Save them outside the repo (your scratchpad dir) with descriptive filenames and report the exact paths — they get uploaded to the PR with `gh --attach`, never committed.
