# B-06 Asynchronous side effects: confirmation and invoice

## Goal

Test what happens after the response: an order is confirmed in the background
and its invoice becomes downloadable. Wait for conditions, never for fixed
amounts of time.

## Context

After `POST /api/orders`, the backend publishes an `OrderCreated` event to a
queue. A processor picks it up (in the review stack, about **3 seconds**
later), generates a PDF invoice, stores it and moves the order to `CONFIRMED`.

| Endpoint | Before confirmation | After confirmation |
| --- | --- | --- |
| `GET /api/orders/{id}` | `status: PENDING` | `status: CONFIRMED`, same `totalInCents`, `invoiceKey: invoices/{id}.pdf` |
| `GET /api/orders/{id}/invoice` | 404 `INVOICE_NOT_AVAILABLE` | 200 `{"url": "...", "expiresAt": "..."}` |

The `url` is a pre-signed S3 URL: opening it downloads the PDF
(`Content-Type: application/pdf`, file starts with `%PDF-`). It is already
encoded, so open it with `java.net.http.HttpClient` rather than RestAssured.

## Your task

1. Write your tests in `app/api-tests/src/test/java/dev/orderflow/apitests/tracks/b06/`.
2. Use Awaitility (`await().atMost(...).untilAsserted(...)`) to wait for
   `CONFIRMED`, then check the order and download the invoice.
3. Your assertions use only the API and the pre-signed URL.

**Investigating failures** (never in assertions): with the AWS CLI pointed at
Floci you can look inside the emulated services, e.g.
`aws --endpoint-url http://localhost:4566 sqs receive-message --queue-url http://localhost:4566/000000000000/order-created`
or `aws --endpoint-url http://localhost:4566 s3 ls s3://orderflow/invoices/`.
An emulator behaves like AWS for the basics, but it is not AWS.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Prerequisite | - | black-box only |
| Gate | - | your tests pass against the real stack |
| Bug bank | 70 | share of planted bugs in the asynchronous flow your tests catch |
| Practices | 30 | **no `Thread.sleep` (counts double)**, no disabled tests, every test asserts, no hard-coded endpoints, naming, stable in random order |

## Hints

- Give `await()` a generous `atMost` (tens of seconds) and a short poll interval:
  it returns as soon as the condition holds.
- The end of the flow is the downloaded file, not the URL.
- Compare the confirmed order with what you created.

## Further reading

- [Awaitility usage](https://github.com/awaitility/awaitility/wiki/Usage)
- [Java HttpClient](https://docs.oracle.com/en/java/javase/21/docs/api/java.net.http/java/net/http/HttpClient.html)
- [AWS: pre-signed URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ShareObjectPreSignedURL.html)
