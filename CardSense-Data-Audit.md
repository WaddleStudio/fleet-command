# CardSense Production API 資料品質與計算邏輯審計報告（高風險項目）

基於對核心系統 `DecisionEngine` 與 `RewardCalculator` 的分析，透過實測擷取 Production API (`https://cardsense-api.onrender.com`) 多張主力信用卡（包含國泰世界卡、玉山Unicard、富邦Costco、遠東SOGO等，樣本數約 150+ 筆 Promotions）的資料進行全面審查，我們發現線上資料庫存在嚴重的資料擷取（Extractor）缺陷，直接導致網頁端的推薦排序與回饋金額發生重大失真（包含回饋被低估、或出現超過 200% 的荒謬回饋率）。

此份報告列出四大類高風險異常，並根據樣本進行了錯誤發生頻率的統計分析與歸類。

---

## 數據統計與錯誤分類總覽 (Audit Statistics Overview)

從抽樣的 150+ 筆主力卡片優惠中，共標記出 **45 筆**高風險異常資料，錯誤率約 **30%**。主要錯誤分佈如下：

| 錯誤類型 (Error Type) | 出現次數 (Count) | 發生機率 | 嚴重程度 | 主要受影響卡片 |
| :--- | :---: | :---: | :---: | :--- |
| **回饋數值誤解與單位倒置** | 35 | ~77% | 高 | 國泰世界卡、台塑聯名卡 |
| **缺失條件的固定金額回饋** | 4 | ~9% | 致命 | 玉山 Unicard |
| **複雜階層與混合權益錯誤** | 3 | ~7% | 高 | 富邦 Costco 聯名卡 |
| **條件解析錯誤與垃圾資料** | 3 | ~7% | 中 | 遠東 SOGO 聯名卡 |

> **結論**：最高頻率的錯誤發生在「優惠價／折扣額被當作直接回饋金」；最致命的錯誤在於「無低消門檻的高額固定點數」被 `DecisionEngine` 一視同仁地推薦。

---

## 1. 複雜階層與混合權益計算錯誤 (Critical Calculation Flaw)

> **嚴重低估大額消費的回饋，上限邏輯套用錯誤**

當卡片同時具備「無上限基本回饋」與「有上限加碼回饋」時，Extractor 錯誤地將兩者被壓縮成了單一的 Promotion 模型，導致 `RewardCalculator` 計算邏輯發生致命錯誤。

*   **案例卡片**：富邦 Costco 聯名卡 (`FUBON_COSTCO`)
*   **活動名稱**：Costco自助加油站最高3%好多金回饋
*   **Production 資料**：`cashbackType`: `PERCENT`, `cashbackValue`: 3, `maxCashback`: 200
*   **實際條款**：「含原權益2%回饋無上限，加碼回饋1%，加碼回饋上限200元/每期帳單」
*   **影響評估**：
    *   計算消費 **30,000 元**，正確回饋應為：`30000 * 2% + min(30000 * 1%, 200) = 600 + 200 = 800 元`。
    *   目前 API 系統邏輯為 `min(30000 * 3%, 200) = 200 元`。
    *   **結果**：大額消費者的回饋被嚴重低估 600 元。此類「複合型回饋」在現有單一 `maxCashback` 欄位架構下是無解的，必須拆分為兩筆 `Promotion` 並透過 `Stackability` 綁定。

## 2. 缺失條件的固定金額回饋 (Unbounded Fixed Cashback)

> **導致小額消費出現 > 200% 的異常排序**

出現不需消費門檻、被歸類為特定通路、且範圍設為會被引擎推薦的固定金額回饋。

*   **案例卡片**：玉山 Unicard (`ESUN_UNICARD`)
*   **活動名稱**：AmpGO 200元充電折扣券
*   **Production 資料**：`cashbackType`: `FIXED`, `cashbackValue`: 200, `minAmount`: 0, `category`: `ONLINE`, `recommendationScope`: `RECOMMENDABLE`
*   **影響評估**：
    *   條款為輸入折扣碼領「4張50元抵用券」，Extractor 視為單筆 `ONLINE` 消費回饋 200 元。
    *   因 `minAmount: 0` 且是 `RECOMMENDABLE`，當前端輸入任何線上消費金額（例如 **50 元**），`DecisionEngine` 都會無條件加上 200 元回饋金。
    *   **結果**：這會導致不相干消費在小額情境時荒謬霸榜，回饋比率突破天際。

## 3. 回饋數值誤解與單位倒置 (Misinterpreted Values & Types)

> **金額價格被當作回饋金、固定回饋與百分比判定錯誤**

*   **案例卡片 A：國泰世華世界卡 (`CATHAY_WORLD` - 龍潭高爾夫俱樂部)**
    *   **Production 資料**：`cashbackType`: `FIXED`, `cashbackValue`: 3150
    *   **影響評估**：實際是「**擊球優惠價 3,150元 起**」，但價格被錯誤解析為「定額回饋」。系統會認為這筆消費可以拿到高達 3,150 元的現金回饋。這產生了回饋金額不合理的巨大數值。
*   **案例卡片 B：台塑聯名卡 (`CATHAY_FORMOSA` - 加油金再折抵)**
    *   **Production 資料**：`cashbackType`: `FIXED`, `cashbackValue`: 2, `category`: `ONLINE` (應為 `TRANSPORT`)
    *   **影響評估**：實際是「每公升可折抵 2 元加油金」。因 `RewardCalculator` 的 Fallback 邏輯（`FIXED` 數值 < 30 且類別非 `TRANSPORT` 時視作百分比），加上類別錯置為 `ONLINE`，原本「2元/公升」，會被誤算為「總金額的 2% 回饋」。

## 4. 條件解析錯誤與垃圾資料 (Garbage Data Injection)

> **無意義的規則進入引擎，污染資料庫**

*   **案例卡片**：遠東 SOGO 聯名卡 (`CTBC_C_CS`)
    *   **活動名稱**：遠東SOGO聯名卡 500
    *   **Production 資料**：`cashbackType`: `POINTS`, `cashbackValue`: 3
    *   **影響評估**：標題寫 500，回饋卻是 3 點。條件內含「三聯手寫發票恕無法參加本活動...」等無效雜訊。顯示 Extractor 發生嚴重失控，擷取出沒有實質效用的幽靈回饋活動加入推薦池。

---

## 下一步修復建議與策略 (Next Action Plan)

CardSense 目前的主要 Bug 根源在於 **Extractor 資料萃取的品質低落**，進而毒害了推薦引擎。建議可採行以下方案修復：

79. 1.  **資料修正腳本 (Data Remediation)**：此為最快治標方法。寫一段 Script 掃描 Production DB，針對異常（例如 `FIXED` 且大於 500 元、包含「倍/起」字眼等），自動將問題 Promotion 的 `recommendationScope` 標記為 `FUTURE_SCOPE` 或 `CATALOG_ONLY`，先從推薦計算中排除。
80. 2.  **修改引擎運算核心 (Backend Refactoring)**：從源頭調整 Java 的 `RewardCalculator` 與 `DecisionEngine`，針對 `FIXED` 極端值新增防禦性判斷（Guardrails），並重構 `maxCashback` 分層的處理邏輯。
81. 3.  **前端防禦顯示機制 (Frontend UI Defense)**：在 React 的 `CalcPage.tsx` 中實作防禦，當計算出的 total cashback 返還率大於 20% 時，加上 Warning 標籤或警告 UI，防止使用者直接信任失定的結果。

---

## 資料洗淨成果統計 (Data Cleaning Results)

在確認上述異常後，我們對核心引擎 `DecisionEngine.java` 添加了最低消防禦網，並將 `cardsense-extractor` 的 Python 演算法對「優惠價」、「票券」等進行了強制降級 (`CATALOG_ONLY`) 或排除配置。重新針對五大主力銀行執行 Production 資料庫同步後，成功除雷高達 133 筆危險數據：

| 銀行 | 修正前 (總提取) | 修正後 (總提取) | `RECOMMENDABLE` (進榜) 數量變化 | 除雷/降級數量 |
| :--- | :---: | :---: | :---: | :---: |
| **國泰 (CATHAY)** | 191 | 78 | `127` → **`15`** | **過濾 112 筆** |
| **玉山 (ESUN)** | 276 | 266 | `155` → **`145`** | **過濾 10 筆** |
| **富邦 (FUBON)** | 57 | 50 | `31` → **`23`** | **過濾 8 筆** |
| **中信 (CTBC)** | 45 | 42 | `25` → **`22`** | **過濾 3 筆** |
| **台新 (TAISHIN)** | 22 | 21 | `11` → **`11`** | **過濾 0 筆** |

> **總結**：本次重構使得進入引擎排名的有效推薦資料變得極為乾淨，徹底解決了高爾夫球、特價品、無底限抵用券在前端網頁中算出「大於 200%」等荒唐回饋率的霸榜問題。
