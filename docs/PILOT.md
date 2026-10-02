# Pilot (phase 8)

The maintainer walks through every topic as a fictional participant, then
adjusts times, hints and weights. This page is the script for that pass.

## Acceptance (SDD, phase 8)

- No topic needs more than 10 minutes for a full review (15 for tracks B and C;
  the bonus challenge is a live session and has a limit of 25 here).
- Every hint was read and makes sense without looking at the solution.

## 1. Measure every review

With the private repository cloned next to this one:

```bash
./scripts/dev/pilot.sh --solutions ../orderflow-academy-private/solutions
```

It runs the full official review of each topic with its reference solution
(no `--quick`), and writes `pilot-results/pilot-<date>.md` and `.csv`: score,
status, minutes, limit and missed bugs. The run takes a couple of hours: start
it before a break, and keep Docker Desktop healthy (see Troubleshooting).
Run a few topics only by naming them:

```bash
./scripts/dev/pilot.sh --solutions ../orderflow-academy-private/solutions b-integration-testing/09-manual-to-automated bonus-ai-review
```

Where a topic is over its limit, in order of preference: fewer or cheaper
mutants (`mutation.target_classes`), `parallel_stacks`, fewer bugs, and only then
a higher limit recorded in `docs/DECISIONS.md`.

## 2. Read as a participant

For each topic, in the order of the tracks:

1. Read only the README and write the tests, without opening `solutions/` or `bugs/`.
2. Run `./scripts/review.sh <topic> --quick` and read the hints of the missed bugs.
3. Check each hint: does it point in a direction without giving the answer?
   Is it still clear a week later? Is it in plain English?
4. Fill in the checklist printed by `./scripts/dev/pilot.sh --checklist`
   (review time, hints, README), with notes.

Things to look at: a README section that assumes knowledge the previous topic did
not teach; a bug whose hint is too vague (nobody finds it) or too direct (the
hint is the answer); a weight that makes a weak suite pass or a good one fail.

## 3. Definition of done of a topic (from the SDD)

`./scripts/dev/validate-topic.sh <topic> --solutions <solutions>` checks most of it:

- [ ] README with the six standard sections, in English, without revealing the bugs
- [ ] `topic.yml` valid, `review.sh` uses only the `score.sh` API
- [ ] 4 to 6 bugs (the example, B-09 and the bonus set their own range), each with `bug.yml` and a useful hint
- [ ] the reference solution catches 100% of the bugs and scores at least 90
- [ ] with no test the review stops at the gate (exit code 2)
- [ ] a weak solution (happy path only) scores below 70 (the bonus: its base score, 20 to 35)
- [ ] a full review stays within the time limit

## 4. After the pass

- Record every change of weights, limits and hints in `docs/DECISIONS.md`.
- Re-run `validate-topic.sh` for each topic you touched, and the structure check
  (`./scripts/dev/validate-structure.sh`).
- Do a dry run of the first session with a participant branch: create
  `participant/<user>`, push, and read the **review** run in the Actions tab
  (see [GITHUB-SETUP.md](GITHUB-SETUP.md)).

## Troubleshooting

- **Containers cannot resolve names ("lookup http.docker.internal ... connection
  refused")**: the internal DNS of Docker Desktop stopped. Restart Docker
  Desktop; it can come back after hours of heavy use. Reviews retry a few times
  by themselves, not for minutes.
- **A bug is reported as "does not build"**: the review prints the last lines of
  the build output. A dropped connection is retried; a real error is yours to fix.
- **Free ports**: reviews use 14566, 18080 and 14200 (and +1000, +2000, +3000 for
  parallel stacks), never the default ports of the developer stack.
