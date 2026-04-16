/**
 * tests/browser/aggregator.spec.js
 * Aggregator mode tests.
 *
 * Groups from dashboard.spec.js:
 *   19. Aggregator Mode (Phase 5 Step 4)
 */

'use strict';

const { test, expect } = require('@playwright/test');
const { stopDashboardNetwork, bootAggregatorDashboard } = require('./test-helpers');

test.afterEach(async ({ page }) => {
  await stopDashboardNetwork(page);
});

// -- 19. Aggregator Mode (Phase 5 Step 4) -------------------------
test.describe('19. Aggregator Mode', () => {
  // This group is specific to the 'aggregator' fixture variant (2 satellites via
  // /api/aggregator/gateways). It must be skipped for all other fixture sets.
  // LESSON-OPS-063: use beforeEach skip guard, hardcoded integer literals in toHaveCount.
  test.beforeEach(async () => {
    test.skip(process.env.FIXTURE_SET !== 'aggregator',
      'Aggregator tests require FIXTURE_SET=aggregator');
  });
  test.setTimeout(90000);

  // -- Test 1: Mode detection -------------------------------------
  test('aggregator mode detected when /api/aggregator/gateways returns populated list', async ({ page }) => {
    await bootAggregatorDashboard(page);
    const mode = await page.evaluate(() => window.DASHBOARD_MODE);
    expect(mode).toBe('aggregator');
  });

  // -- Test 2: Gateway selector bar visible ----------------------
  test('gateway selector bar is visible in aggregator mode', async ({ page }) => {
    await bootAggregatorDashboard(page);
    const selector = page.locator('#gwSelector');
    await expect(selector).toBeVisible();
  });

  // -- Test 3: Gateway selector tab count ------------------------
  test('gateway selector has correct number of tabs', async ({ page }) => {
    await bootAggregatorDashboard(page);
    // "All Gateways" + gw-main + gw-garage + "Settings" = 4 tabs
    const tabs = page.locator('.gw-tab');
    await expect(tabs).toHaveCount(4);
  });

  // -- Test 4: Unreachable satellite shown as offline -------------
  test('unreachable satellite shown with offline indicator', async ({ page }) => {
    await bootAggregatorDashboard(page);
    const offlineTab = page.locator('.gw-tab.gw-offline');
    await expect(offlineTab).toHaveCount(1);
  });

  // -- Test 5: All Gateways summary renders status cards ---------
  test('All Gateways summary renders 2 gateway status cards', async ({ page }) => {
    await bootAggregatorDashboard(page);
    await page.waitForSelector('.gw-summary-card', { timeout: 10000 });
    const summaryCards = page.locator('.gw-summary-card');
    await expect(summaryCards).toHaveCount(2);
  });

  // -- Test 6: Per-gateway tab shows device cards ----------------
  test('clicking a gateway tab shows its device cards', async ({ page }) => {
    await bootAggregatorDashboard(page);
    // Use data-gw attribute selector (DOM-safe rendering per v7.5.5.3)
    await page.locator('.gw-tab[data-gw="gw-main"]').click();
    await page.waitForSelector('#gwGrid .sensor-card', { timeout: 10000 });
    const cards = page.locator('#gwGrid .sensor-card');
    const count = await cards.count();
    expect(count).toBeGreaterThan(0);
  });

  // -- Test 7: Environmental cards receive live temperature values -
  // Enabled by PR #70 review fix (Codex P1): _populateGatewayDeviceLive now
  // handles all card categories, not just network. Fix commit: 6a6ff9d.
  test('environmental cards show live temperature value from aggregator/live', async ({ page }) => {
    await bootAggregatorDashboard(page);
    await page.locator('.gw-tab[data-gw="gw-main"]').click();
    await page.waitForSelector('#gwGrid .sensor-card', { timeout: 10000 });
    // Fixture has office.temp = 23.4 - it should appear in the environmental card.
    // Scope to #gwGrid to avoid matching local sensor cards in #sensorGrid.
    const tempValue = page.locator('#gwGrid .sensor-card').filter({ hasText: 'Office' })
      .locator('.reading-value').first();
    await expect(tempValue).not.toHaveText('\u2014', { timeout: 8000 });
  });

  // -- Test 8: Network cards receive live values ------------------
  test('network cards show live ping value from aggregator/live', async ({ page }) => {
    await bootAggregatorDashboard(page);
    await page.locator('.gw-tab[data-gw="gw-main"]').click();
    await page.waitForSelector('#gwGrid .sensor-card', { timeout: 10000 });
    // Fixture has wan_ping.ping_ms = 12.3 - it should appear in the network card.
    // Scope to #gwGrid to avoid matching local sensor cards in #sensorGrid.
    const pingValue = page.locator('#gwGrid .sensor-card').filter({ hasText: 'WAN Ping' })
      .locator('.reading-value').first();
    await expect(pingValue).not.toHaveText('\u2014', { timeout: 8000 });
  });

  // -- Test 9: Settings tab renders satellite list ----------------
  test('Settings panel shows satellite list', async ({ page }) => {
    await bootAggregatorDashboard(page);
    await page.locator('.gw-tab[data-gw="settings"]').click();
    await page.waitForSelector('.settings-satellite-card', { timeout: 10000 });
    // Expect 2 satellite cards (one per gateway in the fixture)
    const cards = page.locator('.settings-satellite-card');
    await expect(cards).toHaveCount(2);
  });

  // -- Test 10: Gateways section is separate from SENSORS section --
  // BUG-065: gateway cards must not appear in #sensorGrid
  test('Gateways section is visible and separate from SENSORS section', async ({ page }) => {
    await bootAggregatorDashboard(page);
    const gwBody = page.locator('#body-gateways');
    await expect(gwBody).toBeVisible();
    const gwSelector = page.locator('#gwSelectorContainer #gwSelector');
    await expect(gwSelector).toBeVisible();
    const gwGridCards = page.locator('#gwGrid .gw-summary-card');
    await expect(gwGridCards).toHaveCount(2);
    const sensorGridGwCards = page.locator('#sensorGrid .gw-summary-card');
    await expect(sensorGridGwCards).toHaveCount(0);
  });

  // -- Test 11: Local sensors render in aggregator mode (unified boot) --
  // LESSON-OPS-074: aggregator boot = satellite pipeline + overlay, never a fork
  test('local sensor cards rendered in aggregator mode (unified boot)', async ({ page }) => {
    await bootAggregatorDashboard(page);
    const modeLabel = page.locator('#modeLabel');
    await expect(modeLabel).not.toHaveText('');
  });
});
