# B-01 Java basics for testers

## Goal

Get comfortable with the Java you will read and write in API tests:
collections, streams, `Optional`, exceptions and records, all with OrderFlow data.

## Context

`app/exercises` is a small, standalone Maven module (no framework, no
database). `Model.java` has the data: `Product`, `OrderLine`, `Order` (records)
and `Status` (enum). `Exercises.java` has 12 methods, each with a Javadoc that
says what it must return and each throwing `UnsupportedOperationException`
for now.

| # | Practises | # | Practises |
| --- | --- | --- | --- |
| 1 | loops or `mapToLong(...).sum()` | 7 | regular expressions, null checks |
| 2 | `filter`, `map`, `sorted` | 8 | `equalsIgnoreCase`, keeping order |
| 3 | `Collectors.groupingBy` + `counting` | 9 | `flatMap`, `summingInt` |
| 4 | `Optional`, `min` with a `Comparator` | 10 | grouping, then the max entry |
| 5 | `String.format` | 11 | `subList`, argument checks |
| 6 | parsing, exceptions with useful messages | 12 | records are immutable: create a new one |

## Your task

1. Open `app/exercises` in your IDE (it is a normal Maven project).
2. Implement the 12 methods in `Exercises.java`. Do not change `Model.java`
   or the method signatures.
3. Write your own small tests in `app/exercises/src/test/java` if you like:
   it is the best way to check your work as you go (`./mvnw test` in `app/exercises`).
4. Run `./scripts/review.sh b-integration-testing/01-java-basics`.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | the module compiles and at least one exercise is implemented |
| Exercise checks | 100 | share of the maintainer's checks that pass against your code |

The report lists the exercises that still have failing checks.

## Hints

- Read each Javadoc twice: edge cases (empty lists, null, upper case) are part of the rules.
- Streams are not mandatory: a clear loop is fine. Pick what you can read.
- For exercise 12, a record cannot be changed: build a new one with the new status.

## Further reading

- [dev.java: Java collections](https://dev.java/learn/api/collections-framework/)
- [dev.java: the Stream API](https://dev.java/learn/api/streams/)
- [dev.java: records](https://dev.java/learn/records/)
- [dev.java: Optional](https://dev.java/learn/api/streams/optionals/)
