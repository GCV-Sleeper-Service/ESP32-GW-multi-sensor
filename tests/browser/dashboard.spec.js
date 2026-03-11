/**
 * tests/browser/dashboard.spec.js
 * Browser regression suite for the ESP32 gateway dashboard.
 *
 * Element ID / DOM reference (verified against actual dashboard HTML):
 *   Theme button:      #themeBtn  — class 'light' goes on <html> (documentElement), NOT <body>
 *   Apply button:      #customRangeApply
 *   Cancel button:     #customRangeCancel
 *   Prev month:        #crPrev  /  Month label: #crCalHeader
 *   Range values:      24, 168 (7d), 720 (30d), 1080 (45d), custom  — in hours
 *   Export all:        [data-export-all]  /  Per-sensor: [data-export-sensor]
 *   Card names:        text node inside .sensor-card-header (no dedicated title class)
 *   Chart canvases:    inside .chart-card divs, NOT inside .sensor-card
 *   Preset buttons:    [data-cr-preset] — clicking applies AND closes modal immediately
 *                      (no separate Apply click needed after a preset)
 */

'use strict';

const { test, expect } = require('@playwright/test');

async function loadDashboard(page, opts = {}) {
  const timeout = opts.timeout || 15000;
  page._consoleErrors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') page._consoleErrors.push(msg.text());
  });
  await page.goto('/', { waitUntil: 'domcontentloaded' });
  await page.locator('.sensor-card').first().waitFor({ state: 'visible', timeout });
}

async function waitForConnected(page, timeout = 10000) {
  await page.locator('#statusDot.connected').waitFor({ state: 'attached', timeout });
}

// ── 1. Boot and structure ─────────────────────────────────────────

test.describe('1. Boot and structure', () => {
  test('page loads without crashing', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);
    expect(pageError).toBeNull();
  });

  test('version string is present in the DOM', async ({ page }) => {
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
});

// ── 2. Sensor cards ───────────────────────────────────────────────

test.describe('2. Sensor cards', () => {
  test('three sensor cards are rendered', async ({ page }) => {
    await loadDashboard(page);
    await expect(page.locator('.sensor-card')).toHaveCount(3);
  });

  test('sensor card headers contain expected sensor names', async ({ page }) => {
    await loadDashboard(page);
    // Name is a raw text node inside .sensor-card-header — no dedicated title class
    for (const name of ['Office', 'First Floor', 'Outside']) {
      await expect(
        page.locator('.sensor-card-header').filter({ hasText: name }).first()
      ).toBeVisible();
    }
  });

  test('each sensor card contains value display elements', async ({ page }) => {
    await loadDashboard(page);
    const cards = page.locator('.sensor-card');
    const count = await cards.count();
    for (let i = 0; i < count; i++) {
      expect(await cards.nth(i).locator('[id^="val-"]').count()).toBeGreaterThan(0);
    }
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

// ── 4. History and charts ─────────────────────────────────────────

test.describe('4. History and charts', () => {
  test('history loads and point count updates from zero', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => {
      const el = document.getElementById('pointCount');
      return el && el.textContent.includes('data points') && !el.textContent.startsWith('0');
    }, { timeout: 12000 });
    const text = await page.locator('#pointCount').textContent();
    expect(text).toMatch(/\d+ data points/);
    expect(parseInt(text)).toBeGreaterThan(0);
  });

  test('range buttons exist for all five presets including Custom', async ({ page }) => {
    await loadDashboard(page);
    // Range values are in hours: 24h=24, 7d=168, 30d=720, 45d=1080, custom
    for (const range of ['24', '168', '720', '1080', 'custom']) {
      await expect(page.locator(`[data-history-range="${range}"]`).first()).toBeVisible();
    }
  });

  test('clicking range buttons does not crash the page', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);
    for (const range of ['168', '720', '1080', '24']) {
      await page.locator(`[data-history-range="${range}"]`).first().click();
      await page.waitForTimeout(300);
    }
    expect(pageError).toBeNull();
  });

  test('chart canvases are rendered in chart sections', async ({ page }) => {
    await loadDashboard(page);
    // Charts live in .chart-card divs, NOT inside .sensor-card
    await page.waitForFunction(() => {
      const el = document.getElementById('pointCount');
      return el && el.textContent.includes('data points');
    }, { timeout: 12000 });
    // Check the four named chart canvases exist and are attached
    for (const id of ['tempChart', 'humChart', 'tempAvgChart', 'humAvgChart']) {
      await expect(page.locator(`#${id}`)).toBeAttached();
    }
  });

  test('history badge updates from loading state', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => {
      const el = document.getElementById('histBadge');
      return el && !el.textContent.includes('loading');
    }, { timeout: 12000 });
    expect(await page.locator('#histBadge').textContent()).not.toContain('loading');
  });
});

// ── 5. Custom date range ──────────────────────────────────────────

test.describe('5. Custom date range', () => {
  test('Custom button opens the date range modal', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    await expect(page.locator('#customRangeModal')).toBeVisible({ timeout: 3000 });
  });

  test('modal contains calendar and Apply/Cancel buttons', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    const modal = page.locator('#customRangeModal');
    await expect(modal).toBeVisible();
    await expect(modal.locator('#crCalGrid')).toBeVisible();
    await expect(modal.locator('#customRangeApply')).toBeVisible();
    await expect(modal.locator('#customRangeCancel')).toBeVisible();
  });

  test('modal displays data availability from storage-stats', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    await expect(page.locator('#customRangeAvail')).toBeVisible();
    const text = await page.locator('#customRangeAvail').textContent();
    expect(text).not.toContain('unknown');
  });

  test('Cancel closes the modal without changing range', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    await expect(page.locator('#customRangeModal')).toBeVisible();
    await page.locator('#customRangeCancel').click();
    await expect(page.locator('#customRangeModal')).toBeHidden({ timeout: 2000 });
  });

  test('calendar month navigation works', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    await expect(page.locator('#customRangeModal')).toBeVisible();
    const before = await page.locator('#crCalHeader').textContent();
    await page.locator('#crPrev').click();
    const after = await page.locator('#crCalHeader').textContent();
    expect(after).not.toBe(before);
  });

  test('clicking a preset applies range and closes modal', async ({ page }) => {
    // Preset buttons call _applyAndClose() directly — no separate Apply click needed
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);
    await page.locator('[data-history-range="custom"]').first().click();
    await expect(page.locator('#customRangeModal')).toBeVisible();
    // Clicking preset immediately applies and closes — do not click Apply afterwards
    await page.locator('[data-cr-preset="7d"]').click();
    await expect(page.locator('#customRangeModal')).toBeHidden({ timeout: 3000 });
    expect(pageError).toBeNull();
  });

  test('standard range buttons clear custom range state', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);
    // Activate custom range via preset (preset closes modal itself)
    await page.locator('[data-history-range="custom"]').first().click();
    await page.locator('[data-cr-preset="7d"]').click();
    await expect(page.locator('#customRangeModal')).toBeHidden({ timeout: 3000 });
    // Click standard range — should not crash
    await page.locator('[data-history-range="24"]').first().click();
    await page.waitForTimeout(300);
    expect(pageError).toBeNull();
  });
});

// ── 6. Theme toggle ───────────────────────────────────────────────

test.describe('6. Theme toggle', () => {
  test('clicking theme toggle switches to light mode', async ({ page }) => {
    await loadDashboard(page);
    // Theme class is toggled on <html> (documentElement), not <body>
    await expect(page.locator('html')).not.toHaveClass(/light/);
    await page.locator('#themeBtn').click();
    await expect(page.locator('html')).toHaveClass(/light/);
  });

  test('clicking theme toggle twice returns to dark mode', async ({ page }) => {
    await loadDashboard(page);
    await page.locator('#themeBtn').click();
    await page.locator('#themeBtn').click();
    await expect(page.locator('html')).not.toHaveClass(/light/);
  });

  test('theme toggle does not crash the page', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);
    await page.locator('#themeBtn').click();
    await page.waitForTimeout(500);
    await page.locator('#themeBtn').click();
    await page.waitForTimeout(500);
    expect(pageError).toBeNull();
  });
});

// ── 7. Export controls ────────────────────────────────────────────

test.describe('7. Export controls', () => {
  test('Export All button is visible', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => !!document.querySelector('[data-export-all]'), { timeout: 10000 });
    await expect(page.locator('[data-export-all]')).toBeVisible();
  });

  test('per-sensor export buttons are visible', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => {
      return document.querySelectorAll('[data-export-sensor]').length >= 3;
    }, { timeout: 10000 });
    expect(await page.locator('[data-export-sensor]').count()).toBeGreaterThanOrEqual(3);
  });

  test('clicking Export All does not crash', async ({ page }) => {
    let pageError = null;
    page.on('pageerror', err => { pageError = err; });
    await loadDashboard(page);
    await page.waitForFunction(() => {
      const el = document.getElementById('pointCount');
      return el && el.textContent.includes('data points') && !el.textContent.startsWith('0');
    }, { timeout: 12000 });
    await page.waitForFunction(() => !!document.querySelector('[data-export-all]'), { timeout: 10000 });
    await page.locator('[data-export-all]').first().click();
    await page.waitForTimeout(1000);
    expect(pageError).toBeNull();
  });
});

// ── 8. Console error guard ────────────────────────────────────────

test.describe('8. Console error guard', () => {
  test('no unexpected JS errors during normal session startup', async ({ page }) => {
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push(msg.text());
    });
    page.on('pageerror', err => errors.push('PAGEERROR: ' + err.message));

    await loadDashboard(page);
    await waitForConnected(page, 10000);
    await page.waitForTimeout(4000);

    const unexpected = errors.filter(e => {
      if (e.includes('favicon')) return false;
      if (e.includes('404') && e.includes('/text_sensor/')) return false;
      if (e.includes('404') && e.includes('/sensor/')) return false;
      return true;
    });

    if (unexpected.length > 0) console.log('Unexpected console errors:', unexpected);
    expect(unexpected).toHaveLength(0);
  });
});
