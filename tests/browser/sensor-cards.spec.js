/**
 * tests/browser/sensor-cards.spec.js
 * Sensor card rendering tests — environmental, network, and mixed-category.
 *
 * Groups from dashboard.spec.js:
 *    2. Sensor cards
 *   11. Card renderer registry (v7.5.2.1)
 *   17. Phase 4 Step 2 — Network Card Renderer
 *   18. Mixed-Category Rendering (Phase 4 Step 3)
 */

'use strict';

const { test, expect } = require('@playwright/test');
const { loadDashboard, stopDashboardNetwork } = require('./test-helpers');

test.afterEach(async ({ page }) => {
  await stopDashboardNetwork(page);
});

// ── 2. Sensor cards ───────────────────────────────────────────────

test.describe('2. Sensor cards', () => {
  test('four sensor cards are rendered (3 environmental + 1 network)', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'mixed', 'Card count (4) is 3sensor-specific; mixed fixture has 4 sensors (2 env + 1 network + 1 system/nas01).');
    test.skip(process.env.FIXTURE_SET === 'aggregator', 'Aggregator fixture has 0 sensors in manifest; DEFAULT_SENSOR_META fallback yields 3 env-only cards (no network wan_ping).');
    await loadDashboard(page);
    await expect(page.locator('.sensor-card')).toHaveCount(4);
  });

  test('sensor card headers contain expected sensor names', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'mixed', 'Sensor name list includes Outside which is absent from the mixed fixture.');
    test.skip(process.env.FIXTURE_SET === 'system', 'System fixture has 2 env sensors (office, first_floor) only; Outside is absent.');
    await loadDashboard(page);
    // Name is a raw text node inside .sensor-card-header — no dedicated title class
    for (const name of ['Office', 'First Floor', 'Outside']) {
      await expect(
        page.locator('.sensor-card-header').filter({ hasText: name }).first()
      ).toBeVisible();
    }
  });

  test('each environmental sensor card contains value display elements', async ({ page }) => {
    await loadDashboard(page);
    const cards = page.locator('.sensor-card:not(.network-card)');
    const count = await cards.count();
    for (let i = 0; i < count; i++) {
      expect(await cards.nth(i).locator('[id^="val-"]').count()).toBeGreaterThan(0);
    }
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
    test.skip(process.env.FIXTURE_SET === 'mixed', 'Post-buildDeviceCards card count (4) is 3sensor-specific; mixed fixture has 4 sensors (2 env + 1 network + 1 system/nas01).');
    test.skip(process.env.FIXTURE_SET === 'aggregator', 'Aggregator manifest has 0 sensors; DEFAULT_SENSOR_META fallback yields 3 env-only cards (not 4). Card count assertion (4) is satellite-specific.');
    await loadDashboard(page);
    // Wait for manifest and cards
    await page.waitForFunction(() => window._manifest && window._manifest.sensors, { timeout: 10000 });
    // Re-invoke buildDeviceCards and verify cards are rebuilt without error
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await page.evaluate(() => buildDeviceCards());
    await page.locator('.sensor-card').first().waitFor({ state: 'visible', timeout: 5000 });
    // 3 environmental + 1 network = 4 total
    await expect(page.locator('.sensor-card')).toHaveCount(4);
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

// ── 17. Phase 4 Step 2 — Network Card Renderer ───────────────────

test.describe('17. Phase 4 Step 2 — Network Card Renderer', () => {
  test('network card renders when manifest contains a network device', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'aggregator',
      'Aggregator fixture uses DEFAULT_SENSOR_META fallback (3 env-only, no wan_ping); network card from manifest is satellite-specific.');
    await loadDashboard(page);
    // Network card should be present (wan_ping from manifest.json)
    await expect(page.locator('.network-card')).toBeVisible();
    await expect(page.locator('.network-card .sensor-card-header')).toBeVisible();
  });

  test('network card displays latency value element (id: net-ping-wan_ping)', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'aggregator',
      'Aggregator fixture DEFAULT_SENSOR_META has no wan_ping; #net-ping-wan_ping element does not exist in local sensor grid.');
    await loadDashboard(page);
    await expect(page.locator('#net-ping-wan_ping')).toBeAttached();
  });

  test('network card displays success rate element (id: net-success-wan_ping)', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'aggregator',
      'Aggregator fixture DEFAULT_SENSOR_META has no wan_ping; #net-success-wan_ping element does not exist in local sensor grid.');
    await loadDashboard(page);
    await expect(page.locator('#net-success-wan_ping')).toBeAttached();
  });

  test('network card displays target element (id: net-target-wan_ping)', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'aggregator',
      'Aggregator fixture DEFAULT_SENSOR_META has no wan_ping; #net-target-wan_ping element does not exist in local sensor grid.');
    await loadDashboard(page);
    const target = page.locator('#net-target-wan_ping');
    await expect(target).toBeAttached();
    // Target should show the host from manifest source.target
    const text = await target.textContent();
    expect(text).toMatch(/8\.8\.8\.8|—/);
  });

  test('environmental cards have full ThermoPro layout (unaffected by network card)', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'mixed', 'Environmental card count (3) is 3sensor-specific; mixed fixture has 2 env sensors.');
    test.skip(process.env.FIXTURE_SET === 'system', 'System fixture has 2 env + 1 system card; .sensor-card:not(.network-card) includes the system card which lacks .sensor-env-grid.');
    await loadDashboard(page);
    await page.waitForFunction(() => window._manifest && window._manifest.sensors, { timeout: 10000 });
    const envCards = page.locator('.sensor-card:not(.network-card)');
    const count = await envCards.count();
    expect(count).toBe(3);
    for (let i = 0; i < count; i++) {
      await expect(envCards.nth(i).locator('.sensor-card-header')).toBeVisible();
      await expect(envCards.nth(i).locator('.sensor-readings')).toBeVisible();
      await expect(envCards.nth(i).locator('.sensor-env-grid')).toBeVisible();
      await expect(envCards.nth(i).locator('.sensor-minmax')).toBeVisible();
      await expect(envCards.nth(i).locator('.sensor-batt-row')).toBeVisible();
      await expect(envCards.nth(i).locator('.sensor-rssi-row')).toBeVisible();
    }
  });

  test('CARD_RENDERERS.network is registered and callable', async ({ page }) => {
    await loadDashboard(page);
    const result = await page.evaluate(() => {
      try {
        var html = CARD_RENDERERS.network(
          { id: 'wan_ping', name: 'WAN Latency', color: '#4FC3F7', category: 'network' },
          null
        );
        return { ok: typeof html === 'string' && html.length > 0, isNetworkCard: html.indexOf('network-card') !== -1 };
      } catch(e) {
        return { ok: false, error: e.message };
      }
    });
    expect(result.ok).toBe(true);
    expect(result.isNetworkCard).toBe(true);
  });

  test('METRIC_FORMATTERS.ping_latency and success_rate are registered', async ({ page }) => {
    await loadDashboard(page);
    const result = await page.evaluate(() => {
      return {
        hasPingLatency: typeof METRIC_FORMATTERS.ping_latency === 'function',
        hasSuccessRate: typeof METRIC_FORMATTERS.success_rate === 'function',
        pingFormat: METRIC_FORMATTERS.ping_latency(42.7),
        successFormat: METRIC_FORMATTERS.success_rate(100)
      };
    });
    expect(result.hasPingLatency).toBe(true);
    expect(result.hasSuccessRate).toBe(true);
    expect(result.pingFormat).toBe('43 ms');
    expect(result.successFormat).toBe('100%');
  });

  test('makeNetworkSensorConfig produces correct config (no ThermoPro entity IDs)', async ({ page }) => {
    await loadDashboard(page);
    const result = await page.evaluate(() => {
      var cfg = makeNetworkSensorConfig({ id: 'wan_ping', name: 'WAN Latency', category: 'network' }, 3);
      return {
        id: cfg.id,
        name: cfg.name,
        category: cfg.category,
        hasTempId: 'tempId' in cfg,
        hasRestPaths: Array.isArray(cfg.restPaths) && cfg.restPaths.length === 0
      };
    });
    expect(result.id).toBe('wan_ping');
    expect(result.category).toBe('network');
    expect(result.hasTempId).toBe(false);
    expect(result.hasRestPaths).toBe(true);
  });

  test('SENSORS includes network device (wan_ping) after manifest load', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'mixed', 'Total sensor count (4) is 3sensor-specific; mixed fixture has 4 sensors total (2 env + 1 network + 1 system/nas01).');
    test.skip(process.env.FIXTURE_SET === 'aggregator', 'Aggregator DEFAULT_SENSOR_META has no wan_ping; SENSORS.length is 3 (env-only). Network device verified in aggregator gwGrid cards (Group 19).');
    await loadDashboard(page);
    const sensorIds = await page.evaluate(() => App.State.getSensors().map(s => s.id));
    expect(sensorIds).toContain('wan_ping');
    expect(sensorIds.length).toBe(4);
  });

  test('updateNetworkCards populates ping values from live data', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'aggregator',
      'Aggregator DEFAULT_SENSOR_META has no wan_ping; #net-ping-wan_ping and #net-success-wan_ping elements do not exist in local sensor grid.');
    await loadDashboard(page);
    await page.evaluate(() => {
      updateNetworkCards({
        timestamp: 1741694400,
        devices: {
          wan_ping: { ping_ms: 15.3, success_pct: 100, last_seen: 1741694400 }
        }
      });
    });
    const pingText = await page.locator('#net-ping-wan_ping').textContent();
    const successText = await page.locator('#net-success-wan_ping').textContent();
    expect(pingText).toBe('15 ms');
    expect(successText).toBe('100%');
  });
});

// ── 18. Mixed-Category Rendering (Phase 4 Step 3) ─────────────────────
test.describe('18. Mixed-Category Rendering', () => {
  // This group is specific to the 'mixed' fixture variant: 2 ThermoPro environmental sensors,
  // 1 network sensor (wan_ping), and 1 system device (nas01) — i.e., a mixed set of categories.
  // It must be skipped under other fixture sets where the composition differs (e.g. '3sensor' includes
  // an 'outside' environmental sensor and no system device, even though it also has 4 total sensors).
  // In CI, this group runs exclusively via the 'browser-tests (mixed)' matrix job.
  // LESSON-OPS-063: use expectedSensorCount (not { timeout }) for readiness gating;
  //                 use hardcoded integer literals in toHaveCount (not dynamic manifest reads).
  test.beforeEach(async ({}, testInfo) => {
    if (process.env.FIXTURE_SET !== 'mixed') {
      testInfo.skip();
    }
  });
  test.setTimeout(90000);

  test('mixed manifest renders correct total card count', async ({ page }) => {
    await loadDashboard(page, { expectedSensorCount: 4 }); // 2 env + 1 network + 1 system
    // Hardcoded: mixed fixture always has exactly 4 sensor cards.
    // Do NOT read count from window._manifest — dynamic reads pass vacuously when manifest is broken.
    await expect(page.locator('.sensor-card')).toHaveCount(4);
  });

  test('environmental cards have full ThermoPro layout elements', async ({ page }) => {
    await loadDashboard(page, { expectedSensorCount: 4 }); // 2 env + 1 network + 1 system
    const envCards = page.locator('.sensor-card:not(.network-card):not(.system-card)');
    // Hardcoded: mixed fixture always has exactly 2 environmental cards.
    await expect(envCards).toHaveCount(2);
    // Each should have reading-label "Temperature"
    const tempLabels = page.locator('.sensor-card:not(.network-card):not(.system-card) .reading-label:text("Temperature")');
    await expect(tempLabels).toHaveCount(2);
  });

  test('network card renders with latency and success rate elements', async ({ page }) => {
    await loadDashboard(page, { expectedSensorCount: 4 }); // 2 env + 1 network + 1 system
    const netCard = page.locator('.network-card');
    await expect(netCard).toHaveCount(1);
    await expect(page.locator('#net-ping-wan_ping')).toBeVisible();
    await expect(page.locator('#net-success-wan_ping')).toBeVisible();
  });

  test('CARD_RENDERERS dispatches correctly by category', async ({ page }) => {
    await loadDashboard(page, { expectedSensorCount: 4 }); // 2 env + 1 network + 1 system
    const hasNetworkRenderer = await page.evaluate(() => {
      return typeof CARD_RENDERERS.network === 'function';
    });
    expect(hasNetworkRenderer).toBe(true);
  });

  test('chart canvases exist for environmental devices', async ({ page }) => {
    await loadDashboard(page, { expectedSensorCount: 4 }); // 2 env + 1 network + 1 system
    const tempCanvas = page.locator('#tempChart');
    await expect(tempCanvas).toBeVisible();
  });

  test('/api/v2/live returns data for both device categories', async ({ request }) => {
    const response = await request.get('/api/v2/live');
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.devices).toBeDefined();
    expect(data.devices.office).toBeDefined();
    expect(data.devices.wan_ping).toBeDefined();
    expect(data.devices.wan_ping.ping_ms).toBeDefined();
  });

  test('manifest v2 contains both environmental and network devices', async ({ page }) => {
    await loadDashboard(page, { expectedSensorCount: 4 }); // 2 env + 1 network + 1 system
    const categories = await page.evaluate(() => {
      if (!window._manifest || !window._manifest.sensors) return [];
      return window._manifest.sensors.map(function(s) { return s.category; });
    });
    expect(categories).toContain('environmental');
    expect(categories).toContain('network');
  });
});
