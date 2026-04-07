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

> 所有 repo 集中於 workspace 根目錄統一管理（無 git 版控，各 repo 獨立版控）。

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
| cardsense-api | ✅ 核心完成 + 已部署 | 情境推薦、疊加優惠計算、break-even、subcategory 場景過濾、scope/eligibilityType/通路 condition 匹配；指定 subcategory 時會一起比較 matching scene + GENERAL；Render 上線 |
| cardsense-web | ✅ MVP 完成 + 已部署 | 推薦表單 + 卡片目錄 + SubcategoryGrid 場景選擇 + `/calc` 社群入口頁 + merchantName 輸入/提示 + 深色模式 + RWD + fintech UI |
| 資料庫遷移 | ✅ 完成 | SQLite → Supabase sync 已上線；API prod 從 Supabase 讀取 |
| 銀行擴充 | ✅ Phase 1 完成 | 5 家銀行上線（E.SUN / Cathay / Taishin / Fubon / CTBC），100 張卡 763 筆優惠（506 RECOMMENDABLE） |
| 資料品質 | ✅ P0 完成 | general reward expansion 修復、Richart plan-specific 修復、feature extractor expansion 修復；RECOMMENDABLE 從 387→506；聯名卡通路 + 日期 condition 推斷已上線 |
| Auth / Rate Limiting | ⏳ 未開始 | Phase 2 商業化時實作 |

## 已支援銀行

| 銀行 | Extractor | 擷取方式 |
|------|-----------|----------|
| ✅ E.SUN（玉山） | `esun_real.py` | HTML 頁面直接抓取 |
| ✅ CATHAY（國泰） | `cathay_real.py` | Model JSON 抽取 |
| ✅ TAISHIN（台新） | `taishin_real.py` | Cloudflare Browser Rendering + HTML |
| ✅ FUBON（富邦） | `fubon_real.py` | Cloudflare Browser Rendering + HTML |
| ✅ CTBC（中信） | `ctbc_real.py` | JSON API（creditcards.cardlist.json）+ Playwright |
| — MEGA / FIRST / SINOPAC / TPBANK / UBOT | — | Backlog，待既有 5 家資料品質提升後再排入 |

---

## 各子專案詳細狀態

### cardsense-web（最活躍）

**Latest**: `e42c838` — Add total and recommendable promotion counts to CardItem component

**近期功能迭代**：
- `e42c838` Add total and recommendable promotion counts to CardItem component
- `0581117` Show catalog review and general reward hints
- `b2f01ed` Promote key filters above advanced section, default to free/general
- `8535265` Reorder form fields and add grouped payment method picker
- `d9f25aa` Unify condition badge colors across card detail and recommendation pages
- `8f6ab8c` Improve card detail page: color-coded badges, bank-themed header, fix mobile nav overflow
- `e3364b7` Improve cards catalog page: bank colors, highlights, better empty state
- `2cd5ac3` Add WaddleStudio credit to footer
- `21183d8` Hide generic mobile pay option from payment filters
- `2a7e3a5` Show benefit tier badges for Richart
- `1cb1f4f` Improve UI/UX: collapsible switching cards, merchant picker, accessibility fixes
- `a748b3d` Align switching card plan labels with official names
- `1760995` Add switching card state controls to recommendation UIs
- `c4cf8cf` Add shopping and donation subcategory labels
- `de4ab51` Refine travel platform classification
- `85cb93b` Add payment method selection to calculator

**已完成功能**：
- `/calc` 年度損失社群入口頁（計算機風格金額輸入、消費類別/場景選擇、回饋排名 bar chart、年度損失動畫計數器、Canvas 分享圖片生成）
- 情境式推薦表單（金額、類別、子類別場景、通路、支付方式）
- 疊加優惠計算（自動計算所有可疊加優惠總和）
- 優惠明細展開（逐一列出回饋金額、條件、有效期）
- 損益平衡分析（疊加模式自動計算兩卡損益平衡消費點）
- 卡片目錄頁（多維篩選：銀行、資格類型、優惠類別、年費區間、推薦範圍；可收合進階篩選；銀行品牌色 + 精選標記 + 空狀態優化）
- 卡片詳情頁（基本資料 + 優惠資訊依類別分組顯示 + 權益切換提醒 + 一鍵跳轉推薦）
- 權益切換卡支援（可折疊切換卡狀態控制、merchant picker、benefit tier badges、官方方案名稱對齊）
- 深色模式（跟隨系統偏好，可手動切換）
- 行動裝置 RWD 最佳化（響應式 header、touch target 合規 44/36px、300ms tap delay 消除）
- Fintech 風格 UI（OKLCH 語意色彩 token）
- API 連線狀態指示
- 無障礙（aria-label、aria-expanded、prefers-reduced-motion）
- 共用 FilterChip 元件 + touch target sizing tokens（`--spacing-touch` / `--spacing-touch-sm`）
- 回饋率超過 20% 異常警告
- WaddleStudio footer credit

**技術棧**：React 19 / TypeScript 5.9 / Vite 8 / TailwindCSS 4 / React Router 7 / TanStack Query 5 / Radix UI + shadcn/ui / Lucide

### cardsense-api

**Latest**: `1270f2a` — Add catalog review signals to API responses

**近期功能迭代**：
- `1270f2a` Add catalog review signals to API responses
- `494129f` Fix Supabase prepared statement pooler issue
- `c4c375f` Add Richart benefit level runtime handling
- `609470a` Add active plan runtime state to recommendation engine
- `5f275ef` Tighten scenario ranking for scoped promotions
- `ded3278` Refine travel platform classification
- `b587d4f` Support payment method aware recommendation matching
- `a2c1d25` fix: include general promos in subcategory scene matching
- `81acccc` feat: support cube benefit tiers at recommendation time

**核心實作**：
- `DecisionEngine`（736+ 行）— 確定性推薦邏輯，scenario 解析、promotion 過濾、回饋計算、排序；支援 subcategory 場景過濾、payment method 匹配、benefit tier 運行時覆寫
- `RewardCalculator` — PERCENT / FIXED / POINTS / MILES 回饋計算，封頂邏輯
- `CatalogService` — 卡片目錄查詢，scope-aware（RECOMMENDABLE / CATALOG_ONLY / FUTURE_SCOPE）
- `SqlitePromotionRepository` / `SupabasePromotionRepository` — 支援 local SQLite 與 prod Supabase 兩種 promotion 來源
- `CorsConfig` — 前端跨域存取
- `ApiKeyFilter` — API Key 認證（public endpoints 免驗）
- `BenefitPlan` entity + `JsonBenefitPlanRepository` — benefit plan 運行時選擇，active plan runtime state

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
| `MERCHANT` | 商家名稱限定 | CHATGPT, CLAUDE, UBER_EATS, CHINA_AIRLINES |
| `DAY_OF_MONTH` | 每月指定日 | 13（每月13號卡友日） |
| `DAY_OF_WEEK` | 每週指定日 / 週末 | WED, FRI_SAT, WEEKEND |

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

**Latest**: `ca7b38c` — docs: add cobranded retailer and date conditions implementation plan

**近期功能迭代**：
- `ca7b38c` docs: add cobranded retailer and date conditions implementation plan
- `dd91685` fix: use post-expansion cobranded condition inference for E.SUN
- `0a3b588` feat: wire cobranded retailer and date conditions into all extractors
- `fa4087f` feat: add date condition inference (DAY_OF_MONTH, DAY_OF_WEEK)
- `ae41e9b` feat: add co-branded retailer condition inference for 中友百貨 and 大江
- `3fb8f80` fix: recategorize HERBALIFE general reward for expansion
- `d001ab4` fix: pass Fubon feature extractor promos through general reward expansion
- `84c4294` fix: keep Richart plan-specific promos RECOMMENDABLE despite registration text
- `c712e39` fix: promote decomposed general reward clones to RECOMMENDABLE
- `8d3e590` docs: update skills, case studies, and README for feature extractor pattern
- `e4bbf7d` feat: add MILES cashback type and feature extractors for Cathay/Fubon cards
- `5f23202` feat: add Taishin feature extractors for 9 card families
- `a1f02ca` feat: add flexible CTBC targeted extraction and extract-ctbc skill
- `d6920fa` feat: implement general reward promotion expansion across multiple extractors
- `d063574` Add catalog review and bank-wide supplement rules
- `98b1054` feat: review taishin card promos
- `4f663ed` fix: review and sync CTBC promo cleanup
- `5a113d3` Add missing Formosa card promotions
- `228f80c` Review and clean Fubon promo extraction

**專案結構**：
```
extractor/
├── esun_real.py               # E.SUN：HTML 頁面直接抓取
├── cathay_real.py             # Cathay：Model JSON 抽取
├── taishin_real.py            # Taishin：Cloudflare Browser Rendering
├── fubon_real.py              # Fubon：Cloudflare Browser Rendering
├── ctbc_real.py               # CTBC：JSON API + Playwright（47 張卡）
├── promotion_rules.py         # reward / category / condition / subcategory / cobranded / date heuristics
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
├── run_ctbc_targeted.py       # CTBC targeted extraction (specific cards by slug)
├── run_taishin_targeted.py    # Taishin targeted extraction (12 priority cards)
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

**Latest**: `a976614` — docs: add canonical subcategory taxonomy

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

## 已知限制（截至 2026-04-07）

**API**：
- SQLite repo 從 `raw_payload_json` 還原 `stackability` metadata，尚未拆成顯式欄位
- `POINTS` 尚未引入銀行別點數折現規則；`MILES` 為新增類型，API 端 `RewardCalculator` 需對應支援
- Break-even 目前只處理代表 promotion 間的 `FIXED` vs `PERCENT` 比較
- `STACK_ALL_ELIGIBLE` 仍為 heuristic aggregation，待 `stackability` 標註完整後升級為 deterministic stacking

**Extractor**：
- `DAY_OF_MONTH` / `DAY_OF_WEEK` condition 目前僅標記，API 端尚未依日期過濾推薦結果
- `COBRANDED_RETAILER_SIGNALS` 目前僅覆蓋中友百貨 / 大江，其他聯名卡通路待擴充
- 銀行頁面結構可能改版，heuristic 需持續調整
- 部分活動屬於身份型、首刷型或分期型，只適合歸類為 `CATALOG_ONLY` 或 `FUTURE_SCOPE`
- Real extractor 依賴外部網站可用性

**Contracts**：
- `POINTS` 型別尚未定義銀行別點數折現規則；`MILES` 已新增於 extractor 端，contracts schema 需同步
- `stackability` metadata 設計完成，部分銀行的實際標註資料仍在累積中

---

## 已完成里程碑

### Phase 1：5 家銀行上線 + Extractor 架構 ✅

5 家銀行上線（E.SUN / Cathay / Taishin / Fubon / CTBC），91 張卡 717 筆優惠（387 RECOMMENDABLE）。Feature extractors 補強主要卡片回饋覆蓋率。

### Phase 2：前端 + 社群入口 ✅

推薦頁、卡片目錄、`/calc` 社群入口頁、break-even 視覺化、深色模式、RWD。

### Phase 3：資料庫遷移 ✅

SQLite → Supabase sync 上線，API prod 從 Supabase 讀取。

### Skill 整理 ✅

| Skill | 位置 | 說明 |
|-------|------|------|
| `cardsense-bank-promo-review` | `cardsense-extractor/skills/` | 銀行優惠頁面審查 |
| `cardsense-pipeline-verify` | `fleet-command/skills/` (跨 repo) | 端對端驗收 |
| `cardsense-contract-evolution` | `fleet-command/skills/` (跨 repo) | 共用契約演進 |

跨 repo skill 原始檔在 `fleet-command/skills/`，透過 symlink 掛載到 workspace 根目錄 `.claude/skills/`。

---

## 待辦工作路線圖（Roadmap）

### 🔥 當前優先：既有 5 家銀行資料品質提升

**問題現狀**（2026-04-07 部署後）：

- 100 張卡 763 筆優惠：506 RECOMMENDABLE / 148 CATALOG_ONLY / 109 FUTURE_SCOPE
- 82 張卡有 RECOMMENDABLE 優惠
- 16 張卡完全沒有 RECOMMENDABLE 優惠（純 CATALOG_ONLY）
- `MILES` 回饋類型已新增於 extractor 端，API 端 RewardCalculator 需對應支援
- 3 張 Fubon 卡（INSURANCE、INFINITE、DIGITALLIFE）在最新 extraction 中消失，疑似銀行網頁變動

**目標**：讓每張 RECOMMENDABLE 卡在其適用的消費情境中都能公平入榜比較。

#### P0：泛用回饋卡補全 — ✅ 完成

**已完成**：
- ✅ General reward promotion expansion 跨 5 家 extractor 實作（`d6920fa`）
- ✅ Feature extractors 為主要卡族補上基本回饋（Cathay/Fubon/Taishin/ESUN）
- ✅ E.SUN 覆蓋率大幅提升（14→45 張卡，RECOMMENDABLE 85→271 筆）
- ✅ DecisionEngine 已支援泛用回饋與指定通路優惠一起排名
- ✅ Decomposed general reward clones 提升為 RECOMMENDABLE（`c712e39`）— 修復 POYA +7、ANGEL/TAIMALL/TAIPEICITY/GLOBALMALL 等聯名卡
- ✅ Richart plan-specific promos 不因登錄文字降級（`84c4294`）— RICHART +4
- ✅ Fubon feature extractor 通過 general reward expansion（`d001ab4`）— INSURANCE +6
- ✅ HERBALIFE 分類修正 ONLINE/SUBSCRIPTION → OTHER/GENERAL（`3fb8f80`）— HERBALIFE +6
- ✅ 低覆蓋卡審查完成：26 張中可修的已修，其餘為 niche 聯名卡（航空/旅遊/車廠/飯店），1-2 筆 RECOMMENDABLE 已合理

**剩餘項目（移至後續待辦）**：
- `MILES` 類型 API 端 RewardCalculator 支援
- 3 張消失的 Fubon 卡需 targeted re-extraction

#### P0.5：聯名卡通路 + 日期 Condition 推斷 — ✅ 完成

**問題**：中友百貨、大江等聯名卡的特定通路優惠被當成通用回饋（缺少 RETAIL_CHAIN condition）；每月13號卡友日等限定日期優惠缺少日期 condition。

**已完成**：
- ✅ `COBRANDED_RETAILER_SIGNALS` 字典 — title 關鍵字 → RETAIL_CHAIN condition 映射（`ae41e9b`）
- ✅ `append_inferred_date_conditions()` — DAY_OF_MONTH / DAY_OF_WEEK / WEEKEND regex 偵測（`fa4087f`）
- ✅ 全 5 家 extractor + normalize.py 管線整合（`0a3b588`）
- ✅ E.SUN post-expansion cobranded inference — 避免 general reward expansion 被 RETAIL_CHAIN 阻斷（`dd91685`）
- ✅ 驗證：中友 13號卡友日 `RETAIL_CHAIN:CHUNGYO` + `DAY_OF_MONTH:13`、大江 `RETAIL_CHAIN:METROWALK`，promotion 數量不變（493/357）
- ✅ 157 tests pass

**設計決策**：
- API 端暫不依日期 condition 過濾（先標記，前端顯示，使用者自行判斷）
- `COBRANDED_RETAILER_SIGNALS` 可輕鬆擴充（寶雅、燦坤等）
- E.SUN 因 card name 與 promotion title 分離，需 post-expansion pass；其他 extractor 用 inline pipeline

#### P1：CATALOG_ONLY 降級審查 — 🟡 約 50% 完成

**已完成**：
- ✅ API 端新增 catalog review signals 欄位（`1270f2a`）
- ✅ 前端顯示 catalog review hints + 優惠筆數（`0581117`、`e42c838`）
- ✅ 卡片目錄預設篩選 FREE + GENERAL（`b2f01ed`）
- ✅ P0 修復連帶效果：CATALOG_ONLY 從 195→148（-47），4 張純 CATALOG_ONLY 卡升級為有 RECOMMENDABLE

**待完成（核心審查）**：
- 148 筆 CATALOG_ONLY 逐銀行審查
- 16 張純 CATALOG_ONLY 卡重點審查：
  - CATHAY: FORMOSA
  - CTBC: B_IR、C_CAL、C_CHT、C_HANSHIN、C_SHOWTIME、C_TSDREAMMALL、C_UNIOPEN、C_UPE、C_XUEXUE
  - ESUN: ICASH_CARD、LUNA_PLAZA、NICE_CARD
  - TAISHIN: DUAL_CURRENCY、ROSE、SUN
- 確實需要登錄/plan 切換的優惠維持 CATALOG_ONLY 但補充說明

#### P2：聯名卡通用優惠補全 — ⏳ 未開始

聯名卡除了專屬通路優惠，通常也享有該銀行的通用活動。目前 extractor 只抓了專屬頁面。

- 識別各銀行的「全卡適用」通用活動（如玉山全通路回饋）
- 判斷是否需要為聯名卡補入通用優惠 row
- 評估 extractor 是否需要新增「bank-wide promotion」擷取能力

#### P3：前端體驗配合 — 🟡 約 80% 完成

**已完成**：
- ✅ 卡片目錄顯示 total / recommendable 優惠筆數（`e42c838`）
- ✅ Catalog review + general reward hints 提示（`0581117`）
- ✅ 關鍵篩選器提升至進階區塊上方、預設 free/general（`b2f01ed`）
- ✅ 表單欄位重排 + grouped payment method picker（`8535265`）
- ✅ Condition badge 跨頁面統一色系（`d9f25aa`）
- ✅ 卡片詳情頁銀行主題色 header + color-coded badges（`8f6ab8c`）

**待完成**：
- 推薦結果中標示「此卡僅有通用回饋」（需 P0 泛用回饋標記完成後配合）
- 卡片詳情頁「此卡目前僅擷取到 N 筆優惠」細化提示

### ➡️ 建議接續項目

依優先順序：

1. **Merchant Registry（contracts）**：統一 merchant/retailer 參考資料至 contracts repo JSON，extractor + frontend 引用，取代三處 hardcode（含 Unicard 百大通路）
2. **執行 P1 核心審查**：逐銀行走過 148 筆 CATALOG_ONLY，判斷可提升的優惠（使用 `cardsense-bank-promo-review` skill）
3. **Fubon targeted re-extraction**：補回 INSURANCE/INFINITE/DIGITALLIFE 3 張消失的卡
4. **P2 聯名卡通用優惠**：評估 bank-wide promotion 擷取方案
5. **MILES API 支援**：RewardCalculator 新增哩程回饋計算

### 後續待辦

| 項目 | 說明 | 前置條件 |
|------|------|----------|
| Fubon targeted re-extraction | 補回 INSURANCE/INFINITE/DIGITALLIFE | — |
| `MILES` API 支援 | RewardCalculator 新增哩程回饋計算 | — |
| 日期 condition API 過濾 | DecisionEngine 支援 DAY_OF_MONTH / DAY_OF_WEEK 過濾 | P0.5 ✅ |
| 擴充 COBRANDED_RETAILER_SIGNALS | 寶雅、燦坤、新光三越等聯名卡通路 | P0.5 ✅ |
| Merchant Registry（contracts） | 統一 merchant/retailer 參考資料至 contracts repo JSON，取代三處 hardcode | P0.5 ✅ |
| `stackability` 顯式欄位 | 拆出 SQLite 欄位，取代 `raw_payload_enums` 還原 | — |
| `POINTS` 折現規則 | 銀行別點數折現率（目前各銀行點數價值不同） | — |
| 商業化 | API Key + Rate Limiting、聯盟行銷、Stripe Billing | 資料品質達標 |
| Taxonomy + Merchant DB 化 | category/subcategory/merchant 搬進 Supabase，提供管理後台 | 商業化階段 |
| `/calc` 社群投放 | PTT、Dcard、Facebook 信用卡社團 | 資料品質達標 |
| 新銀行擴充 | MEGA / FIRST / SINOPAC / TPBANK / UBOT | 既有 5 家品質穩定後 |

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
- [API Implementation Checklist](https://github.com/WaddleStudio/cardsense-api/blob/master/IMPLEMENTATION_CHECKLIST.md) — API 待辦與遷移時機

*Last updated: 2026-04-07*

## 備註

- Card catalog 篩選準確度同時依賴 API 端的 eligibility aggregation 和 extractor 端的 promotion eligibility tagging
- 若 benefit-plan 或 eligibility heuristic 有變更，須重跑 `refresh_and_deploy.py` 才會反映到前端
- 部分 `ESUN_UNICARD` 和 `TAISHIN_RICHART` 的 coarse rows（`OTHER + GENERAL`、混合 condition）目前保持保守輸出，待後續決定是否進一步細化
- Benefit-plan 相關的詳細設計與工作流程見：
  - `fleet-command/CardSense-Benefit-Plan-Implementation-Plan.md`
  - `fleet-command/CardSense-Bank-Promo-Review-Workflow.md`
  - `cardsense-extractor/skills/cardsense-bank-promo-review`
