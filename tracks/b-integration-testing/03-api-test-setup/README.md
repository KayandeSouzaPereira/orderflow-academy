# B-03 API test setup: the catalog

## Goal

Set up black-box API testing: run the whole OrderFlow stack, point the test
module at it and write the first tests against the catalog endpoints.

## Context

From this topic on, your tests live in `app/api-tests`, a Maven module that
knows nothing about the backend code. It talks to the running system only over
HTTP, like any other client. It gives you:

- `TestApi.spec()`: a RestAssured request specification with the base URL
  (from `API_BASE_URL`, default `http://localhost:8080`) and JSON headers;
- `TestApi.createProduct(name, priceInCents, stock)` and
  `TestApi.setStock(id, stock)`: shortcuts to the test-data endpoints
  (`/api/admin/*`), enabled in the full stack.

Catalog endpoints:

| Method | Path | Answers |
| --- | --- | --- |
| GET | `/api/products` | 200, JSON array with every product (10 seed products) |
| GET | `/api/products/{id}` | 200 with `id`, `name`, `description`, `priceInCents`, `stock`; 404 `{"code": "PRODUCT_NOT_FOUND", ...}` |

All bodies are `application/json`; prices are integers in **cents**.

## Your task

1. Start the stack: `cd app && docker compose --profile full up -d --build --wait`.
2. Run the existing smoke tests: `cd app/api-tests && ./mvnw test`.
3. Write your tests in `app/api-tests/src/test/java/dev/orderflow/apitests/tracks/b03/`
   for both endpoints: content, status codes, headers and the error format.
4. Never import backend classes or the AWS SDK, and never hard-code hosts or ports.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Prerequisite | - | black-box only: no backend classes, no AWS SDK (otherwise the score is 0) |
| Gate | - | your tests pass against the real stack |
| Bug bank | 70 | share of planted bugs in the catalog API your tests catch |
| Practices | 30 | no `Thread.sleep`, no disabled tests, every test asserts, no hard-coded endpoints, `should<Result>When<Condition>` names, stable in random order |

The review starts its own stack on ports 14566/18080/14200, so your local
stack can keep running.

## Hints

- A status code alone tells little: check the body and the headers too.
- Data you create yourself (through `TestApi.createProduct`) has values you know in advance.
- An error response is a response too: test its status and its body.

## Further reading

- [RestAssured usage guide](https://github.com/rest-assured/rest-assured/wiki/Usage)
- [Hamcrest matchers](https://hamcrest.org/JavaHamcrest/javadoc/3.0/org/hamcrest/Matchers.html)
- [MDN: Content-Type](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type)
