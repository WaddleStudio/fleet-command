# CardSense — 情境式信用卡推薦平台

CardSense 是一個以**情境式卡片比較**為核心的信用卡推薦平台。接收消費情境（金額、類別、通路、日期、支付方式），精確計算各張卡在該情境下的有效回饋（含疊加），回傳可解釋、可審計的推薦結果。

> **Live**: https://cardsense-web.vercel.app

---

## 子專案與 Repo

| 子專案 | 角色 | 技術棧 | 部署 | GitHub |
|--------|------|--------|------|--------|
| cardsense-contracts | 共用資料契約（JSON Schema、DTO、列舉、stackability、benefit plan） | JSON Schema | — | [WaddleStudio/cardsense-contracts](https://github.com/WaddleStudio/cardsense-contracts) |
| cardsense-extractor | 銀行優惠資料擷取與正規化 | Python 3.13+ / uv / Pydantic / SQLite + Supabase sync | Local | [WaddleStudio/cardsense-extractor](https://github.com/WaddleStudio/cardsense-extractor) |
| cardsense-api | 情境推薦 REST API | Java 21 / Spring Boot / SQLite / Supabase / Maven | Render | [WaddleStudio/cardsense-api](https://github.com/WaddleStudio/cardsense-api) |
| cardsense-web | 前端展示 | React 19 / TypeScript 5.9 / Vite 8 / shadcn/ui / Tailwind CSS 4 | Vercel | [WaddleStudio/cardsense-web](https://github.com/WaddleStudio/cardsense-web) |

---

## 架構總覽

```
銀行官網 ──→ Extractor ──→ JSONL ──→ SQLite ──→ Supabase ──→ API (Render) ──→ Frontend (Vercel)
              │                        │            │
              │  scrape / heuristic    │  local DB   │  PostgreSQL (prod)
              │  normalize / version   │            │  確定性規則引擎
              ▼                        ▼            ▼
        cardsense-contracts      cardsense-contracts
        (schema 驗證)            (DTO / response 契約)
```

**核心設計原則**：
- **用戶請求路徑零 LLM** — 確定性規則引擎，100% 可重現、可審計
- **版本不可變** — `promoVersionId`，語義變更 = 新版本，SHA-256 hash 去重
- **強制免責聲明** — 每筆 API 回應包含法律 disclaimer
- **Repository 抽象** — mock / sqlite / supabase 三模式，切換無需改動業務邏輯

**資料流**：
1. Extractor 從銀行官網擷取原始優惠頁面（local 執行）
2. scrape → parse_rules → normalize → validate → version 產生 JSONL
3. `import_jsonl_to_db.py` 匯入 SQLite `promotion_current` table
4. `refresh_and_deploy.py` 一鍵完成全銀行提取 → 匯入 → 同步至 Supabase
5. API (Render) 在 prod 從 Supabase 讀取；local 可直接連 SQLite
6. Frontend (Vercel) 呼叫 API 展示推薦結果

---

## 現況快照（2026-04-24）

| 子專案 | 狀態 | Latest |
|--------|------|--------|
| cardsense-contracts | ✅ 穩定 | `28bbaf6` — README 補充 benefit-plan schema 與 recommendation response 結構 |
| cardsense-extractor | ✅ 核心完成 | `1e09b02` — README 補充 Supabase sync 與 `refresh_and_deploy` 新參數 |
| cardsense-api | ✅ 已部署 | `608bba9` — DAY_OF_MONTH / DAY_OF_WEEK 日期過濾 |
| cardsense-web | ✅ 已部署 | `48dc3ce` — 首頁計算機商家捷徑前移與熱門商家 shortcut 調整 |

### 最近進展（2026-04-24）

- **Web / Roadmap #1**：已將 merchant-first 入口前移到實際首頁計算機 `/`，並同步補到 `/recommend`；加入熱門商家捷徑（全聯、家樂福、momo、蝦皮、Agoda、星巴克、Uber Eats）與預設場景映射。
- **首次體驗**：使用者現在可以從「我去全聯刷哪張？」這類商家問題直接進站，不必先理解完整類別樹；切換類別 / 子類別時也不會再清空 merchantName。
- **下一步**：用實際 API / SQLite 結果驗證熱門商家清單，收斂為「高辨識度 + 穩定可回傳 2 張以上卡片」的 shortlist。
- **Pipeline verify 註記**：本輪為前端導向改動，依 `cardsense-pipeline-verify` workflow 暫不需執行 extractor / SQLite / API smoke test；下次若涉及商家映射、promotion import 或 benefit-plan 變更，需補跑完整驗證流程並記錄 pass/fail。

**資料規模**：5 家銀行、100 張卡、813 筆優惠（628 RECOMMENDABLE）

### 已支援銀行

| 銀行 | Extractor | 擷取方式 |
|------|-----------|----------|
| ✅ E.SUN（玉山） | `esun_real.py` | HTML 頁面直接抓取 |
| ✅ CATHAY（國泰） | `cathay_real.py` | Model JSON 抽取 |
| ✅ TAISHIN（台新） | `taishin_real.py` | Cloudflare Browser Rendering + HTML |
| ✅ FUBON（富邦） | `fubon_real.py` | Cloudflare Browser Rendering + HTML |
| ✅ CTBC（中信） | `ctbc_real.py` | JSON API + Playwright |
| ⏸️ MEGA / FIRST / SINOPAC / TPBANK / UBOT | — | 凍結，待既有 5 家品質穩定後排入 |

---

## API 端點

| 方法 | 路徑 | 說明 |
|------|------|------|
| GET | `/health` | 健康檢查 |
| GET | `/v1/banks` | 銀行列表 |
| GET | `/v1/cards` | 卡片目錄（bank / scope / eligibilityType 篩選） |
| GET | `/v1/cards/{cardCode}/promotions` | 卡片優惠列表（依 category 分組） |
| GET | `/v1/cards/{cardCode}/plans` | 卡片 benefit plan 列表 |
| GET | `/v1/exchange-rates` | 系統預設點數 / 里程估值牌告 |
| POST | `/v1/recommendations/card` | 情境推薦 |

Frontend 消費的穩定欄位：`recommendations[].estimatedReturn`、`promotionBreakdown`、`disclaimer`、`activePlan`

---

## Roadmap

### 🔥 社群傳播前必做（Pre-Launch Polish）

CardSense 的核心傳播路徑：用戶算卡 → 覺得結果值得截圖 → 發 PTT/Dcard。以下 6 項是這條路徑上的瓶頸。

#### 1. 商家搜尋入口前置（Web）
**問題**：merchantName 輸入目前藏在進階選項，用戶的第一個問題「我去全聯刷哪張？」沒有明顯入口。  
**目標**：商家名稱成為首頁主要輸入路徑之一，直接觸發推薦。
**進度（2026-04-24）**：已完成第一階段。首頁計算機 `/` 與 `/recommend` 均已加入 merchant-first 輸入區、熱門商家捷徑與預設場景；下一階段改為用實際推薦結果校準 shortcut 名單與排序。

#### 2. 高頻商家覆蓋補強（Extractor + Contracts）
**問題**：精準計算的前提是資料完整。若商家映射缺失，算出來的數字是殘缺答案。  
**目標**：確保台灣前 200 高頻商家（全聯、家樂福、momo、蝦皮、麥當勞、星巴克、POYA、Agoda 等）在 5 家銀行中的 VENUE condition 正確標注，讓同一商家能同時比到多張卡。  
**衡量**：輸入「全聯」→ 至少有 3 張以上不同銀行的卡回傳結果。

#### 3. 卡片基本資料可信度（Extractor + API）
**問題**：用戶算完會去確認年費、條件等基本資料；若有誤，整個推薦結果的信任度崩塌。  
**目標**：5 家銀行現有卡的年費、eligibilityType、基本回饋欄位確認正確。對資料缺口要在前端明確標示（而非假裝完整）。

#### 4. 優惠定期更新維護機制（Ops / Extractor）
**問題**：銀行優惠每季更新，目前沒有標準化的「定期重跑 + 驗證 + 部署」流程，資料新鮮度靠手動觸發。  
**目標**：建立 refresh 排程（月跑或季跑）+ 快速 diff 報告（新增/消失/異動優惠），讓維護成本可控。  
**候選方案**：Cron job 觸發 `refresh_and_deploy.py` + 結果摘要 Discord 通知。

#### 5. 行動裝置體驗（Web）
**問題**：PTT/Dcard 用戶多半用手機看、截圖。若手機體驗卡頓或版面跑掉，傳播就在這裡斷掉。  
**目標**：首頁計算機、推薦結果頁、My Wallet 在 375px 以上裝置流暢可用；截圖在手機上能正確觸發並輸出完整圖片。

#### 6. 首次使用者 30 秒引導（Web）
**問題**：新用戶打開首頁不確定要輸入什麼、這個工具跟一般卡片比較網站有何不同。  
**目標**：首頁一句話說清楚產品主張（例：「輸入消費情境，算出每張卡的實際回饋金額」）；首次進入有輕量引導或預設情境範例，讓用戶 30 秒內產出第一次結果。

---

### 🟢 進行中 / 持續細化

| 項目 | 說明 |
|------|------|
| **哩程 / 點數估值深化** | `MILES` / `POINTS` API、基礎估值已上線；持續補充航空計畫（Asia Miles、EVA Infinity、JAL）與轉點情境，強化 explainability |
| **截圖社群投放** | Canvas 分享圖已實作；定期於 PTT 信用卡板、Dcard 投放真實算卡比較圖 |
| **Feedback 飛輪** | Discord 即時通知已上線；將回報資料轉化為 extractor 補強優先順序 |

---

### ⏸️ 凍結 / 暫緩

| 項目 | 原因 |
|------|------|
| 新銀行擴充（MEGA / FIRST 等） | 先把 5 家主力銀行體驗打磨完整再擴廣度 |
| API 商業化（Stripe Billing） | 延後至使用者基礎建立後 |
| `stackability` 顯式欄位 | 目前 raw_payload 還原可行，暫不拆欄位 |
| Fubon targeted re-extraction | INSURANCE / INFINITE / DIGITALLIFE 3 張消失的卡，排入高頻商家補強後處理 |
| 傳統卡片目錄深度優化 | 維持堪用，不與純內容比價網競爭靜態頁面 |

---

## 已知限制

- POINTS / MILES 估值粒度仍偏粗，高階哩程計畫估值持續演進中
- `STACK_ALL_ELIGIBLE` 為 heuristic aggregation，待 stackability 標注完整後升級
- Break-even 為 pairwise 分析，非完整最佳化模型
- Real extractor 依賴外部銀行網站可用性，頁面改版需人工調整 heuristic
- Merchant registry 190+ 筆，高頻商家補強進行中（見 Roadmap #2）

---

## 相關文件

- [cardsense-api/IMPLEMENTATION_CHECKLIST.md](../cardsense-api/IMPLEMENTATION_CHECKLIST.md) — API 待辦細項
- [CardSense-Bank-Promo-Review-Workflow.md](./CardSense-Bank-Promo-Review-Workflow.md) — 優惠審查與 benefit-plan 流程
- [fleet-command/specs/spec-cardSense.md](./specs/spec-cardSense.md) — 完整專案規格書
- [fleet-command/docs/Supabase-Discord-Webhook-Setup.md](./docs/Supabase-Discord-Webhook-Setup.md) — Feedback Widget 串接說明

*Last updated: 2026-04-24*
