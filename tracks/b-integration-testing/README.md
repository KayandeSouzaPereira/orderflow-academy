# Track B: integration testing (QA)

Black-box testing from the outside: you talk to OrderFlow only through its
API, the way a client does. The track starts with the tools (Java, Git) and
ends with a CI pipeline and a regression suite built from manual cases. Do the
topics in order; 70 points completes a topic.

| Topic | What you learn |
| --- | --- |
| [01-java-basics](01-java-basics/) | Collections, streams, Optional, exceptions, records |
| [02-git-workflow](02-git-workflow/) | Branches, Conventional Commits, conflicts, pull requests |
| [03-api-test-setup](03-api-test-setup/) | Running the stack, RestAssured, first catalog tests |
| [04-api-testing](04-api-testing/) | Status codes, validations, error format, OpenAPI schema |
| [05-test-data](05-test-data/) | Builders, isolated data, stock rules |
| [06-async-side-effects](06-async-side-effects/) | Awaitility, confirmation, invoice download |
| [07-lifecycle-and-concurrency](07-lifecycle-and-concurrency/) | State machine, races |
| [08-ci-pipeline](08-ci-pipeline/) | Your own GitHub Actions workflow |
| [09-manual-to-automated](09-manual-to-automated/) | Manual cases (after B-02), automated at the end |

After track B, continue with track C (end-to-end tests with Playwright).
