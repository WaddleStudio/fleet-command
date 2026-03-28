# Recommendation Enhancement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enhance CardSense with eligibility filtering, platform-specific conditions, catalog filters, card detail promotions, and remove ComparisonMode.

**Architecture:** Six changes across backend domain/service/controller layers and frontend pages/components. Changes are ordered to avoid broken intermediate states: data model first, engine logic second, API third, frontend last.

**Tech Stack:** Java 21 / Spring Boot / Lombok (backend), React 19 / TypeScript / TailwindCSS / shadcn/ui (frontend)

---

### Task 1: Remove ComparisonMode — Backend

Remove `ComparisonMode` enum and all references. The engine will always use the stacking path.

**Files:**
- Delete: `cardsense-api/src/main/java/com/cardsense/api/domain/ComparisonMode.java`
- Modify: `cardsense-api/src/main/java/com/cardsense/api/service/DecisionEngine.java`
- Modify: `cardsense-api/src/main/java/com/cardsense/api/domain/RecommendationRequest.java:92-97`
- Modify: `cardsense-api/src/main/java/com/cardsense/api/domain/RecommendationComparisonOptions.java:15`
- Modify: `cardsense-api/src/main/java/com/cardsense/api/domain/RecommendationComparisonSummary.java:15`
- Modify: `cardsense-api/src/main/java/com/cardsense/api/domain/CardRecommendation.java:25`
- Test: `cardsense-api/src/test/java/com/cardsense/api/service/DecisionEngineTest.java`

**Step 1: Update tests first**

Remove all `ComparisonMode` imports and references from `DecisionEngineTest.java`:
- Remove `import com.cardsense.api.domain.ComparisonMode;`
- In `testRecommendReturnsSortedTopCards`: remove the assertion `assertEquals(ComparisonMode.BEST_SINGLE_PROMOTION, response.getComparison().getMode());`
- In `testRecommendStacksEligiblePromotionsWhenRequested`: remove `.mode(ComparisonMode.STACK_ALL_ELIGIBLE)` from comparison options, change assertion from `assertEquals("STACK_ALL_ELIGIBLE", ...)` to just verify `estimatedReturn` is correct
- In `testRecommendStacksOnlyMetadataCompatiblePromotions`: remove `.mode(ComparisonMode.STACK_ALL_ELIGIBLE)`
- In `testRecommendDoesNotStackMutuallyExclusivePromotions`: remove `.mode(ComparisonMode.STACK_ALL_ELIGIBLE)`
- In `testRecommendWithMoreThanFifteenPromotionsEvaluatesTopFiveNotJustFirstOne`: remove `.mode(ComparisonMode.STACK_ALL_ELIGIBLE)`
- `testRecommendKeepsOnlyBestPromotionPerCard`: this test now expects stacking behavior — the two promotions for the same card have no stackability metadata, so only the best one will be selected (same behavior). Verify assertions still hold.

**Step 2: Run tests to verify they fail**

Run: `cd cardsense-api && mvn test -pl . -Dtest=DecisionEngineTest -q`
Expected: Compilation errors due to ComparisonMode still existing but test code changed

**Step 3: Delete ComparisonMode.java**

Delete: `cardsense-api/src/main/java/com/cardsense/api/domain/ComparisonMode.java`

**Step 4: Update RecommendationComparisonOptions — remove mode field**

In `RecommendationComparisonOptions.java`, remove:
```java
private ComparisonMode mode;
```

**Step 5: Update RecommendationRequest — remove getResolvedComparisonMode**

In `RecommendationRequest.java`, remove the `getResolvedComparisonMode()` method (lines 91-97). Remove `import com.cardsense.api.domain.ComparisonMode;` if present.

**Step 6: Update RecommendationComparisonSummary — change mode to String**

In `RecommendationComparisonSummary.java`:
```java
// Remove: private ComparisonMode mode;
// Add:    private String mode;
```

**Step 7: Update CardRecommendation — remove rankingMode field**

In `CardRecommendation.java`, remove:
```java
private String rankingMode;
```

**Step 8: Update DecisionEngine — remove all ComparisonMode branching**

In `DecisionEngine.java`:

a) Remove `import com.cardsense.api.domain.ComparisonMode;`

b) In `recommend()` method (line 44): remove `ComparisonMode comparisonMode = request.getResolvedComparisonMode();`

c) In `recommend()` line 59: change `toCardAggregate(promotions, comparisonMode)` to `toCardAggregate(promotions)`

d) In `recommend()` line 65: change `toRecommendation(cardAggregate, comparisonMode, ...)` to `toRecommendation(cardAggregate, ...)`

e) In `recommend()` line 75: change `buildComparisonSummary(comparisonMode, ...)` to `buildComparisonSummary(...)`

f) In `toCardAggregate()` (line 172): remove `ComparisonMode comparisonMode` parameter. Always run `resolveContributingPromotions(promotions)`:
```java
private CardAggregate toCardAggregate(List<ScoredPromotion> promotions) {
    List<String> notes = new ArrayList<>();
    StackResolution resolution = resolveContributingPromotions(promotions);
    List<ScoredPromotion> contributingPromotions = resolution.contributingPromotions();
    notes.addAll(resolution.notes());

    ScoredPromotion primary = contributingPromotions.get(0);
    int totalReturn = contributingPromotions.stream().mapToInt(ScoredPromotion::cappedReturn).sum();

    return new CardAggregate(primary.promotion(), promotions, contributingPromotions, totalReturn, notes);
}
```

g) In `toRecommendation()` (line 379): remove `ComparisonMode comparisonMode` parameter. Update reason string to always use stacking format when >1 contributing promotions:
```java
private CardRecommendation toRecommendation(CardAggregate cardAggregate, boolean includePromotionBreakdown) {
    Promotion promotion = cardAggregate.primaryPromotion();
    List<PromotionCondition> recommendationConditions = buildRecommendationConditions(promotion);
    String cashbackValueText = promotion.getCashbackValue() == null
            ? "0"
            : promotion.getCashbackValue().stripTrailingZeros().toPlainString();
    String reason = cardAggregate.contributingPromotions().size() > 1
            ? String.format(
            "%s %s — %d 個可命中的優惠合計預估回饋 $%d 元；代表優惠為 %s%s，優惠至 %s",
            promotion.getBankName(),
            promotion.getCardName(),
            cardAggregate.contributingPromotions().size(),
            cardAggregate.totalReturn(),
            cashbackValueText,
            resolveCashbackSuffix(promotion.getCashbackType()),
            promotion.getValidUntil())
            : String.format(
            "%s %s — %s 消費享 %s%s 回饋，預估回饋 $%d 元，優惠至 %s",
            promotion.getBankName(),
            promotion.getCardName(),
            promotion.getCategory(),
            cashbackValueText,
            resolveCashbackSuffix(promotion.getCashbackType()),
            cardAggregate.totalReturn(),
            promotion.getValidUntil());

    List<PromotionRewardBreakdown> breakdown = includePromotionBreakdown
            ? buildPromotionBreakdown(cardAggregate)
            : List.of();

    return CardRecommendation.builder()
            .cardCode(promotion.getCardCode())
            .cardName(promotion.getCardName())
            .bankCode(promotion.getBankCode())
            .bankName(promotion.getBankName())
            .cashbackType(promotion.getCashbackType())
            .cashbackValue(promotion.getCashbackValue())
            .estimatedReturn(cardAggregate.totalReturn())
            .matchedPromotionCount(cardAggregate.allEligiblePromotions().size())
            .reason(reason)
            .promotionId(promotion.getPromoId())
            .promoVersionId(promotion.getPromoVersionId())
            .validUntil(promotion.getValidUntil())
            .conditions(recommendationConditions)
            .promotionBreakdown(breakdown)
            .applyUrl(promotion.getApplyUrl())
            .build();
}
```

h) In `buildPromotionBreakdown()` (line 429): remove `ComparisonMode comparisonMode` parameter. Update `buildBreakdownReason` calls:
```java
private List<PromotionRewardBreakdown> buildPromotionBreakdown(CardAggregate cardAggregate) {
    return cardAggregate.allEligiblePromotions().stream()
            .map(scoredPromotion -> {
                Promotion promotion = scoredPromotion.promotion();
                boolean contributes = cardAggregate.contributingPromotions().contains(scoredPromotion);
                return PromotionRewardBreakdown.builder()
                        .promotionId(promotion.getPromoId())
                        .promoVersionId(promotion.getPromoVersionId())
                        .title(promotion.getTitle())
                        .cashbackType(promotion.getCashbackType())
                        .cashbackValue(promotion.getCashbackValue())
                        .estimatedReturn(scoredPromotion.estimatedReturn())
                        .cappedReturn(scoredPromotion.cappedReturn())
                        .contributesToCardTotal(contributes)
                        .assumedStackable(false)
                        .validUntil(promotion.getValidUntil())
                        .conditions(buildRecommendationConditions(promotion))
                        .reason(buildBreakdownReason(cardAggregate, scoredPromotion, contributes))
                        .build();
            })
            .toList();
}
```

i) In `buildBreakdownReason()` (line 452): remove `ComparisonMode comparisonMode` parameter:
```java
private String buildBreakdownReason(
    CardAggregate cardAggregate,
    ScoredPromotion scoredPromotion,
    boolean contributes
) {
    if (cardAggregate.contributingPromotions().size() > 1) {
        return contributes
            ? "依 stackability metadata 判定可計入卡片總回饋。"
            : "未納入卡片總回饋：缺少 stackability metadata、未滿足 requires 條件，或與已選優惠互斥。";
    }

    return String.format(
        "%s：預估回饋 $%d 元，封頂後 $%d 元。",
        contributes ? "計入卡片總回饋" : "僅作為比較參考",
        scoredPromotion.estimatedReturn(),
        scoredPromotion.cappedReturn());
}
```

j) In `buildComparisonSummary()` (line 610): remove `ComparisonMode comparisonMode` parameter. Always add stackability note. Set mode to fixed string:
```java
private RecommendationComparisonSummary buildComparisonSummary(
        int evaluatedPromotionCount,
        int eligiblePromotionCount,
        int rankedCardCount,
        List<BreakEvenAnalysis> breakEvenAnalyses
) {
    List<String> notes = new ArrayList<>();
    notes.add("多優惠並存模式已由 promotion.stackability 顯式 metadata 控制；未標註 metadata 的舊資料不得直接視為可並存。");
    if (breakEvenAnalyses.isEmpty()) {
        notes.add("本次比較沒有可計算的 FIXED vs PERCENT/POINTS break-even pair，或呼叫端未要求輸出 break-even 分析。");
    }

    return RecommendationComparisonSummary.builder()
            .mode("STACK_ALL_ELIGIBLE")
            .evaluatedPromotionCount(evaluatedPromotionCount)
            .eligiblePromotionCount(eligiblePromotionCount)
            .rankedCardCount(rankedCardCount)
            .breakEvenEvaluated(!breakEvenAnalyses.isEmpty())
            .breakEvenAnalyses(breakEvenAnalyses)
            .notes(notes)
            .build();
}
```

**Step 9: Run tests**

Run: `cd cardsense-api && mvn test -q`
Expected: All tests pass

**Step 10: Commit**

```bash
git add -A
git commit -m "refactor: remove ComparisonMode, always use stacking calculation"
```

---

### Task 2: Add eligibilityType to data model

**Files:**
- Modify: `cardsense-api/src/main/java/com/cardsense/api/domain/Promotion.java`
- Modify: `cardsense-api/src/main/java/com/cardsense/api/domain/CardSummary.java`
- Test: `cardsense-api/src/test/java/com/cardsense/api/service/DecisionEngineTest.java`
- Test: `cardsense-api/src/test/java/com/cardsense/api/service/CatalogServiceTest.java`

**Step 1: Write failing test — DecisionEngine excludes non-GENERAL cards**

Add to `DecisionEngineTest.java`:
```java
@Test
public void testRecommendExcludesNonGeneralEligibilityType() {
    Promotion generalPromo = buildPromotion("promo1", "ver1", "CTBC_CARD", "中國信託一般卡", "CTBC", "中國信託", BigDecimal.valueOf(3.0), 300, 1800, LocalDate.of(2026, 6, 30));
    generalPromo.setEligibilityType("GENERAL");

    Promotion professionPromo = buildPromotion("promo2", "ver2", "CTBC_DOCTOR", "中國信託醫師卡", "CTBC", "中國信託", BigDecimal.valueOf(5.0), 500, 0, LocalDate.of(2026, 6, 30));
    professionPromo.setEligibilityType("PROFESSION_SPECIFIC");

    Promotion businessPromo = buildPromotion("promo3", "ver3", "CTBC_BIZ", "中國信託商務卡", "CTBC", "中國信託", BigDecimal.valueOf(4.0), 400, 0, LocalDate.of(2026, 6, 30));
    businessPromo.setEligibilityType("BUSINESS");

    when(promotionRepository.findActivePromotions(any())).thenReturn(List.of(generalPromo, professionPromo, businessPromo));

    RecommendationResponse response = decisionEngine.recommend(RecommendationRequest.builder()
            .amount(1000)
            .category("ONLINE")
            .date(LocalDate.now())
            .build());

    assertEquals(1, response.getRecommendations().size());
    assertEquals("promo1", response.getRecommendations().get(0).getPromotionId());
}

@Test
public void testRecommendTreatsNullEligibilityTypeAsGeneral() {
    Promotion noTypePromo = buildPromotion("promo1", "ver1", "CTBC_CARD", "中國信託一般卡", "CTBC", "中國信託", BigDecimal.valueOf(3.0), 300, 1800, LocalDate.of(2026, 6, 30));
    // eligibilityType is null — should still be included

    when(promotionRepository.findActivePromotions(any())).thenReturn(List.of(noTypePromo));

    RecommendationResponse response = decisionEngine.recommend(RecommendationRequest.builder()
            .amount(1000)
            .category("ONLINE")
            .date(LocalDate.now())
            .build());

    assertEquals(1, response.getRecommendations().size());
}
```

**Step 2: Run tests to verify they fail**

Run: `cd cardsense-api && mvn test -Dtest=DecisionEngineTest -q`
Expected: FAIL — `setEligibilityType` does not exist

**Step 3: Add eligibilityType to Promotion.java**

After line 67 (`private String recommendationScope;`), add:
```java
private String eligibilityType;
```

**Step 4: Add eligibilityType to CardSummary.java**

After `private List<String> recommendationScopes;`, add:
```java
private String eligibilityType;
private List<String> availableCategories;
```

**Step 5: Add eligibility check to DecisionEngine**

In `DecisionEngine.java`, in `isEligible()` method, after the `isRecommendationScopeEligible` check (line 93), add:
```java
if (!isEligibilityTypeEligible(promotion)) {
    return false;
}
```

Add new private method:
```java
private boolean isEligibilityTypeEligible(Promotion promotion) {
    String eligibilityType = promotion.getEligibilityType();
    return eligibilityType == null
            || eligibilityType.isBlank()
            || "GENERAL".equalsIgnoreCase(eligibilityType);
}
```

**Step 6: Update CatalogService — populate new CardSummary fields**

In `CatalogService.java`, update `toCardSummary()`:
```java
private CardSummary toCardSummary(List<Promotion> promotions) {
    Promotion promotion = promotions.get(0);
    Set<String> scopes = promotions.stream()
            .map(Promotion::getRecommendationScope)
            .map(this::normalizeScope)
            .collect(java.util.stream.Collectors.toCollection(LinkedHashSet::new));

    List<String> categories = promotions.stream()
            .map(Promotion::getCategory)
            .filter(cat -> cat != null && !cat.isBlank())
            .map(cat -> cat.trim().toUpperCase(Locale.ROOT))
            .distinct()
            .sorted()
            .toList();

    return CardSummary.builder()
            .cardCode(promotion.getCardCode())
            .cardName(promotion.getCardName())
            .cardStatus(promotion.getCardStatus())
            .annualFee(promotion.getAnnualFee())
            .applyUrl(promotion.getApplyUrl())
            .bankCode(promotion.getBankCode())
            .bankName(promotion.getBankName())
            .recommendationScopes(List.copyOf(scopes))
            .eligibilityType(promotion.getEligibilityType() != null ? promotion.getEligibilityType() : "GENERAL")
            .availableCategories(categories)
            .build();
}
```

Update `listCards()` to support `eligibilityType` filter:
```java
public List<CardSummary> listCards(String bank, String status, String scope, String eligibilityType) {
    return promotionsByCard().values().stream()
            .map(this::toCardSummary)
            .filter(card -> matchesBank(card, bank))
            .filter(card -> matchesStatus(card.getCardStatus(), status))
            .filter(card -> matchesScope(card, scope))
            .filter(card -> matchesEligibilityType(card, eligibilityType))
            .sorted(Comparator.comparing(CardSummary::getBankCode, Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER))
                    .thenComparing(CardSummary::getCardCode, Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER)))
            .toList();
}

private boolean matchesEligibilityType(CardSummary card, String requestedType) {
    if (requestedType == null || requestedType.isBlank()) {
        return true;
    }
    return requestedType.equalsIgnoreCase(card.getEligibilityType());
}
```

Update `CardController.java` to pass the new parameter:
```java
@GetMapping
public ResponseEntity<List<CardSummary>> listCards(
        @RequestParam(required = false) String bank,
        @RequestParam(required = false) String status,
        @RequestParam(required = false) String scope,
        @RequestParam(required = false) String eligibilityType) {
    return ResponseEntity.ok(catalogService.listCards(bank, status, scope, eligibilityType));
}
```

**Step 7: Run tests**

Run: `cd cardsense-api && mvn test -q`
Expected: All tests pass (existing CatalogServiceTest calls `listCards(bank, status, scope)` — update to 4 args with null for eligibilityType)

**Step 8: Commit**

```bash
git add -A
git commit -m "feat: add eligibilityType to filter profession/business cards from recommendations"
```

---

### Task 3: Add platform/merchant condition matching to DecisionEngine

**Files:**
- Modify: `cardsense-api/src/main/java/com/cardsense/api/service/DecisionEngine.java`
- Test: `cardsense-api/src/test/java/com/cardsense/api/service/DecisionEngineTest.java`

**Step 1: Write failing tests**

Add to `DecisionEngineTest.java`:
```java
@Test
public void testRecommendMatchesEcommercePlatformCondition() {
    Promotion momoPromo = buildPromotion("promo1", "ver1", "CTBC_CARD", "中國信託卡", "CTBC", "中國信託", BigDecimal.valueOf(5.0), 500, 1800, LocalDate.of(2026, 6, 30));
    momoPromo.setConditions(List.of(condition("ECOMMERCE_PLATFORM", "MOMO", "momo 限定")));

    Promotion generalPromo = buildPromotion("promo2", "ver2", "CATHAY_CARD", "國泰卡", "CATHAY", "國泰世華", BigDecimal.valueOf(3.0), 300, 1800, LocalDate.of(2026, 6, 30));

    when(promotionRepository.findActivePromotions(any())).thenReturn(List.of(momoPromo, generalPromo));

    // With merchantName=MOMO, both should match
    RecommendationResponse withMerchant = decisionEngine.recommend(RecommendationRequest.builder()
            .scenario(RecommendationScenario.builder()
                    .amount(1000)
                    .category("ONLINE")
                    .merchantName("MOMO")
                    .date(LocalDate.now())
                    .build())
            .build());

    assertEquals(2, withMerchant.getRecommendations().size());
    assertEquals("promo1", withMerchant.getRecommendations().get(0).getPromotionId());

    // Without merchantName, platform-specific promo excluded
    RecommendationResponse withoutMerchant = decisionEngine.recommend(RecommendationRequest.builder()
            .amount(1000)
            .category("ONLINE")
            .date(LocalDate.now())
            .build());

    assertEquals(1, withoutMerchant.getRecommendations().size());
    assertEquals("promo2", withoutMerchant.getRecommendations().get(0).getPromotionId());
}

@Test
public void testRecommendExcludesMismatchedPlatformCondition() {
    Promotion shopeePromo = buildPromotion("promo1", "ver1", "CTBC_CARD", "中國信託卡", "CTBC", "中國信託", BigDecimal.valueOf(5.0), 500, 1800, LocalDate.of(2026, 6, 30));
    shopeePromo.setConditions(List.of(condition("ECOMMERCE_PLATFORM", "SHOPEE", "蝦皮限定")));

    when(promotionRepository.findActivePromotions(any())).thenReturn(List.of(shopeePromo));

    RecommendationResponse response = decisionEngine.recommend(RecommendationRequest.builder()
            .scenario(RecommendationScenario.builder()
                    .amount(1000)
                    .category("ONLINE")
                    .merchantName("MOMO")
                    .date(LocalDate.now())
                    .build())
            .build());

    assertTrue(response.getRecommendations().isEmpty());
}
```

**Step 2: Run tests to verify they fail**

Run: `cd cardsense-api && mvn test -Dtest=DecisionEngineTest#testRecommendMatchesEcommercePlatformCondition -q`
Expected: FAIL — platform conditions not yet handled

**Step 3: Add platform matching to DecisionEngine**

In `isEligible()`, after the `matchesLocation` check (line 122), add:
```java
if (!matchesPlatformConditions(promotion, request)) {
    return false;
}
```

Add new private methods:
```java
private static final Set<String> PLATFORM_CONDITION_TYPES = Set.of(
        "ECOMMERCE_PLATFORM", "RETAIL_CHAIN", "PAYMENT_PLATFORM"
);

private boolean matchesPlatformConditions(Promotion promotion, RecommendationRequest request) {
    List<PromotionCondition> conditions = promotion.getConditions();
    if (conditions == null || conditions.isEmpty()) {
        return true;
    }

    List<String> platformValues = conditions.stream()
            .filter(c -> PLATFORM_CONDITION_TYPES.contains(normalizeValue(c.getType())))
            .map(PromotionCondition::getValue)
            .map(this::normalizeValue)
            .filter(v -> !v.isBlank())
            .toList();

    if (platformValues.isEmpty()) {
        return true;
    }

    String merchantName = request.getResolvedMerchantName();
    if (merchantName == null || merchantName.isBlank()) {
        return false;
    }

    String normalizedMerchant = normalizeValue(merchantName);
    return platformValues.stream().anyMatch(normalizedMerchant::equals);
}
```

Also add `getResolvedMerchantName()` to `RecommendationRequest.java`:
```java
@JsonIgnore
public String getResolvedMerchantName() {
    return scenario != null ? scenario.getMerchantName() : null;
}
```

**Step 4: Run tests**

Run: `cd cardsense-api && mvn test -q`
Expected: All tests pass

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add ECOMMERCE_PLATFORM/RETAIL_CHAIN/PAYMENT_PLATFORM condition matching"
```

---

### Task 4: Add card promotions API endpoint

**Files:**
- Modify: `cardsense-api/src/main/java/com/cardsense/api/repository/PromotionRepository.java`
- Modify: `cardsense-api/src/main/java/com/cardsense/api/repository/SqlitePromotionRepository.java`
- Modify: `cardsense-api/src/main/java/com/cardsense/api/repository/SupabasePromotionRepository.java`
- Modify: `cardsense-api/src/main/java/com/cardsense/api/repository/MockPromotionRepository.java`
- Modify: `cardsense-api/src/main/java/com/cardsense/api/service/CatalogService.java`
- Modify: `cardsense-api/src/main/java/com/cardsense/api/controller/CardController.java`

**Step 1: Add repository method**

In `PromotionRepository.java`, add:
```java
List<Promotion> findPromotionsByCardCode(String cardCode, LocalDate date);
```

**Step 2: Implement in all repositories**

For each repository implementation, add the method. The simplest approach — filter `findActivePromotions` by cardCode:

`MockPromotionRepository`: filter from in-memory list
`SqlitePromotionRepository`: add WHERE clause on card_code
`SupabasePromotionRepository`: add WHERE clause on card_code

If the repository implementations use a common query pattern, match it. Otherwise, the default implementation:
```java
@Override
public List<Promotion> findPromotionsByCardCode(String cardCode, LocalDate date) {
    return findActivePromotions(date).stream()
            .filter(p -> cardCode.equalsIgnoreCase(p.getCardCode()))
            .toList();
}
```

**Step 3: Add service method**

In `CatalogService.java`, add:
```java
public List<Promotion> listCardPromotions(String cardCode) {
    return promotionRepository.findPromotionsByCardCode(cardCode, LocalDate.now());
}
```

**Step 4: Add controller endpoint**

In `CardController.java`, add:
```java
@GetMapping("/{cardCode}/promotions")
public ResponseEntity<List<Promotion>> listCardPromotions(@PathVariable String cardCode) {
    List<Promotion> promotions = catalogService.listCardPromotions(cardCode);
    return ResponseEntity.ok(promotions);
}
```

Add required imports:
```java
import org.springframework.web.bind.annotation.PathVariable;
import com.cardsense.api.domain.Promotion;
```

**Step 5: Run tests**

Run: `cd cardsense-api && mvn test -q`
Expected: All tests pass

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add GET /v1/cards/{cardCode}/promotions endpoint"
```

---

### Task 5: Frontend — Remove ComparisonMode and update types

**Files:**
- Modify: `cardsense-web/src/types/enums.ts`
- Modify: `cardsense-web/src/types/api.ts`
- Modify: `cardsense-web/src/components/RecommendationForm.tsx`

**Step 1: Update enums.ts**

Remove:
```typescript
export const COMPARISON_MODES = ['BEST_SINGLE_PROMOTION', 'STACK_ALL_ELIGIBLE'] as const
export type ComparisonMode = (typeof COMPARISON_MODES)[number]

export const COMPARISON_MODE_LABELS: Record<ComparisonMode, string> = {
  BEST_SINGLE_PROMOTION: '最佳單一優惠',
  STACK_ALL_ELIGIBLE: '所有可疊加優惠',
}
```

Add new types:
```typescript
export const ELIGIBILITY_TYPES = ['GENERAL', 'PROFESSION_SPECIFIC', 'BUSINESS'] as const
export type EligibilityType = (typeof ELIGIBILITY_TYPES)[number]

export const ELIGIBILITY_TYPE_LABELS: Record<EligibilityType, string> = {
  GENERAL: '一般',
  PROFESSION_SPECIFIC: '職業限定',
  BUSINESS: '商務卡',
}

export const ANNUAL_FEE_RANGES = ['FREE', 'LOW', 'HIGH'] as const
export type AnnualFeeRange = (typeof ANNUAL_FEE_RANGES)[number]

export const ANNUAL_FEE_RANGE_LABELS: Record<AnnualFeeRange, string> = {
  FREE: '免年費',
  LOW: '低年費 (1-999)',
  HIGH: '高年費 (1000+)',
}
```

**Step 2: Update api.ts**

Update `CardSummary`:
```typescript
export interface CardSummary {
  cardCode: string
  cardName: string
  cardStatus: 'ACTIVE' | 'DISCONTINUED'
  annualFee: number | null
  applyUrl: string | null
  bankCode: BankCode
  bankName: string
  recommendationScopes: string[]
  eligibilityType: string
  availableCategories: string[]
}
```

Update `RecommendationComparisonOptions` — remove `mode`:
```typescript
export interface RecommendationComparisonOptions {
  includePromotionBreakdown?: boolean
  includeBreakEvenAnalysis?: boolean
  maxResults?: number
  compareCardCodes?: string[]
}
```

Update `RecommendationComparisonSummary` — mode to string:
```typescript
export interface RecommendationComparisonSummary {
  mode: string
  // ... rest stays same
}
```

Update `CardRecommendation` — remove `rankingMode`:
```typescript
export interface CardRecommendation {
  cardCode: string | null
  cardName: string
  bankCode: BankCode | null
  bankName: string
  cashbackType: CashbackType
  cashbackValue: number
  estimatedReturn: number
  matchedPromotionCount: number
  reason: string
  promotionId: string | null
  promoVersionId: string | null
  validUntil: string | null
  conditions: PromotionCondition[]
  promotionBreakdown: PromotionRewardBreakdown[]
  applyUrl: string | null
}
```

**Step 3: Update RecommendationForm.tsx**

Remove imports of `COMPARISON_MODES`, `COMPARISON_MODE_LABELS`, `ComparisonMode`.
Remove the `mode` state variable and the entire comparison mode selector section (lines 169-205).
Remove `Tooltip`, `TooltipContent`, `TooltipProvider`, `TooltipTrigger` imports and `HelpCircle` if no longer used.

Update `handleSubmit` — remove `mode` from the request:
```typescript
mutation.mutate(
  {
    amount: amountNum,
    category: category as Category,
    ...(channel && { scenario: { channel: channel as Channel } }),
    ...(selectedCard && { cardCodes: [selectedCard] }),
    comparison: {
      includePromotionBreakdown: true,
      includeBreakEvenAnalysis: true,
      maxResults: 10,
    },
  },
  { onSuccess: onResult },
)
```

**Step 4: Verify frontend builds**

Run: `cd cardsense-web && npm run build`
Expected: Build succeeds with no type errors

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(web): remove ComparisonMode UI, add eligibility/fee type definitions"
```

---

### Task 6: Frontend — CardsPage filter tags

**Files:**
- Modify: `cardsense-web/src/pages/CardsPage.tsx`

**Step 1: Add filter state and filtering logic**

Add new state variables and imports. Add filter chips for: eligibilityType, category (from availableCategories), annualFee range, and recommendationScope.

The filtering logic:
- `eligibilityType`: exact match on `card.eligibilityType`
- `categoryFilter`: card's `availableCategories` includes the selected category
- `annualFeeRange`: FREE = 0, LOW = 1-999, HIGH = 1000+
- `scopeFilter`: card's `recommendationScopes` includes the selected scope

Add new filter chip rows below the bank chips. Each row uses the same chip style pattern already used for banks.

**Step 2: Verify frontend builds**

Run: `cd cardsense-web && npm run build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add -A
git commit -m "feat(web): add eligibility, category, fee range, scope filter tags to CardsPage"
```

---

### Task 7: Frontend — CardDetailPage promotions display

**Files:**
- Modify: `cardsense-web/src/api/hooks.ts`
- Modify: `cardsense-web/src/pages/CardDetailPage.tsx`
- Modify: `cardsense-web/src/types/api.ts` (add Promotion type if needed)

**Step 1: Add API hook**

In `hooks.ts`, add:
```typescript
export function useCardPromotions(cardCode: string) {
  return useQuery({
    queryKey: ['cards', cardCode, 'promotions'],
    queryFn: () => get<CardPromotion[]>(`/v1/cards/${cardCode}/promotions`),
    enabled: !!cardCode,
  })
}
```

Add `CardPromotion` type to `api.ts`:
```typescript
export interface CardPromotion {
  promoId: string
  promoVersionId: string
  title: string | null
  category: string
  channel: string | null
  cashbackType: CashbackType
  cashbackValue: number
  minAmount: number | null
  maxCashback: number | null
  validFrom: string | null
  validUntil: string | null
  frequencyLimit: string | null
  requiresRegistration: boolean
  conditions: PromotionCondition[]
  stackability: {
    relationshipMode: string | null
    groupId: string | null
  } | null
}
```

**Step 2: Update CardDetailPage**

Add a "優惠資訊" section after the existing card info. Group promotions by category. For each promotion show:
- title
- cashback type/value (e.g., "3%" or "NT$50")
- validity period
- conditions as badges
- If stackability.relationshipMode is "MUTUALLY_EXCLUSIVE", show a warning badge: "需切換權益模式"

**Step 3: Verify frontend builds**

Run: `cd cardsense-web && npm run build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add -A
git commit -m "feat(web): display promotions grouped by category on CardDetailPage"
```

---

### Task 8: Update frontend type exports and cleanup

**Files:**
- Modify: `cardsense-web/src/types/index.ts` (if it re-exports)
- Any remaining `ComparisonMode` references across the frontend

**Step 1: Search and remove stale ComparisonMode references**

Grep for `ComparisonMode` and `rankingMode` across `cardsense-web/src/` and remove any remaining references.

**Step 2: Verify full build**

Run: `cd cardsense-web && npm run build`
Expected: Clean build, no warnings

**Step 3: Commit**

```bash
git add -A
git commit -m "chore(web): clean up stale ComparisonMode references"
```

---

### Task 9: Backend full test verification

**Step 1: Run full backend test suite**

Run: `cd cardsense-api && mvn test -q`
Expected: All tests pass

**Step 2: Fix any failures, commit if needed**

---

### Task 10: Contracts schema update

**Files:**
- Modify relevant JSON schemas in `cardsense-contracts/schemas/`

**Step 1: Update promotion schema**

Add `eligibilityType` field (enum: GENERAL, PROFESSION_SPECIFIC, BUSINESS).
Add new condition types to the condition type enum: ECOMMERCE_PLATFORM, RETAIL_CHAIN, PAYMENT_PLATFORM.

**Step 2: Update recommendation request schema**

Remove `mode` from comparison options.

**Step 3: Update card summary schema**

Add `eligibilityType` and `availableCategories` fields.

**Step 4: Remove ComparisonMode from recommendation response schema**

Update `rankingMode` / `mode` fields.

**Step 5: Validate schemas**

Run: `cd cardsense-contracts && npm test` (or equivalent validation command)

**Step 6: Commit**

```bash
git add -A
git commit -m "feat(contracts): update schemas for eligibility, platform conditions, remove ComparisonMode"
```
