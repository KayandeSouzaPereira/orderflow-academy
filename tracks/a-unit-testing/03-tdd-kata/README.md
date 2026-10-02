# A-03 TDD kata: coupon policy

## Goal

Build `CouponPolicy` from scratch with test-driven development: red, green,
refactor, in small steps. Pairing in ping-pong style (one writes a failing
test, the other makes it pass) is recommended.

## Context

OrderFlow will accept discount coupons. A coupon is applied to the order total
after the 10% discount of large orders. The public API is ready in `starter/`:

- `Coupon`: code, type (`PERCENTAGE` or `FIXED`), value, minimum order, validity dates;
- `CouponException`: thrown with a `Reason` when a coupon cannot be applied;
- `CouponPolicy`: `apply(long totalInCents, List<Coupon> coupons)`, with a `Clock`
  in the constructor so tests control "today".

**Specification.** Checks happen in this order; the first that fails wins.

1. No coupon: the total is returned unchanged.
2. More than one coupon: `NOT_CUMULATIVE` (coupons do not combine).
3. Today (from the clock, as a `LocalDate`) before `validFrom`: `NOT_YET_VALID`.
   Today after `validUntil`: `EXPIRED`. Both days are inclusive.
4. Total below `minimumOrderInCents`: `MINIMUM_NOT_REACHED`. A total equal to
   the minimum is accepted.
5. `PERCENTAGE`: the value must be 1..100, otherwise `INVALID_COUPON`. The
   discount is `total x value / 100`, rounded down; the result is total minus discount.
6. `FIXED`: the value must be greater than 0, otherwise `INVALID_COUPON`. The
   result is total minus value, but **never below 0**.

## Your task

1. Copy the three files from `starter/` to
   `app/backend/src/main/java/dev/orderflow/domain/coupon/` without changing
   the public API (`Coupon` and `CouponException` stay exactly as they are).
2. Write tests in `app/backend/src/test/java/dev/orderflow/tracks/a03/`, one
   rule at a time, and make each pass with the simplest code.
3. **Commit often.** The review reads your Git history: for at least 60% of
   the commits that change `CouponPolicy.java`, the tests must change in the
   same commit or in the commit just before. When pairing, add
   `Co-authored-by: Name <email>` to the commit messages.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | your tests pass on your implementation **and** on a reference implementation of the same spec |
| Bug bank | 50 | the review swaps in the reference implementation with planted bugs; share your tests catch |
| Mutation score | 25 | PIT on **your** `CouponPolicy`; full points at 80% |
| Practices | 25 | no `Thread.sleep`, no disabled tests, every test asserts, `should<Result>When<Condition>` names, stable in random order, test-first Git history |

Your tests must only rely on the specification above. A test that checks a
detail the spec does not define (an exact error message, for example) fails
on the reference implementation and stops the review at the gate.

## Hints

- Start with the simplest rule (no coupon), then add one rule per cycle.
- `Clock.fixed(Instant.parse("2026-03-10T12:00:00Z"), ZoneOffset.UTC)` freezes "today".
- Every "inclusive" and "at least" in the spec deserves a test on the exact boundary.
- Assert the `reason()` of a `CouponException`, not only its type.

## Further reading

- [Kent Beck: Test-Driven Development by Example (summary)](https://martinfowler.com/bliki/TestDrivenDevelopment.html)
- [The three rules of TDD](http://butunclebob.com/ArticleS.UncleBob.TheThreeRulesOfTdd)
- [Ping-pong pair programming](https://martinfowler.com/articles/on-pair-programming.html#PingPong)
