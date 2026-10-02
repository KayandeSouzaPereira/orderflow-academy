# shellcheck shell=bash
# -----------------------------------------------------------------------------
# Runs the tests of one topic inside the workspace.
#
#   runner_init <kind> <test-package> [test-file...]
#                                          chooses module and test filter
#                                          (frontend: spec files relative to app/frontend)
#   runner_run [extra args...]             runs the topic's tests once
#
# runner_run returns:
#   0   all tests passed            1   at least one test failed
#   2   production code does not compile
#   3   test code does not compile  124 time limit reached
# and sets RUNNER_TESTS, RUNNER_FAILED (counts) and RUNNER_LOG (full output).
#
# Supported kinds: backend (app/backend), api (app/api-tests), frontend
# (app/frontend, Angular unit tests through 'ng test'), e2e (Playwright) and
# multi: several Maven suites run together, as in the bonus challenge
# (topic.yml: kind: multi, suites: [{kind: backend, test_package: ...}, ...]).
# A multi run sums the tests of its suites; its status is the most severe one.
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
RUNNER_FRONTEND_SPECS=()
RUNNER_SUITES=()   # multi: "kind|test.package" entries

runner_init() {
  RUNNER_KIND="$1"
  RUNNER_TEST_PACKAGE="$2"
  shift 2
  case "$RUNNER_KIND" in
    backend) RUNNER_MODULE_DIR="${REVIEW_WORKSPACE}/app/backend" ;;
    api) RUNNER_MODULE_DIR="${REVIEW_WORKSPACE}/app/api-tests" ;;
    multi)
      RUNNER_SUITES=("$@")
      (( ${#RUNNER_SUITES[@]} > 0 )) || score_fatal "topic.yml has no suites"         "List them: suites: [{kind: backend, test_package: ...}, {kind: api, test_package: ...}]."
      return 0 ;;
    frontend)
      RUNNER_MODULE_DIR="${REVIEW_WORKSPACE}/app/frontend"
      RUNNER_FRONTEND_SPECS=("$@")
      (( ${#RUNNER_FRONTEND_SPECS[@]} > 0 )) || score_fatal "topic.yml has no test_files" \
        "List the spec files, e.g. test_files: [src/app/cart/cart.service.spec.ts]."
      return 0 ;;
    e2e)
      RUNNER_MODULE_DIR="${REVIEW_WORKSPACE}/app/e2e"
      [[ -n "${1:-}" ]] || score_fatal "topic.yml has no test_dir" "Set test_dir, e.g. tests/tracks/c01."
      RUNNER_TEST_DIR="${RUNNER_MODULE_DIR}/$1"
      return 0 ;;
    *) score_fatal "kind '${RUNNER_KIND}' has no test runner yet" \
         "Supported kinds: backend, api, frontend. Use kind: custom and score the topic in its review.sh." ;;
  esac
  [[ -n "$RUNNER_TEST_PACKAGE" ]] || score_fatal "topic.yml has no test_package" \
    "Set test_package, e.g. dev.orderflow.tracks.a01."
  RUNNER_TEST_DIR="${RUNNER_MODULE_DIR}/src/test/java/${RUNNER_TEST_PACKAGE//.//}"
}

# Points the runner at one Maven suite ("backend" or "api") of a multi topic.
runner__select_suite() {
  local kind="$1"
  RUNNER_TEST_PACKAGE="$2"
  case "$kind" in
    backend) RUNNER_MODULE_DIR="${REVIEW_WORKSPACE}/app/backend" ;;
    api) RUNNER_MODULE_DIR="${REVIEW_WORKSPACE}/app/api-tests" ;;
    *) score_fatal "suite kind '${kind}' is not supported" "Suites can be backend or api." ;;
  esac
  RUNNER_TEST_DIR="${RUNNER_MODULE_DIR}/src/test/java/${RUNNER_TEST_PACKAGE//.//}"
}

# Lists the test source files of the topic (absolute paths, one per line).
runner_test_files() {
  if [[ "$RUNNER_KIND" == "multi" ]]; then
    local suite
    for suite in "${RUNNER_SUITES[@]}"; do
      runner__select_suite "${suite%%|*}" "${suite#*|}"
      [[ -d "$RUNNER_TEST_DIR" ]] && find "$RUNNER_TEST_DIR" -type f -name '*.java' | sort
    done
    return 0
  fi
  if [[ "$RUNNER_KIND" == "frontend" ]]; then
    local spec
    for spec in "${RUNNER_FRONTEND_SPECS[@]}"; do
      [[ -f "${RUNNER_MODULE_DIR}/${spec}" ]] && echo "${RUNNER_MODULE_DIR}/${spec}"
    done
    return 0
  fi
  [[ -d "$RUNNER_TEST_DIR" ]] || return 0
  if [[ "$RUNNER_KIND" == "e2e" ]]; then
    find "$RUNNER_TEST_DIR" -type f -name '*.ts' | sort
    return 0
  fi
  find "$RUNNER_TEST_DIR" -type f -name '*.java' | sort
}

runner_run() {
  RUNNER_RUN_COUNT=$(( RUNNER_RUN_COUNT + 1 ))
  RUNNER_LOG="${REVIEW_WORKSPACE}/run-${RUNNER_RUN_COUNT}.log"
  RUNNER_TESTS=0
  RUNNER_FAILED=0
  case "$RUNNER_KIND" in
    frontend) runner__angular "$@" ;;
    e2e) runner__playwright "$@" ;;
    multi) runner__multi "$@" ;;
    *) runner__maven "$@" ;;
  esac
}

# --- Several Maven suites (multi) --------------------------------------------

# Severity of a run status, to keep the worst one: compile errors in the app
# (2) > in the tests (3) > time out (124) > failing tests (1) > passed (0).
runner__severity() {
  case "$1" in
    2) echo 5 ;;
    3) echo 4 ;;
    124) echo 3 ;;
    1) echo 2 ;;
    *) echo 0 ;;
  esac
}

runner__multi() {
  local combined="$RUNNER_LOG" suite status worst=0 total=0 failed=0
  : >"$combined"
  for suite in "${RUNNER_SUITES[@]}"; do
    runner__select_suite "${suite%%|*}" "${suite#*|}"
    RUNNER_LOG="${combined}.${suite%%|*}"
    RUNNER_TESTS=0
    RUNNER_FAILED=0
    status=0
    runner__maven "$@" || status=$?
    total=$(( total + RUNNER_TESTS ))
    failed=$(( failed + RUNNER_FAILED ))
    { printf '=== suite %s ===
' "$suite"; cat "$RUNNER_LOG"; } >>"$combined"
    if (( $(runner__severity "$status") > $(runner__severity "$worst") )); then
      worst=$status
    fi
  done
  RUNNER_LOG="$combined"
  RUNNER_TESTS=$total
  RUNNER_FAILED=$failed
  return "$worst"
}

# Prints "<tests> <failed>" for the test class <ClassName> in the Surefire
# reports of the last run (any Maven module). "0 0" when it did not run.
runner_class_results() {
  local class_name="$1" file counts tests=0 failed=0 t f
  for file in "${REVIEW_WORKSPACE}"/app/*/target/surefire-reports/TEST-*."${class_name}".xml; do
    [[ -f "$file" ]] || continue
    counts="$(yq -p xml -o json '.testsuite' "$file"       | jq -r '[(.["+@tests"] // "0"), ((.["+@failures"] // "0" | tonumber) + (.["+@errors"] // "0" | tonumber))] | @tsv')"
    IFS=$'	' read -r t f <<<"$counts"
    tests=$(( tests + t ))
    failed=$(( failed + f ))
  done
  echo "${tests} ${failed}"
}

# --- Playwright (e2e) --------------------------------------------------------

# node_modules (hard links or npm ci) and the Chromium browser.
runner_e2e_dependencies() {
  local source="${SCORE_REPO_ROOT}/app/e2e/node_modules" target="${RUNNER_MODULE_DIR}/node_modules"
  if [[ ! -d "$target" ]]; then
    if [[ -d "$source" ]] && cp -al "$source" "$target" 2>/dev/null; then
      score_progress "linking e2e dependencies"
    else
      rm -rf "$target"
      score_progress "installing e2e dependencies (npm ci)"
      (cd "$RUNNER_MODULE_DIR" && npm ci --no-audit --no-fund >"${REVIEW_WORKSPACE}/npm-ci-e2e.log" 2>&1) \
        || score_fatal "npm ci failed in app/e2e" "Run 'npm ci' in app/e2e yourself and check the error."
    fi
  fi
  score_progress "making sure Chromium is installed for Playwright"
  # CI sets REVIEW_PLAYWRIGHT_WITH_DEPS=1 to also install the system libraries (needs sudo).
  # shellcheck disable=SC2086 # the flag must disappear when the variable is empty
  runner__playwright_cli install ${REVIEW_PLAYWRIGHT_WITH_DEPS:+--with-deps} chromium >"${REVIEW_WORKSPACE}/playwright-install.log" 2>&1 \
    || score_fatal "Playwright could not install Chromium" "Run 'npx playwright install chromium' in app/e2e."
}

runner__playwright_cli() {
  (cd "$RUNNER_MODULE_DIR" && node node_modules/@playwright/test/cli.js "$@")
}

runner__playwright() {
  local report="${REVIEW_WORKSPACE}/playwright-${RUNNER_RUN_COUNT}.json" status=0
  local relative="${RUNNER_TEST_DIR#"${RUNNER_MODULE_DIR}/"}"
  rm -f "$report"
  # Reviews never retry: a test must pass the first time.
  PLAYWRIGHT_JSON_OUTPUT_NAME="$report" run_with_timeout "$RUNNER_TIMEOUT" runner__playwright_cli test "$relative" \
    --reporter=json --retries=0 "$@" >"$RUNNER_LOG" 2>&1 || status=$?

  if [[ -f "$report" ]]; then
    RUNNER_TESTS="$(jq -r '.stats | (.expected // 0) + (.unexpected // 0) + (.flaky // 0)' "$report")"
    RUNNER_FAILED="$(jq -r '.stats | (.unexpected // 0) + (.flaky // 0)' "$report")"
    # A TypeScript or import error is reported as a global error, with no test run.
    if (( RUNNER_TESTS == 0 )) && [[ "$(jq -r '(.errors // []) | length' "$report")" != "0" ]]; then
      cat "$report" >>"$RUNNER_LOG"
      return 3
    fi
  fi
  if (( status == 124 )); then
    return 124
  fi
  if (( status != 0 || RUNNER_FAILED > 0 )); then
    return 1
  fi
  return 0
}

# --- Maven (backend, api) ----------------------------------------------------

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

# --- Angular (frontend) ------------------------------------------------------

# Makes node_modules available in the workspace: hard links to the
# participant's install when possible (fast, no copy), npm ci otherwise.
runner_frontend_dependencies() {
  local source="${SCORE_REPO_ROOT}/app/frontend/node_modules" target="${RUNNER_MODULE_DIR}/node_modules"
  [[ -d "$target" ]] && return 0
  if [[ -d "$source" ]]; then
    score_progress "linking frontend dependencies"
    cp -al "$source" "$target" 2>/dev/null && return 0
    rm -rf "$target"
  fi
  score_progress "installing frontend dependencies (npm ci)"
  (cd "$RUNNER_MODULE_DIR" && npm ci --no-audit --no-fund >"${REVIEW_WORKSPACE}/npm-ci.log" 2>&1) \
    || score_fatal "npm ci failed in the reviewed copy" "Run 'npm ci' in app/frontend yourself and check the error."
}

runner__ng() {
  (cd "$RUNNER_MODULE_DIR" && node node_modules/@angular/cli/bin/ng.js "$@")
}

runner__angular() {
  local report="${REVIEW_WORKSPACE}/vitest-${RUNNER_RUN_COUNT}.json" spec status=0
  local -a includes=()
  for spec in "${RUNNER_FRONTEND_SPECS[@]}"; do
    [[ -f "${RUNNER_MODULE_DIR}/${spec}" ]] && includes+=("--include=${spec}")
  done
  rm -f "$report"
  # The first reporter (json) writes to --outputFile; 'default' keeps a readable log.
  run_with_timeout "$RUNNER_TIMEOUT" runner__ng test --watch=false \
    --reporters=json --reporters=default "--output-file=${report}" \
    "${includes[@]}" "$@" >"$RUNNER_LOG" 2>&1 || status=$?

  if [[ -f "$report" ]]; then
    RUNNER_TESTS="$(jq -r '.numTotalTests // 0' "$report")"
    RUNNER_FAILED="$(jq -r '(.numFailedTests // 0) + (.numRuntimeErrorTestSuites // 0)' "$report")"
  fi
  if (( status == 124 )); then
    return 124
  fi
  if [[ ! -f "$report" ]] && (( status != 0 )); then
    # The build failed before any test ran: was it the app or a spec?
    if grep -E '[.]spec[.]ts' "$RUNNER_LOG" | grep -qiE 'error|TS[0-9]+'; then
      return 3
    fi
    return 2
  fi
  if (( status != 0 || RUNNER_FAILED > 0 )); then
    return 1
  fi
  return 0
}

# --- Reporting ---------------------------------------------------------------

# Prints the last lines of the log that explain a failure (compile errors or
# failing tests), for the participant.
runner_failure_summary() {
  [[ -f "$RUNNER_LOG" ]] || return 0
  if [[ "$RUNNER_KIND" == "e2e" ]]; then
    jq -r '[.. | objects | select(has("message")) | .message] | .[:4][] | split("\n")[0]' \
      "${REVIEW_WORKSPACE}/playwright-${RUNNER_RUN_COUNT}.json" 2>/dev/null \
      | sed $'s/\x1b\\[[0-9;]*m//g' | head -n 8 | sed 's/^/          /'
    return 0
  fi
  if [[ "$RUNNER_KIND" == "frontend" ]]; then
    sed $'s/\x1b\\[[0-9;]*m//g' "$RUNNER_LOG" \
      | grep -E 'FAIL|×|Error:|error TS|ERROR' \
      | head -n 8 \
      | sed -e "s#${REVIEW_WORKSPACE}/##g" -e 's/^/          /'
    return 0
  fi
  grep -E '^\[ERROR\] .*(\.java|Tests run:|FAIL|expected|but was)' "$RUNNER_LOG" \
    | grep -vE 'To see the full stack trace|Re-run Maven|Help 1|^\[ERROR\] *$' \
    | head -n 8 \
    | sed -e "s#${REVIEW_WORKSPACE}/##g" -e 's/^/          /'
}
