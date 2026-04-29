# CardSense Review — 2026-04-29

本次依序執行 `/office-hours`、`/plan-ceo-review`、`/plan-design-review`、`/design-review`、`/qa-only`、`/plan-eng-review`、`/review`、`/cso`，採 report-only。未修改產品程式碼。

Evidence screenshots:
- `cardsense-prod-home-after-coldstart.png`
- `cardsense-prod-home-mobile.png`
- `cardsense-prod-cards-desktop-after-coldstart.png`
- `cardsense-prod-cards-mobile-after-coldstart.png`
- `cardsense-prod-calc-route.png`

## Post-Research Direction Addendum

After the iCard.AI competitor review, the follow-up direction document became the product north star for planning:

- [CardSense Product Direction vs iCard.AI](./CardSense-Product-Direction-vs-iCardAI.md)

This review remains the source of record for product, UX, engineering, QA, and security findings from 2026-04-29. The product direction document does not invalidate those findings. It sharpens the priority order:

1. Keep the 30-day wedge focused on `My Wallet + transaction decision + trust explanation`.
2. Treat broad catalog, broad SEO, affiliate optimization, loans, insurance, and chatbot-first UX as deferred work.
3. Interpret the review action plan through the product direction lens: fix broken decision flow paths first, then make recommendation logic explainable, cap-aware, eligibility-aware, and source-backed.
4. Use this review for issue inventory; use the product direction document for scope decisions and future implementation planning.

## Executive Summary

CardSense 最強定位不是「信用卡 listing site」，而是 **Taiwan credit card decision engine**：付款前輸入 merchant/channel/amount/payment method/My Wallet，直接回答「這筆該刷哪張、實拿多少、為什麼、哪些條件會翻車」。

目前產品已經有正確骨架：merchant-first calculator、My Wallet、benefit plan switching、promotion stackability、contracts、extractor pipeline、Spring Boot deterministic `DecisionEngine`。但信任層與資料治理還不足，UI 仍像「信用卡比較工具 + 卡片目錄」，不是「交易當下 decision layer」。

30 天內應聚焦一個 wedge：**My Wallet + 20 個台灣高混淆場景**，例如 Agoda、momo、Shopee、全聯、Costco、Uber Eats、LINE Pay、Apple Pay、CUBE/Richart/Unicard 切換方案。不要先追全銀行全卡 SEO。

## Top 10 Critical Issues

1. **P0: `/calc` route 斷裂，share loop 會壞掉**
   `cardsense-web/src/App.tsx` 沒有 `/calc` route，但 `ShareButton.tsx` 產生 `/calc` URL。Production `/calc` screenshot 是空白 SPA shell。這會破壞 Dcard/PTT 分享導流。

2. **P0: `matchesChannel()` 未把 `ALL` 當 wildcard**
   `cardsense-api/src/main/java/com/cardsense/api/service/DecisionEngine.java` exact match channel。promotion `channel=ALL` 在 request 帶 `ONLINE/OFFLINE` 時會被排除，影響 CUBE Japan rewards 等新資料。

3. **P0: invalid enum 回 200 + empty recommendations**
   Live API 對 invalid `category/paymentMethod/maxResults` 沒有回 `400`，而是產生空推薦或 default result。前端無法分辨「真的沒有卡」與「輸入壞掉」。

4. **P0: data trust layer 不夠可見**
   結果需要顯示 source、updatedAt、validUntil、matched rules、excluded rules、confidence、requiresRegistration、cap usage。現在使用者難以判斷推薦是否可信。

5. **P0: Supabase import 使用高權限 secret 且 local `.env` 有實值**
   `cardsense-extractor/.env` 含 `SUPABASE_SERVICE_ROLE_KEY` 與 `CLOUDFLARE_API_TOKEN`，安全審查確認存在。需 rotate，改 secret manager / least-privilege role。

6. **P1: `promotion_current` publish 非 atomic**
   extractor sync 會先 delete current 再 upsert。中途失敗可能讓 production API 讀到空資料或 partial data。應改 staging + validation + atomic promote。

7. **P1: contract drift**
   Java `RecommendationRequest` 支援 `benefitPlanTiers/activePlansByCard/planRuntimeByCard`，但 `cardsense-contracts/recommendation-request.schema.json` 未完全表達。未來 client generation 會壞。

8. **P1: merchant registry 與 API hardcoded aliases 不同步**
   contracts 有 `唐吉訶德/明曜/UNITED ARROWS` 等 alias，但 API 仍靠 hardcoded map。merchant matching 是核心資產，不能分裂。

9. **P1: mobile primary flow 過長且有 overflow 風險**
   live visual audit 顯示 mobile 首屏密度過高，calculator、merchant chips、wallet、exchange rate、switching plan 同時出現。核心 decision flow 被淹沒。

10. **P1: public recommendation POST 無 rate limiting**
    `/v1/recommendations/card` 是 public endpoint，未見 API key/rate limit/body size limit。可能被濫用造成 cost/availability/audit log pollution。

## Product Positioning Recommendation

一句話定位：

> CardSense 是台灣信用卡付款前 decision engine：輸入這筆交易，回你該刷哪張、實拿多少、為什麼，以及哪個條件會讓你拿不到。

不要主打「2026 最強信用卡」或「現金回饋排行榜」。Money101、卡優、信用卡社、Dcard/PTT 懶人包會在 SEO/listing 戰場更強。CardSense 應該贏在 **same user, same wallet, one transaction, best decision changes**。

最窄 wedge：

> My Wallet + merchant/channel/payment calculator for 20 個高混淆台灣消費場景。

30 天先忽略：新戶首刷禮 SEO、全銀行全卡覆蓋、B2B widget、AI chatbot、完整哩程估值系統、漂亮但靜態的卡片目錄。

## UX Improvement Plan

P0:
- 加 `/calc` alias 或 redirect 到 `/`，並修正 share URL canonical path。
- 首頁 H1 從 `Card Calculator` 改成 scenario decision framing，例如「這筆消費該刷哪張卡」。
- 結果第一眼只給 `Use this card now` + 2 alternates，不要一開始像 ranking list。
- no-result state 顯示排除原因：payment method、channel、merchant、date、registration、cap。
- cold start 期間顯示「後端喚醒中，約 60 秒」與 retry state；不要只停在 skeleton。

P1:
- 首頁主流程繁中化，English terms 只保留在 secondary label，例如「我的卡包 My Wallet」。
- mobile progressive disclosure：Scenario -> Wallet/cards -> Recommendation，exchange rate / switching plan 收進 Advanced settings。
- `/recommend` 讀取 query params，讓 CTA handoff 真的 prefill。
- 在 result panel 加 `Data updated`、`Source`、`Calculation basis`、`Assumptions`。

P2:
- 新增 `/merchants/:merchantCode` 與 `/channels/:channelCode`，承接全聯、momo、Agoda、LINE Pay 等高意圖入口。
- 新增 `/promotions/:promoVersionId`，讓每筆優惠可分享、可回報、可引用來源。

## Technical Architecture Recommendations

優先順序：

1. **Contract-first recommendation API**
   用 schema test 鎖住 request/response，Java model 與 JSON Schema 不可 drift。

2. **Split `DecisionEngine` boundaries**
   從單一厚 service 拆成：
   - `EligibilityPolicy`
   - `RewardEstimator`
   - `StackabilityResolver`
   - `BenefitPlanResolver`
   - `MerchantPaymentMatcher`
   - `RecommendationAssembler`

3. **Persistent audit trail**
   新增 `recommendation_audits` table，保存 `request_id`、request、response、evaluated `promo_version_id[]`、engine version、catalog snapshot/run_id、latency、error。

4. **Production cold start handling**
   既然 backend 約 1 分鐘可喚醒，frontend 應把 timeout/retry/cold-start message 當正式 UX，不要讓使用者誤會資料壞了。

## Data Model / Rule Engine Recommendations

P0:
- `channel=ALL` 視為 wildcard。
- invalid `category/paymentMethod/channel/maxResults` 回 `400`。
- `stackability` end-to-end first-class：contracts -> Pydantic -> DB JSONB/columns -> repository，不要只藏在 `raw_payload_json`。
- merchant aliases 由 `merchant-registry.json` 產生 API matcher，不要 frontend/contracts/API 各自維護。

P1:
- Supabase/Postgres 加 constraints：`valid_from <= valid_until`、`cashback_value > 0`、`confidence between 0 and 1`、enum-like `CHECK`。
- `promotion_current` 改 staging table + validation + atomic promote。
- `promoId` logical key 納入 sourceUrl/source section、planId、subcategory/channel、merchant/payment condition hash，避免同標題同日活動互相覆蓋。
- 加 high-value regression scenarios：全聯、momo、Agoda、Uber Eats、LINE Pay、Apple Pay、CUBE Japan、Richart switching、Unicard 任意選。

## Security Risks

High:
- Rotate `SUPABASE_SERVICE_ROLE_KEY` 與 `CLOUDFLARE_API_TOKEN`，移出 local `.env`，用 secret manager。
- Extractor import 改 least-privilege DB role，不要日常用 service role。
- Import publish 必須 staging + validation + atomic promote。

Medium:
- Public recommendation POST 加 per-IP / user-agent rate limit、body size limit、WAF/edge limit。
- Feedback widget 不應由 browser 直接 anon upload/insert；改 backend/Edge Function，加 CAPTCHA、MIME/size validation、RLS/storage policy。
- Vercel build 不要 clone mutable contracts branch；改 pinned commit/tag/package。
- 補 secret scanning，例如 Gitleaks / secretlint。

## 30-Day Action Plan

Week 1:
- 修 `/calc` route/share URL。
- 修 `channel=ALL` wildcard。
- API invalid enum/maxResults 回 `400`。
- 首頁文案改成付款決策語境。
- cold start waiting/retry UX。

Week 2:
- no-result reason engine + UI。
- result panel trust layer：source、updatedAt、validUntil、matched/excluded rules。
- merchant alias 由 registry 產生 API matcher。
- rotate local secrets，收斂 extractor credential policy。

Week 3:
- contract tests：recommendation request/response fixtures。
- `stackability` first-class schema/model/storage。
- staging + atomic publish design and first migration plan。
- high-value scenario regression test suite。

Week 4:
- merchant landing MVP：全聯、momo、Agoda、Uber Eats、LINE Pay。
- promotion detail MVP：`promoVersionId` canonical page。
- mobile progressive disclosure pass。
- prepare public sharing examples for PTT/Dcard/Threads。

## Files Or Components To Modify First

Frontend:
- `cardsense-web/src/App.tsx`
- `cardsense-web/src/pages/CalcPage.tsx`
- `cardsense-web/src/pages/calc/ShareButton.tsx`
- `cardsense-web/src/pages/calc/ResultPanel.tsx`
- `cardsense-web/src/components/RecommendationResults.tsx`
- `cardsense-web/src/components/ui/feedback-widget.tsx`

API:
- `cardsense-api/src/main/java/com/cardsense/api/service/DecisionEngine.java`
- `cardsense-api/src/main/java/com/cardsense/api/domain/RecommendationRequest.java`
- `cardsense-api/src/main/java/com/cardsense/api/controller/RecommendationController.java`
- `cardsense-api/src/main/java/com/cardsense/api/repository/SupabasePromotionRepository.java`
- `cardsense-api/src/main/java/com/cardsense/api/security/ApiKeyFilter.java`

Extractor / Contracts:
- `cardsense-extractor/models/promotion.py`
- `cardsense-extractor/extractor/supabase_store.py`
- `cardsense-extractor/extractor/versioning.py`
- `cardsense-extractor/extractor/cathay_real.py`
- `cardsense-contracts/recommendation/recommendation-request.schema.json`
- `cardsense-contracts/promotion/promotion-normalized.schema.json`
- `cardsense-contracts/taxonomy/merchant-registry.json`

## Document Cleanup Candidates

不建議現在刪 `CardSense-Status.md`，它仍是 workspace overview。建議保留，但更新日期與 roadmap，並把本報告連進「相關文件」。

可清理候選：
- `fleet-command/.worktrees/agent-my-wallet-remaining/`：看起來是舊 worktree 複本，若沒有未合併工作可刪。
- 根目錄散落的 transient screenshots 已移到本 review folder。
- 舊 plan/spec 若已被 `CardSense-Status.md` 或本 review 取代，建議先標 `Archived`，不要直接刪除。

## Verification Notes

- `cardsense-web`: `npm run build` passed。
- Production screenshots captured with Playwright CLI。
- `/cards` 首次截圖停在 skeleton；依使用者補充 cold start 後重試，75 秒後確認 103 張卡正常載入。
- 本次未跑 Python 測試；若後續跑 extractor 測試，應使用 `uv run pytest` 與現有 `uv.lock`。
