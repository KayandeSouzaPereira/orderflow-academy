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
