# A-04 Angular unit tests: cart and order status

## Goal

Unit test Angular code: a service with signals and a component that talks to
the API and polls it, without a browser and without a backend.

## Context

**`CartService`** (`app/frontend/src/app/cart/cart.service.ts`) keeps the cart:

- `add(product)` adds one unit; the same product stays on one line.
- `setQuantity(id, n)` clamps the quantity to 1..10; `remove(id)` removes only
  that product; `clear()` empties the cart.
- `count()` is the number of units; `subtotalInCents()` is the sum of
  `quantity x priceInCents`; `isEmpty()` says whether there is any line.
- The cart is saved in `localStorage`, so a reload keeps it.

**`OrderStatusComponent`** (`app/frontend/src/app/orders/order-status.component.ts`)
shows one order (input `id`):

- loads `GET /api/orders/{id}` and shows the status;
- while the order is `PENDING`, loads it again every `ORDER_POLL_INTERVAL_MS`
  (an injection token, 2000 ms by default); it **stops** at `CONFIRMED` or `CANCELLED`;
- for a `CONFIRMED` order, shows a **Download invoice** link from
  `GET /api/orders/{id}/invoice`;
- shows a **Cancel order** button only for `PENDING` orders; it calls
  `POST /api/orders/{id}/cancel` and shows the API `message` (in an element with
  `role="alert"`) when the API answers 409;
- shows "Order not found" when the API answers 404.

## Your task

1. Create `app/frontend/src/app/cart/cart.service.spec.ts` and
   `app/frontend/src/app/orders/order-status.component.spec.ts` (exactly these
   names: the review runs only these two files).
2. Use `TestBed`. For HTTP, provide `provideHttpClient()` and
   `provideHttpClientTesting()` and drive responses with `HttpTestingController`.
   For polling, use Vitest fake timers (`vi.useFakeTimers()`,
   `vi.advanceTimersByTimeAsync(...)`) and a small `ORDER_POLL_INTERVAL_MS`.
3. Run them with `npm test` in `app/frontend`, then
   `./scripts/review.sh a-unit-testing/04-angular-unit --quick`.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | the two spec files exist and pass against the real code |
| Bug bank | 50 | share of planted bugs in the cart and the order page your tests catch |
| Mutation score | 25 | Stryker on `cart.service.ts` and `order-status.component.ts`; full points at 80% |
| Practices | 25 | no skipped tests, every test asserts, no hard-coded hosts or ports |

Mutation testing runs your specs once per mutant, so the full review takes
several minutes: use `--quick` while you iterate.

## Hints

- `HttpTestingController.expectOne(url)` fails when the request was not made;
  `expectNone(url)` and `verify()` fail when an extra one was.
- After `fixture.componentRef.setInput(...)`, run `fixture.detectChanges()` so
  effects run, then advance the fake clock for the first request.
- Assert on what the user sees: text, links and buttons in `fixture.nativeElement`.
- One item with quantity 1 cannot tell `quantity x price` from `price`.

## Further reading

- [Angular: testing services](https://angular.dev/guide/testing/services)
- [Angular: testing components](https://angular.dev/guide/testing/components-basics)
- [Angular: testing HTTP requests](https://angular.dev/guide/http/testing)
- [Vitest: fake timers](https://vitest.dev/guide/mocking/timers)
- [Stryker: mutant states and metrics](https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/)
