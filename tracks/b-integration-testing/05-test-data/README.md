# B-05 Test data: builders, isolation and stock

## Goal

Make every test own its data: build products and orders through the API,
never depend on seed data or on other tests, and use that to test stock
control and the per-customer order list.

## Context

- `GET /api/orders?customerEmail=...` lists the orders of **one** customer.
- Creating an order takes the ordered units from the product stock; two lines
  of the same product take the **sum** of both.
- Cancelling a `PENDING` order (`POST /api/orders/{id}/cancel`) gives the stock back.
  Orders stay `PENDING` for about 3 seconds before the processor confirms them.
- `GET /api/products/{id}` shows the current `stock`; `TestApi.setStock` overwrites it.

Tests that share data break each other: a test that relies on "the first
product" or on a fixed e-mail passes alone and fails in a full run, or on the
second run against the same stack.

## Your task

1. In `app/api-tests/src/test/java/dev/orderflow/apitests/tracks/b05/`, write
   two builders: `ProductTestData` (creates a product through the admin API with
   a unique name and the stock you ask for) and `OrderTestData` (creates an order
   with a unique e-mail by default).
2. Using them, test the per-customer list and the stock rules above.
3. Run your suite twice in a row against the same stack: it must pass both times.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Prerequisite | - | black-box only |
| Gate | - | your tests pass against the real stack |
| Bug bank | 70 | share of planted bugs in stock and customer queries your tests catch |
| Practices | 30 | no `Thread.sleep`, no disabled tests, every test asserts, no hard-coded endpoints, naming; **random order** and **second run on the same stack** count double |

## Hints

- `UUID.randomUUID()` in names and e-mails makes data unique per test and per run.
- Read the stock before and after: the difference is what the order took.
- To test a filter, create data that must be filtered out.

## Further reading

- [Martin Fowler: Object Mother and Test Data Builder](https://martinfowler.com/bliki/ObjectMother.html)
- [xUnit Patterns: Fresh fixture](http://xunitpatterns.com/Fresh%20Fixture.html)
- [xUnit Patterns: Interacting tests](http://xunitpatterns.com/Erratic%20Test.html#Interacting%20Tests)
