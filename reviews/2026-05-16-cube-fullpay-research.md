# CATHAY CUBE Full Pay Research - 2026-05-16

## Question

Verify the newest CATHAY CUBE benefit category for `全支付` without relying on the existing CardSense extractor output.

## Verdict

`CATHAY_CUBE` has a new/independent benefit plan for `全支付`.

Initial CardSense local data was missing it. Before the 2026-05-16 fix, the local DB only contained `CUBE信用卡 集精選 量販超市` with `PXMART` venue conditions and did not contain a `CATHAY_CUBE_FULL_PAY` benefit plan or a CUBE promotion with `PAYMENT=全支付`.

Implemented follow-up: the local/API DB now includes a `CATHAY_CUBE_FULL_PAY` benefit plan and a CUBE `全支付` promotion candidate. This document remains the source-review evidence for why the extractor needed a rule update instead of trusting old extractor output.

## Source Findings

### Strong Secondary / Press-Release Based

- UDN, 2026-05-05: reports that CUBE users can switch in CUBE App to the `全支付` dedicated plan. With CUBE card bound in 全支付, spending at 全聯 and more than 370,000 partner locations earns up to 2% 小樹點(信用卡). Event add-on through 2026-06-28 adds 5% 全點, for up to 7% total.
  - https://udn.com/news/story/7270/9482645
- Yahoo Finance, 2026-04-22: reports CUBE launched new `全支付` benefit; 全聯 was previously under `集精選`, but is now split into an independent switchable benefit together with 大全聯 and 全支付 domestic partner channels. Reports benefit through 2026-12-31.
  - https://tw.stock.yahoo.com/news/%E5%85%A8%E8%81%AF%E5%A4%A7%E5%85%A8%E8%81%AF%E5%88%B7%E5%8D%A1%E8%B3%BA2%E5%9B%9E%E9%A5%8B%EF%BC%81600%E8%90%AC%E5%9C%8B%E6%B3%B0cube%E5%8D%A1%E6%96%B0%E6%AC%8A%E7%9B%8A%E3%80%8C%E5%85%A8%E6%94%AF%E4%BB%98%E3%80%8D%E5%88%B0%E5%B9%B4%E5%BA%95-082205743.html
- 卡優 / Yahoo News, 2026-05-08: reports CUBE adds `全支付` benefit plan through 2026-12-31, 2% 小樹點 with no cap for domestic partner-channel transactions when CUBE App is switched to `全支付` and CUBE card is bound in 全支付. Full Pay campaign adds up to 5% 全點 through 2026-06-28.
  - https://tw.news.yahoo.com/cube%E5%8D%A1%E8%81%AF%E6%89%8B%E5%85%A8%E6%94%AF%E4%BB%98%E9%80%817-richart%E7%B9%B3%E7%A8%85%E6%9C%80%E9%AB%98%E7%9C%8110-211440281.html

### Earlier 2026 Campaign Context

- NOWnews, 2026-01-09: Q1 campaign before the independent benefit launch. CUBE card bound in 全支付, with coupon/condition and monthly spend threshold, earned 3% 小樹點 plus up to 5% 全點. This is a campaign, not the later independent CUBE plan.
  - https://www.nownews.com/news/6774083

### Official Source Status

- Cathay official search/page snippets confirm CUBE terms still exclude `全支付` from other CUBE benefit schemes such as `台塑家`; this supports treating `全支付` as a special dedicated plan, not as a generic third-party payment condition under existing plans.
- The official CUBE product page and CUBE rights page fetched directly on 2026-05-16 did not expose the new `全支付` plan in static HTML. The page likely requires JS/app content or an updated bank-side endpoint that the current extractor does not parse.

## Recommended CardSense Representation

### Benefit Plan

```json
{
  "planId": "CATHAY_CUBE_FULL_PAY",
  "planName": "全支付",
  "cardCode": "CATHAY_CUBE",
  "validFrom": "2026-04-22",
  "validUntil": "2026-12-31",
  "switchFrequency": "DAILY",
  "exclusiveGroup": "CATHAY_CUBE_PLANS"
}
```

`validUntil=2026-12-31` is based on Yahoo Finance and 卡優/Yahoo reports. Treat as `needs official confirmation` before production sync.

### Base Recommendable Promotion

```json
{
  "title": "CUBE信用卡 全支付 專屬權益",
  "cardCode": "CATHAY_CUBE",
  "bankCode": "CATHAY",
  "category": "OTHER",
  "subcategory": "GENERAL",
  "channel": "ALL",
  "cashbackType": "PERCENT",
  "cashbackValue": "2.00",
  "recommendationScope": "RECOMMENDABLE",
  "validFrom": "2026-04-22",
  "validUntil": "2026-12-31",
  "conditions": [
    { "type": "TEXT", "value": "需切換至「全支付」方案", "label": "需切換至「全支付」方案" },
    { "type": "PAYMENT", "value": "全支付", "label": "全支付" }
  ],
  "planId": "CATHAY_CUBE_FULL_PAY"
}
```

### Covered Channels / Merchants

Use a broad payment condition first. Add venue conditions only if needed for explainability:

- `PXMART` / 全聯福利中心
- `PXMART` / 大全聯
- 全電商
- 小時達
- 分批取
- 全支付 domestic partner merchants

The reports describe "全台逾37萬個合作據點" or "國內合作通路", so the runtime condition should prioritize `PAYMENT=全支付` over enumerating every merchant.

### Campaign Add-On

Do not merge the 5% 全點 campaign into the base CUBE reward.

Represent separately if needed:

- reward: 5% 全點
- validUntil: 2026-06-28
- payment: 全支付
- card/bank: 國泰世華信用卡
- scope: likely `CATALOG_ONLY` or separate non-card-point reward until CardSense models cross-program 全點.

## Gaps Fixed On 2026-05-16

- `cardsense-api/src/main/resources/benefit-plans.json` now includes `CATHAY_CUBE_FULL_PAY`.
- `cardsense-web/src/types/enums.ts` now includes the CUBE `全支付` plan option.
- `cardsense-extractor/extractor/cathay_real.py` now emits the dedicated `全支付` promotion when the official static page feed does not expose it.
- Local/API DB now includes a CUBE `PAYMENT=全支付` promotion.

## Pipeline Reflection

This miss should not be treated as a one-off extractor bug. It is evidence that quarterly bank refreshes need an independent source-review layer before trusting extractor output.

Current extractor jobs can import known page structures, but they are weak at discovering new benefit-plan structures, JS-rendered rights pages, payment-wallet launches, and plan splits such as `集精選` -> dedicated `全支付`.

Recommended quarterly flow:

1. Build a bank-by-bank source review from official pages, PDFs, payment-provider pages, and trusted press-release coverage.
2. Convert that review into a source-of-truth checklist: plans, rates, dates, payment conditions, merchant scopes, caps, registration requirements, and source URLs.
3. Compare the checklist against local `promotion_current` and benefit-plan metadata.
4. Classify differences as extractor drift, taxonomy gap, runtime gap, expired-data cleanup, or safe manual patch.
5. Only then update extractor rules or importer data.

Local or hosted models may help parse pages/PDFs and draft structured candidates, but they should not directly publish production money-decision data. The safer role is:

- model-assisted extraction and diffing
- schema validation
- deterministic tests
- human approval for high-value cards and new rule shapes
- deterministic `DecisionEngine` for final recommendations

In short: extractor output should become something CardSense audits, not something CardSense blindly accepts.

## Suggested Validation Query

```sql
SELECT card_code, title, plan_id, conditions_json, valid_from, valid_until
FROM promotion_current
WHERE card_code = 'CATHAY_CUBE'
  AND (title LIKE '%全支付%' OR conditions_json LIKE '%全支付%');
```

Expected after fix: at least one `CATHAY_CUBE_FULL_PAY` row with `PAYMENT=全支付`.
