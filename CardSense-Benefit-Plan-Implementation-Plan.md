# CardSense Benefit-Plan Implementation Plan
Last updated: 2026-04-05

## Current State

The first real end-to-end benefit-plan implementation is now in place for `CATHAY_CUBE`.

Completed:

- API `benefit-plans.json` updated with cleaner CUBE plan descriptions
- extractor `category -> planId` mapping corrected for CUBE
- canonical `subcategory` taxonomy added in `cardsense-contracts`
- CUBE extractor upgraded from coarse plan promos to merchant-aware cluster promos
- CUBE runtime tier handling added to API recommendation logic
- CUBE-only scoped Supabase sync implemented
- frontend recommendation UI updated with merchant input, CUBE tier selector, and clearer condition display
- reusable review skill updated to reflect the current implementation pattern

## Proven Pattern

The current best-known implementation pattern for switching cards is:

1. keep top-level `category` stable
2. add meaningful `subcategory`
3. model stable clusters as promotions
4. attach merchant-level conditions inside those cluster promos
5. keep runtime-only state explicit in request payload
6. roll out with scoped sync when only one card is production-ready

For `CATHAY_CUBE`, that means:

- `AI_TOOL` promo with merchants like `CHATGPT`, `CLAUDE`
- `SUPERMARKET` promo with merchants like `PXMART`, `CARREFOUR`
- `AIRLINE` promo with merchants like `CHINA_AIRLINES`, `EVA_AIR`
- runtime tier defaulting conservatively to `LEVEL_1`

## Current Product Decisions

### Tier default policy

When tier state is unknown at runtime, recommendation should default conservatively.

Current policy:

- `CATHAY_CUBE` defaults to `LEVEL_1`
- `LEVEL_2` and `LEVEL_3` require explicit request/runtime state

### Merchant modeling policy

Prefer:

- cluster promo plus merchant conditions

Do not immediately create one promo row per merchant unless the bank benefit truly behaves that way.

### Rollout policy

If only one card is ready, prefer scoped rollout.

Current working example:

- `--sync-bank CATHAY --sync-card CATHAY_CUBE`

## What Is Now Complete for CUBE

### Extractor

- plan-aware extraction
- subcategory-aware extraction
- merchant-aware conditions
- non-plan promo tagging guardrails

### API runtime

- plan-aware recommendation
- merchant-aware condition matching
- conservative tier fallback
- explicit `benefitPlanTiers` request support

### Frontend

- `merchantName` input
- merchant suggestion chips
- CUBE tier selector
- clearer result condition badges
- active plan display remains available

### Data pipeline

- SQLite re-import validated
- CUBE-only Supabase sync validated
- no cross-card contamination during scoped rollout

## Remaining Gaps

### 1. Runtime plan-state beyond tiers

Still missing for future cards:

- month-end final plan state
- merchant-slot selection
- unlock or subscription state

Priority card:

- `ESUN_UNICARD`

### 2. Rail and routing-sensitive rules

Still not fully modeled:

- wallet or payment rail
- MCC-like semantics
- transaction country
- billing currency
- direct merchant vs third-party route

Priority card:

- `TAISHIN_RICHART`

### 3. Frontend product refinement

Still worth improving:

- smarter merchant suggestions by selected category and subcategory
- better explanation copy for tier assumptions
- richer condition grouping in result cards

## Recommended Implementation Order

### Phase 1: Keep CUBE stable

- keep CUBE extractor-native output as the baseline
- use CUBE as the reference implementation for switching cards
- avoid reintroducing curated-only shortcuts where extractor-native output now exists

### Phase 2: Structured Unicard review

- use the review skill template
- separate catalog compatibility from runtime recommendation compatibility
- identify which parts require merchant-slot or month-end state

### Phase 3: Structured Richart review

- use the review skill template
- identify which parts are safe cluster promos
- isolate rail- or MCC-sensitive rules that should remain `CATALOG_ONLY`

### Phase 4: Runtime-state schema design

- decide whether to add general plan-state request fields
- model merchant-slot configuration
- model month-end plan resolution when needed

## Output Rules For Future Reviews

Each future switching-card review should answer:

1. Is the plan catalog compatible now?
2. Are the base promotions recommendable now?
3. Are merchant-aware cluster promos enough?
4. What runtime state is missing?
5. What taxonomy, mapping, or frontend changes are needed?
6. Is a scoped rollout required?

## Canonical References

- Skill:
  - `cardsense-extractor/skills/cardsense-bank-promo-review`
- Workflow doc:
  - `fleet-command/CardSense-Bank-Promo-Review-Workflow.md`
