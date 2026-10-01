# Track C: end-to-end testing with Playwright (everyone)

Tests that drive the real UI in Chromium against the full stack. Devs start
after track A; the QA after track B (C-03 prepares data through the API).
Tests are TypeScript, in `app/e2e/tests/tracks/<id>/`.

| Topic | What you learn |
| --- | --- |
| [01-playwright-basics](01-playwright-basics/) | Runner, UI mode, codegen, accessible locators, traces |
| [02-user-flows](02-user-flows/) | A full journey with auto-retrying assertions |
| [03-page-objects-and-fixtures](03-page-objects-and-fixtures/) | Page objects, custom fixtures, data through the API |
| [04-network-and-resilience](04-network-and-resilience/) | `page.route`: errors, slowness, malformed data |
| [05-e2e-in-ci](05-e2e-in-ci/) | The Playwright job in GitHub Actions |
