# CardSense Benefit-Plan Implementation Plan
Last updated: 2026-04-04

## Current State

We completed an initial pass focused on benefit-plan switching cards, especially Cathay CUBE, and created a reusable review skill.

Delivered so far:

- CUBE plan descriptions updated in API `benefit-plans.json`
- Cathay `category -> planId` mapping corrected in extractor
- subcategory coverage expanded for richer CUBE scenarios
- extractor tests added for new mapping and subcategory behavior
- a reusable skill added under `cardsense-extractor/skills/cardsense-bank-promo-review`
- local Codex skill path linked to the repo-managed skill

## Key Product Decision

When plan tiers are unknown at runtime, recommendation should default conservatively.

Current recommendation:

- default to `Level 1`
- expose `Level 2 / Level 3` as explicit user state or future enhancement

## Main Gaps

### 1. Runtime benefit tier state

Current schemas do not cleanly represent:

- CUBE `Level 1 / 2 / 3`
- user-level unlock or qualification state
- month-end plan resolution logic for cards like Unicard

### 2. Merchant-slot / user-plan configuration

Current request/runtime model does not represent:

- Unicard `任意選` merchant picks
- paid/unlocked `UP選`
- other user-configured plan parameters

### 3. Rail / MCC / routing-sensitive rules

Current normalized promotion conditions are still too generic for some Richart-like rules:

- wallet/payment rail
- MCC-based recognition
- transaction country
- foreign-currency vs domestic settlement
- direct booking vs third-party booking

## Recommended Implementation Order

### Phase 1: Stabilize review workflow

Goal:

- make future bank reviews repeatable and low-friction

Tasks:

- use `cardsense-bank-promo-review` for all future switching-card reviews
- produce each future review using the skill template
- classify every new rule into `RECOMMENDABLE`, `CATALOG_ONLY`, or `FUTURE_SCOPE`

### Phase 2: Formalize runtime tier support

Goal:

- support cards whose reward depends on user qualification tier

Suggested changes:

- add request/runtime field such as `benefitPlanLevel` or `userBenefitTier`
- support conservative fallback when omitted
- update recommendation logic to apply tier-specific rates safely

Priority target:

- Cathay CUBE

### Phase 3: Formalize user-configured plan state

Goal:

- support cards whose plan outcome depends on user configuration

Suggested changes:

- add request/runtime support for selected merchant slots
- add request/runtime support for paid/unlocked plan state
- decide how to model month-end final plan resolution

Priority target:

- E.SUN Unicard

### Phase 4: Expand condition modeling

Goal:

- improve deterministic compatibility for routing-sensitive cards

Suggested additions:

- MCC-like condition types
- payment-rail / wallet condition types
- transaction-country / billing-currency condition types
- direct-merchant vs third-party-platform condition types

Priority target:

- Taishin Richart

## Near-Term Card Priorities

### Cathay CUBE

Next step:

- replace curated/approximate pieces with extractor-native output where possible
- decide whether to keep `Level 1` default in production until tier state exists

### E.SUN Unicard

Next step:

- perform a full structured review using the new skill template
- separate catalog compatibility from runtime recommendation compatibility

### Taishin Richart

Next step:

- perform a full structured review using the new skill template
- identify which plan rules are genuinely deterministic versus payment-recognition-sensitive

## Output Rules For Future Reviews

Each future benefit-plan review should answer:

1. Is the plan catalog compatible now?
2. Are the base promotions recommendable now?
3. What runtime state is missing?
4. What taxonomy or mapping changes are needed?
5. Can extractor-native output handle it, or is curated JSONL temporarily needed?

## Canonical Skill Location

Repo-managed skill:

- `cardsense-extractor/skills/cardsense-bank-promo-review`

Local installed skill path is linked to the repo version:

- `%USERPROFILE%\\.codex\\skills\\cardsense-bank-promo-review`

## Immediate Next Actions

1. Run a full `review-output-template` review for Unicard
2. Run a full `review-output-template` review for Richart
3. Design runtime tier field for CUBE
4. Decide whether to introduce plan-state fields before implementing Unicard recommendation logic
