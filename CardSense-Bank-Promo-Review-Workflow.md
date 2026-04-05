# CardSense Bank Promo Review Workflow
Last updated: 2026-04-05

## Purpose

This document captures the cross-repo workflow for reviewing a bank rewards page and turning it into safe CardSense changes.

It complements the repo-managed skill:

- `cardsense-extractor/skills/cardsense-bank-promo-review`

## Scope

Use this workflow when the task involves:

- reviewing a bank credit-card rewards page
- analyzing a benefit-plan switching card
- updating contracts, extractor logic, API runtime logic, frontend inputs, or rollout scope

## Review Flow

### 1. Source review

- prioritize official bank pages and PDFs
- use secondary sources only as research hints
- separate confirmed facts from inferred or secondary-only facts

### 2. Split the content

Split the source into:

- plan metadata
- stable base rewards
- campaigns and coupons
- runtime-state requirements

### 3. Judge compatibility

Decide whether the card is:

- `fully compatible`
- `compatible with approximation`
- `catalog-only until schema/runtime changes`

### 4. Choose the modeling pattern

Prefer this order:

1. stable `category`
2. richer `subcategory`
3. cluster promo
4. merchant-level conditions inside the cluster

Avoid one-promo-per-merchant unless truly required.

### 5. Decide runtime treatment

If reward depends on runtime state:

- use conservative fallback when unknown
- add explicit request/runtime fields when needed
- separate `data complete` from `runtime complete`

### 6. Implement in repo order

1. `cardsense-contracts` if taxonomy or schemas need updates
2. `cardsense-api` plan metadata if plan catalog changed
3. `cardsense-extractor` mapping, taxonomy signals, card parser, and tests
4. `cardsense-api` runtime logic and tests
5. `cardsense-web` input and result UX if new state is now meaningful

### 7. Validate locally

Minimum checks:

- extractor tests
- API tests
- frontend build if UI changed
- SQLite row counts
- representative `conditions_json`

### 8. Roll out safely

Before syncing to Supabase, confirm whether sync is:

- full-table
- bank-scoped
- card-scoped

If only one card is ready, prefer scoped sync.

## Current reference implementation: CATHAY_CUBE

The current best reference flow is `CATHAY_CUBE`.

It demonstrates:

- corrected plan mapping
- expanded subcategories
- merchant-aware cluster promos
- conservative tier handling
- frontend tier and merchant inputs
- card-scoped Supabase sync

## Why this workflow should also live as a skill

The workflow now spans:

- contracts
- extractor
- API runtime
- frontend
- rollout safety

That makes it valuable as both:

- a human-readable cross-repo workflow document
- and a Codex skill for repeated execution

The skill should remain the operational entry point.
This workflow doc should remain the concise project-level reference for cross-conversation continuity.
