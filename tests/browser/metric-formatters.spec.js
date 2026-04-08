/**
 * tests/browser/metric-formatters.spec.js
 * Metric formatter registry tests.
 *
 * Groups from dashboard.spec.js:
 *   12. Metric formatter registry
 */

'use strict';

const { test, expect } = require('@playwright/test');
const { loadDashboard, stopDashboardNetwork } = require('./test-helpers');

test.afterEach(async ({ page }) => {
  await stopDashboardNetwork(page);
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
