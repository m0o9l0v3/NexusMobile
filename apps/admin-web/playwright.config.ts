import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  workers: process.env.CI ? 2 : undefined,
  reporter: 'list',
  use: { baseURL: 'http://127.0.0.1:5179', trace: 'retain-on-failure' },
  webServer: {
    command: 'npm run dev -- --host 127.0.0.1 --strictPort',
    url: 'http://127.0.0.1:5179',
    reuseExistingServer: false,
  },
});
