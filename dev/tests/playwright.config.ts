import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',

  use: {
    // Test server URL - use LUMENMON_TEST_URL env var or default to test server
    // Set LUMENMON_TEST_URL env var to your test server, e.g.: http://your-server:8080
    baseURL: process.env.LUMENMON_TEST_URL || 'http://localhost:8080',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  // Timeout settings
  timeout: 30000,
  expect: {
    timeout: 10000,
  },
});
