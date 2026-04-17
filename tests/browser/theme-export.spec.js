/**
 * tests/browser/theme-export.spec.js
 * Theme toggle, export controls, and console error guard tests.
 *
 * Groups from dashboard.spec.js:
 *    6. Theme toggle
 *    7. Export controls
 *    8. Console error guard
 */

'use strict';

const { test, expect } = require('@playwright/test');
const { loadDashboard, stopDashboardNetwork, waitForConnected } = require('./test-helpers');

test.afterEach(async ({ page }) => {
  await stopDashboardNetwork(page);
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

  test('single-sensor export keeps environmental derived columns populated', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => {
      const el = document.getElementById('pointCount');
      return el && el.textContent.includes('data points') && !el.textContent.startsWith('0');
    }, { timeout: 12000 });
    const csv = await page.evaluate(async () => {
      const sensor = window.SENSORS.find(s => s.id === 'office');
      const meta = await getGatewayExportMeta();
      const rows = await fetchSensorHistoryRows(sensor);
      return buildSingleSensorCsv(meta, sensor, rows);
    });

    expect(csv.split('\n')[0]).toContain('office_temp_c');
    expect(csv.split('\n')[0]).toContain('office_dewpoint_c');
    const firstDataLine = csv.trim().split('\n')[1];
    expect(firstDataLine).toBeTruthy();
    const values = firstDataLine.split(',');
    expect(values[5]).not.toBe('');
    expect(values[8]).not.toBe('');
  });

  test('Mixed export uses manifest-driven ping metrics when present', async ({ page }) => {
    await loadDashboard(page);
    await page.waitForFunction(() => {
      const el = document.getElementById('pointCount');
      return el && el.textContent.includes('data points') && !el.textContent.startsWith('0');
    }, { timeout: 12000 });
    const hasPing = await page.evaluate(() => window.SENSORS.some(s => s.id === 'wan_ping'));
    test.skip(!hasPing, 'fixture set has no ping sensor');

    const csv = await page.evaluate(async () => {
      const sensor = window.SENSORS.find(s => s.id === 'wan_ping');
      const meta = await getGatewayExportMeta();
      const rows = await fetchSensorHistoryRows(sensor);
      return buildSingleSensorCsv(meta, sensor, rows);
    });

    const lines = csv.trim().split('\n');
    test.skip(lines.length < 2, 'fixture set has no ping history rows');
    expect(lines[0]).toContain('wan_ping_ping_ms');
    expect(lines[0]).toContain('wan_ping_success_pct');
    const values = lines[1].split(',');
    expect(values[5]).not.toBe('');
    expect(values[6]).not.toBe('');
  });

  test('System export respects manifest history flags', async ({ page }) => {
    await loadDashboard(page);
    const hasSystem = await page.evaluate(() => window.SENSORS.some(s => s.id === 'nas01'));
    test.skip(!hasSystem, 'fixture set has no system sensor');

    const header = await page.evaluate(() => {
      const sensor = window.SENSORS.find(s => s.id === 'nas01');
      return getSingleSensorExportColumns(sensor).join(',');
    });

    expect(header).not.toContain('nas01_cpu_pct');
    expect(header).not.toContain('nas01_ram_pct');
    expect(header).not.toContain('nas01_disk_pct');
  });
});

// 8. Console error guard

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
