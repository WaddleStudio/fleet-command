# BenefitPlan 權益切換設計

> 日期：2026-03-30
> 狀態：Draft
> 範圍：cardsense-contracts, cardsense-extractor, cardsense-api, cardsense-web

## 背景

台灣市場上有一類「切換卡」，用戶可自選/切換某個權益方案來享有指定通路的最高回饋。目前三大切換卡：

| 卡片 | 銀行 | 方案數 | 切換頻率 | 最高回饋 |
|------|------|--------|---------|---------|
| CUBE卡 | 國泰世華 (CATHAY) | 4 個常駐方案（玩數位、樂饗購、趣旅行、集精選） | 每天 1 次 | 3.3% (L3) |
| Richart卡 | 台新 (TAISHIN) | 7 大權益方案（Pay著刷、天天刷、大筆刷、好饗刷、數趣刷、玩旅刷、假日刷） | 每天 1 次 | 3.8% |
| Unicard | 玉山 (ESUN) | 3 大回饋方案（簡單選、任意選、UP選） | 每月最多 30 次 | 4.5~5% |

現有 promotion 模型是「一個 promotion = 一個固定類別 + 固定回饋率」，無法表達：
- 一個方案內包含多個通路優惠
- 同卡方案之間互斥（同時只能啟用一個）
- 方案本身的元資料（切換頻率、訂閱需求等）

## 設計決策

| 決策 | 選擇 | 理由 |
|------|------|------|
| 資料模型 | 新增獨立 BenefitPlan entity | 方案有自身屬性（切換頻率、訂閱成本等），純欄位會造成重複和遺漏 |
| Plan 元資料產生位置 | API 端維護 | 方案元資料變動頻率低，不需每次爬蟲擷取；Extractor 只負責 planId 對應 |
| 推薦引擎呈現方式 | 推薦最佳方案 + 附註切換提示 | 兼顧推薦精準度和用戶操作指引 |
| 用戶狀態追蹤 | Phase 2（有卡片管理功能後） | 先做純推薦，不追蹤用戶目前設定 |

## 資料模型

### 新增 Entity：BenefitPlan

```json
{
  "planId": "CATHAY_CUBE_DIGITAL",
  "bankCode": "CATHAY",
  "cardCode": "CATHAY_CUBE",
  "planName": "玩數位",
  "planDescription": "涵蓋電商、串流、AI工具等通路",
  "switchFrequency": "DAILY",
  "switchMaxPerMonth": null,
  "requiresSubscription": false,
  "subscriptionCost": null,
  "exclusiveGroup": "CATHAY_CUBE_PLANS",
  "status": "ACTIVE",
  "validFrom": "2026-01-01",
  "validUntil": "2026-06-30"
}
```

#### 欄位說明

| 欄位 | 型別 | 說明 |
|------|------|------|
| `planId` | string | 唯一識別，如 `CATHAY_CUBE_DIGITAL` |
| `bankCode` | string | 銀行代碼 |
| `cardCode` | string | 卡片代碼 |
| `planName` | string | 方案名稱，如「玩數位」 |
| `planDescription` | string | 方案描述 |
| `switchFrequency` | enum | `DAILY` / `MONTHLY` / `UNLIMITED` |
| `switchMaxPerMonth` | int\|null | 每月切換上限，null 表示無限制 |
| `requiresSubscription` | boolean | 是否需要訂閱才能使用 |
| `subscriptionCost` | string\|null | 訂閱費用描述，如 `"149 e point"` |
| `exclusiveGroup` | string | 同卡方案共用，標記互斥關係 |
| `status` | enum | `ACTIVE` / `EXPIRED` |
| `validFrom` | date | 方案生效日 |
| `validUntil` | date | 方案到期日 |

#### switchFrequency 列舉

| 值 | 說明 | 適用卡片 |
|----|------|---------|
| `DAILY` | 每天可切換 1 次 | CUBE卡、Richart卡 |
| `MONTHLY` | 每月有切換次數限制（見 switchMaxPerMonth） | Unicard |
| `UNLIMITED` | 無限制 | 預留 |

### Promotion 變更

現有 promotion schema 新增一個欄位：

```json
{
  "planId": "CATHAY_CUBE_DIGITAL"
}
```

- `planId: string|null` — `null` 代表傳統卡（無切換），有值代表屬於某方案

### 資料關係範例

```
Card: CATHAY_CUBE (國泰 CUBE卡)
 │
 ├── BenefitPlan: "玩數位"  (exclusiveGroup: "CATHAY_CUBE_PLANS")
 │    ├── Promotion: 蝦皮 3%
 │    ├── Promotion: momo 3%
 │    ├── Promotion: Netflix 3%
 │    └── Promotion: ChatGPT 3%
 │
 ├── BenefitPlan: "樂饗購"  (exclusiveGroup: "CATHAY_CUBE_PLANS")
 │    ├── Promotion: SOGO 3%
 │    └── Promotion: 新光三越 3%
 │
 ├── BenefitPlan: "趣旅行"  (exclusiveGroup: "CATHAY_CUBE_PLANS")
 │    └── Promotion: 航空/飯店/旅遊平台 3%
 │
 ├── BenefitPlan: "集精選"  (exclusiveGroup: "CATHAY_CUBE_PLANS")
 │    ├── Promotion: 7-ELEVEN 2%
 │    ├── Promotion: 全家 2%
 │    └── Promotion: 全聯 2%
 │
 └── Promotion: 基本回饋 0.3%  (planId: null, 無需切換，始終生效)
```

## 推薦引擎邏輯

### DecisionEngine 變更

在計算階段新增方案選擇邏輯：

```
1. 篩選 eligible promotions（不變）

2. 分組處理：
   ├── 傳統 promotions (planId = null)
   │    └── 照舊計算，可疊加
   │
   └── 有 planId 的 promotions
        ├── 按 exclusiveGroup 分組
        ├── 每組內按 planId 再分組
        ├── 計算每個方案對當前消費的總回饋
        └── 選出最佳方案，其餘方案丟棄

3. 排名：最佳方案的回饋 + 傳統 promotions 一起參與排名
```

### 範例

用戶查：蝦皮消費 3000 元

```
CUBE卡 eligible promotions:
  ├── planId=null:    基本回饋 0.3% → 9元
  ├── 玩數位方案:     蝦皮 3% → 90元  ← 最佳方案
  ├── 樂饗購方案:     (蝦皮不適用) → 0元
  ├── 集精選方案:     (蝦皮不適用) → 0元
  └── 趣旅行方案:     (蝦皮不適用) → 0元

結果：CUBE卡回饋 = 90元（玩數位方案）
附註：需切換至「玩數位」方案
```

### Response 變更

`CardRecommendation` 新增欄位：

```json
{
  "activePlan": {
    "planId": "CATHAY_CUBE_DIGITAL",
    "planName": "玩數位",
    "switchRequired": true,
    "switchFrequency": "每天可切換1次"
  }
}
```

- `activePlan: object|null` — `null` 代表傳統卡，有值代表推薦引擎選出的最佳方案

## 各層實作影響

### Contracts (`cardsense-contracts`)

- 新增 `benefit-plan/benefit-plan.schema.json`
- 修改 `promotion/promotion-normalized.schema.json`：加 `planId` 欄位（nullable string）
- 修改 `recommendation/recommendation-response.schema.json`：`CardRecommendation` 加 `activePlan` 欄位
- 新增 `taxonomy/switch-frequency-taxonomy.json`：`DAILY / MONTHLY / UNLIMITED`

### Extractor (`cardsense-extractor`)

- 各銀行 extractor 輸出 promotion 時帶上 `planId`
- `normalize.py`：新增 `planId` 欄位處理（直接透傳，不做推導）
- `models/promotion.py`：Pydantic model 加 `planId: str | None = None`
- **不處理** Plan 元資料

### API (`cardsense-api`)

- 新增 `BenefitPlan` domain class
- 新增 `BenefitPlanRepository`：Plan 元資料儲存（JSON 設定檔或 SQLite 新表）
- `DecisionEngine`：加方案分組 + 最佳方案選擇邏輯
- `CardRecommendation`：加 `activePlan` 欄位
- 新增 endpoint：`GET /v1/cards/{cardCode}/plans` — 查詢某卡的可用方案

### Web (`cardsense-web`)

- 推薦結果：顯示方案切換提示（如「需切換至『玩數位』方案」）
- 卡片詳情頁：顯示該卡所有可用方案列表

### 不影響的部分

- `versioning.py`：`planId` 自然加入 semantic payload，無需特殊處理
- `stackability`：方案互斥由 `BenefitPlan.exclusiveGroup` 處理，不經現有 stackability 機制

## Phase 2：用戶狀態追蹤（未來）

當系統加入「用戶卡片管理」功能後，可擴展為：

- 用戶可設定「我的 CUBE 卡目前在『玩數位』方案」
- 推薦引擎可據此判斷是否需要切換，或直接以當前方案計算
- `switchRequired` 可根據用戶當前方案動態判定（已在目標方案 → false）
