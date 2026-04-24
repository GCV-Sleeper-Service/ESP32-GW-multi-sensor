/**
 * tests/browser/regression.spec.js
 * Phase 2 and Phase 3 closure regression tests.
 *
 * Groups from dashboard.spec.js:
 *   14. Phase 2 Closure — Full Regression
 *   15. Phase 3 Closure — v2 API Regression
 */

'use strict';

const { test, expect } = require('@playwright/test');
const { loadDashboard, stopDashboardNetwork, waitForConnected } = require('./test-helpers');

test.afterEach(async ({ page }) => {
  await stopDashboardNetwork(page);
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
    test.skip(process.env.FIXTURE_SET === 'mixed', 'Sensor count (5) and Outside name are active-manifest-specific; mixed fixture has 4 sensors including nas01, so these assertions do not apply.');
    test.skip(process.env.FIXTURE_SET === 'aggregator', 'Aggregator manifest has 0 sensors; loadSensorManifest() falls back to DEFAULT_SENSOR_META (source=auto-promoted). Satellite-manifest rendering verified in other groups.');
    test.skip(process.env.FIXTURE_SET === 'system', 'System fixture has 2 env sensors (no Outside); sensor name assertions are 3sensor-specific.');
    // Default mock server serves full v2 manifest from /api/manifest.
    // The source field reflects the active fixture set (e.g. 'active-manifest', '3sensor') —
    // the critical assertion is that it is NOT 'auto-promoted', which would indicate the
    // fallback chain was used instead of the real /api/manifest endpoint.
    await loadDashboard(page);
    await page.waitForFunction(() => window._manifest && window._manifest.schema_version === 2, { timeout: 10000 });
    const source = await page.evaluate(() => window._manifest.source);
    expect(source).not.toBe('auto-promoted');
    // Sensor cards must render — 3 environmental + 1 network + 1 system = 5 total
    await expect(page.locator('.sensor-card')).toHaveCount(5);
    // Environmental cards must contain expected sensor names from the manifest
    for (const name of ['Office', 'First Floor', 'Outside']) {
      await expect(
        page.locator('.sensor-card-header').filter({ hasText: name }).first()
      ).toBeVisible();
    }
  });

  // Scenario 2: /api/manifest → 404, falls back to /sensors.json → still renders
  test('scenario 2: sensor cards render correctly when /api/manifest returns 404 (fallback to /sensors.json)', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'mixed', 'sensors.json fallback expects outside sensor; mixed sensors.json has only 2 entries (no outside).');
    test.skip(process.env.FIXTURE_SET === 'system', 'System sensors.json has 2 env entries (no outside); fallback card count (3) and Outside name are 3sensor-specific.');
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
    await loadDashboard(page, { expectedSensorCount: 3 });
    // Must still get a v2 manifest (from DEFAULT_SENSOR_META via autoPromoteV1ToV2)
    await page.waitForFunction(() => {
      if (!window._manifest || window._manifest.schema_version !== 2 || window._manifest.source !== 'auto-promoted') return false;
      if (!window.App || !App.State || typeof App.State.getSensors !== 'function') return false;
      var sensorIds = App.State.getSensors().map(function(sensor) { return sensor.id; });
      return sensorIds.join(',') === 'office,first_floor,outside'
        && document.querySelectorAll('.sensor-card').length === sensorIds.length;
    }, { timeout: 10000 });
    const source = await page.evaluate(() => window._manifest.source);
    expect(source).toBe('auto-promoted');
    const sensorIds = await page.evaluate(() => App.State.getSensors().map(sensor => sensor.id));
    expect(sensorIds).toEqual(['office', 'first_floor', 'outside']);
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
    test.skip(process.env.FIXTURE_SET === 'mixed', 'expectedSensorCount (5) and envSensors.length (3) are active-manifest-specific; mixed fixture has 2 env + 1 network + 1 system (nas01) = 4 total.');
    test.skip(process.env.FIXTURE_SET === 'aggregator', 'Aggregator fixture uses DEFAULT_SENSOR_META fallback (3 env, no network); expectedSensorCount(5) and envSensors.length(3) assertions are satellite-specific.');
    test.skip(process.env.FIXTURE_SET === 'system', 'System fixture has 2 env sensors (not 3); envSensors.length(3) assertion is 3sensor-specific.');
    // Active manifest includes 3 environmental, 1 network, and 1 system device.
    await loadDashboard(page, { expectedSensorCount: 5 });
    await page.waitForFunction(() => {
      if (!window._manifest || !Array.isArray(window._manifest.sensors)) return false;
      if (!window.App || !App.State || typeof App.State.getSensors !== 'function') return false;
      var envSensors = window._manifest.sensors.filter(function(sensor) {
        return !sensor.category || sensor.category === 'environmental';
      });
      // Total sensors = environmental + network + system devices
      return envSensors.length > 0
        && App.State.getSensors().length === window._manifest.sensors.length
        && document.querySelectorAll('.sensor-card').length === window._manifest.sensors.length;
    }, { timeout: 10000 });
    // Environmental manifest sensors must map to CARD_RENDERERS.environmental
    const envSensors = await page.evaluate(() => {
      return window._manifest.sensors.filter(function(s) { return !s.category || s.category === 'environmental'; });
    });
    expect(envSensors.length).toBe(3);
    expect(envSensors.every(s => s.category === 'environmental')).toBe(true);
    // Rebuild cards and confirm full card structure for each card
    await page.evaluate(() => buildDeviceCards());
    await page.waitForFunction(() => {
      if (!window.App || !App.State || typeof App.State.getSensors !== 'function') return false;
      var sensors = App.State.getSensors();
      var cards = Array.from(document.querySelectorAll('.sensor-card'));
      if (cards.length !== sensors.length) return false;
      return cards.every(function(card) {
        return card.querySelector('.sensor-card-header') && card.querySelector('.sensor-readings');
      });
    }, { timeout: 5000 });
    const cards = page.locator('.sensor-card');
    const count = await cards.count();
    // 3 environmental + 1 network + 1 system = 5 total
    expect(count).toBe(5);
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
    // Only environmental sensors are expected to expose temp/hum in live payloads.
    const metricKeys = ['temp', 'hum'];
    const envSensorIds = new Set(
      (manifest.sensors || [])
        .filter(s => !s.category || s.category === 'environmental')
        .map(s => s.id)
    );
    for (const sensorId of Object.keys(live.devices)) {
      if (!envSensorIds.has(sensorId)) continue;
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
    test.skip(process.env.FIXTURE_SET === 'aggregator',
      'Aggregator fixture sensors.json is [] (pure aggregator has no local sensors); sensors.length > 0 assertion is satellite-specific.');
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
    test.skip(process.env.FIXTURE_SET === 'mixed', 'Sensor count (5) and Outside name are active-manifest-specific; mixed fixture has 4 sensors (includes nas01; layout/names differ).');
    test.skip(process.env.FIXTURE_SET === 'aggregator', 'Aggregator uses DEFAULT_SENSOR_META fallback (3 env-only); card count (5) and wan_ping network card are satellite-specific.');
    test.skip(process.env.FIXTURE_SET === 'system', 'System fixture has 2 env sensors (no Outside); Outside name assertion is 3sensor-specific.');
    await loadDashboard(page);
    await waitForConnected(page);
    // 3 environmental + 1 network + 1 system = 5 sensor cards total
    await expect(page.locator('.sensor-card')).toHaveCount(5);
    // Verify all environmental sensor names are present
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
