# B-07 Order lifecycle and concurrency

## Goal

Test the order state machine and a race condition through the API, using the
processor delay to observe states that only last a few seconds.

## Context

- Valid transitions: `PENDING -> CONFIRMED` (processor) and `PENDING -> CANCELLED` (API).
  No other transition is valid.
- `POST /api/orders/{id}/cancel`: 200 for a `PENDING` order; **409**
  `INVALID_ORDER_TRANSITION` for a `CONFIRMED` (or `CANCELLED`) one.
- A cancelled order must stay cancelled, even when the processor gets to it later.
- Every `CONFIRMED` order has a downloadable invoice.
- Stock is reserved atomically: when several orders compete for the last unit,
  exactly one succeeds (201) and the others get 409 `OUT_OF_STOCK`.

In the review stack the processor handles an order about 3 seconds after it is
created: before that the order is `PENDING`, after that it is `CONFIRMED`
(unless cancelled).

## Your task

1. Write your tests in `app/api-tests/src/test/java/dev/orderflow/apitests/tracks/b07/`.
2. Cover cancellation of a `PENDING` order (and what happens afterwards),
   cancellation of a `CONFIRMED` order, and the invoice of confirmed orders.
3. Send several orders for the last unit **at the same time** (threads, a
   `CountDownLatch` to release them together) and check every response and
   the final stock.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Prerequisite | - | black-box only |
| Gate | - | your tests pass against the real stack |
| Bug bank | 70 | share of planted bugs in the lifecycle your tests catch |
| Practices | 30 | **no `Thread.sleep` (counts double)**, no disabled tests, every test asserts, no hard-coded endpoints, naming, stable in random order |

## Hints

- "Stays cancelled" is a statement over time: Awaitility's `during(...)`
  checks that a condition keeps holding.
- To get a `CONFIRMED` order, wait for it with Awaitility.
- For the race, count successes and failures; one success is not enough proof.

## Further reading

- [Awaitility: during](https://github.com/awaitility/awaitility/wiki/Usage#ignoring-exceptions-and-during)
- [java.util.concurrent: CountDownLatch](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/CountDownLatch.html)
- [Martin Fowler: Testing asynchronous code](https://martinfowler.com/articles/nonDeterminism.html)
