# Supabase 串接 Discord 回饋系統安裝指南

為了將我們剛剛完成的 **Native Feedback Widget** (原生 React 表單) 無縫對接到 Supabase，並且即時透過 Discord 接收訊息通知，請依照以下三個步驟在您的 Supabase 控制台進行設定！

---

## 步驟一：在 Supabase 建立 `feedbacks` 資料表

請進入您的 Supabase 專案，左側選單點擊 **SQL Editor**，開一個新的 Query，貼上並執行以下 SQL 語法：

```sql
-- 1. 建立 feedbacks 資料表
CREATE TABLE feedbacks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  type text NOT NULL, -- (BUG, INCORRECT_DATA, FEATURE_REQUEST, OTHER)
  description text NOT NULL,
  context jsonb, -- 儲存當前網址、螢幕寬度等除錯資訊
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. 啟用 Row Level Security (RLS) 保護資料表
ALTER TABLE feedbacks ENABLE ROW LEVEL SECURITY;

-- 3. 建立一個不可讀、但任何人可寫入的 Policy (重要：才能讓前端的匿名使用者送出資料)
CREATE POLICY "Enable insert for anonymous users" 
ON feedbacks
FOR INSERT 
TO anon
WITH CHECK (true);
```

> [!CAUTION]
> **為什麼要設定 RLS？** 這樣可以防止有心人士把惡意腳本直接拿您的 `VITE_SUPABASE_ANON_KEY` 給抓去讀取別人發送的回饋，保障安全性。我們設定 `FOR INSERT TO anon` 允許單向寫入。

---

## 步驟二：取得您的 Discord Webhook URL

1. 在您的 Discord 應用庫裡面開啟您想接收訊息的頻道 (Channel)。
2. 點擊頻道名稱旁邊的齒輪圖示 ⚙️ (編輯頻道)。
3. 切換到「**整合 (Integrations)**」標籤頁，點選「**Webhooks**」。
4. 新建一個 Webhook，名稱可以叫做 `CardSense 回報小幫手`。
5. 按下 **「複製 Webhook 網址」** (Copy Webhook URL)，先把它保存在剪貼簿。

---

## 步驟三：在 Supabase 設定 Database Webhook 事件

現在我們要讓 Supabase 當成自動機器人，一收到前端的 `feedbacks` 資料，就轉發去 Discord。

1. 在 Supabase 左側清單選擇 **Database**，再選擇 **Webhooks**（或是 "Database Webhooks"）。
2. 點擊 **Create a new Hook**。
3. **名稱 (Name)**: `Notify Discord on New Feedback`
4. **Table**: 選擇剛剛建立的 `feedbacks`
5. **Events**: 勾選 ✅ `Insert` (只在有人新增資料時跑)
6. **Type of Hook**: 選擇 `HTTP Request`
7. **HTTP Request 設定**:
   - **Method**: `POST`
   - **URL**: [貼上您剛剛複製的 Discord Webhook 網址]
8. **HTTP Headers**:
   - 新增一行： `Content-Type`:`application/json`
9. **HTTP Body**:
   - 選擇 **Raw JSON** 或是 **Toggle the advanced template**
   - 把內容全部清空，只貼上下面這串 JSON 模板 (這是 Discord 專用的 payload 格式支援 Markdown)：

```json
{
  "content": null,
  "embeds": [
    {
      "title": "🚨 收到新使用者回饋！",
      "color": 16711680,
      "fields": [
        {
          "name": "類型 (Type)",
          "value": "`{{record.type}}`",
          "inline": true
        },
        {
          "name": "回報畫面 (URL)",
          "value": "[點我重現操作現場]({{record.context.url}})",
          "inline": false
        },
        {
          "name": "📝 使用者描述",
          "value": "{{record.description}}"
        }
      ]
    }
  ],
  "username": "CardSense 偵錯員",
  "avatar_url": "https://lucide.dev/icons/bug.svg"
}
```

10. 按下 **Create Webhook** 就大功告成了！

---

## 🎉 完成

現在，只要任何使用者在網站點擊右下角的懸浮氣泡送出回饋：
1. 資料會先安穩地儲存進您的 Supabase `feedbacks` table。
2. 您的手機 Discord 在半秒內就會跳出超漂亮的通知卡片！您甚至可以直接點擊裡面附上的 `點我重現操作現場` 網址連結，回去看是哪張卡或是哪個金額試算出了問題。

前端環境變數請記得在 Vercel 後台或 `.env.local` 將 `VITE_SUPABASE_URL` 與 `VITE_SUPABASE_ANON_KEY` 給補上，按鈕就會開始生效。
