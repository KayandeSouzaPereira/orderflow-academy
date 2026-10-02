#!/usr/bin/env bash
# Review of C-05: static checks of the Playwright job in your workflow
# (.github/workflows/e2e-<user>.yml for devs, qa-<user>.yml for the QA).
#
#   ./scripts/review.sh c-e2e-testing/05-e2e-in-ci [--json] [--overlay <dir>]
#
# --overlay <dir> checks <dir>/.github/workflows/ instead.
set -euo pipefail

TOPIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$TOPIC_DIR"
while [[ ! -f "${ROOT}/scripts/lib/score.sh" && "$ROOT" != "/" ]]; do ROOT="$(dirname "$ROOT")"; done
# shellcheck source=../../../scripts/lib/score.sh
source "${ROOT}/scripts/lib/score.sh"
# shellcheck source=../../../scripts/lib/common.sh
source "${ROOT}/scripts/lib/common.sh"
# shellcheck source=../../../scripts/lib/workflow.sh
source "${ROOT}/scripts/lib/workflow.sh"

BASE_DIR="$SCORE_REPO_ROOT"
while (( $# > 0 )); do
  case "$1" in
    --json) export SCORE_JSON=1 ;;
    --quick) ;;
    --overlay) BASE_DIR="${2:?--overlay needs a directory}"; shift ;;
    *) score_fatal "unknown option '$1'" "Options: --json, --overlay <dir>." ;;
  esac
  shift
done

review_require_bash
review_require_tools jq yq
score_begin "$TOPIC_DIR"

workflows="${BASE_DIR}/.github/workflows"
file=""
if [[ "$SCORE_BRANCH" == participant/* ]]; then
  for candidate in "e2e-${SCORE_USER}.yml" "qa-${SCORE_USER}.yml"; do
    [[ -z "$file" && -f "${workflows}/${candidate}" ]] && file="${workflows}/${candidate}"
  done
fi
if [[ -z "$file" ]]; then
  file="$(find "$workflows" -maxdepth 1 \( -name 'e2e-*.yml' -o -name 'qa-*.yml' \) 2>/dev/null | sort | head -n 1)"
fi
if [[ -z "$file" ]]; then
  score_hint "workflow" "Create .github/workflows/e2e-<you>.yml (devs) or add a job to qa-<you>.yml (QA)."
  score_gate false "no e2e-<user>.yml or qa-<user>.yml workflow"
fi
if ! workflow_load "$file"; then
  score_hint "workflow" "The workflow is not valid YAML. Check the indentation (spaces, not tabs)."
  score_gate false "${file##*/} is not valid YAML"
fi
score_gate true "${file##*/} found"

passed=0
total=6
check() {
  local ok="$1" id="$2" title="$3" hint="$4"
  if [[ "$ok" == "true" ]]; then
    passed=$(( passed + 1 ))
  else
    score_hint "$id" "$hint" "$title"
  fi
}

triggered=false
while IFS= read -r branch; do
  [[ "$branch" == participant/* ]] && triggered=true
done < <(workflow_push_branches)
check "$triggered" "trigger" "No push trigger for your branch" \
  "Run the workflow on push to your branch: on: { push: { branches: ['participant/<you>'] } }."

browsers=false
if workflow_any_run 'playwright install' \
  && workflow_any_step '((.uses // "") | startswith("actions/cache")) and ((.with.path // "") | test("ms-playwright"))'; then
  browsers=true
fi
check "$browsers" "browsers" "Playwright browsers are not installed with a cache" \
  "Cache ~/.cache/ms-playwright with actions/cache and run 'npx playwright install --with-deps chromium'."

stack=false
workflow_any_run 'docker compose' '--profile[ =]full' '[[:space:]]up([[:space:]]|$)' && stack=true
check "$stack" "stack" "The stack is not started" \
  "Start the full stack before the tests: docker compose --profile full up -d --build --wait (in app/)."

runs=false
workflow_any_run 'playwright test' 'app/e2e' && runs=true
workflow_any_step '((.run // "") | test("playwright test")) and (.["working-directory"] | test("app/e2e"))' && runs=true
check "$runs" "playwright" "The Playwright tests are not run" \
  "Run them in app/e2e: npx playwright test tests/tracks (with E2E_BASE_URL and API_BASE_URL set)."

trace=false
workflow_any_run 'playwright test' 'on-first-retry' && trace=true
check "$trace" "trace" "No trace on the first retry" \
  "In CI, keep a trace of retried tests: npx playwright test --retries=1 --trace=on-first-retry."

report=false
workflow_any_step '((.uses // "") | startswith("actions/upload-artifact")) and ((.with.path // "") | test("playwright-report"))' && report=true
check "$report" "report" "The HTML report is not published" \
  "Publish app/e2e/playwright-report with actions/upload-artifact, also when tests fail (if: always())."

score_criterion "Workflow checks" "$(review_round_ratio 100 "$passed" "$total")" 100 "${passed}/${total}"
score_end
