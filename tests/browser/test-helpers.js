/**
 * tests/browser/test-helpers.js
 * Shared helpers for the ESP32 gateway dashboard browser regression suite.
 *
 * Extracted from dashboard.spec.js during the v7.6.5.7 test spec split.
 *
 * Usage:
 *   const { loadDashboard, stopDashboardNetwork, waitForConnected, waitForAggregatorReady, bootAggregatorDashboard } = require('./test-helpers');
 */

'use strict';

async function waitForDashboardReady(page, opts = {}) {
  const timeout = opts.timeout || 15000;
  const expectedSensorCount = Number.isInteger(opts.expectedSensorCount) ? opts.expectedSensorCount : null;
  await page.waitForFunction((expected) => {
    if (typeof window._manifest === 'undefined') return false;
    if (!window.App || !App.State || typeof App.State.getSensors !== 'function') return false;
    var sensors = App.State.getSensors();
    if (!Array.isArray(sensors) || sensors.length === 0) return false;
    if (expected !== null && sensors.length !== expected) return false;
    var cards = Array.from(document.querySelectorAll('.sensor-card'));
    if (cards.length !== sensors.length) return false;
    return cards.every(function(card) {
      return !!card.querySelector('.sensor-card-header');
    });
  }, expectedSensorCount, { timeout });
  await page.locator('.sensor-card').first().waitFor({ state: 'visible', timeout });
}

async function stopDashboardNetwork(page) {
  try {
    await page.evaluate(() => {
      if (typeof suspendDashboardNetworkActivity === 'function') {
        suspendDashboardNetworkActivity();
        return;
      }
      // BUG-049: Null out EventSource callbacks BEFORE close. Firefox's Gecko
      // engine holds the SSE TCP socket open if callbacks are still attached,
      // causing browserContext.close() to hang for ~49s during Playwright
      // teardown and exceeding the 30s test timeout.
      if (window.evtSource && typeof window.evtSource.close === 'function') {
        try {
          window.evtSource.onopen = null;
          window.evtSource.onerror = null;
          window.evtSource.onmessage = null;
          window.evtSource.close();
        } catch (_) {}
        window.evtSource = null;
      }
    });
  } catch (_) { /* page may already be closed */ }
}

async function loadDashboard(page, opts = {}) {
  const timeout = opts.timeout || 15000;
  page._consoleErrors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') page._consoleErrors.push(msg.text());
  });
  await page.goto('/', { waitUntil: 'domcontentloaded' });
  await waitForDashboardReady(page, opts);
}

async function waitForConnected(page, timeout = 10000) {
  await page.locator('#statusDot.connected').waitFor({ state: 'attached', timeout });
}

async function waitForAggregatorReady(page) {
  await page.waitForFunction(() => window._aggregatorReady === true, { timeout: 15000 });
}

async function bootAggregatorDashboard(page, opts = {}) {
  const timeout = opts.timeout || 20000;
  const username = opts.username || 'admin';
  const password = opts.password || 'mock';

  await page.goto('/', { waitUntil: 'domcontentloaded' });

  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const ready = await page.evaluate(() => window._aggregatorReady === true).catch(() => false);
    if (ready) return;

    const modalVisible = await page.evaluate(() => {
      const modal = document.getElementById('authModal');
      if (!modal) return false;
      const hidden = modal.classList.contains('hidden') || modal.getAttribute('aria-hidden') === 'true';
      return !hidden;
    }).catch(() => false);

    if (modalVisible) {
      await page.locator('#authUsername').fill(username);
      await page.locator('#authPassword').fill(password);
      await page.locator('#authSubmit').click();
    }

    await page.waitForTimeout(100);
  }

  await waitForAggregatorReady(page);
}

module.exports = {
  waitForDashboardReady,
  stopDashboardNetwork,
  loadDashboard,
  waitForConnected,
  waitForAggregatorReady,
  bootAggregatorDashboard,
};
