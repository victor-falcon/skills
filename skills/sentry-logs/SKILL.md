---
name: sentry-logs
description: Autonomous loop — every hour, scan Sentry logs for errors or wrong behavior and notify me with the relevant details
argument-hint: (run with /loop, e.g. `/loop 2h /sentry-logs`)
---

Every hour, review the Sentry logs looking for possible errors or wrong behavior.

IMPORTANT, check logs, not issues.

If you find something, **notify me** of what's happening with the relevant details: what the error is, where it happens, how often, when it started, and anything else useful to understand it. Don't fix anything — just report.

If nothing noteworthy comes up, stay quiet and check again next hour.
