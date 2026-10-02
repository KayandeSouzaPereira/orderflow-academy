# OrderFlow end-to-end tests (Playwright)

Tests for track C. Each topic has its folder in `tests/tracks/<id>/`, with its
own page objects and fixtures (from C-04 you may import the page objects you
wrote in C-03).

```bash
npm ci
npx playwright install chromium

# Against the full stack (as reviews and CI do):
E2E_BASE_URL=http://localhost:4200 API_BASE_URL=http://localhost:8080 npx playwright test tests/tracks/c01

# Local development: starts the Angular dev server (the backend must be running):
npx playwright test --ui
```

`support/environment.ts` gives you `apiBaseURL` (for test data through the
API) and helpers for unique ids and e-mails. Only Chromium is used.
