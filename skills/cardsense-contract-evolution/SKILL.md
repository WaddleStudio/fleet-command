---
name: cardsense-contract-evolution
description: Safely evolve CardSense shared contracts (JSON Schema, enums, DTOs) across all four repos — contracts, extractor, API, and web — with backward-compatibility checks and cross-repo validation.
---

# CardSense Contract Evolution

Use this skill when a change to `cardsense-contracts` (JSON Schema, enum, DTO) is needed and must propagate safely across the extractor, API, and frontend.

## When to use

- Adding a new field to `promotion-normalized.schema.json`
- Adding a new enum value (category, subcategory, channel, condition type, etc.)
- Changing recommendation request/response schema
- Adding or modifying `benefit-plan.schema.json`
- Updating taxonomy definitions

## Core principles

- **Contracts are the source of truth** — all repos must conform to the schema
- **Additive changes are safe** — new optional fields, new enum values
- **Breaking changes require coordination** — removing fields, changing types, renaming
- **Validate in dependency order** — contracts → extractor → API → web

## Impact assessment

Before making changes, assess which repos are affected:

| Change type | contracts | extractor | API | web |
|---|---|---|---|---|
| New optional field | schema | models + output | DTO + response | types + UI |
| New enum value | taxonomy | rules + signals | enum class | constants + UI |
| New required field | schema | models + output | DTO + validation | types + UI |
| Field rename | schema | models + rules | DTO + mapping | types + UI |
| Field removal | schema | models cleanup | DTO cleanup | types cleanup |

## Evolution steps

### Step 1: Update contracts

```
cd cardsense-contracts
```

1. Edit the relevant schema file under `promotion/` or `recommendation/`
2. If adding an enum value, update the corresponding taxonomy file under `taxonomy/`
3. Update example files (`valid/`, `invalid/`) to cover the new case
4. Validate examples against updated schema

### Step 2: Update extractor

```
cd cardsense-extractor
```

1. Update `models/promotion.py` — Pydantic model fields, enum classes
2. Update `extractor/promotion_rules.py` — if new category/subcategory/condition signals needed
3. Update `extractor/normalize.py` — if field mapping changed
4. Update `extractor/benefit_plans.py` — if benefit-plan schema changed
5. Run tests:

```bash
uv run pytest
```

6. If the change affects output shape, re-run affected bank extractors and verify JSONL output

### Step 3: Update API

```
cd cardsense-api
```

1. Update domain classes under `domain/` — entity fields, enums
2. Update repository mapping — `SqlitePromotionRepository` and `SupabasePromotionRepository` column mapping
3. Update service logic — `DecisionEngine` if filtering/ranking behavior changes
4. Update controller response DTOs if API response shape changes
5. Run tests:

```bash
mvn test
```

6. Pay special attention to `DecisionEngineTest` and integration tests

### Step 4: Update frontend

```
cd cardsense-web
```

1. Update TypeScript types/interfaces that mirror the contract
2. Update API client response parsing
3. Update UI components that display new/changed fields
4. Build check:

```bash
npm run build
```

### Step 5: Cross-repo validation

Use the `cardsense-pipeline-verify` skill to run end-to-end validation:

1. Re-extract at least one bank to produce JSONL with new schema
2. Import to SQLite
3. Start API and verify new fields appear in responses
4. Verify frontend renders correctly
5. Finish with `cardsense-workspace-completion`; use `fleet-dashboard-closeout` for dashboard-specific details so health, roadmap, release evidence, and generated workspace context reflect the contract change

## Backward compatibility checklist

For **additive** changes (safe):
- [ ] New field has a default value or is optional
- [ ] Existing JSONL files still validate against new schema
- [ ] API handles missing field gracefully (old data in DB)
- [ ] Frontend handles missing field gracefully (API may return old data)

For **breaking** changes (requires coordination):
- [ ] All repos updated in the same release cycle
- [ ] SQLite and Supabase data migrated (or re-extracted)
- [ ] Old API responses no longer served (or versioned endpoint)
- [ ] Frontend deployed after API

## Common patterns

### Adding a new subcategory

1. `cardsense-contracts/taxonomy/subcategory-taxonomy.json` — add subcategory entry with `category` and `description`
2. `cardsense-extractor/extractor/promotion_rules.py` — add `SUBCATEGORY_SIGNALS` entry
3. `cardsense-extractor/models/promotion.py` — add to `SubcategoryEnum`
4. `cardsense-api` — `Subcategory` enum class (auto-recognized from DB string)
5. `cardsense-web/src/lib/taxonomy.ts` — add Chinese label to `SUBCATEGORY_LABEL_MAP`; if the subcategory needs a frontend category override (e.g., contracts says OVERSEAS but frontend shows it under ONLINE), add to `FRONTEND_CATEGORY_OVERRIDES`

> **Note:** `SUBCATEGORIES` and `MERCHANT_SUGGESTIONS` in the frontend are auto-derived from contracts JSON via `@contracts` Vite alias. No need to manually edit `enums.ts` for these.

### Adding a new merchant

1. `cardsense-contracts/taxonomy/merchant-registry.json` — add entry with `code`, `label`, `category`, `subcategory`, `aliases`
2. Frontend picks it up automatically on next build (Vercel redeploy or local dev server restart)
3. No frontend code changes needed — `MERCHANT_SUGGESTIONS` is derived from the registry

### Adding a new condition type

1. `cardsense-contracts/promotion/promotion-normalized.schema.json` — add to condition type enum
2. `cardsense-extractor/extractor/promotion_rules.py` — add detection signals
3. `cardsense-extractor/models/promotion.py` — add to condition type enum
4. `cardsense-api/domain/` — add condition type enum value
5. `cardsense-api/service/DecisionEngine.java` — add matching logic in `isEligible()`
6. `cardsense-web` — add condition badge/display

### Adding a new field to promotion

1. `cardsense-contracts/promotion/promotion-normalized.schema.json` — add field definition
2. `cardsense-extractor/models/promotion.py` — add Pydantic field (with default)
3. `cardsense-extractor/extractor/normalize.py` — populate field during normalization
4. `cardsense-extractor/sql/cardsense_schema.sql` — add column (with DEFAULT for migration)
5. `cardsense-api/domain/` — add entity field
6. `cardsense-api/repository/` — add column mapping in both SQLite and Supabase repos
7. `cardsense-web` — update TypeScript type and display component
