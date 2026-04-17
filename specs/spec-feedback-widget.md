# CardSense 回饋與問題回報機制實作規格書 (Feedback Widget Spec)
### Version 1.1 | 2026-04-09

---

## 1. 概覽與目標

此規格書定義 CardSense 前端的「使用者回饋與問題回報管道」。

目前策略已從早期的 **Tally embed 方案** 調整為 **原生前端表單 + 可延伸的後端 payload**：

- 使用者直接在站內 Dialog 完成回報，不需跳轉第三方表單
- 前端自動附帶當前頁面與裝置上下文，降低 Debug 成本
- 當前已可用於站內收集問題
- Notion / Discord 會作為後續 downstream integration，而不是現階段的表單承載層

---

## 2. 目前實作策略

### 2.1 前端技術棧

- React 19
- Tailwind CSS 4
- shadcn/ui `Dialog`、`Button`、`Textarea`、`Input`
- Lucide React (`MessageSquare`, `Bug`, `Image`)

### 2.2 資料流

目前版本採用原生前端表單，資料流如下：

1. 使用者點擊右下角 FAB 開啟回饋 Dialog
2. 填寫回報類型、描述，並可選填截圖
3. 前端自動蒐集：
   - `url`
   - `pathname`
   - `search`
   - `userAgent`
   - `screenWidth`
   - `timestamp`
4. 若有截圖，先上傳至 Supabase Storage
5. 將 payload 寫入 `feedbacks`（目前是站內可用版本）
6. 未來可在寫入後再 fan-out 到：
   - Notion Database
   - Discord webhook

### 2.3 設計決策

- **現階段不再依賴 Tally**：避免表單客製化與 payload 控制受限
- **Notion / Discord 後補**：先把站內回報管道做順，再接外部協作系統
- **Context-first**：優先確保每筆回報都帶完整頁面上下文，而不是只收文字敘述

---

## 3. 使用者介面設計 (UI/UX)

### 3.1 懸浮按鈕 (FAB)

- 位置：右下角
- 形式：圓形按鈕，hover 展開「提供回饋」
- 顏色：沿用主題色
- 行動版：保留足夠安全邊界，避免干擾主要 CTA

### 3.2 回饋 Dialog

- 標題：`協助我們變得更好`
- 欄位：
  - 回報類型
  - 詳細描述
  - 截圖上傳（選填）
- 成功送出後顯示簡短 thank-you state

### 3.3 回報類型

- `BUG`
- `INCORRECT_DATA`
- `FEATURE_REQUEST`
- `OTHER`

---

## 4. 上下文攜帶規格

每次送出回報時，自動附加以下資訊：

```json
{
  "type": "BUG",
  "description": "推薦結果看起來不合理",
  "context": {
    "url": "https://cardsense-web.vercel.app/recommend?...",
    "pathname": "/recommend",
    "search": "?amount=3000&category=TRAVEL",
    "userAgent": "Mozilla/5.0 ...",
    "screenWidth": 430,
    "timestamp": "2026-04-09T10:20:30.000Z",
    "screenshot_url": "https://..."
  }
}
```

### 4.1 必備欄位

- `url`
- `pathname`
- `search`
- `userAgent`
- `screenWidth`
- `timestamp`

### 4.2 選填欄位

- `screenshot_url`

---

## 5. 目前實作狀態

### 已完成

- [x] `cardsense-web/src/components/ui/feedback-widget.tsx` 原生回報元件
- [x] 右下角常駐 FAB + Dialog 互動
- [x] 回報類型 / 描述 / 截圖欄位
- [x] 自動附帶頁面與裝置上下文
- [x] 截圖上傳至 Supabase Storage
- [x] payload 寫入 Supabase `feedbacks`
- [x] 元件已掛載在 `src/App.tsx`

### 尚未完成

- [ ] Notion Database downstream integration
- [ ] Discord webhook downstream integration
- [ ] 後台 triage workflow（標籤、指派、修復狀態）
- [ ] 針對首頁計算機或推薦結果自動補更多 domain-specific context

---

## 6. 後續擴充方向

### 6.1 Notion 整合

目標不是讓 Notion 直接承接使用者表單，而是讓站內表單送出的 payload 再同步進 Notion，作為：

- bug triage board
- extractor 資料問題看板
- 待驗證規則清單

### 6.2 Discord 整合

適合作為即時通知層：

- 新的 `BUG` 回報即時推播
- `INCORRECT_DATA` 直接進資料品質頻道
- 帶上 URL 與截圖，讓開發者快速重現

### 6.3 結構化 domain context

後續可在 payload 裡補更多 CardSense 專屬欄位：

- 使用者當下輸入的 `amount`
- `category` / `subcategory`
- `merchantName`
- `paymentMethod`
- 推薦結果中的 `cardCode`

---

## 7. 隱私與注意事項

- 不收集信用卡卡號、密碼、身分證字號等敏感資料
- 截圖上傳需避免誤曝露個資
- UI 上建議保留簡短說明：
  - 僅收集目前頁面與查詢條件，供除錯與資料修正使用

---

## 8. 結論

Feedback Widget 現在的定位是：

- **已可用的站內原生回報入口**
- **未來 Notion / Discord 的上游資料來源**
- **資料品質修正與使用者回饋循環的基礎設施**

Tally 方案目前不再作為主實作方向。
