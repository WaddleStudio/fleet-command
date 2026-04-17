# CardSense — 即時匯率與價值轉換引擎 (Exchange Rate Engine)
### Version 1.2 | 2026-04-10

---

## 1. 目標

讓 CardSense 能把 **現金回饋、點數、哩程** 統一轉換成 **等值台幣 (TWD)**，再進行跨卡比較與排序。

這項能力的核心價值不只是「支援 `MILES`」，而是：

- 同一個推薦引擎可以直接比較哩程卡與現金回饋卡
- 玩家可以依自己的估值覆寫系統預設匯率
- 推薦結果不只回傳總回饋，還能解釋「原始回饋單位 → 匯率 → 等值台幣」的計算過程

---

## 2. 目前落地狀態

截至 2026-04-09，Exchange Rate Engine 已完成核心串接。

### 2.1 API 已完成

- [x] `exchange-rates.json` 作為系統預設匯率表
- [x] `ExchangeRateService` 載入與管理系統匯率
- [x] `RewardCalculator` 支援 `POINTS` / `MILES` 轉換為 TWD
- [x] `RecommendationRequest.customExchangeRates`
- [x] `RewardDetail` 回傳欄位
- [x] `GET /v1/exchange-rates`
- [x] Break-even / cap saturation 計算已納入 `POINTS` / `MILES`

### 2.2 Contracts 已完成

- [x] `promotion-normalized.schema.json` 支援 `MILES`
- [x] `recommendation-request.schema.json` 支援 `customExchangeRates`
- [x] `recommendation-response.schema.json` 支援 `rewardDetail`
- [x] recommendation request / response example 已同步更新

### 2.3 Web 撌脣???

- [x] ?刻銵典?游? `ExchangeRatesPanel`
- [x] 雿輻?閬神?身?舐?敺?刻 API
- [x] ?刻蝯??芣??敦憿舐內 `rawReward ? exchangeRate`
- [x] `MILES` / `POINTS` ??蝷箸?獢?憿舐內?澆?撌脰?朣?
- [x] Card detail ?甇?Ⅱ憿舐內 `MILES`
- [x] RecommendationForm 已改成 trigger button + right-side drawer，內含 dense 匯率牌告板
- [x] 匯率牌告板已分成 `POINTS` / `MILES` 兩個 section

### 2.4 隞?鋆撥

- [~] 高階點數 / 哩程估值再細化，已補上首批航空計畫 profile-aware 命中與 alias coverage（如 `Cathay Pacific` / `Japan Airlines`），持續補齊更多銀行別與航空計畫 program-level 估值
- [x] 首頁計算機接入同一套匯率牌告板（左欄 inline 工具面板）
- [x] 分享圖顯示本次使用匯率與估值來源摘要（system default / custom overrides）
- [ ] 將目前覆寫面板進一步收斂成 calculator 風格的 dense 匯率牌告板 UI

### 2.5 已上線的推薦頁匯率板

`/recommend` 推薦頁以 trigger button 開啟右側 drawer，讓使用者直接調整匯率估值；首頁計算機（原 `/calc`，現為 `/`）也已接入同一套 shared board semantics，改用左欄 inline 工具面板承接 calculator 節奏。

- `POINTS` / `MILES` 已以 section 分組，保留 `_DEFAULT` 與銀行 / 計畫別 row；板面會顯示來源類型（system default / bank program / program profile）、context 與 `note`。
- board row 以 explainability badge + context line + value formula 呈現；自訂匯率由 recommendation flow 的 request/state 驅動。
- 分享圖已補上本次使用匯率與估值來源摘要；推薦結果也已補上 `rewardDetail` 的換算式、估值來源與 note；更細的 explainability 保留到下一階段。
- 更細的 program-level explainability 仍是後續項目，但 API 已會依 promotion metadata 與 airline alias 命中首批航空計畫 row。

---
## 3. 匯率資料結構

目前系統使用 `cardsense-api/src/main/resources/exchange-rates.json`：

```json
{
  "version": "2026-04-08",
  "rates": {
    "POINTS": {
      "CTBC":    { "value": 1.0, "unit": "LINE Points",  "note": "1:1 折抵消費" },
      "CATHAY":  { "value": 1.0, "unit": "小樹點",       "note": "1:1 折抵消費" }
    },
    "MILES": {
      "_DEFAULT":     { "value": 0.40, "unit": "航空哩程", "note": "保守估值" },
      "ASIA_MILES":   { "value": 0.40, "unit": "亞洲萬里通", "note": "國泰/港龍經濟艙" },
      "EVA_INFINITY": { "value": 0.50, "unit": "長榮哩程", "note": "亞洲區段經濟艙" }
    }
  }
}
```

### 設計重點

- `POINTS.{BANK_CODE}`：優先用銀行別估值
- `MILES._DEFAULT`：提供通用保守估值
- 若使用者傳入 `customExchangeRates`，優先權高於系統預設值

---

## 4. API 契約

### 4.1 Request

`POST /v1/recommendations/card`

```json
{
  "scenario": {
    "category": "TRAVEL",
    "amount": 60000,
    "subcategory": "AIRLINE"
  },
  "customExchangeRates": {
    "MILES._DEFAULT": 0.60,
    "POINTS.ESUN": 0.80
  }
}
```

### 規則

- Key 格式：`{cashbackType}.{bankCode}` 或 `{cashbackType}._DEFAULT`
- 目前允許：
  - `POINTS.XXX`
  - `MILES.XXX`
- Value：1 單位回饋對應的 TWD 價值

### 4.2 Response

`CardRecommendation.rewardDetail` / `PromotionRewardBreakdown.rewardDetail`

```json
{
  "rewardDetail": {
    "rawReward": 4000,
    "rawUnit": "航空哩程",
    "exchangeRate": 0.40,
    "exchangeRateSource": "SYSTEM_DEFAULT",
    "ntdEquivalent": 1600,
    "note": "航空哩程 × 0.40 TWD/哩"
  }
}
```

### 欄位說明

| 欄位 | 說明 |
|------|------|
| `rawReward` | 原始回饋數量 |
| `rawUnit` | 原始回饋單位 |
| `exchangeRate` | 使用的 TWD 匯率 |
| `exchangeRateSource` | `SYSTEM_DEFAULT` / `USER_CUSTOM` |
| `ntdEquivalent` | 換算後等值台幣 |
| `note` | 人類可讀的換算說明 |

### 4.3 牌告 Endpoint

`GET /v1/exchange-rates`

用途：

- 前端渲染匯率面板
- 顯示目前系統預設估值
- 作為使用者自訂匯率的 placeholder / baseline

---

## 5. 前端呈現

### 5.1 目前已上線

#### 推薦表單

- 已有「自訂點數與里程價值」折疊面板
- 由 `ExchangeRatesPanel` 讀取 `/v1/exchange-rates`
- 只有與預設值不同的項目才會送到 API

#### 推薦結果

- 優惠明細會顯示：

```text
4,000 航空哩程 × 0.40 TWD
```

- `CashbackDisplay` 會依 `cashbackType` 顯示：
  - `% 回饋`
  - `點數回饋`
  - `每 X 元 1 哩`

#### Card Detail

- `MILES` 不再被誤當成缺漏型別
- 點數型優惠也區分：
  - 固定點數
  - 百分比點數回饋

### 5.2 尚未完全達標

- 尚未做成獨立的「匯率牌告板」視覺區塊，現況仍偏設定面板而非金融工具牌告
- 已把匯率資訊摘要帶進分享圖 / Canvas
- 已補基礎結果 explainability（換算式 / source / note），API 端也已能依 `cardCode` / `cardName` / `title` / `conditions` 與 `Cathay Pacific` / `Japan Airlines` 等 alias 命中 `ASIA_MILES`、`EVA_INFINITY`、`JALPAK` 等 miles profile；但尚未對高階哩程玩家提供更完整的 program-level explainability

### 5.3 匯率牌告板 UI 方向

- 參考傳統匯率牌告表的 dense list 結構，沿用首頁計算機現有的深色 fintech 元件語言，而非直接複製舊式黑底紫字 App 視覺
- 畫面結構分為兩段：上方顯示本次比較基準（例如 `TWD = 100` 或「系統預設」），下方以固定 row rhythm 列出所有點數 / 哩程估值
- 每列維持三段資訊：左側顯示銀行 / 計畫 badge 與單位名稱，中段用大數字呈現估值，右側顯示 `SYSTEM_DEFAULT` / `USER_CUSTOM` 或最近同步狀態
- 數值排版應強化「牌告」感，例如使用等寬數字、細分隔線、整齊對齊與高對比 accent 色，避免一般設定表單的鬆散卡片感
- `USER_CUSTOM` 應以 calculator 頁既有 chip / badge 語言標示，讓使用者一眼看出哪些估值是自行覆寫
- 不採用國旗隱喻；點數 / 哩程項目更適合使用銀行縮寫 badge、計畫 icon 或簡潔 logo block
- 若沒有明確即時行情需求，右側優先顯示來源與覆寫狀態，不以完整 datetime 為主要資訊
- 互動上可保留 inline edit 或展開編輯，但整體定位應維持「專業工具」而非「系統設定頁」

---

## 6. 實作對應

### API

- `ExchangeRateService`
- `RewardCalculator`
- `RecommendationRequest.customExchangeRates`
- `RewardDetail`
- `ExchangeRateController`

### Web

- `RecommendationForm`
- `ExchangeRatesPanel`
- `RecommendationResults`
- `CardDetailPage`

### Contracts

- `promotion/promotion-normalized.schema.json`
- `recommendation/recommendation-request.schema.json`
- `recommendation/recommendation-response.schema.json`

---

## 7. 目前限制

### 7.1 估值粒度仍偏粗

雖然系統已支援 `POINTS` / `MILES`，但目前仍以：

- 銀行別點數估值
- 通用或少數 program-level 哩程估值

為主，尚未細到：

- 不同兌換艙等
- 淡旺季
- 航空聯盟別
- 點數轉點折損

### 7.2 比較模型仍以 TWD 等值為核心

這是設計上的刻意取捨：

- 優點：推薦可排序、可解釋、可 deterministic
- 缺點：無法完整表達哩程玩家對「稀缺票價值」的主觀偏好

所以 `customExchangeRates` 會是長期保留的核心能力。

---

## 8. 下一步

1. 補強 `POINTS` / `MILES` 的更多銀行別與 program-level 估值，目前先完成首批 miles profile-aware 命中與部分 airline alias coverage
2. 補強首頁分享圖中的匯率細節與更完整的 program-level explainability
3. 讓使用者在「我的卡包」裡保存個人估值偏好
4. 將目前面板升級為首頁計算機風格的 dense「匯率牌告板」，強化金融工具感與可掃讀性

---

## 9. 結論

Exchange Rate Engine 已從「概念規格」進入「核心能力已落地」階段。

現在 CardSense 已具備：

- `MILES` / `POINTS` / `TWD` 三類回饋統一排序
- 系統預設匯率 + 使用者自訂匯率
- API / contracts / web 三層一致的契約
- 可解釋的 `rewardDetail`

後續重點不再是「有沒有這個功能」，而是把估值模型做得更細、更像真正高階玩家會用的工具。
