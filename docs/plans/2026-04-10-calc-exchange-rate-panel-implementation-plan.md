# Calc Exchange Rate Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reuse the shipped exchange-rate board inside `/calc` as a left-column inline tool panel, and make both auto-select and final recommendation requests honor `customExchangeRates`.

**Architecture:** Keep the exchange-rate normalization and override semantics shared across surfaces, while moving surface-specific UX into thin wrappers. `RecommendationForm` keeps its drawer-based wrapper; `/calc` gets a new inline wrapper powered by the same shared controller logic and request payload semantics.

**Tech Stack:** React 19 / TypeScript 5.9 / Vite 8 / TanStack Query / Vitest / Testing Library / Tailwind CSS 4

---

## File Structure

- Modify: `cardsense-web/src/components/ExchangeRatesPanel.tsx`
  Extract the shared exchange-rate controller behavior out of the recommendation-specific drawer wrapper.
- Create: `cardsense-web/src/components/exchange-rates/ExchangeRatesControl.tsx`
  Shared container that fetches rates, normalizes rows, computes active overrides, and exposes a render prop for surface wrappers.
- Create: `cardsense-web/src/components/exchange-rates/InlineExchangeRatesPanel.tsx`
  `/calc`-specific inline tool panel wrapper.
- Modify: `cardsense-web/src/pages/CalcPage.tsx`
  Add `customExchangeRates` state, render the inline tool panel, and include overrides in both recommendation requests.
- Test: `cardsense-web/src/pages/__tests__/CalcPage.exchange-rates.test.tsx`
  Lock in the request payload behavior for auto-select and submit flows.

---

## Task 1: Extract Shared Exchange Rate Control Logic

**Files:**
- Create: `cardsense-web/src/components/exchange-rates/ExchangeRatesControl.tsx`
- Modify: `cardsense-web/src/components/ExchangeRatesPanel.tsx`

- [ ] **Step 1: Write the failing component test for shared override semantics**

Create a focused test that mounts the shared controller through a lightweight harness and asserts:

```tsx
it('only emits non-default numeric overrides', async () => {
  render(<Harness />)

  await user.type(screen.getByLabelText(/POINTS\.ESUN/i), '0.8')
  await user.clear(screen.getByLabelText(/POINTS\.ESUN/i))

  expect(onChange).toHaveBeenLastCalledWith({})
})
```

- [ ] **Step 2: Run the targeted test and verify it fails**

Run:

```bash
cd cardsense-web
npx vitest run src/pages/__tests__/CalcPage.exchange-rates.test.tsx
```

Expected:

- FAIL because the shared controller does not exist yet

- [ ] **Step 3: Create `ExchangeRatesControl.tsx` with the shared fetch/normalize/override logic**

Implement a shared container that owns:

```tsx
const normalizedRates = useMemo(() => normalizeExchangeRates(data?.rates), [data?.rates])
const defaultRateMap = useMemo(() => getDefaultRateMap(normalizedRates), [normalizedRates])
const activeRates = useMemo(() => { /* same override semantics as shipped panel */ }, [customRates, defaultRateMap])
useEffect(() => onChange(activeRates), [activeRates, onChange])
```

Expose these values through a render prop:

```tsx
children({
  rows: normalizedRates,
  customRates,
  setCustomRates,
  activeRates,
  isLoading,
  isError,
})
```

- [ ] **Step 4: Refactor `ExchangeRatesPanel.tsx` to use the shared controller**

Replace in-file data handling with:

```tsx
<ExchangeRatesControl onChange={onChange}>
  {({ rows, customRates, setCustomRates, activeRates, isLoading, isError }) => (
    // existing drawer wrapper UI
  )}
</ExchangeRatesControl>
```

- [ ] **Step 5: Run type-check and the targeted test**

Run:

```bash
cd cardsense-web
npx tsc -b
npx vitest run src/pages/__tests__/CalcPage.exchange-rates.test.tsx
```

Expected:

- `tsc` PASS
- test now fails later or passes once the harness is complete

- [ ] **Step 6: Commit the extraction**

```bash
cd cardsense-web
git add src/components/ExchangeRatesPanel.tsx src/components/exchange-rates/ExchangeRatesControl.tsx
git commit -m "refactor: share exchange rate control logic across surfaces"
```

---

## Task 2: Add The `/calc` Inline Exchange Rate Panel

**Files:**
- Create: `cardsense-web/src/components/exchange-rates/InlineExchangeRatesPanel.tsx`
- Modify: `cardsense-web/src/pages/CalcPage.tsx`

- [ ] **Step 1: Extend the failing test to cover `/calc` rendering**

Add a test that expects the inline tool panel to render in the left rail after the switching-card panel:

```tsx
it('renders the exchange-rate inline tool panel in calc', async () => {
  render(<CalcPage />)

  expect(await screen.findByText(/回饋匯率工具面板/i)).toBeInTheDocument()
})
```

- [ ] **Step 2: Run the targeted test and verify it fails**

Run:

```bash
cd cardsense-web
npx vitest run src/pages/__tests__/CalcPage.exchange-rates.test.tsx -t "renders the exchange-rate inline tool panel in calc"
```

Expected:

- FAIL because `/calc` does not render the inline panel yet

- [ ] **Step 3: Create `InlineExchangeRatesPanel.tsx`**

Implement a thin inline wrapper around `ExchangeRatesControl` + `ExchangeRatesBoard`:

```tsx
export function InlineExchangeRatesPanel({ onChange }: { onChange: (rates: Record<string, number>) => void }) {
  return (
    <section className="space-y-3 rounded-xl border border-border bg-muted/20 p-4">
      <header className="space-y-1">
        <h2 className="text-sm font-semibold">回饋匯率工具面板</h2>
        <p className="text-xs text-muted-foreground">以 1 單位兌 TWD 顯示估值，可直接覆寫 POINTS / MILES。</p>
      </header>
      <ExchangeRatesControl onChange={onChange}>
        {({ rows, customRates, setCustomRates, activeRates, isLoading, isError }) => (
          // loading/error state + ExchangeRatesBoard
        )}
      </ExchangeRatesControl>
    </section>
  )
}
```

- [ ] **Step 4: Mount the inline panel in `CalcPage.tsx`**

Add:

```tsx
const [customExchangeRates, setCustomExchangeRates] = useState<Record<string, number>>({})
```

Render:

```tsx
<InlineExchangeRatesPanel onChange={setCustomExchangeRates} />
```

Place it between `SwitchingCardPanel` and `CardSelector`.

- [ ] **Step 5: Run the targeted test and type-check**

Run:

```bash
cd cardsense-web
npx vitest run src/pages/__tests__/CalcPage.exchange-rates.test.tsx -t "renders the exchange-rate inline tool panel in calc"
npx tsc -b
```

Expected:

- PASS

- [ ] **Step 6: Commit the inline panel UI**

```bash
cd cardsense-web
git add src/components/exchange-rates/InlineExchangeRatesPanel.tsx src/pages/CalcPage.tsx
git commit -m "feat: add inline exchange rate panel to calc"
```

---

## Task 3: Wire `customExchangeRates` Into Both `/calc` Requests

**Files:**
- Modify: `cardsense-web/src/pages/CalcPage.tsx`
- Test: `cardsense-web/src/pages/__tests__/CalcPage.exchange-rates.test.tsx`

- [ ] **Step 1: Add failing tests for auto-select and submit request payloads**

Write two tests that intercept the recommendation mutation calls and assert:

```tsx
expect(autoSelectMutate).toHaveBeenCalledWith(
  expect.objectContaining({
    customExchangeRates: { 'POINTS.ESUN': 0.8 },
  }),
  expect.any(Object),
)

expect(submitMutate).toHaveBeenCalledWith(
  expect.objectContaining({
    customExchangeRates: { 'POINTS.ESUN': 0.8 },
  }),
  expect.any(Object),
)
```

- [ ] **Step 2: Run the targeted tests and verify they fail**

Run:

```bash
cd cardsense-web
npx vitest run src/pages/__tests__/CalcPage.exchange-rates.test.tsx -t "includes custom exchange rates"
```

Expected:

- FAIL because `/calc` request builders currently omit `customExchangeRates`

- [ ] **Step 3: Update both recommendation requests in `CalcPage.tsx`**

Add the same conditional payload spread to both `autoSelectCards(...)` and `getRecommendation(...)`:

```tsx
...(Object.keys(customExchangeRates).length > 0 && { customExchangeRates }),
```

Keep the existing omission semantics when no overrides are active.

- [ ] **Step 4: Re-run the targeted tests**

Run:

```bash
cd cardsense-web
npx vitest run src/pages/__tests__/CalcPage.exchange-rates.test.tsx -t "includes custom exchange rates"
```

Expected:

- PASS

- [ ] **Step 5: Run lint/type-check for the changed files**

Run:

```bash
cd cardsense-web
npx eslint src/pages/CalcPage.tsx src/components/ExchangeRatesPanel.tsx src/components/exchange-rates/ExchangeRatesControl.tsx src/components/exchange-rates/InlineExchangeRatesPanel.tsx
npx tsc -b
```

Expected:

- PASS

- [ ] **Step 6: Commit the request wiring**

```bash
cd cardsense-web
git add src/pages/CalcPage.tsx src/pages/__tests__/CalcPage.exchange-rates.test.tsx
git commit -m "feat: include custom exchange rates in calc requests"
```

---

## Task 4: Verify Surface Parity And Regressions

**Files:**
- Verify: `cardsense-web/src/components/ExchangeRatesPanel.tsx`
- Verify: `cardsense-web/src/components/exchange-rates/InlineExchangeRatesPanel.tsx`
- Verify: `cardsense-web/src/pages/CalcPage.tsx`

- [ ] **Step 1: Run the targeted calc test file**

Run:

```bash
cd cardsense-web
npx vitest run src/pages/__tests__/CalcPage.exchange-rates.test.tsx
```

Expected:

- PASS

- [ ] **Step 2: Run a full frontend type-check**

Run:

```bash
cd cardsense-web
npx tsc -b
```

Expected:

- PASS

- [ ] **Step 3: Run targeted lint**

Run:

```bash
cd cardsense-web
npx eslint src/pages/CalcPage.tsx src/components/ExchangeRatesPanel.tsx src/components/exchange-rates/ExchangeRatesControl.tsx src/components/exchange-rates/InlineExchangeRatesPanel.tsx src/components/exchange-rates/ExchangeRatesBoard.tsx
```

Expected:

- PASS

- [ ] **Step 4: Manual smoke-check both surfaces**

Run:

```bash
cd cardsense-web
npm run dev
```

Verify:

- Recommendation page still opens the drawer and preserves override semantics
- `/calc` shows the inline panel in the left rail
- Editing a value affects both auto-select and submit requests
- Resetting to default clears the override from outgoing payloads

- [ ] **Step 5: Commit any final polish**

```bash
cd cardsense-web
git add src/pages/CalcPage.tsx src/components/ExchangeRatesPanel.tsx src/components/exchange-rates/ExchangeRatesControl.tsx src/components/exchange-rates/InlineExchangeRatesPanel.tsx src/pages/__tests__/CalcPage.exchange-rates.test.tsx
git commit -m "chore: polish calc exchange rate panel integration"
```

Skip this commit if no follow-up code changes were needed.

---

## Self-Review

### Spec Coverage

- `/calc` inline panel placement: covered in Task 2
- Shared controller + surface-specific wrappers: covered in Task 1
- Reuse of shared board/normalization/override semantics: covered in Tasks 1-2
- `customExchangeRates` state in `CalcPage`: covered in Task 2
- Auto-select + submit request wiring: covered in Task 3
- Recommendation drawer unchanged in behavior: verified in Task 4

### Placeholder Scan

- No `TODO`, `TBD`, or deferred implementation placeholders remain
- Files, commands, and expected outcomes are explicit

### Type Consistency

- `customExchangeRates` uses the existing recommendation request field name
- Shared exchange-rate control keeps `ExchangeRatesBoard` and `normalizeExchangeRates` as the source of truth
- `/calc` remains a surface wrapper rather than re-implementing request or override logic
