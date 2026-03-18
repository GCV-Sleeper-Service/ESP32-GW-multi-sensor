/**
 * tests/browser/dashboard.spec.js
 * Browser regression suite for the ESP32 gateway dashboard.
 *
 * Element ID / DOM reference (verified against actual dashboard HTML):
 *   Theme button:      #themeBtn  — class 'light' goes on <html> (documentElement), NOT <body>
 *   Apply button:      #customRangeApply
 *   Cancel button:     #customRangeCancel
 *   Prev month:        #crPrev  /  Month label: #crCalHeader
 *   Range values:      24, 168 (7d), 720 (30d), 1080 (45d), custom  — in hours
 *   Export all:        [data-export-all]  /  Per-sensor: [data-export-sensor]
 *   Card names:        text node inside .sensor-card-header (no dedicated title class)
 *   Chart canvases:    inside .chart-card divs, NOT inside .sensor-card
 *   Preset buttons:    [data-cr-preset] — clicking applies AND closes modal immediately
 *                      (no separate Apply click needed after a preset)
 */

'use strict';

const { test, expect } = require('@playwright/test');

async function loadDashboard(page, opts = {}) {
  const timeout = opts.timeout || 15000;
  page._consoleErrors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') page._consoleErrors.push(msg.text());
  });
  await page.goto('/', { waitUntil: 'domcontentloaded' });
  await page.locator('.sensor-card').first().waitFor({ state: 'visible', timeout });
}

async function waitForConnected(page, timeout = 10000) {
  await page.locator('#statusDot.connected').waitFor({ state: 'attached', timeout });
}

// Firefox SSE teardown fix: navigate away to close EventSource before context.close()
test.afterEach(async ({ page }) => { await page.goto("about:blank"); });

// ── 1. Boot and structure ─────────────────────────────────────────

test.describe('1. Boot and structure', () => {
  test('page loads without crashing', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);
    expect(pageError).toBeNull();
  });

  test('version string is present in the DOM', async ({ page }) => {
    await loadDashboard(page);
    const modeLabel = page.locator('#modeLabel');
    await expect(modeLabel).toBeVisible();
    expect(await modeLabel.textContent()).toMatch(/\[.+\s+mode\]/i);
  });

  test('dark mode is the default theme', async ({ page }) => {
    await loadDashboard(page);
    // Theme class is on <html> (documentElement), not <body>
    const cls = await page.locator('html').getAttribute('class') || '';
    expect(cls).not.toContain('light');
  });

  test('all primary UI sections are present', async ({ page }) => {
    await loadDashboard(page);
    await expect(page.locator('#histBadge')).toBeVisible();
    await expect(page.locator('#pointCount')).toBeVisible();
    await expect(page.locator('#statusDot')).toBeVisible();
    await expect(page.locator('#themeBtn')).toBeVisible();
  });
});

// ── 2. Sensor cards ───────────────────────────────────────────────

test.describe('2. Sensor cards', () => {
  test('three sensor cards are rendered', async ({ page }) => {
    await loadDashboard(page);
    await expect(page.locator('.sensor-card')).toHaveCount(3);
  });

  test('sensor card headers contain expected sensor names', async ({ page }) => {
    await loadDashboard(page);
    // Name is a raw text node inside .sensor-card-header — no dedicated title class
    for (const name of ['Office', 'First Floor', 'Outside']) {
      await expect(
        page.locator('.sensor-card-header').filter({ hasText: name }).first()
      ).toBeVisible();
    }
  });

  test('each sensor card contains value display elements', async ({ page }) => {
    await loadDashboard(page);
    const cards = page.locator('.sensor-card');
    const count = await cards.count();
    for (let i = 0; i < count; i++) {
      expect(await cards.nth(i).locator('[id^="val-"]').count()).toBeGreaterThan(0);
    }
  });
});

// ── 3. Transport / status ─────────────────────────────────────────

test.describe('3. Transport / status', () => {
  test('dashboard reaches connected state', async ({ page }) => {
    await loadDashboard(page);
    await waitForConnected(page, 10000);
    expect(await page.locator('#statusText').textContent()).toMatch(/connected/i);
  });

  test('status dot has connected class after connection', async ({ page }) => {
    await loadDashboard(page);
    await waitForConnected(page);
    await expect(page.locator('#statusDot')).toHaveClass(/connected/);
  });
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

// ── 6. Theme toggle ───────────────────────────────────────────────

test.describe('6. Theme toggle', () => {
  test('clicking theme toggle switches to light mode', async ({ page }) => {
    await loadDashboard(page);
    // Theme class is toggled on <html> (documentElement), not <body>
    await expect(page.locator('html')).not.toHaveClass(/light/);
    await page.locator('#themeBtn').click();
    await expect(page.locator('html')).toHaveClass(/light/);
  });

  test('clicking theme toggle twice returns to dark mode', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('#themeBtn').click();
    await page.locator('#themeBtn').click();
    await expect(page.locator('html')).not.toHaveClass(/light/);
  });

  test('theme toggle does not crash the page', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);
    await page.locator('#themeBtn').click();
    await page.waitForTimeout(500);
    await page.locator('#themeBtn').click();
    await page.waitForTimeout(500);
    expect(pageError).toBeNull();
  });
});

// ── 7. Export controls ────────────────────────────────────────────

test.describe('7. Export controls', () => {
  test('Export All button is visible', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => !!document.querySelector('[data-export-all]'), { timeout: 10000 });
    await expect(page.locator('[data-export-all]')).toBeVisible();
  });

  test('per-sensor export buttons are visible', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => {
      return document.querySelectorAll('[data-export-sensor]').length >= 3;
    }, { timeout: 10000 });
    expect(await page.locator('[data-export-sensor]').count()).toBeGreaterThanOrEqual(3);
  });

  test('clicking Export All does not crash', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);
    await page.waitForFunction(() => {
      const el = document.getElementById('pointCount');
      return el && el.textContent.includes('data points') && !el.textContent.startsWith('0');
    }, { timeout: 12000 });
    await page.waitForFunction(() => !!document.querySelector('[data-export-all]'), { timeout: 10000 });
    await page.locator('[data-export-all]').first().click();
    await page.waitForTimeout(1000);
    expect(pageError).toBeNull();
  });
});

// ── 8. Console error guard ────────────────────────────────────────

test.describe('8. Console error guard', () => {
  test('no unexpected JS errors during normal session startup', async ({ page }) => {
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push(msg.text());
    });
    page.on('pageerror', err => errors.push('PAGEERROR: ' + err.message));

    await loadDashboard(page);
    await waitForConnected(page, 10000);
    await page.waitForTimeout(4000);

    const unexpected = errors.filter(e => {
      if (e.includes('favicon')) return false;
      if (e.includes('404') && e.includes('/text_sensor/')) return false;
      if (e.includes('404') && e.includes('/sensor/')) return false;
      return true;
    });

    if (unexpected.length > 0) console.log('Unexpected console errors:', unexpected);
    expect(unexpected).toHaveLength(0);
  });
});

// ── 9. Manifest v2 loader ─────────────────────────────────────────

test.describe('9. Manifest v2 loader', () => {
  test('window._manifest is set after boot', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => typeof window._manifest !== 'undefined' && window._manifest !== null, { timeout: 10000 });
    const manifest = await page.evaluate(() => window._manifest);
    expect(manifest).not.toBeNull();
    expect(manifest.ok).toBe(true);
  });

  test('window._manifest has correct schema_version', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => window._manifest && window._manifest.schema_version === 2, { timeout: 10000 });
    const schemaVersion = await page.evaluate(() => window._manifest.schema_version);
    expect(schemaVersion).toBe(2);
  });

  test('window._manifest contains sensors array', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => window._manifest && Array.isArray(window._manifest.sensors), { timeout: 10000 });
    const sensors = await page.evaluate(() => window._manifest.sensors.map(s => s.id));
    expect(sensors).toEqual(['office', 'first_floor', 'outside']);
  });

  test('window._manifest contains gateway block', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => window._manifest && window._manifest.gateway, { timeout: 10000 });
    const gateway = await page.evaluate(() => window._manifest.gateway);
    expect(gateway.role).toBe('satellite');
    expect(gateway.api_version).toBe('v2');
  });

  test('window._manifest contains metrics array', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => window._manifest && Array.isArray(window._manifest.metrics), { timeout: 10000 });
    const metricKeys = await page.evaluate(() => window._manifest.metrics.map(m => m.key));
    expect(metricKeys).toEqual(['temp', 'hum']);
  });
});

// ── 10. Manifest v2 fallback chain ───────────────────────────────

test.describe('10. Manifest v2 fallback chain', () => {
  test('dashboard loads and window._manifest is auto-promoted when /api/manifest returns 404', async ({ page }) => {
    await page.route('**/api/manifest', async route => {
      await route.fulfill({ status: 404, contentType: 'application/json', body: JSON.stringify({ ok: false }) });
    });
    await loadDashboard(page);
    await page.waitForFunction(() => window._manifest && window._manifest.schema_version === 2, { timeout: 10000 });
    const source = await page.evaluate(() => window._manifest.source);
    expect(source).toBe('auto-promoted');
    const sensors = await page.evaluate(() => App.State.getSensors().map(s => s.id));
    expect(sensors.length).toBeGreaterThan(0);
  });

  test('loadManifestV2 and autoPromoteV1ToV2 are accessible on window', async ({ page }) => {
    await loadDashboard(page);
    const hasFns = await page.evaluate(() => typeof loadManifestV2 === 'function' && typeof autoPromoteV1ToV2 === 'function');
    expect(hasFns).toBe(true);
  });
});

// ── 11. Card renderer registry (v7.5.2.1) ────────────────────────

test.describe('11. Card renderer registry', () => {
  test('CARD_RENDERERS registry exists with environmental and _default entries', async ({ page }) => {
    await loadDashboard(page);
    const hasRegistry = await page.evaluate(() => {
      return typeof CARD_RENDERERS === 'object' &&
        typeof CARD_RENDERERS.environmental === 'function' &&
        typeof CARD_RENDERERS._default === 'function';
    });
    expect(hasRegistry).toBe(true);
  });

  test('buildDeviceCards and buildEnvironmentalCard are accessible', async ({ page }) => {
    await loadDashboard(page);
    const hasFns = await page.evaluate(() => {
      return typeof buildDeviceCards === 'function' &&
        typeof buildEnvironmentalCard === 'function';
    });
    expect(hasFns).toBe(true);
  });

  test('buildSensorCards is still a callable function (compatibility alias)', async ({ page }) => {
    await loadDashboard(page);
    const hasAlias = await page.evaluate(() => typeof buildSensorCards === 'function');
    expect(hasAlias).toBe(true);
  });

  test('environmental renderer dispatches correctly and produces sensor cards', async ({ page }) => {
    await loadDashboard(page);
    // Wait for manifest and cards
    await page.waitForFunction(() => window._manifest && window._manifest.sensors, { timeout: 10000 });
    // Re-invoke buildDeviceCards and verify cards are rebuilt without error
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await page.evaluate(() => buildDeviceCards());
    await page.locator('.sensor-card').first().waitFor({ state: 'visible', timeout: 5000 });
    await expect(page.locator('.sensor-card')).toHaveCount(3);
    expect(pageError).toBeNull();
  });

  test('environmental renderer produces full card structure (temp, hum, minmax, batt, rssi)', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => window._manifest && window._manifest.sensors, { timeout: 10000 });
    const card = page.locator('.sensor-card').first();
    await expect(card.locator('.sensor-card-header')).toBeVisible();
    await expect(card.locator('.sensor-readings')).toBeVisible();
    await expect(card.locator('.sensor-env-grid')).toBeVisible();
    await expect(card.locator('.sensor-minmax')).toBeVisible();
    await expect(card.locator('.sensor-batt-row')).toBeVisible();
    await expect(card.locator('.sensor-rssi-row')).toBeVisible();
  });

  test('_default renderer handles unknown category gracefully without crashing', async ({ page }) => {
    await loadDashboard(page);
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    // Call the _default renderer directly with a minimal device object
    const result = await page.evaluate(() => {
      try {
        var html = CARD_RENDERERS._default({ id: 'test-unknown', name: 'Test Device', foo: 'bar' }, null);
        return { ok: typeof html === 'string' && html.length > 0, html: html };
      } catch(e) {
        return { ok: false, error: e.message };
      }
    });
    expect(result.ok).toBe(true);
    expect(pageError).toBeNull();
  });

  test('App.Render exposes buildDeviceCards and buildEnvironmentalCard', async ({ page }) => {
    await loadDashboard(page);
    const hasExports = await page.evaluate(() => {
      return typeof App.Render.buildDeviceCards === 'function' &&
        typeof App.Render.buildEnvironmentalCard === 'function';
    });
    expect(hasExports).toBe(true);
  });
});

// ── 12. Metric formatter registry ────────────────────────────────

test.describe('12. Metric formatter registry', () => {
  test('METRIC_FORMATTERS registry exists with temperature, humidity, and _default entries', async ({ page }) => {
    await loadDashboard(page);
    const result = await page.evaluate(() => {
      return {
        hasTemperature: typeof METRIC_FORMATTERS.temperature === 'function',
        hasHumidity: typeof METRIC_FORMATTERS.humidity === 'function',
        hasDefault: typeof METRIC_FORMATTERS._default === 'function'
      };
    });
    expect(result.hasTemperature).toBe(true);
    expect(result.hasHumidity).toBe(true);
    expect(result.hasDefault).toBe(true);
  });

  test('formatMetricValue is a callable function', async ({ page }) => {
    await loadDashboard(page);
    const ok = await page.evaluate(() => typeof formatMetricValue === 'function');
    expect(ok).toBe(true);
  });

  test('formatMetricValue formats temperature with °C/°F output', async ({ page }) => {
    await loadDashboard(page);
    const result = await page.evaluate(() => {
      return formatMetricValue('temperature', 22.5, { unit: 'celsius', unit_symbol: '\u00b0C' });
    });
    expect(result).toBe('22.5 \u00b0C / 72.5 \u00b0F');
  });

  test('formatMetricValue formats humidity with rounded % output', async ({ page }) => {
    await loadDashboard(page);
    const result = await page.evaluate(() => {
      return formatMetricValue('humidity', 55.3, { unit: 'percent', unit_symbol: '%' });
    });
    expect(result).toBe('55 %');
  });

  test('formatMetricValue falls back to _default for unknown metric key', async ({ page }) => {
    await loadDashboard(page);
    const result = await page.evaluate(() => {
      return formatMetricValue('unknown_metric', 42.0, { unit: 'ppm', unit_symbol: 'ppm' });
    });
    expect(result).toBe('42.0 ppm');
  });

  test('formatMetricValue handles null metric_def gracefully', async ({ page }) => {
    await loadDashboard(page);
    const result = await page.evaluate(() => {
      return formatMetricValue('temperature', 20.0, null);
    });
    // Without unit info, temperature formatter falls back to default unit path
    expect(typeof result).toBe('string');
    expect(result).toContain('20.0');
  });
});

// ── 13. Manifest-driven history fetching ─────────────────────────

test.describe('13. Manifest-driven history fetching', () => {
  test('fetchDeviceHistory is a callable function', async ({ page }) => {
    await loadDashboard(page);
    const ok = await page.evaluate(() => typeof fetchDeviceHistory === 'function');
    expect(ok).toBe(true);
  });

  test('App.API.fetchDeviceHistory is exported', async ({ page }) => {
    await loadDashboard(page);
    const ok = await page.evaluate(() => typeof App.API.fetchDeviceHistory === 'function');
    expect(ok).toBe(true);
  });

  test('fetchDeviceHistory uses history_url from manifest measurements', async ({ page }) => {
    await loadDashboard(page);

    // Intercept subsequent history requests (after initial page load)
    const requestedUrls = [];
    await page.route('**/history/**', (route) => {
      requestedUrls.push(new URL(route.request().url()).pathname);
      route.fulfill({ status: 200, contentType: 'text/plain', body: '1700000000,22.5\n' });
    });

    // Call fetchDeviceHistory with a sensor that exists in window._manifest
    await page.evaluate(() => {
      return fetchDeviceHistory({ id: 'office', name: 'Office' }, window._manifest);
    });

    // Manifest has history_url: '/history/office/temp' and '/history/office/hum'
    expect(requestedUrls).toContain('/history/office/temp');
    expect(requestedUrls).toContain('/history/office/hum');
  });

  test('fetchDeviceHistory falls back to legacy URLs when manifest is null', async ({ page }) => {
    await loadDashboard(page);

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
    await loadDashboard(page);

    const requestedUrls = [];
    await page.route('**/history/**', (route) => {
      requestedUrls.push(new URL(route.request().url()).pathname);
      route.fulfill({ status: 200, contentType: 'text/plain', body: '' });
    });

    // Call with a manifest that has no sensor matching 'test-sensor'
    const ok = await page.evaluate(() => {
      var sensor = { id: 'test-sensor', name: 'Test Sensor' };
      var emptyManifest = { schema_version: 2, sensors: [], metrics: [] };
      return fetchDeviceHistory(sensor, emptyManifest)
        .then(function() { return true; })
        .catch(function() { return false; });
    });

    expect(ok).toBe(true);
    expect(requestedUrls).toContain('/history/test-sensor/temp');
    expect(requestedUrls).toContain('/history/test-sensor/hum');
  });
});

// ── 14. Phase 2 Closure — Full Regression ────────────────────────
//
// Comprehensive eight-scenario regression covering Phase 2 closure:
//   1. Renders correctly when /api/manifest returns full v2 manifest
//   2. Renders correctly when /api/manifest returns 404 (fallback to /sensors.json)
//   3. Renders correctly when both /api/manifest and /sensors.json fail (hardcoded defaults)
//   4. Environmental card renderer dispatches correctly
//   5. _default card renderer handles unknown category gracefully
//   6. Metric formatters produce correct temperature output (°C / °F)
//   7. fetchDeviceHistory uses manifest history_url when available
//   8. fetchDeviceHistory falls back to legacy URLs when manifest unavailable

test.describe('14. Phase 2 Closure — Full Regression', () => {
  // Scenario 1: full v2 manifest → correct rendering
  test('scenario 1: sensor cards render correctly when /api/manifest returns full v2 manifest', async ({ page }) => {
    // Default mock server serves full v2 manifest from /api/manifest.
    // The source field reflects the active fixture set (e.g. 'active-manifest', '3sensor') —
    // the critical assertion is that it is NOT 'auto-promoted', which would indicate the
    // fallback chain was used instead of the real /api/manifest endpoint.
    await loadDashboard(page);
    await page.waitForFunction(() => window._manifest && window._manifest.schema_version === 2, { timeout: 10000 });
    const source = await page.evaluate(() => window._manifest.source);
    expect(source).not.toBe('auto-promoted');
    // Sensor cards must render
    await expect(page.locator('.sensor-card')).toHaveCount(3);
    // Cards must contain expected sensor names from the manifest
    for (const name of ['Office', 'First Floor', 'Outside']) {
      await expect(
        page.locator('.sensor-card-header').filter({ hasText: name }).first()
      ).toBeVisible();
    }
  });

  // Scenario 2: /api/manifest → 404, falls back to /sensors.json → still renders
  test('scenario 2: sensor cards render correctly when /api/manifest returns 404 (fallback to /sensors.json)', async ({ page }) => {
    await page.route('**/api/manifest', route => {
      route.fulfill({ status: 404, contentType: 'application/json', body: JSON.stringify({ ok: false }) });
    });
    await loadDashboard(page);
    await page.waitForFunction(() => window._manifest && window._manifest.schema_version === 2, { timeout: 10000 });
    const source = await page.evaluate(() => window._manifest.source);
    expect(source).toBe('auto-promoted');
    // Sensor cards must still render from the /sensors.json fallback
    await expect(page.locator('.sensor-card')).toHaveCount(3);
    for (const name of ['Office', 'First Floor', 'Outside']) {
      await expect(
        page.locator('.sensor-card-header').filter({ hasText: name }).first()
      ).toBeVisible();
    }
  });

  // Scenario 3: both /api/manifest and /sensors.json fail → hardcoded DEFAULT_SENSOR_META
  test('scenario 3: sensor cards render correctly when both /api/manifest and /sensors.json fail (hardcoded defaults)', async ({ page }) => {
    await page.route('**/api/manifest', route => {
      route.fulfill({ status: 404, contentType: 'application/json', body: JSON.stringify({ ok: false }) });
    });
    await page.route('**/sensors.json', route => {
      route.fulfill({ status: 404, contentType: 'text/plain', body: 'Not found' });
    });
    await loadDashboard(page);
    // Must still get a v2 manifest (from DEFAULT_SENSOR_META via autoPromoteV1ToV2)
    await page.waitForFunction(() => window._manifest && window._manifest.schema_version === 2, { timeout: 10000 });
    const source = await page.evaluate(() => window._manifest.source);
    expect(source).toBe('auto-promoted');
    // Sensor cards must still render using hardcoded DEFAULT_SENSOR_META (office, first_floor, outside)
    await expect(page.locator('.sensor-card')).toHaveCount(3);
    // DEFAULT_SENSOR_META contains office, first_floor, outside
    for (const name of ['Office', 'First Floor', 'Outside']) {
      await expect(
        page.locator('.sensor-card-header').filter({ hasText: name }).first()
      ).toBeVisible();
    }
  });

  // Scenario 4: environmental card renderer dispatches correctly
  test('scenario 4: environmental card renderer dispatches correctly for all sensors', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => window._manifest && window._manifest.sensors, { timeout: 10000 });
    // All manifest sensors must have category='environmental' and map to CARD_RENDERERS.environmental
    const allEnvironmental = await page.evaluate(() => {
      return window._manifest.sensors.every(function(s) { return s.category === 'environmental'; });
    });
    expect(allEnvironmental).toBe(true);
    // Rebuild cards and confirm full card structure for each card
    await page.evaluate(() => buildDeviceCards());
    await page.locator('.sensor-card').first().waitFor({ state: 'visible', timeout: 5000 });
    const cards = page.locator('.sensor-card');
    const count = await cards.count();
    expect(count).toBe(3);
    for (let i = 0; i < count; i++) {
      await expect(cards.nth(i).locator('.sensor-card-header')).toBeVisible();
      await expect(cards.nth(i).locator('.sensor-readings')).toBeVisible();
    }
  });

  // Scenario 5: _default card renderer handles unknown category gracefully
  test('scenario 5: _default card renderer handles unknown category gracefully without crashing', async ({ page }) => {
    await loadDashboard(page);
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    const result = await page.evaluate(() => {
      try {
        // _default renderer must return a non-empty string for any input
        var html = CARD_RENDERERS._default({ id: 'mystery', name: 'Mystery Device', category: 'unknown' }, null);
        return { ok: typeof html === 'string', html: html };
      } catch (e) {
        return { ok: false, error: e.message };
      }
    });
    expect(result.ok).toBe(true);
    expect(pageError).toBeNull();
  });

  // Scenario 6: metric formatters produce correct temperature output (°C / °F)
  test('scenario 6: metric formatters produce correct temperature output (°C / °F)', async ({ page }) => {
    await loadDashboard(page);
    // Temperature: 22.5°C → "22.5 °C / 72.5 °F"
    const temp = await page.evaluate(() =>
      formatMetricValue('temperature', 22.5, { unit: 'celsius', unit_symbol: '\u00b0C' })
    );
    expect(temp).toBe('22.5 \u00b0C / 72.5 \u00b0F');
    // Humidity: 55.3 → "55 %"
    const hum = await page.evaluate(() =>
      formatMetricValue('humidity', 55.3, { unit: 'percent', unit_symbol: '%' })
    );
    expect(hum).toBe('55 %');
  });

  // Scenario 7: fetchDeviceHistory uses manifest history_url when available
  test('scenario 7: fetchDeviceHistory uses manifest history_url when available', async ({ page }) => {
    await loadDashboard(page);
    const requestedUrls = [];
    await page.route('**/history/**', route => {
      requestedUrls.push(new URL(route.request().url()).pathname);
      route.fulfill({ status: 200, contentType: 'text/plain', body: '1700000000,22.5\n' });
    });
    // Provide a manifest with explicit history_url values
    await page.evaluate(() => {
      var manifest = {
        schema_version: 2,
        sensors: [{
          id: 'office',
          name: 'Office',
          category: 'environmental',
          measurements: [
            { key: 'temp', history_url: '/history/office/temp' },
            { key: 'hum',  history_url: '/history/office/hum'  }
          ]
        }],
        metrics: [
          { key: 'temp', history: true, display: { chart: true }, history_suffix: 'temp' },
          { key: 'hum',  history: true, display: { chart: true }, history_suffix: 'hum'  }
        ]
      };
      return fetchDeviceHistory({ id: 'office', name: 'Office' }, manifest);
    });
    expect(requestedUrls).toContain('/history/office/temp');
    expect(requestedUrls).toContain('/history/office/hum');
  });

  // Scenario 8: fetchDeviceHistory falls back to legacy URLs when manifest is unavailable
  test('scenario 8: fetchDeviceHistory falls back to legacy URLs when manifest is unavailable', async ({ page }) => {
    await loadDashboard(page);
    const requestedUrls = [];
    await page.route('**/history/**', route => {
      requestedUrls.push(new URL(route.request().url()).pathname);
      route.fulfill({ status: 200, contentType: 'text/plain', body: '' });
    });
    // null manifest → must use /history/{id}/temp and /history/{id}/hum
    await page.evaluate(() =>
      fetchDeviceHistory({ id: 'office', name: 'Office' }, null)
    );
    expect(requestedUrls).toContain('/history/office/temp');
    expect(requestedUrls).toContain('/history/office/hum');
  });
});

// ── 15. Phase 3 Closure — v2 API Regression ───────────────────────

test.describe('15. Phase 3 Closure — v2 API Regression', () => {
  // Test 1: /api/v2/live returns valid JSON with all device IDs from manifest
  test('/api/v2/live returns valid JSON with all device IDs from manifest', async ({ page }) => {
    await loadDashboard(page);
    const live = await page.evaluate(async () => {
      const resp = await fetch('/api/v2/live');
      return resp.json();
    });
    expect(live).toHaveProperty('timestamp');
    expect(live).toHaveProperty('devices');
    // All manifest sensor IDs must be present
    const manifest = await page.evaluate(async () => {
      const resp = await fetch('/api/manifest');
      return resp.json();
    });
    for (const sensor of manifest.sensors) {
      expect(live.devices).toHaveProperty(sensor.id);
    }
  });

  // Test 2: /api/v2/live returns metric keys matching manifest definitions
  test('/api/v2/live returns metric keys matching manifest metric definitions', async ({ page }) => {
    await loadDashboard(page);
    const manifest = await page.evaluate(async () => {
      const resp = await fetch('/api/manifest');
      return resp.json();
    });
    const live = await page.evaluate(async () => {
      const resp = await fetch('/api/v2/live');
      return resp.json();
    });
    const metricKeys = manifest.metrics.map(m => m.key);
    for (const sensorId of Object.keys(live.devices)) {
      for (const key of metricKeys) {
        expect(live.devices[sensorId]).toHaveProperty(key);
      }
    }
  });

  // Test 3: /api/v2/history/{device}/{metric} returns CSV data
  test('/api/v2/history/{device}/{metric} returns CSV data', async ({ page }) => {
    await loadDashboard(page);
    const csv = await page.evaluate(async () => {
      const resp = await fetch('/api/v2/history/office/temp');
      return resp.text();
    });
    expect(csv.length).toBeGreaterThan(0);
    const lines = csv.trim().split('\n');
    expect(lines.length).toBeGreaterThan(1);
    // Each line must be epoch,value
    for (const line of lines) {
      expect(line).toMatch(/^\d+,[\d.-]+$/);
    }
  });

  // Test 4: Legacy /history/{id}/temp still works (backward compat)
  test('legacy /history/{id}/temp still works', async ({ page }) => {
    await loadDashboard(page);
    const csv = await page.evaluate(async () => {
      const resp = await fetch('/history/office/temp');
      return resp.text();
    });
    expect(csv.length).toBeGreaterThan(0);
    const lines = csv.trim().split('\n');
    expect(lines.length).toBeGreaterThan(1);
    for (const line of lines) {
      expect(line).toMatch(/^\d+,[\d.-]+$/);
    }
  });

  // Test 5: Legacy /sensors.json still works (backward compat)
  test('legacy /sensors.json still works', async ({ page }) => {
    await loadDashboard(page);
    const sensors = await page.evaluate(async () => {
      const resp = await fetch('/sensors.json');
      return resp.json();
    });
    expect(Array.isArray(sensors)).toBe(true);
    expect(sensors.length).toBeGreaterThan(0);
    for (const s of sensors) {
      expect(s).toHaveProperty('id');
      expect(s).toHaveProperty('name');
    }
  });

  // Test 6: Dashboard renders identically with new endpoints
  test('dashboard renders identically with new endpoints', async ({ page }) => {
    await loadDashboard(page);
    await waitForConnected(page);
    // Sensor cards must render
    await expect(page.locator('.sensor-card')).toHaveCount(3);
    // Verify all sensor names are present
    for (const name of ['Office', 'First Floor', 'Outside']) {
      await expect(
        page.locator('.sensor-card-header').filter({ hasText: name }).first()
      ).toBeVisible();
    }
    // Charts must be present
    const chartCards = page.locator('.chart-card');
    const chartCount = await chartCards.count();
    expect(chartCount).toBeGreaterThan(0);
  });

  // Test 7: /api/v2/history returns 404 for unknown device
  test('/api/v2/history returns 404 for unknown device', async ({ page }) => {
    await loadDashboard(page);
    const status = await page.evaluate(async () => {
      const resp = await fetch('/api/v2/history/nonexistent/temp');
      return resp.status;
    });
    expect(status).toBe(404);
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
    await page.evaluate(() => { try { var r = App.API.loadHistory(); if (r && typeof r.catch === "function") r.catch(function() {}); } catch(e) {} });
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
    expect(requests[0]).toBe('/api/manifest');
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
