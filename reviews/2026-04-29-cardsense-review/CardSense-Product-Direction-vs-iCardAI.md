> **Historical / superseded / not planned (2026-09).** CardSense is archived. This document and its linked CardSense plans are engineering history, not an active roadmap or an instruction to run production operations. [Archive decision](https://github.com/WaddleStudio/cardsense-api/blob/master/ARCHIVED.md).

# CardSense Product Direction vs iCard.AI

Date: 2026-04-29
Purpose: turn iCard.AI competitor research into concrete CardSense product direction.
Status: Direction document, not an implementation plan.

## 1. Product North Star

CardSense should not become another Taiwan credit card listing site.

CardSense should become a scenario-based credit card benefit decision engine:

> Given my cards, this merchant, this payment method, this amount, and today's rules, tell me which card to use and why.

The product should optimize for trustworthy decisions at the moment of spending, not for the largest public card catalog.

## 2. Competitor Lessons From iCard.AI

| iCard.AI observation | What it means | CardSense response |
|---|---|---|
| iCard.AI has broad SEO coverage across cards, banks, merchants, scenarios, loans, and insurance. | Competing on breadth requires content operations, structured data scale, and partner distribution. | Do not start by chasing full catalog parity. |
| The strongest overlapping feature is the `/diagnosis` owned-card decision flow. | The market already understands the checkout-time decision problem. | Win by making this flow more personal, transparent, and faster. |
| Pages show high headline rewards such as stacked percentages. | Users still need to understand caps, thresholds, registration, and eligibility. | Show effective value after conditions, not only headline rate. |
| The site mixes recommendations with application CTAs. | Monetization is likely tied to affiliate and lead generation. | Keep ranking logic and commercial incentives explicitly separated. |
| Public pages expose detailed card, channel, reward, cap, period, and exclusion data. | A serious competitor treats rules as structured data. | Make rule structure a first-class product and engineering concern. |
| Privacy policy discloses collection of searches, questions, selected cards, and loan inputs. | Personalization is valuable but can erode trust. | Use privacy-light portfolio design: card names only, no card numbers. |

## 3. Strategic Choice

Recommended choice: focus on personal decision quality.

| Option | What it means | Recommendation |
|---|---|---|
| Full catalog competitor | Build the largest card, bank, merchant, and SEO database. | Avoid for now. It is expensive and makes CardSense look like a smaller iCard.AI. |
| Affiliate comparison site | Rank cards and push applications. | Defer. Monetization can come later, after trust is established. |
| Personal wallet decision engine | Help users decide which existing or candidate card wins for a real transaction. | Choose this. It matches the CardSense concept and creates differentiation. |

## 4. Non-Goals

CardSense should not spend the next phase on:

- Rebuilding every iCard.AI category page.
- Listing every Taiwan credit card before the decision engine is excellent.
- Expanding into loans or insurance.
- Optimizing around affiliate CTAs before ranking trust is clear.
- Publishing high-volume SEO pages with weak verification.
- Giving a recommendation when eligibility or freshness is too uncertain.

## 5. Win Conditions

CardSense can beat iCard.AI in these specific areas:

| Win condition | Why users care | Product requirement |
|---|---|---|
| Personal best card | Public best card is often not the user's best card. | User-owned card portfolio. |
| Cap-aware recommendation | A card can stop being best after monthly cap is used. | Cap tracking and reward ledger. |
| Eligibility-aware recommendation | New-user, registration, payment, and threshold rules change the answer. | Eligibility checklist per recommendation. |
| Transparent reasoning | Users do not trust black-box rankings for money decisions. | Explain matched rules, excluded rules, assumptions, and confidence. |
| Freshness trust | Credit card promotions change constantly. | Show source, verified date, valid period, and stale warnings. |
| Checkout speed | Users need one answer quickly. | Fast merchant/amount/payment flow with one primary recommendation and alternatives. |
| Privacy trust | Users hesitate to enter financial data. | Card name only, no card number, optional account, clear storage model. |

## 6. MVP Scope

The MVP should answer one question well:

> For this transaction, which card should I use?

### Must Have

| Capability | MVP behavior |
|---|---|
| My Wallet | User can add owned cards by card name. No card number required. |
| Scenario input | User enters merchant or category, payment method, amount, and optional date. |
| Recommendation result | Show best card, estimated return, and 1-2 alternatives. |
| Explanation | Show base reward, bonus reward, cap, threshold, registration, expiry, and exclusions. |
| Confidence | Display high/medium/low confidence with reason. |
| No-result state | Explain why no confident recommendation exists and what user can change. |
| Source freshness | Show source URL or source name, last verified date, and valid period. |
| Manual cap tracking | Let user mark estimated monthly cap usage manually at first. |

### Defer

| Deferred item | Why |
|---|---|
| Full bank/card catalog | Too broad before product fit. |
| Bank account/card transaction integration | High complexity and privacy burden. |
| Loans and insurance | Dilutes the product wedge. |
| Affiliate optimization | Can compromise trust if introduced too early. |
| AI chatbot as primary interface | Users need deterministic, auditable decisions first. |

## 7. Recommendation Engine Principles

The recommendation engine should be deterministic, explainable, and conservative.

| Principle | Rule |
|---|---|
| Effective value over headline rate | Rank by expected reward after caps, thresholds, and eligibility. |
| Eligibility first | If the user does not qualify, the card should be excluded or clearly demoted. |
| Explain every win | The winning card must include why it wins and what assumptions could change it. |
| Show disqualifiers | Missing registration, expired promotion, exceeded cap, excluded merchant, or wrong payment method should be visible. |
| Prefer uncertainty over false confidence | If merchant coding or rule freshness is uncertain, say so. |
| Separate organic and paid ranking | Commercial relationships must not silently change ranking. |

## 8. Data Model Direction

CardSense needs structured entities, not prose-only promotions.

| Entity | Purpose | Important fields |
|---|---|---|
| Bank | Issuer identity. | `bankId`, `name`, `sourceUrl` |
| Card | Product identity. | `cardId`, `bankId`, `name`, `aliases`, `network`, `annualFee`, `applyUrl` |
| UserCard | User-owned card state. | `userCardId`, `cardId`, `owned`, `benefitPlan`, `capUsage`, `notes` |
| Merchant | Merchant/channel identity. | `merchantId`, `name`, `aliases`, `category`, `paymentMethods`, `mccHints` |
| Scenario | Transaction context. | `merchantId`, `category`, `amount`, `paymentMethod`, `date`, `currency` |
| Promotion | Public offer. | `promotionId`, `cardId`, `validFrom`, `validUntil`, `sourceUrl`, `verifiedAt` |
| RewardRule | Computable reward condition. | `rewardType`, `rate`, `fixedValue`, `cap`, `threshold`, `period`, `stackability` |
| EligibilityRule | Whether user qualifies. | `newCustomerOnly`, `registrationRequired`, `requiredAccount`, `paymentMethodRequired`, `exclusions` |
| Recommendation | Engine output. | `cardId`, `estimatedReturn`, `confidence`, `matchedRules`, `excludedRules`, `assumptions` |
| SourceSnapshot | Trust/audit trail. | `sourceUrl`, `fetchedAt`, `parsedAt`, `verifiedAt`, `hash` |

## 9. UX Direction

CardSense UX should feel like a decision tool, not a search results page.

| Surface | Direction |
|---|---|
| Home | Start with the transaction decision input, not a marketing hero or giant card list. |
| My Wallet | Make adding cards lightweight and reassuring. Show "card name only, no card number." |
| Result | One primary answer, two alternatives, clear estimated value. |
| Explanation | Use compact sections: Why this wins, Watch outs, Assumptions, Source freshness. |
| Compare | Compare cards by this user's scenarios, not generic feature tables. |
| Mobile | Optimize for checkout-time use: input, result, reason. Hide advanced settings until needed. |
| Trust | Surface stale data, low confidence, and affiliate disclosure where decisions are made. |

## 10. SEO And Growth Direction

CardSense should not copy iCard.AI's broad template strategy. It should build fewer, more trustworthy pages.

| Page type | Example | Why it fits CardSense |
|---|---|---|
| Scenario decision page | `momo 刷哪張卡最划算` | High intent, easy to connect to calculator. |
| Merchant verified page | `Agoda 信用卡回饋檢查` | Lets CardSense show source freshness and rule logic. |
| Payment method page | `LINE Pay 已達上限後刷哪張` | Highlights cap-aware differentiation. |
| Edge case guide | `保費刷卡回饋上限怎麼算` | Builds trust through rule explanation. |
| CardSense methodology | `我們如何計算信用卡回饋` | Converts transparency into brand trust. |

SEO content should always link back to an interactive decision flow.

## 11. 30/60/90 Day Roadmap

### First 30 Days: Prove The Decision Wedge

| Workstream | Deliverable |
|---|---|
| Product | My Wallet + transaction input + best card result. |
| Data | Top 20-50 high-frequency merchants/scenarios with verified rules. |
| Engine | Effective reward calculation with cap, threshold, date, and registration handling. |
| UX | Trust-first result panel with source freshness and assumptions. |
| QA | Regression cases for momo, Shopee, Agoda, Uber Eats, LINE Pay, Apple Pay, Costco, insurance premium, overseas spend. |

### First 60 Days: Build Retention

| Workstream | Deliverable |
|---|---|
| Product | Reward ledger for cap usage and bonus progress. |
| Data | User correction loop: "reward posted / did not post / merchant categorized differently." |
| UX | Alerts for expiring promotions and changed best-card recommendations. |
| Engine | Confidence score based on source freshness, merchant certainty, and rule completeness. |
| Growth | Publish a small set of high-trust scenario pages. |

### First 90 Days: Create Defensibility

| Workstream | Deliverable |
|---|---|
| Product | Personal card strategy dashboard: caps, annual fee waiver progress, first-spend tasks. |
| Data | Versioned source snapshots and promotion change history. |
| Engine | Scenario simulation: "if amount changes", "if cap is used", "if not new customer". |
| Trust | Public methodology page and clear affiliate policy. |
| Growth | CardSense Verified pages for top 100 merchants/scenarios. |

## 12. Product Decision Table

| Decision | Choice | Reason |
|---|---|---|
| Primary user job | Decide which card to use for a transaction. | This is the clearest differentiated wedge. |
| Initial data scope | Narrow verified dataset. | Better to be trusted for 50 scenarios than vague for 7,000. |
| Ranking basis | Effective value after eligibility and caps. | More useful than headline rewards. |
| Privacy posture | Card name only, no card number. | Reduces adoption friction. |
| Monetization timing | Defer affiliate-first optimization. | Trust must come before conversion. |
| SEO posture | High-trust scenario pages. | Avoid becoming a thin listing site. |
| AI usage | Assist parsing and explanation, not final unchecked decisions. | Financial recommendations need auditability. |

## 13. Implementation Plan Candidates

These are candidate implementation plans to write next. They should be split into separate implementation docs.

| Candidate plan | Scope | Priority |
|---|---|---|
| My Wallet MVP | Add owned cards, store locally or account-backed, no card number. | P0 |
| Transaction Decision Flow | Merchant/category/payment/amount input to recommendation result. | P0 |
| Trust Result Panel | Source freshness, matched rules, excluded rules, assumptions, confidence. | P0 |
| Rule Schema Hardening | Structured reward and eligibility rules across contracts/API/extractor. | P0 |
| Cap Tracking MVP | Manual cap usage and bonus progress. | P1 |
| Merchant Registry | Canonical merchants, aliases, payment methods, category hints. | P1 |
| Scenario SEO Pages | Verified pages for selected high-intent merchants and payment methods. | P1 |
| User Correction Loop | Capture user feedback on reward posting and merchant classification. | P2 |

## 14. Open Questions

| Question | Recommended default |
|---|---|
| Should My Wallet be local-only or account-backed first? | Start local-first if implementation is faster, but design the model so account sync can be added. |
| How many merchants should be verified for MVP? | 20-50, selected by actual high-frequency Taiwan spending scenarios. |
| Should CardSense include affiliate links in MVP? | Only if clearly disclosed and never used to alter ranking. |
| Should AI be visible to users? | Not as a chatbot first. Use AI behind the scenes for parsing, explanation drafts, and QA, with deterministic engine output. |
| What is the first public growth asset? | A methodology/trust page plus 3-5 scenario pages that demonstrate calculation quality. |

## 15. Self-Review

| Check | Result |
|---|---|
| Completion-marker scan | No unfinished draft markers found. |
| Internal consistency | Positioning, MVP, roadmap, and data model all point to the same wallet-based decision engine. |
| Scope check | The MVP is narrow enough to become an implementation plan. Deferred items are explicit. |
| Ambiguity check | Core ranking principle is explicit: effective value after eligibility, caps, and freshness. |
| Competitive constraint | The document avoids copying iCard.AI text/design and uses it only as strategic input. |
