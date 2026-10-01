# Example: testing the order state machine

> A warm-up topic to see how reviews work. It does not count towards the training.

## Goal

Write unit tests for `OrderStateMachine` and get familiar with the review
report: gate, bug bank, mutation score and practices.

## Context

An order is created as `PENDING`. The order processor moves it to `CONFIRMED`;
the customer can move it to `CANCELLED`. No other transition is valid.
`OrderStateMachine` (in `app/backend/src/main/java/dev/orderflow/domain/`) has
two methods: `canTransition(from, to)` answers whether a transition is allowed,
and `ensureCanTransition(from, to)` throws a `DomainException` with code
`INVALID_ORDER_TRANSITION` when it is not.

## Your task

1. Create your tests in `app/backend/src/test/java/dev/orderflow/tracks/example/`
   (package `dev.orderflow.tracks.example`).
2. Cover the allowed transitions and the rejected ones, for both methods.
3. Run `./scripts/review.sh _example` and read the report.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | your tests compile and pass against the real code |
| Bug bank | 50 | share of planted bugs your tests catch |
| Mutation score | 25 | PIT on `OrderStateMachine`, full points at 80% |
| Practices | 25 | no `Thread.sleep`, no disabled tests, every test asserts, `should<Result>When<Condition>` names, stable in random order |

70 points or more passes. Use `--quick` while iterating (skips mutation testing).

## Hints

- A transition table has 9 cells (3 x 3); how many does your suite check?
- Testing only that valid things work is half of the job.
- `@ParameterizedTest` with `@CsvSource` keeps a table-like test short.

## Further reading

- [JUnit 5: parameterized tests](https://junit.org/junit5/docs/current/user-guide/#writing-tests-parameterized-tests)
- [AssertJ: exception assertions](https://assertj.github.io/doc/#assertj-core-exception-assertions-assertThatThrownBy)
- [PIT: mutation testing basics](https://pitest.org/quickstart/basic_concepts/)
