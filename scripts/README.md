# Review engine

Scripts that score a topic from 0 to 100. Participants only need
`./scripts/review.sh`; the rest of this page is for maintainers.

## Usage

```bash
./scripts/review.sh <track>/<topic>            # full review
./scripts/review.sh <track>/<topic> --quick    # no mutation testing (partial score)
./scripts/review.sh <track>/<topic> --json     # also write results/<track>-<topic>.json
./scripts/review-all.sh [--quick]              # every topic + summary table
```

Maintainers can also pass `--overlay <dir>`: `<dir>/app` is copied over the
reviewed copy. This is how reference and calibration solutions are checked:

```bash
./scripts/review.sh _example --overlay tracks/_example/reference           # must score >= 90
./scripts/review.sh _example --overlay tracks/_example/calibration-weak    # must score < 70
```

Exit codes: `0` passed, `1` below the threshold, `2` gate failed, `3`
environment or configuration error.

Requirements: Bash 4+ (Bash 5 recommended), `git`, `tar`, `jq`, [`yq` v4
(mikefarah)](https://github.com/mikefarah/yq), plus Java 21+ for Java topics and
Docker for topics that need Floci or the full stack. XML reports (Surefire,
PIT) are read with `yq -p xml`, so `xmllint` is not needed.

## Maintainer checks (also run by `main-ci.yml`)

```bash
./scripts/dev/validate-structure.sh       # every topic and bug well formed, every patch applies
./scripts/dev/validate-topic.sh <topic> --solutions ../orderflow-academy-private/solutions
```

`validate-topic.sh` checks the definition of done of a topic's bug bank:
without tests the review stops at the gate (exit 2); the `reference` solution
catches 100% of the bugs, scores at least 90 and raises no warning; the
`calibration-weak` solution (if any) scores below the threshold. Solutions are
read from the private repository (`solutions/<track>/<topic>/`) and, for the
public example only, from `tracks/_example/`.

## How a review works

1. **Pre-checks**: tools, Java, Docker. Failure: exit 3.
2. **Isolated copy**: `app/` is copied to a temporary directory (without
   `node_modules`, `target`, `dist`). The participant's working tree is never
   changed. Containers and temporary files are removed on exit, including
   Ctrl+C.
3. **Required practices** (e.g. `black-box-only`): failure scores 0, exit 2.
4. **Stack** (`requires_stack: true`): compose project `orderflow-review` on
   ports 14566/18080/14200, so it never clashes with the developer stack.
5. **Gate**: the topic's tests must compile, pass against the real code and
   be at least one. Failure scores 0, exit 2.
6. **Practices**: rules listed in `topic.yml` (static checks and extra runs).
7. **Bug bank**: for each `bugs/BUG-NN`, apply the patch, rebuild what is
   needed, run the topic's tests; the bug is *detected* when a test fails.
   A patch that does not apply or compile is ignored and reported as a warning.
8. **Mutation testing**: PIT on `mutation.target_classes` (skipped with `--quick`).

## Files of a topic

```
tracks/<track>/<NN-topic>/
├── README.md       Goal, Context, Your task, How you are scored, Hints, Further reading
├── topic.yml       settings read by the scripts
├── review.sh       sources scripts/lib/standard.sh (or scores a custom topic itself)
└── bugs/BUG-NN/    bug.yml + patch.diff
```

### topic.yml

```yaml
id: a01
title: Test anatomy
track: a-unit-testing
kind: backend                 # backend | api | frontend | e2e | custom
test_package: dev.orderflow.tracks.a01
# kind frontend lists spec files instead (relative to app/frontend):
# test_files: [src/app/cart/cart.service.spec.ts]
# kind e2e names the test folder (relative to app/e2e):
# test_dir: tests/tracks/c01
requires_stack: false         # true: build and start the full stack (kind api)
requires_docker: false        # true: Docker needed without the stack (Testcontainers)
pass_threshold: 70
weights: { bugs: 50, mutation: 25, practices: 25 }   # defaults: backend 50/25/25, api 70/0/30
mutation:
  target_classes: ["dev.orderflow.domain.OrderPricing"]   # frontend: source files
  target_tests: ["dev.orderflow.tracks.a01.*"]            # default: <test_package>.* (frontend: test_files)
  target_score: 80
implementation_swap:          # TDD kata only: bugs are planted in a reference implementation
  path: app/backend/src/main/java/dev/orderflow/domain/coupon/CouponPolicy.java
  reference: bugs/reference/CouponPolicy.java
bug_bank: { min: 4, max: 6 }  # optional: expected number of bugs
bug_sources: [b-integration-testing/03-api-test-setup]  # optional: reuse other topics' bugs (B-09)
practices:
  - no-thread-sleep
  - { rule: every-test-asserts, weight: 2 }          # counts twice
  - { rule: idempotent-data, required: true }        # prerequisite: failing scores 0
assertion_patterns: []        # optional EREs replacing the recognised assertions
stack: { processor_delay_ms: 3000 }
timeouts: { test_run_seconds: 300 }
```

### bug.yml

```yaml
id: BUG-02
title: OrderCreated event is never published     # shown only when the bug is missed
hint: Follow the order until the end of its lifecycle, not just the POST response.
side: backend                                    # backend | frontend: what is rebuilt
files: [app/backend/src/main/java/dev/orderflow/application/CreateOrderUseCase.java]
```

Create bugs with the helper, which writes `patch.diff` from your uncommitted
changes in `app/` (commit unrelated work first):

```bash
# 1. change production code in app/ to plant the bug
./scripts/dev/new-bug.sh a-unit-testing/02-test-doubles BUG-03
# 2. fill in title and hint in bug.yml, 3. restore the files it lists
```

## Practice rules

| Rule | Check |
| --- | --- |
| `no-thread-sleep` | no `Thread.sleep` / `TimeUnit.X.sleep` in the topic's tests |
| `no-disabled-tests` | no `@Disabled`, `@Ignore`, `xit`, `xdescribe`, `.skip(` |
| `every-test-asserts` | every `@Test`/`@ParameterizedTest`/`@RepeatedTest` method (or `it`/`test` block) has an assertion; calls to helpers named `assert*`, `await*`, `expect*` or `verify*` count |
| `no-hardcoded-endpoints` | no `localhost:<port>`, `:4566` or `.port(<number>)` |
| `naming-convention` | test methods match `should<Result>When<Condition>` |
| `random-order-stable` | suite passes twice with random class and method order (fixed seeds) |
| `idempotent-data` | suite passes again on the same environment |
| `black-box-only` | always a prerequisite: no backend or AWS SDK in `api-tests` |
| `no-quarkus-test` | no `@QuarkusTest`, `@InjectMock` and friends (pure unit tests) |
| `starter-fixed` | the starter test class was copied and fixed (`file`, `forbidden_names`, `min_tests`) |
| `tdd-history` | Git history: tests change in or right before most implementation commits (`implementation`, `min_percent`); skipped with `--overlay` |
| `traceability` | every `## MC-NN` case of `cases_file` has a `@Tag("MC-NN")` test; at least `min_cases` cases |
| `no-wait-for-timeout` | no `page.waitForTimeout` (Playwright) |
| `no-test-only` | no `test.only`/`.skip`/`.fixme`, `describe.only`/`.skip` |
| `accessible-locators` | `page.locator(...)` only for `[data-testid]`; no `$()`, `$$()`, XPath |
| `no-hardcoded-base-url` | no `http://localhost...`, `:4200` or `:8080` in tests |
| `page-objects` | `*.spec.ts` files never call `page.getBy*` or `page.locator` |
| `api-data-setup` | the topic folder prepares data with `request.post(...)` |
| `stable-without-retries` | the suite passes twice more with `--retries=0` |

Each rule is worth `practices weight x rule weight / sum of rule weights`.
Criteria are rounded to the nearest point. `every-test-asserts` understands
JUnit methods and TypeScript `it()`/`test()` blocks. `no-empty-catch` and
`original-tests-kept` come with the bonus challenge (phase 7).

Several reviews with a stack can run at the same time with different
`REVIEW_STACK_PROJECT`, `REVIEW_FLOCI_PORT`, `REVIEW_BACKEND_PORT` and
`REVIEW_FRONTEND_PORT`.

Mutation testing: PIT for backend topics; Stryker for frontend topics, through
its command runner (see `app/frontend/stryker.config.json` and
[docs/DECISIONS.md](../docs/DECISIONS.md)).

## Library API (`scripts/lib/score.sh`)

| Function | Use |
| --- | --- |
| `score_begin <topic-dir>` | reads `topic.yml`, prints the header |
| `score_gate <ok> <detail>` | records the gate; exits 2 when it fails |
| `score_criterion <name> <earned> <max> <detail> [ok\|fail]` | one criterion line |
| `score_skip <name> <reason>` | a skipped criterion (makes the score partial) |
| `score_hint <id> <text> [title]` | hint for the final block (`BUG-*` ids go under "Missed bugs") |
| `score_warn <text>` | warning for the maintainer (e.g. a patch that no longer applies) |
| `score_end` | total, hints, JSON; exits 0 or 1 |
| `score_fatal <message> [hint]` | environment/configuration error; exits 3 |

Other libraries: `common.sh` (tool checks, timeout, workspace, cleanup),
`runner.sh` (runs a topic's tests), `bugbank.sh`, `mutation.sh`, `stack.sh`,
`practices.sh`, and `standard.sh` (the standard flow above).

Every script must pass `shellcheck -x` with no findings (`.shellcheckrc` sets
the source paths).
