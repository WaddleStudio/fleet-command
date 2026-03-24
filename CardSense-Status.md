# CardSense — 情境式信用卡推薦平台

CardSense 是一個以**情境式卡片比較**為核心的信用卡推薦平台。不同於傳統的單筆優惠排名，CardSense 接收使用者的消費情境（金額、類別、通路、日期等），過濾不符合條件的優惠，比較各張卡在該情境下的有效回饋，回傳可解釋的推薦結果。

> **Live**: https://cardsense-web.vercel.app

---

## 子專案與 Repo

| 子專案 | 角色 | 技術棧 | 部署 | GitHub |
|--------|------|--------|------|--------|
| cardsense-contracts | 共用資料契約（JSON Schema、DTO、列舉、stackability） | JSON Schema | — | [WaddleStudio/cardsense-contracts](https://github.com/WaddleStudio/cardsense-contracts) |
| cardsense-extractor | 銀行優惠資料擷取與正規化 | Python 3.13+ / uv / Pydantic / SQLite | Local | [WaddleStudio/cardsense-extractor](https://github.com/WaddleStudio/cardsense-extractor) |
| cardsense-api | 情境推薦 REST API | Java 21 / Spring Boot / SQLite / Maven | Railway | [WaddleStudio/cardsense-api](https://github.com/WaddleStudio/cardsense-api) |
| cardsense-web | 前端展示 | React 19 / TypeScript 5.9 / Vite 8 / shadcn/ui / Tailwind CSS 4 | Vercel | [WaddleStudio/cardsense-web](https://github.com/WaddleStudio/cardsense-web) |

> 所有 repo 集中於 `D:/Projects/cardsense-workspace/` 統一管理。

## 架構總覽

```
銀行官網 ──→ Extractor ──→ JSONL ──→ SQLite ──→ API (Railway) ──→ Frontend (Vercel)
              │                        │
              │  scrape / heuristic    │  promotion_current table
              │  normalize / version   │  確定性規則引擎
              ▼                        ▼
        cardsense-contracts      cardsense-contracts
        (schema 驗證)            (DTO / response 契約)
```

**核心設計原則**：
- **用戶請求路徑零 LLM** — 確定性規則引擎，100% 可重現、可審計
- **版本不可變** — `promoVersionId`，語義變更 = 新版本，SHA-256 hash 去重
- **強制免責聲明** — 每筆 API 回應包含法律 disclaimer
- **Repository 抽象** — mock / sqlite 雙模式，切換無需改動業務邏輯

**資料流**：
1. **Extractor** 從銀行官網擷取原始優惠頁面（local 執行）
2. 經過 scrape → parse_rules → normalize → validate → version 產生 JSONL
3. `import_jsonl_to_db.py` 匯入 **SQLite** 的 `promotion_current` table
4. `refresh_and_deploy.py` 一鍵完成全銀行提取 → 匯入 → 部署至 Railway
5. **API** (Railway) 從 SQLite 讀取 promotion 資料，Dockerfile bake-in DB
6. **Frontend** (Vercel) 呼叫 API 展示推薦結果

---

## 完成進度

| 模組 | 狀態 | 說明 |
|------|------|------|
| cardsense-contracts | ✅ 完成 | Promotion / Recommendation / Stackability schema 穩定，結構化 conditions |
| cardsense-extractor | ✅ 核心完成 | E.SUN + Cathay + TAISHIN + FUBON + CTBC real extractor、JSONL + SQLite 匯入、refresh_and_deploy 一鍵流程 |
| cardsense-api | ✅ 核心完成 + 已部署 | 情境推薦、雙模式比較（BEST_SINGLE / STACK_ALL）、break-even、scope 過濾、stackability 解析；Railway 上線 |
| cardsense-web | ✅ MVP 完成 + 已部署 | 推薦表單 + 卡片目錄（101 張卡）+ 銀行篩選 + 深色模式 + RWD + fintech UI；Vercel 上線 |
| 資料庫遷移 | ⏳ 規劃中 | SQLite → Supabase，待觸發條件（見 Phase 3） |
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

**Latest**: `92c56c6` — fix: prevent logo and card title overflow on narrow screens (2026-03-24)

**近期功能迭代**：
- `89aeda3` fix: remaining UX issues + break-even analysis display
- `802ecf0` feat: fintech UI redesign + UX bug fixes
- `c5ab6c8` fix: prevent badge and card content overflow on narrow screens
- `4f60279` fix: cashback display, horizontal overflow, and theme redesign
- `2c561a3` feat: UI optimization — mobile RWD, form UX, dark mode, animations, card detail page
- `59a814d` Upgrade recommendation results UI and card catalog filters

**已完成功能**：
- 情境式推薦表單（金額、類別、通路）
- 兩種比較模式（最佳單一優惠 / 所有可疊加優惠）
- 優惠明細展開（逐一列出回饋金額、條件、有效期）
- 損益平衡分析（疊加模式自動計算兩卡損益平衡消費點）
- 卡片目錄頁 + 詳情頁（依銀行、名稱篩選與排序）
- 深色模式（跟隨系統偏好，可手動切換）
- 行動裝置 RWD 最佳化
- Fintech 風格 UI（OKLCH 語意色彩 token）
- API 連線狀態指示

**技術棧**：React 19 / TypeScript 5.9 / Vite 8 / TailwindCSS 4 / React Router 7 / TanStack Query 5 / Radix UI + shadcn/ui / Lucide

### cardsense-api

**Latest**: `158243e` — fix: cap reward to never exceed transaction amount + refresh DB (2026-03-23)

**核心實作**：
- `DecisionEngine`（736+ 行）— 確定性推薦邏輯，scenario 解析、promotion 過濾、回饋計算、排序
- `RewardCalculator` — PERCENT / FIXED / POINTS 回饋計算，封頂邏輯
- `CatalogService` — 卡片目錄查詢，scope-aware（RECOMMENDABLE / CATALOG_ONLY / FUTURE_SCOPE）
- `SqlitePromotionRepository` — 讀取 extractor 匯入的 `promotion_current`，還原 stackability metadata
- `CorsConfig` — 前端跨域存取
- `ApiKeyFilter` — API Key 認證（public endpoints 免驗）

**比較模式**：
| Mode | 說明 |
|------|------|
| `BEST_SINGLE_PROMOTION` | 每張卡取最佳單筆 promotion 做排名 |
| `STACK_ALL_ELIGIBLE` | 依 `promotion.stackability` metadata 解出可並存組合，計算 card-level total return |

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

**部署**：Railway，Dockerfile bake-in SQLite DB

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
├── promotion_rules.py         # reward / category / condition heuristics（含民國年份轉換）
├── html_utils.py              # HTML cleanup helpers
├── page_extractors/
│   └── sectioned_page.py     # shared section / offer block extraction
├── db_store.py                # SQLite persistence helpers
├── ingest.py / parse_rules.py / normalize.py / validate.py / versioning.py / load.py
jobs/
├── refresh_and_deploy.py      # 一鍵全銀行 extract → import → deploy（含 CTBC）
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
| GET | `/v1/cards?bank=&status=&scope=` | 卡片目錄（scope=CATALOG_ONLY 拉 catalog 型卡片） |
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

- API Key 認證 + Rate Limiting
- 免責聲明 + 聯盟行銷連結揭露
- B2B 客戶 onboarding 流程
- Stripe Billing 整合（API 訂閱制）
- 前端進階功能：break-even 視覺化 ✅、多優惠堆疊展示 ✅

### Phase 3：資料庫遷移（SQLite → Supabase）

不急，按觸發條件決定時機。**任一成立即啟動**：

- 多個前端環境需要共享讀取
- audit log 需外部查詢
- extractor 需集中儲存
- 部署環境需共享 persistence

**遷移步驟**：

1. 凍結前端 API 契約
2. 完成 E.SUN / CATHAY 端對端 smoke coverage
3. 建立 PostgreSQL schema parity
4. 加入 repository abstraction 雙跑測試
5. 切換至 Supabase

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
| API | Railway | (internal，透過前端 proxy 存取) |

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
- [cardsense-api](https://github.com/WaddleStudio/cardsense-api) — 推薦 API、比較模式、break-even 分析、Postman collection
- [cardsense-web](https://github.com/WaddleStudio/cardsense-web) — 前端展示、推薦表單、卡片目錄、深色模式
- [CardSense Spec](./specs/spec-cardSense.md) — 完整專案規格說明書
- [API Implementation Checklist](https://github.com/WaddleStudio/cardsense-api/blob/master/IMPLEMENTATION_CHECKLIST.md) — API 待辦與遷移時機

*Last updated: 2026-03-24*
