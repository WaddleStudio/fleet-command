# CardSense — 完整專案規格說明書
### Version 1.1 | 2026-03-27

---

## 1. 專案概述

### 1.1 一句話定位
**確定性信用卡推薦平台：將銀行促銷文字轉化為結構化數據，用規則邏輯而非 LLM 產生可審計的刷卡建議，並透過 `/calc` 社群入口把陌生流量導入完整推薦與卡片目錄。**

### 1.2 問題陳述
台灣消費者持有多張信用卡（平均 3-5 張），每張卡在不同通路、時段、門檻有不同回饋。現有比較平台（Money101、卡優）提供的是靜態文章式比較，無法根據用戶「當下消費場景」即時推薦最佳卡片。更大的問題是：銀行優惠經常更新，手動追蹤成本極高。

### 1.3 解決方案
一套三層架構的資料 pipeline + 推薦 API：
1. **Extractor**：半自動從銀行官網抓取優惠文字，用 LLM（離線）轉為結構化資料
2. **Contracts**：定義跨 repo 共用的資料結構和 API 契約
3. **API**：接收消費場景，用確定性規則匹配最佳卡片，回傳可審計的推薦理由
4. **Frontend Surfaces**：用完整推薦頁 `/`、卡片目錄 `/cards`、社群入口 `/calc` 承接 B2C 查詢、瀏覽與傳播

### 1.4 為什麼刻意不用 LLM
| 考量 | 說明 |
|------|------|
| 審計需求 | 金融推薦需可追溯，規則邏輯可 100% 重現 |
| API ToS 風險 | 多數 LLM API 禁止用於金融建議 |
| 延遲 | 規則引擎 < 50ms，LLM 推理 > 500ms |
| 成本 | 規則引擎零額外成本，LLM 按 token 計費 |
| 法規合規 | 確定性輸出更容易向監管機構解釋 |

> LLM 只用在離線的 **extraction pipeline**（文字→結構化資料），不出現在用戶請求路徑。

### 1.5 目標用戶

| 用戶類型 | 角色 | 需求 | 付費意願 |
|---------|------|------|---------|
| **B2B2C：電商與旅行社** | 整合方 | 在結帳頁面嵌入 CardSense Widget 提示最佳結帳卡 | 中（Affiliate Share） |
| **B2C：高階算卡玩家** | 直接用戶 | 精確計算飯店、機票、特定通路疊加後能獲得多少點數/哩程 | 高（高互動） |
| **B2B：記帳軟體** | 整合方 | 嵌入推薦 API，分析用戶開銷並展示「辦這張卡可省多少」 | 高（API 訂閱） |
| **B2C：一般大眾** | 流量方 | 查詢自己錢包裡哪張卡最好 (`My Wallet` 模式) | — (帶流量) |

### 1.6 產品入口與頁面分工

| 路徑/介面 | 角色 | 目標 | 主要依賴 |
|------|------|------|----------|
| `/calc` | 社群計算器 | 針對高消/複雜情境（哩程、保費）提供一鍵分析圖，主打社群分享裂變 | `POST /v1/recommendations/card` |
| 推薦頁匯率牌告板 | RecommendationForm drawer | Trigger button + 右側 drawer 的 dense 匯率板，展示 `POINTS` / `MILES` 區塊；`/calc` 先不接入 | `POST /v1/recommendations/card` |
| 我的卡包 (My Wallet) | 核心依賴轉換 | 把比價轉向「持卡最佳化」，讓用戶只需關心自己的小範圍卡庫 | `POST /v1/recommendations/card` (加卡片過濾) |
| Checkout Widget | B2B2C 獲客點 | 做成供第三方電商結帳頁嵌入的 Snippet，在交易當下提醒省錢 | `POST /v1/recommendations/card` |
| `/cards` 與 `/` | 基礎目錄 (維持堪用) | 滿足基礎查閱與 SEO，不花費過多精力包裝 | `GET /v1/cards` |

> `/calc` 的詳細互動、SEO、分享與元件規格，另見 `fleet-command/CardSense-Demo-Spec.md`，主規格只保留產品定位、KPI 與系統邊界。

---

## 2. 商業模式

### 2.1 營收模型：三軌並行

```
Revenue Streams
│
├── 1️⃣ 嵌入式聯盟導購 (B2B2C Checkout Widget 主力)
│   ├── 在合作品牌結帳頁面攔截精準流量
│   ├── 展示「刷這張立刻省 X 元」
│   └── 若無卡則導向辦理最優卡片，分潤 (CPA)
│
├── 2️⃣ 高階工具與我的卡包 (B2C 附加)
│   ├── My Wallet (我的卡包) 黏著度引流
│   ├── 進階點數估值/哩程兌換規劃
│   └── 產生辦卡「利差」說服辦卡
│
└── 3️⃣ API 訂閱與數據 (中後期)
    ├── Fintech / 記帳 App 介接推薦技術
    ├── 提供 Rate Limit Tier 商業租賃
    └── 匿名化消費趨勢報告
```

### 2.2 關鍵指標

| 指標 | 定義 | Phase 2 目標 |
|------|------|-------------|
| API Calls/Day | 日呼叫量 | 1,000 |
| P50 Latency | 推薦回應時間 | < 100ms |
| Data Freshness | 優惠資料更新延遲 | < 24hr |
| Coverage | 涵蓋的銀行/卡片數 | 10 家銀行 / 50 張卡 |
| B2B Clients | 付費 API 客戶數 | 3 |
| MRR | 月經常性收入 | $200 |

### 2.2.1 B2C 傳播漏斗（`/calc`）

| 指標 | 定義 | Phase 2 目標 |
|------|------|-------------|
| 計算完成率 | `calc_submit / calc_page_view` | > 60% |
| 分享率 | `calc_share / calc_result` | > 10% |
| 跳轉推薦頁率 | `calc_cta_click(recommend) / calc_result` | > 30% |
| 社群來源流量 | 帶 `ref` 參數的 `/calc` page view | 追蹤即可 |

### 2.3 成本結構 (MVP)

| 項目 | 月成本 | 備註 |
|------|--------|------|
| Railway (API hosting) | $5-10 | Spring Boot + PostgreSQL |
| Gemini AI Studio | $0 | 免費額度足夠 extraction |
| 網域 | ~$1 | 年費 $12 |
| Alan 的時間 (8-10hr/week) | — | 主要成本 |
| **Total** | **< $15/mo** | |

### 2.4 商業化里程碑

| 階段 | 時間 | 目標 | Go/No-Go |
|------|------|------|----------|
| Phase 0 (✅完成) | Sprint 0 | 3-repo 架構、contracts 定義 | ✅ |
| Phase 1 (✅完成) | Month 1-2 | 5 大銀行資料、API MVP、極端情境運算上線 | Engine 邏輯重現度達標 |
| Phase 2 (P0)     | Month 3-4 | 上線 My Wallet、MILES 精算、Discord 報錯機制 | 於 PTT/Dcard 產生自發裂變 |
| Phase 3 (P1)     | Month 5-8 | 開發 Checkout Widget，爭取第一家電商/平台嵌入 | 有首發合作夥伴 |
| Phase 4          | Month 9+  | $2K MRR (聯盟行銷與 API 混合)、探索訂閱制 | — |

---

## 3. 系統架構

### 3.1 三 Repo 架構

```
GitHub Organization
│
├── cardsense-contracts
│   ├── src/main/java/com/cardsense/contracts/
│   │   ├── model/          ← 共用資料模型 (Card, Promotion, Recommendation)
│   │   ├── dto/            ← API 請求/回應 DTO
│   │   └── enums/          ← 消費類別、銀行代碼、回饋類型
│   ├── build.gradle.kts
│   └── 發佈到 Maven Local / GitHub Packages
│
├── cardsense-extractor
│   ├── src/main/java/com/cardsense/extractor/
│   │   ├── scraper/        ← 銀行網頁爬蟲 (Jsoup / Playwright)
│   │   ├── parser/         ← LLM 驅動的文字→結構化解析
│   │   ├── validator/      ← 結果驗證 (規則檢查 + 人工抽驗)
│   │   └── loader/         ← 寫入 PostgreSQL
│   ├── 依賴: cardsense-contracts
│   └── 排程: 每日 / 銀行公告觸發
│
└── cardsense-api
    ├── src/main/java/com/cardsense/api/
    │   ├── controller/     ← REST endpoints
    │   ├── service/        ← 推薦邏輯（確定性規則引擎）
    │   ├── repository/     ← Spring Data JPA
    │   ├── security/       ← JWT + API Key 驗證
    │   └── config/         ← RBAC, Rate Limiting
    ├── 依賴: cardsense-contracts
    └── 部署: Railway
```

### 3.1.1 Frontend Delivery Surface

- `cardsense-web` 作為獨立前端 repo，承接 `/`、`/cards`、`/calc` 三個主要路由。
- `/calc` 明確不新增 API endpoint、不新增資料庫表，僅重用既有 `GET /v1/cards` 與 `POST /v1/recommendations/card`；推薦頁匯率牌告板則留在 `RecommendationForm` drawer。
- `/calc` 的年度損失、分享圖片、CTA 導流與追蹤埋點皆屬前端責任，不改動 contracts 或 extractor 邊界。

### 3.2 資料流

```
                    離線 Pipeline (每日)
                    ┌─────────────────────────────────────┐
                    │                                     │
 銀行官網 ─── 爬蟲 ─┤─── Gemini Flash ─── 結構化 JSON    │
 (HTML)    (Jsoup/  │   (促銷文字解析)   (Promotion DTO) │
            PW)     │                                     │
                    │─── Validator ─── PostgreSQL          │
                    │   (規則檢查)    (promotions 表)      │
                    └─────────────────────────────────────┘

                    線上 API (即時)
                    ┌─────────────────────────────────────┐
 用戶請求 ──────────┤                                     │
 {                  │  API Key 驗證                       │
   category: "餐飲", │       │                             │
   amount: 1200,    │  規則引擎 (確定性)                   │
   cards: ["中信", │       │                             │
           "玉山"]  │  排序 + 推薦理由                    │
 }                  │       │                             │
                    │  回應 (< 50ms)                      │
 ◄──────────────────┤  {                                  │
                    │    best_card: "中信",                │
                    │    cashback: "3%",                   │
                    │    reason: "餐飲類 3% 回饋...",      │
                    │    promotion_id: "promo_123",        │
                    │    valid_until: "2026-03-31",        │
                    │    audit_trail: {...}                │
                    │  }                                   │
                    └─────────────────────────────────────┘
```

### 3.3 技術選型

| 層 | 選擇 | 理由 |
|----|------|------|
| 語言 | Java 21 | 金融場景慣例、型別安全、生態成熟 |
| 框架 | Spring Boot 4 | 企業級穩定性、Security + JPA 內建 |
| DB | PostgreSQL (Supabase) | JSONB 存促銷結構、版本化、免費起步 |
| ORM | Spring Data JPA | 與 Spring 生態深度整合 |
| 爬蟲 | Jsoup + Playwright (備) | Jsoup 處理靜態頁、Playwright 處理 SPA |
| LLM (離線) | Gemini Flash (AI Studio) | 免費額度、結構化輸出能力強 |
| LLM (備選) | Mistral OCR 3 | 銀行 PDF 文件解析 |
| API 認證 | JWT + API Key | B2B 用 API Key、B2C 用 JWT |
| 部署 | Railway | Spring Boot 友好、PostgreSQL addon |
| CI/CD | GitHub Actions | 三 repo 統一 pipeline |

---

## 4. 資料模型

### 4.1 核心 Entity

```sql
-- 銀行
CREATE TABLE banks (
    id          UUID PRIMARY KEY,
    code        VARCHAR(10) UNIQUE NOT NULL,  -- "CTBC", "ESUN", "TAISHIN"
    name_zh     VARCHAR(50) NOT NULL,         -- "中國信託"
    name_en     VARCHAR(50),
    website     VARCHAR(255),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 信用卡
CREATE TABLE cards (
    id          UUID PRIMARY KEY,
    bank_id     UUID REFERENCES banks(id),
    name        VARCHAR(100) NOT NULL,        -- "中信 LINE Pay 卡"
    card_type   VARCHAR(20) NOT NULL,         -- VISA, MASTERCARD, JCB
    annual_fee  INTEGER DEFAULT 0,            -- 年費 (TWD)
    apply_url   VARCHAR(500),                 -- 聯盟行銷連結
    status      VARCHAR(20) DEFAULT 'ACTIVE', -- ACTIVE, DISCONTINUED
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 優惠活動（核心資料）
CREATE TABLE promotions (
    id              UUID PRIMARY KEY,
    card_id         UUID REFERENCES cards(id),
    version         INTEGER NOT NULL DEFAULT 1,  -- 資料版本（每次更新 +1）
    title           VARCHAR(200) NOT NULL,
    category        VARCHAR(50) NOT NULL,         -- DINING, TRANSPORT, ONLINE, OVERSEAS...
    cashback_type   VARCHAR(20) NOT NULL,         -- PERCENT, FIXED, POINTS
    cashback_value  DECIMAL(5,2) NOT NULL,        -- 3.00 = 3%
    min_amount      INTEGER DEFAULT 0,            -- 最低消費門檻 (TWD)
    max_cashback    INTEGER,                      -- 回饋上限 (TWD)
    valid_from      DATE NOT NULL,
    valid_until     DATE NOT NULL,
    conditions      JSONB,                        -- 額外條件 (結構化)
    source_url      VARCHAR(500),                 -- 原始來源頁面
    source_text     TEXT,                         -- 原始促銷文字（可審計）
    extraction_model VARCHAR(50),                 -- "gemini-flash-2.0"
    extraction_at   TIMESTAMPTZ,
    verified        BOOLEAN DEFAULT FALSE,        -- 人工驗證過
    status          VARCHAR(20) DEFAULT 'ACTIVE',
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(card_id, category, valid_from, version)
);

-- API 呼叫記錄（計費 + 分析）
CREATE TABLE api_calls (
    id          UUID PRIMARY KEY,
    client_id   UUID NOT NULL,               -- API Key 對應的客戶
    endpoint    VARCHAR(100) NOT NULL,
    request     JSONB NOT NULL,
    response    JSONB NOT NULL,
    latency_ms  INTEGER NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- API 客戶
CREATE TABLE clients (
    id          UUID PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    api_key     VARCHAR(64) UNIQUE NOT NULL,
    plan        VARCHAR(20) DEFAULT 'FREE',  -- FREE, STARTER, GROWTH, ENTERPRISE
    daily_limit INTEGER DEFAULT 100,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### 4.2 核心 API Contract

```java
// === Request ===
public record RecommendationRequest(
    String category,        // "DINING", "TRANSPORT", "ONLINE"...
    Integer amount,         // 消費金額 (TWD)
    List<String> cardCodes, // 用戶持有的卡片代碼 (optional, 空 = 全部)
    String location,        // 消費地點 (optional)
    LocalDate date,         // 消費日期 (optional, default = today)
    Map<String, BigDecimal> customExchangeRates // 用戶自訂匯率 (optional, 可覆寫系統預設哩程與點數估值)
) {}

// === Response ===
public record RecommendationResponse(
    String requestId,
    List<CardRecommendation> recommendations,
    LocalDateTime generatedAt
) {}

public record CardRecommendation(
    String cardName,
    String bankName,
    String cashbackType,      // "PERCENT", "FIXED", "POINTS"
    BigDecimal cashbackValue, // 3.00 = 3%
    Integer estimatedReturn,  // 預估回饋金額 (TWD)
    String reason,            // 人可讀推薦理由
    String promotionId,       // 可追溯到 promotions 表
    LocalDate validUntil,
    List<String> conditions,  // 需注意的條件
    String applyUrl           // 聯盟行銷連結 (optional)
) {}
```

### 4.3 推薦規則引擎（確定性邏輯）

```java
// 虛擬碼 — 推薦排序邏輯
public List<CardRecommendation> recommend(RecommendationRequest req) {
    
    // 1. 篩選：找出符合條件的優惠
    List<Promotion> eligible = promotionRepo.findActive(
        category = req.category(),
        date = req.date(),
        minAmount <= req.amount()
    );
    
    // 2. 過濾：只保留用戶持有的卡
    if (req.cardCodes() != null && !req.cardCodes().isEmpty()) {
        eligible = eligible.stream()
            .filter(p -> req.cardCodes().contains(p.card().code()))
            .toList();
    }
    
    // 3. 計算：估算每張卡的實際回饋
    List<ScoredPromotion> scored = eligible.stream()
        .map(p -> new ScoredPromotion(
            promotion = p,
            estimatedReturn = calculateReturn(p, req.amount()),
            // 回饋上限封頂
            cappedReturn = Math.min(
                calculateReturn(p, req.amount()),
                p.maxCashback() != null ? p.maxCashback() : Integer.MAX_VALUE
            )
        ))
        .toList();
    
    // 4. 排序：確定性排序規則
    scored.sort(Comparator
        .comparing(ScoredPromotion::cappedReturn).reversed() // 回饋金額最高
        .thenComparing(s -> s.promotion().validUntil())      // 快到期的優先
        .thenComparing(s -> s.promotion().card().annualFee()) // 年費低的優先
    );
    
    // 5. 轉換：生成推薦結果 + 可審計理由
    return scored.stream()
        .limit(5)
        .map(this::toRecommendation)
        .toList();
}
```

### 4.4 即時匯率與價值轉換引擎 (Exchange Rate Engine)

這是 CardSense 的差異化核心之一。它解決的是：「同一張卡的回饋，對不同使用者到底值多少？」以及「點數 / 哩程如何在推薦演算法中被正確量化？」的問題。

目前實作已落地到推薦頁的 trigger button + 右側 drawer 匯率牌告板，板內分成 `POINTS` / `MILES` 兩個 section；`/calc` 整合仍保留在後續迭代。

**玩家自訂匯率 (Custom Rates)**：玩家可透過前端 UI 輸入自己心目中的點數/哩程價值（例如：「我覺得長榮哩程值 0.6 元」）。API 在 `RecommendationRequest` 中接收 `customExchangeRates` 後，會覆寫系統預設值，使排名演算法依照玩家的個人價值觀重新洗牌。

**前端互動現況**：
- `RecommendationForm` 已使用 trigger button 開啟右側 drawer，先展示 dense 匯率牌告板。
- 牌告板以 `POINTS` / `MILES` 分 section 顯示，板面目前以 `unit`、`note` 與估值輸入為主。
- `/calc` 仍保留為下一階段的共用入口，分享圖與更細的 program-level explainability 尚待補強。

```text
使用者心中匯率不同 -> 排名不同

玩家 A（常換頭等艙）：1 哩 = 0.6 TWD -> 哩程卡排名上升
玩家 B（只換經濟艙）：1 哩 = 0.3 TWD -> 現金回饋卡排名上升
```

**後續 UI 方向**：
- 推薦頁與 `/calc` 應逐步收斂為 calculator 風格的「匯率牌告板」密集列表，而非跑馬燈。
- 匯率板以上方基準列 + 下方估值列表呈現，左側為銀行 / 計畫 badge，中段為大數字估值，右側為狀態與估值輸入。
- `/calc` 仍提供自訂點數價值能力，但視覺定位應從「進階設定折疊面板」提升為「專業估值工具面板」。
- 推薦結果的 `estimatedReturn` 統一以 TWD 呈現，並附註所使用的匯率。

### 5.1 LLM 使用邊界

```
┌──────────────────────────────────────────┐
│           CardSense LLM 使用邊界          │
│                                          │
│   ✅ 允許 (離線 pipeline)                │
│   ┌────────────────────────────────┐     │
│   │ 銀行促銷文字 → 結構化 JSON      │     │
│   │ 銀行 PDF → OCR → 結構化        │     │
│   │ 新卡片資訊解析                  │     │
│   └────────────────────────────────┘     │
│                                          │
│   ❌ 禁止 (線上 API)                     │
│   ┌────────────────────────────────┐     │
│   │ 推薦邏輯                       │     │
│   │ 排序決策                       │     │
│   │ 推薦理由生成                   │     │
│   │ 任何面向用戶的輸出             │     │
│   └────────────────────────────────┘     │
└──────────────────────────────────────────┘
```

### 5.2 Extraction Pipeline LLM 選型

| 模型 | 用途 | 成本 | 備註 |
|------|------|------|------|
| Gemini Flash (AI Studio) | 主力：促銷文字→JSON | $0 (免費額度) | 結構化輸出能力強 |
| Mistral OCR 3 | 備選：銀行 PDF 解析 | API 計費 | PDF/圖片場景 |
| Gemini Pro (手動) | 備選：複雜條件解析 | $0 (已有訂閱) | 困難案例降級處理 |

### 5.3 Extraction Prompt 範例

```
你是信用卡優惠數據解析器。請將以下銀行促銷文字轉為 JSON。

規則：
1. 嚴格按照 schema，不要加入未明確提到的資訊
2. 不確定的欄位填 null
3. cashback_value 統一為百分比 (3% = 3.00)
4. 日期格式 YYYY-MM-DD
5. category 只能是: DINING, TRANSPORT, ONLINE, OVERSEAS, SHOPPING, GROCERY, ENTERTAINMENT, OTHER

Schema:
{
  "card_name": string,
  "bank_code": string,
  "promotions": [{
    "category": string,
    "cashback_type": "PERCENT" | "FIXED" | "POINTS",
    "cashback_value": number,
    "min_amount": number | null,
    "max_cashback": number | null,
    "valid_from": string,
    "valid_until": string,
    "conditions": [string]
  }]
}

促銷文字:
---
{raw_text}
---
```

---

## 6. OpenClaw Agent 設計

### 6.1 CardSense Agents (Phase 3)

| Agent | 觸發 | 功能 | LLM |
|-------|------|------|-----|
| **PromoWatcher** | 每日 cron 08:00 | 爬取銀行優惠頁，偵測變動 | GPT-5.3 (via OpenClaw) |
| **DataExtractor** | PromoWatcher 觸發 | 新優惠文字 → Extraction Pipeline | Gemini Flash (API) |

### 6.2 Agent 流程

```
PromoWatcher (每日)
│
├── 爬取 10 家銀行優惠頁
├── Hash 比對，偵測內容變動
├── 有變動 → 寫入 Notion「待解析」
├── 無變動 → 靜默
└── 高優先變動 → Discord #cardsense-alerts

DataExtractor (事件觸發)
│
├── 從 Notion 讀取「待解析」項目
├── 呼叫 Gemini Flash extraction
├── 驗證 JSON schema
├── 寫入 PostgreSQL (status = unverified)
├── 更新 Notion status = "extracted"
└── Discord @Alan「新優惠已解析，請人工驗證」
```

---

## 7. 跨專案整合點

| 對象 | 整合方式 | 階段 | 價值 |
|------|---------|------|------|
| **小決定** | 小決定推薦餐廳 → 呼叫 CardSense API → 最佳刷卡建議 | Phase 2 | 最高 |
| **冰箱管理** | 超市採購 → CardSense API → 最優超市卡 | Phase 3 | 中 |
| **RTA** | 間接：評論可信度 + 最佳付款方式 = 完整決策 | Phase 3 | 低 |
| **TechTrend** | NB4 追蹤信用卡市場動態、聯盟行銷趨勢 | 持續 | 情報 |

---

## 8. 版權與法律

### 8.1 風險矩陣

| 風險 | 等級 | 緩解措施 |
|------|------|---------|
| **金融資訊提供是否需要特殊許可** | 🔴 高 | 需諮詢律師；CardSense 提供的是「資料比較」非「投資建議」，但界線模糊 |
| **銀行資料爬取合法性** | 🟡 中 | 只爬公開頁面、遵守 robots.txt、不高頻請求 |
| **LLM 解析的資料準確性** | 🟡 中 | 人工驗證 + version 控制 + 錯誤可回溯 |
| **聯盟行銷揭露義務** | 🟢 低 | API 回應中明確標記 affiliate link |
| **PDPA 個資保護** | 🟡 中 | API 不收集用戶個資；api_calls 表不存用戶識別資訊 |

### 8.2 免責聲明（必須加入）

所有 API 回應和 B2C 頁面必須包含：
> 「CardSense 提供信用卡優惠比較資訊，不構成金融建議。實際回饋依各銀行公告為準，請以銀行官網資訊為最終依據。」

### 8.3 合規待辦

- [ ] 諮詢律師：「信用卡比較推薦」是否屬於金融業務需特許
- [ ] 確認各銀行官網 ToS 是否禁止爬取
- [ ] PDPA 合規：API 呼叫記錄的保存和刪除政策
- [ ] 聯盟行銷揭露標準（FTC 台灣等效規範）

---

## 9. 成功標準與退出條件

| 階段 | 成功條件 | 退出條件 |
|------|---------|---------|
| Phase 1 | 5 家銀行支援 / 穩定 API (< 100ms) / 疊加正確 | Extraction 準確率長期落後無法收斂 |
| Phase 2 | /calc 成功在特定社群產生討論與分享案例 | 上線 My Wallet 無法提升用戶回訪與依賴 |
| Phase 3 | 成功談成至少一家 Widget 平台合作 | 轉換率過低，或無法透過導流拿到 CPA |
| Phase 4 | 穩定產生 $2K 收入 (首刷分潤與 API 訂閱) | 連續 3 個月下滑或停滯 |

### 每周時間投入
- 目標：**8-10 hr/week**（所有專案中最高）
- 不可低於 6 hr/week

---

## 10. 下一步行動 (Sprint 1)

```
Sprint 1 目標：5 家銀行資料 + API 可呼叫

Week 1-2:
  □ cardsense-contracts: 確定 Promotion / Card / Bank 的 Java record 定義
  □ cardsense-api: Spring Boot 骨架 + PostgreSQL 連接 + health check
  □ cardsense-api: /recommend endpoint (硬編碼 3 張卡測試)

Week 3-4:
  □ cardsense-extractor: 選定第一家銀行 (建議中信，優惠最多)
  □ cardsense-extractor: Jsoup 爬蟲 + Gemini Flash extraction
  □ cardsense-extractor: 人工驗證第一批資料

Week 5-6:
  □ 擴展到 5 家銀行
  □ cardsense-api: 接上真實資料
  □ cardsense-api: API Key 認證 + rate limiting
  □ 部署到 Railway

Sprint 1 交付物:
  ✅ 5 家銀行的結構化優惠資料 (PostgreSQL)
  ✅ /recommend API endpoint (< 100ms)
  ✅ API Key 認證
  ✅ Railway 部署 + health monitoring
```

---

*Owner: Alan | Created: 2026-02-25 | Priority: 🔴 最高 | Next: Sprint 1 Week 1*
