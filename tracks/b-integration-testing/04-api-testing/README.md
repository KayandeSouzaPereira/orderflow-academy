# B-04 API testing with RestAssured: orders

## Goal

Cover the order API: successful creation, every validation rule, every error
and the error format, using the API's own OpenAPI description as a contract.

## Context

`POST /api/orders` with `{"customerEmail": "...", "items": [{"productId": "...", "quantity": 2}]}`:

| Situation | Status | Body |
| --- | --- | --- |
| valid order | **201**, `Location: .../api/orders/{id}` | the order, `status: PENDING` |
| invalid e-mail, no items, quantity outside **1..10** | 400 | `code: VALIDATION_ERROR` |
| unknown product | 404 | `code: PRODUCT_NOT_FOUND` |
| not enough stock | 409 | `code: OUT_OF_STOCK` |

Every error body is `{"code": "...", "message": "..."}`, with both fields.
The API publishes its OpenAPI description at `/q/openapi?format=json`; the
error body is `components.schemas.ErrorResponse`.

## Your task

1. Write your tests in `app/api-tests/src/test/java/dev/orderflow/apitests/tracks/b04/`.
2. Cover each row of the table, including the edges of the quantity range.
3. Validate error bodies against the schema from the OpenAPI description, with
   `io.restassured.module.jsv.JsonSchemaValidator.matchesJsonSchema(...)`.
   Note that the published schema does not mark fields as required: the
   documented contract says both are always present, so add that yourself.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Prerequisite | - | black-box only |
| Gate | - | your tests pass against the real stack |
| Bug bank | 70 | share of planted bugs in order creation your tests catch |
| Practices | 30 | no `Thread.sleep`, no disabled tests, every test asserts, no hard-coded endpoints, `should<Result>When<Condition>` names, stable in random order |

## Hints

- `@ParameterizedTest` with `@ValueSource` covers many invalid values in one test.
- Create your own product with a known stock for every order test.
- "Created" has an exact status code; check it, and the `Location` header.

## Further reading

- [RestAssured: JSON schema validation](https://github.com/rest-assured/rest-assured/wiki/Usage#json-schema-validation)
- [OpenAPI specification](https://spec.openapis.org/oas/latest.html)
- [JUnit 5: parameterized tests](https://junit.org/junit5/docs/current/user-guide/#writing-tests-parameterized-tests)
- [MDN: 201 Created](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/201)
