/**
 * tests/browser/history-charts.spec.js
 * History loading, chart rendering, custom date range, and request-scheduling tests.
 *
 * Groups from dashboard.spec.js:
 *    4. History and charts
 *    5. Custom date range
 *   13. Manifest-driven history fetching
 *   16. BUG-043 Request Scheduling Regression
 */

'use strict';

const { test, expect } = require('@playwright/test');
const { loadDashboard, stopDashboardNetwork, waitForConnected } = require('./test-helpers');

test.afterEach(async ({ page }) => {
  await stopDashboardNetwork(page);
});

// ── 4. History and charts ─────────────────────────────────────────

test.describe('4. History and charts', () => {
  test('history loads and point count updates from zero', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => {
      const el = document.getElementById('pointCount');
      return el && el.textContent.includes('data points') && !el.textContent.startsWith('0');
    }, { timeout: 12000 });
    const text = await page.locator('#pointCount').textContent();
    expect(text).toMatch(/\d+ data points/);
    expect(parseInt(text)).toBeGreaterThan(0);
  });

  test('range buttons exist for all five presets including Custom', async ({ page }) => {
    await loadDashboard(page);
    // Range values are in hours: 24h=24, 7d=168, 30d=720, 45d=1080, custom
    for (const range of ['24', '168', '720', '1080', 'custom']) {
      await expect(page.locator(`[data-history-range="${range}"]`).first()).toBeVisible();
    }
  });

  test('clicking range buttons does not crash the page', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);
    for (const range of ['168', '720', '1080', '24']) {
      await page.locator(`[data-history-range="${range}"]`).first().click();
      await page.waitForTimeout(300);
    }
    expect(pageError).toBeNull();
  });

  test('chart canvases are rendered in chart sections', async ({ page }) => {
    await loadDashboard(page);
    // Charts live in .chart-card divs, NOT inside .sensor-card
    await page.waitForFunction(() => {
      const el = document.getElementById('pointCount');
      return el && el.textContent.includes('data points');
    }, { timeout: 12000 });
    // Check the four named chart canvases exist and are attached
    for (const id of ['tempChart', 'humChart', 'tempAvgChart', 'humAvgChart']) {
      await expect(page.locator(`#${id}`)).toBeAttached();
    }
  });

  test('history badge updates from loading state', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => {
      const el = document.getElementById('histBadge');
      return el && !el.textContent.includes('loading');
    }, { timeout: 12000 });
    expect(await page.locator('#histBadge').textContent()).not.toContain('loading');
  });
});

// ── 5. Custom date range ──────────────────────────────────────────

test.describe('5. Custom date range', () => {
  test('Custom button opens the date range modal', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    await expect(page.locator('#customRangeModal')).toBeVisible({ timeout: 3000 });
  });

  test('modal contains calendar and Apply/Cancel buttons', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    const modal = page.locator('#customRangeModal');
    await expect(modal).toBeVisible();
    await expect(modal.locator('#crCalGrid')).toBeVisible();
    await expect(modal.locator('#customRangeApply')).toBeVisible();
    await expect(modal.locator('#customRangeCancel')).toBeVisible();
  });

  test('modal displays data availability from storage-stats', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    await expect(page.locator('#customRangeAvail')).toBeVisible();
    const text = await page.locator('#customRangeAvail').textContent();
    expect(text).not.toContain('unknown');
  });

  test('Cancel closes the modal without changing range', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    await expect(page.locator('#customRangeModal')).toBeVisible();
    await page.locator('#customRangeCancel').click();
    await expect(page.locator('#customRangeModal')).toBeHidden({ timeout: 2000 });
  });

  test('calendar month navigation works', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    await expect(page.locator('#customRangeModal')).toBeVisible();
    const before = await page.locator('#crCalHeader').textContent();
    await page.locator('#crPrev').click();
    const after = await page.locator('#crCalHeader').textContent();
    expect(after).not.toBe(before);
  });

  test('clicking a preset applies range and closes modal', async ({ page }) => {
    // Preset buttons call _applyAndClose() directly — no separate Apply click needed
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    await expect(page.locator('#customRangeModal')).toBeVisible();
    // Clicking preset immediately applies and closes — do not click Apply afterwards
    await page.locator('[data-cr-preset="7d"]').click();
    await expect(page.locator('#customRangeModal')).toBeHidden({ timeout: 3000 });
    expect(pageError).toBeNull();
  });

  test('standard range buttons clear custom range state', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);
    // Activate custom range via preset (preset closes modal itself)
    await page.locator('[data-history-range="custom"]').first().click();
    await page.locator('[data-cr-preset="7d"]').click();
    await expect(page.locator('#customRangeModal')).toBeHidden({ timeout: 3000 });
    // Click standard range — should not crash
    await page.locator('[data-history-range="24"]').first().click();
    await page.waitForTimeout(300);
    expect(pageError).toBeNull();
  });
});

// ── 13. Manifest-driven history fetching ─────────────────────────

test.describe('13. Manifest-driven history fetching', () => {
  // BUG-049: Firefox's slower event loop + SSE teardown requires longer
  // timeouts.  90s test timeout accounts for ~49s worst-case SSE teardown.
  // 30s loadDashboard timeout accounts for slower Gecko DOM rendering.
  test.setTimeout(90000);

  test('fetchDeviceHistory is a callable function', async ({ page }) => {
    await loadDashboard(page, { timeout: 30000 });
    const ok = await page.evaluate(() => typeof fetchDeviceHistory === 'function');
    expect(ok).toBe(true);
  });

  test('App.API.fetchDeviceHistory is exported', async ({ page }) => {
    await loadDashboard(page, { timeout: 30000 });
    const ok = await page.evaluate(() => typeof App.API.fetchDeviceHistory === 'function');
    expect(ok).toBe(true);
  });

  test('fetchDeviceHistory uses history_url from manifest measurements', async ({ page }) => {
    await loadDashboard(page, { timeout: 30000 });

    // Intercept subsequent history requests (after initial page load)
    const requestedUrls = [];
    await page.route('**/history/**', (route) => {
      requestedUrls.push(new URL(route.request().url()).pathname);
      route.fulfill({ status: 200, contentType: 'text/plain', body: '1700000000,22.5\n' });
    });

    // Explicitly wait for both expected requests to arrive before asserting.
    // fetchDeviceHistory() issues requests sequentially with a 300ms gap; using
    // Promise.all + waitForRequest guarantees the route callbacks have fired in
    // both Chromium and Firefox before we check requestedUrls.
    await Promise.all([
      page.waitForRequest(req => req.url().includes('/history/office/temp')),
      page.waitForRequest(req => req.url().includes('/history/office/hum')),
      page.evaluate(() => fetchDeviceHistory({ id: 'office', name: 'Office' }, window._manifest)),
    ]);

    // Manifest has history_url: '/history/office/temp' and '/history/office/hum'
    expect(requestedUrls).toContain('/history/office/temp');
    expect(requestedUrls).toContain('/history/office/hum');
  });

  test('fetchDeviceHistory falls back to legacy URLs when manifest is null', async ({ page }) => {
    await loadDashboard(page, { timeout: 30000 });

    const requestedUrls = [];
    await page.route('**/history/**', (route) => {
      requestedUrls.push(new URL(route.request().url()).pathname);
      route.fulfill({ status: 200, contentType: 'text/plain', body: '' });
    });

    // Call fetchDeviceHistory with null manifest — should fall back to /history/{id}/temp and /history/{id}/hum
    await page.evaluate(() => {
      return fetchDeviceHistory({ id: 'office', name: 'Office' }, null);
    });

    expect(requestedUrls).toContain('/history/office/temp');
    expect(requestedUrls).toContain('/history/office/hum');
  });

  test('fetchDeviceHistory falls back to legacy URLs when manifest has no matching sensor', async ({ page }) => {
    await loadDashboard(page, { timeout: 30000 });

    const requestedUrls = [];
    await page.route('**/history/**', (route) => {
      requestedUrls.push(new URL(route.request().url()).pathname);
      route.fulfill({ status: 200, contentType: 'text/plain', body: '' });
    });

    // Explicitly wait for both legacy-fallback requests to arrive before asserting.
    await Promise.all([
      page.waitForRequest(req => req.url().includes('/history/test-sensor/temp')),
      page.waitForRequest(req => req.url().includes('/history/test-sensor/hum')),
      page.evaluate(() => {
        var sensor = { id: 'test-sensor', name: 'Test Sensor' };
        var emptyManifest = { schema_version: 2, sensors: [], metrics: [] };
        return fetchDeviceHistory(sensor, emptyManifest);
      }),
    ]);

    expect(requestedUrls).toContain('/history/test-sensor/temp');
    expect(requestedUrls).toContain('/history/test-sensor/hum');
  });
});

// ── 16. BUG-043 Request Scheduling Regression ─────────────────────
//
// These tests catch JavaScript-level request scheduling regressions that
// contributed to ESP32-C3 dashboard instability (BUG-043).
// They run against the mock server and cover request ordering, concurrency
// guards, and boot timing. They do NOT replace real-device validation —
// transfer-size, NVS blocking, and watchdog starvation require on-device tests.
//
// Related: Docs/BUG-043-browser-test-implementation-instructions.md

test.describe('16. BUG-043 Request Scheduling Regression', () => {

  // Test 1: /api/manifest fetched exactly once during boot
  test('boot fetches /api/manifest exactly once', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'aggregator',
      'Aggregator boot calls /api/manifest twice (loadManifestV2 + loadSensorManifest fallback chain); "exactly once" constraint is satellite-specific.');
    const manifestRequests = [];
    page.on('request', req => {
      if (req.url().includes('/api/manifest')) manifestRequests.push(req);
    });
    await loadDashboard(page);
    await waitForConnected(page);
    await page.waitForTimeout(3000);
    expect(manifestRequests.length).toBe(1);
  });

  // Test 2: History fetches are sequential (max 1 concurrent)
  // Mock server adds 50ms delay to history responses to make concurrency observable.
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
    await waitForConnected(page);
    // Wait for history bootstrap to complete (t+10s in production, mock is faster)
    await page.waitForTimeout(15000);

    expect(maxConcurrent).toBeLessThanOrEqual(1);
  });

  // Test 3: loadHistory in-flight guard prevents double invocation
  test('loadHistory rejects concurrent invocations', async ({ page }) => {
    await loadDashboard(page);
    await waitForConnected(page);
    // Call loadHistory twice rapidly — one should return false (skipped)
    const results = await page.evaluate(() => {
      return Promise.all([
        App.API.loadHistory(),
        App.API.loadHistory()
      ]);
    });
    expect(results).toContain(false);
  });

  // Test 4: _historyInFlight guard resets after failure so retry works
  test('history in-flight guard resets after failure', async ({ page }) => {
    await loadDashboard(page);
    await waitForConnected(page);

    // Intercept and abort history requests to force failure
    await page.route('**/history/**', route => route.abort());

    // Trigger history load — should fail
    await page.evaluate(() => { try { var r = App.API.loadHistory(); if (r && typeof r.catch === 'function') r.catch(function() {}); } catch(e) {} });
    await page.waitForTimeout(3000);

    // Restore history endpoint
    await page.unroute('**/history/**');

    // Should be able to load again (guard must have reset)
    const result = await page.evaluate(() => App.API.loadHistory());
    // result should NOT be false (not blocked by stale guard)
    expect(result).not.toBe(false);
  });

  // Test 5: SSE ping/onopen handlers do not fire /api/status
  test('SSE ping/onopen handlers do not fetch /api/status', async ({ page }) => {
    const statusRequests = [];
    page.on('request', req => {
      if (req.url().includes('/api/status')) statusRequests.push({ url: req.url(), time: Date.now() });
    });

    await loadDashboard(page);
    await waitForConnected(page);

    // Wait for SSE to send several pings (~2s interval × 7 = ~14s)
    await page.waitForTimeout(15000);

    // Should have at most 2-3 status requests (deferred boot + maybe 1 poll cycle),
    // NOT 10+ (which would indicate ping/onopen handlers are firing loadStatusSnapshot)
    expect(statusRequests.length).toBeLessThanOrEqual(3);
  });

  // Test 6: No /favicon.ico request from dashboard (inline favicon prevents it)
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

  // Test 7: Manifest is the first API/data HTTP request at boot
  test('manifest is first HTTP request at boot', async ({ page }) => {
    const requests = [];
    page.on('request', req => {
      const u = new URL(req.url());
      if (u.pathname.startsWith('/api/') || u.pathname.startsWith('/history/') ||
          u.pathname.startsWith('/sensor/') || u.pathname === '/events' ||
          u.pathname === '/sensors.json') {
        requests.push(u.pathname);
      }
    });

    await loadDashboard(page);
    await page.waitForTimeout(2000);

    expect(requests.length).toBeGreaterThan(0);
    // v7.5.5.3: detectAggregatorMode() probes /api/aggregator/gateways first (404 on satellites).
    // Filter it out to preserve the original BUG-043 intent: manifest before entity polling.
    const apiRequests = requests.filter(r => r !== '/api/aggregator/gateways');
    expect(apiRequests.length).toBeGreaterThan(0);
    expect(apiRequests[0]).toBe('/api/manifest');
  });

  // Test 8: loadStorageStats in-flight guard prevents concurrent calls
  test('loadStorageStats rejects concurrent invocations', async ({ page }) => {
    await loadDashboard(page);
    await waitForConnected(page);
    // Call loadStorageStats twice rapidly — second should be suppressed
    const results = await page.evaluate(() => {
      return Promise.all([
        App.API.loadStorageStats(),
        App.API.loadStorageStats()
      ]);
    });
    // At least one should return null (skipped by guard)
    expect(results).toContain(null);
  });
});
