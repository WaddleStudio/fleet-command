# CardSense — 即時匯率與價值轉換引擎 (Exchange Rate Engine)
### Version 1.1 | 2026-04-09

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

- [ ] 高階點數 / 哩程估值再細化，補齊銀行別與航空計畫 program-level 估值
- [ ] `/calc` 接入同一套匯率牌告板
- [ ] 分享圖顯示本次使用匯率與估值來源

### 2.5 已上線的推薦頁匯率板

RecommendationForm 先以 trigger button 開啟右側 drawer，讓使用者在推薦頁直接調整匯率估值，不必先進 `/calc`。

- `POINTS` / `MILES` 已以 section 分組，保留 `_DEFAULT` 與銀行 / 計畫別 row；板面只呈現 `unit` 與 `note`。
- board row 只顯示 `unit` 與 `note`；自訂匯率由 recommendation flow 的 request/state 驅動。
- `/calc` 的整合與分享圖聯動保留到下一階段
- 更細的 program-level explainability 仍是後續項目

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

- 尚未做成獨立的「匯率牌告看板」視覺區塊
- 尚未把匯率資訊帶進分享圖 / Canvas
- 尚未對高階哩程玩家提供更細的 program-level explainability

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

1. 補強 `POINTS` / `MILES` 的銀行別與 program-level 估值
2. 把匯率資訊延伸到 `/calc` 分享圖
3. 讓使用者在「我的卡包」裡保存個人估值偏好
4. 視覺上做出更強的「匯率牌告板」金融工具感

---

## 9. 結論

Exchange Rate Engine 已從「概念規格」進入「核心能力已落地」階段。

現在 CardSense 已具備：

- `MILES` / `POINTS` / `TWD` 三類回饋統一排序
- 系統預設匯率 + 使用者自訂匯率
- API / contracts / web 三層一致的契約
- 可解釋的 `rewardDetail`

後續重點不再是「有沒有這個功能」，而是把估值模型做得更細、更像真正高階玩家會用的工具。
