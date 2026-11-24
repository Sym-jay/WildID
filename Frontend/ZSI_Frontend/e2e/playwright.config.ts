import { defineConfig, devices } from '@playwright/test';

// Tests run against the web demo build:
//   flutter build web --dart-define=ZSI_DEMO=true
// Demo mode returns a labelled sample result, so no API key is needed.
const port = 8799;
const ci = !!process.env.CI;

export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  expect: { timeout: ci ? 15_000 : 10_000, toHaveScreenshot: { maxDiffPixelRatio: 0.02 } },
  // Baselines are captured on Windows; Linux runners render fonts slightly
  // differently, so CI runs every functional check but skips pixel diffs.
  ignoreSnapshots: ci,
  fullyParallel: true,
  // Flutter web is CPU-heavy; too many parallel browsers cause timeouts.
  workers: ci ? 2 : 4,
  retries: ci ? 1 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: `http://127.0.0.1:${port}`,
    trace: 'retain-on-failure',
  },
  webServer: {
    command: `node serve.mjs`,
    env: { PORT: String(port) },
    url: `http://127.0.0.1:${port}/`,
    reuseExistingServer: !process.env.CI,
  },
  projects: [
    { name: 'pixel7-light', use: { ...devices['Pixel 7'], colorScheme: 'light' } },
    { name: 'pixel7-dark', use: { ...devices['Pixel 7'], colorScheme: 'dark' } },
    { name: 'iphone14-light', use: { ...devices['iPhone 14'], colorScheme: 'light', browserName: 'chromium' } },
  ],
});
