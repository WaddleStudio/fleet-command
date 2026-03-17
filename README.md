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
| **CardSense** | 信用卡推薦 API（確定性規則引擎） | Java 21 / Spring Boot / PostgreSQL | Sprint 0 ✅ |
| **ReviewTrustAnalyzer** | Google Maps 評論信任度分析 | Python / FastAPI / pgvector | V1 ✅ |
| **SEEDCRAFT** | LINE-first 家庭教育教練 | Python / FastAPI / LINE SDK / Next.js | Rebrand ✅ |
| **TechTrend** | B2B 技術週刊（NotebookLM → SaaS） | Next.js / Stripe | Spec ✅ |
| **GoDine（搞定）** | AI 餐廳推薦（情境感知 + 個人化） | Next.js PWA / Google Maps API | 規劃中 |
| **FridgeManager** | 食材管理 + 到期提醒 + AI 食譜 | Next.js PWA / Web Push / Open Food Facts | 規劃中 |
| **Knoty** | 大學生人際關係圖譜 + 社交風險 AI | React Native / Supabase / D3.js | Spec ✅ |

---

## 開發優先序

```
1️⃣ CardSense     — Sprint 1 開發中（最高商業價值）
2️⃣ RTA           — V1 → custom model + Agent SDK
3️⃣ SEEDCRAFT     — LINE MVP 開發
4️⃣ TechTrend     — 週刊生產 + 訂閱成長
5️⃣ GoDine        — Spec → Sprint 1
6️⃣ FridgeManager — Spec → Sprint 1（可與 GoDine 平行）
7️⃣ Knoty         — Spec 完成，待排入開發
```

---

## 跨專案整合（高價值路徑）

```
GoDine → CardSense       推薦餐廳 → 最優付款卡
GoDine → RTA             推薦餐廳 → 評論信任度驗證
FridgeManager → GoDine   食材快過期 → 今天煮什麼
FridgeManager → CardSense 採購清單 → 超市最優卡
SEEDCRAFT → RTA           補習班推薦 → 評論可信度
```

---

## 與各專案 Code Repo 的關係

本 repo 存放**規格書和知識庫文件**。各專案程式碼在獨立 repo：

| Repo | 內容 | Spec | 狀態 |
|------|------|------|------|
| [cardsense-contracts](https://github.com/WaddleStudio/cardsense-contracts) | 共用資料模型 | §4 | |
| [cardsense-extractor](https://github.com/WaddleStudio/cardsense-extractor) | 銀行爬蟲 + LLM 解析 | §3 | |
| [cardsense-api](https://github.com/WaddleStudio/cardsense-api) | 推薦 API | §4-5 | |
| [review-trust-analyzer](https://github.com/WaddleStudio/review-trust-analyzer) | 混合評分系統 | spec-rta | |
| [seedcraft](https://github.com/WaddleStudio/seedcraft) | LINE Bot + LIFF | spec-seedcraft | |
| [techtrend](https://github.com/WaddleStudio/techtrend) | B2B 技術週刊 | spec-techtrend | |
| [godine](https://github.com/WaddleStudio/godine) | AI 餐廳推薦 | spec-godine | |
| [fridgemanager](https://github.com/WaddleStudio/fridgemanager) | 食材管理 | spec-fridgemanager | |
| [knoty](https://github.com/WaddleStudio/knoty) | 人際關係圖譜 | spec-knoty | |

更新流程：**改 spec → commit to fleet-command → 對應 code repo 跟進實作**。

---

## Claude Project Knowledge 同步

本 repo 同時作為 Claude Project Knowledge 的 source of truth。  
更新 spec 後記得同步上傳到 Claude Project。

未來可用 GitHub Action 自動化：push → 觸發 Claude API 更新 Project Knowledge。

---

*Maintained by [Waddle Studio](https://github.com/WaddleStudio) | Last updated: 2026-03-17*
