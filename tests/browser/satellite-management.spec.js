/**
 * tests/browser/satellite-management.spec.js
 * Satellite management API and UI tests.
 *
 * Groups from dashboard.spec.js:
 *   21. Satellite Management
 */

'use strict';

const { test, expect } = require('@playwright/test');
const { stopDashboardNetwork, waitForAggregatorReady } = require('./test-helpers');

test.afterEach(async ({ page }) => {
  await stopDashboardNetwork(page);
});

// ── 21. Satellite Management ───────────────────────────────────────

test.describe('21. Satellite Management', () => {
  test.beforeEach(async ({ request }, testInfo) => {
    test.skip(process.env.FIXTURE_SET !== 'aggregator',
      'Satellite management tests require FIXTURE_SET=aggregator');

    // Stateful isolation: Reset satellites before each test to avoid cross-test contamination
    await request.post('/api/system/reset-satellites?auth=mock', {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      data: 'a=1'
    });
  });

  // ── API Tests (request-only, no page needed) ──

  test('POST add-satellite: valid URL returns 200', async ({ request }) => {
    const resp = await request.post('/api/aggregator/add-satellite?url=http://192.168.1.100&name=Test+Sat', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.ok).toBe(true);
    expect(body.id).toBeDefined();
    expect(body.name).toBe('Test Sat');
    expect(body.satellite_count).toBeGreaterThan(0);
  });

  test('POST add-satellite: duplicate URL returns 409', async ({ request }) => {
    // Add first
    await request.post('/api/aggregator/add-satellite?url=http://unique-dup-test.local', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    // Add duplicate
    const resp = await request.post('/api/aggregator/add-satellite?url=http://unique-dup-test.local', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    expect(resp.status()).toBe(409);
    const body = await resp.json();
    expect(body.ok).toBe(false);
  });

  test('POST add-satellite: missing URL returns 400', async ({ request }) => {
    const resp = await request.post('/api/aggregator/add-satellite', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    expect(resp.status()).toBe(400);
  });

  test('POST add-satellite: full list returns 409', async ({ request }) => {
    // Fill to capacity
    for (let i = 0; i < 8; i++) {
      await request.post('/api/aggregator/add-satellite?url=http://fill-' + i + '.local', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    }
    const resp = await request.post('/api/aggregator/add-satellite?url=http://overflow.local', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    expect(resp.status()).toBe(409);
  });

  test('POST add-satellite: unreachable URL returns 400', async ({ request }) => {
    const resp = await request.post('/api/aggregator/add-satellite?url=http://unreachable.local', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    expect(resp.status()).toBe(400);
    const body = await resp.json();
    expect(body.message).toContain('unreachable');
  });

  test('DELETE satellite: valid ID returns 200', async ({ request }) => {
    // Add one first
    const addResp = await request.post('/api/aggregator/add-satellite?url=http://192.168.1.201', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    const addBody = await addResp.json();
    const satId = addBody.id;
    // Delete it with auth
    const resp = await request.delete('/api/aggregator/satellite/' + satId + '?auth=mock');
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.ok).toBe(true);
  });

  test('DELETE satellite: unknown ID returns 404', async ({ request }) => {
    const resp = await request.delete('/api/aggregator/satellite/nonexistent-id?auth=mock');
    expect(resp.status()).toBe(404);
  });

  test('POST test-satellite: valid URL returns gateway info', async ({ request }) => {
    const resp = await request.post('/api/aggregator/test-satellite?url=http://192.168.1.100&auth=mock', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.ok).toBe(true);
    expect(body.gateway).toBeDefined();
    expect(body.gateway.id).toBeDefined();
    expect(body.gateway.hardware).toBeDefined();
  });

  test('POST test-satellite: missing URL returns 400', async ({ request }) => {
    const resp = await request.post('/api/aggregator/test-satellite?auth=mock', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    expect(resp.status()).toBe(400);
  });

  test('POST test-satellite: unreachable URL returns 400', async ({ request }) => {
    const resp = await request.post('/api/aggregator/test-satellite?url=http://unreachable.local&auth=mock', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    expect(resp.status()).toBe(400);
  });

  test('POST test-satellite: URL without http:// returns 400', async ({ request }) => {
    const resp = await request.post('/api/aggregator/test-satellite?url=192.168.1.100&auth=mock', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    expect(resp.status()).toBe(400);
  });

  test('POST reset-satellites: resets to fixture defaults', async ({ request }) => {
    await request.post('/api/aggregator/add-satellite?url=http://192.168.1.250', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    const resp = await request.post('/api/system/reset-satellites?auth=mock', { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, data: 'a=1' });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.ok).toBe(true);
    expect(body.satellite_count).toBeDefined();
  });

  // ── UI Tests (need page) ──

  test('Settings panel renders add form', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForAggregatorReady(page);
    await page.locator('.gw-tab[data-gw="settings"]').click();
    const urlInput = page.locator('#sat-url-input');
    await expect(urlInput).toBeVisible();
    const addBtn = page.locator('#sat-add-btn');
    await expect(addBtn).toBeVisible();
    const testBtn = page.locator('#sat-test-btn');
    await expect(testBtn).toBeVisible();
  });

  test('Settings panel renders remove buttons for each satellite', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForAggregatorReady(page);
    await page.locator('.gw-tab[data-gw="settings"]').click();
    await page.waitForSelector('.settings-satellite-card', { timeout: 10000 });
    const removeBtns = page.locator('.settings-btn-remove');
    // Count should match number of satellites in aggregator fixture
    const count = await removeBtns.count();
    expect(count).toBeGreaterThan(0);
  });

  // ── PR #128 Regression Tests (MANDATORY) ──

  test('PR128-regression: URL input value preserved across poll-driven rerender', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForAggregatorReady(page);
    await page.locator('.gw-tab[data-gw="settings"]').click();
    const urlInput = page.locator('#sat-url-input');
    await urlInput.fill('http://192.168.1.250');

    // Deterministic wait: Wait for aggregator poll cycle by waiting for /api/aggregator/gateways
    await page.waitForResponse(resp => resp.url().includes('/api/aggregator/gateways') && resp.status() === 200);

    // Value must still be present — poll guard must have blocked the destructive rerender
    await expect(urlInput).toHaveValue('http://192.168.1.250');
  });

  test('PR128-regression: test-satellite result appears in live panel after action', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForAggregatorReady(page);
    await page.locator('.gw-tab[data-gw="settings"]').click();

    // Inject mock auth token into page context (simulates logged-in user)
    await page.evaluate(() => {
      sessionStorage.setItem('auth_token', 'mock');
    });

    const urlInput = page.locator('#sat-url-input');
    await urlInput.fill('http://192.168.1.100');
    const testBtn = page.locator('#sat-test-btn');
    await testBtn.click();

    // Wait for status element to be updated with non-placeholder content
    const statusEl = page.locator('#sat-add-status');
    await expect(statusEl).not.toHaveText('', { timeout: 5000 });

    // Verify the status contains meaningful content (not just empty or placeholder)
    const statusText = await statusEl.textContent();
    expect(statusText).toBeTruthy();
    expect(statusText.length).toBeGreaterThan(0);
  });

  test('PR128-regression: settings panel not destroyed during in-flight add', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForAggregatorReady(page);
    await page.locator('.gw-tab[data-gw="settings"]').click();
    const urlInput = page.locator('#sat-url-input');
    await urlInput.fill('http://192.168.1.130');
    const addBtn = page.locator('#sat-add-btn');

    // Set up response listener BEFORE clicking so it is registered before the response arrives
    const addResponse = page.waitForResponse(resp => resp.url().includes('/api/aggregator/add-satellite') && resp.status() === 200);

    // Click add and immediately verify input still exists (before request completes)
    await addBtn.click();
    await expect(urlInput).toBeVisible();

    // Wait for the add-satellite API response to complete
    await addResponse;

    // Panel must still be usable — no crash/blank
    await expect(page.locator('#sat-add-btn')).toBeVisible();
  });

  test('PR128-regression: panel remains usable after completed add', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForAggregatorReady(page);
    await page.locator('.gw-tab[data-gw="settings"]').click();
    const urlInput = page.locator('#sat-url-input');
    await urlInput.fill('http://192.168.1.140');
    await page.locator('#sat-add-btn').click();
    // Wait for add-satellite request to complete
    await page.waitForResponse(resp => resp.url().includes('/api/aggregator/add-satellite') && resp.status() === 200);
    // After add completes, user must be able to type in the URL field again without reload
    await urlInput.fill('http://192.168.1.141');
    await expect(urlInput).toHaveValue('http://192.168.1.141');
  });

  test('PR128-regression: panel remains usable after completed delete', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForAggregatorReady(page);
    await page.locator('.gw-tab[data-gw="settings"]').click();

    // First add a new satellite so we have one to delete
    const urlInput = page.locator('#sat-url-input');
    await urlInput.fill('http://192.168.1.199');
    await page.locator('#sat-add-btn').click();
    // Wait for add to complete
    await page.waitForResponse(resp => resp.url().includes('/api/aggregator/add-satellite') && resp.status() === 200);

    // Stub requestManagementCredentials to bypass auth modal
    await page.evaluate(() => {
      window.requestManagementCredentials = () => Promise.resolve({ username: 'admin', password: 'mock' });
    });

    // Now attempt to delete the satellite we just added
    await page.waitForSelector('.settings-satellite-card', { timeout: 10000 });
    const removeBtns = page.locator('.settings-btn-remove');

    // Set up dialog handler for confirmation prompt, then click remove (on last satellite = one we just added)
    page.on('dialog', dialog => dialog.accept());

    // Set up response listener BEFORE clicking so it is registered before the response arrives
    const deleteResponse = page.waitForResponse(resp => resp.url().includes('/api/aggregator/satellite/') && resp.request().method() === 'DELETE');

    await removeBtns.last().click();

    // Wait for delete API response to complete
    await deleteResponse;

    // Panel must still render after delete — test button still visible (this is the regression test)
    await expect(page.locator('#sat-test-btn')).toBeVisible();
  });
});
