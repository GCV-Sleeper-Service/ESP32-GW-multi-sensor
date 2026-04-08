# Dashboard Implementation Checklist

_Domain-specific prompt patterns for dashboard work_
_Extracted from: Writing Effective Prompts for Coding Agents — A Practitioner's Guide_

---

## Table of Contents

- [Critical Rules for Dashboard Work](#critical-rules-for-dashboard-work)
- [Data Flow Patterns](#data-flow-patterns)
- [Test Group Implementation](#test-group-implementation)
- [Async Safety Requirements](#async-safety-requirements)
- [Mock Server Patterns](#mock-server-patterns)
- [Code Quality Gates](#code-quality-gates)

---

## Critical Rules for Dashboard Work

### ESPHome POST Body Requirements

ESPHome only consumes POST body bytes for `application/x-www-form-urlencoded` and `multipart/form-data`. JSON bodies are not consumed — socket state is corrupted. All dashboard `fetch()` POST calls must use `Content-Type: application/x-www-form-urlencoded` and `body: 'a=1'`.

**Template:**
```javascript
fetch(url, {
  method: 'POST',
  cache: 'no-store',
  headers: {
    'Authorization': 'Basic ' + btoa(user + ':' + pass),
    'Content-Type': 'application/x-www-form-urlencoded'
  },
  body: 'a=1'
})
```

### Data Path Tracing

For dashboard features, the complete data flow is:
```
Data source → Transport → State handler → DOM update → User sees value
```

Every link in that chain needs explicit guidance. If one link is missing, the feature is broken even if every other link is perfect.

#### Network Device Data Path Example

Network device data does NOT come through ESPHome SSE state events. The `handleState()` function processes SSE events by matching ThermoPro entity IDs (`s.tempId`, `s.humId`, etc.). Network devices have no such entities.

Instead, network cards get live data from the `/api/v2/live` endpoint via periodic polling:
1. Fetch `/api/v2/live` on the same interval as existing polling cycle
2. Extract network device values from response
3. Update network card DOM elements

**Key Functions:**
- `updateNetworkCards()` — extracts and updates network device metrics
- `pollV2Live()` — periodic fetch with in-flight guard

### SENSORS Array and Index-Based Consumers

When expanding the SENSORS array to include new device categories, audit ALL index-based consumers:

- `mkDS()` — creates chart datasets for ALL SENSORS entries
- `applyHistoryRange()` — writes history data to `datasets[idx]`
- `handleState()` — pushes real-time data to `datasets[idx]`
- `loadHistory()` — fetches history for every SENSORS entry

**Solution Pattern:** Add a `chartIdx` property:
- Environmental sensors: `chartIdx = 0, 1, 2, ...` (sequential)
- Non-environmental: `chartIdx = -1`
- All chart code uses `s.chartIdx` instead of raw SENSORS array index

### Helper Function Assumptions

`makeSensorConfig(meta, idx)` builds ThermoPro-specific entity IDs (`text_sensor-{id}_temperature`, etc.). This function is THERMOPRO-SHAPED and will produce meaningless IDs for non-environmental devices.

**Solution:** Create category-specific config builders:
- `makeSensorConfig()` — for environmental devices
- `makeNetworkSensorConfig()` — returns `{ id, name, color, category: 'network', restPaths: [] }` with no ThermoPro entity IDs
- `applySensorMeta()` — dispatches based on category

---

## Data Flow Patterns

### SSE vs. REST Polling

**SSE Path (ThermoPro environmental sensors):**
```
YAML text_sensor → ESPHome SSE event → handleState() → DOM update
```

**REST Polling Path (network devices, system metrics):**
```
Adapter → add_sample() → MetricState.current_value → /api/v2/live → poll function → DOM update
```

### In-Flight Guards

Any periodic polling function must have an in-flight guard to prevent request pileup:

```javascript
let _pollInFlight = false;

function pollV2Live() {
  if (_pollInFlight) return;
  _pollInFlight = true;

  fetch('/api/v2/live', { cache: 'no-store' })
    .then(r => r.json())
    .then(data => {
      updateNetworkCards(data);
      // ... other updates
    })
    .finally(() => { _pollInFlight = false; });
}
```

---

## Test Group Implementation

### Readiness Helper Signature

All `loadDashboard()` calls must use `{ expectedSensorCount: N }`:

```javascript
await loadDashboard(page, { expectedSensorCount: 3 })
```

**DO NOT use `{ timeout: 30000 }`**. That pattern appears in Group 13 for Firefox SSE teardown (BUG-049) and must not be copied. It does not validate that cards have rendered — it only prevents a Playwright timeout. Using it would allow tests to proceed before cards exist, producing intermittent false passes.

### Count Assertion Format

All count assertions must use **hardcoded integer literals**:

```javascript
await expect(cards).toHaveCount(3)   ✅
await expect(cards).toHaveCount(window._manifest.sensors.length)   ❌
```

**Vacuous-pass warning:** Dynamic reads pass vacuously when the manifest is broken. If the manifest returns 0 sensors, `toHaveCount(0)` passes — the test reports green while the feature is completely broken. Hardcoded integers fail loudly in exactly that scenario.

### Group Number Derivation

Never hardcode the group number. Determine the current last group number by reading `dashboard.spec.js` and finding the highest numbered `test.describe()` heading (format: "N. Description"). Your new group is N+1.

### Pre-Commit Verification

Before committing new test groups:
- [ ] All `loadDashboard()` calls use `{ expectedSensorCount: N }` — not `{ timeout: T }`, not bare `loadDashboard(page)`
- [ ] All count assertions are integer literals — zero `window._manifest` reads for counts
- [ ] No code copied from Group 13 that includes `timeout: 30000` or `test.setTimeout(90000)`
- [ ] Group number is N+1 of the actual last group (verified by reading the file)
- [ ] If new FIXTURE_SET variant introduced: `FIXTURE_SET=<variant> npx playwright test` (full suite) run, all failures have skip guards

### New Fixture Variant Audit

When introducing a new `FIXTURE_SET` variant, run the full suite:

```bash
FIXTURE_SET=<new_variant> npx playwright test   # full suite, no --grep
```

Any test that fails needs a skip guard with specific reason:
```javascript
test.skip(process.env.FIXTURE_SET === 'new_variant',
    'Reason: this test asserts a 3sensor-specific count of 3; not applicable to new_variant');
```

The reason string must explain the specific incompatibility — not just "n/a."

---

## Async Safety Requirements

### Dashboard Handler Async Patterns

When a dashboard handler calls `requestManagementCredentials()` (or any async function that yields control), `pollAggregatorLive()` may fire during the wait and replace `innerHTML`. DOM references captured before the `await` become stale.

**Required patterns:**

1. **In-flight flag** set before async call, cleared in `finally`:
```javascript
let _deleteInFlight = false;

async function handleDelete() {
  _deleteInFlight = true;
  try {
    const creds = await requestManagementCredentials();
    // ... rest of handler
  } finally {
    _deleteInFlight = false;
  }
}
```

2. **Poll rerender suppression** while any in-flight flag is true or management input has focus:
```javascript
if (_deleteInFlight || _addInFlight || document.activeElement.classList.contains('mgmt-input')) {
  return; // skip rerender
}
```

3. **Synchronous value capture BEFORE async boundary**:
```javascript
const satId = idInput.value.trim();  // capture before await
const creds = await requestManagementCredentials();
// use satId here, not idInput.value
```

4. **Re-query stable `id` nodes AFTER async boundary** — never reuse pre-captured element references:
```javascript
const resp = await fetch(...);
// DOM may have been replaced during fetch
const statusDiv = document.getElementById('sat-status');  // re-query
```

---

## Mock Server Patterns

### Stateful Mock Endpoints

Tests that mutate server state (add/delete satellite) require test isolation via reset hooks:

1. **State initialization** — from fixture file or hardcoded default
2. **Reset hook** — `beforeEach` block that reinitializes state:
```javascript
test.beforeEach(async ({ request }) => {
  await request.post('http://localhost:8765/test/reset-satellites');
});
```

3. **Response shape verification** — mock must match firmware's literal `httpd_resp_sendstr()` call

### Network Wait Pattern

Use `page.waitForResponse(urlPredicate)` for network-triggered state changes, **never** `waitForTimeout(N)`:

```javascript
const respPromise = page.waitForResponse(resp =>
  resp.url().includes('/api/aggregator/satellites') && resp.status() === 200
);
await page.click('button#add-satellite');
await respPromise;
```

### Stub-Before-Click

When stubbing window functions, stub BEFORE the click that triggers the handler:

```javascript
await page.evaluate(() => {
  window.alert = () => {};  // stub first
});
await page.click('button#dangerous-action');  // then trigger
```

---

## Code Quality Gates

### HTML Safety

`escHtml()` applied to every config-derived or manifest-derived string inserted into HTML:

```javascript
// Bad
card.innerHTML += `<div>${device.name}</div>`;

// Good
card.innerHTML += `<div>${escHtml(device.name)}</div>`;
```

### Null/Undefined Guards

Use explicit checks (`!== undefined && !== null`), **never truthy checks** on values that could legitimately be `0` or `""`:

```javascript
// Bad (fails on last_seen === 0, which is valid epoch timestamp)
if (devData.last_seen) { ... }

// Good
if (devData.last_seen !== undefined && devData.last_seen !== null) { ... }
```

### Numeric-to-CSS Guards

`isFinite()` guard on any numeric value before conversion to CSS:

```javascript
// Bad (produces "width: NaN%" when value is NaN)
bar.style.width = `${value}%`;

// Good
if (isFinite(value)) {
  bar.style.width = `${value}%`;
} else {
  bar.style.width = '0%';
}
```

### No Mixed Guard Styles

Within a single function body, use consistent guard style:

```javascript
// Bad (inconsistent)
if (upVal !== undefined && upVal !== null) { ... }
if (devData.last_seen) { ... }  // truthy check

// Good (consistent)
if (upVal !== undefined && upVal !== null) { ... }
if (devData.last_seen !== undefined && devData.last_seen !== null) { ... }
```

---

## Module-Scoped Critical Rules

### CI-Exact Pre-Conditions

Pre-condition blocks must include the exact commands CI runs — with the same environment variables, `--project` flags, and `--grep` patterns:

```bash
FIXTURE_SET=3sensor npx playwright test --project=chromium
FIXTURE_SET=3sensor npx playwright test --project=firefox
FIXTURE_SET=1sensor npx playwright test tests/browser/sensor-count.spec.js --project=chromium
FIXTURE_SET=mixed npx playwright test --project=chromium --grep "18\. Mixed"
bash scripts/preflight.sh
```

A bare `npx playwright test` is never sufficient as the sole pre-condition.

### Mirror Requirements for Endpoint Changes

When adding or modifying endpoints, verify behavior across all device categories:

| Endpoint | Expected behavior for each category |
|---|---|
| `/sensors.json` | v1 projection: MUST include only environmental devices |
| `/api/status` | per-device fields must be category-appropriate |
| `/api/v2/live` | verify non-environmental devices have correct metric keys |
| `/history/{id}/temp` and `/history/{id}/hum` | MUST return 404 for non-environmental devices |

---

## Phase X Architecture Patterns (v7.6.5.0–v7.6.5.8)

### Module-Scoped Prompts

After Phase X, dashboard prompts should reference only the specific source module(s) being modified:

- Reference `dashboard/core/app-shell.js` — not `dashboard.js`
- Reference `dashboard/components/sensor-cards/index.js` — not "the dashboard"
- Reference `dashboard/components/charts/styles.css` — not "the CSS"

**Anti-pattern:** Prompts that say "update dashboard.js" when the actual change is in a single module.

### Bundle Pipeline Requirement

Every dashboard prompt must include the full pipeline in its validation section:

```bash
bash scripts/bundle-dashboard.sh --write
python3 scripts/render_sensor_config.py --write
node tests/fixtures/generate-fixtures.js
python3 scripts/render_sensor_config.py --write
bash scripts/build-dashboard.sh --write
bash scripts/minify-dashboard.sh
bash scripts/generate-header.sh
python3 scripts/render_sensor_config.py --check
```

**Never edit `dashboard.js` or `dashboard.html` directly.** These are generated artifacts.

### Component Ownership

Changes to a component should be contained within its directory:

- `dashboard/components/sensor-cards/` — index.js, template.html, styles.css
- `dashboard/components/charts/` — index.js, template.html, styles.css
- etc.

**Cross-component changes** (e.g., modifying both `sensor-cards` and `charts`) require explicit justification in the prompt.

### POST Body Requirements

Critical Rule 38 applies to **all** dashboard code with `fetch()` POST calls. This includes:
- Management endpoints (add satellite, remove satellite, delete data)
- Import endpoints
- System control endpoints

ESPHome only consumes `application/x-www-form-urlencoded` POST bodies. JSON bodies are not consumed.

---