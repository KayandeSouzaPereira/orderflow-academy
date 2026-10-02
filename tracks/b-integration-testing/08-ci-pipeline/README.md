# B-08 CI pipeline for the API tests

## Goal

Run your API tests automatically on every push: start the stack in a GitHub
Actions job, run the `api-tests` module and keep the reports when something fails.

## Context

GitHub Actions runs workflows from `.github/workflows/*.yml`. A job runs on a
fresh Linux machine with Docker, so it can start the whole OrderFlow stack the
same way you do locally. The official scoring workflow belongs to the
maintainer; this one is yours and lives on your branch only.

What the workflow must do:

1. run on `push` to your branch (`participant/<you>`);
2. set up Java 21 with a **Maven cache** (`actions/setup-java` with `cache: maven`);
3. start the stack: `docker compose --profile full up -d --build --wait` in `app/`
   (set `ORDERFLOW_PROCESSOR_DELAY_MS: "3000"` as the reviews do);
4. run the API tests of B-03 to B-07 in `app/api-tests` (`./mvnw -B test`);
5. publish `app/api-tests/target/surefire-reports` with
   `actions/upload-artifact`, **also when the tests fail** (`if: always()`).

## Your task

1. Create `.github/workflows/qa-<your-github-user>.yml` on your branch.
2. Push and watch the run in the *Actions* tab; download the artifact once.
3. Run `./scripts/review.sh b-integration-testing/08-ci-pipeline`.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | `.github/workflows/qa-<you>.yml` exists and is valid YAML |
| Workflow checks | 100 | 20 points each: push trigger for your branch, stack started, `api-tests` run, Maven cache, Surefire reports published |

The review reads the file; it does not run it. Watching it go green on GitHub
is part of the job.

## Hints

- `working-directory:` on a step (or `defaults.run.working-directory` on the
  job) avoids `cd` in every command.
- Stop the stack at the end with `if: always()`, so a failed run cleans up too.
- `-Dtest='dev/orderflow/apitests/tracks/b0[3-7]/**/*'` limits Maven to your topic packages.

## Further reading

- [GitHub Actions: workflow syntax](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions)
- [actions/setup-java: caching](https://github.com/actions/setup-java#caching-packages-dependencies)
- [actions/upload-artifact](https://github.com/actions/upload-artifact)
- [Docker Compose: up --wait](https://docs.docker.com/reference/cli/docker/compose/up/)
