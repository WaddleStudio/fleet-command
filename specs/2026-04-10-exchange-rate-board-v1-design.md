# CardSense - Exchange Rate Board v1 Design
### Date: 2026-04-10

---

## 1. 背景

CardSense 的 Exchange Rate Engine 核心能力已經落地：

- API 已提供 `GET /v1/exchange-rates`
- recommendation request 已支援 `customExchangeRates`
- recommendation response 已支援 `rewardDetail`
- 推薦頁已有可用的 `ExchangeRatesPanel`

但目前推薦頁上的匯率設定仍偏「進階設定表單」，還沒有形成明確的金融工具感；同時估值資料雖已打通，也仍停留在 `_DEFAULT` 與少數 bank-level 條目，尚未整理成適合展示與持續演進的牌告板形式。

本設計聚焦於把「前兩項待辦」收斂成一個最小閉環：

1. 補齊 v1 所需的最小估值資料與說明
2. 在 `RecommendationForm` 上做出可用的匯率牌告板 drawer

---

## 2. 目標

### 2.1 這輪要達成

- 讓推薦頁使用者能透過一個明確的 trigger 開啟匯率牌告板
- 讓匯率設定從「原位展開的表單欄位」升級為「drawer 內的 dense 牌告板」
- 保留既有 `customExchangeRates` 行為，不改 API 契約
- 補齊 `POINTS` / `MILES` v1 展示所需的 `unit` / `note` / bank-level 條目
- 抽出可重用的牌告板展示元件，為下一輪接入 `/calc` 預留結構

### 2.2 這輪不做

- 不新增 contracts 欄位
- 不新增 request key 格式，例如 `MILES.<PROGRAM_ID>.<CARD_ID>`
- 不做真正的 program-level / card-level 哩程估值引擎
- 不在這輪接入 `/calc`
- 不做使用者長期保存個人估值偏好
- 不把輸入互動改成複雜的 inline edit / spreadsheet 模式

---

## 3. 現況與問題

### 3.1 現況

- [RecommendationForm.tsx](/d:/Projects/cardsense-workspace/cardsense-web/src/components/RecommendationForm.tsx)
  已掛載 `ExchangeRatesPanel`
- [ExchangeRatesPanel.tsx](/d:/Projects/cardsense-workspace/cardsense-web/src/components/ExchangeRatesPanel.tsx)
  同時負責：
  - 抓取 `/v1/exchange-rates`
  - normalize rows
  - 管理收合狀態
  - 管理使用者輸入
  - 回傳 `customExchangeRates`
- [ExchangeRateService.java](/d:/Projects/cardsense-workspace/cardsense-api/src/main/java/com/cardsense/api/service/ExchangeRateService.java)
  仍以 `rewardType + bankCode` 為主要 lookup key
- [exchange-rates.json](/d:/Projects/cardsense-workspace/cardsense-api/src/main/resources/exchange-rates.json)
  已有 `POINTS` 與 `MILES` 條目，但仍偏少量、偏基礎

### 3.2 主要問題

- UI 問題：目前的原位展開會把表單拉長，工具感不夠
- 結構問題：`ExchangeRatesPanel` 職責過多，不利於下一輪搬去 `/calc`
- 資料問題：估值條目雖可用，但 bank-level / profile-level 說明仍不足
- 品牌問題：匯率功能已存在，但沒有形成清楚可感知的「牌告板」體驗

---

## 4. 設計摘要

### 4.1 選定方案

採用「最小閉環 + RecommendationForm 優先」方案：

- 抽出共用的 `ExchangeRatesBoard` 展示元件
- 保留 `ExchangeRatesPanel` 作為容器層
- 在 `RecommendationForm` 中以 trigger button 開啟 drawer
- drawer 內顯示 dense 匯率牌告板

### 4.2 為什麼不是原位展開

相較於延續原位展開：

- drawer 更適合承接需要掃讀的 dense list
- 不會把主表單拉得更長
- 更容易承接 badge / note / 狀態 / 輸入框等多層資訊
- 更接近未來 `/calc` 的工具面板互動

---

## 5. 元件與責任切分

### 5.1 `ExchangeRatesBoard`

新元件，純展示層。

責任：

- 顯示 `POINTS` / `MILES` 兩個 section
- 顯示 dense rows
- 顯示 status badge、note、input
- 呼叫上層傳入的 input change handler

不負責：

- 呼叫 API
- 判斷哪些 key 要送到 request
- 管理 drawer 開關

### 5.2 `ExchangeRatesPanel`

保留為容器層，內部改為組裝 `ExchangeRatesBoard`。

責任：

- 呼叫 `useExchangeRates()`
- normalize API rows
- 生成 default rate map
- 管理使用者輸入暫存
- 計算 active override count
- 將真正有效的覆寫值透過 `onChange` 回傳
- 管理 drawer 開關

### 5.3 `RecommendationForm`

保留目前作為 request 組裝入口。

責任：

- 接收 `customExchangeRates`
- 把 `customExchangeRates` 合併進 recommendation request
- 顯示匯率牌告 trigger button

不負責：

- 直接處理牌告 rows
- 直接處理 exchange rate API response

---

## 6. 資料深化範圍

### 6.1 這輪要補的內容

- 整理 [exchange-rates.json](/d:/Projects/cardsense-workspace/cardsense-api/src/main/resources/exchange-rates.json) 的條目與文案
- 確保主要 `POINTS` bank rows 有一致的 `unit` 與 `note`
- 保留 `MILES._DEFAULT` 與既有 profile 條目，讓 drawer 可清楚展示
- 用既有 `unit` / `note` / `exchangeRateSource` 形成 v1 explainability

### 6.2 這輪不進一步擴張的原因

[ExchangeRateService.java](/d:/Projects/cardsense-workspace/cardsense-api/src/main/java/com/cardsense/api/service/ExchangeRateService.java) 現況仍以 `rewardType + bankCode` 查值。若本輪直接升級為真正的 program-level engine，會連帶改動：

- request key 規格
- lookup model
- extractor / API / web 對應
- rewardDetail 說明方式

這會讓本輪從「v1 閉環」擴大成另一個基礎設計專案，因此明確延後。

---

## 7. UI 與互動

### 7.1 Trigger Button

在 `RecommendationForm` 內保留一個摘要型入口，不直接展開牌告板。

button 文案包含：

- 區塊名稱：`匯率牌告`
- 總筆數
- 已覆寫筆數

範例：

```text
匯率牌告 8 項 / 已覆寫 2 項
```

### 7.2 Drawer

點擊 trigger button 後開啟 drawer。

桌機：

- 右側 drawer

手機：

- 同邏輯的 sheet / drawer 體驗

drawer 內包含：

- 標題
- 簡短說明
- 關閉按鈕
- 基準說明列
- `POINTS` 與 `MILES` 兩個 section

### 7.3 Dense Row 結構

每列固定三段：

1. 左側
   - type badge
   - 銀行 / 計畫名稱
2. 中段
   - 大數字估值
   - 次行顯示 `1 單位 = X TWD`
3. 右側
   - 狀態 badge：`系統預設` / `已覆寫`
   - 數字輸入框

### 7.4 Row 附加資訊

- `note` 顯示在 row 次行
- `_DEFAULT` row 置頂
- `POINTS` 與 `MILES` 分 section 呈現

### 7.5 視覺方向

- 沿用現有推薦頁 / `/calc` 的深色 fintech 語言
- 數字使用 `tabular-nums`
- 使用細分隔線，而非厚重卡片堆疊
- 高對比 accent 色只留給估值數字與少數狀態
- 避免復刻舊 app 黑底紫字視覺

---

## 8. 輸入與資料流

### 8.1 輸入規則

- 空值：不視為 override
- 非法值：不視為 override
- 與預設值相同：不視為 override
- 只有真正不同於預設值的 key 才會進入 `customExchangeRates`

### 8.2 資料流

1. `ExchangeRatesPanel` 透過 `useExchangeRates()` 取得系統預設資料
2. normalize 成 board rows
3. 使用者在 drawer 內修改數值
4. `ExchangeRatesPanel` 比對 default map，過濾出真正有效的 overrides
5. `RecommendationForm` 將 `customExchangeRates` 併入 request
6. API 回傳的 `rewardDetail` 繼續使用既有契約顯示結果

### 8.3 Drawer 關閉行為

- 關閉 drawer 不會清掉已輸入數值
- 只有使用者手動改回預設，或清空輸入，該 override 才會消失

---

## 9. 驗證策略

### 9.1 前端驗證

- `npx tsc -b`

### 9.2 功能驗證

1. 進入推薦頁時可看到匯率牌告 trigger button
2. 點擊後可開啟 drawer
3. drawer 內可看到 `GET /v1/exchange-rates` 的 rows
4. 修改任一 row 後，active override count 會反映變化
5. 提交推薦後，request 內含正確的 `customExchangeRates`
6. 將數值改回預設後，對應 key 從 request 中消失
7. 不輸入任何 override 時，行為與目前版本一致

### 9.3 API / 資料驗證

- `/v1/exchange-rates` response shape 不變
- `rewardDetail` response shape 不變
- 覆寫估值後，推薦結果中的 `estimatedReturn` 與 `rewardDetail` 應反映新的匯率

---

## 10. 後續延伸

本 spec 完成後，下一輪自然延伸包括：

- `/calc` 接入同一套 `ExchangeRatesBoard`
- 強化 `MILES` / `POINTS` 的 bank-level 與 profile-level explainability
- 導入個人估值偏好保存
- 視需要再評估 program-level / card-level rate model

---

## 11. 決策摘要

- 採用「最小閉環」策略
- 優先落地在 `RecommendationForm`
- 使用 trigger button + drawer，而非原位展開
- 抽出 `ExchangeRatesBoard` 作為可重用展示元件
- 本輪只做支撐 v1 UI 所需的最小資料深化，不擴張到底層契約重設
