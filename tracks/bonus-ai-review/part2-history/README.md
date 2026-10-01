# Bonus part 2: humans and AI on a new endpoint

## Goal

Compare what an AI assistant produces on its own with what survives a human
review, on an endpoint nobody has tested yet.

## Context

`GET /api/orders/{id}/history` returns the status history of an order, oldest
first, as a JSON array of `{"status": "...", "at": "<ISO-8601 instant>"}`:

- every order starts with `PENDING`, at its creation time (the `createdAt` of the order);
- an order that is no longer `PENDING` has a second entry with its current
  status (`CONFIRMED` or `CANCELLED`), at the time of its last update
  (`updatedAt`);
- an unknown order answers `404` with `{"code": "ORDER_NOT_FOUND", "message": "..."}`.

The endpoint has its own planted bugs. The review checks whether your tests
catch them.

## Your task

1. Ask an AI assistant for API tests of this endpoint (give it the description
   above and the OpenAPI at `/q/openapi`). Save its answer **untouched** in
   `app/api-tests/src/test/java/dev/orderflow/apitests/tracks/bonus2/`
   (package `dev.orderflow.apitests.tracks.bonus2`) and run
   `./scripts/review.sh bonus-ai-review/part2-history`. Write the score down.
2. Review the tests the way you did in the session: which wrong implementations
   would they accept? Fix them, run the review again, and write the new score down.
3. Record both scores, what the AI got right and what only a human caught in
   your `FINDINGS.md`.

OrderFlow is fictional, so there is no proprietary code in your prompts. That
freedom does **not** apply to code or data of your company: never paste them
into an AI assistant without approval.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Prerequisite | - | black-box only: no backend classes, no AWS SDK |
| Gate | - | your tests pass against the real stack |
| Bug bank | 70 | share of the 4 planted bugs of the endpoint your tests catch |
| Practices | 30 | no `Thread.sleep`, no disabled tests, every test asserts, no hard-coded endpoints, naming, stable in random order, no empty `catch` |

The point of the exercise is the difference between the two scores, not the
score itself.

## Hints

- A history has a length, an order, statuses and timestamps: four things to check.
- Create the orders you need; to get a `CONFIRMED` one, wait for it with Awaitility.
- Compare the timestamps with `createdAt` and `updatedAt` of the order itself.

## Further reading

- [Awaitility usage](https://github.com/awaitility/awaitility/wiki/Usage)
- [RestAssured usage guide](https://github.com/rest-assured/rest-assured/wiki/Usage)
- [Simon Willison: how I use LLMs to write code](https://simonwillison.net/2025/Mar/11/using-llms-for-code/)
