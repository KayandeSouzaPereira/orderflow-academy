# C-03 Page objects and fixtures

## Goal

Make end-to-end tests readable and robust: hide selectors behind page
objects, inject them with custom fixtures, and prepare test data through the
API instead of clicking through the UI.

## Context

- **Page objects** are classes that know how to find and use one page
  (`CatalogPage`, `CartPage`, `OrderPage`). Specs talk to them, so a UI change
  is fixed in one place.
- **Fixtures** (`test.extend`) give each test what it needs, already set up:
  page objects, a product with a given stock, an order in a given state.
- **API data setup**: Playwright's `request` fixture calls the API directly.
  `support/environment.ts` gives you `apiBaseURL` and unique ids:
  `POST /api/admin/products` creates a product, `POST /api/orders` an order,
  `GET /api/orders/{id}` shows its status.

Behaviour to cover:

- an order refused for lack of stock shows the API message in an alert
  (`Not enough stock for product <id>.`);
- an invalid e-mail shows `Enter a valid e-mail address.` and keeps
  **Place order** disabled;
- a CONFIRMED order offers no **Cancel order** button;
- cancelling a PENDING order shows `CANCELLED` at once.

## Your task

1. Refactor your C-02 tests into page objects and fixtures, in
   `app/e2e/tests/tracks/c03/` (e.g. `pages.ts`, `fixtures.ts`, `*.spec.ts`).
2. Create every product and order the tests need with `request.post(...)` in fixtures.
3. Cover the four behaviours above.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Prerequisites | - | **page-objects** (spec files never call `page.getBy*`/`page.locator`) and **api-data-setup** (`request.post` in the topic folder); failing either scores 0 |
| Gate | - | your tests pass against the full stack |
| Bug bank | 70 | share of planted bugs your tests catch |
| Practices | 30 | as C-01 |

## Hints

- A product with stock 1 is the easiest way to get a 409.
- To test a CONFIRMED order, create it through the API and poll its status
  with `expect.poll` before opening the page.
- The processor waits about 3 seconds: open a fresh order right away to catch it PENDING.

## Further reading

- [Playwright: page object models](https://playwright.dev/docs/pom)
- [Playwright: fixtures](https://playwright.dev/docs/test-fixtures)
- [Playwright: API testing and the request fixture](https://playwright.dev/docs/api-testing)
