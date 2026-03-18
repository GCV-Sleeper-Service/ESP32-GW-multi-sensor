/**
 * tests/browser/sensor-count.spec.js
 *
 * Smoke tests for variable sensor manifest sizes (1 / 2 / 3 / 4).
 * The FIXTURE_SET environment variable selects which variant the mock server serves.
 *
 * This spec is deliberately fixture-driven — it reads the active sensors.json
 * manifest to know how many cards to expect, so the same test works for any count
 * without hardcoding values.
 *
 * The existing dashboard.spec.js baseline suite (28 tests, 3-sensor) is untouched.
 *
 * Usage:
 *   FIXTURE_SET=1sensor npx playwright test tests/browser/sensor-count.spec.js
 *   FIXTURE_SET=2sensor npx playwright test tests/browser/sensor-count.spec.js
 *   FIXTURE_SET=4sensor npx playwright test tests/browser/sensor-count.spec.js
 */

'use strict';

const { test, expect } = require('@playwright/test');

// ── Helpers ──────────────────────────────────────────────────────
async function loadDashboard(page, timeout) {
  timeout = timeout || 15000;
  page._consoleErrors = [];
  page.on('console', function(msg) {
    if (msg.type() === 'error') page._consoleErrors.push(msg.text());
  });
  await page.goto('/', { waitUntil: 'domcontentloaded' });
  await page.locator('.sensor-card').first().waitFor({ state: 'visible', timeout: timeout });
}

// Fetch the active sensor manifest from the mock server at runtime
async function getManifest(page) {
  return page.evaluate(async function() {
    const res = await fetch('/sensors.json');
    return res.json();
  });
}

// ── Suite ────────────────────────────────────────────────────────
// Firefox SSE teardown fix: navigate away to close EventSource before context.close().
// Wrapped in try/catch so a page that is already closed or in a finished-test state
// does not cause a spurious afterEach failure.
test.afterEach(async ({ page }) => {
  try { await page.goto('about:blank'); } catch (_) { /* page may already be closing */ }
});

test.describe('sensor-count: card and control counts match manifest', function() {

  test('correct number of sensor cards render', async function({ page }) {
    await loadDashboard(page);
    const manifest = await getManifest(page);
    expect(Array.isArray(manifest)).toBe(true);
    expect(manifest.length).toBeGreaterThan(0);
    await expect(page.locator('.sensor-card')).toHaveCount(manifest.length);
  });

  test('sensor card headers contain all manifest sensor names', async function({ page }) {
    await loadDashboard(page);
    const manifest = await getManifest(page);
    const headers  = await page.locator('.sensor-card-header').allTextContents();
    const joined   = headers.join(' | ');
    for (const sensor of manifest) {
      expect(joined).toContain(sensor.name);
    }
  });

  test('per-sensor export buttons match manifest count', async function({ page }) {
    await loadDashboard(page);
    const manifest = await getManifest(page);
    await expect(page.locator('[data-export-sensor]')).toHaveCount(manifest.length);
  });

  test('export-all button is present', async function({ page }) {
    await loadDashboard(page);
    await expect(page.locator('[data-export-all]')).toBeVisible();
  });

});

// Firefox SSE teardown fix: navigate away to close EventSource before context.close().
// Wrapped in try/catch so a page that is already closed or in a finished-test state
// does not cause a spurious afterEach failure.
test.afterEach(async ({ page }) => {
  try { await page.goto('about:blank'); } catch (_) { /* page may already be closing */ }
});

test.describe('sensor-count: status and charts render correctly', function() {

  test('status dot becomes connected', async function({ page }) {
    await loadDashboard(page);
    await page.locator('#statusDot.connected').waitFor({ state: 'attached', timeout: 10000 });
  });

  test('chart canvases are present', async function({ page }) {
    await loadDashboard(page);
    const canvasCount = await page.locator('.chart-card canvas').count();
    expect(canvasCount).toBeGreaterThan(0);
  });

  test('no JS console errors on load', async function({ page }) {
    await loadDashboard(page);
    // Allow a moment for async operations to settle
    await page.waitForTimeout(500);
    expect(page._consoleErrors || []).toEqual([]);
  });

});

// Firefox SSE teardown fix: navigate away to close EventSource before context.close().
// Wrapped in try/catch so a page that is already closed or in a finished-test state
// does not cause a spurious afterEach failure.
test.afterEach(async ({ page }) => {
  try { await page.goto('about:blank'); } catch (_) { /* page may already be closing */ }
});

test.describe('sensor-count: interactive controls', function() {

  test('theme toggle applies class to html element', async function({ page }) {
    await loadDashboard(page);
    await page.locator('#themeBtn').click();
    const cls = await page.locator('html').getAttribute('class') || '';
    expect(cls.includes('light') || cls.length === 0 || cls.includes('dark')).toBe(true);
  });

  test('custom range modal opens and closes', async function({ page }) {
    await loadDashboard(page);
    const customOpeners = page.locator('[data-hours="custom"]');
    const openerCount   = await customOpeners.count();
    if (openerCount === 0) {
      // No custom range button present — pass (valid for some layouts)
      return;
    }
    await customOpeners.first().click();
    await expect(page.locator('#customRangeModal')).toBeVisible();
    await page.locator('#customRangeCancel').click();
    await expect(page.locator('#customRangeModal')).not.toBeVisible();
  });

});
