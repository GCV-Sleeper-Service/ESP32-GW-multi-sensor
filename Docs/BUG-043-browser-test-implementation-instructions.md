# BUG-043 Browser Regression Tests — Implementation Instructions

_For assistant implementation. Self-contained prompt._

---

## Context

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

After BUG-043 resolution, browser-side regression tests are needed to catch JavaScript request-scheduling regressions that contributed to dashboard instability. These tests run against the Playwright mock server and catch JS-level issues — they do NOT replace real-device validation.

**Reference:** `Docs/BUG-043-post-PR41-test-plans.md` (Proposed Browser / Playwright Tests section)

---

## Required reading before implementation

1. `tests/browser/dashboard.spec.js` — existing test groups and patterns
2. `tests/mock-server/server.js` — existing mock routes and response patterns
3. `tests/fixtures/` — fixture structure
4. `playwright.config.js` — test configuration
5. `Docs/BUG-043-post-PR41-test-plans.md` — proposed test specifications
6. `dashboard/dashboard.js` — boot sequence, loadHistory, pollAll, connectSSE, loadStatusSnapshot, loadStorageStats

---

## Tests to implement

Add a new test group to `tests/browser/dashboard.spec.js`. Use the existing `loadDashboard()` and `waitForConnected()` helpers.

### Group N: BUG-043 Request Scheduling Regression Tests

#### Test 1: No duplicate manifest fetch at boot

**What to test:** During boot, `/api/manifest` should be fetched exactly once (not twice).

**How to implement:**
```javascript
test('boot fetches /api/manifest exactly once', async ({ page }) => {
  const manifestRequests = [];
  page.on('request', req => {
    if (req.url().includes('/api/manifest')) manifestRequests.push(req);
  });
  await loadDashboard(page);
  await waitForConnected(page);
  // Wait for boot to settle
  await page.waitForTimeout(3000);
  expect(manifestRequests.length).toBe(1);
});
```

#### Test 2: History fetches are sequential (not concurrent)

**What to test:** History endpoints (`/history/*/temp`, `/history/*/hum`) should never have more than 1 request in flight at a time.

**How to implement:**
```javascript
test('history fetches are sequential — max 1 concurrent', async ({ page }) => {
  let maxConcurrent = 0;
  let currentInFlight = 0;
  
  page.on('request', req => {
    if (req.url().includes('/history/')) {
      currentInFlight++;
      if (currentInFlight > maxConcurrent) maxConcurrent = currentInFlight;
    }
  });
  page.on('response', resp => {
    if (resp.url().includes('/history/')) {
      currentInFlight--;
    }
  });
  
  await loadDashboard(page);
  // Wait for history bootstrap (t+10s in production, faster with mock)
  await page.waitForTimeout(15000);
  
  expect(maxConcurrent).toBeLessThanOrEqual(1);
});
```

**Mock server consideration:** The mock server responds instantly. To make concurrency observable, add a small delay (50-100ms) to history endpoint responses in the mock server:
```javascript
// In server.js, for /history/* routes:
await new Promise(resolve => setTimeout(resolve, 50));
```

#### Test 3: loadHistory in-flight guard prevents double invocation

**What to test:** If `loadHistory()` is called while already in flight, the second call should be rejected.

**How to implement:**
```javascript
test('loadHistory rejects concurrent invocations', async ({ page }) => {
  await loadDashboard(page);
  await waitForConnected(page);
  
  // Call loadHistory twice rapidly via page.evaluate
  const results = await page.evaluate(() => {
    return Promise.all([
      App.API.loadHistory(),
      App.API.loadHistory()
    ]);
  });
  
  // One should return false (skipped)
  expect(results).toContain(false);
});
```

#### Test 4: _historyInFlight resets after failure

**What to test:** If history loading fails, the in-flight guard resets so a later attempt succeeds.

**How to implement:**
```javascript
test('history in-flight guard resets after failure', async ({ page }) => {
  await loadDashboard(page);
  await waitForConnected(page);
  
  // Sabotage history endpoint temporarily (via page.route intercept)
  await page.route('**/history/**', route => route.abort());
  
  // Trigger history load — should fail
  await page.evaluate(() => App.API.loadHistory());
  await page.waitForTimeout(5000);
  
  // Restore history endpoint
  await page.unroute('**/history/**');
  
  // Should be able to load again (guard must have reset)
  const result = await page.evaluate(() => App.API.loadHistory());
  // Should not return false (not blocked by guard)
  expect(result).not.toBe(false);
});
```

#### Test 5: SSE mode boot does not fire loadStatusSnapshot from ping/onopen

**What to test:** In SSE mode, the `ping` and `onopen` handlers must NOT trigger `/api/status` fetches.

**How to implement:**
```javascript
test('SSE ping/onopen handlers do not fetch /api/status', async ({ page }) => {
  const statusRequests = [];
  page.on('request', req => {
    if (req.url().includes('/api/status')) statusRequests.push({ url: req.url(), time: Date.now() });
  });
  
  await loadDashboard(page);
  await waitForConnected(page);
  
  // Wait for SSE to send several pings
  await page.waitForTimeout(15000);
  
  // Should have at most 1-2 status requests (the deferred boot one),
  // not 10+ (which would indicate ping handler is firing)
  expect(statusRequests.length).toBeLessThanOrEqual(3);
});
```

#### Test 6: Polling mode startup is sequential (no concurrent batch)

**What to test:** In polling mode, the initial `pollAll` must fire requests one at a time (batch=1).

**How to implement:** This requires running the dashboard in polling mode. The mock server should be accessed via a different URL/config that triggers polling transport.

```javascript
test('polling startup uses sequential requests', async ({ page }) => {
  let maxConcurrent = 0;
  let currentInFlight = 0;
  
  page.on('request', req => {
    const url = req.url();
    if (url.includes('/sensor/') || url.includes('/text_sensor/') || url.includes('/binary_sensor/')) {
      currentInFlight++;
      if (currentInFlight > maxConcurrent) maxConcurrent = currentInFlight;
    }
  });
  page.on('response', resp => {
    const url = resp.url();
    if (url.includes('/sensor/') || url.includes('/text_sensor/') || url.includes('/binary_sensor/')) {
      currentInFlight--;
    }
  });
  
  // Load in polling mode (mock server with https or FILE_FALLBACK_HOST)
  await loadDashboard(page, { pollingMode: true });
  await page.waitForTimeout(12000);
  
  // batch=1 means max 1 concurrent entity request
  expect(maxConcurrent).toBeLessThanOrEqual(1);
});
```

#### Test 7: No /favicon.ico request from dashboard

**What to test:** The inline favicon prevents the browser from requesting `/favicon.ico`.

**How to implement:**
```javascript
test('no /favicon.ico request from dashboard', async ({ page }) => {
  const faviconRequests = [];
  page.on('request', req => {
    if (req.url().includes('/favicon.ico')) faviconRequests.push(req);
  });
  
  await loadDashboard(page);
  await waitForConnected(page);
  await page.waitForTimeout(3000);
  
  expect(faviconRequests.length).toBe(0);
});
```

#### Test 8: Boot timing — manifest before anything else

**What to test:** The first HTTP request after page load should be `/api/manifest`.

**How to implement:**
```javascript
test('manifest is first HTTP request at boot', async ({ page }) => {
  const requests = [];
  page.on('request', req => {
    const url = new URL(req.url());
    if (url.pathname.startsWith('/api/') || url.pathname.startsWith('/history/') || 
        url.pathname.startsWith('/sensor/') || url.pathname === '/events') {
      requests.push(url.pathname);
    }
  });
  
  await loadDashboard(page);
  await page.waitForTimeout(2000);
  
  expect(requests.length).toBeGreaterThan(0);
  expect(requests[0]).toBe('/api/manifest');
});
```

---

## Mock server changes needed

Add to `tests/mock-server/server.js`:

1. **History endpoint delay** — add 50ms delay to `/history/*` responses to make concurrency observable
2. **SSE ping interval** — if not already sending pings, add periodic ping events (~3s) to the `/events` SSE stream

---

## Critical rules

1. Add tests as a new test group in `tests/browser/dashboard.spec.js`
2. Use existing `loadDashboard()` and `waitForConnected()` helpers
3. All existing tests must still pass (regression gate)
4. Run `npx playwright test --project=chromium` to verify
5. Tests must work against the mock server (not real device)
6. Use `page.waitForTimeout()` for timing-sensitive tests — avoid flaky assertions on exact request counts; use `toBeLessThanOrEqual` for reasonable bounds
7. Update `Docs/changelog.md` and create a session log

---

## What these tests CANNOT catch

- Actual ESP32-C3 watchdog starvation (requires real device)
- TCP buffer pressure from large responses (mock server has unlimited bandwidth)
- NVS scan blocking duration (mock server responds instantly)
- The gzip/transfer-size issue (mock server has zero transfer delay)

These require real-device validation per LESSON-OPS-051.

