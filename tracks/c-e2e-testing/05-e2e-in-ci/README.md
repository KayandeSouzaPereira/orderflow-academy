# C-05 End-to-end tests in CI

## Goal

Run your Playwright tests on every push, with the browsers cached, a trace for
anything that needed a retry and the HTML report kept as an artifact.

## Context

- **QA**: add a `playwright` job to your `.github/workflows/qa-<you>.yml` from B-08.
- **Devs**: create `.github/workflows/e2e-<you>.yml`.

The job must:

1. run on `push` to `participant/<you>`;
2. install Node 22, `npm ci` in `app/e2e`, and Chromium with
   `npx playwright install --with-deps chromium`, caching `~/.cache/ms-playwright`
   with `actions/cache`;
3. start the stack: `docker compose --profile full up -d --build --wait` in `app/`
   (with `ORDERFLOW_PROCESSOR_DELAY_MS: "3000"`);
4. run `npx playwright test tests/tracks` in `app/e2e` with
   `E2E_BASE_URL=http://localhost:4200` and `API_BASE_URL=http://localhost:8080`;
5. in CI only, allow one retry and keep its trace: `--retries=1 --trace=on-first-retry`;
6. publish `app/e2e/playwright-report` with `actions/upload-artifact`, also when tests fail.

## Your task

1. Write the job, push, and check the run in the *Actions* tab.
2. Download the report artifact once and open it (`npx playwright show-report <folder>`).
3. Run `./scripts/review.sh c-e2e-testing/05-e2e-in-ci`.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | the workflow exists and is valid YAML |
| Workflow checks | 100 | push trigger, cached browsers, stack started, Playwright run in `app/e2e`, trace on first retry, report published (about 17 points each) |

## Hints

- A retry that passes is still a warning: the trace tells you why the first run failed.
- `if: always()` on the upload and on `docker compose down`.
- Use the `package-lock.json` hash as part of the cache key.

## Further reading

- [Playwright: continuous integration](https://playwright.dev/docs/ci)
- [Playwright: retries](https://playwright.dev/docs/test-retries)
- [actions/cache](https://github.com/actions/cache)
