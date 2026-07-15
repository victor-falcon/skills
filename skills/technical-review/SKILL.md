---
name: technical-review
description: Technical review of a diff — code architecture, bad patterns, consistency with existing conventions and components, and Fowler code smells
argument-hint: "[ref or PR to review — defaults to your working changes]"
---

Review the diff. **By default** that means your uncommitted changes plus the commits on this branch vs the main branch; if `$ARGUMENTS` names a ref/branch/PR, review that instead.

Focus on code architecture, bad patterns, consistency with existing conventions and components, and the Fowler code smells below. Match each smell against the diff — name it and quote the hunk — as judgement-call heuristics, not hard rules, and skip anything tooling already enforces:

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

Report the findings clearly. Don't apply changes unless I ask — if you want, end with a short list of which findings you'd act on and which you'd drop, and why.
