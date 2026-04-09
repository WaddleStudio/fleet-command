# Exchange Rate Board v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a drawer-based Exchange Rate Board v1 for `RecommendationForm`, backed by cleaned-up `POINTS` / `MILES` rate metadata, without changing API contracts.

**Architecture:** Keep the current request/response contract intact. Clean up `cardsense-api` exchange-rate seed data first, then refactor `cardsense-web` so `ExchangeRatesPanel` becomes a container and a new `ExchangeRatesBoard` handles dense quote-board presentation inside a right-side drawer opened from `RecommendationForm`.

**Tech Stack:** Java 21 / Spring Boot 3 / JUnit 5 / React 19 / TypeScript 5.9 / Vite 8 / Radix Dialog / Tailwind CSS 4

---

## File Structure

### cardsense-api

- Modify: `cardsense-api/src/main/resources/exchange-rates.json`
  Normalize `POINTS` / `MILES` labels and notes so the board can display clean bank/program rows.
- Create: `cardsense-api/src/test/java/com/cardsense/api/service/ExchangeRateServiceTest.java`
  Lock in the JSON loading behavior and ensure the service returns the expected rows/version/defaults.

### cardsense-web

- Create: `cardsense-web/src/components/exchange-rates/exchange-rate-board.types.ts`
  Shared row type for board rendering and container logic.
- Create: `cardsense-web/src/components/exchange-rates/normalize-exchange-rates.ts`
  Pure normalization and grouping helpers extracted from the current panel.
- Create: `cardsense-web/src/components/exchange-rates/ExchangeRatesBoard.tsx`
  Pure presentational dense quote-board UI.
- Modify: `cardsense-web/src/components/ExchangeRatesPanel.tsx`
  Convert from expandable inline form to drawer container + trigger button.
- Modify: `cardsense-web/src/components/RecommendationForm.tsx`
  Keep the current integration point, but render the new trigger + drawer flow.
- Optional Modify: `cardsense-web/src/components/ui/dialog.tsx`
  Only if the current dialog content class list needs a right-side drawer variant without breaking existing dialog usage.

### fleet-command

- Modify: `fleet-command/CardSense-Status.md`
  Mark the implementation as in progress or update the status after shipping.
- Modify: `fleet-command/specs/spec-exchange-rate-engine.md`
  Reflect the implemented drawer/board shape once code lands.

---

## Task 1: Clean Up Exchange Rate Seed Data In API

**Files:**
- Modify: `cardsense-api/src/main/resources/exchange-rates.json`
- Test: `cardsense-api/src/test/java/com/cardsense/api/service/ExchangeRateServiceTest.java`

- [ ] **Step 1: Write the failing API test for exchange-rate loading**

Create `cardsense-api/src/test/java/com/cardsense/api/service/ExchangeRateServiceTest.java`:

```java
package com.cardsense.api.service;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ExchangeRateServiceTest {

    @Test
    void getSystemRates_exposesVersionAndNormalizedEntries() {
        ExchangeRateService service = new ExchangeRateService();
        service.init();

        var response = service.getSystemRates();

        assertEquals("2026-04-10", response.version());
        assertNotNull(response.rates());
        assertFalse(response.rates().isEmpty());
        assertTrue(
                response.rates().stream().anyMatch(entry ->
                        entry.type().equals("POINTS")
                                && entry.bank().equals("CTBC")
                                && entry.unit().equals("LINE Points")
                                && entry.value().compareTo(BigDecimal.ONE) == 0
                )
        );
        assertTrue(
                response.rates().stream().anyMatch(entry ->
                        entry.type().equals("MILES")
                                && entry.bank().equals("_DEFAULT")
                                && entry.value().compareTo(new BigDecimal("0.40")) == 0
                )
        );
    }

    @Test
    void customRate_overridesSpecificOrDefaultKey() {
        ExchangeRateService service = new ExchangeRateService();
        service.init();

        assertEquals(
                new BigDecimal("0.80"),
                service.getPointValueRate("ESUN", Map.of("POINTS.ESUN", new BigDecimal("0.80")))
        );
        assertEquals(
                new BigDecimal("0.60"),
                service.getMileValueRate("CATHAY", Map.of("MILES._DEFAULT", new BigDecimal("0.60")))
        );
    }
}
```

- [ ] **Step 2: Run the API test to verify it fails on the current seed file**

Run:

```bash
cd cardsense-api
mvn -Dtest=ExchangeRateServiceTest test
```

Expected:

- FAIL because `response.version()` is still `2026-04-08`
- Or FAIL because current `exchange-rates.json` contains malformed / dirty labels that do not match the normalized assertions

- [ ] **Step 3: Update `exchange-rates.json` to clean labels and notes**

Change `cardsense-api/src/main/resources/exchange-rates.json` to a clean v1 board dataset:

```json
{
  "version": "2026-04-10",
  "rates": {
    "POINTS": {
      "_DEFAULT": { "value": 1.0, "unit": "點數", "note": "預設 1:1 台幣估值" },
      "CTBC": { "value": 1.0, "unit": "LINE Points", "note": "中信 LINE Points 以 1:1 折抵估值" },
      "CATHAY": { "value": 1.0, "unit": "小樹點", "note": "國泰小樹點以 1:1 折抵估值" },
      "TAISHIN": { "value": 1.0, "unit": "DAWHO Points", "note": "台新 DAWHO Points 以 1:1 折抵估值" },
      "ESUN": { "value": 1.0, "unit": "e point", "note": "玉山 e point 以 1:1 折抵估值" },
      "FUBON": { "value": 1.0, "unit": "momo 幣 / mmo Point", "note": "富邦體系點數以保守 1:1 折抵估值" }
    },
    "MILES": {
      "_DEFAULT": { "value": 0.40, "unit": "航空哩程", "note": "保守估值，適合作為一般哩程比較基準" },
      "ASIA_MILES": { "value": 0.40, "unit": "亞洲萬里通", "note": "以亞洲區段經濟艙的保守兌換價值估算" },
      "EVA_INFINITY": { "value": 0.50, "unit": "長榮無限萬哩遊", "note": "以長榮亞洲線兌換價值做保守估算" },
      "JALPAK": { "value": 0.35, "unit": "JAL 哩程", "note": "以日航經濟艙兌換價值做保守估算" }
    }
  }
}
```

- [ ] **Step 4: Run the API test to verify it passes**

Run:

```bash
cd cardsense-api
mvn -Dtest=ExchangeRateServiceTest test
```

Expected:

- PASS
- Confirms the board will receive clean `unit`, `note`, `value`, and `version` data

- [ ] **Step 5: Run the existing reward calculator tests for regression coverage**

Run:

```bash
cd cardsense-api
mvn -Dtest=RewardCalculatorTest test
```

Expected:

- PASS
- Confirms the data cleanup did not break the existing reward conversion path

- [ ] **Step 6: Commit the API changes**

```bash
cd cardsense-api
git add src/main/resources/exchange-rates.json src/test/java/com/cardsense/api/service/ExchangeRateServiceTest.java
git commit -m "feat: normalize exchange rate board seed data"
```

---

## Task 2: Extract Shared Exchange Rate Board Types And Normalizers

**Files:**
- Create: `cardsense-web/src/components/exchange-rates/exchange-rate-board.types.ts`
- Create: `cardsense-web/src/components/exchange-rates/normalize-exchange-rates.ts`
- Modify: `cardsense-web/src/components/ExchangeRatesPanel.tsx`

- [ ] **Step 1: Add the shared board row type**

Create `cardsense-web/src/components/exchange-rates/exchange-rate-board.types.ts`:

```ts
export interface ExchangeRateBoardRow {
  key: string
  type: 'POINTS' | 'MILES' | string
  bank: string
  unit: string
  value: number
  note: string | null
  label: string
  sectionOrder: number
  rowOrder: number
}
```

- [ ] **Step 2: Add a pure normalizer helper**

Create `cardsense-web/src/components/exchange-rates/normalize-exchange-rates.ts`:

```ts
import type { ExchangeRateEntry, ExchangeRatesResponse } from '@/types'
import type { ExchangeRateBoardRow } from './exchange-rate-board.types'

const TYPE_ORDER: Record<string, number> = { POINTS: 0, MILES: 1 }

const BANK_LABEL_MAP: Record<string, string> = {
  _DEFAULT: '系統預設',
  CTBC: '中信',
  CATHAY: '國泰',
  TAISHIN: '台新',
  ESUN: '玉山',
  FUBON: '富邦',
  ASIA_MILES: '亞洲萬里通',
  EVA_INFINITY: '長榮無限萬哩遊',
  JALPAK: 'JAL 哩程',
}

export function formatExchangeRateLabel(type: string, bank: string, unit: string) {
  if (bank === '_DEFAULT') {
    return unit || '系統預設'
  }
  return BANK_LABEL_MAP[bank] ? `${BANK_LABEL_MAP[bank]} / ${unit}` : `${bank} / ${unit}`
}

export function normalizeExchangeRates(
  rates: ExchangeRatesResponse['rates'] | undefined,
): ExchangeRateBoardRow[] {
  if (!rates) return []

  const entries = Array.isArray(rates)
    ? rates
    : Object.entries(rates).map(([key, value]) => {
        const [type = 'POINTS', bank = '_DEFAULT'] = key.split('.')
        return { type, bank, unit: type, value, note: null } as ExchangeRateEntry
      })

  return entries
    .map((entry) => ({
      key: `${entry.type}.${entry.bank}`,
      type: entry.type,
      bank: entry.bank,
      unit: entry.unit,
      value: Number(entry.value),
      note: entry.note ?? null,
      label: formatExchangeRateLabel(entry.type, entry.bank, entry.unit),
      sectionOrder: TYPE_ORDER[entry.type] ?? 99,
      rowOrder: entry.bank === '_DEFAULT' ? 0 : 1,
    }))
    .filter((row) => !Number.isNaN(row.value))
    .sort((a, b) =>
      a.sectionOrder - b.sectionOrder ||
      a.rowOrder - b.rowOrder ||
      a.label.localeCompare(b.label, 'zh-Hant'),
    )
}

export function getDefaultRateMap(rows: ExchangeRateBoardRow[]) {
  return Object.fromEntries(rows.map((row) => [row.key, row.value]))
}
```

- [ ] **Step 3: Point `ExchangeRatesPanel` at the shared normalizer**

In `cardsense-web/src/components/ExchangeRatesPanel.tsx`, remove the local `NormalizedExchangeRate` interface and local normalize helpers, then replace them with imports:

```ts
import {
  getDefaultRateMap,
  normalizeExchangeRates,
} from '@/components/exchange-rates/normalize-exchange-rates'
import type { ExchangeRateBoardRow } from '@/components/exchange-rates/exchange-rate-board.types'
```

And update the derived state:

```ts
const normalizedRates = useMemo(
  () => normalizeExchangeRates(data?.rates),
  [data?.rates],
)

const defaultRateMap = useMemo(
  () => getDefaultRateMap(normalizedRates),
  [normalizedRates],
)
```

- [ ] **Step 4: Type-check the web repo**

Run:

```bash
cd cardsense-web
npx tsc -b
```

Expected:

- PASS
- No unresolved imports after extracting the helper module

- [ ] **Step 5: Commit the extraction**

```bash
cd cardsense-web
git add src/components/exchange-rates/exchange-rate-board.types.ts src/components/exchange-rates/normalize-exchange-rates.ts src/components/ExchangeRatesPanel.tsx
git commit -m "refactor: extract exchange rate board normalization helpers"
```

---

## Task 3: Build The Presentational Exchange Rate Board

**Files:**
- Create: `cardsense-web/src/components/exchange-rates/ExchangeRatesBoard.tsx`
- Modify: `cardsense-web/src/components/ExchangeRatesPanel.tsx`

- [ ] **Step 1: Create the board presentation component**

Create `cardsense-web/src/components/exchange-rates/ExchangeRatesBoard.tsx`:

```tsx
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { cn } from '@/lib/utils'
import type { ExchangeRateBoardRow } from './exchange-rate-board.types'

interface ExchangeRatesBoardProps {
  rows: ExchangeRateBoardRow[]
  values: Record<string, string>
  activeOverrideKeys: Set<string>
  onValueChange: (key: string, value: string) => void
}

export function ExchangeRatesBoard({
  rows,
  values,
  activeOverrideKeys,
  onValueChange,
}: ExchangeRatesBoardProps) {
  const pointRows = rows.filter((row) => row.type === 'POINTS')
  const mileRows = rows.filter((row) => row.type === 'MILES')

  return (
    <div className="space-y-6">
      <section className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">POINTS</p>
        <div className="overflow-hidden rounded-xl border border-border">
          {pointRows.map((row) => (
            <ExchangeRateBoardRowItem
              key={row.key}
              row={row}
              value={values[row.key] ?? ''}
              overridden={activeOverrideKeys.has(row.key)}
              onValueChange={onValueChange}
            />
          ))}
        </div>
      </section>

      <section className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">MILES</p>
        <div className="overflow-hidden rounded-xl border border-border">
          {mileRows.map((row) => (
            <ExchangeRateBoardRowItem
              key={row.key}
              row={row}
              value={values[row.key] ?? ''}
              overridden={activeOverrideKeys.has(row.key)}
              onValueChange={onValueChange}
            />
          ))}
        </div>
      </section>
    </div>
  )
}

function ExchangeRateBoardRowItem({
  row,
  value,
  overridden,
  onValueChange,
}: {
  row: ExchangeRateBoardRow
  value: string
  overridden: boolean
  onValueChange: (key: string, value: string) => void
}) {
  return (
    <div className="grid grid-cols-[minmax(0,1.3fr)_minmax(0,0.9fr)_132px] gap-3 border-b border-border bg-card px-4 py-3 last:border-b-0">
      <div className="min-w-0">
        <div className="flex items-center gap-2">
          <Badge variant="outline" className="rounded-full text-[10px]">{row.type}</Badge>
          <p className="truncate text-sm font-medium">{row.label}</p>
        </div>
        {row.note && <p className="mt-1 text-xs leading-relaxed text-muted-foreground">{row.note}</p>}
      </div>

      <div className="min-w-0 text-left">
        <p className="tabular-nums text-2xl font-semibold text-reward">{row.value.toFixed(2)}</p>
        <p className="text-xs text-muted-foreground">1 {row.unit} = {row.value.toFixed(2)} TWD</p>
      </div>

      <div className="space-y-2">
        <Badge
          variant={overridden ? 'default' : 'secondary'}
          className={cn('rounded-full', !overridden && 'text-muted-foreground')}
        >
          {overridden ? '已覆寫' : '系統預設'}
        </Badge>
        <div className="relative">
          <Input
            type="number"
            min={0}
            step="0.01"
            value={value}
            placeholder={row.value.toFixed(2)}
            onChange={(event) => onValueChange(row.key, event.target.value)}
            className="pr-12 text-sm tabular-nums"
          />
          <span className="pointer-events-none absolute inset-y-0 right-3 flex items-center text-xs text-muted-foreground">
            TWD
          </span>
        </div>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Replace the current inline row list with `ExchangeRatesBoard`**

In `cardsense-web/src/components/ExchangeRatesPanel.tsx`, replace the existing `normalizedRates.map(...)` inline markup with:

```tsx
<ExchangeRatesBoard
  rows={normalizedRates}
  values={customRates}
  activeOverrideKeys={new Set(Object.keys(activeRates))}
  onValueChange={(key, value) =>
    setCustomRates((prev) => ({
      ...prev,
      [key]: value,
    }))
  }
/>
```

Before this render, compute `activeRates` once with `useMemo` instead of only inside the effect:

```ts
const activeRates = useMemo(() => {
  const next: Record<string, number> = {}

  Object.entries(customRates).forEach(([key, value]) => {
    const numericValue = Number(value)
    if (value.trim() === '' || Number.isNaN(numericValue) || numericValue < 0) return
    if (!(key in defaultRateMap) || defaultRateMap[key] !== numericValue) {
      next[key] = numericValue
    }
  })

  return next
}, [customRates, defaultRateMap])
```

And simplify the effect to:

```ts
useEffect(() => {
  onChange(activeRates)
}, [activeRates, onChange])
```

- [ ] **Step 3: Type-check the board component**

Run:

```bash
cd cardsense-web
npx tsc -b
```

Expected:

- PASS
- `ExchangeRatesBoard` compiles cleanly and `ExchangeRatesPanel` still produces the same override payloads

- [ ] **Step 4: Lint the changed web files**

Run:

```bash
cd cardsense-web
npx eslint src/components/ExchangeRatesPanel.tsx src/components/exchange-rates/ExchangeRatesBoard.tsx src/components/exchange-rates/normalize-exchange-rates.ts
```

Expected:

- PASS

- [ ] **Step 5: Commit the board UI extraction**

```bash
cd cardsense-web
git add src/components/ExchangeRatesPanel.tsx src/components/exchange-rates/ExchangeRatesBoard.tsx
git commit -m "feat: add dense exchange rate board presentation"
```

---

## Task 4: Convert The Panel To A Trigger + Drawer Flow

**Files:**
- Modify: `cardsense-web/src/components/ExchangeRatesPanel.tsx`
- Modify: `cardsense-web/src/components/ui/dialog.tsx` (only if needed)
- Modify: `cardsense-web/src/components/RecommendationForm.tsx`

- [ ] **Step 1: Add drawer state and trigger summary to `ExchangeRatesPanel`**

At the top of `ExchangeRatesPanel.tsx`, add the dialog imports:

```ts
import { ChartNoAxesColumn, ChevronRight } from 'lucide-react'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
```

Then add local state:

```ts
const [isOpen, setIsOpen] = useState(false)
```

Replace the old collapsible trigger with a summary button:

```tsx
<button
  type="button"
  onClick={() => setIsOpen(true)}
  className="flex w-full items-center justify-between rounded-xl border border-border bg-card px-4 py-3 text-left shadow-sm transition-colors hover:bg-accent/30"
>
  <div className="flex items-center gap-3">
    <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary/10 text-primary">
      <ChartNoAxesColumn className="h-4 w-4" />
    </div>
    <div>
      <p className="text-sm font-medium">匯率牌告</p>
      <p className="text-xs text-muted-foreground">
        {normalizedRates.length} 項 / 已覆寫 {Object.keys(activeRates).length} 項
      </p>
    </div>
  </div>
  <ChevronRight className="h-4 w-4 text-muted-foreground" />
</button>
```

- [ ] **Step 2: Render the board inside a right-side drawer**

Add the dialog content below the trigger:

```tsx
<Dialog open={isOpen} onOpenChange={setIsOpen}>
  <DialogContent
    showCloseButton
    className="right-0 left-auto top-0 h-dvh w-full max-w-[720px] translate-x-0 translate-y-0 rounded-none border-l border-border p-0 sm:max-w-[720px]"
  >
    <div className="flex h-full flex-col bg-background">
      <DialogHeader className="border-b border-border px-6 py-5 text-left">
        <DialogTitle>匯率牌告</DialogTitle>
        <DialogDescription>
          以 1 單位兌 TWD 顯示目前估值。只有與系統預設不同的值才會送進推薦請求。
        </DialogDescription>
      </DialogHeader>

      <div className="border-b border-border bg-muted/20 px-6 py-3">
        <p className="text-xs text-muted-foreground">
          POINTS 與 MILES 分開顯示；每列可直接輸入自訂估值。
        </p>
      </div>

      <div className="flex-1 overflow-y-auto px-6 py-5">
        <ExchangeRatesBoard
          rows={normalizedRates}
          values={customRates}
          activeOverrideKeys={new Set(Object.keys(activeRates))}
          onValueChange={(key, value) =>
            setCustomRates((prev) => ({
              ...prev,
              [key]: value,
            }))
          }
        />
      </div>
    </div>
  </DialogContent>
</Dialog>
```

If the base `DialogContent` animations break the drawer positioning, update `src/components/ui/dialog.tsx` so `className` fully overrides the centered layout without affecting existing modals.

- [ ] **Step 3: Keep `RecommendationForm` integration unchanged except for the new trigger behavior**

No request-shape change is needed in `RecommendationForm.tsx`. Keep this line in place:

```tsx
<ExchangeRatesPanel onChange={setCustomExchangeRates} />
```

Only adjust surrounding spacing if the new trigger needs less top margin than the old expandable card:

```tsx
<div className="space-y-2">
  <ExchangeRatesPanel onChange={setCustomExchangeRates} />
</div>
```

- [ ] **Step 4: Type-check and lint the drawer flow**

Run:

```bash
cd cardsense-web
npx tsc -b
npx eslint src/components/ExchangeRatesPanel.tsx src/components/RecommendationForm.tsx src/components/ui/dialog.tsx
```

Expected:

- PASS
- No regressions in dialog imports or layout props

- [ ] **Step 5: Manual smoke-check in dev server**

Run:

```bash
cd cardsense-web
npm run dev
```

Then verify manually in the browser:

- `RecommendationForm` shows a compact `匯率牌告` button
- Clicking it opens a right-side drawer on desktop
- Editing a value changes the override count
- Closing and reopening the drawer keeps the typed values
- Returning a value to its placeholder/default removes the override count

- [ ] **Step 6: Commit the drawer integration**

```bash
cd cardsense-web
git add src/components/ExchangeRatesPanel.tsx src/components/RecommendationForm.tsx src/components/ui/dialog.tsx
git commit -m "feat: open exchange rate board in recommendation drawer"
```

---

## Task 5: Verify End-To-End Recommendation Payload Behavior

**Files:**
- Verify: `cardsense-web/src/components/RecommendationForm.tsx`
- Verify: `cardsense-web/src/api/hooks.ts`
- Verify: `cardsense-web/src/types/api.ts`

- [ ] **Step 1: Start the API and web app**

Run in one terminal:

```bash
cd cardsense-api
mvn spring-boot:run
```

Run in a second terminal:

```bash
cd cardsense-web
npm run dev
```

Expected:

- API serves `/v1/exchange-rates`
- Web app loads without type/runtime errors

- [ ] **Step 2: Submit a recommendation without overrides**

Use the UI to submit a normal recommendation with no edited rows.

Expected:

- The POST body does not contain `customExchangeRates`
- Recommendation behavior matches the current baseline

- [ ] **Step 3: Submit a recommendation with one `POINTS` override**

Example manual input:

- Open drawer
- Change `POINTS.ESUN` from `1.00` to `0.80`
- Submit a recommendation

Expected:

- Request body contains:

```json
{
  "customExchangeRates": {
    "POINTS.ESUN": 0.8
  }
}
```

- Returned `estimatedReturn` / `rewardDetail.exchangeRate` reflect the override

- [ ] **Step 4: Submit a recommendation with one `MILES` default override**

Example manual input:

- Open drawer
- Change `MILES._DEFAULT` from `0.40` to `0.60`
- Submit a travel recommendation

Expected:

- Request body contains:

```json
{
  "customExchangeRates": {
    "MILES._DEFAULT": 0.6
  }
}
```

- Returned travel recommendations use the overridden mile value

- [ ] **Step 5: Reset the values and confirm the request is clean again**

Set the edited values back to their defaults or clear the input.

Expected:

- Override count returns to `0`
- The POST body no longer includes `customExchangeRates`

- [ ] **Step 6: Commit if any final polish was needed during verification**

```bash
cd cardsense-web
git add src/components/ExchangeRatesPanel.tsx src/components/exchange-rates/ExchangeRatesBoard.tsx src/components/exchange-rates/normalize-exchange-rates.ts src/components/RecommendationForm.tsx
git commit -m "chore: polish exchange rate board verification fixes"
```

Skip this commit if verification required no code changes.

---

## Task 6: Sync Documentation After Implementation

**Files:**
- Modify: `fleet-command/CardSense-Status.md`
- Modify: `fleet-command/specs/spec-exchange-rate-engine.md`
- Modify: `fleet-command/specs/spec-cardSense.md`

- [ ] **Step 1: Update status wording to reflect implementation**

In `fleet-command/CardSense-Status.md`, update the Exchange Rate entry from “next step” language to “drawer-based board shipped on recommendation page” language.

Use wording like:

```md
2. **即時匯率引擎 (Exchange Rate Engine)**：底層能力已上線，推薦頁已改為 trigger button + drawer 的匯率牌告板；下一步是把同一套體驗延伸到 `/calc` 與分享圖。
```

- [ ] **Step 2: Update the exchange-rate spec from planned UI to shipped UI**

In `fleet-command/specs/spec-exchange-rate-engine.md`, revise the “尚未完全達標 / UI 方向” sections so they say:

- recommendation page board shipped
- `/calc` still pending
- program-level explainability still pending

- [ ] **Step 3: Update the main product spec summary**

In `fleet-command/specs/spec-cardSense.md`, update the exchange-rate presentation bullet to reflect:

- trigger button + drawer on recommendation page
- dense board layout with `POINTS` / `MILES` sections

- [ ] **Step 4: Review the docs diff**

Run:

```bash
cd fleet-command
git diff -- CardSense-Status.md specs/spec-exchange-rate-engine.md specs/spec-cardSense.md
```

Expected:

- Only wording updates related to shipped exchange-rate-board behavior

- [ ] **Step 5: Commit docs sync**

```bash
cd fleet-command
git add CardSense-Status.md specs/spec-exchange-rate-engine.md specs/spec-cardSense.md
git commit -m "docs: sync shipped exchange rate board behavior"
```

---

## Self-Review

### Spec Coverage

- Drawer-based trigger flow: covered in Task 4
- Shared presentation component extraction: covered in Tasks 2-3
- Minimal data cleanup for `POINTS` / `MILES`: covered in Task 1
- Keep API contract unchanged: preserved across Tasks 1, 4, and 5
- Verification of override payload behavior: covered in Task 5
- Doc follow-up after implementation: covered in Task 6

### Placeholder Scan

- No `TODO`, `TBD`, or “implement later” placeholders remain
- Commands are concrete
- File paths are explicit
- Snippets use the actual current repo structure

### Type Consistency

- `customExchangeRates`, `ExchangeRatesResponse`, and `rewardDetail` match current type names in `cardsense-web/src/types/api.ts`
- `useExchangeRates()` remains the data source in `cardsense-web/src/api/hooks.ts`
- `ExchangeRateServiceTest` uses the real `ExchangeRateService` API and does not introduce new contract names

