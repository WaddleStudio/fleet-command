# Merchant-First Calculator Flow Design

> Date: 2026-05-06
> Status: Draft for review
> Scope: `cardsense-web` calculator UX, frontend request builder, validation, unit tests, and browser smoke coverage.

## Goal

Make the CardSense calculator match the checkout-time question users actually ask:

> I am buying at this merchant, with this payment method, for this amount. Which card should I use?

The primary calculator order becomes merchant first, payment method second, amount third. Category and subcategory become optional precision controls instead of mandatory first-class inputs.

## Recommended Approach

Use a `Merchant Intent Mode` in the calculator:

- `merchant`: the user knows or can choose a merchant.
- `general`: the user wants a general purchase comparison or is not sure which merchant applies.
- `advancedCategory`: the user chooses category/subcategory to sharpen matching.

The UI should make this feel like one flow, not a setup wizard. The first screen should still be the calculator, with results reachable after one submit once cards are selected.

## User Experience

### Primary Order

The main calculator panel should present:

1. Merchant intent
2. Payment method
3. Amount
4. Compare CTA

`My Wallet`, card selection, exchange-rate settings, and switching-card settings stay available without becoming the first interaction.

### Merchant Intent

The merchant section should include a segmented control or equivalent compact choice:

- `Specific merchant`
- `General purchase / not sure`

When `Specific merchant` is active:

- Show the merchant text input and high-signal merchant shortcuts.
- Merchant shortcuts set `merchantName` and, when available, infer category/subcategory.
- If the merchant maps to a known scene, show a compact inferred-scene note with an affordance to adjust in advanced details.
- Unknown merchant names remain valid. The calculator should still submit merchant, payment method, and amount without forcing category.

When `General purchase / not sure` is active:

- Clear or ignore `merchantName` in the request.
- Keep payment method and amount visible.
- Show advanced category controls as the way to narrow a broad comparison.

### Payment Method

Payment method appears immediately after merchant intent. It remains optional because not every checkout uses a named wallet or payment rail.

The existing `PaymentMethodPicker` behavior can stay, including grouped methods and a "no specific method" option. Copy should explain that payment method affects rules like LINE Pay, Apple Pay, and bank-wallet gates.

### Amount

Amount appears third and remains required for a recommendation run. Keep the current range validation:

- Minimum: NT$100
- Maximum: NT$100,000

The default can remain NT$1,200 unless implementation testing shows it creates misleading first-run results.

### Advanced Category

Category and subcategory move into an advanced details section.

Rules:

- No category should be required to submit.
- Category selection should send `category`.
- Subcategory selection should send `subcategory` only when a category is selected.
- Known merchant shortcuts may prefill category/subcategory, but the UI must label them as inferred, not user-required.
- Clearing advanced category should remove both category and subcategory from the next request unless a known merchant shortcut is selected again.

### Escape Hatch

The flow must retain an obvious escape hatch:

- Label: `General purchase / not sure`
- Behavior: submit without merchant constraints.
- Optional refinement: user can still select category/subcategory in advanced details.

This avoids forcing a fake merchant when the user only knows a purchase type.

## Request Semantics

`buildCalcRecommendationRequest` should model omitted fields honestly:

- Always include `amount`.
- Include `scenario.merchantName` only when `Specific merchant` is active and the trimmed merchant is non-empty.
- Include `scenario.paymentMethod` only when selected.
- Include `category` only when the user selected or accepted an inferred category.
- Include `subcategory` only when category is present and subcategory is present.
- Do not inject a hidden default category solely to satisfy the previous UI model.

If the API returns weak or empty results when category is omitted, the frontend should surface an actionable result-state message rather than silently broadening or narrowing in the request builder.

## Validation

Submit should be allowed when all of the following are true:

- Amount is present and within NT$100 to NT$100,000.
- At least two cards are selected for comparison.
- The recommendation request is not already pending.

Submit should not require:

- Merchant name.
- Category.
- Subcategory.
- Payment method.

Merchant-specific validation:

- In `Specific merchant` mode, an empty merchant input should not block submit, but the UI should either switch to `General purchase / not sure` semantics or show that no merchant constraint will be applied.
- Known merchant shortcut selection should keep the merchant input filled so the user can see the constraint being applied.

## Result Messaging

Results should make the applied assumptions visible:

- Specific merchant: show `Merchant: <merchantName>`.
- Payment method: show the selected payment method label.
- Category/subcategory: show selected or inferred values.
- General purchase: show a broad comparison label rather than implying a merchant-scoped result.

If no result is returned and category was omitted, the empty state should suggest either choosing a known merchant shortcut or opening advanced details to add category/subcategory.

## Test Coverage

Update unit tests before implementation where practical.

Request builder tests should cover:

- Merchant + payment + amount without category.
- General purchase + payment + amount without merchant/category.
- Category/subcategory included only when selected or inferred.
- Clearing category removes stale subcategory.
- Existing wallet, plan runtime, card codes, comparison, and custom exchange-rate fields still pass through.

Validation/UI logic tests should cover:

- Submit enabled without category when amount and card selection are valid.
- Submit blocked for invalid amount.
- Submit blocked when fewer than two cards are selected.
- Merchant shortcut applies merchant and inferred scene.
- Escape hatch omits merchant from the request.

Browser smoke should cover:

- Mobile viewport: specific merchant shortcut -> payment method -> amount -> compare, with no console errors.
- Mobile viewport: general purchase / not sure -> payment method -> amount -> compare, with no console errors.
- Desktop viewport: advanced details visible or reachable, category can be selected and cleared, and request results still render.

Use installed Chrome through gstack/browser for browser smoke. If gstack cannot run from PowerShell, use installed Chrome headless and report the fallback.

## Non-Goals

- Do not redesign the deterministic API engine in this work unless implementation proves category omission is unsupported.
- Do not add LLM parsing.
- Do not collect card numbers or change My Wallet storage semantics.
- Do not turn the calculator into a marketing landing page or multi-page wizard.
- Do not change promotion taxonomy or merchant registry data as part of this UX pass.

## Implementation Decisions

The implementation plan should use these decisions:

- A known merchant shortcut immediately accepts its inferred category/subcategory and sends them in the request. The UI must show the inference and let the user clear or adjust it in advanced details.
- This pass should focus on `/calc`, which is the app index and primary calculator surface. Leave `RecommendationForm` on `/recommend` unchanged unless shared type changes break it.
- Keep the default initial amount at NT$1,200 for this pass to avoid adding a second behavior change to validation and auto-select.

## Acceptance Criteria

- The first user-facing calculator inputs are merchant intent, payment method, and amount, in that order.
- A user can run a comparison without category/subcategory.
- A user can choose `General purchase / not sure` without entering a merchant.
- Known merchant shortcuts still improve precision by applying merchant and inferred scene.
- The request builder does not send hidden category defaults.
- Unit tests and build pass in `cardsense-web`.
- Mobile and desktop browser smoke produce evidence with no blocking console errors.
