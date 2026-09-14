> **Historical / superseded / not planned (2026-09).** CardSense is archived. This document and its linked CardSense plans are engineering history, not an active roadmap or an instruction to run production operations. [Archive decision](https://github.com/WaddleStudio/cardsense-api/blob/master/ARCHIVED.md).

# Supabase 串接 Discord 回饋系統安裝指南

為了將 **Native Feedback Widget** 無縫對接到 Supabase，並即時透過 Discord 接收通知，請依照以下步驟在 Supabase 控制台進行設定。

---

## 步驟零：開啟儲存桶 (Storage) 放截圖

1. 進入 Supabase 首頁側邊欄點選 **Storage**。
2. 點擊 **New Bucket**，名字取作 `feedback-images`。
3. **重要**：勾選 `Public bucket`，讓 Discord 也能讀取圖片，然後按下 Save。
4. 點選建立好的 `feedback-images` 桶子，切換到 **Policies** 標籤頁。
5. 點擊 **New policy** → **For full customization**
6. 給個名字（例如：`Allow anonymous uploads`），在 **Allowed operations** 勾選 `INSERT`。
7. 其他都不用填，直接按下 **Save policy**。

---

## 步驟一：在 Supabase 建立 `feedbacks` 資料表

進入 **SQL Editor**，貼上並執行以下 SQL：

```sql
CREATE TABLE feedbacks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  type text NOT NULL,
  description text NOT NULL,
  context jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE feedbacks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable insert for anonymous users"
ON feedbacks
FOR INSERT
TO anon
WITH CHECK (true);
```

---

## 步驟二：取得 Discord Webhook URL

1. 開啟想接收通知的 Discord 頻道，點擊齒輪圖示 ⚙️ 進入編輯頻道。
2. 切換到「**整合 (Integrations)**」→「**Webhooks**」。
3. 新建 Webhook，名稱可取 `CardSense 回報小幫手`。
4. 按下 **複製 Webhook 網址** 備用。

---

## 步驟三：建立 Edge Function

> **注意**：Supabase Database Webhook 的 HTTP Parameters 欄位有 UI bug 且格式不符合 Discord 要求，必須改用 Edge Function 轉發。

1. Supabase 左側 → **Edge Functions** → **Deploy a new function**
2. 名稱填 `notify-discord`
3. 內容貼上：

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  const payload = await req.json();
  const record = payload.record;
  const context = record.context ?? {};

  const discordWebhookUrl = Deno.env.get("DISCORD_WEBHOOK_URL")!;

  const embed: Record<string, unknown> = {
    title: "收到新使用者回饋！",
    color: 16711680,
    fields: [
      { name: "類型 (Type)", value: record.type ?? "無", inline: true },
      {
        name: "回報畫面 (URL)",
        value: context.url ? `[點我重現操作現場](${context.url})` : "無",
        inline: true,
      },
      { name: "使用者描述", value: record.description ?? "無" },
    ],
  };

  if (context.screenshot_url) {
    embed.image = { url: context.screenshot_url };
  }

  await fetch(discordWebhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      content: null,
      embeds: [embed],
      username: "CardSense",
    }),
  });

  return new Response("ok", { status: 200 });
});
```

4. Edge Functions → **Settings** → 新增環境變數：
   - Key: `DISCORD_WEBHOOK_URL`
   - Value: 步驟二複製的完整 Discord Webhook URL

---

## 步驟四：設定 Database Webhook

1. Supabase 左側 → **Database** → **Webhooks** → **Create a new Hook**
2. 填寫：
   - **Name**: `Notify Discord on New Feedback`
   - **Table**: `feedbacks`
   - **Events**: 勾選 `Insert`
   - **Type of Hook**: `Supabase Edge Functions`
   - **Function**: 選擇 `notify-discord`
3. 按下 **Create Webhook**。

---

## 完成

只要使用者透過右下角的懸浮按鈕送出回饋：
1. 資料儲存進 Supabase `feedbacks` table。
2. 若有附上截圖，圖片會上傳至 `feedback-images` Storage bucket。
3. Discord 在半秒內跳出通知卡片，附有類型、描述、操作現場連結，以及截圖（若有）。

前端環境變數請在 Vercel 後台或 `.env.local` 補上 `VITE_SUPABASE_URL` 與 `VITE_SUPABASE_ANON_KEY`。
