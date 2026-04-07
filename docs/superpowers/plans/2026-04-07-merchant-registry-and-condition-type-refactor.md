# Merchant Registry + Condition Type Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify merchant/retailer reference data into a single `merchant-registry.json` in contracts, simplify condition types from 4 merchant-related values (`ECOMMERCE_PLATFORM`, `RETAIL_CHAIN`, `MERCHANT`, `PAYMENT_PLATFORM`) down to 2 semantic types (`VENUE` for where you spend, `PAYMENT` for how you pay), and split the ambiguous `VENUE` subcategory into `SINGING` (KTV) + `LIVE_EVENT` (展演).

**Architecture:** Create a canonical merchant registry in `cardsense-contracts/taxonomy/` as a flat JSON array. Migrate all condition type references across 4 repos (contracts schema, extractor production code + tests, API matching logic + tests, frontend badge/picker code). The extractor is the source of truth for condition types — once it outputs `VENUE`/`PAYMENT`, a `refresh_and_deploy` propagates to Supabase, which the API reads. Frontend changes are pure display-side.

**Tech Stack:** Python 3.13+ (extractor), Java 21 / Spring Boot (API), TypeScript / React 19 (web), JSON Schema (contracts)

---

## File Structure

### contracts (cardsense-contracts)
- **Create:** `taxonomy/merchant-registry.json` — flat array of merchant entries with code, label, category, subcategory, aliases
- **Modify:** `taxonomy/subcategory-taxonomy.json` — split `VENUE` into `SINGING` + `LIVE_EVENT`
- **Modify:** `promotion/promotion-normalized.schema.json` — no enum constraint on condition type (currently free-form `minLength: 3`), but update examples

### extractor (cardsense-extractor)
- **Modify:** `extractor/promotion_rules.py` — replace all `ECOMMERCE_PLATFORM`/`RETAIL_CHAIN`/`MERCHANT` → `VENUE`, `PAYMENT_PLATFORM` → `PAYMENT`
- **Modify:** `extractor/esun_real.py` — feature extractor condition types
- **Modify:** `extractor/cathay_real.py` — feature extractor condition types
- **Modify:** `extractor/taishin_real.py` — feature extractor condition types
- **Modify:** `extractor/fubon_real.py` — feature extractor condition types
- **Modify:** `extractor/ctbc_real.py` — feature extractor condition types
- **Modify:** `extractor/bank_wide_promotions.py` — condition type reference
- **Modify:** 8 test files — update all condition type assertions
- **Modify:** `extractor/normalize.py` — if any condition type filtering exists

### api (cardsense-api)
- **Modify:** `src/main/java/com/cardsense/api/service/DecisionEngine.java:41-45` — update `MERCHANT_CONDITION_TYPES` and `PAYMENT_CONDITION_TYPES`
- **Modify:** `src/main/java/com/cardsense/api/service/CatalogService.java:128-131` — update venue condition type set
- **Modify:** `src/test/java/com/cardsense/api/service/DecisionEngineTest.java` — update test condition types
- **Modify:** `src/test/java/com/cardsense/api/service/DecisionEngineBenefitPlanTest.java` — update test condition types

### web (cardsense-web)
- **Modify:** `src/types/enums.ts:24-31` — update `CHANNEL_CONDITION_TYPES` set, split into `VENUE_CONDITION_TYPES` and `PAYMENT_CONDITION_TYPES`
- **Modify:** `src/pages/CardDetailPage.tsx` — update badge rendering to distinguish VENUE vs PAYMENT
- **Modify:** `src/components/RecommendationResults.tsx` — update condition type check

---

## Task Ordering & Dependencies

```
Task 1 (contracts: registry + subcategory split) → Task 2 (extractor rules) → Task 3 (extractor extractors)
                                                                             → Task 4 (extractor tests)
                                                                             → Task 5 (API)
                                                                             → Task 6 (web: condition types + subcategory split)
Task 7 (verify end-to-end)
```

Tasks 3-6 are independent of each other (they all depend on Task 2's type constants being defined). Task 7 requires all prior tasks.

---

### Task 1: Create Merchant Registry in Contracts

**Files:**
- Create: `cardsense-contracts/taxonomy/merchant-registry.json`

- [ ] **Step 1: Create the merchant registry JSON**

This is the canonical list of all merchants/venues/payment platforms. Each entry has: `code` (unique ID, matches condition value), `label` (display name), `category`, `subcategory`, and `aliases` (tokens used for text matching in extractor).

```json
[
  {"code": "PCHOME_24H", "label": "PChome 24h", "category": "ONLINE", "subcategory": "ECOMMERCE", "aliases": ["PChome 24h", "PChome"]},
  {"code": "MOMO", "label": "momo", "category": "ONLINE", "subcategory": "ECOMMERCE", "aliases": ["momo"]},
  {"code": "SHOPEE", "label": "蝦皮", "category": "ONLINE", "subcategory": "ECOMMERCE", "aliases": ["蝦皮"]},
  {"code": "YAHOO", "label": "Yahoo", "category": "ONLINE", "subcategory": "ECOMMERCE", "aliases": ["Yahoo"]},
  {"code": "COUPANG", "label": "Coupang", "category": "ONLINE", "subcategory": "ECOMMERCE", "aliases": ["Coupang"]},
  {"code": "TAOBAO", "label": "淘寶", "category": "ONLINE", "subcategory": "INTERNATIONAL_ECOMMERCE", "aliases": ["淘寶"]},
  {"code": "TMALL", "label": "天貓", "category": "ONLINE", "subcategory": "INTERNATIONAL_ECOMMERCE", "aliases": ["天貓"]},

  {"code": "LINE_PAY", "label": "LINE Pay", "category": "ONLINE", "subcategory": "MOBILE_PAY", "aliases": ["LINE Pay"]},
  {"code": "APPLE_PAY", "label": "Apple Pay", "category": "ONLINE", "subcategory": "MOBILE_PAY", "aliases": ["Apple Pay"]},
  {"code": "GOOGLE_PAY", "label": "Google Pay", "category": "ONLINE", "subcategory": "MOBILE_PAY", "aliases": ["Google Pay"]},
  {"code": "SAMSUNG_PAY", "label": "Samsung Pay", "category": "ONLINE", "subcategory": "MOBILE_PAY", "aliases": ["Samsung Pay"]},
  {"code": "JKOPAY", "label": "街口支付", "category": "ONLINE", "subcategory": "MOBILE_PAY", "aliases": ["街口", "街口支付"]},
  {"code": "ESUN_WALLET", "label": "玉山 Wallet", "category": "ONLINE", "subcategory": "MOBILE_PAY", "aliases": ["玉山WALLET電子支付", "玉山 Wallet電子支付"]},
  {"code": "全支付", "label": "全支付", "category": "ONLINE", "subcategory": "MOBILE_PAY", "aliases": ["全支付"]},
  {"code": "悠遊付", "label": "悠遊付", "category": "ONLINE", "subcategory": "MOBILE_PAY", "aliases": ["悠遊付"]},
  {"code": "全盈_PAY", "label": "全盈+PAY", "category": "ONLINE", "subcategory": "MOBILE_PAY", "aliases": ["全盈+PAY"]},
  {"code": "IPASS_MONEY", "label": "iPASS MONEY", "category": "ONLINE", "subcategory": "MOBILE_PAY", "aliases": ["iPASS MONEY"]},
  {"code": "ICASH_PAY", "label": "icash Pay", "category": "ONLINE", "subcategory": "MOBILE_PAY", "aliases": ["icash Pay"]},

  {"code": "CHATGPT", "label": "ChatGPT", "category": "ONLINE", "subcategory": "AI_TOOL", "aliases": ["ChatGPT"]},
  {"code": "CLAUDE", "label": "Claude", "category": "ONLINE", "subcategory": "AI_TOOL", "aliases": ["Claude"]},
  {"code": "CURSOR", "label": "Cursor", "category": "ONLINE", "subcategory": "AI_TOOL", "aliases": ["Cursor"]},
  {"code": "GEMINI", "label": "Gemini", "category": "ONLINE", "subcategory": "AI_TOOL", "aliases": ["Gemini"]},
  {"code": "PERPLEXITY", "label": "Perplexity", "category": "ONLINE", "subcategory": "AI_TOOL", "aliases": ["Perplexity"]},
  {"code": "NOTION", "label": "Notion", "category": "ONLINE", "subcategory": "AI_TOOL", "aliases": ["Notion"]},
  {"code": "CANVA", "label": "Canva", "category": "ONLINE", "subcategory": "AI_TOOL", "aliases": ["Canva"]},
  {"code": "GAMMA", "label": "Gamma", "category": "ONLINE", "subcategory": "AI_TOOL", "aliases": ["Gamma"]},

  {"code": "HOTELS_COM", "label": "Hotels.com", "category": "OVERSEAS", "subcategory": "TRAVEL_PLATFORM", "aliases": ["Hotels.com"]},
  {"code": "AGODA", "label": "Agoda", "category": "OVERSEAS", "subcategory": "TRAVEL_PLATFORM", "aliases": ["Agoda"]},
  {"code": "BOOKING", "label": "Booking.com", "category": "OVERSEAS", "subcategory": "TRAVEL_PLATFORM", "aliases": ["Booking.com", "Booking"]},
  {"code": "KLOOK", "label": "Klook", "category": "OVERSEAS", "subcategory": "TRAVEL_PLATFORM", "aliases": ["Klook"]},
  {"code": "KKDAY", "label": "KKday", "category": "OVERSEAS", "subcategory": "TRAVEL_PLATFORM", "aliases": ["KKday"]},
  {"code": "TRIP_COM", "label": "Trip.com", "category": "OVERSEAS", "subcategory": "TRAVEL_PLATFORM", "aliases": ["Trip.com"]},
  {"code": "EZTRAVEL", "label": "易遊網", "category": "OVERSEAS", "subcategory": "TRAVEL_PLATFORM", "aliases": ["易遊網"]},
  {"code": "LION_TRAVEL", "label": "雄獅旅遊", "category": "OVERSEAS", "subcategory": "TRAVEL_PLATFORM", "aliases": ["雄獅旅遊", "雄獅"]},

  {"code": "PXMART", "label": "全聯", "category": "GROCERY", "subcategory": "SUPERMARKET", "aliases": ["全聯"]},
  {"code": "CARREFOUR", "label": "家樂福", "category": "GROCERY", "subcategory": "SUPERMARKET", "aliases": ["家樂福"]},
  {"code": "LOPIA", "label": "LOPIA", "category": "GROCERY", "subcategory": "SUPERMARKET", "aliases": ["LOPIA"]},
  {"code": "RT_MART", "label": "RT-Mart", "category": "SHOPPING", "subcategory": "WAREHOUSE", "aliases": ["RT-Mart"]},

  {"code": "SOGO", "label": "遠東 SOGO", "category": "SHOPPING", "subcategory": "DEPARTMENT", "aliases": ["SOGO"]},
  {"code": "SHIN_KONG_MITSUKOSHI", "label": "新光三越", "category": "SHOPPING", "subcategory": "DEPARTMENT", "aliases": ["新光三越"]},
  {"code": "FAR_EAST_DEPARTMENT_STORE", "label": "遠東百貨", "category": "SHOPPING", "subcategory": "DEPARTMENT", "aliases": ["遠東百貨"]},
  {"code": "BREEZE", "label": "微風", "category": "SHOPPING", "subcategory": "DEPARTMENT", "aliases": ["微風"]},
  {"code": "TAIPEI_101", "label": "台北101", "category": "SHOPPING", "subcategory": "DEPARTMENT", "aliases": ["台北101"]},
  {"code": "CHUNGYO", "label": "中友百貨", "category": "SHOPPING", "subcategory": "DEPARTMENT", "aliases": ["中友百貨", "中友"]},
  {"code": "METROWALK", "label": "大江購物中心", "category": "SHOPPING", "subcategory": "DEPARTMENT", "aliases": ["大江"]},
  {"code": "GLOBAL_MALL", "label": "環球購物中心", "category": "SHOPPING", "subcategory": "DEPARTMENT", "aliases": ["環球購物中心"]},

  {"code": "COSMED", "label": "康是美", "category": "SHOPPING", "subcategory": "DRUGSTORE", "aliases": ["康是美"]},
  {"code": "WATSONS", "label": "屈臣氏", "category": "SHOPPING", "subcategory": "DRUGSTORE", "aliases": ["屈臣氏"]},

  {"code": "CPC", "label": "台灣中油", "category": "OTHER", "subcategory": "GAS_STATION", "aliases": ["台灣中油"]},
  {"code": "NATIONWIDE_GAS", "label": "全國加油", "category": "OTHER", "subcategory": "GAS_STATION", "aliases": ["全國加油"]},
  {"code": "FORMOSA_PETROCHEMICAL", "label": "台塑石油", "category": "OTHER", "subcategory": "GAS_STATION", "aliases": ["台塑石油"]},
  {"code": "TAIA", "label": "台亞", "category": "OTHER", "subcategory": "GAS_STATION", "aliases": ["台亞"]},
  {"code": "FORMOZA", "label": "福懋", "category": "OTHER", "subcategory": "GAS_STATION", "aliases": ["福懋"]},

  {"code": "UBER", "label": "Uber", "category": "TRANSPORT", "subcategory": "RIDESHARE", "aliases": ["Uber"]},
  {"code": "GRAB", "label": "Grab", "category": "TRANSPORT", "subcategory": "RIDESHARE", "aliases": ["Grab"]},
  {"code": "YOXI", "label": "yoxi", "category": "TRANSPORT", "subcategory": "RIDESHARE", "aliases": ["yoxi"]},

  {"code": "CHINA_AIRLINES", "label": "中華航空", "category": "TRANSPORT", "subcategory": "AIRLINE", "aliases": ["中華航空"]},
  {"code": "EVA_AIR", "label": "長榮航空", "category": "TRANSPORT", "subcategory": "AIRLINE", "aliases": ["長榮航空", "長榮"]},
  {"code": "STARLUX", "label": "星宇航空", "category": "TRANSPORT", "subcategory": "AIRLINE", "aliases": ["星宇航空", "星宇"]},
  {"code": "CATHAY_PACIFIC", "label": "國泰航空", "category": "TRANSPORT", "subcategory": "AIRLINE", "aliases": ["國泰航空"]},

  {"code": "TRA", "label": "台鐵", "category": "TRANSPORT", "subcategory": "PUBLIC_TRANSIT", "aliases": ["台鐵"]},
  {"code": "THSR", "label": "高鐵", "category": "TRANSPORT", "subcategory": "PUBLIC_TRANSIT", "aliases": ["高鐵"]},

  {"code": "UBER_EATS", "label": "Uber Eats", "category": "DINING", "subcategory": "DELIVERY", "aliases": ["Uber Eats", "UberEats"]},
  {"code": "FOODPANDA", "label": "foodpanda", "category": "DINING", "subcategory": "DELIVERY", "aliases": ["foodpanda"]},
  {"code": "STARBUCKS", "label": "星巴克", "category": "DINING", "subcategory": "CAFE", "aliases": ["星巴克", "Starbucks"]},
  {"code": "MCDONALD", "label": "麥當勞", "category": "DINING", "subcategory": "RESTAURANT", "aliases": ["麥當勞"]},

  {"code": "NETFLIX", "label": "Netflix", "category": "ENTERTAINMENT", "subcategory": "STREAMING", "aliases": ["Netflix"]},
  {"code": "YOUTUBE_PREMIUM", "label": "YouTube Premium", "category": "ENTERTAINMENT", "subcategory": "STREAMING", "aliases": ["YouTube Premium", "YouTube"]},
  {"code": "DISNEY_PLUS", "label": "Disney+", "category": "ENTERTAINMENT", "subcategory": "STREAMING", "aliases": ["Disney+", "Disney"]},
  {"code": "SPOTIFY", "label": "Spotify", "category": "ENTERTAINMENT", "subcategory": "STREAMING", "aliases": ["Spotify"]},

  {"code": "UNIQLO", "label": "UNIQLO", "category": "SHOPPING", "subcategory": "APPAREL", "aliases": ["UNIQLO"]},
  {"code": "NET", "label": "NET", "category": "SHOPPING", "subcategory": "APPAREL", "aliases": ["NET"]},
  {"code": "DECATHLON", "label": "迪卡儂", "category": "SHOPPING", "subcategory": "SPORTING_GOODS", "aliases": ["迪卡儂"]},
  {"code": "IKEA", "label": "IKEA", "category": "OTHER", "subcategory": "HOME_LIVING", "aliases": ["IKEA"]},
  {"code": "MUJI", "label": "MUJI", "category": "OTHER", "subcategory": "HOME_LIVING", "aliases": ["MUJI"]},

  {"code": "GOSHARE", "label": "GoShare", "category": "TRANSPORT", "subcategory": "RIDESHARE", "aliases": ["GoShare"]},
  {"code": "WEMO", "label": "WeMo", "category": "TRANSPORT", "subcategory": "RIDESHARE", "aliases": ["WeMo"]},

  {"code": "U_POWER", "label": "U-POWER", "category": "OTHER", "subcategory": "EV_CHARGING", "aliases": ["U-POWER"]},
  {"code": "EVOASIS", "label": "EVOASIS", "category": "OTHER", "subcategory": "EV_CHARGING", "aliases": ["EVOASIS"]},
  {"code": "ICHARGING", "label": "iCharging", "category": "OTHER", "subcategory": "EV_CHARGING", "aliases": ["iCharging"]}
]
```

Note: This registry consolidates merchants from three sources:
- `extractor/promotion_rules.py` → `STRUCTURED_SUBCATEGORY_CONDITION_SIGNALS` + `COBRANDED_RETAILER_SIGNALS`
- `cardsense-web/src/types/enums.ts` → `SUBCATEGORY_MERCHANT_OPTIONS` + `MERCHANT_OPTIONS`
- Feature extractors in each bank's `*_real.py`

The implementer should cross-reference all three sources and add any merchants found in feature extractors that are not in this list. The registry is the **complete** list.

- [ ] **Step 2: Split VENUE subcategory into SINGING + LIVE_EVENT in subcategory-taxonomy.json**

In `cardsense-contracts/taxonomy/subcategory-taxonomy.json`, replace:
```json
"VENUE": {
  "category": "ENTERTAINMENT",
  "description": "Entertainment venues such as KTV, bowling, and other leisure venues."
},
```

With:
```json
"SINGING": {
  "category": "ENTERTAINMENT",
  "description": "KTV, karaoke venues, and singing-related entertainment."
},
"LIVE_EVENT": {
  "category": "ENTERTAINMENT",
  "description": "Live performances, concerts, exhibitions, and stage events."
},
```

- [ ] **Step 3: Commit**

```bash
cd cardsense-contracts
git add taxonomy/merchant-registry.json taxonomy/subcategory-taxonomy.json
git commit -m "feat: add merchant registry, split VENUE subcategory into SINGING + LIVE_EVENT"
```

---

### Task 2: Migrate Extractor Condition Types in promotion_rules.py

**Files:**
- Modify: `cardsense-extractor/extractor/promotion_rules.py`

This is the highest-impact file — ~97 occurrences of the old condition type strings. The migration is mechanical:
- `"ECOMMERCE_PLATFORM"` → `"VENUE"`
- `"RETAIL_CHAIN"` → `"VENUE"`
- `"MERCHANT"` → `"VENUE"` (only where it's a condition type string, NOT the word "merchant" in comments/variable names)
- `"PAYMENT_PLATFORM"` → `"PAYMENT"`

- [ ] **Step 1: Run existing tests to confirm green baseline**

```bash
cd cardsense-extractor
uv run pytest -x -q
```

Expected: All 157+ tests pass.

- [ ] **Step 2: Replace condition type strings in promotion_rules.py**

Use find-and-replace with care. The replacements in order:

1. Replace `"type": "ECOMMERCE_PLATFORM"` → `"type": "VENUE"` (all occurrences in STRUCTURED_SUBCATEGORY_CONDITION_SIGNALS and related dicts)
2. Replace `"type": "RETAIL_CHAIN"` → `"type": "VENUE"` (in STRUCTURED_SUBCATEGORY_CONDITION_SIGNALS, COBRANDED_RETAILER_SIGNALS)
3. Replace `"type": "MERCHANT"` → `"type": "VENUE"` (in STRUCTURED_SUBCATEGORY_CONDITION_SIGNALS — careful: only replace inside condition dict literals where `"type":` precedes it)
4. Replace `"type": "PAYMENT_PLATFORM"` → `"type": "PAYMENT"` (in STRUCTURED_SUBCATEGORY_CONDITION_SIGNALS)

Also update the set/constant references:
- Any `"PAYMENT_PLATFORM"` in `PAYMENT_PLATFORM_VALUE_ALIASES` variable name can stay (it's a variable name, not a condition type string)
- Any string comparisons like `condition["type"] == "PAYMENT_PLATFORM"` → `condition["type"] == "PAYMENT"`
- Any string comparisons like `condition_type == "PAYMENT_PLATFORM"` → `condition_type == "PAYMENT"`
- `"PAYMENT_METHOD"` → `"PAYMENT"` (if used as condition type)

Key areas in promotion_rules.py:
- Lines 676-791: `STRUCTURED_SUBCATEGORY_CONDITION_SIGNALS` and `COBRANDED_RETAILER_SIGNALS` dicts
- Lines 960-1060: `append_inferred_subcategory_conditions` and `append_inferred_cobranded_conditions` functions
- Lines 1010-1050: `append_inferred_payment_method_conditions` and related helpers
- Any `_has_positive_payment_signal` or `_canonicalize_payment_condition` helpers that reference these types

Also split the `VENUE` subcategory keyword mapping at line 551:
```python
# Before:
"VENUE":      [("KTV", 5), ("好樂迪", 4), ("錢櫃", 4), ("桌遊", 3), ("保齡球", 3)],
# After:
"SINGING":    [("KTV", 5), ("好樂迪", 4), ("錢櫃", 4)],
"LIVE_EVENT": [("桌遊", 3), ("保齡球", 3), ("展演", 4), ("演唱會", 4), ("音樂祭", 3)],
```

Note: The implementer should verify the keyword-to-subcategory mappings make sense (e.g., 桌遊/保齡球 might belong to a different subcategory — adjust as needed).

- [ ] **Step 3: Run tests — expect failures in assertion strings**

```bash
cd cardsense-extractor
uv run pytest -x -q 2>&1 | head -40
```

Expected: Many test failures because tests still assert `"ECOMMERCE_PLATFORM"`, `"RETAIL_CHAIN"`, etc.

- [ ] **Step 4: Commit production code change**

```bash
cd cardsense-extractor
git add extractor/promotion_rules.py
git commit -m "refactor: migrate condition types ECOMMERCE_PLATFORM/RETAIL_CHAIN/MERCHANT → VENUE, PAYMENT_PLATFORM → PAYMENT in promotion_rules"
```

---

### Task 3: Migrate Extractor Feature Extractors

**Files:**
- Modify: `cardsense-extractor/extractor/esun_real.py`
- Modify: `cardsense-extractor/extractor/cathay_real.py`
- Modify: `cardsense-extractor/extractor/taishin_real.py`
- Modify: `cardsense-extractor/extractor/fubon_real.py`
- Modify: `cardsense-extractor/extractor/ctbc_real.py`
- Modify: `cardsense-extractor/extractor/bank_wide_promotions.py`

Each bank's `*_real.py` has feature extractors that hardcode condition types in promotion dicts. Same mechanical replacement:
- `"type": "ECOMMERCE_PLATFORM"` → `"type": "VENUE"`
- `"type": "RETAIL_CHAIN"` → `"type": "VENUE"`
- `"type": "MERCHANT"` → `"type": "VENUE"` (only in condition dict context)
- `"type": "PAYMENT_PLATFORM"` → `"type": "PAYMENT"`

- [ ] **Step 1: Replace in all 6 extractor files**

Occurrence counts per file (from research):
- `esun_real.py`: 57 occurrences
- `cathay_real.py`: 84 occurrences
- `taishin_real.py`: 43 occurrences
- `fubon_real.py`: 12 occurrences
- `ctbc_real.py`: 14 occurrences
- `bank_wide_promotions.py`: 1 occurrence

- [ ] **Step 2: Commit**

```bash
cd cardsense-extractor
git add extractor/esun_real.py extractor/cathay_real.py extractor/taishin_real.py extractor/fubon_real.py extractor/ctbc_real.py extractor/bank_wide_promotions.py
git commit -m "refactor: migrate condition types to VENUE/PAYMENT in all bank extractors"
```

---

### Task 4: Update Extractor Tests

**Files:**
- Modify: `cardsense-extractor/tests/test_subcategory_conditions.py`
- Modify: `cardsense-extractor/tests/test_cobranded_and_date_conditions.py`
- Modify: `cardsense-extractor/tests/test_normalize.py`
- Modify: `cardsense-extractor/tests/test_esun_real.py`
- Modify: `cardsense-extractor/tests/test_cathay_real.py`
- Modify: `cardsense-extractor/tests/test_taishin_real.py`
- Modify: `cardsense-extractor/tests/test_fubon_real.py`
- Modify: `cardsense-extractor/tests/test_ctbc_real.py`

~72 occurrences across 8 test files. Same mechanical replacement in assertion strings.

- [ ] **Step 1: Replace condition type strings in all test files**

Key patterns to replace:
- `condition["type"] == "ECOMMERCE_PLATFORM"` → `condition["type"] == "VENUE"`
- `condition["type"] == "RETAIL_CHAIN"` → `condition["type"] == "VENUE"`
- `condition["type"] == "MERCHANT"` → `condition["type"] == "VENUE"`
- `condition["type"] == "PAYMENT_PLATFORM"` → `condition["type"] == "PAYMENT"`
- `{"type": "PAYMENT_PLATFORM", ...}` → `{"type": "PAYMENT", ...}` (in test fixture data)
- `{"type": "RETAIL_CHAIN", ...}` → `{"type": "VENUE", ...}` (in test fixture data)
- `"PAYMENT_METHOD"` and `"PAYMENT_PLATFORM"` in `test_normalize.py` → `"PAYMENT"`

Special attention for `test_normalize.py:167,188` which checks `condition["type"] not in {"PAYMENT_METHOD", "PAYMENT_PLATFORM"}` — update to `condition["type"] not in {"PAYMENT"}`.

- [ ] **Step 2: Run all tests**

```bash
cd cardsense-extractor
uv run pytest -x -q
```

Expected: All 157+ tests pass.

- [ ] **Step 3: Commit**

```bash
cd cardsense-extractor
git add tests/
git commit -m "test: update all condition type assertions to VENUE/PAYMENT"
```

---

### Task 5: Migrate API Condition Types

**Files:**
- Modify: `cardsense-api/src/main/java/com/cardsense/api/service/DecisionEngine.java:41-45`
- Modify: `cardsense-api/src/main/java/com/cardsense/api/service/CatalogService.java:128-131`
- Modify: `cardsense-api/src/test/java/com/cardsense/api/service/DecisionEngineTest.java`
- Modify: `cardsense-api/src/test/java/com/cardsense/api/service/DecisionEngineBenefitPlanTest.java`

- [ ] **Step 1: Update DecisionEngine.java constants**

Change lines 41-45 from:
```java
private static final Set<String> MERCHANT_CONDITION_TYPES = Set.of(
        "ECOMMERCE_PLATFORM", "RETAIL_CHAIN", "MERCHANT"
);
private static final Set<String> PAYMENT_CONDITION_TYPES = Set.of(
        "PAYMENT_PLATFORM", "PAYMENT_METHOD"
);
```

To:
```java
private static final Set<String> MERCHANT_CONDITION_TYPES = Set.of(
        "VENUE"
);
private static final Set<String> PAYMENT_CONDITION_TYPES = Set.of(
        "PAYMENT"
);
```

- [ ] **Step 2: Update CatalogService.java**

Change lines 128-131 from:
```java
return promotion.getConditions() == null || promotion.getConditions().stream()
        .noneMatch(condition -> Set.of("MERCHANT", "RETAIL_CHAIN", "ECOMMERCE_PLATFORM").contains(
                condition.getType() == null ? "" : condition.getType().trim().toUpperCase(Locale.ROOT)
        ));
```

To:
```java
return promotion.getConditions() == null || promotion.getConditions().stream()
        .noneMatch(condition -> Set.of("VENUE").contains(
                condition.getType() == null ? "" : condition.getType().trim().toUpperCase(Locale.ROOT)
        ));
```

- [ ] **Step 3: Update DecisionEngineTest.java**

Replace condition type strings in test helper calls (~4 occurrences):
- `condition("MERCHANT", "CHATGPT", "ChatGPT")` → `condition("VENUE", "CHATGPT", "ChatGPT")`
- `condition("RETAIL_CHAIN", "DECATHLON", "迪卡儂")` → `condition("VENUE", "DECATHLON", "迪卡儂")`
- `condition("PAYMENT_PLATFORM", "LINE_PAY", "LINE Pay")` → `condition("PAYMENT", "LINE_PAY", "LINE Pay")`
- `condition("ECOMMERCE_PLATFORM", "PCHOME_24H", "PChome 24h")` → `condition("VENUE", "PCHOME_24H", "PChome 24h")`

- [ ] **Step 4: Update DecisionEngineBenefitPlanTest.java**

Search for any `ECOMMERCE_PLATFORM`, `RETAIL_CHAIN`, `MERCHANT`, `PAYMENT_PLATFORM` strings and replace with `VENUE` or `PAYMENT` accordingly.

- [ ] **Step 5: Run API tests**

```bash
cd cardsense-api
mvn test -q
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
cd cardsense-api
git add src/
git commit -m "refactor: migrate condition types to VENUE/PAYMENT in DecisionEngine and CatalogService"
```

---

### Task 6: Migrate Frontend Condition Types + PAYMENT Badge Distinction + Subcategory Split

**Files:**
- Modify: `cardsense-web/src/types/enums.ts:24-31, 54`
- Modify: `cardsense-web/src/pages/CardDetailPage.tsx`
- Modify: `cardsense-web/src/components/RecommendationResults.tsx`

- [ ] **Step 1: Update enums.ts — split CHANNEL_CONDITION_TYPES into VENUE and PAYMENT**

Replace lines 24-31:
```typescript
export const CHANNEL_CONDITION_TYPES = new Set([
  'LOCATION_ONLY',
  'LOCATION_EXCLUDE',
  'ECOMMERCE_PLATFORM',
  'RETAIL_CHAIN',
  'PAYMENT_PLATFORM',
  'MERCHANT',
])
```

With:
```typescript
/** Condition types for designated venues/merchants (where you spend) */
export const VENUE_CONDITION_TYPES = new Set([
  'VENUE',
  'LOCATION_ONLY',
  'LOCATION_EXCLUDE',
])

/** Condition types for payment methods (how you pay) */
export const PAYMENT_CONDITION_TYPES = new Set([
  'PAYMENT',
])

/** All channel-related condition types (union of venue + payment) — used for badge filtering */
export const CHANNEL_CONDITION_TYPES = new Set([
  ...VENUE_CONDITION_TYPES,
  ...PAYMENT_CONDITION_TYPES,
])
```

This keeps `CHANNEL_CONDITION_TYPES` as a backwards-compatible union for existing code that just checks "is this a channel condition?", while allowing new code to distinguish VENUE vs PAYMENT.

- [ ] **Step 2: Update CardDetailPage.tsx badge rendering**

In `CardDetailPage.tsx`, the current code at line 334 renders all channel conditions with the same blue badge. Split into two:

Find the block that renders channel condition badges (around line 334):
```tsx
{promotion.conditions?.filter((c) => CHANNEL_CONDITION_TYPES.has(c.type)).map((condition, index) => (
  <Badge key={`ch-${index}`} variant="outline" className="text-xs rounded-full border-blue-300 text-blue-700 dark:border-blue-700 dark:text-blue-400">
    {condition.label || `${condition.type}: ${condition.value}`}
  </Badge>
))}
```

Replace with:
```tsx
{promotion.conditions?.filter((c) => VENUE_CONDITION_TYPES.has(c.type)).map((condition, index) => (
  <Badge key={`venue-${index}`} variant="outline" className="text-xs rounded-full border-blue-300 text-blue-700 dark:border-blue-700 dark:text-blue-400">
    {condition.label || `${condition.type}: ${condition.value}`}
  </Badge>
))}
{promotion.conditions?.filter((c) => PAYMENT_CONDITION_TYPES.has(c.type)).map((condition, index) => (
  <Badge key={`pay-${index}`} variant="outline" className="text-xs rounded-full border-purple-300 text-purple-700 dark:border-purple-700 dark:text-purple-400">
    {condition.label || `${condition.type}: ${condition.value}`}
  </Badge>
))}
```

Update the import at the top to include `VENUE_CONDITION_TYPES` and `PAYMENT_CONDITION_TYPES`.

- [ ] **Step 3: Update RecommendationResults.tsx**

Find the condition type check (around line 457):
```tsx
const isChannel = CHANNEL_CONDITION_TYPES.has(c.type)
```

Update to distinguish venue vs payment for badge styling:
```tsx
const isVenue = VENUE_CONDITION_TYPES.has(c.type)
const isPayment = PAYMENT_CONDITION_TYPES.has(c.type)
```

Then update the badge className to use purple for payment, blue for venue. The exact JSX depends on the current rendering — the implementer should check the surrounding code and apply the same blue/purple distinction as CardDetailPage.

- [ ] **Step 4: Split VENUE subcategory label in enums.ts**

In `enums.ts` line 54, replace:
```typescript
{ value: 'VENUE', label: 'KTV / 展演' },
```

With:
```typescript
{ value: 'SINGING', label: 'KTV' },
{ value: 'LIVE_EVENT', label: '展演 / 演唱會' },
```

Also update `SUBCATEGORY_LABELS` if it exists — search for any `VENUE` → split into `SINGING` and `LIVE_EVENT` entries.

- [ ] **Step 5: Verify frontend builds**

```bash
cd cardsense-web
npm run build
```

Expected: Build succeeds with no TypeScript errors.

- [ ] **Step 6: Commit**

```bash
cd cardsense-web
git add src/
git commit -m "refactor: migrate condition types to VENUE/PAYMENT, split VENUE subcategory, add purple badge for payment conditions"
```

---

### Task 7: End-to-End Verification

**Files:** No code changes — verification only.

- [ ] **Step 1: Run extractor E.SUN extraction and check output**

```bash
cd cardsense-extractor
uv run python jobs/run_esun_real_job.py
```

Then inspect the JSONL output for a few key promotions:
- 中友百貨 13號卡友日 should have `{"type": "VENUE", "value": "CHUNGYO", ...}`
- Any LINE Pay promotion should have `{"type": "PAYMENT", "value": "LINE_PAY", ...}`
- Any PChome promotion should have `{"type": "VENUE", "value": "PCHOME_24H", ...}`

Verify no old condition types (`ECOMMERCE_PLATFORM`, `RETAIL_CHAIN`, `MERCHANT`, `PAYMENT_PLATFORM`) appear in the output, and no `VENUE` subcategory (should be `SINGING` or `LIVE_EVENT`).

```bash
cd cardsense-extractor
grep -c "ECOMMERCE_PLATFORM\|RETAIL_CHAIN\|PAYMENT_PLATFORM" outputs/esun-real-*.jsonl
grep -c '"subcategory": "VENUE"' outputs/esun-real-*.jsonl
```

Expected: 0 matches for both.

- [ ] **Step 2: Run refresh_and_deploy to sync to Supabase**

```bash
cd cardsense-extractor
uv run python jobs/refresh_and_deploy.py
```

Expected: All 5 banks extract + import + sync successfully. Promotion counts should be similar to before (~775 total, ~514 RECOMMENDABLE).

- [ ] **Step 3: Run API tests against new data**

```bash
cd cardsense-api
mvn test -q
```

Expected: All tests pass.

- [ ] **Step 4: Push all repos**

```bash
cd cardsense-contracts && git push
cd ../cardsense-extractor && git push
cd ../cardsense-api && git push
cd ../cardsense-web && git push
```

- [ ] **Step 5: Commit verification notes**

No code to commit — just verify the deploy pipeline works end-to-end.

---

## Migration Notes

### Backwards Compatibility

The API reads condition types from Supabase data. After `refresh_and_deploy`, all conditions will use `VENUE`/`PAYMENT`. The API code must be deployed **before or at the same time** as the data sync. If the API is deployed first with the new constants, old data with `ECOMMERCE_PLATFORM` etc. will fail to match — but this only affects a brief window.

**Recommended deploy order:**
1. Deploy API (new code handles both old and new types during transition)
2. Run `refresh_and_deploy` (data now uses new types)
3. Deploy frontend

To make the API handle both old and new types during the transition window, temporarily add both:
```java
private static final Set<String> MERCHANT_CONDITION_TYPES = Set.of(
        "VENUE", "ECOMMERCE_PLATFORM", "RETAIL_CHAIN", "MERCHANT"
);
```

Then remove the old values after data sync is confirmed.

### Condition Type Summary

| Before | After | Semantic |
|--------|-------|----------|
| `ECOMMERCE_PLATFORM` | `VENUE` | 消費場所 — 在哪買 |
| `RETAIL_CHAIN` | `VENUE` | 消費場所 — 在哪買 |
| `MERCHANT` | `VENUE` | 消費場所 — 在哪買 |
| `PAYMENT_PLATFORM` | `PAYMENT` | 支付工具 — 怎麼付 |
| `PAYMENT_METHOD` | `PAYMENT` | 支付工具 — 怎麼付 |
| `TEXT` | `TEXT` | 不動 |
| `REGISTRATION_REQUIRED` | `REGISTRATION_REQUIRED` | 不動 |
| `DAY_OF_MONTH` | `DAY_OF_MONTH` | 不動 |
| `DAY_OF_WEEK` | `DAY_OF_WEEK` | 不動 |
| `LOCATION_ONLY` | `LOCATION_ONLY` | 不動 |
| `LOCATION_EXCLUDE` | `LOCATION_EXCLUDE` | 不動 |
