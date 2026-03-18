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

// Firefox SSE teardown fix: navigate away to close EventSource before context.close()
test.afterEach(async ({ page }) => { await page.goto("about:blank"); });

// Firefox SSE teardown fix: navigate away to close EventSource before context.close()
test.afterEach(async ({ page }) => { await page.goto("about:blank"); });

test.describe('manifest boot flow', () => {
  test('api manifest endpoint returns schema v2 metadata', async ({ request }) => {
    const response = await request.get('/api/manifest');
    expect(response.ok()).toBeTruthy();
    const payload = await response.json();
    expect(payload.ok).toBe(true);
    expect(payload.schema_version).toBe(2);
    expect(payload.sensor_count).toBe(4);
    expect(payload.gateway.role).toBe('satellite');
    expect(payload.gateway.api_version).toBe('v2');
    expect(payload.history.backend).toBe('nvs');
    expect(typeof payload.history.retention_hours).toBe('number');
    expect(Array.isArray(payload.metrics)).toBeTruthy();
    expect(payload.metrics.map(m => m.key)).toEqual(['temp', 'hum']);
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
    await stubCdn(page);
    await page.goto('/dashboard.html');
    await page.waitForFunction(() => window.App && App.State && App.State.getSensors().length === 3);
    const sensors = await page.evaluate(() => App.State.getSensors().map(s => ({ id: s.id, name: s.name })));
    expect(sensors).toEqual([
      { id: 'office', name: 'Office' },
      { id: 'first_floor', name: 'First Floor' },
      { id: 'outside', name: 'Outside' },
    ]);
  });

  test('dashboard falls back to /sensors.json when /api/manifest is unavailable', async ({ page }) => {
    await stubCdn(page);
    await page.route('**/api/manifest', async route => {
      await route.fulfill({
        status: 404,
        contentType: 'application/json',
        body: JSON.stringify({ ok: false, message: 'forced fallback' }),
      });
    });
    await page.goto('/dashboard.html');
    await page.waitForFunction(() => window.App && App.State && App.State.getSensors().length === 3);
    const sensors = await page.evaluate(() => App.State.getSensors().map(s => s.id));
    expect(sensors).toEqual(['office', 'first_floor', 'outside']);
  });
});
