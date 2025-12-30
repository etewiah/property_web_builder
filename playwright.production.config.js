// @ts-check
const { defineConfig, devices } = require('@playwright/test');

/**
 * Playwright Configuration for Production Visual Regression Tests
 *
 * This config is specifically for testing the production site at
 * https://demo.propertywebbuilder.com and its theme subdomains.
 *
 * Usage:
 *   # Run all production visual tests
 *   npx playwright test --config=playwright.production.config.js
 *
 *   # Update snapshots after intentional changes
 *   npx playwright test --config=playwright.production.config.js --update-snapshots
 *
 *   # Run specific test file
 *   npx playwright test --config=playwright.production.config.js tests/e2e/visual/production.spec.js
 */

module.exports = defineConfig({
  // Only run visual regression tests for production
  testDir: './tests/e2e/visual',
  testMatch: ['**/*.spec.js'],

  // Snapshot settings
  snapshotDir: './tests/e2e/visual/snapshots',
  snapshotPathTemplate: '{snapshotDir}/{testFileDir}/{testFileName}-snapshots/{arg}{-projectName}{ext}',

  // Don't run tests in parallel to avoid rate limiting
  fullyParallel: false,
  workers: 1,

  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,

  // Retry failed tests (useful for flaky network conditions)
  retries: process.env.CI ? 2 : 1,

  // Reporter configuration
  reporter: [
    ['html', { outputFolder: 'playwright-report-production', open: 'never' }],
    ['list'],
  ],

  // Global test timeout (production sites may be slower)
  timeout: 60000,

  // Expect timeout for assertions
  expect: {
    timeout: 10000,
    // Default screenshot comparison settings
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.05,
      threshold: 0.2,
      animations: 'disabled',
    },
  },

  // Shared settings for all projects
  use: {
    // No baseURL - tests use full URLs for different subdomains
    baseURL: undefined,

    // Collect trace when retrying the failed test
    trace: 'on-first-retry',

    // Screenshot on failure
    screenshot: 'only-on-failure',

    // Video on retry
    video: 'on-first-retry',

    // Longer navigation timeout for production
    navigationTimeout: 30000,

    // Action timeout
    actionTimeout: 15000,
  },

  // Configure projects for different browsers/devices
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1440, height: 900 },
      },
    },
    {
      name: 'firefox',
      use: {
        ...devices['Desktop Firefox'],
        viewport: { width: 1440, height: 900 },
      },
    },
    {
      name: 'webkit',
      use: {
        ...devices['Desktop Safari'],
        viewport: { width: 1440, height: 900 },
      },
    },
    // Mobile Chrome
    {
      name: 'mobile-chrome',
      use: {
        ...devices['Pixel 5'],
      },
    },
    // Mobile Safari
    {
      name: 'mobile-safari',
      use: {
        ...devices['iPhone 13'],
      },
    },
  ],

  // Output folder for test artifacts
  outputDir: 'test-results-production',
});
