# Merchant Search, Category Facet Calculator Design

> Date: 2026-05-07
> Status: Approved for implementation
> Supersedes: `fleet-command/specs/2026-05-06-merchant-first-calculator-flow-design.md`
> Scope: `cardsense-web` `/calc` UX, merchant selection semantics, request builder validation, frontend tests, and browser smoke evidence.

## Goal

Make `/calc` answer the checkout-time question through a merchant-first search flow:

> I am buying at this merchant, with this payment method, for this amount. Which card should I use?

The merchant is the primary locator. Payment method and amount remain primary inputs. Category/subcategory become assistive metadata: they help users narrow merchant search, explain how CardSense classified the selected merchant, and provide a fallback when the merchant is not supported.

## Product Direction

The calculator should not ask users to pick a consumption category first. Most users do not think "餐飲" or "網購" first; they think "星巴克", "momo", "Agoda", or "全聯".

The next version should therefore use:

- Merchant search as the first interaction.
- Category as an assistive facet while browsing/searching merchants.
- Registry-backed merchant selection before merchant-specific recommendations are allowed.
- Category fallback only when the searched merchant is not found.

`General purchase` is no longer a first-class mode. It becomes an empty-search fallback path instead of a segmented-control peer to merchant search.

## UX Shape

### Primary Calculator Order

The main calculator panel should present:

1. Merchant search/picker
2. Payment method
3. Amount
4. Compare CTA

`My Wallet`, card selection, exchange-rate settings, switching-card settings, and result details stay available without becoming the first interaction.

### Merchant Search

The first field is a merchant picker with search:

- The empty state shows featured merchants such as 全聯, 家樂福, momo, 蝦皮, Agoda, 星巴克, Uber Eats, and McDonald's.
- Typing filters the registry by label, code, and aliases.
- A selected merchant is represented by a canonical merchant code and label from the registry.
- Free text is not submitted as a merchant constraint.
- The user can clear the selected merchant and search again.

The picker may show category facet chips near the search field:

- All
- 餐飲
- 網購
- 生活採買
- 旅遊
- 交通
- 購物
- 娛樂
- 海外

Facet chips only narrow merchant search results. They do not override the selected merchant's category.

### Selected Merchant State

After the user selects a merchant, show a compact confirmation:

- Selected merchant label
- System-located category/subcategory, for example `餐飲 / 咖啡茶飲`
- A clear/reselect affordance

The category/subcategory shown here is derived from the merchant registry. The user should not manually edit it in this state. If the classification looks wrong, the user can choose a different merchant; data correction belongs in the registry pipeline, not the calculator session.

### No-Match Fallback

When search has no matching merchant:

- Tell the user CardSense only applies merchant-specific rules to supported merchants.
- Offer category fallback actions such as `改用餐飲比較`, `改用網購比較`, or `改用旅遊比較`.
- Category fallback sends category/subcategory without a merchant constraint.
- Fallback copy must make it clear the result is a general scene comparison, not a merchant-specific recommendation.

This is the only place category becomes a user-selected primary locator.

### Background Merchant Data

The long-term merchant registry should distinguish foreground suggestions from background coverage:

- `featured`: shown by default in the empty picker state.
- `searchable`: visible through normal search.
- `background`: not shown by default, but searchable when the user looks for a specific merchant and available to the API for condition matching/explainability.

Examples of background coverage include partner merchants from cards and plans such as Cathay CUBE, Taishin Richart, and UniCard. These merchants should not flood the default UI, but they should improve search recall when a user types a supported store.

The first implementation can derive this behavior from the existing registry and a frontend featured-code list. It does not need to migrate the contracts schema in the same pass.

## Request Semantics

`buildCalcRecommendationRequest` should model selected merchant and fallback category honestly:

- Always include `amount`.
- Include `scenario.merchantName` only when a registry merchant is selected.
- Prefer the canonical merchant code as the merchant value sent to the API.
- Include `scenario.paymentMethod` only when a payment method is selected.
- Include `category` and `subcategory` from the selected merchant's registry metadata.
- In category fallback mode, include category/subcategory but omit `scenario.merchantName`.
- Never send hidden category defaults.
- Never send unsupported free-text merchant input.

If the API returns weak or empty results in category fallback mode, the frontend should show recovery actions rather than pretending a merchant-specific recommendation was calculated.

## Validation

Submit should be allowed when all of the following are true:

- Amount is present and within NT$100 to NT$100,000.
- At least two cards are selected for comparison.
- Either a registry merchant is selected, or a category fallback has been explicitly selected.
- The recommendation request is not already pending.

Submit should not require payment method.

Submit should be blocked when the search field contains text but no merchant is selected. The error should tell the user to choose a supported merchant from the results or use category fallback.

## Data Flow

```text
Search text + category facet
  -> merchant registry results
  -> selected merchant code/label/category/subcategory
  -> payment method + amount + selected cards
  -> buildCalcRecommendationRequest()
  -> RecommendationRequest
  -> useRecommendation()
  -> ResultPanel / empty state

No merchant match
  -> explicit category fallback
  -> payment method + amount + selected cards
  -> buildCalcRecommendationRequest()
  -> RecommendationRequest without merchant
```

## Component Boundaries

Create a dedicated calculator merchant module instead of adding more merchant logic directly to `CalcPage`.

Recommended frontend units:

- `src/pages/calc/merchant-search.ts`: pure search, facet, selected merchant, and fallback helpers.
- `src/pages/calc/merchant-search.test.ts`: pure behavior tests.
- `src/pages/calc/MerchantSearchPicker.tsx`: UI for search, facets, results, selected state, and fallback actions.
- `src/pages/calc/buildCalcRecommendationRequest.ts`: request payload boundary.
- `src/pages/CalcPage.tsx`: orchestration only.

Existing `src/components/MerchantPicker.tsx` is for UniCard flexible merchant selection and should not be reused as-is for `/calc`; it allows multi-select and has plan-specific copy.

## Result Messaging

Results should show the applied locator:

- Selected merchant: `Merchant: 星巴克`, plus `System-located: 餐飲 / 咖啡茶飲`.
- Payment method: show the selected payment method label when present.
- Category fallback: show `Using 餐飲 as a general scene comparison` or equivalent localized copy.

Empty results should suggest:

- Select a different supported merchant.
- Clear or change payment method.
- Use category fallback if no merchant is selected.
- Select different cards.

## Test Coverage

Unit tests should cover:

- Merchant search filters by label, code, and aliases.
- Category facet narrows search results without changing selected merchant metadata.
- Selecting a merchant returns canonical code, label, category, and subcategory.
- Search with no results exposes category fallback choices.
- Request builder includes selected merchant metadata.
- Request builder omits merchant in category fallback mode.
- Submit is blocked for search text without selected merchant.
- Submit is allowed for selected merchant with valid amount and selected cards.
- Submit is allowed for explicit category fallback with valid amount and selected cards.

Browser smoke should cover:

- Mobile: featured merchant -> payment method -> amount -> compare.
- Mobile: search no-match -> category fallback -> compare.
- Desktop: category facet filters merchant search results and selected merchant shows system-located metadata.
- No blocking console errors.
- No incoherent layout overlap.

## Non-Goals

- Do not add LLM merchant parsing.
- Do not submit arbitrary free-text merchants.
- Do not redesign the deterministic API engine unless implementation proves canonical merchant code breaks matching.
- Do not migrate the merchant registry schema to include `visibility` or `sources` in this pass.
- Do not change My Wallet storage semantics.
- Do not redesign `/recommend` `RecommendationForm`.

## Acceptance Criteria

- `/calc` starts with merchant search, not merchant intent segmentation.
- `Specific merchant` and `General purchase` segmented controls are removed.
- A user must select a supported merchant before merchant-specific comparison.
- Category appears as a search facet and selected-merchant metadata.
- Category fallback is available only after no merchant match.
- Unsupported free text is never sent as a merchant constraint.
- Request payloads include honest merchant/category semantics.
- Unit tests and build pass in `cardsense-web`.
- Mobile and desktop browser smoke evidence is saved with no blocking console errors.
