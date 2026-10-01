# OrderFlow Academy

Hands-on training in test automation, built around **OrderFlow**, a small
fictional online store (Quarkus + Angular + AWS emulated locally by
[Floci](https://github.com/floci-io/floci)). Each training topic has its own
folder with instructions, planted bugs and a `review.sh` that scores your
tests from 0 to 100.

> OrderFlow is fictional. No real company, data or AWS account is involved.

## Status

| Phase | Content | State |
| --- | --- | --- |
| 1 | App base: backend, frontend, local AWS, API test module | done |
| 2 | Review engine (`scripts/`) and example topic (`tracks/_example`) | done |
| 3 | Private reference repo and `main-ci.yml` | done |
| 4 | Fundamentals and track A | next |
| 5–8 | Tracks B and C, participant CI, bonus challenge, pilot | planned |

## What is inside

```
app/
├── docker-compose.yml   # Floci + aws-init; profile "full" adds backend and frontend
├── aws-init/            # creates tables, queue, bucket; seeds 10 products with images
├── backend/             # Quarkus (Java 21) - white-box tests of track A live here
├── api-tests/           # black-box API tests of track B (no dependency on the backend)
└── frontend/            # Angular - unit tests of topic A-04 live next to the components
```

## Requirements

- Docker (Docker Desktop on macOS/Windows; Windows via WSL2)
- JDK 21 or newer (`JAVA_HOME` must point to it)
- Node.js 22.22+ or 24.15+ (required by Angular 22)
- Bash 5, `jq` and [`yq` v4 (mikefarah)](https://github.com/mikefarah/yq#install), for the review
  scripts (Linux, macOS, WSL or Git Bash)

No AWS account and no IDE are needed.

## Run OrderFlow locally

Day-to-day setup: AWS in Docker, backend and frontend on your machine.

```bash
cd app
docker compose up -d                 # Floci on :4566, then aws-init seeds it

cd backend && ./mvnw quarkus:dev     # API on http://localhost:8080 (admin endpoints on in dev mode)
cd frontend && npm install && npm start   # UI on http://localhost:4200 (proxies /api to :8080)
```

Everything in containers, as the reviews of tracks B and C use it:

```bash
cd app
ORDERFLOW_PROCESSOR_DELAY_MS=3000 docker compose --profile full up -d --build --wait
```

Useful URLs:

- UI: http://localhost:4200
- API: http://localhost:8080/api/products
- OpenAPI spec: http://localhost:8080/q/openapi (Swagger UI at `/q/swagger-ui` in dev mode)
- Health: http://localhost:8080/q/health

## The product in one minute

- **Catalog**: `GET /api/products`, `GET /api/products/{id}`, `GET /api/products/{id}/image` (pre-signed S3 URL).
- **Orders**: `POST /api/orders` creates a `PENDING` order, reserves stock and publishes `OrderCreated` to SQS.
  A background processor generates the invoice PDF (`invoices/{orderId}.pdf` in S3) and moves the order to `CONFIRMED`.
  `POST /api/orders/{id}/cancel` cancels a `PENDING` order and gives the stock back.
- **Rules**: 1+ items, quantity 1..10, valid e-mail, 10% off above R$500.00 (rounded down), money always in cents.
- **Errors** always look like `{"code": "OUT_OF_STOCK", "message": "..."}`.
- **Test data**: `POST /api/admin/products` and `PUT /api/admin/products/{id}/stock` exist only when `orderflow.admin.enabled=true`.

Configuration (environment variables):

| Variable | Default | Purpose |
| --- | --- | --- |
| `AWS_ENDPOINT_URL` | `http://localhost:4566` | Where the backend reaches Floci |
| `ORDERFLOW_AWS_PUBLIC_ENDPOINT` | same as above | Host used in pre-signed URLs |
| `ORDERFLOW_PROCESSOR_DELAY_MS` | `0` | Minimum age of an order before it is processed (keeps `PENDING` observable) |
| `ORDERFLOW_ADMIN_ENABLED` | `false` (`true` in dev mode and in the `full` profile) | Enables `/api/admin/*` |
| `API_BASE_URL` | `http://localhost:8080` | Target of the black-box API tests |

## Run the tests that ship with the app

```bash
cd app/backend && ./mvnw test        # needs Docker: starts Floci with Testcontainers
cd app/api-tests && ./mvnw test      # needs the full stack running
cd app/frontend && npm test
```

## Get your score

Each topic is reviewed by a script that plants known bugs in a copy of the app
and checks whether your tests catch them:

```bash
./scripts/review.sh _example            # try it on the example topic
./scripts/review.sh <track>/<topic>     # e.g. a-unit-testing/01-test-anatomy
./scripts/review.sh <track>/<topic> --quick   # faster, skips mutation testing
./scripts/review-all.sh                 # every topic, with a summary table
```

```
══ Review: _example ══
   user: kayan  |  branch: participant/kayan  |  commit: 3f9a2c1

[✔] Gate: 10 tests passing ....................... OK
[✔] Bug bank ..................................... 3/3    50/50
[✔] Mutation score (100%, target 80%) ............ 25/25
[✔] Practices .................................... 5/5    25/25

TOTAL: 100/100  PASSED (threshold 70)
```

70 points or more completes a topic. The score is feedback for you, not a
ranking. Your local score is for quick feedback; the official one is computed
by CI with the scripts from `main`. See [scripts/README.md](scripts/README.md)
for how reviews work.

## Keeping your branch up to date

You work on `participant/<github-username>`. When the maintainer publishes a
new topic or fixes a script, bring it into your branch:

```bash
git fetch origin
git merge origin/main
```

## Troubleshooting

- **`The JAVA_HOME environment variable is not defined correctly`**: point
  `JAVA_HOME` to a JDK 21+ folder, without quotes or a trailing `"`.
- **Backend logs `Cannot poll the order-created queue`**: Floci is not running or
  `aws-init` did not finish. Run `docker compose up -d` in `app/` and check
  `docker compose logs aws-init`.
- **Containers hang in `Created`/`Starting` on Docker Desktop**: restart Docker
  Desktop (`docker run --rm alpine echo ok` should print `ok`).
- **Angular says the Node.js version is not supported**: install Node 22 LTS or newer.

## License

[MIT](LICENSE).
