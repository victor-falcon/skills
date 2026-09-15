![skills](assets/header.png)

# skills

Agent skills that finish the job — review, ship, and watch CI so you don't babysit it.

Small, hackable skills for the unglamorous end of shipping: reviewing your own
diff, opening the PR, watching CI turn green, and keeping an eye on Sentry.
Built on [`npx skills`](https://github.com/vercel-labs/skills) — copy them into
your repo and make them yours.

| Check this video |  |
| --- | --- |
| [<img src="https://img.youtube.com/vi/y4F5K6yhxqY/mqdefault.jpg" width="240">](https://www.youtube.com/watch?v=y4F5K6yhxqY) | **[This AI Skill programs BETTER than your entire team](https://www.youtube.com/watch?v=y4F5K6yhxqY)**<br>How these skills work and how I use them day to day. This is video is mainly focused on the most important skill on this repo, /ship. |

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
- **delegate** — Hands a task off to a fresh agent in its own Herdr worktree:
  scouts the repo first, briefs it with what it found, and tells it to `/ship`.
- **qa-change** — QAs a change the way it's actually used: browser + recorded
  video for UI, or run the command / hit the endpoint / check logs for backend.

**Autonomous loops** — run these with `/loop`:

- **sentry-issues** — Triages Sentry issues and hands each fix worth making to a
  fresh agent in its own worktree off `origin/main`, which opens the PR
  (auto-merge when confident, draft when not). `/loop 2h /sentry-issues`
- **sentry-logs** — Scans Sentry logs on a timer and pings you when something
  looks wrong. Reports, never touches code. `/loop 1h /sentry-logs`

## Make them yours

These are starting points, not gospel. `npx skills add` copies each SKILL.md
into your repo — open it and rewrite anything that doesn't fit how you work.
