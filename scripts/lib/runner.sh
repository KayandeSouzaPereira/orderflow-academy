# shellcheck shell=bash
# -----------------------------------------------------------------------------
# Runs the tests of one topic inside the workspace.
#
#   runner_init <kind> <test-package>      chooses module and test filter
#   runner_run [maven args...]             runs the topic's tests once
#
# runner_run returns:
#   0   all tests passed            1   at least one test failed
#   2   production code does not compile
#   3   test code does not compile  124 time limit reached
# and sets RUNNER_TESTS, RUNNER_FAILED (counts) and RUNNER_LOG (full output).
#
# Supported kinds: backend (app/backend) and api (app/api-tests). frontend and
# e2e runners are added with the topics that need them (phases 4 and 5).
# -----------------------------------------------------------------------------

RUNNER_KIND=""
RUNNER_MODULE_DIR=""
RUNNER_TEST_PACKAGE=""
RUNNER_TEST_DIR=""
RUNNER_TIMEOUT=300
RUNNER_TESTS=0
RUNNER_FAILED=0
RUNNER_LOG=""
RUNNER_RUN_COUNT=0

runner_init() {
  RUNNER_KIND="$1"
  RUNNER_TEST_PACKAGE="$2"
  case "$RUNNER_KIND" in
    backend) RUNNER_MODULE_DIR="${REVIEW_WORKSPACE}/app/backend" ;;
    api) RUNNER_MODULE_DIR="${REVIEW_WORKSPACE}/app/api-tests" ;;
    *) score_fatal "kind '${RUNNER_KIND}' has no test runner yet" \
         "Supported kinds: backend, api. Use kind: custom and score the topic in its review.sh." ;;
  esac
  [[ -n "$RUNNER_TEST_PACKAGE" ]] || score_fatal "topic.yml has no test_package" \
    "Set test_package, e.g. dev.orderflow.tracks.a01."
  RUNNER_TEST_DIR="${RUNNER_MODULE_DIR}/src/test/java/${RUNNER_TEST_PACKAGE//.//}"
}

# Lists the test source files of the topic (absolute paths, one per line).
runner_test_files() {
  [[ -d "$RUNNER_TEST_DIR" ]] || return 0
  find "$RUNNER_TEST_DIR" -type f -name '*.java' | sort
}

runner_run() {
  RUNNER_RUN_COUNT=$(( RUNNER_RUN_COUNT + 1 ))
  RUNNER_LOG="${REVIEW_WORKSPACE}/run-${RUNNER_RUN_COUNT}.log"
  RUNNER_TESTS=0
  RUNNER_FAILED=0
  runner__maven "$@"
}

runner__mvnw() {
  (cd "$RUNNER_MODULE_DIR" && chmod +x mvnw && ./mvnw -B -ntp "$@")
}

runner__maven() {
  local reports="${RUNNER_MODULE_DIR}/target/surefire-reports"
  rm -rf "$reports"

  # One Maven run (compile + test); the log tells compile errors from failing tests.
  local pattern="${RUNNER_TEST_PACKAGE//.//}/**/*"
  local status=0
  run_with_timeout "$RUNNER_TIMEOUT" runner__mvnw test \
    "-Dtest=${pattern}" \
    -Dsurefire.failIfNoSpecifiedTests=false \
    -DtrimStackTrace=true \
    "$@" >"$RUNNER_LOG" 2>&1 || status=$?

  runner__count_results "$reports"
  if (( status == 124 )); then
    return 124
  fi
  if (( status != 0 )) && grep -q 'COMPILATION ERROR' "$RUNNER_LOG"; then
    if grep -E '^\[ERROR\] .*[/\\]src[/\\]main[/\\]' "$RUNNER_LOG" >/dev/null; then
      return 2
    fi
    return 3
  fi
  if (( status != 0 || RUNNER_FAILED > 0 )); then
    return 1
  fi
  return 0
}

# Sums tests/failures/errors over the Surefire XML reports.
runner__count_results() {
  local reports="$1" file counts tests failed
  [[ -d "$reports" ]] || return 0
  for file in "$reports"/TEST-*.xml; do
    [[ -f "$file" ]] || continue
    counts="$(yq -p xml -o json '.testsuite' "$file" \
      | jq -r '[(.["+@tests"] // "0"), ((.["+@failures"] // "0" | tonumber) + (.["+@errors"] // "0" | tonumber))] | @tsv')"
    IFS=$'\t' read -r tests failed <<<"$counts"
    RUNNER_TESTS=$(( RUNNER_TESTS + tests ))
    RUNNER_FAILED=$(( RUNNER_FAILED + failed ))
  done
}

# Prints the last lines of the log that explain a failure (compile errors or
# failing tests), for the participant.
runner_failure_summary() {
  [[ -f "$RUNNER_LOG" ]] || return 0
  grep -E '^\[ERROR\] .*(\.java|Tests run:|FAIL|expected|but was)' "$RUNNER_LOG" \
    | grep -vE 'To see the full stack trace|Re-run Maven|Help 1|^\[ERROR\] *$' \
    | head -n 8 \
    | sed -e "s#${REVIEW_WORKSPACE}/##g" -e 's/^/          /'
}
