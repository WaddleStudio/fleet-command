# CardSense — 情境式信用卡推薦平台

CardSense 是一個以**情境式卡片比較**為核心的信用卡推薦平台。不同於傳統的單筆優惠排名，CardSense 接收使用者的消費情境（金額、類別、通路、日期等），過濾不符合條件的優惠，比較各張卡在該情境下的有效回饋，回傳可解釋的推薦結果。

## 子專案

| 子專案 | 角色 | 技術棧 |
|--------|------|--------|
| [cardsense-contracts](../cardsense-contracts/) | 共用資料契約（schema、DTO、列舉） | JSON Schema |
| [cardsense-extractor](../cardsense-extractor/) | 銀行優惠資料擷取與正規化 | Python 3.13+ / uv / Pydantic / Playwright / SQLite + Supabase |
| [cardsense-api](../cardsense-api/) | 情境推薦 REST API | Java 21 / Spring Boot / SQLite + Supabase |
| [cardsense-web](../cardsense-web/) | 前端展示與社群入口 | React 19 / TypeScript / Vite / Tailwind CSS / Vercel |

## 架構總覽

```
銀行官網 ──→ Extractor ──→ JSONL ──→ SQLite ──→ Supabase ──→ API ──→ Frontend
              │                        │            │
              │  parse / normalize     │  local DB   │  PostgreSQL (prod)
              │  validate / version    │             │
              ▼                        ▼             ▼
        cardsense-contracts      cardsense-contracts
        (schema 驗證)            (DTO / response 契約)
```

**資料流**：
1. **Extractor** 從銀行官網擷取原始優惠頁面（HTML 抽取或 Playwright Browser Rendering）
2. 經過 parse → normalize → validate → version 產生 JSONL
3. JSONL 匯入 **SQLite** 的 `promotion_current` table
4. **Supabase Sync** 將 SQLite 資料同步至 PostgreSQL（prod 環境）
5. **API** 從 Supabase（prod）或 SQLite（local）讀取 promotion 資料，提供情境推薦端點
6. **Frontend**（`cardsense-web`）呼叫 API 展示推薦結果；已上線推薦頁、卡片目錄、`/calc` 年度損失社群入口頁

## 完成進度

| 模組 | 狀態 | 說明 |
|------|------|------|
| cardsense-contracts | ✅ 完成 | Promotion / Recommendation schema 穩定，含 Stackability metadata |
| cardsense-extractor | ✅ 核心完成 | 5 家銀行 real extractor（E.SUN / Cathay / Taishin / Fubon / CTBC）、JSONL + SQLite + Supabase sync |
| cardsense-api | ✅ 核心完成 | 情境推薦、疊加優惠計算（STACK_ALL_ELIGIBLE）、break-even、benefit plan 權益切換、subcategory 過濾、scope 過濾、Supabase 讀取 |
| cardsense-web | ✅ MVP Live | 推薦頁、卡片目錄、卡片詳情、`/calc` 社群入口頁、FilterChip 設計系統、touch target token、RWD + a11y 最佳化 |
| 資料庫遷移 | ✅ 完成 | Extractor → SQLite → Supabase sync（psycopg2）；API prod 從 Supabase 讀取 |
| 銀行擴充 | ✅ Phase 1 完成 | 5 家銀行全部上線（E.SUN / Cathay / Taishin / Fubon / CTBC） |
| 權益切換 | ✅ 核心完成 | Extractor plan inference + API DecisionEngine 自動選擇最佳 plan；支援 CATHAY CUBE（7 plans）、TAISHIN RICHART |
| 子類別場景排名 | ✅ 核心完成 | Subcategory 維度（MOVIE, DELIVERY, DEPARTMENT 等）過濾場景限定優惠，避免汙染通用排名 |

## 已支援銀行

- ✅ **E.SUN（玉山）** — HTML 頁面抽取
- ✅ **CATHAY（國泰）** — Model JSON 抽取
- ✅ **TAISHIN（台新）** — Cloudflare Browser Rendering + HTML 抽取
- ✅ **FUBON（富邦）** — Cloudflare Browser Rendering + HTML 抽取
- ✅ **CTBC（中信）** — Playwright + JSON API 抽取
- — MEGA / FIRST / SINOPAC / TPBANK / UBOT（Backlog，待既有 5 家資料品質提升後）

## 已完成里程碑

### Phase 1：新銀行擴充 + Extractor 能力提升 ✅

- 5 家銀行 real extractor 全部上線：E.SUN / Cathay / Taishin / Fubon / CTBC
- 每家銀行獨立 extractor 檔案（`esun_real.py`、`cathay_real.py`、`taishin_real.py`、`fubon_real.py`、`ctbc_real.py`）
- Playwright + Cloudflare Browser Rendering 支援反爬蟲銀行
- Plan inference 與 card lifecycle normalization（benefit plan switching）

### Phase 2：前端開發 ✅

- 推薦頁 `/recommend`、卡片目錄 `/cards`、卡片詳情 `/cards/:cardCode` 全部上線
- `/calc` 年度損失社群入口頁已完成（AmountInput、CategoryGrid、CardSelector、ResultPanel、ShareButton）
- React 19 + TypeScript + Vite + Tailwind CSS + Radix UI + TanStack Query
- Vercel 部署，深色模式支援

### Phase 3：資料庫遷移（SQLite → Supabase）✅

- Extractor Supabase sync 已完成（psycopg2 直連 PostgreSQL）
- `refresh_and_deploy.py` 整合 extract → import → sync 一鍵部署
- API 支援三種 repository mode：mock / sqlite / supabase
- Prod 環境從 Supabase 讀取，local 環境保留 SQLite

### 權益切換（Benefit Plan Switching）✅

支援同一張卡片擁有多個權益方案，推薦引擎自動選出最佳 plan。

- **Extractor**：`benefit_plans.py` plan inference（PLAN_MAPPING + PLAN_NAME_SIGNALS）、`tag_plan_ids.py` 批次標記、`planId` 欄位貫穿 SQLite → Supabase
- **API**：`BenefitPlan` entity + `JsonBenefitPlanRepository`（讀取 `benefit-plans.json`）、`DecisionEngine` 依 `exclusiveGroup` 自動選最佳 plan、`GET /v1/cards/{cardCode}/plans` endpoint、`CardRecommendation.activePlan` 回傳
- **已支援卡片**：CATHAY CUBE（7 plans：數位/饗購/旅行/精選/生日/兒童/日本）、TAISHIN RICHART、E.SUN UNI Card（3 plans：簡單選/任意選/UP選）
- **contracts**：`benefit-plan.schema.json` ✅ 已建立
- **前端**：`activePlan` 顯示 ✅ 已完成（`PlanSwitchBadge` 元件，含方案名稱、切換頻率、訂閱費用）

### 子類別場景排名（Subcategory Scenario Ranking）✅

在 8 大 `category` 之下新增 `subcategory` 維度，解決商家限定優惠汙染通用排名的問題。

- **Extractor**：`SubcategoryEnum`（15 值）、`SUBCATEGORY_SIGNALS` 信號字典、`infer_subcategory()` 關鍵字 scoring（threshold ≥ 3）；5 家銀行 extractor 全部整合
- **API**：`DecisionEngine.isEligible()` 新增 subcategory 過濾 — 通用查詢排除場景限定優惠；選擇子類別時，該場景 + GENERAL 優惠一起排名
- **DB**：`subcategory TEXT NOT NULL DEFAULT 'GENERAL'` 加入 `promotion_versions` 和 `promotion_current`
- **contracts**：`promotion-normalized.schema.json`、`recommendation-request/response.schema.json` 皆已更新
- **前端**：`SubcategoryGrid.tsx` 元件（水平 chip row），CalcPage 整合，ResultPanel 場景 badge
- **Phase 1 覆蓋**：ENTERTAINMENT（電影/遊樂園/KTV/串流）、DINING（外送/指定餐廳/咖啡/飯店）、SHOPPING（百貨/量販/3C）、ONLINE（電商/行動支付/訂閱）
- **設計文件**：[`specs/2026-04-01-subcategory-scenario-ranking-design.md`](./specs/2026-04-01-subcategory-scenario-ranking-design.md)

## 待辦工作路線圖（Roadmap）

### 🔥 當前優先：既有 5 家銀行資料品質提升

100 張卡 763 筆優惠（506 RECOMMENDABLE / 148 CATALOG_ONLY / 109 FUTURE_SCOPE）。82 張卡有 RECOMMENDABLE 優惠。

- **P0：泛用回饋卡補全** ✅ 完成 — RECOMMENDABLE 從 387→506（+119），decomposed scope fix、Richart plan fix、feature extractor expansion fix、HERBALIFE 分類修正
- **P1：CATALOG_ONLY 降級審查** 🟡 ~50% — 基礎建設 + P0 連帶效果，CATALOG_ONLY 從 195→148，16 張純 CATALOG_ONLY 卡待審查
- **P2：聯名卡通用優惠補全** ⏳ 未開始 — 聯名卡除專屬通路外通常也享有銀行通用活動，目前未擷取
- **P3：前端體驗配合** 🟡 ~80% — promo counts、catalog hints、filter 優化已上線

**➡️ 接續重點**：P1 核心審查 → Fubon targeted re-extraction → P2 bank-wide promotion → MILES API 支援

### 後續待辦

| 項目 | 前置條件 |
|------|----------|
| Fubon targeted re-extraction | — |
| `MILES` API 支援 | — |
| `stackability` 顯式欄位 | — |
| `POINTS` 銀行別折現規則 | — |
| 商業化（API Key / Rate Limiting / Stripe） | 資料品質達標 |
| `/calc` 社群投放 | 資料品質達標 |
| 新銀行擴充（MEGA / SINOPAC / ...） | 既有 5 家品質穩定 |

## 快速開始

### Extractor — 擷取銀行優惠資料

Extractor 的 Python 流程統一使用 `uv`，不要另外建立或啟用 `venv`。

```bash
cd cardsense-extractor
uv sync
uv run pytest                                    # 單元測試
uv run python jobs/run_esun_real_job.py           # 玉山 real extraction
uv run python jobs/run_cathay_real_job.py         # 國泰 real extraction
uv run python jobs/run_taishin_real_job.py        # 台新 real extraction
uv run python jobs/run_fubon_real_job.py          # 富邦 real extraction
uv run python jobs/run_ctbc_real_job.py           # 中信 real extraction
uv run python jobs/import_jsonl_to_db.py \
  --input outputs/taishin-real-*.jsonl \
  --db data/cardsense.db                          # 匯入 SQLite
uv run python jobs/refresh_and_deploy.py          # 一鍵：extract → import → Supabase sync
```

### API — 啟動推薦服務

```bash
cd cardsense-api
mvn spring-boot:run \
  -Dspring-boot.run.jvmArguments="\
    -Dcardsense.repository.mode=sqlite \
    -Dcardsense.repository.sqlite.path=../cardsense-extractor/data/cardsense.db"
```

API 啟動後可用的端點：

- `GET /health` — 健康檢查（回報 repository mode）
- `GET /v1/cards?bank=ESUN&scope=RECOMMENDABLE` — 卡片目錄
- `GET /v1/cards/{cardCode}/promotions` — 卡片優惠列表
- `GET /v1/cards/{cardCode}/plans` — 卡片 benefit plan
- `GET /v1/banks` — 銀行列表
- `POST /v1/recommendations/card` — 情境推薦

### Contracts — 檢視共用契約

```bash
cd cardsense-contracts
# 直接瀏覽 promotion/ 與 recommendation/ 目錄下的 JSON Schema
```

## 子專案連結

- [cardsense-contracts README](../cardsense-contracts/README.md) — 共用資料契約、schema、列舉定義
- [cardsense-extractor README](../cardsense-extractor/README.md) — 資料擷取 pipeline、銀行 extractor、SQLite 匯入
- [cardsense-api README](../cardsense-api/README.md) — 推薦 API、疊加優惠計算、benefit plan / subcategory 支援
- [cardsense-web README](../cardsense-web/README.md) — 前端展示、技術棧、部署設定
- [API Implementation Checklist](../cardsense-api/IMPLEMENTATION_CHECKLIST.md) — API 待辦與前端 / 資料庫遷移時機
- [CardSense Demo Spec](./CardSense-Demo-Spec.md) — `/calc` 年度損失入口頁詳細規格
