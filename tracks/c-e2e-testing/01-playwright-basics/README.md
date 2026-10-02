# C-01 Playwright basics: the catalog

## Goal

Get to know Playwright: run tests in UI and headed mode, record a flow with
codegen and rewrite it by hand, find elements the way users do (accessible
locators) and read a trace when a test fails.

## Context

The tests live in `app/e2e` (TypeScript, `@playwright/test`, Chromium only).
`playwright.config.ts` reads the UI address from `E2E_BASE_URL`
(default `http://localhost:4200`); without it, it starts the Angular dev
server for you. Traces and videos are kept only for failed tests.

The catalog page (`/`) shows one card per product: an `article` named after
the product, with its image, price (e.g. `R$89.90`), stock (`In stock (60)` or
`Out of stock`) and an **Add to cart** button (disabled without stock). The
browser tab title is `Catalog | OrderFlow`.

## Your task

1. `cd app/e2e && npm ci && npx playwright install chromium`.
2. Start the app (`docker compose --profile full up -d --build --wait` in `app/`)
   and run `E2E_BASE_URL=http://localhost:4200 npx playwright test --ui`.
3. Record a visit to the catalog with `npx playwright codegen http://localhost:4200`,
   then rewrite it by hand, keeping only meaningful steps and assertions.
4. Write your tests in `app/e2e/tests/tracks/c01/` (files `*.spec.ts`): the page
   title, the price and stock of a product, a product without stock, and that
   images really load.
5. Break a test on purpose, run it, and open its trace with
   `npx playwright show-trace test-results/<test>/trace.zip`.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | your tests pass against the full stack |
| Bug bank | 70 | share of planted UI bugs your tests catch |
| Practices | 30 | no `.only`/`.skip`, every test asserts, accessible locators, no hard-coded base URL, no `waitForTimeout`, passes twice more without retries |

## Hints

- `page.getByRole('article', { name: 'USB-C Hub' })` scopes the next locators to one card.
- Web-first assertions (`await expect(locator).toBeVisible()`) wait by themselves.
- An `<img>` can be on the page and still be broken: its `naturalWidth` is 0.

## Further reading

- [Playwright: writing tests](https://playwright.dev/docs/writing-tests)
- [Playwright: locators](https://playwright.dev/docs/locators)
- [Playwright: UI mode](https://playwright.dev/docs/test-ui-mode) and [codegen](https://playwright.dev/docs/codegen)
- [Playwright: trace viewer](https://playwright.dev/docs/trace-viewer)
