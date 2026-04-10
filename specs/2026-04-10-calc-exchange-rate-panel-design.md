# CardSense - Calc Exchange Rate Panel Design
### Date: 2026-04-10

---

## 1. Goal

將已經在 `RecommendationForm` 落地的匯率牌告能力，擴展到 `/calc`，做成左欄內的 inline 工具面板，而不是沿用 drawer。

這一輪的目標不是重做 Exchange Rate Engine，也不是重做整個 calculator 頁面，而是把既有的 shared board / rate semantics 接到第二個 surface，形成最小閉環：

1. `/calc` 可以直接查看並調整 `POINTS` / `MILES` 匯率
2. `/calc` 送出的 request 可以帶上 `customExchangeRates`
3. `/calc` 的 auto-select 與正式試算都使用同一套自訂估值
4. `RecommendationForm` 現有 drawer 流程保持不變

---

## 2. Scope

### 2.1 In Scope

- 在 `/calc` 左欄加入 inline 匯率工具面板
- 重用既有 `ExchangeRatesBoard`
- 重用既有 exchange-rate normalization / override semantics
- 在 `CalcPage` 新增 `customExchangeRates` state
- 將 `customExchangeRates` 接入：
  - auto-select recommendation request
  - submit recommendation request

### 2.2 Out of Scope

- 不變更 contracts
- 不新增新的 request key 規格
- 不新增 program-level / card-level 精細估值模型
- 不改 `RecommendationForm` 的 drawer UX
- 不在這輪處理 share image / Canvas 匯率標示
- 不做個人化長期保存的匯率偏好

---

## 3. Current State

### 3.1 Already Shipped

- `ExchangeRatesBoard.tsx`
  - pure presentational dense board
- `exchange-rate-board.types.ts`
  - shared board row model
- `normalize-exchange-rates.ts`
  - row normalization and default-rate map
- `ExchangeRatesPanel.tsx`
  - recommendation-page drawer wrapper
- `RecommendationForm.tsx`
  - 已能送出 `customExchangeRates`

### 3.2 Missing in `/calc`

- 沒有 `customExchangeRates` state
- 沒有匯率牌告板入口
- auto-select request 尚未吃自訂匯率
- submit request 尚未吃自訂匯率

---

## 4. Design Choice

採用「shared container + surface-specific wrapper」的方式，而不是直接把 `ExchangeRatesPanel` 複製到 `/calc`。

### 4.1 Recommended Split

- Shared layer
  - `ExchangeRatesBoard`
  - normalize helpers
  - default-rate map
  - active override 計算
  - `onChange(customRates)` semantics
- Recommendation surface
  - button + drawer wrapper
- Calc surface
  - inline panel wrapper

### 4.2 Why Not Reuse Drawer Directly

`/calc` 是持續可見、偏工具導向的左欄操作介面。把匯率板做成 inline panel，會比 drawer 更符合 calculator 的使用節奏：

- 使用者可以一邊看條件、一邊看匯率、一邊調整
- 不需要來回開關抽屜
- 更容易與後續分享圖、進階估值工具合流

---

## 5. UI Placement

匯率工具面板放在 `CalcPage` 左欄，位置在：

- `SwitchingCardPanel` 之後
- `CardSelector` 之前

理由：

- 先讓使用者決定情境、通路、merchant、payment 和 benefit plan
- 接著調整估值基準
- 最後再看要比較哪些卡

這樣匯率板會自然成為「試算前的估值工具」，而不是雜訊設定。

---

## 6. Component Design

### 6.1 Shared Container

新增一個共用 container，暫定方向如下：

- 負責 `useExchangeRates()`
- 將 API 資料轉成 board rows
- 建立 default-rate map
- 計算 active overrides
- 對外只暴露：
  - board rendering 所需 props
  - `customExchangeRates` 數值回傳

這層不負責 drawer、inline panel 或頁面排版。

### 6.2 Recommendation Wrapper

`RecommendationForm` 仍維持現在的 `ExchangeRatesPanel` drawer 版本。

這層只負責：

- trigger button
- drawer header / close behavior
- recommendation page placement

### 6.3 Calc Wrapper

`/calc` 新增 inline panel wrapper，視覺上更像 calculator 左欄工具卡：

- 標題區
- 說明文字
- `POINTS` / `MILES` dense board

這層不做 drawer trigger，也不做 modal behavior。

---

## 7. Data Flow

### 7.1 Calc State

`CalcPage` 新增：

- `customExchangeRates: Record<string, number>`

### 7.2 Auto-Select Request

目前 `autoSelectCards()` 會送一筆 recommendation request 來挑前幾張卡。

這一輪要讓它也帶上：

- `customExchangeRates`

這樣 auto-select 的候選卡排序，才會和使用者在 `/calc` 最終試算時使用的估值一致。

### 7.3 Final Submit Request

`getRecommendation()` 送出的正式試算 request 也要帶上：

- `customExchangeRates`

### 7.4 Override Semantics

維持既有規則：

- 空值不送
- 非法值不送
- 與 default rate 相同的值不送
- 只有真正 override 的 key 才進入 `customExchangeRates`

---

## 8. Verification

### 8.1 Frontend Verification

- `npx tsc -b`
- targeted eslint for changed files

### 8.2 Behavior Verification

1. `/calc` 左欄可看到 inline 匯率工具面板
2. 面板可顯示 `GET /v1/exchange-rates` 回傳的 rows
3. 調整某個匯率後，`CalcPage` state 會產生對應 override
4. auto-select request 會帶上 `customExchangeRates`
5. final submit request 會帶上 `customExchangeRates`
6. 將數值改回預設或清空後，request 不再帶 해당 key
7. recommendation page 的 drawer 行為不回歸

---

## 9. Risks

### 9.1 Scope Creep

最容易失控的方向：

- 順手重做 `ExchangeRatesPanel`
- 順手把 share image 一起接完
- 順手引入更細的 MILES / POINTS 模型

這些都不在本輪。

### 9.2 Shared/Surface Boundary Drift

如果把 `/calc` 的排版需求塞回 shared board，會讓 board 再次變成 page-aware 元件。

這輪要守住：

- board 只管展示
- wrapper 才管 surface UX

---

## 10. Outcome

完成後，CardSense 的 exchange-rate capability 會形成更合理的雙入口：

- `RecommendationForm`: trigger button + drawer
- `/calc`: left-column inline tool panel

兩邊共用同一套 board / normalization / override semantics，但各自保有最適合自己的 surface UX。
