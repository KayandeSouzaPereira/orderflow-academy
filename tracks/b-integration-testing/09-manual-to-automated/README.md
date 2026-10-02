# B-09 From manual cases to automated tests

## Goal

Turn your manual testing experience into an automated regression suite: write
the test cases first, as you would for a manual campaign, then automate every
one of them and keep the link between case and test.

## Context

This topic has two parts and spans the whole track:

1. **Right after B-02**: write 10 manual test cases for OrderFlow's business
   rules (catalog, order creation, validations, stock, confirmation and invoice,
   cancellation, concurrency). Use `manual-cases.template.md`: id, business
   rule, preconditions, steps, expected result.
2. **At the end of the track**: automate all of them with what you learned in
   B-03 to B-07. Each test is tagged with the case it automates:

```java
@Test
@Tag("MC-04")
void shouldReturn400WhenQuantityIsOutOfRange() { ... }
```

A dev reviews your cases (pull request, as in B-02) before you automate them.

## Your task

1. Copy `manual-cases.template.md` to `app/api-tests/manual-cases.md` and write
   at least 10 cases (`## MC-01 ...` to `## MC-10 ...`).
2. Automate them in `app/api-tests/src/test/java/dev/orderflow/apitests/tracks/b09/`.
   One case may need several tests; every case needs at least one.
3. Run `./scripts/review.sh b-integration-testing/09-manual-to-automated`.
   It takes longer than the other topics: it checks 20 bugs.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Prerequisite | - | black-box only |
| Gate | - | your tests pass against the real stack |
| Bug bank | 70 | the bugs of B-03 to B-07 together (20): share your suite catches |
| Practices | 30 | the usual API-test practices, plus **traceability** (counts double): at least 10 cases, and every case id has a `@Tag` test |

## Hints

- Good manual cases already contain the assertions: the "expected result" is
  what your test must check.
- Cover the rules, not the screens: each business rule deserves at least one case.
- Reuse your builders and helpers from earlier topics (copy them into the b09 package).

## Further reading

- [JUnit 5: tagging and filtering](https://junit.org/junit5/docs/current/user-guide/#writing-tests-tagging-and-filtering)
- [ISTQB glossary: test case](https://glossary.istqb.org/en_US/term/test-case)
- [Martin Fowler: Test pyramid and regression suites](https://martinfowler.com/articles/practical-test-pyramid.html)
