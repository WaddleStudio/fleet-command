# CardSense Demo 頁面規格書 — `/calc`
### Version 1.0 | 2026-03-27
### 併入 cardsense-web 專案

---

## 1. 定位與目標

### 1.1 一句話定位

**社群傳播入口頁：用「刷錯卡的年度損失」製造痛感，將陌生流量導入現有推薦功能。**

### 1.2 與現有頁面的關係

```
/calc（本頁）              /（現有推薦頁）            /cards（現有卡片目錄）
┌──────────────┐          ┌──────────────┐          ┌──────────────┐
│  傳播入口     │ ──CTA──▶ │  完整推薦工具  │          │  100 張卡目錄  │
│  極簡互動     │          │  416 優惠比較  │          │  銀行篩選     │
│  痛感數字     │          │  詳細條件     │          │  申辦連結     │
│  分享按鈕     │          │  申辦連結     │          │              │
└──────────────┘          └──────────────┘          └──────────────┘
  目標：讓人點進來            目標：讓人做決策            目標：讓人瀏覽比較
  KPI：分享率、跳轉率        KPI：查詢次數              KPI：申辦點擊率
```

### 1.3 不做什麼

- 不重複現有推薦頁的完整功能（不顯示優惠明細、條件、頻率限制等）
- 不需要登入或帳號
- 不新增 API endpoint（直接呼叫現有 `/v1/recommendations/card`）
- 不新增資料庫表

---

## 2. 使用者流程

### 2.1 完整 flow

```
1. 用戶從社群連結進入 /calc
2. 看到標題「刷錯卡，你虧了多少？」
3. 輸入消費金額（預設 $1,200）
4. 選擇消費類別（餐飲/網購/超市/交通/海外/百貨/串流/其他）
5. 勾選持有的卡片（從 /v1/cards 動態載入，預設勾選前 4 張熱門卡）
6. 按下「算出我的損失」
7. 呼叫現有 API，取得推薦排名
8. 顯示結果：
   a. 回饋排名 bar chart（最佳=綠、最差=紅）
   b. 最佳 vs 最差卡片對比 + 金額差
   c. 年度累計損失（動畫計數器）
   d. 分享按鈕（生成結果圖片）
9. CTA 導向：
   a.「查看完整推薦 →」跳轉 /（帶入當前 amount + category 作為 query params）
   b.「瀏覽所有卡片 →」跳轉 /cards
```

### 2.2 社群分享 flow

```
結果頁底部「分享我的結果」
  → 前端用 html2canvas 生成結果圖片（含金額、最佳卡名、CardSense logo）
  → navigator.share() 或 fallback 到複製連結
  → 分享出去的 URL: cardsense-web.vercel.app/calc
  → og:image 用預設靜態圖（「台灣人平均每年刷錯卡損失 NT$____」）
```

---

## 3. 技術規格

### 3.1 路由與檔案結構

```
cardsense-web/
└── app/
    └── calc/
        ├── page.tsx              ← 主頁面
        ├── components/
        │   ├── AmountInput.tsx    ← 金額輸入 + 快速按鈕
        │   ├── CategoryGrid.tsx   ← 消費類別選擇
        │   ├── CardSelector.tsx   ← 卡片勾選（從 API 動態載入）
        │   ├── ResultPanel.tsx    ← 結果區塊（含 bar chart + 對比 + 年度損失）
        │   ├── AnnualLossBox.tsx  ← 年度損失動畫計數器
        │   ├── ShareButton.tsx    ← 分享功能
        │   └── CtaStrip.tsx       ← 底部 CTA
        ├── lib/
        │   ├── calcApi.ts         ← API 呼叫封裝
        │   └── shareImage.ts      ← 分享圖片生成
        └── opengraph-image.tsx    ← OG image（Next.js App Router 內建）
```

### 3.2 API 整合

不新增任何 API，直接呼叫現有 endpoint：

```typescript
// calcApi.ts

// 1. 載入可選卡片清單（頁面初始化時）
async function fetchCards(): Promise<Card[]> {
  const res = await fetch('/v1/cards');
  return res.json();
  // 回傳所有 100 張卡，前端依銀行分組顯示
}

// 2. 取得推薦結果（用戶按下計算時）
async function fetchRecommendation(params: {
  amount: number;
  category: string;      // 對應現有 API 的 category enum
  cardCodes: string[];   // 用戶勾選的卡片 codes
}): Promise<RecommendationResponse> {
  const res = await fetch('/v1/recommendations/card', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      amount: params.amount,
      category: params.category,
      cardCodes: params.cardCodes,
      compareMode: 'BEST_SINGLE',  // 用單一最佳優惠模式
    }),
  });
  return res.json();
}
```

### 3.3 推薦結果轉換邏輯

現有 API 回傳的是推薦排名，`/calc` 頁面需要做以下前端計算：

```typescript
// ResultPanel.tsx 內部邏輯

interface CalcResult {
  ranked: CardResult[];       // 依回饋金額排序
  best: CardResult;           // ranked[0]
  worst: CardResult;          // ranked[ranked.length - 1]
  singleDiff: number;         // best.estimatedReturn - worst.estimatedReturn
  annualLoss: number;         // singleDiff * 12
}

function processResult(
  recommendations: RecommendationResponse,
  amount: number
): CalcResult {
  // API 回傳的 recommendations 已按推薦排序
  const ranked = recommendations.map(rec => ({
    cardName: rec.cardName,
    bankName: rec.bankName,
    rate: rec.cashbackValue,        // e.g. 3.00 = 3%
    estimatedReturn: rec.estimatedReturn, // API 已算好的回饋金額
  }));

  const best = ranked[0];
  const worst = ranked[ranked.length - 1];
  const singleDiff = best.estimatedReturn - worst.estimatedReturn;

  return {
    ranked,
    best,
    worst,
    singleDiff,
    annualLoss: singleDiff * 12,  // 假設每月相同消費
  };
}
```

### 3.4 元件規格

#### AmountInput

| 屬性 | 規格 |
|------|------|
| 預設值 | 1,200 |
| 快速按鈕 | 500 / 1,000 / 3,000 / 5,000（沿用現有推薦頁設計） |
| 最小值 | 100 |
| 最大值 | 100,000 |
| 驗證 | 必填，正整數 |

#### CategoryGrid

| 屬性 | 規格 |
|------|------|
| 選項 | 餐飲 / 網購 / 超市 / 交通 / 海外 / 百貨 / 串流 / 其他 |
| 預設選取 | 餐飲 |
| 佈局 | 4 欄 grid（與現有推薦頁一致） |
| 對應 API enum | DINING / ONLINE / GROCERY / TRANSPORT / OVERSEAS / SHOPPING / STREAMING / OTHER |

#### CardSelector

| 屬性 | 規格 |
|------|------|
| 資料來源 | `GET /v1/cards` 動態載入 |
| 顯示方式 | 依銀行分組，checkbox 勾選 |
| 預設勾選 | 前 4 張最熱門卡（或無預設，讓用戶自選） |
| 最少勾選 | 2 張（否則無法比較） |
| 搜尋 | 可選：輸入框篩選卡名或銀行 |
| 佈局 | 2 欄 grid，每項顯示：卡名 + 銀行名 |

#### ResultPanel

| 區塊 | 內容 |
|------|------|
| 回饋排名 bar chart | 水平柱狀圖，依回饋金額排序，最佳=綠色 (#1D9E75)、最差=紅色 (#E24B4A)、其餘=灰色 |
| 最佳 vs 最差對比 | 左：最佳卡名 + 回饋金額（綠色）；右：差額（紅色） |
| 年度損失框 | 紅色邊框，內含動畫計數器（從 0 滾到最終數字） |
| 說明文字 | 「假設每月在「{category}」消費 ${amount}，用 {worst} 代替 {best}，一年少拿 ${annualLoss} 回饋。」 |

#### AnnualLossBox

```typescript
// 動畫計數器規格
const ANIMATION_DURATION = 800; // ms
const FRAME_INTERVAL = 20;     // ms

function AnimatedCounter({ target }: { target: number }) {
  const [current, setCurrent] = useState(0);

  useEffect(() => {
    const step = Math.max(1, Math.floor(target / (ANIMATION_DURATION / FRAME_INTERVAL)));
    const timer = setInterval(() => {
      setCurrent(prev => {
        const next = Math.min(prev + step, target);
        if (next >= target) clearInterval(timer);
        return next;
      });
    }, FRAME_INTERVAL);
    return () => clearInterval(timer);
  }, [target]);

  return <span>${current.toLocaleString()}</span>;
}
```

#### ShareButton

```typescript
// 分享圖片生成規格
interface ShareImageData {
  annualLoss: number;
  bestCardName: string;
  worstCardName: string;
  category: string;
  amount: number;
}

// 方案 1：html2canvas 截圖 ResultPanel
// 方案 2：Canvas API 手繪（更可控，建議採用）

// 分享行為
async function handleShare(data: ShareImageData) {
  const canvas = generateShareImage(data);
  const blob = await canvas.toBlob('image/png');

  if (navigator.share && navigator.canShare({ files: [new File([blob], 'cardsense.png')] })) {
    // Mobile: 原生分享（LINE、IG Story 等）
    await navigator.share({
      title: '刷錯卡虧多少？',
      text: `我每年因為刷錯卡少了 NT$${data.annualLoss.toLocaleString()} 😱`,
      files: [new File([blob], 'cardsense.png', { type: 'image/png' })],
      url: 'https://cardsense-web.vercel.app/calc',
    });
  } else {
    // Desktop: 下載圖片 + 複製連結
    downloadImage(blob, 'cardsense-result.png');
    await navigator.clipboard.writeText('https://cardsense-web.vercel.app/calc');
  }
}
```

#### CtaStrip

| CTA | 目標 | URL |
|-----|------|-----|
| 「查看完整推薦細節 →」 | 跳轉推薦頁，帶入參數 | `/?amount={amount}&category={category}` |
| 「瀏覽 100 張信用卡 →」 | 跳轉卡片目錄 | `/cards` |
| 「開發者？整合 CardSense API →」 | 外部連結（Phase 2） | API 文件 URL |

---

## 4. 設計規格

### 4.1 視覺一致性

從現有頁面截圖提取的設計 token：

```css
/* 沿用現有 cardsense-web 設計系統 */

/* 色彩 */
--cs-navy: #1e3a5f;           /* navbar 背景 */
--cs-navy-light: #2a4a72;     /* navbar hover */
--cs-primary-btn: #2563eb;    /* 「推薦」按鈕 active */
--cs-primary-btn-dark: #1e3a5f; /* 「卡片目錄」按鈕 active */
--cs-green-badge: #16a34a;    /* 「最佳推薦」「發行中」badge */
--cs-green-text: #15803d;     /* 「免年費」「前往申辦」文字 */
--cs-teal-badge: #0d9488;     /* 「有效至」badge */
--cs-red-badge: #dc2626;      /* 「發行中」紅色 badge */
--cs-border: #e5e7eb;         /* 卡片邊框 */
--cs-bg: #f9fafb;             /* 頁面背景 */
--cs-surface: #ffffff;        /* 卡片表面 */
--cs-text: #111827;           /* 主文字 */
--cs-text-muted: #6b7280;     /* 副文字 */
--cs-text-link: #1e3a5f;      /* 連結文字 */

/* Demo 頁專用（新增） */
--cs-loss-red: #dc2626;       /* 損失金額 */
--cs-win-green: #16a34a;      /* 最佳回饋金額 */

/* 圓角 */
--cs-radius-sm: 6px;          /* 快速按鈕、badge */
--cs-radius-md: 8px;          /* 輸入框、小卡片 */
--cs-radius-lg: 12px;         /* 大卡片容器 */

/* 字型 */
font-family: 系統字型（與現有一致）;
/* 金額數字建議用 tabular-nums 或 monospace 以對齊 */
```

### 4.2 頁面 layout

```
┌─────────────────────────────────────────────────┐
│  CardSense Navbar（共用，加入 /calc 導航項）      │
│  [✨ 推薦]  [卡片目錄]  [🧮 計算機]  [🌙] [連線] │
├─────────────────────────────────────────────────┤
│                                                  │
│  刷錯卡，你虧了多少？                             │
│  輸入一筆消費，看看你的卡片回饋差多少。             │
│                                                  │
│  ┌──────────────────┐  ┌──────────────────────┐  │
│  │  消費情境         │  │  計算結果             │  │
│  │                  │  │                      │  │
│  │  金額 [$1,200]   │  │  （按下計算後顯示）    │  │
│  │  [500][1K][3K][5K]│  │                      │  │
│  │                  │  │  回饋排名 bar chart   │  │
│  │  類別             │  │  ████████ $36  3%    │  │
│  │  [餐飲][網購]     │  │  ██████   $24  2%    │  │
│  │  [超市][交通]     │  │  ████     $12  1%    │  │
│  │  [海外][百貨]     │  │                      │  │
│  │  [串流][其他]     │  │  ─────────────────   │  │
│  │                  │  │  最佳：XX卡  +$36    │  │
│  │  持有卡片         │  │  最差：YY卡  -$24    │  │
│  │  ☑ 中信 LINE Pay │  │                      │  │
│  │  ☑ 玉山 Only     │  │  ┌─ 年度累計損失 ──┐  │  │
│  │  ☑ 國泰 CUBE     │  │  │  $3,456         │  │  │
│  │  ☐ 台新 FlyGo    │  │  │  每月省 $288... │  │  │
│  │                  │  │  └────────────────┘  │  │
│  │  [算出我的損失]   │  │                      │  │
│  │                  │  │  [分享我的結果]       │  │
│  └──────────────────┘  │  [查看完整推薦 →]     │  │
│                        │  [瀏覽 100 張卡 →]    │  │
│                        └──────────────────────┘  │
│                                                  │
├─────────────────────────────────────────────────┤
│  Footer（如有）                                  │
└─────────────────────────────────────────────────┘

RWD：
  Desktop (>768px)：左右雙欄（同現有推薦頁 layout）
  Mobile (<768px)：單欄，結果區在輸入區下方
```

### 4.3 navbar 修改

現有 navbar 有兩個按鈕：「推薦」「卡片目錄」。新增第三個：

```typescript
// 新增導航項
{ label: '計算機', href: '/calc', icon: Calculator }

// 排序：推薦 | 卡片目錄 | 計算機
// active 狀態樣式與現有一致（深色背景 + 白字）
```

### 4.4 動畫規格

| 元素 | 動畫 | 時長 | Easing |
|------|------|------|--------|
| 結果面板出現 | fadeUp (opacity 0→1, translateY 12→0) | 400ms | ease-out |
| Bar chart 柱狀 | width 0→target% | 600ms | ease-out, staggered 80ms |
| 年度損失數字 | counter 0→target | 800ms | linear (frame-based) |
| 結果區 scroll | scrollIntoView smooth | browser default | — |

---

## 5. SEO / OG Meta

### 5.1 Meta Tags

```html
<title>刷錯卡虧多少？信用卡回饋計算機 | CardSense</title>
<meta name="description" content="輸入消費金額和持有卡片，即時算出你每年因為刷錯卡少拿多少回饋。支援台灣 100 張信用卡、416 個優惠比較。" />
<meta name="keywords" content="信用卡比較,信用卡回饋,現金回饋,刷卡推薦,台灣信用卡" />
```

### 5.2 OG Tags

```html
<meta property="og:title" content="刷錯卡，你每年虧了多少？" />
<meta property="og:description" content="台灣人平均持有 3-5 張信用卡，但 80% 的人不知道每次該刷哪張。3 秒算出你的年度損失。" />
<meta property="og:image" content="/calc/og-image.png" />
<meta property="og:url" content="https://cardsense-web.vercel.app/calc" />
<meta property="og:type" content="website" />
```

### 5.3 OG Image 規格

```
尺寸：1200 × 630 px
背景：白色
內容：
  左側：CardSense logo + 「刷錯卡，你每年虧了多少？」
  右側：模擬的年度損失數字（紅色大字，如 NT$4,320）
  底部：「cardsense-web.vercel.app/calc」
用 Next.js App Router 的 opengraph-image.tsx 動態生成，
或放一張靜態 PNG 在 /public/calc/
```

---

## 6. 投放與追蹤

### 6.1 投放渠道

| 渠道 | 貼文格式 | URL |
|------|---------|-----|
| PTT creditcard 版 | 「我做了一個信用卡回饋計算機，歡迎試用」 | cardsense-web.vercel.app/calc?ref=ptt |
| Dcard 理財版 | 「你知道每年刷錯卡虧多少嗎？」 | cardsense-web.vercel.app/calc?ref=dcard |
| Facebook 信用卡社團 | 圖文貼（結果截圖 + 連結） | cardsense-web.vercel.app/calc?ref=fb |
| LINE 群組分享 | 分享按鈕產出的圖片 + 連結 | cardsense-web.vercel.app/calc |

### 6.2 追蹤埋點

```typescript
// 用現有 analytics 工具（PostHog 或 Vercel Analytics）

// 頁面載入
track('calc_page_view', { ref: searchParams.ref });

// 計算按鈕
track('calc_submit', {
  amount: number,
  category: string,
  cardCount: number,      // 勾選幾張卡
});

// 結果展示
track('calc_result', {
  annualLoss: number,
  bestCard: string,
  worstCard: string,
});

// 分享按鈕
track('calc_share', { method: 'native' | 'clipboard' | 'download' });

// CTA 跳轉
track('calc_cta_click', { target: 'recommend' | 'cards' | 'api_docs' });
```

### 6.3 成功指標

| 指標 | 定義 | 目標 |
|------|------|------|
| 計算完成率 | calc_submit / calc_page_view | > 60% |
| 分享率 | calc_share / calc_result | > 10% |
| 跳轉推薦頁率 | calc_cta_click(recommend) / calc_result | > 30% |
| 社群來源流量 | calc_page_view with ref param | 追蹤即可 |

---

## 7. 實作優先級

### Sprint 0（2-3 小時）— 核心功能

```
□ 建立 /app/calc/page.tsx 基本結構
□ AmountInput + CategoryGrid（沿用現有推薦頁的 UI 元件）
□ CardSelector（呼叫 /v1/cards，checkbox 列表）
□ 呼叫現有 /v1/recommendations/card API
□ ResultPanel 靜態版（不含動畫）
□ navbar 加入「計算機」按鈕
```

### Sprint 1（2-3 小時）— 傳播力

```
□ AnnualLossBox 動畫計數器
□ Bar chart 動畫
□ ShareButton（html2canvas + navigator.share）
□ OG meta tags + 靜態 OG image
□ CTA 跳轉帶入 query params
□ 追蹤埋點
```

### Sprint 2（1-2 小時）— 優化

```
□ RWD 測試 + 修正
□ 分享圖片品質調整
□ Dark mode 相容（跟隨現有 dark mode toggle）
□ 第一批社群投放
```

### 不做（Out of Scope）

```
✗ 用戶帳號 / 登入
✗ 新增 API endpoint
✗ 歷史查詢紀錄
✗ 個人化推薦（那是現有推薦頁的事）
✗ 聯盟行銷連結（Phase 3 再從現有推薦頁擴展）
```

---

## 8. 版權與法律

### 8.1 風險

此 demo 頁面不引入新的法律風險，因為：
- 使用的資料來源與現有推薦頁完全相同（同一 API）
- 「年度損失」計算純屬前端推估，不構成金融建議
- 需沿用現有頁面的免責聲明

### 8.2 免責聲明（結果頁底部）

```
本計算機提供信用卡回饋估算，僅供參考。年度損失基於假設每月消費金額相同的簡化模型，
實際回饋依各銀行公告為準。CardSense 不構成金融建議，請以銀行官網資訊為最終依據。
```

---

*Owner: Alan | Created: 2026-03-27*
*預估總工時：6-8 小時（分 3 個 sprint）*
*前提：現有 /v1/cards 和 /v1/recommendations/card API 正常運作*
## Demo Addendum (2026-04-05)

### Recommendation Labels

- Demo outputs should prefer `bankName + cardName` in ranking and summary areas when space is limited.
- Long card names should be truncated in-chart, while keeping the full name available via tooltip / title text where possible.
- The same naming strategy should stay consistent across ranking chart, best/worst summary, and share copy/image.

### Eligibility Filter Expectations

- Card catalog demo behavior now assumes `/v1/cards` can filter by `eligibilityType`.
- Expected values are `GENERAL`, `PROFESSION_SPECIFIC`, and `BUSINESS`.
- Demo verification should include at least one business-card and one profession-specific-card case after each DB refresh.

### Benefit Plan / Subcategory Expectations

- Benefit-switching cards should no longer be demonstrated as mostly `GENERAL` subcategory rows when plan/category context is known.
- Demo checks should prioritize Cathay CUBE, Taishin Richart, and ESUN Unicard.
