# Team notes

Notes the QA team keeps about the test setup. Topic B-02 practises Git on this file.

## Test environment

- Start the stack: `cd app && docker compose --profile full up -d --build --wait`
- API base URL: http://localhost:8080
- Processor delay in reviews: 3000 ms

## Conventions

- Test names: should<Result>When<Condition>
- One package per topic: dev.orderflow.apitests.tracks.<id>
