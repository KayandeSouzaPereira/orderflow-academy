import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration for OrderFlow end-to-end tests (track C).
 *
 * - E2E_BASE_URL: where the UI is served (default http://localhost:4200).
 *   Reviews and CI set it and start the full stack themselves.
 * - Without E2E_BASE_URL, local development starts the Angular dev server
 *   (`npm start` in ../frontend). The backend must be running already
 *   (`./mvnw quarkus:dev` in app/backend, or the full docker compose profile).
 */
const baseURL = process.env['E2E_BASE_URL'] ?? 'http://localhost:4200';
const localDevelopment = !process.env['E2E_BASE_URL'] && !process.env['CI'];

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env['CI'],
  retries: 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL,
    // Evidence only when something fails.
    trace: 'retain-on-failure',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: localDevelopment
    ? {
        command: 'npm start --prefix ../frontend',
        url: baseURL,
        reuseExistingServer: true,
        timeout: 120_000,
      }
    : undefined,
});
