# CardSense 推薦引擎與目錄增強設計

> Date: 2026-03-28

## 概述

六項調整涵蓋：資料模型擴充、推薦引擎邏輯修改、前端篩選與顯示增強。

---

## 1. 職業別/特別資格卡片排除

### 問題

會計師卡、牙醫師卡等職業限定卡目前仍被列入推薦計算，應排除。

### 設計

- `CardSummary` 新增 `eligibilityType: String` 欄位
- 值域：`GENERAL`（一般）、`PROFESSION_SPECIFIC`（職業限定）、`BUSINESS`（商務/公司卡）
- 推薦引擎在篩選階段排除 `eligibilityType != GENERAL` 的卡片
- 目錄頁可依此欄位做篩選

### 影響範圍

- `CardSummary.java`：新增欄位
- `Promotion.java`：對應欄位（來源資料）
- `DecisionEngine.java`：過濾邏輯
- `CatalogService.java`：查詢參數
- 前端 `enums.ts`、`api.ts`：型別定義
- 資料庫 `promotion_current` 表：新增欄位
- Contracts schema：新增定義

---

## 2. 電商平台與通路個別處理

### 問題

momo、shopee、PCHome 等電商平台的專屬優惠無法與「線上通路通用」優惠區分。實體通路（全聯、好市多）與支付平台（LINE Pay、街口）也有類似需求。

### 設計

在 `PromotionCondition` 新增三個 condition type：

| Condition Type | 用途 | value 範例 |
|---|---|---|
| `ECOMMERCE_PLATFORM` | 電商平台限定 | `MOMO`, `SHOPEE`, `PCHOME` |
| `RETAIL_CHAIN` | 實體通路限定 | `COSTCO`, `PXMART`, `CARREFOUR` |
| `PAYMENT_PLATFORM` | 支付平台限定 | `LINE_PAY`, `JKOPAY`, `TAIWAN_PAY` |

### 匹配邏輯

- Scenario 帶入 `merchantName` 時，引擎檢查 promotion 的 conditions 是否包含上述三種 type
- 有的話做 value 精確比對：匹配則保留，不匹配則排除該 promotion
- 沒有這些 condition 的 promotion 視為「通路不限」，照常匹配
- Scenario 未帶 `merchantName` 時，含有這些 condition 的 promotion 不參與匹配

### 影響範圍

- `PromotionCondition` type 值域擴充
- `DecisionEngine.java`：匹配邏輯新增 condition type 處理
- 前端 `RecommendationForm`：可選擇性新增平台/通路選項
- Contracts schema：condition type 定義更新
- Extractor：解析時標記 condition

---

## 3. 卡片目錄頁篩選標籤

### 問題

目前 CardsPage 只能依銀行篩選和文字搜尋，標籤不足。

### 設計

新增以下篩選維度（以標籤/下拉形式呈現）：

1. **銀行**（現有）
2. **資格類型** — `eligibilityType`：一般 / 職業限定 / 商務卡
3. **優惠類別** — 該卡擁有的 promotion categories：餐飲、交通、網購、海外、購物、超市、娛樂、其他
4. **年費區間** — 免年費（0）/ 低年費（1-999）/ 高年費（1000+）
5. **推薦範圍** — `recommendationScope`：可推薦 / 僅目錄

### 資料需求

- `CardSummary` API 回傳需附帶 `eligibilityType`
- 優惠類別篩選需要知道每張卡有哪些 category 的 promotion
  - 方案：API 回傳 `CardSummary` 時附帶 `availableCategories: String[]`
  - 或前端額外呼叫 promotion API 取得（增加請求數，不建議）
  - **決定：擴充 `CardSummary` 增加 `availableCategories` 欄位**

### 影響範圍

- `CardSummary.java`：新增 `availableCategories` 欄位
- `CatalogService.java`：組裝 `availableCategories`
- `GET /v1/cards`：新增查詢參數 `eligibilityType`
- 前端 `CardsPage.tsx`：篩選 UI 元件
- 前端型別定義更新

---

## 4. 卡片詳細頁顯示優惠資訊

### 問題

CardDetailPage 目前只顯示基本資料，沒有優惠資訊。

### 設計

- 新增 API 端點：`GET /v1/cards/{cardCode}/promotions`
  - 回傳該卡所有目前有效的 promotions
  - 依 category 分組
- 前端 CardDetailPage 新增「優惠資訊」區塊
  - 依 category 分組顯示（例如：餐飲、網購各一個區塊）
  - 每筆 promotion 顯示：title、回饋類型與值、有效期間、限制條件
  - `MUTUALLY_EXCLUSIVE` 的 promotion 標示「需切換權益模式」提醒

### 影響範圍

- 新增 API 端點及 Controller method
- `PromotionRepository`：新增依 cardCode 查詢方法
- 前端 `CardDetailPage.tsx`：優惠列表元件
- 前端 API hooks：新增 `useCardPromotions`

---

## 5. 權益切換型卡片（Cube 卡類型）

### 問題

國泰 Cube 卡等需切換權益模式的卡片，在比較時需考慮不同模式的回饋，並提醒使用者切換。

### 設計

使用現有 `PromotionStackability` 機制：

- 同一張卡的不同權益模式設為同一個 `groupId`
- `relationshipMode: MUTUALLY_EXCLUSIVE`
- 引擎在疊加計算時自動從同 group 中選最佳的一筆
- 提醒文字透過 `conditions` 帶入：`{ type: "TEXT", value: "需切換至網購模式" }`

### 不需要的變更

- 不新增 `benefitMode` 欄位
- 不修改 schema 結構
- 如果未來更多銀行推出類似卡型再評估是否需要獨立欄位

### 影響範圍

- 資料層：Cube 卡的 promotions 設定正確的 stackability metadata
- 前端：`PromotionRewardBreakdown` 顯示時，偵測 `MUTUALLY_EXCLUSIVE` 並渲染提醒
- Extractor：解析 Cube 卡類型時正確標記 groupId 和 relationshipMode

---

## 6. 移除比較模式，固定使用疊加計算

### 問題

`BEST_SINGLE_PROMOTION` 模式的結果是 `STACK_ALL_ELIGIBLE` 的子集，沒有實質獨立用途。

### 設計

- 移除 `ComparisonMode` enum
- 移除 API request 中的 `mode` 欄位（或接受但忽略，向後相容過渡期）
- `DecisionEngine` 固定走 `STACK_ALL_ELIGIBLE` 路徑
- 前端移除模式切換 UI

### 影響範圍

- `ComparisonMode.java`：移除
- `DecisionEngine.java`：移除模式分支，固定疊加路徑
- API request/response schema：移除 `mode` 相關欄位
- 前端 `RecommendationForm.tsx`：移除模式選擇器
- 前端 `enums.ts`：移除 `COMPARISON_MODES`
- Contracts schema：更新

---

## 實作順序建議

1. **資料模型變更**（第 1、2 點）— 擴充 schema、domain、資料庫
2. **引擎邏輯修改**（第 5、6 點）— 移除 ComparisonMode、eligibility 過濾、condition 匹配
3. **API 擴充**（第 3、4 點的後端部分）— 新端點、查詢參數
4. **前端更新**（第 3、4、6 點的前端部分）— 篩選標籤、優惠顯示、移除模式選擇器
5. **資料修正** — 更新現有 promotions 的 eligibilityType、condition type、Cube 卡 stackability
