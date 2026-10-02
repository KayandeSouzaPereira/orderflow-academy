# Track A: unit testing (developers)

White-box tests of the OrderFlow code, from pure domain rules to the adapters
that talk to AWS. Do the topics in order; 70 points completes a topic.

Backend tests always run with `@QuarkusTest`: inject the class under test with
`@Inject` and replace its collaborators with `@InjectMock`. The review checks
it (a test class without `@QuarkusTest` scores 0). Quarkus starts once for all
the test classes of a run, in a few seconds, and needs no Docker for topics 01
to 03.

| Topic | You test | With |
| --- | --- | --- |
| [01-test-anatomy](01-test-anatomy/) | `OrderPricing` | `@QuarkusTest`, JUnit 5, AssertJ |
| [02-test-doubles](02-test-doubles/) | `CreateOrderUseCase`, `CancelOrderUseCase` | `@QuarkusTest`, `@InjectMock` (Mockito) |
| [03-tdd-kata](03-tdd-kata/) | `CouponPolicy`, written test first | `@QuarkusTest`, JUnit 5, Git history |
| [04-angular-unit](04-angular-unit/) | `CartService`, `OrderStatusComponent` | Angular TestBed, Vitest |
| [05-adapter-integration](05-adapter-integration/) | DynamoDB, SQS and S3 adapters | `@QuarkusTest`, Floci |

After track A, continue with track C (end-to-end tests with Playwright).
