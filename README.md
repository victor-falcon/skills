# falcon-skills

Agent skills for coding workflows, installable with [`npx skills`](https://github.com/vercel-labs/skills).

## Install

```bash
# all of them
npx skills add victor-falcon/falcon-skills

# or pick specific ones
npx skills add victor-falcon/falcon-skills --skill ship --skill pr-ci
```

## Skills

| Skill | What it does |
|-------|--------------|
| **ship** | Implement a task and finalize it: two parallel reviews, QA appropriate to the change (browser + video for UI, otherwise the way it's actually used), a PR, and watching CI until every required check is green. |
| **pr-ci** | Watch the current PR's CI, fix failures caused by the diff, retry flakes, and warn on unrelated main-branch breakage. |
| **sentry-issues** | Autonomous loop — triage Sentry issues, fix the code-fixable & user-relevant ones, and open PRs (auto-merge when confident, draft otherwise). Run with `/loop`. |
| **sentry-logs** | Autonomous loop — periodically scan Sentry logs for errors or wrong behavior and report them (no fixes). Run with `/loop`. |
