# C-04 Network and resilience

## Goal

Check how the UI behaves when the network does not: server errors, slow
answers and malformed data, simulated with `page.route`.

## Context

`page.route(urlPattern, handler)` intercepts requests from the page. The
handler can answer itself (`route.fulfill({ status, body })`), delay
(`await` something, then `route.continue()`) or count requests.

Expected behaviour:

- when creating an order answers **500**, an alert says
  `Something went wrong while creating the order. Please try again.`;
- `Placing order…` is visible and **Place order** disabled while the request
  runs, and both go back to normal when it ends, even after a failure;
- a **double click** on Place order sends a single order;
- when an order comes back with unexpected JSON, the order page shows
  `The server sent an unexpected response.` instead of breaking.

## Your task

1. Write your tests in `app/e2e/tests/tracks/c04/`. You may import the page
   objects and fixtures you wrote in C-03.
2. Cover the four behaviours above with `page.route`.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | your tests pass against the full stack |
| Bug bank | 70 | share of planted bugs your tests catch |
| Practices | 30 | as C-01, plus page objects and API data setup |

## Hints

- To observe a loading state, hold the response until you have checked it
  (a promise you resolve later), instead of a fixed delay.
- Count requests inside the route handler; check the method too.
- Route only what the test is about (e.g. `**/api/orders`), and let the rest go to the real API.

## Further reading

- [Playwright: network](https://playwright.dev/docs/network)
- [Playwright: mock APIs](https://playwright.dev/docs/mock)
- [Playwright: Route](https://playwright.dev/docs/api/class-route)
