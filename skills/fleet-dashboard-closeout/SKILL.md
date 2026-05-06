---
name: fleet-dashboard-closeout
description: Closeout workflow for CardSense workspace tasks. Use at the end of every task to decide whether the fleet-command dashboard, status docs, release evidence, agent log, and generated workspace assets need updates, then verify the static dashboard.
---

# Fleet Dashboard Closeout

Use this skill before ending any CardSense workspace task. The dashboard is the control-plane view for repo health, roadmap progress, open work, latest checks, and release evidence. Do not wait for the user to ask for dashboard maintenance separately.

## When to use

- At the end of every CardSense workspace task, after the task-specific verification has run.
- After any change in `cardsense-web`, `cardsense-api`, `cardsense-extractor`, `cardsense-contracts`, or `fleet-command`.
- After opening, merging, or verifying PRs that change product capability, data coverage, API behavior, frontend UX, ops/security posture, or release evidence.
- After changing workspace rules, generated context, AGENTS instructions, shared skills, or dashboard files.

## Decide what changed

Inspect the diff and task result, then classify the closeout:

- `no_dashboard_change`: only local exploration or a tiny implementation detail that does not change status, roadmap, checks, release evidence, or workspace rules.
- `status_update`: current capability, roadmap, open follow-ups, or project health changed.
- `release_evidence`: a completed repair, feature, PR batch, production smoke, or verification run should be added to release history.
- `open_queue_update`: a new blocker/follow-up exists, or an existing action queue item changed status.
- `workspace_rule_update`: AGENTS, manifest, generated context, or shared skills changed.

If unsure, prefer a small dashboard/status update over letting the control plane drift.

## Update targets

Use the smallest set of files that match the classification:

- `CardSense-Status.md`: product direction, current capability, roadmap, open follow-ups, and evidence links.
- `dashboard/data/checks.json`: current repo health, latest production or engine smoke, and open action queue.
- `dashboard/data/roadmap.json`: 0-30 / 31-60 / 61-90 progress and item status.
- `dashboard/data/releases.json`: completed release/repair evidence and PR links. Keep solved work here, not in the main action queue.
- `dashboard/data/projects.json`: repo health, focus, stage, commands, and links.
- `agent-log/YYYY-MM-DD.md`: material agent work, decisions, verification, PRs, or blockers.
- `workspace/workspace.manifest.json`: completion flow, repo map, policies, or generated context rules.

Rules:

- Keep `dashboard/data/checks.json` focused on current health and open work.
- Move completed repairs to `dashboard/data/releases.json`.
- Update `updatedAt` fields when the data file changes.
- Link evidence folders, PRs, or plan docs instead of pasting long verification logs.
- Do not invent PR numbers, production results, or passing checks.

## Verify

Run the dashboard data tests:

```bash
cd fleet-command
uv run python -m unittest tests.test_dashboard_data
```

If the manifest or generated context changed, render or check workspace assets:

```bash
cd fleet-command
uv run python scripts/render_workspace_assets.py
uv run python scripts/render_workspace_assets.py --check
uv run python -m unittest tests.test_render_workspace_assets
```

## Browser smoke

When dashboard files changed, serve the dashboard over HTTP and verify it with Chrome through gstack/browser:

```bash
cd fleet-command/dashboard
uv run python -m http.server 5177
```

Then use gstack/browser verification:

```bash
$B goto http://127.0.0.1:5177
$B text
$B console --errors
$B snapshot -i
$B screenshot --viewport reviews/dashboard-closeout.png
```

Expected:

- Page title is `Fleet Command Dashboard`.
- Workspace, Overall Status, Last Production Smoke, Repos, Roadmap, Open Work, and Latest Signals render.
- `loadError` is hidden.
- Browser console has no errors.
- JSON files load over HTTP.

Use installed Google Chrome for browser verification. If gstack cannot run from the current shell, use Chrome headless directly and report the fallback. Do not use a bundled browser unless Chrome is unavailable.

If browser automation is unavailable, report the blocker and keep the command/test evidence.

## Git and PR closeout

Before ending:

1. Confirm the current repo branch. Do not finish implementation work on `main` or `master` unless the user explicitly asked for that.
2. If work happened on the wrong branch, create or switch to the correct task branch before committing, preserving the working tree.
3. Review `git status --short` and `git diff`.
4. Commit the verified changes in the repo that owns them.
5. Push the branch and create or update the PR when remote access is available.
6. If push or PR creation is unavailable, report the exact blocker and leave the branch/commit ready.

## Closeout report

End the task with:

- Dashboard classification.
- Files updated or confirmation that no dashboard change was needed.
- Verification commands and results.
- Branch, commit, push, and PR status.
- Any remaining dashboard drift or follow-up.
