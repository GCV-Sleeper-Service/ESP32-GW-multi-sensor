/**
 * tests/browser/boot-structure.spec.js
 * Boot, structure, and transport / status tests.
 *
 * Groups from dashboard.spec.js:
 *   1. Boot and structure
 *   3. Transport / status
 */

'use strict';

const { test, expect } = require('@playwright/test');
const { loadDashboard, stopDashboardNetwork, waitForConnected } = require('./test-helpers');

test.afterEach(async ({ page }) => {
  await stopDashboardNetwork(page);
});

// ── 1. Boot and structure ─────────────────────────────────────────

test.describe('1. Boot and structure', () => {
  test('page loads without crashing', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);
    expect(pageError).toBeNull();
  });

  test('version string is present in the DOM', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'aggregator',
      'Aggregator manifest has hardware=ESP32-S3; updateBoardInfo() hides #c3DescriptionBlock which contains #modeLabel. Aggregator boot verified in Group 19.');
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

  test('satellite mode — no aggregator UI when gateways returns empty list', async ({ page }) => {
    test.skip(process.env.FIXTURE_SET === 'aggregator',
      'Aggregator fixture returns populated gateways list, so DASHBOARD_MODE is aggregator; this test verifies satellite behaviour only.');
    // root/3sensor fixture: mock server returns {"gateways":[]} for /api/aggregator/gateways
    // detectAggregatorMode() sees empty array and stays in satellite mode
    await loadDashboard(page);
    const gwSelector = page.locator('#gwSelector');
    await expect(gwSelector).toHaveCount(0);
    const mode = await page.evaluate(() => window.DASHBOARD_MODE || 'satellite');
    expect(mode).toBe('satellite');
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
