---
name: product-review
description: Product review of a diff — side-effects and bugs (what could break) plus whether the change is correct and sensible for the user (requirement fit, UX, empty/error states, copy)
argument-hint: "[ref or PR to review — defaults to your working changes]"
---

Review the diff. **By default** that means your uncommitted changes plus the commits on this branch vs the main branch; if `$ARGUMENTS` names a ref/branch/PR, review that instead.

Cover both angles:

1. **Side-effects and bugs**: what could break or misbehave because of these changes (interactions, state, edge cases, regressions).
2. **Product**: does the change actually do the right thing for the user?
   - **Requirement fit** — does it deliver what the task/PRD/issue asked for? Anything missing or out of scope?
   - **UX** — do the flows make sense? Cancel/confirm, loading, mobile vs desktop where it applies.
   - **Empty / error states** — what the user sees when there's no data or something fails.
   - **Copy & accessibility** — clear, correct wording; basic a11y (labels, contrast, keyboard) where relevant.

Report the findings clearly. Don't apply changes unless I ask — if you want, end with a short list of which findings you'd act on and which you'd drop, and why.
