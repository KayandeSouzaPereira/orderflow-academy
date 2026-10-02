#!/usr/bin/env bash
# Review of the bonus challenge: the standard flow over two suites (backend
# unit tests and black-box API tests), plus 10 points for fixing
# HallucinatedApiTest and moving it into the API test package.
set -euo pipefail

TOPIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$TOPIC_DIR"
while [[ ! -f "${ROOT}/scripts/lib/standard.sh" && "$ROOT" != "/" ]]; do ROOT="$(dirname "$ROOT")"; done
# shellcheck source=../../scripts/lib/standard.sh
source "${ROOT}/scripts/lib/standard.sh"

HALLUCINATED_RESULT="0 0"

# Called by review_standard right after the gate, while the Surefire reports
# are still those of the gate run.
# shellcheck disable=SC2317,SC2329 # invoked by review_standard
topic_after_gate() {
  HALLUCINATED_RESULT="$(runner_class_results HallucinatedApiTest)"
}

# shellcheck disable=SC2317,SC2329 # invoked by review_standard
topic_report() {
  local tests failed
  read -r tests failed <<<"$HALLUCINATED_RESULT"
  if (( tests > 0 && failed == 0 )); then
    score_criterion "HallucinatedApiTest fixed and passing" 10 10 "" ok
  else
    score_criterion "HallucinatedApiTest fixed and passing" 0 10 "" fail
    score_hint "hallucinated" "Fix tracks/bonus-ai-review/starter/broken/HallucinatedApiTest.java.txt (use only methods that exist in RestAssured, AssertJ and Awaitility), rename it to .java and move it to app/api-tests/src/test/java/dev/orderflow/apitests/tracks/bonus/." \
      "HallucinatedApiTest is not in the package yet"
  fi
}

review_standard "$TOPIC_DIR" "$@"
