// playwright.config.js
// Configuration for the ESP32 gateway dashboard browser regression suite.
//
// The mock server is started automatically by webServer before any test runs.
// Tests use Chromium only as the primary target; Firefox is available via
// the 'firefox' project if needed.

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
