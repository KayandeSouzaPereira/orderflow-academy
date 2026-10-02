# A-02 Test doubles: order use cases with Mockito

## Goal

Test application logic in isolation: replace the database, the queue and the
clock with test doubles, and check both what the code returns and what it
does to its collaborators.

## Context

The application layer (`app/backend/src/main/java/dev/orderflow/application/`)
depends only on interfaces (ports): `ProductRepository`, `OrderRepository`,
`EventPublisher`, `IdGenerator`, plus a `java.time.Clock`. Every class has a
plain constructor, so you can build it with `new` and Mockito mocks.

**`CreateOrderUseCase.execute(command)`**

1. Validates the request (`OrderValidator`): invalid e-mail, no items or a
   quantity outside 1..10 throw `DomainException` with code `VALIDATION_ERROR`.
2. Every product must exist, otherwise `DomainException` `PRODUCT_NOT_FOUND`.
3. Reserves stock, once per product (lines of the same product are added up).
   If one reservation fails, the ones already made are released and
   `DomainException` `OUT_OF_STOCK` is thrown.
4. Saves the order as `PENDING`, with prices copied from the products and the
   total from `OrderPricing`.
5. If saving fails, the reserved stock is released and the error is rethrown;
   **no event is published**.
6. Only **after** the order is saved, publishes `OrderCreated`.

**`CancelOrderUseCase.execute(orderId)`**

1. Unknown order: `DomainException` `ORDER_NOT_FOUND`.
2. Only `PENDING` orders can be cancelled; otherwise `INVALID_ORDER_TRANSITION`.
3. Saves the order as `CANCELLED` (only if it is still `PENDING`) and gives
   back the stock of every item.

## Your task

1. Write your tests in `app/backend/src/test/java/dev/orderflow/tracks/a02/`.
2. Use real objects for the domain (`OrderValidator`, `OrderPricing`,
   `OrderStateMachine`), mocks or fakes for the ports, and
   `Clock.fixed(...)` for time (or `TestData.fixedClock()` from
   `dev.orderflow.support`).
3. Do not start Quarkus: no `@QuarkusTest`, no `@InjectMock`.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | your tests compile and pass against the real code |
| Bug bank | 50 | share of planted bugs in the two use cases your tests catch |
| Mutation score | 25 | PIT on `CreateOrderUseCase` and `CancelOrderUseCase`; full points at 80% |
| Practices | 25 | no `Thread.sleep`, no disabled tests, every test asserts, `should<Result>When<Condition>` names, stable in random order, no `@QuarkusTest` |

## Hints

- A mock answers `false`, `null` or `Optional.empty()` unless told otherwise:
  stub what the scenario needs, nothing more.
- `verify(...)` checks that something happened; `verify(..., never())` that it did not.
- Order matters in rule 6: look at `Mockito.inOrder(...)`.
- Make a collaborator fail on purpose (`when(...).thenThrow(...)` or `doThrow`)
  to test the unhappy paths.
- `ArgumentCaptor` lets you assert on the order that was saved.

## Further reading

- [Mockito documentation](https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html)
- [Martin Fowler: Mocks aren't stubs](https://martinfowler.com/articles/mocksArentStubs.html)
- [Martin Fowler: Test double](https://martinfowler.com/bliki/TestDouble.html)
