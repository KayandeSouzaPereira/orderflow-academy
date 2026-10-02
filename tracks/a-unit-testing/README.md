# Track A: unit testing (developers)

White-box tests of the OrderFlow code, from pure domain rules to the adapters
that talk to AWS. Do the topics in order; 70 points completes a topic.

| Topic | You test | With |
| --- | --- | --- |
| [01-test-anatomy](01-test-anatomy/) | `OrderPricing` | JUnit 5, AssertJ |
| [02-test-doubles](02-test-doubles/) | `CreateOrderUseCase`, `CancelOrderUseCase` | Mockito |
| [03-tdd-kata](03-tdd-kata/) | `CouponPolicy`, written test first | JUnit 5, Git history |
| [04-angular-unit](04-angular-unit/) | `CartService`, `OrderStatusComponent` | Angular TestBed, Vitest |
| [05-adapter-integration](05-adapter-integration/) | DynamoDB, SQS and S3 adapters | `@QuarkusTest`, Floci |

After track A, continue with track C (end-to-end tests with Playwright).
