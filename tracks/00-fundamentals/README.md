# 00 Fundamentals: what to test, where and why

## Goal

Share one vocabulary before writing tests: the kinds of tests, what each one
is good at, what it costs to keep, and where it runs in CI. Then answer a
10-question quiz.

## Context

### The test pyramid

Tests differ in **scope** (how much of the system runs), **speed** and
**cost of maintenance**. The pyramid is a rule of thumb for the mix:

```
          /\        end-to-end (UI)      few: slow, broad, costly to keep stable
         /  \
        /----\      integration / API    some: real infrastructure, one boundary at a time
       /      \
      /--------\    unit                 many: fast, precise, cheap
```

- **Unit tests** check one class or function in isolation, in memory. They run
  in milliseconds, point straight at the broken line and rarely break for
  reasons unrelated to the code under test. In OrderFlow: `OrderPricing`,
  `CreateOrderUseCase` with test doubles.
- **Integration tests** check that our code works with something real: a
  database, a queue, an HTTP server. *White-box* integration tests know the
  implementation (e.g. a DynamoDB adapter, checking the stored item).
  *Black-box* API tests only use the public interface (HTTP), the way a client
  would, and do not know how the data is stored.
- **End-to-end tests** drive the whole system through the UI, like a user.
  They give the most confidence per test, but are the slowest, the hardest to
  debug and the most likely to be **flaky** (pass and fail without any code
  change), usually because of timing, shared data or environment.

The pyramid is not a law: what matters is fast feedback for most changes and a
few broad tests for the critical journeys.

### Test doubles

A **test double** replaces a collaborator in a test. A **stub** returns canned
answers so the code under test can run; a **mock** also lets the test verify
which calls were made; a **fake** is a working lightweight implementation (an
in-memory repository). Doubles make unit tests fast and deterministic, but a
test that mocks the very thing it is testing proves nothing.

### Quality of a test suite

- **Coverage** says which lines ran during the tests, not whether anything was
  checked. A test without assertions can produce 100% coverage.
- **Mutation testing** changes the code on purpose (a `>` becomes `>=`, a
  return value becomes 0) and checks whether some test fails. The **mutation
  score** is the share of those changes that the tests catch: it measures how
  well the tests *check* behaviour.
- In this training, each topic plants real bugs and counts how many your tests
  catch. That is the same idea, with bugs written by a person.

### Cost of maintenance

Every test is code that must be read, fixed and kept fast. Tests are cheap to
keep when they check behaviour (inputs and outputs), not implementation
details; when each test owns its data; and when their names say what broke.
Tests that depend on the order they run in, on fixed waits (`sleep`) or on
shared state are the main source of flakiness.

### Where tests run in CI

| Stage | Tests | Typical time |
| --- | --- | --- |
| Every push / pull request | unit tests, fast integration tests | seconds to a few minutes |
| Before merge or on main | API tests against a deployed stack | minutes |
| On main, nightly or before release | end-to-end UI tests on the critical journeys | minutes to tens of minutes |

Fast tests run first so a broken build is reported early; slow, broad tests
run less often but still before users see the change.

## Your task

1. Read the Context above.
2. Copy `answers.template.yml` to `answers.yml` in this folder and replace each
   `?` with the letter you choose (`a`, `b`, `c` or `d`). The questions are in
   `quiz.yml`.
3. Run `./scripts/review.sh 00-fundamentals`. Commit `answers.yml` on your branch.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | `answers.yml` exists and answers at least one question |
| Quiz | 100 | 10 points per correct answer |

70 points or more completes the topic. A wrong answer shows a hint, never the
answer.

## Hints

- Every question can be answered from the Context section.
- When two options look right, pick the one that is true in every case.

## Further reading

- [Martin Fowler: The practical test pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)
- [Martin Fowler: Mocks aren't stubs](https://martinfowler.com/articles/mocksArentStubs.html)
- [Google Testing Blog: Flaky tests at Google](https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html)
- [PIT: mutation testing concepts](https://pitest.org/quickstart/basic_concepts/)
