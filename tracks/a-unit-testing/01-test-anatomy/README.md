# A-01 Test anatomy: pricing rules

## Goal

Write focused unit tests for `OrderPricing`: one behaviour per test, a name
that says what is expected, and an assertion that would fail if the behaviour
broke. Then fix three badly written tests.

## Context

`OrderPricing` (`app/backend/src/main/java/dev/orderflow/domain/OrderPricing.java`)
computes the total of an order. It is pure Java: no framework, no database.

The rules (all amounts are integers in cents):

1. The subtotal is the sum of `quantity x unitPriceInCents` over all items.
2. Orders **strictly above** R$500.00 (`50000` cents) get **10% off**.
   An order of exactly `50000` gets no discount.
3. The discounted total is **rounded down** to the cent (`50009` becomes `45008`).
4. A negative quantity or unit price is rejected with an `IllegalArgumentException`,
   so a total is never negative.
5. An empty list of items totals `0`.

A good unit test follows **Arrange, Act, Assert**: build the input, call the
method once, check one behaviour. If a test name needs "and", it is probably
two tests.

## Your task

1. Write your tests in `app/backend/src/test/java/dev/orderflow/tracks/a01/`
   (package `dev.orderflow.tracks.a01`). Cover every rule above, including
   the boundaries.
2. Copy `starter/OrderPricingStarterTest.java` into the same folder (keep the
   class name) and fix its three tests:
   - one has a generic name that says nothing about the expected result;
   - one has no assertion at all;
   - one checks two different behaviours at once.
3. Run `./scripts/review.sh a-unit-testing/01-test-anatomy --quick` while you
   work, and a full review at the end.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | your tests compile and pass against the real code |
| Bug bank | 50 | share of planted bugs in `OrderPricing` your tests catch |
| Mutation score | 25 | PIT on `OrderPricing`; full points at 80% |
| Practices | 25 | no `Thread.sleep`, no disabled tests, every test asserts, `should<Result>When<Condition>` names, stable in random order, starter tests fixed |

70 points or more completes the topic.

## Hints

- Boundaries hide most bugs: test just below, exactly at and just above the threshold.
- A total with a fractional discount is the only way to see the rounding direction.
- One item with quantity 1 cannot tell `quantity x price` from `price`.
- Ask yourself, for each test: which wrong implementation would still pass it?

## Further reading

- [JUnit 5 user guide: writing tests](https://junit.org/junit5/docs/current/user-guide/#writing-tests)
- [AssertJ core guide](https://assertj.github.io/doc/#assertj-core)
- [Martin Fowler: Unit test](https://martinfowler.com/bliki/UnitTest.html)
- [PIT: basic concepts](https://pitest.org/quickstart/basic_concepts/)
