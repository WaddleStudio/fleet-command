> **CardSense status: Archived / Commercial No-Go / Technical Asset Retained (2026-09).**
> [Archive decision](https://github.com/WaddleStudio/cardsense-api/blob/master/ARCHIVED.md). This status applies to CardSense only; other Fleet projects are unchanged.

# Fleet Command（專案艦隊指揮中心）

七個 side project 的統一規格書庫 — 架構文件、專案 Spec、TechTrend 知識庫來源。

> 所有專案以商業化為最終目標。各 Spec 均包含版權/IP 風險評估。

---

## 命名規則

```
{category}-{name}.{ext}

category:
  spec-    專案規格書
  arch-    架構文件
  prompt-  Prompt 模板
  url-     NotebookLM 來源 URL（純 URL，一行一條）
  ref-     參考資料（說明文件、全景分析）

name:     kebab-case，簡短明確
ext:      .md / .txt
```

## 專案總覽

| 專案 | 定位 | 技術棧 | 狀態 |
|------|------|--------|------|
| **CardSense** | 信用卡推薦 API（確定性規則引擎） | Java 21 / Spring Boot / React 19 / Vite / Python 3.13 / Supabase | Archived / Commercial No-Go (2026-09) |
| **ReviewTrustAnalyzer** | Google Maps 評論信任度分析 | Python / FastAPI / pgvector | V1 ✅ |
| **SEEDCRAFT** | LINE-first 家庭教育教練 | Python / FastAPI / LINE SDK / Next.js | Rebrand ✅ |
| **TechTrend** | B2B 技術週刊（NotebookLM → SaaS） | Next.js / Stripe | Spec ✅ |
| **GoDine（搞定）/ SmartChoice** | AI 餐廳推薦（情境感知 + 個人化） | Next.js PWA / Google Maps API | Spec ✅ |
| **FridgeManager** | 食材管理 + 到期提醒 + AI 食譜 | Next.js PWA / Web Push / Open Food Facts | Spec ✅ |
| **Knoty** | 大學生人際關係圖譜 + 社交風險 AI | React Native / Supabase / D3.js | Spec ✅ |

---

## 開發優先序

```
1️⃣ CardSense     — Live（5 銀行 + 首頁計算機），當前：既有資料品質提升 + 泛用回饋卡入榜
2️⃣ RTA           — V1 → custom model + Agent SDK
3️⃣ SEEDCRAFT     — LINE MVP 開發
4️⃣ TechTrend     — 週刊生產 + 訂閱成長
5️⃣ GoDine        — Spec → Sprint 1
6️⃣ FridgeManager — Spec → Sprint 1（可與 GoDine 平行）
7️⃣ Knoty         — Spec 完成，待排入開發
```

---

## 個人工具（已部署，非商業）

| 工具 | 定位 | 技術棧 | 狀態 |
|------|------|--------|------|
| **RentRadar** | 591 租屋新物件監控，LINE + Discord 即時推播 | Python 3.12 / uv / Playwright / Supabase / LINE Messaging API / Discord Webhook / Oracle Cloud | ✅ 運行中 |

---

## 跨專案整合（高價值路徑）

```
GoDine → CardSense          推薦餐廳 → 最優付款卡
GoDine → RTA                推薦餐廳 → 評論信任度驗證
FridgeManager → GoDine      食材快過期 → 今天煮什麼
FridgeManager → CardSense   採購清單 → 超市最優卡
SEEDCRAFT → RTA             補習班推薦 → 評論可信度
```

---

## 重點文件索引

- [CardSense-Status.md](./CardSense-Status.md) — CardSense text source of truth: product direction, current capability, roadmap, and open follow-ups.
- [dashboard/index.html](./dashboard/index.html) — CardSense fleet dashboard: repo health, roadmap progress, open action queue, latest checks, and release evidence links.

Run the dashboard over HTTP so the browser can read JSON data:

```bash
cd dashboard
python -m http.server 5177
```

## 與各專案 Code Repo 的關係

本 repo 存放**規格書和知識庫文件**。各專案程式碼在獨立 repo：

| Repo | 內容 | Spec | 狀態 |
|------|------|------|------|
| [cardsense-contracts](https://github.com/WaddleStudio/cardsense-contracts) | 共用資料模型 | §4 | Archived; schemas retained |
| [cardsense-extractor](https://github.com/WaddleStudio/cardsense-extractor) | 銀行爬蟲 + 正規化 | §3 | Archived; extraction/sync retained |
| [cardsense-api](https://github.com/WaddleStudio/cardsense-api) | 推薦 API | §4-5 | Archived; runtime retained |
| [cardsense-web](https://github.com/WaddleStudio/cardsense-web) | 前端展示（首頁算卡計算機 + 卡片目錄） | spec-cardSense | Archived; UI retained |
| [review-trust-analyzer](https://github.com/WaddleStudio/review-trust-analyzer) | 混合評分系統 | spec-rta | |
| [seedcraft](https://github.com/WaddleStudio/seedcraft) | LINE Bot + LIFF | spec-seedcraft | |
| [techtrend](https://github.com/WaddleStudio/techtrend) | B2B 技術週刊 | spec-techtrend | |
| [godine](https://github.com/WaddleStudio/godine) | AI 餐廳推薦（SmartChoice 縮小版） | spec-smartChoice | |
| [fridgemanager](https://github.com/WaddleStudio/fridgemanager) | 食材管理 | spec-fridgemanager | |
| [knoty](https://github.com/WaddleStudio/knoty) | 人際關係圖譜 | spec-knoty | |
| [rent-radar](https://github.com/WaddleStudio/rent-radar) | 591 租屋監控 Bot | spec-rent-radar | ✅ 運行中 |

更新流程：**改 spec → commit to fleet-command → 對應 code repo 跟進實作**。

---

## Claude Project Knowledge 同步

本 repo 同時作為 Claude Project Knowledge 的 source of truth。  
更新 spec 後記得同步上傳到 Claude Project。

未來可用 GitHub Action 自動化：push → 觸發 Claude API 更新 Project Knowledge。

---

*Maintained by [Waddle Studio](https://github.com/WaddleStudio) | Last updated: 2026-04-20*
