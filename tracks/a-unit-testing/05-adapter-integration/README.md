# A-05 Adapter integration: DynamoDB, SQS and S3 against Floci

## Goal

Write white-box integration tests for the infrastructure adapters: run them
against real (emulated) AWS services and check the state they leave behind,
directly in DynamoDB, SQS and S3.

## Context

The adapters in `app/backend/src/main/java/dev/orderflow/infrastructure/`
implement the application ports:

| Adapter | Port | What it must do |
| --- | --- | --- |
| `DynamoOrderRepository` | `OrderRepository` | store orders with attributes `id`, `customerEmail`, `items`, `totalInCents`, `status`, `invoiceKey`, `createdAt`, `updatedAt`; query by customer through the `customerEmail` index (only that customer's orders); `replaceIfStatus` only writes when the stored status is the expected one |
| `DynamoProductRepository` | `ProductRepository` | `reserveStock` takes units only when there are enough (otherwise returns `false` and changes nothing) |
| `SqsEventPublisher` | `EventPublisher` | sends `OrderCreated` as JSON with `orderId`, `totalInCents` and `occurredAt` |
| `S3InvoiceStorage` | `InvoiceStorage` | stores the PDF with `Content-Type: application/pdf`; `presign` returns a URL that downloads it |

Tests start the application with `@QuarkusTest` and Floci with
`FlociTestResource` (in `dev.orderflow.support`), which creates tables, queue
and bucket with unique names and points the application at them:

```java
@QuarkusTest
@WithTestResource(value = FlociTestResource.class, scope = TestResourceScope.MATCHING_RESOURCES,
        initArgs = @ResourceArg(name = FlociTestResource.PROCESSOR_ENABLED_ARG, value = "false"))
class DynamoOrderRepositoryTest {

    @Inject OrderRepository orders;          // the adapter under test
    @Inject DynamoDbClient dynamo;           // to look at the table directly
    @ConfigProperty(name = "orderflow.dynamodb.orders-table") String table;
}
```

Turning the order processor off keeps it from consuming the queue while your
test reads it. Use the same `@WithTestResource` settings in every class, so
Quarkus and Floci start only once per run.

## Your task

1. Write your tests in `app/backend/src/test/java/dev/orderflow/tracks/a05/`.
2. For every adapter, call it through its port and assert on what is really
   stored: DynamoDB items (`getItem`, `query`), SQS messages (`receiveMessage`),
   S3 objects (`headObject`, `getObject`).
3. Never hard-code endpoints or ports: inject the clients and read resource
   names with `@ConfigProperty`.

Docker must be running (Testcontainers starts Floci).

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | your tests compile and pass against the real adapters |
| Bug bank | 70 | share of planted bugs in the adapters your tests catch |
| Practices | 30 | no `Thread.sleep`, no disabled tests, every test asserts, no hard-coded endpoints, `should<Result>When<Condition>` names, stable in random order |

There is no mutation score in this topic: mutation testing would restart
Quarkus and Floci for every mutant.

## Hints

- Reading the data back through the same adapter hides symmetric mistakes:
  look at the raw item, message or object.
- Use unique ids and e-mails in every test: all tests share the same tables.
- For the per-customer query, store orders of two customers.
- A conditional write is only tested when the condition is false.

## Further reading

- [Quarkus: testing your application](https://quarkus.io/guides/getting-started-testing)
- [Quarkus: test resources](https://quarkus.io/guides/getting-started-testing#quarkus-test-resource)
- [Testcontainers for Java](https://java.testcontainers.org/)
- [Floci](https://github.com/floci-io/floci)
- [AWS SDK for Java v2: DynamoDB, SQS, S3 examples](https://docs.aws.amazon.com/sdk-for-java/latest/developer-guide/java_code_examples.html)
