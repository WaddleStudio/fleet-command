# CardSense — 情境式信用卡推薦平台

CardSense 是一個以**情境式卡片比較**為核心的信用卡推薦平台。不同於傳統的單筆優惠排名，CardSense 接收使用者的消費情境（金額、類別、通路、日期等），過濾不符合條件的優惠，比較各張卡在該情境下的有效回饋，回傳可解釋的推薦結果。

> **Live**: https://cardsense-web.vercel.app

---

## 子專案與 Repo

| 子專案 | 角色 | 技術棧 | 部署 | GitHub |
|--------|------|--------|------|--------|
| cardsense-contracts | 共用資料契約（JSON Schema、DTO、列舉、stackability、benefit plan） | JSON Schema | — | [WaddleStudio/cardsense-contracts](https://github.com/WaddleStudio/cardsense-contracts) |
| cardsense-extractor | 銀行優惠資料擷取與正規化 | Python 3.13+ / uv / Pydantic / SQLite + Supabase sync | Local | [WaddleStudio/cardsense-extractor](https://github.com/WaddleStudio/cardsense-extractor) |
| cardsense-api | 情境推薦 REST API | Java 21 / Spring Boot / SQLite / Supabase / Maven | Render | [WaddleStudio/cardsense-api](https://github.com/WaddleStudio/cardsense-api) |
| cardsense-web | 前端展示 | React 19 / TypeScript 5.9 / Vite 8 / shadcn/ui / Tailwind CSS 4 | Vercel | [WaddleStudio/cardsense-web](https://github.com/WaddleStudio/cardsense-web) |

> 所有 repo 集中於 `D:/Projects/cardsense-workspace/` 統一管理。

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
1. **Extractor** 從銀行官網擷取原始優惠頁面（local 執行）
2. 經過 scrape → parse_rules → normalize → validate → version 產生 JSONL
3. `import_jsonl_to_db.py` 匯入 **SQLite** 的 `promotion_current` table
4. `refresh_and_deploy.py` 一鍵完成全銀行提取 → 匯入 → 同步至 **Supabase**
5. **API** (Render) 在 prod 從 Supabase 讀取 promotion 資料；local 仍可直接連 SQLite
6. **Frontend** (Vercel) 呼叫 API 展示推薦結果

---

## 完成進度

| 模組 | 狀態 | 說明 |
|------|------|------|
| cardsense-contracts | ✅ 完成 | Promotion / Recommendation / Stackability schema 穩定，含 subcategory 欄位 |
| cardsense-extractor | ✅ 核心完成 | E.SUN + Cathay + TAISHIN + FUBON + CTBC real extractor、subcategory inference、JSONL + SQLite 匯入、refresh_and_deploy |
| cardsense-api | ✅ 核心完成 + 已部署 | 情境推薦、疊加優惠計算、break-even、subcategory 場景過濾、scope/eligibilityType/通路 condition 匹配；Render 上線 |
| cardsense-web | ✅ MVP 完成 + 已部署 | 推薦表單 + 卡片目錄 + SubcategoryGrid 場景選擇 + `/calc` 社群入口頁 + 深色模式 + RWD + fintech UI |
| 資料庫遷移 | ✅ 完成 | SQLite → Supabase sync 已上線；API prod 從 Supabase 讀取 |
| 銀行擴充 | 🔄 進行中 | TAISHIN ✅ FUBON ✅ CTBC ✅ 完成（5 銀行 101 張卡 452 筆優惠）、下一批：MEGA / SINOPAC |
| Auth / Rate Limiting | ⏳ 未開始 | Phase 2 商業化時實作 |

## 已支援銀行

| 銀行 | Extractor | 擷取方式 |
|------|-----------|----------|
| ✅ E.SUN（玉山） | `esun_real.py` | HTML 頁面直接抓取 |
| ✅ CATHAY（國泰） | `cathay_real.py` | Model JSON 抽取 |
| ✅ TAISHIN（台新） | `taishin_real.py` | Cloudflare Browser Rendering + HTML |
| ✅ FUBON（富邦） | `fubon_real.py` | Cloudflare Browser Rendering + HTML |
| ✅ CTBC（中信） | `ctbc_real.py` | JSON API（creditcards.cardlist.json）+ Playwright |
| ⏳ MEGA / FIRST / SINOPAC / TPBANK / UBOT | — | 待排入 |

---

## 各子專案詳細狀態

### cardsense-web（最活躍）

**Latest**: `f04ea6d` — refactor: extract FilterChip component and unify touch target tokens (2026-04-04)

**近期功能迭代**：
- `f04ea6d` refactor: extract FilterChip component and unify touch target tokens
- `8819dbc` fix: improve mobile responsiveness, touch targets, and accessibility
- `e6f229a` feat: clarify strict subcategory comparison in web UI
- `19a33b8` feat: add subcategory context to recommendation flows
- `b441466` Add anomaly warning for cashback rates exceeding 20%
- `4aced72` Add Vercel analytics

**已完成功能**：
- `/calc` 年度損失社群入口頁（計算機風格金額輸入、消費類別/場景選擇、回饋排名 bar chart、年度損失動畫計數器、Canvas 分享圖片生成）
- 情境式推薦表單（金額、類別、子類別場景、通路）
- 疊加優惠計算（自動計算所有可疊加優惠總和）
- 優惠明細展開（逐一列出回饋金額、條件、有效期）
- 損益平衡分析（疊加模式自動計算兩卡損益平衡消費點）
- 卡片目錄頁（多維篩選：銀行、資格類型、優惠類別、年費區間、推薦範圍；可收合進階篩選）
- 卡片詳情頁（基本資料 + 優惠資訊依類別分組顯示 + 權益切換提醒 + 一鍵跳轉推薦）
- 深色模式（跟隨系統偏好，可手動切換）
- 行動裝置 RWD 最佳化（響應式 header、touch target 合規 44/36px、300ms tap delay 消除）
- Fintech 風格 UI（OKLCH 語意色彩 token）
- API 連線狀態指示
- 無障礙（aria-label、aria-expanded、prefers-reduced-motion）
- 共用 FilterChip 元件 + touch target sizing tokens（`--spacing-touch` / `--spacing-touch-sm`）
- 回饋率超過 20% 異常警告

**技術棧**：React 19 / TypeScript 5.9 / Vite 8 / TailwindCSS 4 / React Router 7 / TanStack Query 5 / Radix UI + shadcn/ui / Lucide

### cardsense-api

**Latest**: `158243e` — fix: cap reward to never exceed transaction amount + refresh DB (2026-03-23)

**核心實作**：
- `DecisionEngine`（736+ 行）— 確定性推薦邏輯，scenario 解析、promotion 過濾、回饋計算、排序
- `RewardCalculator` — PERCENT / FIXED / POINTS 回饋計算，封頂邏輯
- `CatalogService` — 卡片目錄查詢，scope-aware（RECOMMENDABLE / CATALOG_ONLY / FUTURE_SCOPE）
- `SqlitePromotionRepository` / `SupabasePromotionRepository` — 支援 local SQLite 與 prod Supabase 兩種 promotion 來源
- `CorsConfig` — 前端跨域存取
- `ApiKeyFilter` — API Key 認證（public endpoints 免驗）

**比較模式**：固定使用疊加優惠計算（`STACK_ALL_ELIGIBLE`），已移除 `BEST_SINGLE_PROMOTION` 模式（其結果為疊加模式的子集，無獨立用途）。

**eligibilityType 過濾**：
| Type | 說明 |
|------|------|
| `GENERAL` | 一般卡片，可進入推薦排名 |
| `PROFESSION_SPECIFIC` | 職業限定卡（醫師卡、會計師卡等），僅目錄展示 |
| `BUSINESS` | 商務/公司卡，僅目錄展示 |

**平台/通路 Condition 匹配**：
| Condition Type | 用途 | 範例 |
|---|---|---|
| `ECOMMERCE_PLATFORM` | 電商平台限定 | MOMO, SHOPEE, PCHOME |
| `RETAIL_CHAIN` | 實體通路限定 | COSTCO, PXMART, CARREFOUR |
| `PAYMENT_PLATFORM` | 支付平台限定 | LINE_PAY, JKOPAY, TAIWAN_PAY |

**推薦排序（確定性五層 tiebreaker）**：
1. effective return 降序
2. 到期日升序
3. 年費升序
4. 銀行 code
5. promoVersionId

**Repository 模式**：
| 模式 | 設定 | 資料來源 |
|------|------|----------|
| mock（預設） | 無需設定 | `promotions.json` |
| sqlite | `cardsense.repository.mode=sqlite` | extractor 匯入的 `promotion_current` |
| supabase | `cardsense.repository.mode=supabase` | Supabase PostgreSQL `promotion_current` |

**部署**：Render；prod profile 連 Supabase PostgreSQL，local profile 保留 SQLite

**測試覆蓋**：DecisionEngineTest（387+ 行）、CathaySqliteApiIntegrationTest（327 行）、SqliteApiSmokeTest、CatalogServiceTest、SqlitePromotionRepositoryTest

**Postman Collection**：`postman/` 目錄包含完整 smoke test（Health、Cards By Bank、Recommend Card、Stackability Scenario）

### cardsense-extractor

**Latest**: `32bce41` — feat: add Playwright fetcher, CTBC runner, Fubon name cleaning (2026-03-24)

**專案結構**：
```
extractor/
├── esun_real.py               # E.SUN：HTML 頁面直接抓取
├── cathay_real.py             # Cathay：Model JSON 抽取
├── taishin_real.py            # Taishin：Cloudflare Browser Rendering
├── fubon_real.py              # Fubon：Cloudflare Browser Rendering
├── ctbc_real.py               # CTBC：JSON API + Playwright（47 張卡）
├── promotion_rules.py         # reward / category / condition / subcategory heuristics
├── html_utils.py              # HTML cleanup helpers
├── page_extractors/
│   └── sectioned_page.py     # shared section / offer block extraction
├── db_store.py                # SQLite persistence helpers
├── supabase_store.py          # Supabase PostgreSQL sync helpers
├── ingest.py / parse_rules.py / normalize.py / validate.py / versioning.py / load.py
jobs/
├── refresh_and_deploy.py      # 一鍵全銀行 extract → import → Supabase sync
├── import_jsonl_to_db.py      # JSONL → SQLite importer
├── run_real_bank_job.py       # shared runner for bank extractors
├── run_{esun,cathay,taishin,fubon,ctbc}_real_job.py
├── analyze_jsonl_output.py    # quality inspection
sql/
└── cardsense_schema.sql       # SQLite schema
```

**Recommendation Scope 分類**：
| Scope | 說明 |
|-------|------|
| `RECOMMENDABLE` | 可由單筆交易 deterministic 判斷，進入推薦排名 |
| `CATALOG_ONLY` | 保留在卡片 catalog 展示，不進 ranking |
| `FUTURE_SCOPE` | 已抽取但 API 缺乏必要上下文（首刷、新戶、身份型等） |

**SQLite Schema**：
| Table | 用途 |
|-------|------|
| `promotion_versions` | 歷次 promotion version 資料 |
| `promotion_current` | 每個 `promoId` 的最新版本，供 API 查詢 |
| `extract_runs` | 每次抽取或匯入執行紀錄 |

### cardsense-contracts

**Latest**: `b0589b3` — docs: rewrite README with unified structure (2026-03-20)

**Schema 結構**：
```
promotion/     → promotion-normalized.schema.json + valid/invalid 範例
recommendation/ → request + response JSON schema 與範例
taxonomy/      → category / channel / frequency taxonomy
```

**Stackability Metadata**：描述優惠間的可疊加關係
- 永遠可疊加
- 互斥群組
- 依賴其他優惠才可生效
- 需人工判斷，不進 deterministic stack mode

---

## API 端點

| 方法 | 路徑 | 說明 |
|------|------|------|
| GET | `/health` | 健康檢查（DB 連線 + 運行狀態） |
| GET | `/v1/banks` | 銀行列表 |
| GET | `/v1/cards?bank=&status=&scope=&eligibilityType=` | 卡片目錄（支援 eligibilityType 篩選） |
| GET | `/v1/cards/{cardCode}/promotions` | 卡片優惠列表（依 category 分組） |
| GET | `/v1/cards/{cardCode}/plans` | 卡片 benefit plan 列表 |
| POST | `/v1/recommendations/card` | 情境推薦 |

**API 方案（Phase 2）**：

| 方案 | 每日上限 | 價格 |
|------|---------|------|
| FREE | 100 次 | $0 |
| STARTER | 5,000 次 | $29/月 |
| GROWTH | 50,000 次 | $99/月 |
| ENTERPRISE | 無限 + SLA | 客製 |

---

## 已知限制（截至 2026-03-23）

**API**：
- SQLite repo 從 `raw_payload_json` 還原 `stackability` metadata，尚未拆成顯式欄位
- `POINTS` 尚未引入銀行別點數折現規則
- Break-even 目前只處理代表 promotion 間的 `FIXED` vs `PERCENT` 比較
- `STACK_ALL_ELIGIBLE` 仍為 heuristic aggregation，待 `stackability` 標註完整後升級為 deterministic stacking

**Extractor**：
- 銀行頁面結構可能改版，heuristic 需持續調整
- 部分活動屬於身份型、首刷型或分期型，只適合歸類為 `CATALOG_ONLY` 或 `FUTURE_SCOPE`
- Real extractor 依賴外部網站可用性

**Contracts**：
- `POINTS` 型別尚未定義銀行別點數折現規則
- `stackability` metadata 設計完成，部分銀行的實際標註資料仍在累積中

---

## 待辦工作路線圖（Roadmap）

### Phase 1：新銀行擴充 + Extractor 能力提升

**新銀行優先序**：TAISHIN ✅ → FUBON ✅ → CTBC ✅（JSON API 繞過 WAF，Playwright 抓 detail 頁）

- 每家銀行先分析官網結構，判斷適用 HTML 抽取或 JSON API
- 復用 `promotion_rules.py` 與 `run_real_bank_job.py` 共用層
- 每家銀行作為獨立 extractor 檔案（如 `ctbc_real.py`）
- 完成一家就匯入 SQLite 並跑 API smoke test，不等全部做完

**Extractor 能力提升**：
- 強化 `sectioned_page.py` 的 section detection，支援更多 heading 模式
- 在 `promotion_rules.py` 增加更多 category/channel signal 權重
- 為每家新銀行建立 fixture 檔案，確保 heuristic 變更不破壞既有銀行

**API 下一步**：
- `stackability` 拆成顯式 SQLite 欄位
- 擴充 ESUN / CATHAY stacked-promotion 整合測試 fixtures
- 加入 promotion 排除原因的可解釋性說明
- 定義 `POINTS` 型別的銀行別點數折現規則

### Phase 2：商業化準備

**前提**：Phase 1 達到 5 家銀行 + 前端穩定。

- `cardsense-web` 新增 `/calc` 傳播入口頁，驗證分享率與推薦頁導流率
- API Key 認證 + Rate Limiting
- 免責聲明 + 聯盟行銷連結揭露
- B2B 客戶 onboarding 流程
- Stripe Billing 整合（API 訂閱制）
- 前端進階功能：break-even 視覺化 ✅、多優惠堆疊展示 ✅

### Phase 3：資料庫遷移（SQLite → Supabase）✅

- Extractor 已支援 SQLite → Supabase sync（`supabase_store.py` + `refresh_and_deploy.py`）
- API prod profile 已切到 Supabase PostgreSQL，local profile 仍保留 SQLite
- `promotion_versions` / `promotion_current` / `extract_runs` 三張表都已完成 schema parity
- `subcategory` 與 `planId` 等新欄位已貫穿 SQLite / Supabase / API response

### Phase 4：Skill 整理

- 現有 3 個 skill（contract-evolution、git-commit-push、api-smoke-postman）維護良好
- 考慮新增：
  - `cardsense-extractor-new-bank` — 新銀行 extractor 開發的標準流程
  - `cardsense-full-pipeline-verify` — 從抽取到 API 驗證的端對端驗收流程

---

## 快速開始

### Extractor — 擷取銀行優惠資料

```bash
cd cardsense-extractor
uv sync
uv run pytest                                    # 單元測試
uv run python jobs/run_esun_real_job.py           # 玉山 real extraction
uv run python jobs/run_cathay_real_job.py         # 國泰 real extraction
uv run python jobs/run_taishin_real_job.py        # 台新 real extraction
uv run python jobs/run_fubon_real_job.py          # 富邦 real extraction
uv run python jobs/import_jsonl_to_db.py \
  --input outputs/fubon-real-*.jsonl \
  --db data/cardsense.db                          # 匯入 SQLite

# 一鍵全銀行提取 → 匯入 → 部署
uv run python jobs/refresh_and_deploy.py          # 全部銀行
```

### API — 啟動推薦服務（本地開發）

```bash
cd cardsense-api
# 使用 mock 資料
mvn spring-boot:run

# 使用 SQLite（real extractor 資料）
mvn spring-boot:run \
  -Dspring-boot.run.jvmArguments="\
    -Dcardsense.repository.mode=sqlite \
    -Dcardsense.repository.sqlite.path=/path/to/cardsense.db"
```

### Frontend — 啟動前端（本地開發）

```bash
cd cardsense-web
npm install
cp .env.example .env.local                       # 設定 VITE_API_BASE_URL
npm run dev                                       # http://localhost:5173
```

### 線上環境

| 服務 | 平台 | URL |
|------|------|-----|
| Frontend | Vercel | https://cardsense-web.vercel.app |
| API | Render | (internal，透過前端 proxy 存取) |

---

## 法律與合規

- 每筆回應包含強制法律免責聲明
- API 不收集用戶個資 — `api_calls` 表儲存 `client_id`（B2B 實體），非終端用戶
- 聯盟行銷連結在 `applyUrl` 欄位明確標示
- Extractor 僅爬取公開可存取頁面，遵守 `robots.txt`，每銀行每秒最多 1 次請求
- 金融許可諮詢進行中（台灣「信用卡比較」是否屬需特許金融業務？）

---

## 子專案連結

- [cardsense-contracts](https://github.com/WaddleStudio/cardsense-contracts) — 共用資料契約、schema、列舉定義、stackability
- [cardsense-extractor](https://github.com/WaddleStudio/cardsense-extractor) — 資料擷取 pipeline、5 銀行 extractor、SQLite 匯入
- [cardsense-api](https://github.com/WaddleStudio/cardsense-api) — 推薦 API、疊加優惠計算、benefit plan / subcategory、Postman collection
- [cardsense-web](https://github.com/WaddleStudio/cardsense-web) — 前端展示、推薦表單、卡片目錄、深色模式
- [CardSense Demo Spec](./CardSense-Demo-Spec.md) — `/calc` 社群入口頁詳細規格
- [CardSense Spec](./specs/spec-cardSense.md) — 完整專案規格說明書
- [推薦引擎增強設計](./specs/cardsense-plans/2026-03-28-recommendation-enhancement-design.md) — 六項增強設計文件
- [推薦引擎增強實作計畫](./specs/cardsense-plans/2026-03-28-recommendation-enhancement-impl.md) — 10-task 實作計畫
- [API Implementation Checklist](https://github.com/WaddleStudio/cardsense-api/blob/master/IMPLEMENTATION_CHECKLIST.md) — API 待辦與遷移時機

*Last updated: 2026-04-05*
## Update Addendum (2026-04-05)

### Newly Completed

- Fixed card-catalog eligibility aggregation in API so card-level filtering no longer depends on the first promotion row only.
- Fixed extractor output so business / profession-specific cards emit the correct promotion-level `eligibilityType` instead of falling back to `GENERAL`.
- Expanded benefit-plan subcategory coverage for benefit-switching cards, especially Cathay CUBE, Taishin Richart, and ESUN Unicard.
- Refreshed extractor data and redeployed the local DB snapshot used by `cardsense-api`.

### Notes

- Card catalog filtering accuracy now depends on both API-side card eligibility aggregation and extractor-side promotion eligibility tagging.
- If benefit-plan or eligibility heuristics change again, rerunning `refresh_and_deploy.py` is required before frontend behavior will reflect the fix.
