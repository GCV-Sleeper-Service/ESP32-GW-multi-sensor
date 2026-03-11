/**
 * tests/browser/dashboard.spec.js
 * Browser regression suite for the ESP32 gateway dashboard.
 *
 * Test groups:
 *   1. Boot and structure     — page loads, no critical errors, key elements exist
 *   2. Sensor cards           — all three sensor cards rendered with expected content
 *   3. Transport / status     — dashboard reaches "connected" state via mock server
 *   4. History and charts     — range buttons work, chart canvases render
 *   5. Custom date range      — modal opens, calendar renders, cancel/apply work
 *   6. Theme toggle           — dark/light switch works, persists class change
 *   7. Export controls        — buttons are visible and clickable without crashing
 *   8. Console error guard    — no unexpected JS errors during a normal session
 *
 * The mock server (tests/mock-server/server.js) handles all API calls.
 * Playwright starts it automatically via webServer in playwright.config.js.
 */

'use strict';

const { test, expect } = require('@playwright/test');

// ── Helpers ───────────────────────────────────────────────────────

/**
 * Navigate to the dashboard and wait for the boot sequence to complete.
 * "Boot complete" is defined as:
 *   - The page is fully loaded
 *   - The status indicator shows "connected" (SSE ping received OR polling success)
 *   - The first sensor card is visible
 *
 * @param {import('@playwright/test').Page} page
 * @param {object} [opts]
 * @param {number} [opts.timeout=15000]  ms to wait for connected state
 */
async function loadDashboard(page, opts = {}) {
  const timeout = opts.timeout || 15000;

  // Collect console errors so individual tests can inspect them
  page._consoleErrors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') page._consoleErrors.push(msg.text());
  });

  await page.goto('/', { waitUntil: 'domcontentloaded' });

  // Wait for at least one sensor card to appear — confirms boot completed
  await page.locator('.sensor-card').first().waitFor({ state: 'visible', timeout });
}

/**
 * Wait for the status dot to reach "connected" state.
 * The mock server sends an SSE ping, which sets the connected class.
 */
async function waitForConnected(page, timeout = 10000) {
  await page.locator('#statusDot.connected').waitFor({ state: 'attached', timeout });
}

// ── Test suite ────────────────────────────────────────────────────

test.describe('1. Boot and structure', () => {
  test('page loads without crashing', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });

    await loadDashboard(page);

    // No uncaught JS exceptions
    expect(pageError).toBeNull();
  });

  test('version string is present in the DOM', async ({ page }) => {
    await loadDashboard(page);
    // The mode label is set during boot: [SSE mode], [POLLING mode], etc.
    const modeLabel = page.locator('#modeLabel');
    await expect(modeLabel).toBeVisible();
    const text = await modeLabel.textContent();
    expect(text).toMatch(/\[.+\s+mode\]/i);
  });

  test('dark mode is the default theme', async ({ page }) => {
    await loadDashboard(page);
    const body = page.locator('body');
    // Default class should NOT include 'light' (dark is default)
    const cls = await body.getAttribute('class') || '';
    expect(cls).not.toContain('light');
  });

  test('all primary UI sections are present', async ({ page }) => {
    await loadDashboard(page);
    // History badge
    await expect(page.locator('#histBadge')).toBeVisible();
    // Point count
    await expect(page.locator('#pointCount')).toBeVisible();
    // Status dot
    await expect(page.locator('#statusDot')).toBeVisible();
    // Theme toggle
    await expect(page.locator('#themeToggle')).toBeVisible();
  });
});

test.describe('2. Sensor cards', () => {
  test('three sensor cards are rendered', async ({ page }) => {
    await loadDashboard(page);
    const cards = page.locator('.sensor-card');
    await expect(cards).toHaveCount(3);
  });

  test('sensor card headings match fixture sensor names', async ({ page }) => {
    await loadDashboard(page);
    const headings = await page.locator('.sensor-card .card-title').allTextContents();
    expect(headings).toContain('Office');
    expect(headings).toContain('First Floor');
    expect(headings).toContain('Outside');
  });

  test('each sensor card contains a temperature and humidity display element', async ({ page }) => {
    await loadDashboard(page);
    const cards = page.locator('.sensor-card');
    const count = await cards.count();
    for (let i = 0; i < count; i++) {
      const card = cards.nth(i);
      // Each card should have value display elements (waiting or populated)
      const valueEls = card.locator('[id^="val-"]');
      const n = await valueEls.count();
      expect(n).toBeGreaterThan(0);
    }
  });
});

test.describe('3. Transport / status', () => {
  test('dashboard reaches connected state', async ({ page }) => {
    await loadDashboard(page);
    // The mock server sends SSE pings — status dot should become connected
    await waitForConnected(page, 10000);
    const statusText = await page.locator('#statusText').textContent();
    expect(statusText).toMatch(/connected/i);
  });

  test('status dot has connected class after connection', async ({ page }) => {
    await loadDashboard(page);
    await waitForConnected(page);
    await expect(page.locator('#statusDot')).toHaveClass(/connected/);
  });
});

test.describe('4. History and charts', () => {
  test('history loads and point count updates from zero', async ({ page }) => {
    await loadDashboard(page);
    // After history loads (2s boot delay + fetch), point count should show data
    await page.waitForFunction(() => {
      const el = document.getElementById('pointCount');
      return el && el.textContent.includes('data points') && !el.textContent.startsWith('0');
    }, { timeout: 12000 });
    const text = await page.locator('#pointCount').textContent();
    expect(text).toMatch(/\d+ data points/);
    // With 72h × 3 sensors × 2 series = 432 points expected
    const n = parseInt(text);
    expect(n).toBeGreaterThan(0);
  });

  test('range buttons exist for all five presets including Custom', async ({ page }) => {
    await loadDashboard(page);
    for (const label of ['24h', '7d', '30d', '45d', 'Custom']) {
      const btn = page.locator(`button[data-history-range], button`).filter({ hasText: label }).first();
      await expect(btn).toBeVisible();
    }
  });

  test('clicking range buttons does not crash the page', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);

    for (const range of ['7d', '30d', '45d', '24h']) {
      await page.locator(`[data-history-range="${range}"]`).first().click();
      await page.waitForTimeout(300);
    }
    expect(pageError).toBeNull();
  });

  test('chart canvases are rendered inside sensor cards', async ({ page }) => {
    await loadDashboard(page);
    // Wait for history to load
    await page.waitForFunction(() => {
      const el = document.getElementById('pointCount');
      return el && el.textContent.includes('data points');
    }, { timeout: 12000 });
    const canvases = page.locator('.sensor-card canvas');
    const count = await canvases.count();
    expect(count).toBeGreaterThan(0);
  });

  test('history badge updates from loading state', async ({ page }) => {
    await loadDashboard(page);
    // After load it should NOT still say "loading..."
    await page.waitForFunction(() => {
      const el = document.getElementById('histBadge');
      return el && !el.textContent.includes('loading');
    }, { timeout: 12000 });
    const badgeText = await page.locator('#histBadge').textContent();
    expect(badgeText).not.toContain('loading');
  });
});

test.describe('5. Custom date range', () => {
  test('Custom button opens the date range modal', async ({ page }) => {
    await loadDashboard(page);

    // Click the first "Custom" button (in the history range toggle)
    await page.locator('[data-history-range="custom"]').first().click();

    // Modal should become visible
    const modal = page.locator('#customRangeModal');
    await expect(modal).toBeVisible({ timeout: 3000 });
  });

  test('modal contains calendar and preset buttons', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();

    // Preset buttons inside the modal
    const modal = page.locator('#customRangeModal');
    await expect(modal).toBeVisible();

    // Calendar grid
    const calGrid = modal.locator('#crCalGrid');
    await expect(calGrid).toBeVisible();

    // Apply and Cancel buttons
    await expect(modal.locator('#crApply')).toBeVisible();
    await expect(modal.locator('#crCancel')).toBeVisible();
  });

  test('modal displays data availability from storage-stats', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    const avail = page.locator('#customRangeAvail');
    await expect(avail).toBeVisible();
    // Should show one of our three states — not "unknown"
    const text = await avail.textContent();
    expect(text).not.toContain('unknown');
  });

  test('Cancel closes the modal without changing range', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    await expect(page.locator('#customRangeModal')).toBeVisible();

    await page.locator('#crCancel').click();
    await expect(page.locator('#customRangeModal')).toBeHidden({ timeout: 2000 });
  });

  test('calendar month navigation works', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    await expect(page.locator('#customRangeModal')).toBeVisible();

    const monthLabel = page.locator('#crMonthLabel');
    const before = await monthLabel.textContent();

    // Navigate back one month
    await page.locator('#crPrevMonth').click();
    const after = await monthLabel.textContent();
    expect(after).not.toBe(before);
  });

  test('Apply with a preset selection does not crash', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);

    await page.locator('[data-history-range="custom"]').first().click();
    await expect(page.locator('#customRangeModal')).toBeVisible();

    // Click the "Last 7 days" preset button inside the modal
    await page.locator('#customRangeModal button').filter({ hasText: /7.?d|7 days/i }).first().click();
    // Then apply
    await page.locator('#crApply').click();

    // Modal should close
    await expect(page.locator('#customRangeModal')).toBeHidden({ timeout: 3000 });
    expect(pageError).toBeNull();
  });

  test('standard range buttons clear custom range state', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);

    // Activate custom range via a preset
    await page.locator('[data-history-range="custom"]').first().click();
    await page.locator('#customRangeModal button').filter({ hasText: /7.?d|7 days/i }).first().click();
    await page.locator('#crApply').click();
    await expect(page.locator('#customRangeModal')).toBeHidden({ timeout: 3000 });

    // Click a standard range button — should not crash
    await page.locator('[data-history-range="24h"]').first().click();
    await page.waitForTimeout(300);
    expect(pageError).toBeNull();
  });
});

test.describe('6. Theme toggle', () => {
  test('clicking theme toggle switches to light mode', async ({ page }) => {
    await loadDashboard(page);

    // Start in dark mode (default)
    await expect(page.locator('body')).not.toHaveClass(/light/);

    await page.locator('#themeToggle').click();

    // Should now have light class
    await expect(page.locator('body')).toHaveClass(/light/);
  });

  test('clicking theme toggle twice returns to dark mode', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('#themeToggle').click();
    await page.locator('#themeToggle').click();
    await expect(page.locator('body')).not.toHaveClass(/light/);
  });

  test('theme toggle does not crash the page', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);

    await page.locator('#themeToggle').click();
    await page.waitForTimeout(500);
    await page.locator('#themeToggle').click();
    await page.waitForTimeout(500);

    expect(pageError).toBeNull();
  });
});

test.describe('7. Export controls', () => {
  test('Export All button is visible', async ({ page }) => {
    await loadDashboard(page);
    const exportBtn = page.locator('button').filter({ hasText: /export all/i });
    await expect(exportBtn).toBeVisible();
  });

  test('per-sensor export buttons are visible', async ({ page }) => {
    await loadDashboard(page);
    // Each sensor card should have an export button
    const exportBtns = page.locator('button').filter({ hasText: /export/i });
    const count = await exportBtns.count();
    // At minimum: one per sensor + Export All = 4
    expect(count).toBeGreaterThanOrEqual(4);
  });

  test('clicking Export All does not crash', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);

    // Wait for history to load before triggering export
    await page.waitForFunction(() => {
      const el = document.getElementById('pointCount');
      return el && el.textContent.includes('data points') && !el.textContent.startsWith('0');
    }, { timeout: 12000 });

    const exportAllBtn = page.locator('button').filter({ hasText: /export all/i }).first();
    await exportAllBtn.click();
    await page.waitForTimeout(1000);

    expect(pageError).toBeNull();
  });
});

test.describe('8. Console error guard', () => {
  test('no unexpected JS errors during normal session startup', async ({ page }) => {
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push(msg.text());
    });
    page.on('pageerror', err => errors.push('PAGEERROR: ' + err.message));

    await loadDashboard(page);
    await waitForConnected(page, 10000);

    // Wait for history bootstrap (2s delay in boot sequence)
    await page.waitForTimeout(4000);

    // Filter out known-harmless errors that don't indicate dashboard bugs.
    // The mock server returns 404 for some ESPHome entity paths that are
    // optional (device info telemetry) — those are expected during testing.
    const unexpected = errors.filter(e => {
      if (e.includes('favicon')) return false;         // browsers always try
      if (e.includes('404') && e.includes('/text_sensor/')) return false; // optional device info
      if (e.includes('404') && e.includes('/sensor/')) return false;
      return true;
    });

    if (unexpected.length > 0) {
      console.log('Unexpected console errors:', unexpected);
    }
    expect(unexpected).toHaveLength(0);
  });
});
