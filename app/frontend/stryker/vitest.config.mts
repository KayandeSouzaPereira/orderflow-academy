// Vitest config used only by Stryker (mutation testing). `ng test` keeps using
// the Angular CLI's own Vitest setup; this one compiles Angular with the Analog
// plugin so Stryker can run Vitest directly.
//
// STRYKER_TEST_FILES (comma-separated globs) limits the tests to a topic's specs.
import angular from '@analogjs/vite-plugin-angular';
import { defineConfig } from 'vitest/config';

const include = (process.env['STRYKER_TEST_FILES'] ?? 'src/**/*.spec.ts')
  .split(',')
  .map((pattern) => pattern.trim())
  .filter((pattern) => pattern.length > 0);

export default defineConfig({
  plugins: [angular({ tsconfig: 'tsconfig.spec.json' })],
  test: {
    globals: true,
    environment: 'jsdom',
    // The Analog plugin defaults to the 'vmThreads' pool, where test files run
    // in a separate VM context and never see Stryker's active-mutant global.
    pool: 'forks',
    setupFiles: ['stryker/test-setup.ts'],
    include,
    reporters: ['default'],
  },
});
