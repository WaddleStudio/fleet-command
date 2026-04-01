# Subcategory Scenario Ranking Design

## Problem

CardSense 的推薦引擎目前以 8 大 `category`（餐飲、網購、娛樂等）為最小分類粒度。同一 category 下，「麗寶樂園門票6折」與「通用娛樂消費 3% 回饋」被放在同一個池子裡排名，導致商家限定優惠在通用查詢時汙染排名結果。

## Solution

在現有 `category` 之下新增 `subcategory` 維度。每筆 Promotion 由 Extractor 標記為 `GENERAL`（通用）或某個具體子類別（如 `MOVIE`、`THEME_PARK`）。排名邏輯：

- **使用者未選子類別**（通用查詢）：只有 `GENERAL` 的優惠參與排名，排除所有特定場景優惠
- **使用者選了子類別**：該子類別的優惠 + `GENERAL` 優惠都參與排名（GENERAL fallback）

## Decisions

| 決策 | 選項 | 理由 |
|------|------|------|
| 整體方案 | 完整情境模型（Option C） | 建立從 extractor 到 UI 的完整情境匹配系統 |
| 交付節奏 | 前後端同步（Option B） | 一次到位，使用者體驗完整 |
| UI 互動 | 子類別網格（Option A） | 簡潔直覺，不需維護商家資料庫，Extractor 準確度高 |
| 覆蓋範圍 | 先做 4 個高汙染類別 | ENTERTAINMENT、DINING、SHOPPING、ONLINE |
| 無匹配處理 | 通用優惠自動 fallback | 核心目的是排除不相干場景優惠，不排除通用優惠 |
| Extractor 判斷方式 | 關鍵字規則 signal scoring | 與現有 infer_category 模式一致，簡單透明 |

## Phase 1 Subcategory Definitions

### ENTERTAINMENT

| Subcategory | Enum | 代表關鍵字 |
|-------------|------|-----------|
| 通用 | `GENERAL` | （無特定場景信號） |
| 電影 | `MOVIE` | 電影、影城、威秀、秀泰、國賓 |
| 遊樂園 | `THEME_PARK` | 樂園、遊樂、麗寶、六福村、劍湖山 |
| KTV/娛樂場所 | `VENUE` | KTV、好樂迪、錢櫃、桌遊 |
| 串流/票券 | `STREAMING` | Netflix、Spotify、KKBOX、串流、訂閱 |

### DINING

| Subcategory | Enum | 代表關鍵字 |
|-------------|------|-----------|
| 通用 | `GENERAL` | （無特定場景信號） |
| 外送 | `DELIVERY` | 外送、UberEats、foodpanda、熊貓 |
| 指定餐廳 | `RESTAURANT` | 指定餐廳、合作餐廳、特約餐廳 |
| 咖啡/飲料 | `CAFE` | 星巴克、咖啡、手搖、飲料 |
| 飯店餐飲 | `HOTEL_DINING` | 飯店、酒店、自助餐、buffet |

### SHOPPING

| Subcategory | Enum | 代表關鍵字 |
|-------------|------|-----------|
| 通用 | `GENERAL` | （無特定場景信號） |
| 百貨 | `DEPARTMENT` | 百貨、SOGO、新光三越、遠百、週年慶 |
| 量販/超市 | `WAREHOUSE` | Costco、好市多、家樂福、大潤發 |
| 3C/家電 | `ELECTRONICS` | 3C、家電、燦坤、全國電子 |

### ONLINE

| Subcategory | Enum | 代表關鍵字 |
|-------------|------|-----------|
| 通用 | `GENERAL` | （無特定場景信號） |
| 電商平台 | `ECOMMERCE` | 蝦皮、momo、PChome、博客來 |
| 行動支付 | `MOBILE_PAY` | Line Pay、街口、全盈、台灣Pay |
| 訂閱服務 | `SUBSCRIPTION` | 訂閱、月費、年費 |

### 未覆蓋類別

TRANSPORT、GROCERY、OVERSEAS、OTHER 在 Phase 1 不展開子類別，所有優惠視為 `GENERAL`。

## Data Model Changes

### New Field

所有層新增 `subcategory` 欄位，型別 `TEXT/String`，預設值 `"GENERAL"`。

### Extractor — Python Pydantic Model

```python
# models/promotion.py
class SubcategoryEnum(str, Enum):
    GENERAL = "GENERAL"
    # ENTERTAINMENT
    MOVIE = "MOVIE"
    THEME_PARK = "THEME_PARK"
    VENUE = "VENUE"
    STREAMING = "STREAMING"
    # DINING
    DELIVERY = "DELIVERY"
    RESTAURANT = "RESTAURANT"
    CAFE = "CAFE"
    HOTEL_DINING = "HOTEL_DINING"
    # SHOPPING
    DEPARTMENT = "DEPARTMENT"
    WAREHOUSE = "WAREHOUSE"
    ELECTRONICS = "ELECTRONICS"
    # ONLINE
    ECOMMERCE = "ECOMMERCE"
    MOBILE_PAY = "MOBILE_PAY"
    SUBSCRIPTION = "SUBSCRIPTION"

# PromotionNormalized 新增欄位：
subcategory: SubcategoryEnum = Field(default=SubcategoryEnum.GENERAL)
```

### DB Schema — SQLite + Supabase

```sql
ALTER TABLE promotion_versions ADD COLUMN subcategory TEXT NOT NULL DEFAULT 'GENERAL';
ALTER TABLE promotion_current ADD COLUMN subcategory TEXT NOT NULL DEFAULT 'GENERAL';
```

### Supabase Store

`_PROMOTION_VERSION_COLS` 和 `_PROMOTION_CURRENT_COLS` 各加入 `"subcategory"`。

### API — Java Domain

```java
// Promotion.java
private String subcategory;
```

`SqlitePromotionRepository.mapPromotions()` 和 `SupabasePromotionRepository.mapPromotion()` 各新增 `.subcategory(rs.getString("subcategory"))`。

### Contract Schema

`promotion-normalized.schema.json` 新增：
```json
"subcategory": { "type": "string", "default": "GENERAL" }
```

## Extractor — Subcategory Inference

### New Function: `infer_subcategory()`

```python
def infer_subcategory(
    title: str,
    body: str,
    category: str,
    subcategory_signals: Dict[str, Dict[str, List[tuple[str, int]]]],
) -> str:
    if category not in subcategory_signals:
        return "GENERAL"
    text = f"{title} {body}"
    scores = {
        sub: score_signals(text, signals)
        for sub, signals in subcategory_signals[category].items()
    }
    best = max(scores, key=scores.get)
    return best if scores[best] >= 3 else "GENERAL"
```

Reuses existing `score_signals()`. Threshold of 3 requires at least one medium-weight signal hit.

### Signal Dictionary

```python
SUBCATEGORY_SIGNALS: Dict[str, Dict[str, List[tuple[str, int]]]] = {
    "ENTERTAINMENT": {
        "MOVIE":      [("電影", 5), ("影城", 5), ("威秀", 4), ("秀泰", 4), ("國賓", 4), ("影廳", 3)],
        "THEME_PARK": [("樂園", 5), ("遊樂", 5), ("麗寶", 4), ("六福村", 4), ("劍湖山", 4), ("門票", 3)],
        "VENUE":      [("KTV", 5), ("好樂迪", 4), ("錢櫃", 4), ("桌遊", 3), ("保齡球", 3)],
        "STREAMING":  [("Netflix", 5), ("Spotify", 4), ("KKBOX", 4), ("串流", 4), ("Disney+", 4), ("訂閱", 2)],
    },
    "DINING": {
        "DELIVERY":     [("外送", 5), ("UberEats", 5), ("foodpanda", 5), ("熊貓", 4), ("Uber Eats", 5)],
        "RESTAURANT":   [("指定餐廳", 5), ("合作餐廳", 5), ("特約餐廳", 4), ("指定門市", 3)],
        "CAFE":         [("星巴克", 5), ("Starbucks", 5), ("咖啡", 3), ("手搖", 4), ("飲料", 2)],
        "HOTEL_DINING": [("飯店", 4), ("酒店", 4), ("自助餐", 3), ("buffet", 4), ("Buffet", 4)],
    },
    "SHOPPING": {
        "DEPARTMENT":   [("百貨", 5), ("SOGO", 5), ("新光三越", 5), ("遠百", 5), ("週年慶", 4), ("統一時代", 4)],
        "WAREHOUSE":    [("Costco", 5), ("好市多", 5), ("家樂福", 5), ("大潤發", 5), ("量販", 4)],
        "ELECTRONICS":  [("3C", 5), ("家電", 4), ("燦坤", 5), ("全國電子", 5), ("Apple Store", 4)],
    },
    "ONLINE": {
        "ECOMMERCE":    [("蝦皮", 5), ("momo", 5), ("PChome", 5), ("博客來", 4), ("Yahoo", 3), ("樂天", 4)],
        "MOBILE_PAY":   [("Line Pay", 5), ("街口", 5), ("全盈", 4), ("台灣Pay", 4), ("悠遊付", 4)],
        "SUBSCRIPTION": [("訂閱", 4), ("月費", 3), ("年費", 3), ("自動扣繳", 3)],
    },
}
```

### Bank Extractor Integration

5 bank extractors (`cathay_real.py`, `esun_real.py`, `fubon_real.py`, `ctbc_real.py`, `taishin_real.py`) — identical change pattern:

1. Import `infer_subcategory` from `promotion_rules`
2. After `infer_category()` call, add: `subcategory = infer_subcategory(title, body, category, SUBCATEGORY_SIGNALS)`
3. Include `"subcategory": subcategory` in the promotion dict

## API — DecisionEngine Filter Logic

### RecommendationRequest + RecommendationScenario

```java
// RecommendationRequest.java — new top-level field + resolver
private String subcategory;

@JsonIgnore
public String getResolvedSubcategory() {
    return scenario != null && scenario.getSubcategory() != null && !scenario.getSubcategory().isBlank()
            ? scenario.getSubcategory()
            : subcategory;
}
```

```java
// RecommendationScenario.java — new field
private String subcategory;
```

`toResolvedScenario()` adds `.subcategory(getResolvedSubcategory())`.

### DecisionEngine.isEligible() — New Filter

Inserted after the existing category match (line ~112):

```java
String requestSubcategory = request.getResolvedSubcategory();
String promoSubcategory = normalizeValue(promotion.getSubcategory());

if (!"GENERAL".equals(promoSubcategory) && !promoSubcategory.isBlank()) {
    if (requestSubcategory == null || requestSubcategory.isBlank()) {
        return false;  // General query → exclude scene-specific promotions
    }
    if (!promoSubcategory.equals(normalizeValue(requestSubcategory))) {
        return false;  // Different scene → exclude
    }
}
```

Truth table:

| Promotion subcategory | Request subcategory | Result |
|----------------------|--------------------|----|
| `GENERAL` | any or empty | Pass |
| `MOVIE` | empty (general query) | **Exclude** |
| `MOVIE` | `MOVIE` | Pass |
| `MOVIE` | `THEME_PARK` | **Exclude** |

### CardRecommendation Response

```java
// CardRecommendation.java — new field
private String subcategory;
```

`toRecommendation()` includes `.subcategory(promotion.getSubcategory())`.

### Contract Schema Updates

`recommendation-request.schema.json`: add `"subcategory": { "type": "string" }` to top-level and `scenario` object.

`recommendation-response.schema.json`: add `"subcategory": { "type": "string" }` to `CardRecommendation`.

## Frontend

### New Component: `SubcategoryGrid.tsx`

Renders a horizontal row of chips below `CategoryGrid` when the selected category has subcategories. Only appears for ENTERTAINMENT, DINING, SHOPPING, ONLINE.

```
┌─────────────────────────────────┐
│ 消費類別                         │
│ [🍽️餐飲] [🛒網購] [🏪超市] [🚗交通] │
│ [✈️海外] [🏬百貨] [🎬娛樂] [📦其他] │
│                                 │
│ 消費場景（可不選）                  │
│ [全部] [外送] [指定餐廳] [咖啡] [飯店] │
└─────────────────────────────────┘
```

Behavior:
- Default: "全部" highlighted = general query, excludes scene-specific promotions
- Selecting a subcategory: that scene + GENERAL promotions ranked together
- Switching category: subcategory resets to null (general)
- Categories without subcategories: row hidden
- Style: same as CategoryGrid chips but smaller, horizontal scrollable single row

### `enums.ts` Addition

```typescript
export const SUBCATEGORIES: Partial<Record<Category, { value: string; label: string }[]>> = {
  ENTERTAINMENT: [
    { value: 'MOVIE', label: '電影' },
    { value: 'THEME_PARK', label: '遊樂園' },
    { value: 'VENUE', label: 'KTV/娛樂' },
    { value: 'STREAMING', label: '串流訂閱' },
  ],
  DINING: [
    { value: 'DELIVERY', label: '外送' },
    { value: 'RESTAURANT', label: '指定餐廳' },
    { value: 'CAFE', label: '咖啡/飲料' },
    { value: 'HOTEL_DINING', label: '飯店餐飲' },
  ],
  SHOPPING: [
    { value: 'DEPARTMENT', label: '百貨' },
    { value: 'WAREHOUSE', label: '量販' },
    { value: 'ELECTRONICS', label: '3C家電' },
  ],
  ONLINE: [
    { value: 'ECOMMERCE', label: '電商平台' },
    { value: 'MOBILE_PAY', label: '行動支付' },
    { value: 'SUBSCRIPTION', label: '訂閱服務' },
  ],
}
```

### `CalcPage.tsx` Changes

- New state: `const [subcategory, setSubcategory] = useState<string | null>(null)`
- Category change handler resets subcategory to null
- Request includes `subcategory: subcategory ?? undefined`
- Auto-select cards call also passes subcategory

### `api.ts` Changes

```typescript
// RecommendationRequest — add field
subcategory?: string

// CardRecommendation — add field
subcategory?: string
```

### `ResultPanel.tsx` Changes

When `rec.subcategory` is not `GENERAL`, display a small muted badge next to the cashback amount (e.g. `[外送優惠]`).

## Testing Strategy

### Extractor

- Unit test `infer_subcategory()` with known promotion titles
- Verify threshold behavior: weak signals (score < 3) → GENERAL
- Verify non-Phase-1 categories always return GENERAL

### API

- Unit test `isEligible()` subcategory filtering (all 4 truth table cases)
- Integration test: general query excludes scene-specific promotions
- Integration test: subcategory query includes GENERAL + matching subcategory
- Verify backward compatibility: requests without subcategory field work as before (treat as general query — which now EXCLUDES scene-specific promotions; this is the intended behavior change)

### Frontend

- SubcategoryGrid renders only for the 4 configured categories
- Category switch resets subcategory
- Request payload includes subcategory when selected
- Result badges render for non-GENERAL promotions

## Backward Compatibility

- **API**: Requests without `subcategory` field are treated as general queries. This is a **behavior change** for existing clients: scene-specific promotions that previously appeared in general queries will now be excluded. This is intentional — it fixes the ranking pollution problem.
- **DB**: `DEFAULT 'GENERAL'` ensures existing rows are valid without migration scripts.
- **Extractor**: Existing promotions without subcategory default to GENERAL and remain in general query results.
- **Rollout order**: The behavior change is safe to deploy before re-extraction. Since all existing DB rows default to `GENERAL`, the subcategory filter is effectively a no-op until extractors re-run and tag promotions with specific subcategories. No data loss or ranking disruption during the transition window.

## Future Extensions

- Add subcategories for TRANSPORT, GROCERY, OVERSEAS, OTHER when pollution warrants it
- Layer merchant-name autocomplete on top of subcategory selection (evolving toward Option C)
- Use subcategory data to build per-scene landing pages
