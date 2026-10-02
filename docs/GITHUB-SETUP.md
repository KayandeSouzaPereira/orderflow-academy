# GitHub setup (maintainer)

Settings that cannot live in the repository. Do them once, after phase 6
reaches `main`: `workflow_run` workflows only start from the default branch.

## 1. Actions

1. **Settings > Actions > General > Workflow permissions**: *Read repository
   contents and packages permissions* (workflows also declare `contents: read`).
2. **Settings > Secrets and variables > Actions**: `PRIVATE_REPO_TOKEN`, a
   fine-grained token with *Contents: Read-only* on `orderflow-academy-private`
   (used only by `main-ci.yml`). The review workflow uses no secret.

## 2. Rulesets

**Settings > Rules > Rulesets > New ruleset > Import a ruleset**, once per file:

| File | Applies to | What it does |
| --- | --- | --- |
| `.github/rulesets/main.json` | the default branch | no deletion or force push; changes only through a pull request with a code-owner review and the `main-ci ok` check green. Repository admins can merge a pull request without the approval (so the maintainer can merge their own work). |
| `.github/rulesets/participant-branches.json` | `participant/**` | nobody can delete a participant branch (admins can). |

Limits worth knowing:

- Personal repositories cannot restrict a branch to one user. The SDD asks for
  that only as a recommendation. With an organization, create a team per
  participant and a ruleset per branch with *Restrict updates* and that team as
  the only bypass actor.
- Participants need the **Write** role to push their own branch. That also lets
  them open pull requests to `main`; the ruleset stops them from merging.
- Rebase is allowed (participants may force-push their own branch).
- Import `main.json` after the first `main-ci` run: the status check name
  `main-ci ok` must exist before it can be required.

## 3. Participant branches

For each participant (the maintainer creates them from `main`):

```bash
git switch -c participant/<github-username> main
git push -u origin participant/<github-username>
```

Study branches (`study/<user>/<topic>`, topic B-02) are not scored.
After the phase with `TEAM-NOTES.md` is on `main`, create the B-02 exercise branches:

```bash
./scripts/dev/create-b02-exercise.sh --push
```

## 4. How the official score works

```
push to participant/<user>
  -> participant-push (records before/after; may be edited by the participant)
  -> review  (ALWAYS the file from main, started by workflow_run)
       plan     which topics changed
       review   one job per topic: main's scripts + the participant's tests
       summary  table in the Job Summary; the run fails if a topic is below 70
```

Why `workflow_run` and not `push`: a `push` workflow runs the file of the
pushed branch, which the participant controls. `review.yml` only ever runs from
`main`, and reads the participant's commit as data:

1. `trusted/` is a checkout of `main`, `work/` the participant's commit.
2. `scripts/ci/sanitize.sh` replaces `scripts/`, `tracks/`, `docs/` and `app/`
   in `work/` with main's copy, then restores only the paths listed in
   `scripts/ci/participant-paths.txt` (tests, answers, exercises, the TDD
   implementation, manual cases); files such as `Model.java` stay as in main.
3. Only then is `./scripts/review.sh` run.

A participant can still delete or edit `participant-push.yml`: the automatic
start then fails for that branch, and the maintainer starts the review by hand
(**Actions > review > Run workflow**, branch and topic). The tests themselves
run code of the participant in the job, without secrets and with a read-only
token; the score is feedback, not a ranking.

Check the protection locally with the tamper simulation:

```bash
./scripts/dev/simulate-participant-ci.sh a-unit-testing/01-test-anatomy \
  ../orderflow-academy-private/solutions/a-unit-testing/01-test-anatomy/calibration-weak
```
