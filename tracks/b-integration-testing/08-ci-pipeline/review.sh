#!/usr/bin/env bash
# Review of B-08: static checks of the QA workflow .github/workflows/qa-<user>.yml.
#
#   ./scripts/review.sh b-integration-testing/08-ci-pipeline [--json] [--overlay <dir>]
#
# --overlay <dir> checks <dir>/.github/workflows/qa-*.yml instead.
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

# qa-<user>.yml for the participant on this branch; any qa-*.yml otherwise.
workflows="${BASE_DIR}/.github/workflows"
file=""
if [[ "$SCORE_BRANCH" == participant/* && -f "${workflows}/qa-${SCORE_USER}.yml" ]]; then
  file="${workflows}/qa-${SCORE_USER}.yml"
else
  file="$(find "$workflows" -maxdepth 1 -name 'qa-*.yml' 2>/dev/null | sort | head -n 1)"
fi
if [[ -z "$file" ]]; then
  score_hint "workflow" "Create .github/workflows/qa-${SCORE_USER:-<user>}.yml on your branch (see the README)."
  score_gate false "no .github/workflows/qa-<user>.yml"
fi
if ! workflow_load "$file"; then
  score_hint "workflow" "The workflow is not valid YAML. Check the indentation (spaces, not tabs)."
  score_gate false "${file##*/} is not valid YAML"
fi
score_gate true "${file##*/} found"

passed=0
check() {
  local ok="$1" id="$2" title="$3" hint="$4"
  if [[ "$ok" == "true" ]]; then
    passed=$(( passed + 1 ))
  else
    score_hint "$id" "$hint" "$title"
  fi
}

triggered=false
user_pattern="participant/${SCORE_USER}"
[[ "$SCORE_BRANCH" == participant/* ]] || user_pattern="participant/"
while IFS= read -r branch; do
  [[ "$branch" == "$user_pattern"* || "$branch" == "participant/**" || "$branch" == "participant/*" ]] && triggered=true
done < <(workflow_push_branches)
check "$triggered" "trigger" "No push trigger for your branch" \
  "Run the workflow on push to your branch: on: { push: { branches: ['participant/<you>'] } }."

stack=false
workflow_any_run 'docker compose' '--profile[ =]full' '[[:space:]]up([[:space:]]|$)' && stack=true
check "$stack" "stack" "The stack is not started" \
  "Start the full stack before the tests: docker compose --profile full up -d --build --wait (in app/)."

api_tests=false
workflow_any_run 'mvnw|mvn ' 'app/api-tests' && api_tests=true
workflow_any_step '((.run // "") | test("mvnw|mvn ")) and (.["working-directory"] | test("app/api-tests"))' && api_tests=true
check "$api_tests" "api-tests" "The api-tests module is not run" \
  "Run the API tests: ./mvnw -B test with working-directory: app/api-tests."

cache=false
workflow_any_step '((.uses // "") | startswith("actions/setup-java")) and (.with.cache // "") == "maven"' && cache=true
workflow_any_step '((.uses // "") | startswith("actions/cache")) and ((.with.path // "") | test("\\.m2"))' && cache=true
check "$cache" "cache" "Maven dependencies are not cached" \
  "Cache Maven: actions/setup-java with 'cache: maven' (or actions/cache on ~/.m2)."

artifact=false
workflow_any_step '((.uses // "") | startswith("actions/upload-artifact")) and ((.with.path // "") | test("surefire-reports"))' && artifact=true
check "$artifact" "artifact" "Test reports are not published" \
  "Publish the Surefire reports: actions/upload-artifact with path app/api-tests/target/surefire-reports, also when tests fail (if: always())."

score_criterion "Workflow checks" $(( passed * 20 )) 100 "${passed}/5"
score_end
