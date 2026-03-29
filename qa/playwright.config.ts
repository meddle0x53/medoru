import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration for Medoru QA testing
 *
 * @see https://playwright.dev/docs/test-configuration
 */
export default defineConfig({
  // Test directory
  testDir: './scenarios',

  // Run tests in files in parallel
  fullyParallel: true,

  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,

  // Retry on CI only
  retries: process.env.CI ? 2 : 0,

  // Opt out of parallel tests on CI
  workers: process.env.CI ? 1 : undefined,

  // Increase test timeout for dev environment (60 seconds)
  timeout: 60000,

  // Increase expect timeout
  expect: {
    timeout: 10000,
  },

  // Reporter to use
  reporter: [
    ['html', { open: 'never' }],
    ['list'],
    // Add JSON reporter for CI integration
    ...(process.env.CI ? [['json', { outputFile: 'test-results.json' }]] : [])
  ],

  // Shared settings for all the projects below
  use: {
    // Base URL for Medoru QA server
    baseURL: 'http://localhost:4001',

    // Collect trace when retrying the failed test
    trace: 'on-first-retry',

    // Take screenshot on failure
    screenshot: 'only-on-failure',

    // Record video on failure
    video: 'on-first-retry',

    // Action timeout - wait up to 15 seconds for actions
    actionTimeout: 15000,

    // Navigation timeout
    navigationTimeout: 30000,
  },

  // Configure projects for major browsers
  projects: [
    // Setup project for authentication
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts$/,
    },

    // Chromium (Chrome/Edge)
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        // Use storage state from setup
        storageState: 'playwright/.auth/user.json',
      },
      dependencies: ['setup'],
    },

    // Firefox - disabled (browser not installed)
    // {
    //   name: 'firefox',
    //   use: {
    //     ...devices['Desktop Firefox'],
    //     storageState: 'playwright/.auth/user.json',
    //   },
    //   dependencies: ['setup'],
    // },

    // WebKit (Safari) - disabled (browser not installed)
    // {
    //   name: 'webkit',
    //   use: {
    //     ...devices['Desktop Safari'],
    //     storageState: 'playwright/.auth/user.json',
    //   },
    //   dependencies: ['setup'],
    // },

    // Mobile Chrome - disabled (browser not installed)
    // {
    //   name: 'Mobile Chrome',
    //   use: {
    //     ...devices['Pixel 5'],
    //     storageState: 'playwright/.auth/user.json',
    //   },
    //   dependencies: ['setup'],
    // },

    // Mobile Safari - disabled (browser not installed)
    // {
    //   name: 'Mobile Safari',
    //   use: {
    //     ...devices['iPhone 12'],
    //     storageState: 'playwright/.auth/user.json',
    //   },
    //   dependencies: ['setup'],
    // }
  ],

  // Run local dev server before starting the tests
  webServer: {
    command: 'cd .. && MIX_ENV=qa mix phx.server',
    url: 'http://localhost:4001/qa/health',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000, // 2 minutes
  },
});
