const { test, expect } = require('@playwright/test');

test.describe('manifest boot flow', () => {
  test('api manifest endpoint returns schema v2 metadata', async ({ request }) => {
    const response = await request.get('/api/manifest');
    expect(response.ok()).toBeTruthy();
    const payload = await response.json();

    // Validate top-level fields
    expect(payload.ok).toBe(true);
    expect(payload.schema_version).toBe(2);
    expect(payload.sensor_count).toBeGreaterThan(0);

    // Validate gateway block
    expect(payload.gateway).toBeDefined();
    expect(payload.gateway.id).toBeDefined();
    expect(payload.gateway.name).toBeDefined();
    expect(payload.gateway.role).toBe('satellite');
    expect(payload.gateway.hardware).toBe('ESP32-C3');
    expect(payload.gateway.firmware_version).toBeDefined();
    expect(payload.gateway.api_version).toBe('v2');

    // Validate history block
    expect(payload.history).toBeDefined();
    expect(payload.history.backend).toBe('nvs');
    expect(payload.history.retention_hours).toBe(1080);
    expect(payload.history.ram_window_hours).toBe(24);
    expect(payload.history.sample_interval_seconds).toBe(900);

    // Validate metrics array structure
    expect(payload.metrics).toBeDefined();
    expect(Array.isArray(payload.metrics)).toBe(true);
    expect(payload.metrics.length).toBeGreaterThan(0);
    expect(payload.metrics.map(m => m.key)).toEqual(['temp', 'hum']);

    const firstMetric = payload.metrics[0];
    expect(firstMetric.key).toBeDefined();
    expect(firstMetric.name).toBeDefined();
    expect(firstMetric.unit).toBeDefined();
    expect(firstMetric.class).toBe('analog_numeric');
    expect(firstMetric.data_type).toBe('float');
    expect(firstMetric.bounds).toBeDefined();
    expect(firstMetric.history).toBe(true);
    expect(firstMetric.display).toBeDefined();
    expect(firstMetric.display.precision).toBeDefined();
    expect(firstMetric.display.chart).toBe(true);

    // Validate sensors array structure
    expect(Array.isArray(payload.sensors)).toBeTruthy();
    expect(payload.sensors.length).toBe(payload.sensor_count);

    const firstSensor = payload.sensors[0];
    expect(firstSensor.id).toBeDefined();
    expect(firstSensor.name).toBeDefined();
    expect(firstSensor.category).toBe('environmental');
    expect(firstSensor.adapter).toBe('thermopro_ble');
    expect(firstSensor.source).toBeDefined();
    expect(firstSensor.source.mac).toBeDefined();
    expect(firstSensor.measurements).toBeDefined();
    expect(Array.isArray(firstSensor.measurements)).toBe(true);

    expect(payload.sensors[0]).toMatchObject({ id: 'office', name: 'Office' });
  });

  test('dashboard boots from /api/manifest', async ({ page }) => {
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
