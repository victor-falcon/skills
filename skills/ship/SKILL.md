---
name: ship
description: Implement a task and finalize it (two parallel reviews, QA appropriate to the change — browser + video for UI, otherwise the way it's actually used — a PR, and watching CI until green)
argument-hint: <task description>
---

Your task: $ARGUMENTS

Implement it. **Once the implementation is ready, you MUST run this wrap-up in order:**

## 1. Two parallel reviews

Launch two agents **in parallel** (in the same message) over the diff:

1. **Technical review**: code architecture, bad patterns, consistency with existing conventions and components, and the Fowler code smells below. Match each smell against the diff — name it and quote the hunk — as judgement-call heuristics, not hard rules, and skip anything tooling already enforces:
   - **Mysterious Name** — a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
   - **Duplicated Code** — the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
   - **Feature Envy** — a method that reaches into another object's data more than its own. → move the method onto the data it envies.
   - **Data Clumps** — the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
   - **Primitive Obsession** — a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
   - **Repeated Switches** — the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
   - **Shotgun Surgery** — one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
   - **Divergent Change** — one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
   - **Speculative Generality** — abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
   - **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
   - **Middle Man** — a class or function that mostly just delegates onward. → cut it, call the real target direct.
   - **Refused Bequest** — a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.
2. **Side-effects and bugs**: what could break or misbehave because of these changes (interactions, state, edge cases, regressions).

Apply the changes you consider reasonable from their findings — use judgment, not every finding warrants a change — and briefly explain what you apply and what you drop, and why.

## 2. QA

**First decide if browser QA makes sense.** For a purely backend task or a terminal command there's no UI to test — skip the browser and the video entirely, and QA it the way it's actually used (run the command, hit the endpoint, check the DB/logs, run the relevant tests).

If the change **has a UI surface**, do real browser QA before creating the PR:

- Launch a browser (Playwright) and **really test the change in the running app**, not just unit tests.
- Confirm everything works as expected, including the relevant edge cases (e.g. cancel/confirm, empty states, mobile vs desktop where it applies).
- Verify the real effect (DB, UI, network) when it makes sense — don't stop at the visual layer.
- **Record a video** demonstrating what you tested and the result. Save it to `~/Downloads/` in a format that can be dragged into GitHub (mp4/H.264).

## 3. PR

- Create the PR (title and description **in English**).
- **Only if you recorded a video:** include a **Demo** section with a clearly marked **placeholder** so I can attach the video manually, and tell me the exact path of the generated video so I can drag it in.

## 4. Watch CI

After the PR is created, **stay watching the CI until every required check is green** — don't stop at "PR created". Poll the PR's checks (e.g. `gh pr checks --watch`) until all **required** checks have passed.

- If a required check fails, investigate: fix real failures caused by the change and push, or retry flakes. Then keep watching.
- Only report the task as done once all required checks are green (skipped/optional non-required checks are fine).
