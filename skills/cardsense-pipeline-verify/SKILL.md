---
name: cardsense-pipeline-verify
description: End-to-end verification from extractor output through SQLite import, API smoke test, and optional Supabase sync — used after data changes to confirm the full CardSense pipeline produces correct results.
---

# CardSense Pipeline Verify

Use this skill after any data-affecting change (extractor heuristic update, new bank onboarding, schema migration, benefit-plan mapping change) to verify the full pipeline from extraction to API response.

## When to use

- After running `refresh_and_deploy.py` (full or bank-scoped)
- After modifying `promotion_rules.py`, `benefit_plans.py`, or any `*_real.py` extractor
- After schema changes in `cardsense-contracts`
- Before syncing to Supabase (production)
- After importing new JSONL into SQLite

## Pre-flight checks

Before starting verification, confirm:

1. Which banks/cards were affected by the change
2. Whether the change is data-only or also touches API/frontend logic
3. Expected direction of change (more promos? fewer? different categories?)

## Verification steps

### Step 1: Extractor tests

```bash
cd cardsense-extractor
uv run pytest
```

All existing tests must pass. If heuristic changes were made, check that fixtures for unrelated banks still pass.

### Step 2: SQLite row validation

After import, verify row counts and distribution for affected cards:

```sql
-- Total promotions per bank
SELECT bank_code, COUNT(*) FROM promotion_current GROUP BY bank_code;

-- Per-card breakdown for affected bank
SELECT card_code, COUNT(*) as promo_count
FROM promotion_current
WHERE bank_code = '{BANK}'
GROUP BY card_code
ORDER BY promo_count DESC;

-- Category distribution for affected card
SELECT category, subcategory, COUNT(*) as cnt
FROM promotion_current
WHERE card_code = '{CARD_CODE}'
GROUP BY category, subcategory
ORDER BY category, subcategory;

-- Spot-check plan assignment (benefit-plan cards only)
SELECT promo_id, category, subcategory, plan_id, cashback_value
FROM promotion_current
WHERE card_code = '{CARD_CODE}' AND plan_id IS NOT NULL
ORDER BY category;

-- Check for anomalies: cashback > 20%
SELECT promo_id, card_code, cashback_value, reward_type
FROM promotion_current
WHERE reward_type = 'PERCENT' AND cashback_value > 20;
```

Compare counts against previous run. Flag unexpected drops or spikes.

### Step 3: API smoke test

Start API in SQLite mode:

```bash
cd cardsense-api
mvn spring-boot:run \
  -Dspring-boot.run.jvmArguments="\
    -Dcardsense.repository.mode=sqlite \
    -Dcardsense.repository.sqlite.path={path-to-cardsense.db}"
```

Verify endpoints:

| Endpoint | Check |
|---|---|
| `GET /health` | returns `UP`, correct repository mode |
| `GET /v1/banks` | affected bank present |
| `GET /v1/cards?bank={BANK}&scope=RECOMMENDABLE` | card count matches expectation |
| `GET /v1/cards/{cardCode}/promotions` | promo list non-empty, categories look correct |
| `GET /v1/cards/{cardCode}/plans` | plans present (benefit-plan cards only) |
| `POST /v1/recommendations/card` | recommendation returns results for affected category |

For recommendation, use a representative scenario:

```json
{
  "amount": 1000,
  "category": "DINING",
  "channel": "PHYSICAL"
}
```

Check that:
- affected card appears in ranking (if it should)
- effective return is reasonable (not 0, not > 20%)
- `activePlan` is present for benefit-plan cards
- disclaimer field is non-empty

### Step 4: API tests

```bash
cd cardsense-api
mvn test
```

If API runtime logic changed, pay attention to `DecisionEngineTest` and integration tests.

### Step 5: Frontend build (if applicable)

Only needed if request/response shape changed or new UI elements were added.

```bash
cd cardsense-web
npm run build
```

### Step 6: Supabase sync decision

Before syncing to production, confirm:

- [ ] All above steps pass
- [ ] Sync scope is correct (full-table / bank-scoped / card-scoped)
- [ ] Non-target banks/cards will not be affected

If scoped sync:

```bash
cd cardsense-extractor
uv run python jobs/refresh_and_deploy.py --banks {BANK} --db data/cardsense.db
```

If full sync, ensure all banks have been re-extracted and validated first.

## Red flags to report

- Row count dropped > 10% for any bank without intentional cleanup
- Any `RECOMMENDABLE` promo with cashback > 20%
- `plan_id` is NULL for a known benefit-plan card
- API returns empty recommendation for a scenario that previously had results
- `conditions_json` contains unrecognized condition types

## Post-verification

After successful verification:

1. Record the verification result (pass/fail + notes) for the PR or agent log
2. If Supabase sync was done, verify production API returns updated data
3. If frontend was affected, check the deployed Vercel preview
4. Run `cardsense-workspace-completion` before ending the task; use `fleet-dashboard-closeout` for dashboard-specific details so `CardSense-Status.md`, `dashboard/data/*.json`, release evidence, and workspace generated assets stay current without a separate reminder
