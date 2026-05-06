---
name: cardsense-dev-checks
description: Use during CardSense development when a task needs quick CLI/API verification before final closeout. Covers repo test selection, local/prod API smoke checks with curl, frontend/browser smoke with Chrome/gstack, dashboard data checks, GitHub PR/CI inspection with gh, and Vercel deployment inspection when available.
---

# CardSense Dev Checks

Use this skill during development, before the final `cardsense-workspace-completion` closeout. Prefer CLI/API checks when they can answer the question directly.

## Defaults

- Python commands: `uv run python`.
- Browser checks: installed Google Chrome through gstack/browser. If gstack is silent or unavailable, use Chrome headless directly and report the fallback.
- API checks: `curl` first for simple HTTP assertions.
- GitHub checks: `gh` for PRs, checks, and workflow state.
- Do not use production-mutating commands unless the user explicitly asked for them.

## Pick The Smallest Useful Check

Use the narrowest check that can confirm or reject the current hypothesis:

- Contracts/schema touched: validate schema examples or run targeted `rg`/JSON checks, then broader repo checks if needed.
- Extractor/data touched: `uv run pytest` or targeted tests, plus SQLite/API smoke when output changed.
- API logic touched: targeted Maven tests first, then `mvn test`.
- Web UI touched: `npm run test:unit` for logic, `npm run build` for integration, browser smoke for routes.
- Dashboard/workflow touched: dashboard data tests and workspace renderer checks.
- PR/deploy state questioned: `gh pr view`, `gh pr checks`, `gh run list`, or Vercel CLI/API if configured.

## Repo Commands

From workspace root:

```bash
cd fleet-command
uv run python -m unittest tests.test_dashboard_data
uv run python -m unittest tests.test_render_workspace_assets
uv run python scripts/render_workspace_assets.py --check
```

```bash
cd cardsense-extractor
uv run pytest
uv run pytest tests/test_payment_classification.py
uv run python jobs/refresh_and_deploy.py --help
```

```bash
cd cardsense-api
mvn test
mvn -Dtest=DecisionEngineTest test
mvn -Dtest=RewardCalculatorTest test
```

```bash
cd cardsense-web
npm run test:unit
npm run build
npm run lint
```

## Local API Smoke

Start API in the mode needed for the task, then check:

```bash
curl -s http://localhost:8080/health
curl -s "http://localhost:8080/v1/banks"
curl -s "http://localhost:8080/v1/cards?scope=RECOMMENDABLE"
```

Recommendation smoke:

```bash
curl -s -X POST http://localhost:8080/v1/recommendations/card \
  -H "Content-Type: application/json" \
  -d "{\"amount\":1000,\"category\":\"DINING\",\"channel\":\"PHYSICAL\"}"
```

For SQLite mode:

```bash
cd cardsense-api
mvn spring-boot:run -Dspring-boot.run.jvmArguments="-Dcardsense.repository.mode=sqlite -Dcardsense.repository.sqlite.path=../cardsense-extractor/data/cardsense.db"
```

## Production API Read-Only Smoke

Use only read-only production checks unless explicitly asked otherwise:

```bash
curl -s https://cardsense-api-production.up.railway.app/health
curl -s "https://cardsense-api-production.up.railway.app/v1/cards?scope=RECOMMENDABLE"
```

If the production base URL differs, discover it from project docs or deployment settings and report the URL used.

## Browser Smoke

For local web:

```bash
cd cardsense-web
npm run dev
```

Then use Chrome/gstack:

```bash
$B goto http://127.0.0.1:5173
$B console --errors
$B snapshot -i
$B screenshot --viewport ../fleet-command/reviews/dev-check-web.png
```

Chrome headless fallback:

```bash
"C:\Program Files\Google\Chrome\Application\chrome.exe" --headless=new --disable-gpu --window-size=1440,1200 --screenshot=../fleet-command/reviews/dev-check-web.png http://127.0.0.1:5173
```

For deployed web:

```bash
$B goto https://cardsense-web.vercel.app
$B console --errors
$B snapshot -i
```

## GitHub And CI

Inspect PR state:

```bash
gh pr status
gh pr view --json url,state,headRefName,baseRefName,title,mergeStateStatus
gh pr checks
```

Inspect recent runs:

```bash
gh run list --limit 10
gh run view --log-failed
```

Use these for visibility. Do not rerun, cancel, merge, or close PRs unless the user asked for that operation.

## Vercel

When Vercel CLI is linked and the question is deployment/readiness:

```bash
vercel ls
vercel inspect <deployment-url>
vercel logs <deployment-url>
```

If Vercel CLI is unavailable or the repo is not linked, report that and use the live URL plus browser/API smoke instead.

## Report

Report:

- Check goal.
- Commands run and pass/fail.
- URL or environment checked.
- Evidence path when screenshots/logs were produced.
- Recommended next check, only if the result is still ambiguous.
