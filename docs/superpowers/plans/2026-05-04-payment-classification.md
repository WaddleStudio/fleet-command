# Payment Classification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the bug where payment methods (LINE Pay, 街口支付, etc.) are incorrectly treated as merchants in reward calculation, and implement Unicard's "third-party payment reclassification" rule and Richart's "payment-method-gated merchant" rule.

**Architecture:** Existing `promotion-normalized.schema.json` already has `excludedConditions[]` and `conditions[]`. No schema changes needed. We extend `DecisionEngine.matchesExcludedConditions` to handle `PAYMENT` and `VENUE` exclusion types, remove the merchant→payment token bridge, clean up `merchant-registry.json`, and tag Unicard/Richart promotions with the appropriate `conditions`/`excludedConditions`.

**Tech Stack:** Java 17 (cardsense-api Spring Boot), Python 3.11 (cardsense-extractor), JSON Schema (cardsense-contracts).

**Affected repos:**
- `cardsense-api` — DecisionEngine.java + DecisionEngineTest.java
- `cardsense-extractor` — esun_real.py, taishin_real.py, tests
- `cardsense-contracts` — taxonomy/merchant-registry.json (cleanup only)

**Out of scope (future plans):**
- Schema-level `paymentEligibility` object — current schema (`conditions[]` + `excludedConditions[]`) sufficient for all 4 patterns
- 聯邦 (UBOT) / 中信 (CTBC) cards similar payment-rail rules — apply same pattern in follow-up

**Bank rule citations (verified 2026-05-04):**
- **Pattern A — Unicard reclassify**: 「百大特店消費限玉山Unicard實體卡支付，若透過第三方支付及電子支付錢包**將不認列為該特店之交易**，**改歸類為行動支付特店類別**」 — `event.esunbank.com.tw/credit/unicard/discount-channel.html`
- **Pattern B — Richart 天天刷 payment gate**: 7-11/全家「限使用台新Pay 綁定支付，使用實體卡、OPEN 錢包、全盈支付、FamiPay 等不予回饋」
- **Pattern C — 富邦 momo downgrade**: 「使用第三方支付平台，如 LINE Pay、街口支付，包含 LINE Pay 綁 momo 卡於 momo 通路消費，皆視為一般消費 1%」
- **Pattern D — 富邦數位生活卡 channel rail**: 「Apple Pay、Google Pay、Samsung Pay、台灣行動支付等**行動支付實體店面交易，不適用數位通路 2%**」

---

## Task 1: Extend DecisionEngine to honor PAYMENT/VENUE excludedConditions

**Files:**
- Modify: `cardsense-api/src/main/java/com/cardsense/api/service/DecisionEngine.java:1409-1433` (matchesExcludedConditions)
- Test: `cardsense-api/src/test/java/com/cardsense/api/service/DecisionEngineTest.java`

**Context:** Currently `matchesExcludedConditions` only supports `CATEGORY_EXCLUDE` and `LOCATION_EXCLUDE`. Schema allows any condition type in `excludedConditions[]`, and we need to honor `PAYMENT` and `VENUE` types so an `{type: PAYMENT, value: LINE_PAY}` exclusion knocks out a promotion when the user's payment method is LINE Pay.

- [ ] **Step 1: Write the failing test (PAYMENT exclusion)**

Add to `DecisionEngineTest.java`:

```java
@Test
void promotionWithPaymentExclusionIsFilteredOutWhenUserPaysWithExcludedPayment() {
    Promotion promo = baseSupermarketPromotion()
            .conditions(List.of(condition("VENUE", "PXMART", "全聯")))
            .excludedConditions(List.of(condition("PAYMENT", "LINE_PAY", "LINE Pay")))
            .build();
    RecommendationRequest req = RecommendationRequest.builder()
            .resolvedMerchantName("全聯")
            .resolvedPaymentMethod("LINE Pay")
            .build();
    DecisionResult result = engine.decide(List.of(promo), req);
    assertThat(result.getMatched()).isEmpty();
}

@Test
void promotionWithVenueExclusionIsFilteredOutWhenMerchantMatchesExclusion() {
    Promotion promo = basePromotion()
            .conditions(List.of(condition("VENUE", "PXMART", "全聯")))
            .excludedConditions(List.of(condition("VENUE", "MOMO", "momo")))
            .build();
    RecommendationRequest req = RecommendationRequest.builder()
            .resolvedMerchantName("momo")
            .build();
    DecisionResult result = engine.decide(List.of(promo), req);
    assertThat(result.getMatched()).isEmpty();
}
```

(Helpers `basePromotion()`, `baseSupermarketPromotion()`, `condition()` already exist in the test class — reuse them.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd cardsense-api && ./gradlew test --tests DecisionEngineTest.promotionWithPaymentExclusionIsFilteredOutWhenUserPaysWithExcludedPayment`

Expected: FAIL — promotion still matches because PAYMENT exclusion is ignored.

- [ ] **Step 3: Extend matchesExcludedConditions to handle PAYMENT and VENUE**

Replace lines 1418-1430 in `DecisionEngine.java`:

```java
        Set<String> normalizedMerchantTokens = expandMerchantTokens(request.getResolvedMerchantName());
        Set<String> normalizedPaymentMethods = expandPaymentMethods(request.getResolvedPaymentMethod());

        for (PromotionCondition excludedCondition : excludedConditions) {
            String normalizedType = normalizeValue(excludedCondition.getType());
            String normalizedValue = normalizeValue(excludedCondition.getValue());
            if ("CATEGORY_EXCLUDE".equals(normalizedType)) {
                if (normalizedCategory.equals(normalizedValue)) {
                    return true;
                }
            } else if ("LOCATION_EXCLUDE".equals(normalizedType)) {
                if (!normalizedLocation.isBlank() && normalizedLocation.contains(normalizedValue)) {
                    return true;
                }
            } else if ("PAYMENT".equals(normalizedType)) {
                if (normalizedPaymentMethods.contains(normalizedValue)) {
                    return true;
                }
                if ("MOBILE_PAY".equals(normalizedValue)
                        && normalizedPaymentMethods.stream().anyMatch(MOBILE_PAY_PLATFORM_VALUES::contains)) {
                    return true;
                }
            } else if ("VENUE".equals(normalizedType)) {
                if (normalizedMerchantTokens.contains(normalizedValue)) {
                    return true;
                }
            }
        }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd cardsense-api && ./gradlew test --tests DecisionEngineTest`

Expected: PASS — both new tests + all existing tests.

- [ ] **Step 5: Commit**

```bash
git -C cardsense-api add src/main/java/com/cardsense/api/service/DecisionEngine.java src/test/java/com/cardsense/api/service/DecisionEngineTest.java
git -C cardsense-api commit -m "feat(engine): honor PAYMENT and VENUE exclusions in excludedConditions"
```

---

## Task 2: Remove merchant→payment token bridge in DecisionEngine

**Files:**
- Modify: `cardsense-api/src/main/java/com/cardsense/api/service/DecisionEngine.java:1287`
- Test: `cardsense-api/src/test/java/com/cardsense/api/service/DecisionEngineTest.java`

**Context:** Line 1287 reads `normalizedPaymentMethods.addAll(normalizedMerchantTokens);` — this means when a user enters "LINE Pay" as merchant name, it gets resolved to `LINE_PAY` via merchant-registry and incorrectly treated as a valid payment method. This is the literal "支付方式可當成店家" bug. Payment methods should only match when entered in the payment field.

- [ ] **Step 1: Write the failing test**

Add to `DecisionEngineTest.java`:

```java
@Test
void merchantNameInputDoesNotSatisfyPaymentRequirement() {
    Promotion promo = basePromotion()
            .conditions(List.of(condition("PAYMENT", "LINE_PAY", "LINE Pay")))
            .build();
    RecommendationRequest req = RecommendationRequest.builder()
            .resolvedMerchantName("LINE Pay")        // wrong field
            .resolvedPaymentMethod(null)
            .build();
    DecisionResult result = engine.decide(List.of(promo), req);
    assertThat(result.getMatched())
        .as("LINE Pay in merchant field must not satisfy a PAYMENT condition")
        .isEmpty();
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd cardsense-api && ./gradlew test --tests DecisionEngineTest.merchantNameInputDoesNotSatisfyPaymentRequirement`

Expected: FAIL — promotion currently matches because merchant tokens leak into payment matching.

- [ ] **Step 3: Remove the merchant→payment bridge**

In `DecisionEngine.java` line 1287, delete:

```java
        normalizedPaymentMethods.addAll(normalizedMerchantTokens);
```

The block becomes:

```java
        Set<String> normalizedPaymentMethods = expandPaymentMethods(request.getResolvedPaymentMethod());
        if (normalizedPaymentMethods.isEmpty()) {
            return false;
        }
```

- [ ] **Step 4: Run all DecisionEngine tests**

Run: `cd cardsense-api && ./gradlew test --tests DecisionEngineTest`

Expected: PASS — new test + every existing test still green.

If any existing tests break, audit them: a test that was relying on merchant-as-payment behavior was testing the bug, not a feature. Update the test to use `resolvedPaymentMethod` correctly.

- [ ] **Step 5: Commit**

```bash
git -C cardsense-api add src/main/java/com/cardsense/api/service/DecisionEngine.java src/test/java/com/cardsense/api/service/DecisionEngineTest.java
git -C cardsense-api commit -m "fix(engine): stop treating merchant input as a payment method"
```

---

## Task 3: Remove payment-method entries from merchant-registry.json

**Files:**
- Modify: `cardsense-contracts/taxonomy/merchant-registry.json`

**Context:** Lines 1823-1916 of `merchant-registry.json` list LINE_PAY, APPLE_PAY, GOOGLE_PAY, SAMSUNG_PAY, JKOPAY, ESUN_WALLET, PX_PAY, EASY_WALLET, ICASH_PAY, IPASS_MONEY as merchant entries (subcategory MOBILE_PAY). They're already in `payment-registry.json` — duplicate registration violates single source of truth and enables the bug fixed in Task 2.

- [ ] **Step 1: Confirm payment-registry.json contains all entries before deletion**

Read `cardsense-contracts/taxonomy/payment-registry.json` and verify it includes: LINE_PAY, APPLE_PAY, GOOGLE_PAY, SAMSUNG_PAY, JKOPAY, ESUN_WALLET, PX_PAY, EASY_WALLET, ICASH_PAY, IPASS_MONEY. If any missing, copy from merchant-registry first (to payment-registry).

- [ ] **Step 2: Delete the 10 payment-method entries from merchant-registry.json**

Remove the entries with `subcategory: "MOBILE_PAY"`. After edit, the merchant-registry should contain ZERO entries with `subcategory: "MOBILE_PAY"`. Verify with:

```bash
grep -c '"MOBILE_PAY"' cardsense-contracts/taxonomy/merchant-registry.json
```

Expected output: `0`

- [ ] **Step 3: Run contracts validation**

Run: `cd cardsense-contracts && npm test` (or whatever `package.json` script validates the taxonomy JSON)

Expected: PASS — merchant-registry still valid JSON, no schema regressions.

- [ ] **Step 4: Run full extractor test suite**

Run: `cd cardsense-extractor && python -m pytest`

Expected: PASS — extractor's merchant-registry consumers still work (because LINE_PAY etc. still exist in payment-registry).

- [ ] **Step 5: Commit**

```bash
git -C cardsense-contracts add taxonomy/merchant-registry.json
git -C cardsense-contracts commit -m "chore(taxonomy): remove duplicate payment-method entries from merchant-registry"
```

---

## Task 4: Tag Unicard merchant clusters with mobile-payment exclusion

**Files:**
- Modify: `cardsense-extractor/extractor/esun_real.py:832-895` (_build_unicard_hundred_store_promotions_for_cluster)
- Test: `cardsense-extractor/tests/test_esun_hundred_store.py`

**Context:** Per Unicard rule, paying via mobile payment at any 百大特店 (e.g., 全聯) reclassifies the transaction to the 行動支付 cluster. We model this with `excludedConditions` on every non-mobile-payment cluster: when payment matches any of the 8 mobile pay tools, the merchant cluster is excluded, and only the MOBILE_PAY cluster matches. With Task 1 in place, the engine will honor this.

- [ ] **Step 1: Define the mobile-payment exclusion list at module top**

We rely on Task 1's MOBILE_PAY aggregate expansion in the engine — a single `MOBILE_PAY` exclusion auto-matches all 8 individual mobile-pay tools. Add near line 67 in `esun_real.py` (just before `UNICARD_PLAN_CONDITIONS`):

```python
UNICARD_MOBILE_PAY_EXCLUSIONS: tuple[dict[str, str], ...] = (
    {"type": "PAYMENT", "value": "MOBILE_PAY", "label": "行動支付"},
)
```

- [ ] **Step 2: Write the failing test**

Add to `tests/test_esun_hundred_store.py`:

```python
def test_unicard_supermarket_cluster_excludes_mobile_payments():
    """SUPERMARKET cluster should mark mobile-pay tools as excluded
    so that paying with LINE Pay at 全聯 reclassifies to MOBILE_PAY cluster."""
    promos = build_unicard_promotions_for_test()  # use existing fixture
    super_promos = [p for p in promos if p["subcategory"] == "SUPERMARKET"]
    assert super_promos, "expected at least one SUPERMARKET cluster promotion"

    for p in super_promos:
        excluded_payment_values = {
            c["value"] for c in p["excludedConditions"] if c["type"] == "PAYMENT"
        }
        assert "MOBILE_PAY" in excluded_payment_values, \
            "expected MOBILE_PAY aggregate exclusion (engine expands to all 8 tools)"


def test_unicard_mobile_pay_cluster_has_no_self_exclusion():
    """The 行動支付 cluster itself must NOT exclude mobile payments."""
    promos = build_unicard_promotions_for_test()
    mobile_promos = [p for p in promos if "行動支付" in p["title"]]
    assert mobile_promos
    for p in mobile_promos:
        assert p["excludedConditions"] == [], \
            "MOBILE_PAY cluster must not have any payment exclusions"
```

(Helper `build_unicard_promotions_for_test` should call `_build_unicard_hundred_store_promotions_for_cluster` with realistic args; reuse fixtures from existing tests.)

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd cardsense-extractor && python -m pytest tests/test_esun_hundred_store.py::test_unicard_supermarket_cluster_excludes_mobile_payments -v`

Expected: FAIL — `excludedConditions` is empty.

- [ ] **Step 4: Implement the exclusion in the cluster builder**

In `esun_real.py`, modify `_build_unicard_hundred_store_promotions_for_cluster` (around lines 866-894 where each promotion dict is built). Replace `"excludedConditions": [],` with:

```python
            "excludedConditions": (
                [] if condition_type == "PAYMENT"
                else [dict(c) for c in UNICARD_MOBILE_PAY_EXCLUSIONS]
            ),
```

(LOCATION_ONLY i.e. 國外實體 also keeps `[]` — overseas physical stores have no domestic-mobile-pay reclassification rule. The condition `if condition_type == "PAYMENT"` only excludes the 行動支付 cluster itself.)

Wait — `condition_type == "LOCATION_ONLY"` should also be `[]`. Update the conditional:

```python
            "excludedConditions": (
                [] if condition_type in ("PAYMENT", "LOCATION_ONLY")
                else [dict(c) for c in UNICARD_MOBILE_PAY_EXCLUSIONS]
            ),
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd cardsense-extractor && python -m pytest tests/test_esun_hundred_store.py -v`

Expected: PASS — both new tests + every existing Unicard test.

- [ ] **Step 6: Run full extractor test suite (regression check)**

Run: `cd cardsense-extractor && python -m pytest`

Expected: PASS — no regressions in other extractors.

- [ ] **Step 7: Commit**

```bash
git -C cardsense-extractor add extractor/esun_real.py tests/test_esun_hundred_store.py
git -C cardsense-extractor commit -m "feat(unicard): mark mobile-pay exclusion on 百大特店 clusters per bank reclassify rule"
```

---

## Task 5: Add API integration test for Unicard reclassify scenario

**Files:**
- Test: `cardsense-api/src/test/java/com/cardsense/api/service/DecisionEngineTest.java`

**Context:** End-to-end check that the schema → extractor → engine pipeline produces correct behavior for the canonical scenario from the bug report: 全聯 + LINE Pay must NOT trigger SUPERMARKET cluster (3%); only MOBILE_PAY cluster (3%) matches.

- [ ] **Step 1: Write the integration test**

Add to `DecisionEngineTest.java`:

```java
@Test
void unicardReclassifyRule_pxmartWithLinePay_excludesSupermarketCluster() {
    Promotion supermarketCluster = basePromotion()
            .cardCode("ESUN_UNICARD")
            .planId("ESUN_UNICARD_SIMPLE")
            .subcategory("SUPERMARKET")
            .cashbackValue(BigDecimal.valueOf(3.0))
            .conditions(List.of(condition("VENUE", "PXMART", "全聯")))
            .excludedConditions(List.of(
                    condition("PAYMENT", "LINE_PAY", "LINE Pay"),
                    condition("PAYMENT", "MOBILE_PAY", "行動支付")))
            .build();
    Promotion mobilePayCluster = basePromotion()
            .cardCode("ESUN_UNICARD")
            .planId("ESUN_UNICARD_SIMPLE")
            .subcategory("MOBILE_PAY")
            .cashbackValue(BigDecimal.valueOf(3.0))
            .conditions(List.of(condition("PAYMENT", "MOBILE_PAY", "行動支付"),
                                condition("PAYMENT", "LINE_PAY", "LINE Pay")))
            .build();

    RecommendationRequest req = RecommendationRequest.builder()
            .resolvedMerchantName("全聯")
            .resolvedPaymentMethod("LINE Pay")
            .resolvedCardCodes(List.of("ESUN_UNICARD"))
            .build();

    DecisionResult result = engine.decide(List.of(supermarketCluster, mobilePayCluster), req);

    assertThat(result.getMatched()).hasSize(1);
    assertThat(result.getMatched().get(0).getSubcategory()).isEqualTo("MOBILE_PAY");
}
```

- [ ] **Step 2: Run the test**

Run: `cd cardsense-api && ./gradlew test --tests DecisionEngineTest.unicardReclassifyRule_pxmartWithLinePay_excludesSupermarketCluster`

Expected: PASS (because Tasks 1 & 2 already wired up the engine).

- [ ] **Step 3: Commit**

```bash
git -C cardsense-api add src/test/java/com/cardsense/api/service/DecisionEngineTest.java
git -C cardsense-api commit -m "test(engine): integration test for Unicard mobile-pay reclassify rule"
```

---

## Task 6: Add Richart 7-11/全家 payment-gate (TAISHIN_RICHART_DAILY)

**Files:**
- Modify: `cardsense-extractor/extractor/taishin_real.py:113-117` (RICHART_PLAN_CONDITIONS)
- Test: `cardsense-extractor/tests/test_richart.py` (or equivalent)

**Context:** Per Richart rule, 7-11/全家 in 天天刷 plan only earn the bonus when paid with TAISHIN_PAY. Other mobile pays (LINE Pay, OPEN 錢包, FamiPay, 全盈) are excluded. Currently `RICHART_PLAN_CONDITIONS["TAISHIN_RICHART_DAILY", "SUPERMARKET"]` only has VENUE conditions — no payment gate.

Note: this only adds the gate where the plan-condition mapping fires for convenience-store promotions. We need to verify which subcategory actually corresponds to 7-11/全家 — likely `CONVENIENCE_STORE` not `SUPERMARKET`. **Sub-task 6.0 below verifies this first.**

- [ ] **Step 0: Verify the convenience-store subcategory key used by Richart promotions**

```bash
cd cardsense-extractor && python -c "from extractor.taishin_real import RICHART_PLAN_CONDITIONS; print(list(RICHART_PLAN_CONDITIONS.keys()))"
```

Also check what subcategory is assigned to 7-11/全家 promotions emitted by the Taishin extractor — grep for `CONVENIENCE_STORE`, `SEVEN_ELEVEN`, `FAMILY_MART` in `taishin_real.py`. Record findings before continuing.

If no `CONVENIENCE_STORE` mapping exists, you'll need to add a new key `("TAISHIN_RICHART_DAILY", "CONVENIENCE_STORE")` plus the routing logic that uses it. This may grow the task — escalate if so.

- [ ] **Step 1: Write the failing test**

Add to the appropriate Richart test file:

```python
def test_richart_daily_711_promotion_requires_taishin_pay():
    """Richart 天天刷 7-11/全家 promotion must include PAYMENT=TAISHIN_PAY
    in its conditions per bank rule."""
    promos = build_richart_daily_promotions_for_test()
    seven_eleven_promos = [
        p for p in promos
        if any(c["type"] == "VENUE" and c["value"] == "SEVEN_ELEVEN" for c in p["conditions"])
    ]
    assert seven_eleven_promos, "expected at least one 7-11 Richart promotion"

    for p in seven_eleven_promos:
        payment_values = {c["value"] for c in p["conditions"] if c["type"] == "PAYMENT"}
        assert "TAISHIN_PAY" in payment_values, \
            f"7-11 Richart promo missing TAISHIN_PAY gate; conditions: {p['conditions']}"


def test_richart_daily_711_promotion_excludes_other_mobile_payments():
    promos = build_richart_daily_promotions_for_test()
    seven_eleven_promos = [
        p for p in promos
        if any(c["type"] == "VENUE" and c["value"] == "SEVEN_ELEVEN" for c in p["conditions"])
    ]
    for p in seven_eleven_promos:
        excluded_payment_values = {
            c["value"] for c in p["excludedConditions"] if c["type"] == "PAYMENT"
        }
        assert "LINE_PAY" in excluded_payment_values
        assert "JKOPAY" in excluded_payment_values
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd cardsense-extractor && python -m pytest tests/ -k richart_daily_711 -v`

Expected: FAIL.

- [ ] **Step 3: Add the payment-gate mapping**

In `taishin_real.py`, add a new entry to `RICHART_PLAN_CONDITIONS` (around line 113):

```python
    ("TAISHIN_RICHART_DAILY", "CONVENIENCE_STORE"): (
        {"type": "VENUE", "value": "SEVEN_ELEVEN", "label": "7-ELEVEN"},
        {"type": "VENUE", "value": "FAMILY_MART", "label": "全家"},
        {"type": "PAYMENT", "value": "TAISHIN_PAY", "label": "台新Pay"},
    ),
```

If Step 0 found that the subcategory key is different (e.g. `SUPERMARKET`), use that key instead. If the existing mapping for SUPERMARKET also covers 7-11/全家, add the PAYMENT condition there.

Also add an `excludedConditions` source for non-台新Pay mobile pays. Add near top of file (line ~44 after RICHART_EXCLUDED_ACTIVITY_TOKENS):

```python
RICHART_DAILY_711_PAYMENT_EXCLUSIONS: tuple[dict[str, str], ...] = (
    {"type": "PAYMENT", "value": "LINE_PAY", "label": "LINE Pay"},
    {"type": "PAYMENT", "value": "JKOPAY", "label": "街口支付"},
    {"type": "PAYMENT", "value": "OPEN_WALLET", "label": "OPEN 錢包"},
    {"type": "PAYMENT", "value": "FAMIPAY", "label": "FamiPay"},
    {"type": "PAYMENT", "value": "PLUS_PAY", "label": "全盈+PAY"},
)
```

Then in the promotion-building path that emits 7-11/全家 promos, set `excludedConditions` to a copy of this tuple. (Locate the builder by grepping for `SEVEN_ELEVEN` or `7-ELEVEN` in `taishin_real.py`. If the path is shared with non-7-11 promos, add a conditional only for convenience stores under TAISHIN_RICHART_DAILY.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd cardsense-extractor && python -m pytest tests/ -k richart -v`

Expected: PASS.

- [ ] **Step 5: Run full extractor suite**

Run: `cd cardsense-extractor && python -m pytest`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git -C cardsense-extractor add extractor/taishin_real.py tests/
git -C cardsense-extractor commit -m "feat(richart): gate 天天刷 7-11/全家 on TAISHIN_PAY per bank rule"
```

---

## Task 7: Pattern C — FUBON_MOMO third-party-payment downgrade

**Files:**
- Modify: `cardsense-extractor/extractor/fubon_real.py` (around line 603 — FUBON_MOMO branch)
- Test: `cardsense-extractor/tests/test_fubon_real.py`

**Context:** Per bank rule, paying via third-party payment (LINE Pay, 街口) on FUBON_MOMO at momo platform "視為一般消費 1%". The high-rate momo promotion must be excluded when the user pays via third-party payment. The base 1% general-consumption promotion (assumed to exist for FUBON_MOMO) will then be the only matcher.

Note: "third-party payment" (第三方支付) in this rule is narrower than MOBILE_PAY aggregate — it covers LINE_PAY, JKOPAY, PX_PAY, EASY_WALLET (wallet-style apps that aggregate cards), but typically NOT contactless wallets like APPLE_PAY/GOOGLE_PAY/SAMSUNG_PAY (which transmit the actual card directly). We list the 4 third-party values explicitly to avoid over-excluding.

- [ ] **Step 1: Define third-party payment exclusion constant**

Near the top of `fubon_real.py` (after existing module constants), add:

```python
FUBON_MOMO_THIRD_PARTY_PAYMENT_EXCLUSIONS: tuple[dict[str, str], ...] = (
    {"type": "PAYMENT", "value": "LINE_PAY", "label": "LINE Pay"},
    {"type": "PAYMENT", "value": "JKOPAY", "label": "街口支付"},
    {"type": "PAYMENT", "value": "PX_PAY", "label": "全支付"},
    {"type": "PAYMENT", "value": "EASY_WALLET", "label": "悠遊付"},
)
```

- [ ] **Step 2: Write the failing test**

Add to `tests/test_fubon_real.py`:

```python
def test_fubon_momo_high_rate_promotion_excludes_third_party_payments():
    """FUBON_MOMO momo-platform high-rate promo must exclude LINE Pay / 街口
    so transactions paid via third-party fall back to general 1%."""
    promos = build_fubon_momo_promotions_for_test()  # use existing fixture
    momo_high_rate = [
        p for p in promos
        if any(c["type"] == "VENUE" and c["value"] == "MOMO" for c in p["conditions"])
        and p.get("cashbackValue", 0) > 1.0
    ]
    assert momo_high_rate, "expected at least one high-rate momo promotion"
    for p in momo_high_rate:
        excluded_payment_values = {
            c["value"] for c in p["excludedConditions"] if c["type"] == "PAYMENT"
        }
        assert "LINE_PAY" in excluded_payment_values
        assert "JKOPAY" in excluded_payment_values


def test_fubon_momo_high_rate_promotion_does_not_exclude_contactless_wallets():
    """Apple Pay / Google Pay / Samsung Pay are NOT third-party payments
    and must not be excluded — they transmit the underlying card directly."""
    promos = build_fubon_momo_promotions_for_test()
    momo_high_rate = [
        p for p in promos
        if any(c["type"] == "VENUE" and c["value"] == "MOMO" for c in p["conditions"])
        and p.get("cashbackValue", 0) > 1.0
    ]
    for p in momo_high_rate:
        excluded_payment_values = {
            c["value"] for c in p["excludedConditions"] if c["type"] == "PAYMENT"
        }
        assert "APPLE_PAY" not in excluded_payment_values
        assert "GOOGLE_PAY" not in excluded_payment_values
        assert "SAMSUNG_PAY" not in excluded_payment_values
        # MOBILE_PAY aggregate would over-exclude — must not be present
        assert "MOBILE_PAY" not in excluded_payment_values
```

If `build_fubon_momo_promotions_for_test` doesn't exist, define a minimal fixture that calls the relevant FUBON_MOMO promotion-building path with synthesized inputs. Reuse fixtures from existing fubon tests.

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd cardsense-extractor && python -m pytest tests/test_fubon_real.py -k third_party -v`

Expected: FAIL — `excludedConditions` empty.

- [ ] **Step 4: Wire in the exclusion**

Locate the FUBON_MOMO promotion-building path. Looking at `fubon_real.py:603`, the `card_code == "FUBON_MOMO"` branch in the rule classifier returns `(category, subcategory, channel, recommendation_scope, merged_conditions)` — note it doesn't return `excludedConditions`. The exclusion must be added downstream where the final promotion dict is constructed.

Search for where FUBON_MOMO promotions are emitted as dicts (grep for `"cardCode": "FUBON_MOMO"` or `card.card_code == "FUBON_MOMO"` in the dict-building section). At that point, add:

```python
if card_code == "FUBON_MOMO" and any(
    c.get("type") == "VENUE" and c.get("value") == "MOMO" for c in conditions
):
    excluded_conditions = [dict(c) for c in FUBON_MOMO_THIRD_PARTY_PAYMENT_EXCLUSIONS]
else:
    excluded_conditions = []
```

If the existing code already passes `excludedConditions` from elsewhere, merge rather than overwrite.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd cardsense-extractor && python -m pytest tests/test_fubon_real.py -v`

Expected: PASS — both new tests + every existing fubon test.

- [ ] **Step 6: Run full extractor suite**

Run: `cd cardsense-extractor && python -m pytest`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git -C cardsense-extractor add extractor/fubon_real.py tests/test_fubon_real.py
git -C cardsense-extractor commit -m "feat(fubon-momo): exclude third-party payments from momo high-rate promo per bank rule"
```

---

## Task 8: Pattern D — FUBON_DIGITALLIFE channel-rail enforcement

**Files:**
- Modify: `cardsense-extractor/extractor/fubon_real.py` (FUBON_DIGITALLIFE 2% promotion build path)
- Test: `cardsense-extractor/tests/test_fubon_real.py`
- (Optional) Modify: `cardsense-api/src/main/java/com/cardsense/api/service/DecisionEngine.java` (channel resolution audit)

**Context:** Per bank rule, 富邦數位生活卡 ONLINE 2% reward does NOT apply when user pays Apple Pay/Google Pay/Samsung Pay 在實體店面 (physical store). The promotion already has `channel: "ONLINE"` so it should not match physical-store transactions in theory — but the bug surfaces when the request's `resolvedChannel` is incorrectly inferred as ONLINE just because the payment method is mobile-pay.

We solve this defensively at two layers: (1) add `excludedConditions` of type `CATEGORY_EXCLUDE` listing physical-only categories on the digital-life ONLINE 2% promo, so even if channel is mis-resolved the wrong-merchant transaction gets filtered out; (2) verify the engine's channel resolution doesn't promote mobile-pay to ONLINE (it shouldn't — channel is taken from request — but we add a regression test).

- [ ] **Step 1: Audit channel resolution in DecisionEngine**

Read `DecisionEngine.java` lines 1226-1238 (`matchesChannel`) and search for any place where payment method influences channel. Run:

```bash
grep -n "channel" cardsense-api/src/main/java/com/cardsense/api/service/DecisionEngine.java | grep -i "payment\|mobile\|wallet"
```

Expected: no hits. If any code derives channel from payment method, escalate (BLOCKED) — that's a separate refactor.

- [ ] **Step 2: Define physical-merchant category exclusions**

Near top of `fubon_real.py`:

```python
FUBON_DIGITALLIFE_PHYSICAL_CATEGORY_EXCLUSIONS: tuple[dict[str, str], ...] = (
    {"type": "CATEGORY_EXCLUDE", "value": "GROCERY", "label": "實體生活採買"},
    {"type": "CATEGORY_EXCLUDE", "value": "DINING", "label": "實體餐飲"},
    {"type": "CATEGORY_EXCLUDE", "value": "TRANSPORT", "label": "實體交通加油"},
    {"type": "CATEGORY_EXCLUDE", "value": "SHOPPING", "label": "實體百貨/超商"},
)
```

(These are categories whose merchants are predominantly physical. ONLINE-typed shopping like e-commerce is `category: ONLINE`, not `SHOPPING`.)

- [ ] **Step 3: Write the failing test**

Add to `tests/test_fubon_real.py`:

```python
def test_fubon_digitallife_online_promo_excludes_physical_categories():
    """FUBON_DIGITALLIFE ONLINE 2% promo must mark physical merchant categories
    as excluded so Apple Pay at 7-11 doesn't accidentally trigger the digital reward."""
    promos = build_fubon_digitallife_promotions_for_test()
    online_promos = [
        p for p in promos
        if p.get("channel") == "ONLINE" and p.get("cardCode") == "FUBON_DIGITALLIFE"
        and abs(float(p.get("cashbackValue", 0)) - 2.0) < 0.01
    ]
    assert online_promos, "expected the FUBON_DIGITALLIFE 2% online promotion"
    for p in online_promos:
        excluded_categories = {
            c["value"] for c in p["excludedConditions"] if c["type"] == "CATEGORY_EXCLUDE"
        }
        assert "GROCERY" in excluded_categories
        assert "DINING" in excluded_categories
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd cardsense-extractor && python -m pytest tests/test_fubon_real.py -k digitallife -v`

Expected: FAIL.

- [ ] **Step 5: Wire in the exclusion**

Locate the FUBON_DIGITALLIFE 2% promotion build path (grep for `FUBON_DIGITALLIFE` in `fubon_real.py`). At the dict-construction site, when `cardCode == "FUBON_DIGITALLIFE"` AND `channel == "ONLINE"` AND cashbackValue is the 2% tier, set:

```python
excluded_conditions = [dict(c) for c in FUBON_DIGITALLIFE_PHYSICAL_CATEGORY_EXCLUSIONS]
```

Merge with any existing `excludedConditions` rather than overwrite.

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd cardsense-extractor && python -m pytest tests/test_fubon_real.py -v`

Expected: PASS.

- [ ] **Step 7: Add API integration test**

Add to `DecisionEngineTest.java`:

```java
@Test
void fubonDigitalLifeOnlineRewardExcludesPhysicalMerchants() {
    Promotion digitalLifeOnline = basePromotion()
            .cardCode("FUBON_DIGITALLIFE")
            .channel("ONLINE")
            .cashbackValue(BigDecimal.valueOf(2.0))
            .conditions(List.of())
            .excludedConditions(List.of(
                    condition("CATEGORY_EXCLUDE", "GROCERY", "實體生活採買"),
                    condition("CATEGORY_EXCLUDE", "DINING", "實體餐飲")))
            .build();

    RecommendationRequest req = RecommendationRequest.builder()
            .resolvedMerchantName("7-ELEVEN")
            .resolvedCategory("GROCERY")
            .resolvedPaymentMethod("Apple Pay")
            .resolvedChannel("ONLINE")  // wrong-resolved channel
            .resolvedCardCodes(List.of("FUBON_DIGITALLIFE"))
            .build();

    DecisionResult result = engine.decide(List.of(digitalLifeOnline), req);
    assertThat(result.getMatched()).isEmpty();
}
```

- [ ] **Step 8: Run API tests**

Run: `cd cardsense-api && ./gradlew test --tests DecisionEngineTest.fubonDigitalLifeOnlineRewardExcludesPhysicalMerchants`

Expected: PASS (Task 1 already wired CATEGORY_EXCLUDE; this just verifies end-to-end).

- [ ] **Step 9: Commit (extractor)**

```bash
git -C cardsense-extractor add extractor/fubon_real.py tests/test_fubon_real.py
git -C cardsense-extractor commit -m "feat(fubon-digitallife): exclude physical categories from ONLINE 2% per bank rule"
```

- [ ] **Step 10: Commit (api)**

```bash
git -C cardsense-api add src/test/java/com/cardsense/api/service/DecisionEngineTest.java
git -C cardsense-api commit -m "test(engine): integration test for FUBON_DIGITALLIFE channel-rail rule"
```

---

## Task 9: Final regression sweep + verify with gstack against bank pages

**Files:** none

- [ ] **Step 1: Run all repo test suites**

```bash
cd cardsense-api && ./gradlew test
cd cardsense-extractor && python -m pytest
cd cardsense-contracts && npm test
```

Expected: ALL PASS.

- [ ] **Step 2: Spin up the API and run a smoke recommendation**

Start the API with the updated extractor JSON loaded. Hit `/recommendations` with payload:

```json
{
  "merchantName": "全聯",
  "paymentMethod": "LINE Pay",
  "amount": 1000
}
```

Expected response: Unicard MOBILE_PAY plan recommendations, NOT SUPERMARKET plan. Save response to `/tmp/unicard-smoke.json`.

- [ ] **Step 3: Use gstack to capture official rule pages as evidence**

```bash
cd cardsense-api/.claude/skills/gstack && ./setup   # one-time
$B goto https://event.esunbank.com.tw/credit/unicard/discount-channel.html
$B screenshot /tmp/unicard-rule.png
$B goto https://richart.tw/RichartWeb/CreditCard
$B screenshot /tmp/richart-rule.png
```

Read both screenshots and confirm the wording matches the citations in this plan's header.

- [ ] **Step 4: Commit nothing; report results**

No code changes in this task. Report STATUS: DONE with smoke-test response and screenshot evidence.

---

## Self-Review Checklist (controller runs this before dispatching)

- **Spec coverage:** Pattern A (Unicard) → Task 4 + integration Task 5; Pattern B (Richart gate) → Task 6; Pattern C (FUBON_MOMO) → Task 7; Pattern D (FUBON_DIGITALLIFE) → Task 8. Task 1 enables engine logic for all 4. Task 2 fixes the merchant→payment leak. Task 3 cleans the registry. Task 9 verifies end-to-end. ✓
- **Schema unchanged** — header confirms; current `conditions[]` + `excludedConditions[]` express all 4 patterns. ✓
- **Type consistency:** Condition keys use `type/value/label` everywhere. Method names match Java codebase (`getExcludedConditions`, `expandPaymentMethods`, `matchesChannel`). ✓
- **Each task self-contained:** Each ends with a commit. Tasks 1–3 unblock 4–8. Task 6 has Step 0 (verify-before-act). Tasks 7–8 each verify their fixture exists before testing. ✓
- **Aggregate vs explicit exclusions** — Task 4 (Unicard) uses MOBILE_PAY aggregate (all 8 mobile pays); Task 7 (FUBON_MOMO) uses explicit 4-payment list (third-party only); Task 8 (FUBON_DIGITALLIFE) uses CATEGORY_EXCLUDE not PAYMENT. Each matches the bank's specific rule. ✓

---

## Execution Notes

- Each repo (cardsense-api, cardsense-extractor, cardsense-contracts) is a separate git repo on `master`. Create feature branches per repo at task start: `feat/payment-classification`. No worktrees needed (commits stay on the feature branch in each repo).
- Implementer subagents should NOT cross repos in a single task — each task touches one repo, plus an optional follow-up commit in another repo if the spec calls for it.
- Subagents should announce STATUS: DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT at the end of every task.
