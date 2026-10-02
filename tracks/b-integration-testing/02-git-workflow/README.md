# B-02 Git workflow: branches, commits, conflicts and pull requests

## Goal

Work the way the team works: a branch per task, small commits with clear
messages, a merge conflict resolved on purpose, and a pull request reviewed by
a developer before it lands on your branch.

## Context

Your long-lived branch is `participant/<your-github-user>`. For each piece of
work you create a **study branch** from it, `study/<your-github-user>/<topic>`,
and bring it back through a pull request.

(Git cannot have both `participant/ana` and `participant/ana/b02`: a branch
name cannot also be a folder of other branch names. That is why study branches
use their own `study/` prefix.)

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):
`type(scope): summary`, for example `test(api-tests): cover order creation` or
`docs(api-tests): explain the base URL`. Types: `feat`, `fix`, `docs`,
`style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

The maintainer prepared two branches, `exercise/b02-conflict-a` and
`exercise/b02-conflict-b`. Both change the same line of
`app/api-tests/TEAM-NOTES.md`, so merging both causes a conflict.

## Your task

1. Update and branch:
   ```bash
   git fetch origin
   git switch participant/<you>
   git switch -c study/<you>/b02
   ```
2. Make at least two commits in your own area (for example, add a line to the
   *Conventions* of `TEAM-NOTES.md`, or a short document in `app/api-tests/docs/`),
   with Conventional Commits messages.
3. Merge both exercise branches: `git merge origin/exercise/b02-conflict-a`,
   then `git merge origin/exercise/b02-conflict-b`. The second one conflicts.
   Resolve it by keeping **one** line that carries both pieces of information:
   ```
   - API base URL: http://localhost:8080 (set API_BASE_URL to change it; review stack: http://localhost:18080)
   ```
   Then `git add` the file and `git commit` to finish the merge.
4. Push the study branch and open a pull request from `study/<you>/b02` to
   `participant/<you>`. Ask a developer to review it; merge it after approval
   (use "Create a merge commit").
5. `git switch participant/<you> && git pull`, then run
   `./scripts/review.sh b-integration-testing/02-git-workflow`.

## How you are scored

| Criterion | Weight | Measured by |
| --- | --- | --- |
| Gate | - | your branch has commits of yours since `main` |
| Git workflow | 100 | 20 points each: Conventional Commits (2+ commits, 80% valid), both exercise branches merged, conflict resolved with the line above, study branch merged through a pull request, only your own folders changed |

The review reads the history of the branch you are on, so run it on
`participant/<you>` after the pull request is merged.

## Hints

- `git status` during a conflict tells you exactly which files to fix.
- Conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) must all be gone.
- A commit message can be fixed before pushing with `git commit --amend`.
- Allowed folders: `app/api-tests/`, `app/exercises/`, `app/e2e/tests/`,
  `tracks/00-fundamentals/answers.yml` and `.github/workflows/`.

## Further reading

- [Pro Git: branching and merging](https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging)
- [Pro Git: resolving merge conflicts](https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging#_basic_merge_conflicts)
- [Conventional Commits 1.0](https://www.conventionalcommits.org/en/v1.0.0/)
- [GitHub: about pull requests](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests)
