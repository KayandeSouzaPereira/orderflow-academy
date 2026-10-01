#!/usr/bin/env bash
# Review of B-01: runs the maintainer checks (checks/) against the exercises
# in app/exercises and scores the share that pass.
#
#   ./scripts/review.sh b-integration-testing/01-java-basics [--json] [--overlay <dir>]
set -euo pipefail

TOPIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$TOPIC_DIR"
while [[ ! -f "${ROOT}/scripts/lib/score.sh" && "$ROOT" != "/" ]]; do ROOT="$(dirname "$ROOT")"; done
# shellcheck source=../../../scripts/lib/score.sh
source "${ROOT}/scripts/lib/score.sh"
# shellcheck source=../../../scripts/lib/common.sh
source "${ROOT}/scripts/lib/common.sh"
# shellcheck source=../../../scripts/lib/runner.sh
source "${ROOT}/scripts/lib/runner.sh"

OVERLAY=""
while (( $# > 0 )); do
  case "$1" in
    --json) export SCORE_JSON=1 ;;
    --quick) ;; # nothing slow to skip
    --overlay) OVERLAY="${2:?--overlay needs a directory}"; shift ;;
    *) score_fatal "unknown option '$1'" "Options: --json, --overlay <dir>." ;;
  esac
  shift
done

review_require_bash
review_require_tools jq yq tar
review_require_java
review_install_traps
score_begin "$TOPIC_DIR"

review_workspace_create
[[ -n "$OVERLAY" ]] && review_workspace_overlay "$OVERLAY"

RUNNER_MODULE_DIR="${REVIEW_WORKSPACE}/app/exercises"
RUNNER_LOG="${REVIEW_WORKSPACE}/exercises.log"
checks_dir="${RUNNER_MODULE_DIR}/src/test/java/dev/orderflow/exercises"
mkdir -p "$checks_dir"
cp "${TOPIC_DIR}/checks/"*.java "$checks_dir/"

score_progress "running the checks against your exercises"
status=0
run_with_timeout 300 runner__mvnw test -Dsurefire.failIfNoSpecifiedTests=false >"$RUNNER_LOG" 2>&1 || status=$?
runner__count_results "${RUNNER_MODULE_DIR}/target/surefire-reports"

if (( status == 124 )); then
  score_gate false "the checks timed out (an endless loop?)"
fi
if (( status != 0 )) && grep -q 'COMPILATION ERROR' "$RUNNER_LOG"; then
  score_hint "compile" "Fix the compilation errors in app/exercises:
$(runner_failure_summary)"
  score_gate false "app/exercises does not compile"
fi
passed=$(( RUNNER_TESTS - RUNNER_FAILED ))
if (( RUNNER_TESTS == 0 || passed == 0 )); then
  score_hint "start" "Implement the exercises in app/exercises/src/main/java/dev/orderflow/exercises/Exercises.java."
  score_gate false "no exercise implemented yet"
fi
score_gate true "app/exercises compiles"

# Exercises with at least one failing check (test names start with exNN).
failing="$(for file in "${RUNNER_MODULE_DIR}/target/surefire-reports"/TEST-*.xml; do
  yq -p xml -o json '.testsuite.testcase' "$file"
done | jq -r 'if type == "array" then .[] else . end
  | select(has("failure") or has("error")) | .["+@name"]' \
  | { grep -oE '^ex[0-9]{2}' || true; } | sed 's/^ex0\{0,1\}//' | sort -n | uniq | paste -sd ',' - | sed 's/,/, /g')"
if [[ -n "$failing" ]]; then
  score_hint "exercises" "Exercises with failing checks: ${failing}. Re-read their Javadoc in Exercises.java and test them yourself."
fi

score_criterion "Exercise checks" "$(review_round_ratio 100 "$passed" "$RUNNER_TESTS")" 100 "${passed}/${RUNNER_TESTS}"
score_end
