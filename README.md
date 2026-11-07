![skills](assets/header.png)

# skills

Agent skills that finish the job — review, ship, and watch CI so you don't babysit it.

Small, hackable skills for the unglamorous end of shipping: reviewing your own
diff, opening the PR, watching CI turn green, and keeping an eye on Sentry.
Built on [`npx skills`](https://github.com/vercel-labs/skills) — copy them into
your repo and make them yours.

## Quickstart

```bash
npx skills add victor-falcon/skills
```

Bam — installed. Or pick one:

```bash
npx skills add victor-falcon/skills --skill ship
```

## The skills

**Slash commands** — you run these:

- **ship** — Implement a task, then finalize it properly: two parallel reviews,
  real QA (browser + video for UI), a PR, and it watches CI until every required
  check is green.
- **pr-ci** — Babysits your PR's CI so you don't: fixes failures caused by your
  diff, retries flakes, and warns when it's `main` that's broken, not you.
- **technical-review** — Reviews a diff for architecture, bad patterns, and
  Fowler code smells. The code half of `ship`, on its own.
- **product-review** — Reviews a diff for side-effects and bugs plus whether it's
  actually right for the user (requirement fit, UX, empty/error states, copy).
- **delegate** — Hands a task off to a fresh agent in its own worktree ([Herdr](https://herdr.dev) or [Rex](https://superlogical.com)):
  scouts the repo first, briefs it with what it found, and tells it to `/ship`.
- **qa-change** — QAs a change the way it's actually used: browser + recorded
  video for UI, or run the command / hit the endpoint / check logs for backend.
- **orchestrate** — Give it a goal and walk away: it splits it into PRs,
  delegates each to its own worktree agent, steers them from one place, merges
  what's safe, cleans up the worktrees, and keeps going until the goal is met.
- **on-new-tab** — Launches one thing in a new tab of the session you're in: a
  fresh Claude Code agent with its own prompt, no worktree or PR. Set
  `MUX_CLAUDE` to start it with your own wrapper (`MUX_CLAUDE=clc`).

> [!NOTE]
> `delegate`, `orchestrate` and `on-new-tab` only work inside [Herdr](https://herdr.dev) or
> [Rex](https://superlogical.com), and `sentry-issues` uses them to hand off its
> fixes. See [Requirements](#requirements-for-delegate-orchestrate-and-on-new-tab). The
> rest work in any terminal.

**Autonomous loops** — run these with `/loop`:

- **sentry-issues** — Triages Sentry issues and hands each fix worth making to a
  fresh agent in its own worktree off `origin/main`, which opens the PR
  (auto-merge when confident, draft when not). `/loop 2h /sentry-issues`
- **sentry-logs** — Scans Sentry logs on a timer and pings you when something
  looks wrong. Reports, never touches code. `/loop 1h /sentry-logs`

## Requirements for delegate, orchestrate and on-new-tab

`delegate` and `orchestrate` run agents in their own worktrees through a
terminal multiplexer, and `on-new-tab` opens agents in new tabs, so they need a
few things on your machine:

- [Herdr](https://herdr.dev) or [Rex](https://superlogical.com) — start your
  Claude Code session inside one. No other multiplexer (tmux, Zellij, …) is
  supported. `sentry-issues` hands its fixes to `delegate`, so it needs one too;
  without it, it falls back to fixing the issue itself and running `ship`.
- `git`, `jq`, `shasum` and `gh` (logged in; it checks PR state to clean up worktrees)
- `claude` on your `PATH`: each worktree agent is a new Claude Code session

Herdr here is the Herdr app on herdr-core: the helper drives it with `hc` and
`herdr-app`, so both must be on your `PATH`. On a remote machine whose core a
Herdr window elsewhere shows (a server, a WSL box), only `hc` is needed: names
go straight into that core's layout, and splits fall back to tabs. The old standalone `herdr` CLI is
no longer supported.

The worktrees go in `~/.worktrees/<repo>/<branch>`.

The multiplexer helper they all source ships with the skill, in
`skills/delegate/scripts/multiplexer.sh`. `orchestrate` and `on-new-tab` reuse
delegate's copy, so install `delegate` alongside them.

## Make them yours

These are starting points, not gospel. `npx skills add` copies each skill folder
into your repo — open it and rewrite anything that doesn't fit how you work.
