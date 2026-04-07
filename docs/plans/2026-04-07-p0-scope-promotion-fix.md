# P0 收尾：CATALOG_ONLY 泛用回饋提升為 RECOMMENDABLE

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix two scope classification bugs that prevent valid general rewards from entering recommendation rankings — affecting ESUN_POYA_CARD (8 promos) and TAISHIN_RICHART (4 promos).

**Architecture:** Two independent fixes in the extractor pipeline: (1) `expand_general_reward_promotions` should promote decomposed clones to RECOMMENDABLE regardless of source scope, since the expansion already gates on no-registration + no-plan + no-merchant; (2) Taishin Richart plan-specific promos should not be downgraded by registration-heavy heuristic when they have a planId.

**Tech Stack:** Python 3.13+ / uv / pytest / SQLite

---

## Bug Analysis

### Bug 1: General reward expansion inherits CATALOG_ONLY

**File:** `extractor/promotion_rules.py:1198-1283`

`expand_general_reward_promotions` creates per-category clones of a general reward promo. It already guards against bad expansion (skips if `requiresRegistration`, `planId`, or merchant conditions present). But clones inherit `recommendationScope` from the source promo. If the source was CATALOG_ONLY (e.g., due to a catalog token in the original body text), all decomposed clones are CATALOG_ONLY too — even though they represent clean, deterministic general rewards.

**Impact:** ESUN_POYA_CARD has 8 decomposed 0.2% point-earning promos across all categories stuck as CATALOG_ONLY.

### Bug 2: Richart plan-specific promos downgraded by registration heuristic

**File:** `extractor/taishin_real.py:1308-1316`

`_resolve_richart_marketing_scope` downgrades promos to CATALOG_ONLY when `requires_registration=True` AND `is_registration_heavy_catalog_offer()` returns True. But Richart plan-specific promos (with planId) have text mentioning "登錄" because plan activation requires a click — this isn't a promotional registration, it's standard plan switching. The function doesn't consider planId.

**Impact:** 4 high-value Richart plan promos (Hotels.com 8.3%, 訂房網 3.3%, LINE Pay 3.8%, 健身 5%) stuck as CATALOG_ONLY.

---

### Task 1: Fix general reward expansion scope promotion

**Files:**
- Modify: `extractor/promotion_rules.py:1253-1267` (inside the clone loop)
- Test: `tests/test_promotion_rules.py`

**Step 1: Write failing test**

Add to `tests/test_promotion_rules.py`:

```python
def test_expand_general_reward_promotions_promotes_catalog_only_clones_to_recommendable():
    promotion = {
        "title": "寶雅悠遊聯名卡 店內外點數累積",
        "category": "OTHER",
        "subcategory": "GENERAL",
        "channel": "ALL",
        "cashbackType": "POINTS",
        "cashbackValue": "0.20",
        "requiresRegistration": False,
        "recommendationScope": "CATALOG_ONLY",
        "conditions": [],
        "planId": None,
    }

    expanded = expand_general_reward_promotions(
        promotion,
        "店內外點數累積",
        "店外 消費：新增一般消費享0.2% 玉山e point回饋。",
    )

    assert len(expanded) > 1
    for clone in expanded:
        assert clone["recommendationScope"] == "RECOMMENDABLE"
```

**Step 2: Run test to verify it fails**

Run: `cd cardsense-extractor && uv run pytest tests/test_promotion_rules.py::test_expand_general_reward_promotions_promotes_catalog_only_clones_to_recommendable -v`

Expected: FAIL — clones still have `"CATALOG_ONLY"`

**Step 3: Write minimal implementation**

In `extractor/promotion_rules.py`, inside `expand_general_reward_promotions`, after line 1267 (`conditions` assignment) and before the dedupe_key block (line 1269), add one line to promote decomposed clones:

```python
            clone["recommendationScope"] = "RECOMMENDABLE"
```

The full context (lines ~1253-1281) should look like:

```python
        for target_category, target_channel in _general_reward_targets(scope_kind):
            clone = dict(promotion)
            clone["title"] = _append_scope_suffix(str(promotion.get("title", "") or ""), scope_label)
            clone["summary"] = collapse_text(f"{scope_label}；{fragment}")[:300]
            clone["category"] = target_category
            clone["subcategory"] = "GENERAL"
            clone["channel"] = target_channel
            clone["cashbackType"] = reward["type"]
            clone["cashbackValue"] = reward["value"]
            clone["conditions"] = _append_general_reward_conditions(
                conditions,
                scope_kind=scope_kind,
                scope_label=scope_label,
                fragment=fragment,
            )
            clone["recommendationScope"] = "RECOMMENDABLE"

            dedupe_key = (
                ...
```

**Step 4: Run test to verify it passes**

Run: `cd cardsense-extractor && uv run pytest tests/test_promotion_rules.py::test_expand_general_reward_promotions_promotes_catalog_only_clones_to_recommendable -v`

Expected: PASS

**Step 5: Run all promotion_rules tests to check for regressions**

Run: `cd cardsense-extractor && uv run pytest tests/test_promotion_rules.py -v`

Expected: All PASS. Existing tests don't assert on `recommendationScope`, so no regressions.

**Step 6: Commit**

```bash
cd cardsense-extractor
git add extractor/promotion_rules.py tests/test_promotion_rules.py
git commit -m "fix: promote decomposed general reward clones to RECOMMENDABLE

Expanded general rewards already gate on no-registration, no-plan,
no-merchant conditions. Clones should not inherit CATALOG_ONLY from
source promo. Fixes ESUN_POYA_CARD 8 promos stuck as CATALOG_ONLY."
```

---

### Task 2: Fix Richart plan-specific scope downgrade

**Files:**
- Modify: `extractor/taishin_real.py:1308-1316` (`_resolve_richart_marketing_scope`)
- Modify: `extractor/taishin_real.py:1123` (call site — pass plan_id)
- Test: `tests/test_taishin_real.py`

**Step 1: Write failing test**

Add to `tests/test_taishin_real.py`:

```python
def test_resolve_richart_marketing_scope_keeps_plan_specific_offer_recommendable():
    from extractor.taishin_real import _resolve_richart_marketing_scope

    scope = _resolve_richart_marketing_scope(
        "Hotels.com回饋最高8.3%，玩旅刷Richart卡",
        "2026/1/1~2026/6/30 Hotels.com回饋最高8.3%，需登錄，每月上限 500 元。",
        "OVERSEAS",
        True,
        plan_id="TAISHIN_RICHART_TRAVEL",
    )

    assert scope == "RECOMMENDABLE"
```

**Step 2: Run test to verify it fails**

Run: `cd cardsense-extractor && uv run pytest tests/test_taishin_real.py::test_resolve_richart_marketing_scope_keeps_plan_specific_offer_recommendable -v`

Expected: FAIL — `TypeError: _resolve_richart_marketing_scope() got an unexpected keyword argument 'plan_id'`

**Step 3: Modify `_resolve_richart_marketing_scope` to accept plan_id**

In `extractor/taishin_real.py`, change the function signature and add an early return:

```python
def _resolve_richart_marketing_scope(
    title: str, text: str, category: str, requires_registration: bool,
    *, plan_id: str | None = None,
) -> str:
    if plan_id and requires_registration:
        scope = classify_recommendation_scope(title, text, category)
        if scope != "FUTURE_SCOPE":
            return "RECOMMENDABLE"
    combined = f"{title} {text}"
    hard_catalog_tokens = [token for token in RICHART_CATALOG_ONLY_TOKENS if token not in REGISTRATION_TOKENS]
    if any(token in combined for token in hard_catalog_tokens):
        return "CATALOG_ONLY"
    scope = classify_recommendation_scope(title, text, category)
    if requires_registration and scope == "RECOMMENDABLE" and is_registration_heavy_catalog_offer(combined):
        return "CATALOG_ONLY"
    return scope
```

Logic: if a promo has a planId AND requires_registration, the "registration" is plan activation — keep RECOMMENDABLE unless `classify_recommendation_scope` says FUTURE_SCOPE (new-customer-only promos should still be excluded).

**Step 4: Update the call site to pass plan_id**

In `extractor/taishin_real.py` line 1123, change:

```python
    recommendation_scope = _resolve_richart_marketing_scope(title, focused_text, category, requires_registration)
```

to:

```python
    recommendation_scope = _resolve_richart_marketing_scope(title, focused_text, category, requires_registration, plan_id=plan_id)
```

**Step 5: Run new test to verify it passes**

Run: `cd cardsense-extractor && uv run pytest tests/test_taishin_real.py::test_resolve_richart_marketing_scope_keeps_plan_specific_offer_recommendable -v`

Expected: PASS

**Step 6: Update existing tests to pass plan_id=None explicitly (optional — default is None)**

The existing tests at lines 325-348 call with 4 positional args and no plan_id. Since we added plan_id as keyword-only with default None, existing tests should still pass without changes.

**Step 7: Run all taishin tests**

Run: `cd cardsense-extractor && uv run pytest tests/test_taishin_real.py -v`

Expected: All PASS

**Step 8: Commit**

```bash
cd cardsense-extractor
git add extractor/taishin_real.py tests/test_taishin_real.py
git commit -m "fix: keep Richart plan-specific promos RECOMMENDABLE despite registration text

Plan activation (登錄/切換) is a standard Richart feature, not
promotional registration. When planId is set, skip the
registration-heavy downgrade. Fixes 4 Richart promos (Hotels.com
8.3%, 訂房網 3.3%, LINE Pay 3.8%, 健身 5%) stuck as CATALOG_ONLY."
```

---

### Task 3: Verify with full test suite

**Step 1: Run all extractor tests**

Run: `cd cardsense-extractor && uv run pytest -v`

Expected: All PASS

---

### Task 4: Re-extract and verify in database (optional — requires bank website access)

To see the fix in action on real data, re-run the affected extractors and check the database:

```bash
cd cardsense-extractor
# Re-extract E.SUN (for POYA)
uv run python jobs/run_esun_real_job.py
uv run python jobs/import_jsonl_to_db.py --input outputs/esun-real-*.jsonl --db data/cardsense.db

# Re-extract Taishin (for Richart)
uv run python jobs/run_taishin_real_job.py
uv run python jobs/import_jsonl_to_db.py --input outputs/taishin-real-*.jsonl --db data/cardsense.db
```

Then verify:
```sql
-- POYA should now have 8+ RECOMMENDABLE promos
SELECT recommendation_scope, COUNT(*) FROM promotion_current
WHERE card_code = 'ESUN_POYA_CARD' GROUP BY recommendation_scope;

-- Richart should now have 6+ RECOMMENDABLE promos (was 2)
SELECT recommendation_scope, COUNT(*) FROM promotion_current
WHERE card_code = 'TAISHIN_RICHART' GROUP BY recommendation_scope;
```
