# CardSense 回饋與問題回報機制實作規格書 (Feedback Widget Spec)

## 1. 概覽與目標
此規格書定義了 CardSense 前端系統中「使用者回饋與問題回報管道」的實作細節。
基於 **方案 A（常駐懸浮按鈕 + Modal 彈窗）**，並結合 **進階項目（動態攜帶 URL 狀態參數）**，目標是讓使用者能以最低痛點回報問題、同時幫助開發者獲取最完整的 Debug 上下文（含情境參數、裝置資訊等），並且與 Notion 無縫整合。

---

## 2. 系統架構與技術棧

*   **前端框架**: React 19, TailwindCSS 4, shadcn/ui.
*   **按鈕與彈窗組件**: shadcn/ui 的 `Dialog` 組件與 `Button` 組件。
*   **圖示**: Lucide React (`MessageSquare` 或 `Bug` icon)。
*   **後端/表單服務**: **Tally.so** (提供支援檔案上傳功能且完美整合 Notion 的第三方表單)。
*   **狀態管理看板**: Notion Database (直接接收 Tally 的 webhook)。

---

## 3. 使用者介面設計 (UI/UX)

### 3.1 懸浮按鈕 (Floating Action Button, FAB)
*   **位置**: 畫面右下角 (距離底部及右側預留安全邊距，並需確保不會阻擋行動裝置底部的 Navigation Bar 或主要的 Action 區塊)。
    *   桌機版建議 `bottom-8 right-8`
    *   手機版建議考慮是否置於側邊或 `bottom-24 right-4` 避開主按鈕。
*   **外觀**: 圓形或是帶有橢圓背景的按鈕，內部包含 `MessageSquare` 圖示，hover 時展開顯示「提供回饋」。
*   **顏色**: 使用專案的主題色 (Primary color)。

### 3.2 回饋彈窗 (Modal)
*   點擊 FAB 後跳出一個置中的對話框 (Dialog)。
*   標題：「協助我們變得更好 💡」或「回報問題」。
*   內容：滿版嵌入 (`iframe`) Tally 表單。
*   高度：佔畫面最高約 80vh，確保能夠正常滾動，或是配合 Tally 提供的 Widget JS script 來達成自適應高度。

---

## 4. 進階項目實作：動態狀態攜帶 (Context URL Parameters)

為了在收到 Bug 時能精確重現使用者的操作現場，系統會自動將當前頁面的狀態（特別是 `/calc` 的各種推薦參數）默默塞入 Tally 表單中。

### 4.1 Tally 表單的 Hidden Fields 設計
在建立 Tally 表單時，請設定以下 **Hidden Fields（隱藏欄位）**：
1.  `current_url`: 當前完整的 URL（包含 query string，如 `?amount=1000&category=DINING`）。
2.  `path_name`: 當前頁面的獨立路徑（如 `/calc` 或 `/catalog`）。
3.  `user_agent`: 使用者的瀏覽器和裝置資訊。
4.  `screen_width`: 裝置螢幕寬度（用來判斷是行動端還是桌機版的問題）。

### 4.2 前端動態生成 Tally iframe URL
在 React 組件中，動態讀取這些參數，並將其 attach 到 Tally iframe 的 `src`：

```javascript
// 範例邏輯
const tallyBaseUrl = "https://tally.so/embed/YOUR_FORM_ID";
const currentUrl = encodeURIComponent(window.location.href);
const pathName = encodeURIComponent(window.location.pathname);
const userAgent = encodeURIComponent(navigator.userAgent);
const screenWidth = window.innerWidth;

const iframeSrc = `${tallyBaseUrl}?current_url=${currentUrl}&path_name=${pathName}&user_agent=${userAgent}&screen_width=${screenWidth}&alignLeft=1&hideTitle=1&transparentBackground=1`;
```

---

## 5. Tally.so x Notion 表單欄位與後台設定建議

### 5.1 Tally 內部題目設定
除了隱藏欄位外，給使用者看到的問題越少越好：
1.  **回報類型** (單選)：
    *   🚨 遇到錯誤 (Bug / 網頁壞掉)
    *   🤔 推薦結果或卡片福利有誤
    *   💡 許願或功能建議
    *   💖 只是想對開發者說聲讚
2.  **詳細描述** (長文字)：這張卡片哪裡算錯了？或者遇到了什麼問題？
3.  **上傳截圖** (檔案上傳功能，設定為選填)。
4.  **您的 Email** (短文字，選填)：若希望我們進一步與您聯繫或通知問題已修復。

### 5.2 與 Notion 綁定
*   在 Tally 的 "Integrations" 設定中選擇 Notion。
*   將對應的題目與隱藏欄位 (Hidden fields) 全部 map 對應至事先開好的 Notion Database。

---

## 6. 實作步驟 (Frontend Implementation Checklist)

1.  **[ ] 第一步：第三方平台設定**
    *   註冊/登入 Tally.so 並建立表單，設定上述的題目與 Hidden Fields。
    *   建立 Notion 資料庫作為看板。
    *   將 Tally 表單綁定到 Notion 資料庫。
2.  **[ ] 第二步：新增元件檔案**
    *   若尚未安裝 shadcn 的 dialog，需執行：`npx shadcn@latest add dialog`。
    *   在 `cardsense-web/src/components/ui/` (或對應的目錄) 下建立 `FeedbackWidget.tsx` 組件。
3.  **[ ] 第三步：實作 `<FeedbackWidget />` 邏輯**
    *   引入 `useLocation` (React Router) 來隨時監聽並更新 `window.location`，確保彈窗開啟瞬間抓到正確最新的 URL 參數。
    *   封裝 `Dialog` 與內部 Tally embed code 或 iframe。
4.  **[ ] 第四步：注入應用程式**
    *   將 `<FeedbackWidget />` 放進最外層的 Layout (`src/App.tsx`、`src/layouts/MainLayout.tsx` 或是 Root Provider 內)。
    *   測試桌機和手機版面是否會發生位置衝突，調整 `z-index` 與 `bottom/right` 像素。
5.  **[ ] 第五步：端對端測試**
    *   隨便在網站中進行試算與篩選操作（產生複雜的 Query Param）。
    *   打開 Widget 並送出一筆回饋。
    *   至 Notion Database 驗證是否順利收到附加的截圖以及 URL 情境參數。

## 7. 隱私權限制與注意事項
*   若使用者處於部分無痕模式或阻擋跨站追蹤，Tally iframe 的載入可能會遇到小問題，記得為 iframe 加上錯誤 fallback。
*   為維護用戶隱私，建議在該彈窗下方加註一行：「此表單不會記錄您的信用卡號密碼等個人隱私資料，僅收集當前瀏覽頁面之查詢條件以供除錯」。
