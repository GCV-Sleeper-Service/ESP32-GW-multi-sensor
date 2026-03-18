// playwright.config.js
// Configuration for the ESP32 gateway dashboard browser regression suite.
//
// The mock server is started automatically by webServer before any test runs.
//
// Browser coverage:
//   Chromium  — primary target, required for CI pass
//   Firefox   — secondary, catches Gecko-specific JS/CSS issues (BUG-014 crossorigin)
//   WebKit    — opt-in only (WEBKIT=1 env var). Playwright's WebKit on Linux requires
//               system libraries that are unavailable in most container environments
//               (ESPHome LXC, Docker). Run WebKit tests on a full desktop Linux or macOS.
//
// Parallelism:
//   fullyParallel: true — the mock server is stateless (fixture reads only, no
//   mutations), so concurrent workers sharing port 3737 is safe. page.route()
//   intercepts in BUG-043 tests are per-browser-context, not server-level.
//   Workers default to half the CPU cores. Override with --workers=N.
//
// Container / Linux sandbox note:
//   Chromium's default sandbox requires kernel features (user namespaces) that
//   are not available in most Docker / container environments including the
//   ESPHome container. The '--no-sandbox' arg in Chromium's launchOptions is
//   required for those environments. It is safe for a local test runner —
//   the risk model only applies when running untrusted web content.

'use strict';

const { defineConfig, devices } = require('@playwright/test');

const projects = [
  {
    name: 'chromium',
    use: {
      ...devices['Desktop Chrome'],
      // Required in container / Docker / ESPHome environments where the kernel
      // does not support Chromium's user-namespace sandbox.
      launchOptions: {
        args: ['--no-sandbox', '--disable-setuid-sandbox'],
      },
    },
  },
  {
    name: 'firefox',
    use: { ...devices['Desktop Firefox'] },
  },
];

// WebKit is opt-in: WEBKIT=1 npx playwright test
// Playwright's WebKit on Linux needs system libraries unavailable in containers.
if (process.env.WEBKIT === '1') {
  projects.push({
    name: 'webkit',
    use: { ...devices['Desktop Safari'] },
  });
}

module.exports = defineConfig({
  testDir: './tests/browser',

  // Parallel execution — mock server is stateless, safe for concurrent workers.
  // Each test gets its own browser context so page.route intercepts don't leak.
  fullyParallel: true,

  // Half the CPU cores by default. Override: npx playwright test --workers=4
  workers: undefined,

  // Fail fast on CI; locally allow retries
  retries: process.env.CI ? 1 : 0,

  // Timeout per test (dashboard has async chart + history loading;
  // BUG-043 timing tests use up to 15s waits)
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

  projects: projects,

  // Store test artifacts where CI can collect them
  outputDir: 'tests/playwright-results',
});
