# Decisions

Decisions taken while implementing the SDD, including the open decisions it
listed (D1-D6) and every deviation from it. Newest last.

| Id | Decision | Why |
| --- | --- | --- |
| D1 | Bug bank lives in the public repository (`tracks/**/bugs/`). | Simplicity and fast local feedback; participants agree not to open `bugs/`. Revisit if abused. |
| D2 | Angular unit tests run on Vitest (Angular 22 default). | Recommended by the SDD; see the Stryker note below. |
| D3 | AWS access through the Quarkiverse Amazon Services extensions, Quarkus 3.40 LTS, Dev Services off. | Recommended by the SDD. |
| D4 | Floci image pinned to `floci/floci:2.1.0`. | Latest stable when phase 1 started; updated only through a PR to main. |
| D5 | Training cadence: not decided (does not affect the repository). | Left to the maintainer. |
| D6 | Playwright tests in TypeScript. | Recommended by the SDD (fixtures, UI mode, trace viewer). |
| - | Angular 22 requires Node.js 22.22+ (24.15+ also supported). | Latest stable Angular, as the SDD asks. |
| - | `xmllint` is not used: Surefire and PIT XML reports are read with `yq -p xml`. | One dependency less for participants. |
| - | `aws-init` is built into its own image instead of bind-mounting the script. | Bind mounts from temporary folders broke the Docker Desktop API ("error during connect ... EOF") and are fragile in CI and WSL. |
| - | Reviews of black-box topics start their own stack as compose project `orderflow-review` on ports 14566/18080/14200. | Never clashes with a developer stack on the default ports. |
| - | `00-fundamentals` answers are hashed as `sha256("<id>:<letter>")`. | Checked without revealing them; with 4 options per question this hides answers from casual reading, not from a determined participant. |
| - | A-03 (TDD kata): bugs are planted in a reference `CouponPolicy` in `bugs/reference/`, swapped in for the participant's implementation; participants' tests must also pass on it. | The SDD asks for bug variants of the reference implementation; the extra gate stops tests that check behaviour outside the specification. |
| - | A-05 has no mutation testing: weights are bugs 70, practices 30, with 6 planted bugs. | PIT restarts Quarkus and Floci for every mutant: more than 6 minutes for a single class, and timed-out mutants count as killed. Decided by the maintainer. |
| - | A-04 mutation testing uses Stryker's `command` runner (Vitest once per mutant, through `app/frontend/stryker/vitest.config.mts` with the Analog Angular plugin) instead of Stryker's Vitest runner. | With the Analog plugin, Stryker's Vitest runner never activates mutants (0% killed). The command runner works but is slower: string, object and array literal mutations are excluded and the cart's `localStorage` helpers are marked `// Stryker disable`. |
| - | Study branches are `study/<user>/<topic>`, not `participant/<user>/<topic>`. | Git cannot hold `participant/<user>` and `participant/<user>/b02` at the same time (a ref cannot also be a folder). The separate prefix also keeps study pushes out of the review workflow, which watches `participant/**`. |
| - | B-01 exercises live in `app/exercises` (a standalone Maven module); the maintainer checks in `tracks/.../01-java-basics/checks/` are copied in during the review. | Participant work must stay out of `tracks/`, which CI replaces with the version from main. |
| - | B-02 exercise branches are created by `scripts/dev/create-b02-exercise.sh --push` after the phase that adds `TEAM-NOTES.md` reaches main. | They must start from main, so they can only exist once main has the file. |
| - | Reviews of custom topics whose work is not files (B-02) validate with Git bundles: `empty/`, `reference/` and `calibration-weak/repo.bundle` in the private repository. | A history cannot be applied as an overlay. |
| - | The frontend `package-lock.json` is generated on Linux. | A lock file written on Windows misses optional packages of other platforms (`@emnapi/*`), which breaks `npm ci` in Docker and CI. |
| - | Planted bugs never rely on S3 signature checks. | Floci does not verify pre-signed URL signatures (a real difference from AWS): a bug that only spoils the signature goes unnoticed. Bugs break the object key instead. |
| - | Reviews call Node tools through `node <package>/cli.js` instead of `npx`. | `npx` fails silently in Git Bash with a portable Node on Windows; calling the CLI file works everywhere. |
| - | B-09 checks its 20 bugs on 3 stacks in parallel (`parallel_stacks: 3`). | One stack took 22 minutes (each bug rebuilds the backend image); three take about 12, within the 15 minutes of tracks B and C. Decided by the maintainer. |
| - | `scripts/review.sh` runs the topic review in a forked subshell and forwards Ctrl+C/TERM to it, instead of `exec`. | On Windows (MSYS) every exec leaves an intermediate process that swallows signals, so an interrupted review left its stacks running. |
