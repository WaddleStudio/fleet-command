# CardSense Status

CardSense is the Taiwan credit-card payment decision engine for answering one checkout-time question:

> Given my cards, merchant, payment method, amount, and today's rules, which card should I use, what do I actually earn, and why might the answer change?

> **Live**: https://cardsense-web.vercel.app
> **Dashboard**: [fleet-command/dashboard](./dashboard/index.html)
> **Last updated**: 2026-05-03 (0-30 day wedge 90% complete)
> **Direction docs**: [2026-04-29 Review](./reviews/2026-04-29-cardsense-review/CardSense-Review-2026-04-29.md) + [Product Direction vs iCard.AI](./reviews/2026-04-29-cardsense-review/CardSense-Product-Direction-vs-iCardAI.md)

---

## Product Position

CardSense is not trying to clone iCard.AI, Money101, or card news SEO directories in the short term. The wedge is:

- **My Wallet**: local-first card selection without collecting card numbers.
- **Transaction decision**: merchant, channel, payment method, amount, eligibility, caps, and date.
- **Trust explanation**: source freshness, valid period, matched rules, excluded rules, assumptions, and confidence.

The request path stays deterministic. LLMs may help parsing, drafting explanations, and QA, but final user-facing money decisions must be reproducible and auditable.

---

## Current Capability

| Area | Current state |
|------|---------------|
| Product | Merchant-first calculator, My Wallet, benefit plan switching, recommendation result, and share flow exist. |
| Frontend | React/Vite app is live on Vercel with `/` and `/calc` surfaces. |
| API | Spring Boot deterministic `DecisionEngine` reads production data and serves recommendation responses. |
| Data | Extractor, contracts, SQLite, Supabase sync, and production API path are connected. |
| Banks | E.SUN, CATHAY, TAISHIN, FUBON, CTBC. |
| Merchants | Focus is high-frequency Taiwan scenarios such as Pxmart, momo, Shopee, Agoda, Uber Eats, LINE Pay, Apple Pay, Costco, insurance, overseas, and Japan spend. |
| Trust | Recommendation response and UI can carry confidence, source, verified date, valid period, matched/excluded rules, and assumptions. |

The dashboard shows repo health, roadmap progress, open action queue, latest checks, and release evidence links. This Markdown file stays intentionally short and keeps product direction as the source of truth.

---

## Repo Map

| Repo | Role | Stack |
|------|------|-------|
| [cardsense-contracts](https://github.com/WaddleStudio/cardsense-contracts) | Shared schemas, DTOs, taxonomy, merchant registry, stackability, benefit plans | JSON Schema |
| [cardsense-extractor](https://github.com/WaddleStudio/cardsense-extractor) | Bank promotion extraction, normalization, import, Supabase sync | Python 3.13, uv, Pydantic, SQLite, Supabase |
| [cardsense-api](https://github.com/WaddleStudio/cardsense-api) | Deterministic recommendation API and repository adapters | Java 21, Spring Boot, Maven, SQLite, Supabase |
| [cardsense-web](https://github.com/WaddleStudio/cardsense-web) | Frontend decision UX and calculator surface | React 19, TypeScript, Vite, Tailwind CSS |
| [fleet-command](https://github.com/WaddleStudio/fleet-command) | Cross-repo specs, review evidence, workspace rules, dashboard | Markdown, static HTML, Python tests |

---

## Roadmap

### 0-30 Days: Prove The Decision Wedge

| Workstream | Outcome |
|------------|---------|
| Product | My Wallet + transaction input + one best card + 1-2 alternatives. |
| UX | Checkout-time flow with mobile progressive disclosure. |
| Engine | Deeper cap, threshold, date, registration, channel, and eligibility coverage. |
| Trust | Result explanations that are readable enough for money decisions. |
| Data | 20-50 high-frequency merchants/scenarios with verified rules. |
| QA | Regression cases for the top merchants and payment scenarios. |
| Security | External secret rotation and ongoing secret scanning. |

### 31-60 Days: Build Retention

| Workstream | Outcome |
|------------|---------|
| Product | Manual cap usage, reward ledger, and bonus progress. |
| Data | User correction loop for reward posting and merchant classification. |
| UX | Promotion expiry alerts and best-card-changed alerts. |
| Engine | Confidence scoring based on source freshness, merchant certainty, and rule completeness. |
| Growth | 3-5 high-trust scenario pages plus methodology page. |
| Ops | Production runbook, rollback drill, and scheduled sync monitoring. |

### 61-90 Days: Create Defensibility

| Workstream | Outcome |
|------------|---------|
| Product | Personal card strategy dashboard for caps, annual fee thresholds, and first-spend tasks. |
| Data | Source snapshots, promotion change history, and versioned audit trail. |
| Engine | Scenario simulation for amount changes, cap used, eligibility, and payment method. |
| Trust | Public methodology page and affiliate policy. |
| Growth | CardSense Verified pages for top 100 merchants/scenarios. |

---

## Open Follow-Ups

| Item | Why it matters | Suggested timing |
|------|----------------|------------------|
| Supabase / Cloudflare secret rotation | Repo-side policy exists, but vendor-console credentials still need real rotation. | Security/Ops follow-up |
| Secret scanning | Prevent local or deployment secrets from entering repos again. | Security/Ops follow-up |
| `recommendation_audits` | Money decisions need request/response, evaluated promo versions, engine version, latency, and errors. | 60-90 days |
| `promoId` logical key hardening | Same-title same-day promotions can collide without stronger source keys. | 31-60 days |
| Feedback widget upload security | Direct anon upload/insert is too exposed for production. | P1 security batch |
| Pinned contracts dependency | Vercel builds should not clone mutable contracts branches. | P1 DX/Ops batch |

---

## Evidence

Completed repair details are intentionally not tracked on the main dashboard. Use these evidence paths when history matters:

- [2026-05-03 Chrome post-merge evidence](./reviews/2026-05-03-post-merge-chrome/)
- [2026-04-29 CardSense review](./reviews/2026-04-29-cardsense-review/CardSense-Review-2026-04-29.md)
- [Product direction vs iCard.AI](./reviews/2026-04-29-cardsense-review/CardSense-Product-Direction-vs-iCardAI.md)
- [Bank promo review workflow](./CardSense-Bank-Promo-Review-Workflow.md)
- [Full CardSense spec](./specs/spec-cardSense.md)
