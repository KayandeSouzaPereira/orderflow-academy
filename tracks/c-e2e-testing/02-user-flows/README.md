# C-02 User flows: from cart to confirmed order

## Goal

Test the purchase journey end to end, the way a customer lives it: add
products, adjust the cart, place the order and watch it move from PENDING to
CONFIRMED, using only assertions that retry by themselves.

## Context

- The header link shows the number of units in the cart: `Cart (2)`.
- The cart page (`/cart`) has a quantity field per product (label
  `Quantity of <product>`), the subtotal, an **E-mail** field and a **Place
  order** button, enabled only when the cart is not empty and the e-mail is valid.
  While the order is sent, the button is disabled and `Placing order…` is shown.
- After placing the order, the app goes to `/orders/<id>` and says
  `Order created! Your order ID is <id>.`
- The order page refreshes the status by itself: `PENDING` for about 3
  seconds in the review stack, then `CONFIRMED`, with a **Download invoice** link.

## Your task

1. Write your tests in `app/e2e/tests/tracks/c02/`.
2. Cover the cart (quantities, subtotal, header count) and the whole purchase,
   including the confirmation message and the status change.
3. Never wait with `page.waitForTimeout`: use `expect(...).toHaveText(...)`,
   `toBeVisible({ timeout })` or `expect.poll(...)`.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | your tests pass against the full stack |
| Bug bank | 70 | share of planted bugs in the purchase flow your tests catch |
| Practices | 30 | as C-01; **no `waitForTimeout` counts double** |

## Hints

- Read the order id from the URL after placing the order, then look for it on the page.
- The confirmation takes a few seconds: give that assertion a longer timeout.
- Products from the seed have plenty of stock; for scarce stock, wait for C-03.

## Further reading

- [Playwright: auto-waiting](https://playwright.dev/docs/actionability)
- [Playwright: assertions](https://playwright.dev/docs/test-assertions)
- [Playwright: expect.poll](https://playwright.dev/docs/test-assertions#expectpoll)
