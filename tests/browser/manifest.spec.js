const { test, expect } = require('@playwright/test');

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

async function waitForDashboardReady(page, expectedSensorCount, timeout = 10000) {
  await page.waitForFunction((expected) => {
    if (typeof window._manifest === 'undefined') return false;
    if (!window.App || !App.State || typeof App.State.getSensors !== 'function') return false;
    var sensors = App.State.getSensors();
    if (!Array.isArray(sensors) || sensors.length !== expected) return false;
    var cards = Array.from(document.querySelectorAll('.sensor-card'));
    if (cards.length !== expected) return false;
    return cards.every(function(card) {
      return !!card.querySelector('.sensor-card-header');
    });
  }, expectedSensorCount, { timeout });
}

async function stopDashboardNetwork(page) {
  try {
    await page.evaluate(() => {
      if (typeof suspendDashboardNetworkActivity === 'function') {
        suspendDashboardNetworkActivity();
        return;
      }
      if (window.evtSource && typeof window.evtSource.close === 'function') {
        try { window.evtSource.close(); } catch (_) {}
        window.evtSource = null;
      }
    });
  } catch (_) { /* page may already be closed */ }
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
    await waitForDashboardReady(page, expectedSensors.length);
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
    await waitForDashboardReady(page, 3);
    const sensors = await page.evaluate(() => App.State.getSensors().map(s => s.id));
    expect(sensors).toEqual(['office', 'first_floor', 'outside']);
  });
});
