// playwright.config.js
// Configuration for the ESP32 gateway dashboard browser regression suite.
//
// The mock server is started automatically by webServer before any test runs.
//
// Browser coverage:
//   Chromium is the primary (and only required) target. Firefox and WebKit are
//   intentionally excluded — the dashboard targets modern browsers and Chromium
//   headless is the practical validation target for CI and containers.
//   Adding Firefox/WebKit is straightforward but out of scope until Chromium
//   coverage is stable across all fixture variants.
//
// Container / Linux sandbox note:
//   Chromium's default sandbox requires kernel features (user namespaces) that
//   are not available in most Docker / container environments including the
//   ESPHome container. The '--no-sandbox' arg in launchOptions below is required
//   for tests to run in those environments. It is safe for a local test runner —
//   the risk model only applies when running untrusted web content (we are not;
//   the mock server serves our own fixture HTML only).

'use strict';

const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests/browser',

  // Each test gets a fresh browser context
  fullyParallel: false,    // Sequential — avoids port conflicts with the mock server

  // Fail fast on CI; locally allow retries
  retries: process.env.CI ? 1 : 0,

  // Timeout per test (dashboard has async chart + history loading)
  timeout: 30000,

  // Reporter: list for local, GitHub Actions annotations on CI
  reporter: process.env.CI
    ? [['github'], ['html', { open: 'never', outputFolder: 'tests/playwright-report' }]]
    : [['list'], ['html', { open: 'never', outputFolder: 'tests/playwright-report' }]],

  use: {
    baseURL: 'http://127.0.0.1:3737',
    // Capture screenshots and traces on failure only
    screenshot: 'only-on-failure',
    trace: 'on-first-retry',
    // Headless always in CI; can override locally with --headed
    headless: true,
    // Console messages and page errors are collected by tests
    ignoreHTTPSErrors: true,
    // Required in container / Docker / ESPHome environments where the kernel
    // does not support Chromium's user-namespace sandbox.
    launchOptions: {
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    },
  },

  // Start mock server before tests, shut it down after
  webServer: {
    command: 'node tests/mock-server/server.js --port 3737',
    port: 3737,
    reuseExistingServer: !process.env.CI,
    timeout: 10000,
    stdout: 'ignore',
    stderr: 'pipe',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    // Uncomment to add Firefox coverage once Chromium suite is stable:
    // {
    //   name: 'firefox',
    //   use: { ...devices['Desktop Firefox'] },
    // },
  ],

  // Store test artifacts where CI can collect them
  outputDir: 'tests/playwright-results',
});
