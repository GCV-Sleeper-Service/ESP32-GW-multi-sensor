/**
 * tests/browser/system-devices.spec.js
 * System devices and data ingest tests.
 *
 * Groups from dashboard.spec.js:
 *   20. System Devices and Data Ingest
 */

'use strict';

const { test, expect } = require('@playwright/test');
const { loadDashboard, stopDashboardNetwork } = require('./test-helpers');

test.afterEach(async ({ page }) => {
  await stopDashboardNetwork(page);
});

// ── 20. System Devices and Data Ingest ───────────────────────────

test.describe('20. System Devices and Data Ingest', () => {
  // This group is specific to the 'system' fixture variant (2 env + 1 network + 1 system = 4).
  // It must be skipped for all other fixture sets.
  // LESSON-OPS-063: use beforeEach skip guard, hardcoded integer literals in toHaveCount.
  test.beforeEach(({}, testInfo) => {
    test.skip(process.env.FIXTURE_SET !== 'system',
      'System tests require system fixture (2 env + 1 net + 1 sys = 4)');
  });
  test.setTimeout(90000);

  test('system fixture renders correct total card count', async ({ page }) => {
    await loadDashboard(page, { expectedSensorCount: 4 });
    await expect(page.locator('.sensor-card')).toHaveCount(4);
  });

  test('system card renders with usage bar elements', async ({ page }) => {
    await loadDashboard(page, { expectedSensorCount: 4 });
    const sysCard = page.locator('.system-card');
    await expect(sysCard).toHaveCount(1);
    await expect(page.locator('[id^="bar-sys-cpu-"]')).toBeVisible();
    await expect(page.locator('[id^="bar-sys-ram-"]')).toBeVisible();
    await expect(page.locator('[id^="bar-sys-disk-"]')).toBeVisible();
  });

  test('environmental cards have full ThermoPro layout', async ({ page }) => {
    await loadDashboard(page, { expectedSensorCount: 4 });
    const envCards = page.locator('.sensor-card:not(.network-card):not(.system-card)');
    await expect(envCards).toHaveCount(2);
  });

  test('network card present alongside system card', async ({ page }) => {
    await loadDashboard(page, { expectedSensorCount: 4 });
    await expect(page.locator('.network-card')).toHaveCount(1);
  });

  test('CARD_RENDERERS.system is registered', async ({ page }) => {
    await loadDashboard(page, { expectedSensorCount: 4 });
    const has = await page.evaluate(() => typeof CARD_RENDERERS.system === 'function');
    expect(has).toBe(true);
  });

  test('/api/v2/live returns system device data', async ({ request }) => {
    const resp = await request.get('/api/v2/live');
    expect(resp.ok()).toBeTruthy();
    const data = await resp.json();
    expect(data.devices.nas01).toBeDefined();
    expect(data.devices.nas01.cpu_pct).toBeDefined();
  });

  test('POST /api/ingest returns 200 for valid device/metric', async ({ request }) => {
    const resp = await request.post('/api/ingest/nas01/cpu_pct?val=55.5');
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.ok).toBe(true);
  });

  test('POST /api/ingest returns 404 for unknown device', async ({ request }) => {
    const resp = await request.post('/api/ingest/nonexistent/cpu_pct?val=1');
    expect(resp.status()).toBe(404);
  });
});
