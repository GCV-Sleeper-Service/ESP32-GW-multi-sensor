/**
 * tests/browser/manifest.spec.js
 * Manifest boot flow, manifest v2 loader, and manifest v2 fallback chain tests.
 *
 * Groups from dashboard.spec.js added at v7.6.5.7:
 *    9. Manifest v2 loader
 *   10. Manifest v2 fallback chain
 *
 * Original manifest boot flow group preserved from pre-split.
 */

'use strict';

const { test, expect } = require('@playwright/test');
const {
  loadDashboard: loadDashboardHelper,
  waitForDashboardReady,
  stopDashboardNetwork
} = require('./test-helpers');

// Stub external CDN resources (Chart.js, Google Fonts) so page.goto resolves
// in offline / sandboxed CI environments.  The dashboard wraps initCharts()
// in try/catch so a missing Chart global is handled gracefully; sensor-load
// logic (loadManifestV2 / loadSensorManifest) runs independently of charts.
async function stubCdn(page) {
  await page.route('https://cdn.jsdelivr.net/**', route =>
    route.fulfill({ status: 200, contentType: 'application/javascript', body: '/* cdn stub */' })
  );
  await page.route('https://fonts.googleapis.com/**', route =>
    route.fulfill({ status: 200, contentType: 'text/css', body: '' })
  );
  await page.route('https://fonts.gstatic.com/**', route =>
    route.fulfill({ status: 200, contentType: 'font/woff2', body: '' })
  );
}

test.afterEach(async ({ page }) => {
  await stopDashboardNetwork(page);
});

test.describe('manifest boot flow', () => {
  test('api manifest endpoint returns schema v2 metadata', async ({ request }) => {
    if (process.env.FIXTURE_SET === 'aggregator') {
      // Aggregator manifest has 0 local sensors; sensor_count=0 and gateway.role='aggregator'.
      // Satellite-specific assertions (sensor_count>=1, role=satellite, temp/hum metrics, first sensor) do not apply.
      test.skip(true, 'Aggregator manifest has sensor_count=0 and role=aggregator; satellite-specific manifest metadata assertions do not apply.');
    }
    const response = await request.get('/api/manifest');
    expect(response.ok()).toBeTruthy();
    const payload = await response.json();
    expect(payload.ok).toBe(true);
    expect(payload.schema_version).toBe(2);
    expect(payload.sensor_count).toBeGreaterThanOrEqual(1);
    expect(payload.gateway.role).toBe('satellite');
    expect(payload.gateway.api_version).toBe('v2');
    expect(payload.history.backend).toBe('nvs');
    expect(typeof payload.history.retention_hours).toBe('number');
    expect(Array.isArray(payload.metrics)).toBeTruthy();
    const metricKeys = payload.metrics.map(m => m.key);
    expect(metricKeys).toEqual(expect.arrayContaining(['temp', 'hum', 'cpu_pct', 'ram_pct', 'disk_pct', 'uptime_hrs']));
    const firstMetric = payload.metrics[0];
    expect(firstMetric.class).toBe('analog_numeric');
    expect(firstMetric.data_type).toBe('float');
    expect(firstMetric.display.chart).toBe(true);
    expect(Array.isArray(payload.sensors)).toBeTruthy();
    expect(payload.sensors.length).toBe(payload.sensor_count);
    const firstSensor = payload.sensors[0];
    expect(firstSensor).toMatchObject({ id: 'office', name: 'Office' });
    expect(firstSensor.category).toBe('environmental');
    expect(firstSensor.adapter).toBe('thermopro_ble');
    expect(Object.prototype.hasOwnProperty.call(firstSensor.source, 'mac')).toBe(true);
  });

  test('dashboard boots from /api/manifest', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'aggregator', 'Aggregator manifest has 0 sensors; DEFAULT_SENSOR_META fallback loads 3 env-only sensors. Expected sensor list is satellite-specific.');
    await stubCdn(page);
    await page.goto('/dashboard.html');
    const manifest = await page.evaluate(async () => {
      const response = await fetch('/api/manifest');
      return response.json();
    });
    const expectedSensors = (manifest.sensors || []).map(s => ({ id: s.id, name: s.name }));
    await waitForDashboardReady(page, { expectedSensorCount: expectedSensors.length });
    const sensors = await page.evaluate(() => App.State.getSensors().map(s => ({ id: s.id, name: s.name })));
    expect(sensors).toEqual(expectedSensors);
  });

  test('dashboard falls back to /sensors.json when /api/manifest is unavailable', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'mixed', 'sensors.json fallback list (office,first_floor,outside) is 3sensor-specific; mixed sensors.json has 2 entries (no outside).');
    test.skip(process.env.FIXTURE_SET === 'system', 'System sensors.json has 2 entries (office,first_floor); fallback sensor list (office,first_floor,outside) is 3sensor-specific.');
    await stubCdn(page);
    await page.route('**/api/manifest', async route => {
      await route.fulfill({
        status: 404,
        contentType: 'application/json',
        body: JSON.stringify({ ok: false, message: 'forced fallback' }),
      });
    });
    await page.goto('/dashboard.html');
    await waitForDashboardReady(page, { expectedSensorCount: 3 });
    const sensors = await page.evaluate(() => App.State.getSensors().map(s => s.id));
    expect(sensors).toEqual(['office', 'first_floor', 'outside']);
  });
});

// ── 9. Manifest v2 loader ─────────────────────────────────────────

test.describe('9. Manifest v2 loader', () => {
  test('window._manifest is set after boot', async ({ page }) => {
    await loadDashboardHelper(page);
    await page.waitForFunction(() => typeof window._manifest !== 'undefined' && window._manifest !== null, { timeout: 10000 });
    const manifest = await page.evaluate(() => window._manifest);
    expect(manifest).not.toBeNull();
    expect(manifest.ok).toBe(true);
  });

  test('window._manifest has correct schema_version', async ({ page }) => {
    await loadDashboardHelper(page);
    await page.waitForFunction(() => window._manifest && window._manifest.schema_version === 2, { timeout: 10000 });
    const schemaVersion = await page.evaluate(() => window._manifest.schema_version);
    expect(schemaVersion).toBe(2);
  });

  test('window._manifest contains sensors array', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'aggregator',
      'Aggregator manifest has sensors:[] (0 local sensors); window._manifest.sensors is empty and does not match DEFAULT_SENSOR_META fallback. Aggregator manifest verified via Group 19 integration tests.');
    await loadDashboardHelper(page);
    await page.waitForFunction(() => window._manifest && Array.isArray(window._manifest.sensors), { timeout: 10000 });
    // Compare against the active fixture — fixture-agnostic so all FIXTURE_SET variants pass
    const result = await page.evaluate(async () => {
      const resp = await fetch('/api/manifest');
      const m = await resp.json();
      return {
        expected: m.sensors.map(function(s) { return s.id; }),
        actual: window._manifest.sensors.map(function(s) { return s.id; }),
      };
    });
    expect(result.actual.length).toBeGreaterThan(0);
    expect(result.actual.length).toBe(result.expected.length);
    for (const id of result.expected) {
      expect(result.actual).toContain(id);
    }
  });

  test('window._manifest contains gateway block', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'aggregator',
      'Aggregator manifest gateway.role is "aggregator" (not "satellite") and hardware is "ESP32-S3"; satellite-specific gateway block assertions do not apply.');
    await loadDashboardHelper(page);
    await page.waitForFunction(() => window._manifest && window._manifest.gateway, { timeout: 10000 });
    const gateway = await page.evaluate(() => window._manifest.gateway);
    expect(gateway.role).toBe('satellite');
    expect(gateway.api_version).toBe('v2');
  });

  test('window._manifest contains metrics array', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'aggregator',
      'Aggregator manifest has metrics:[] (no local env sensors); metrics assertions (temp/hum) do not apply to pure aggregator.');
    await loadDashboardHelper(page);
    await page.waitForFunction(() => window._manifest && Array.isArray(window._manifest.metrics), { timeout: 10000 });
    const metricKeys = await page.evaluate(() => window._manifest.metrics.map(m => m.key));
    expect(metricKeys).toEqual(expect.arrayContaining(['temp', 'hum']));
  });
});

// ── 10. Manifest v2 fallback chain ───────────────────────────────

test.describe('10. Manifest v2 fallback chain', () => {
  test('dashboard loads and window._manifest is auto-promoted when /api/manifest returns 404', async ({ page }) => {
    await page.route('**/api/manifest', async route => {
      await route.fulfill({ status: 404, contentType: 'application/json', body: JSON.stringify({ ok: false }) });
    });
    await loadDashboardHelper(page);
    await page.waitForFunction(() => window._manifest && window._manifest.schema_version === 2, { timeout: 10000 });
    const source = await page.evaluate(() => window._manifest.source);
    expect(source).toBe('auto-promoted');
    const sensors = await page.evaluate(() => App.State.getSensors().map(s => s.id));
    expect(sensors.length).toBeGreaterThan(0);
  });

  test('loadManifestV2 and autoPromoteV1ToV2 are accessible on window', async ({ page }) => {
    await loadDashboardHelper(page);
    const hasFns = await page.evaluate(() => typeof loadManifestV2 === 'function' && typeof autoPromoteV1ToV2 === 'function');
    expect(hasFns).toBe(true);
  });
});
