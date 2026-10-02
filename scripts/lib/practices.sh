# shellcheck shell=bash
# -----------------------------------------------------------------------------
# Good-practice rules. Each rule is a function practice_<rule_with_underscores>
# that returns 0 (passes) or 1 (fails) and may set PRACTICE_DETAIL with the
# offending files/methods. Static rules read PRACTICE_FILES (the topic's test
# files); runtime rules run the tests again through runner.sh.
#
#   practice_run <rule>        runs one rule
#   practice_hint <rule>       one-line, actionable hint (English)
#   practice_title <rule>      short description of the rule
#
# Rules with parameters read them from PRACTICE_RULE_JSON, the rule's entry in
# topic.yml (e.g. {"rule": "starter-fixed", "file": "X.java"}).
# -----------------------------------------------------------------------------

PRACTICE_FILES=()
PRACTICE_DETAIL=""
PRACTICE_RULE_JSON='{}'
# Rules that read the Git history: skipped when reviewing an overlay
# (reference or calibration solutions have no history of their own).
PRACTICE_HISTORY_RULES=" tdd-history "
# EREs below avoid backslashes ([(] instead of \(): awk -v would eat them.
# Helpers named assert*/await*/expect*/verify* (e.g. awaitConfirmed, expectStatus) count too.
PRACTICE_ASSERTIONS='assertThat|assert[A-Z][A-Za-z]*[[:space:]]*[(]|await[A-Z][A-Za-z]*[[:space:]]*[(]|expect[A-Z][A-Za-z]*[[:space:]]*[(]|verify[A-Za-z]*[[:space:]]*[(]|[.]statusCode[[:space:]]*[(]|[.]body[[:space:]]*[(]|expect[[:space:]]*[(]|expect[.](poll|soft)[[:space:]]*[(]'
PRACTICE_SEEDS=(20261001 4242)

practice_title() {
  case "$1" in
    no-thread-sleep) echo "No Thread.sleep in tests" ;;
    no-disabled-tests) echo "No disabled or skipped tests" ;;
    every-test-asserts) echo "Every test asserts something" ;;
    no-hardcoded-endpoints) echo "No hard-coded hosts or ports" ;;
    naming-convention) echo "Test names follow should<Result>When<Condition>" ;;
    random-order-stable) echo "Tests pass in random order" ;;
    idempotent-data) echo "Tests pass twice on the same environment" ;;
    black-box-only) echo "Only the public API is used" ;;
    no-quarkus-test) echo "Unit tests do not start Quarkus" ;;
    starter-fixed) echo "The starter tests were fixed" ;;
    tdd-history) echo "Tests come before or with the code (Git history)" ;;
    traceability) echo "Every manual case has an automated test" ;;
    no-empty-catch) echo "No swallowed exceptions in tests" ;;
    original-tests-kept) echo "Every original test still exists" ;;
    no-wait-for-timeout) echo "No fixed waits (waitForTimeout)" ;;
    no-test-only) echo "No test.only, test.skip or test.fixme" ;;
    accessible-locators) echo "Locators by role, label or text" ;;
    no-hardcoded-base-url) echo "Navigation relative to baseURL" ;;
    page-objects) echo "Specs use page objects" ;;
    api-data-setup) echo "Test data prepared through the API" ;;
    stable-without-retries) echo "Passes twice more without retries" ;;
    *) echo "$1" ;;
  esac
}

practice_hint() {
  case "$1" in
    no-thread-sleep) echo "Wait for a condition, not for time: await().atMost(...).untilAsserted(...) (Awaitility)." ;;
    no-disabled-tests) echo "Remove @Disabled/@Ignore: a skipped test protects nothing. Fix it or delete it." ;;
    every-test-asserts) echo "A test without an assertion only checks that nothing throws. Assert the result you expect (helpers named assert*/expect*/await* count)." ;;
    no-hardcoded-endpoints) echo "Read hosts and ports from configuration (TestApi, @ConfigProperty, injected clients), never from literals." ;;
    naming-convention) echo "Rename tests to should<Result>When<Condition>, e.g. shouldReturn409WhenStockIsInsufficient." ;;
    random-order-stable) echo "A test relies on state left by another one. Give each test its own data and no shared mutable fields." ;;
    idempotent-data) echo "Running the suite again fails. Create unique data per run (new products, random e-mails) instead of fixed ids." ;;
    black-box-only) echo "Talk to the system only through HTTP: no backend classes, no AWS SDK, no direct database checks." ;;
    no-quarkus-test) echo "Build the class under test with 'new' and Mockito mocks; @QuarkusTest belongs to integration tests." ;;
    starter-fixed) echo "Copy the starter test into your package and fix all three problems: missing assertion, two behaviours in one test, generic name." ;;
    tdd-history) echo "Commit a failing test first (or together with the code), then the code that makes it pass. Small commits make this visible." ;;
    traceability) echo "Give every manual case a heading with its id (## MC-01 ...) and tag at least one test with @Tag(\"MC-01\")." ;;
    no-empty-catch) echo "An empty catch hides failures: assert the exception (assertThatThrownBy) or let it fail the test." ;;
    original-tests-kept) echo "Fix the tests, do not delete or rename them: every original test method must still exist under its name." ;;
    no-wait-for-timeout) echo "Wait for what you expect to see: await expect(locator).toHaveText(...) or expect.poll(...) retry until it holds." ;;
    no-test-only) echo "Remove .only/.skip/.fixme before you push: they hide tests from the run." ;;
    accessible-locators) echo "Use page.getByRole/getByLabel/getByText; CSS or XPath only for [data-testid] when nothing accessible exists." ;;
    no-hardcoded-base-url) echo "Navigate with relative paths (page.goto('/cart')) and read the API URL from support/environment.ts." ;;
    page-objects) echo "Move page.getBy*/page.locator calls into page objects; specs should read like a user story." ;;
    api-data-setup) echo "Create products and orders in a fixture with request.post(...) to the API, not through the UI." ;;
    stable-without-retries) echo "A test passed once and failed later: wait on assertions, use your own data, avoid timing assumptions." ;;
    *) echo "See the topic README." ;;
  esac
}

practice_known() {
  declare -F "practice_${1//-/_}" >/dev/null
}

practice_is_history_rule() {
  [[ "$PRACTICE_HISTORY_RULES" == *" $1 "* ]]
}

# Reads a parameter of the current rule (empty when missing).
practice_param() {
  jq -r "$1 // empty" <<<"$PRACTICE_RULE_JSON"
}

practice_run() {
  local rule="$1"
  PRACTICE_DETAIL=""
  "practice_${rule//-/_}"
}

# --- Helpers -----------------------------------------------------------------

# Prints "file:line" for lines of the test files matching an ERE, ignoring
# comment-only lines.
practice__grep() {
  local pattern="$1" file
  for file in "${PRACTICE_FILES[@]}"; do
    awk -v pat="$pattern" -v name="${file##*/}" '
      /^[[:space:]]*(\/\/|\*|\/\*)/ { next }
      $0 ~ pat { printf "%s:%d\n", name, NR }' "$file"
  done
}

# Prints "<method>\t<has-assertion 0|1>" for every @Test-like method.
practice__java_tests() {
  local file
  for file in "${PRACTICE_FILES[@]}"; do
    awk -v asserts="$PRACTICE_ASSERTIONS" '
      function strip(s) { gsub(/"([^"\\]|\\.)*"/, "\"\"", s); sub(/\/\/.*$/, "", s); return s }
      {
        code = strip($0)
        if (!inbody) {
          if (code ~ /@(Test|ParameterizedTest|RepeatedTest)([^A-Za-z]|$)/) pending = 1
          if (pending && match(code, /void[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(/)) {
            name = substr(code, RSTART, RLENGTH)
            sub(/^void[[:space:]]+/, "", name); sub(/[[:space:]]*\($/, "", name)
            inbody = 1; depth = 0; started = 0; found = 0; pending = 0
          }
        }
        if (inbody) {
          if (code ~ asserts) found = 1
          n = split(code, chars, "")
          for (i = 1; i <= n; i++) {
            if (chars[i] == "{") { depth++; started = 1 }
            else if (chars[i] == "}") depth--
          }
          if (started && depth <= 0) { printf "%s\t%d\n", name, found; inbody = 0 }
        }
      }' "$file"
  done
}

# Same as practice__java_tests for TypeScript specs: one line per it()/test(),
# "<title>\t<has-assertion 0|1>".
practice__ts_tests() {
  local file
  for file in "${PRACTICE_FILES[@]}"; do
    awk -v asserts="$PRACTICE_ASSERTIONS|expectOne[(]|expectNone[(]" '
      function strip(s) {
        gsub(/"([^"\\]|\\.)*"/, "\"\"", s)
        gsub(/\047([^\047\\]|\\.)*\047/, "\047\047", s)
        gsub(/`[^`]*`/, "``", s)
        sub(/\/\/.*$/, "", s)
        return s
      }
      {
        if (!inbody && match($0, /(^|[^A-Za-z_.])(it|test)[[:space:]]*[(][[:space:]]*['\''"`]/)) {
          title = substr($0, RSTART + RLENGTH)
          sub(/['\''"`].*$/, "", title)
          inbody = 1; depth = 0; started = 0; found = 0
        }
        if (inbody) {
          code = strip($0)
          if (code ~ asserts) found = 1
          n = split(code, chars, "")
          for (i = 1; i <= n; i++) {
            if (chars[i] == "{") { depth++; started = 1 }
            else if (chars[i] == "}") depth--
          }
          if (started && depth <= 0) { printf "%s\t%d\n", title, found; inbody = 0 }
        }
      }' "$file"
  done
}

# Test methods of the topic, Java or TypeScript.
practice__tests() {
  if [[ "${PRACTICE_FILES[0]:-}" == *.ts ]]; then
    practice__ts_tests
  else
    practice__java_tests
  fi
}

practice__set_detail() {
  local list
  list="$(head -n 5 | paste -sd ',' - | sed 's/,/, /g')"
  PRACTICE_DETAIL="$list"
}

# --- Static rules ------------------------------------------------------------

practice_no_thread_sleep() {
  local hits
  hits="$(practice__grep 'Thread[.]sleep|TimeUnit[.][A-Z]+[.]sleep')"
  [[ -z "$hits" ]] && return 0
  practice__set_detail <<<"$hits"
  return 1
}

practice_no_disabled_tests() {
  local hits
  hits="$(practice__grep '@Disabled|@Ignore([^A-Za-z]|$)|(^|[^A-Za-z])x(it|describe)[[:space:]]*[(]|[.]skip[[:space:]]*[(]')"
  [[ -z "$hits" ]] && return 0
  practice__set_detail <<<"$hits"
  return 1
}

practice_no_hardcoded_endpoints() {
  local hits
  hits="$(practice__grep '(localhost|127[.]0[.]0[.]1|0[.]0[.]0[.]0):[0-9]+|:4566([^0-9]|$)|[.]port[[:space:]]*[(][[:space:]]*[0-9]+')"
  [[ -z "$hits" ]] && return 0
  practice__set_detail <<<"$hits"
  return 1
}

practice_every_test_asserts() {
  local missing
  missing="$(practice__tests | awk -F'\t' '$2 == 0 { print $1 }')"
  [[ -z "$missing" ]] && return 0
  practice__set_detail <<<"$missing"
  return 1
}

practice_naming_convention() {
  local wrong
  wrong="$(practice__java_tests | cut -f1 | grep -vE '^should[A-Z][A-Za-z0-9]*When[A-Z][A-Za-z0-9]*$' || true)"
  [[ -z "$wrong" ]] && return 0
  practice__set_detail <<<"$wrong"
  return 1
}

practice_black_box_only() {
  local pom="${REVIEW_WORKSPACE}/app/api-tests/pom.xml" problems=""
  if grep -qE '<artifactId>orderflow-backend</artifactId>|<groupId>software\.amazon\.awssdk</groupId>' "$pom"; then
    problems="api-tests/pom.xml depends on the backend or the AWS SDK"
  fi
  local imports
  imports="$(practice__grep '^[[:space:]]*import[[:space:]]+(static[[:space:]]+)?(dev[.]orderflow[.]|software[.]amazon[.]awssdk)' \
    | while IFS=: read -r name line; do
        local file
        for file in "${PRACTICE_FILES[@]}"; do
          [[ "${file##*/}" == "$name" ]] || continue
          sed -n "${line}p" "$file" | grep -qE 'dev\.orderflow\.apitests' || echo "${name}:${line}"
        done
      done)"
  [[ -n "$imports" ]] && problems="${problems:+${problems}; }${imports//$'\n'/, }"
  [[ -z "$problems" ]] && return 0
  PRACTICE_DETAIL="$problems"
  return 1
}

practice_no_quarkus_test() {
  local hits
  hits="$(practice__grep '@Quarkus(Test|IntegrationTest|ComponentTest|MainTest)|@InjectMock|@TestHTTPEndpoint')"
  [[ -z "$hits" ]] && return 0
  practice__set_detail <<<"$hits"
  return 1
}

# Parameters: file (test class copied from starter/), forbidden_names (original
# method names that must be gone), min_tests (at least this many tests in it).
practice_starter_fixed() {
  local name file="" candidate methods missing wrong forbidden min_tests count
  name="$(practice_param '.file')"
  for candidate in "${PRACTICE_FILES[@]}"; do
    [[ "${candidate##*/}" == "$name" ]] && file="$candidate"
  done
  if [[ -z "$file" ]]; then
    PRACTICE_DETAIL="${name} not found in your package (copy it from starter/)"
    return 1
  fi
  # Arrays cannot be passed as a temporary prefix: swap them explicitly.
  local -a all_files=("${PRACTICE_FILES[@]}")
  PRACTICE_FILES=("$file")
  methods="$(practice__java_tests)"
  PRACTICE_FILES=("${all_files[@]}")
  missing="$(awk -F'\t' '$2 == 0 { print $1 }' <<<"$methods")"
  wrong="$(cut -f1 <<<"$methods" | grep -vE '^should[A-Z][A-Za-z0-9]*When[A-Z][A-Za-z0-9]*$' || true)"
  forbidden="$(practice_param '.forbidden_names // [] | .[]' | grep -xF -f - <(cut -f1 <<<"$methods") || true)"
  min_tests="$(practice_param '.min_tests')"
  count="$(grep -c . <<<"$methods" || true)"
  local problems=()
  local nl=$'\n'
  [[ -n "$missing" ]] && problems+=("no assertion: ${missing//"$nl"/, }")
  [[ -n "$wrong" ]] && problems+=("generic names: ${wrong//"$nl"/, }")
  [[ -n "$forbidden" ]] && problems+=("still there: ${forbidden//"$nl"/, }")
  if [[ -n "$min_tests" ]] && (( count < min_tests )); then
    problems+=("${count} tests, expected at least ${min_tests} (split tests that check two things)")
  fi
  (( ${#problems[@]} == 0 )) && return 0
  PRACTICE_DETAIL="$(printf '%s; ' "${problems[@]}")"
  PRACTICE_DETAIL="${PRACTICE_DETAIL%; }"
  return 1
}

# Parameters: implementation (repo-relative path of the production file),
# min_percent (default 60). For every commit that changes the implementation,
# the topic's tests must change in the same commit or in the commit just
# before it (among the commits touching either).
practice_tdd_history() {
  local implementation min_percent tests_path commit files touches_impl touches_tests
  local previous_tests=0 impl_commits=0 ok_commits=0
  implementation="$(practice_param '.implementation')"
  min_percent="$(practice_param '.min_percent')"
  min_percent="${min_percent:-60}"
  tests_path="${RUNNER_TEST_DIR#"${REVIEW_WORKSPACE}/"}"

  while read -r commit; do
    [[ -z "$commit" ]] && continue
    files="$(git -C "$SCORE_REPO_ROOT" show --name-only --format= "$commit")"
    touches_impl=0 touches_tests=0
    grep -qxF "$implementation" <<<"$files" && touches_impl=1
    grep -q "^${tests_path}/" <<<"$files" && touches_tests=1
    if (( touches_impl )); then
      impl_commits=$(( impl_commits + 1 ))
      (( touches_tests || previous_tests )) && ok_commits=$(( ok_commits + 1 ))
    fi
    previous_tests=$(( touches_tests && ! touches_impl ))
  done < <(git -C "$SCORE_REPO_ROOT" log --reverse --format=%H -- "$implementation" "$tests_path" 2>/dev/null)

  if (( impl_commits == 0 )); then
    PRACTICE_DETAIL="no commit changes ${implementation##*/} yet (commit your work)"
    return 1
  fi
  local percent=$(( ok_commits * 100 / impl_commits ))
  (( percent >= min_percent )) && return 0
  PRACTICE_DETAIL="${ok_commits} of ${impl_commits} implementation commits had a test first (${percent}%, need ${min_percent}%)"
  return 1
}

# Parameters: cases_file (repo-relative Markdown file with one heading per
# manual case, e.g. "## MC-01 Order with an invalid e-mail"), min_cases.
# Every case id must appear in at least one @Tag("MC-XX") of the topic's tests.
practice_traceability() {
  local cases_file min_cases ids id missing=() count
  cases_file="$(practice_param '.cases_file')"
  min_cases="$(practice_param '.min_cases')"
  min_cases="${min_cases:-10}"
  if [[ ! -f "${REVIEW_WORKSPACE}/${cases_file}" ]]; then
    PRACTICE_DETAIL="${cases_file} not found"
    return 1
  fi
  ids="$(grep -oE '^#+[[:space:]]+MC-[0-9]{2}' "${REVIEW_WORKSPACE}/${cases_file}" | grep -oE 'MC-[0-9]{2}' | sort -u)"
  count="$(grep -c . <<<"$ids" || true)"
  for id in $ids; do
    grep -qE "@Tag[(][[:space:]]*\"${id}\"[[:space:]]*[)]" "${PRACTICE_FILES[@]}" || missing+=("$id")
  done
  local problems=()
  (( count >= min_cases )) || problems+=("${count} manual cases, expected at least ${min_cases}")
  (( ${#missing[@]} == 0 )) || problems+=("no @Tag test for $(printf '%s ' "${missing[@]}")")
  (( ${#problems[@]} == 0 )) && return 0
  PRACTICE_DETAIL="$(printf '%s; ' "${problems[@]}")"
  PRACTICE_DETAIL="${PRACTICE_DETAIL%; }"
  return 1
}

# Prints "<ClassName>#<method>" for every test method of the given Java files, sorted.
practice_list_tests() {
  local file saved=("${PRACTICE_FILES[@]}") name
  for file in "$@"; do
    PRACTICE_FILES=("$file")
    name="$(basename "$file" .java)"
    practice__java_tests | cut -f1 | sed "s/^/${name}#/"
  done | sort
  PRACTICE_FILES=("${saved[@]}")
}

# catch blocks with nothing inside (comments do not count). Lines of the form
# file:line, like the other static rules.
practice_no_empty_catch() {
  local file hits=""
  for file in "${PRACTICE_FILES[@]}"; do
    hits+="$(awk -v name="${file##*/}" '
      function strip(s) { gsub(/\/\*.*\*\//, "", s); sub(/\/\/.*$/, "", s); return s }
      {
        code = strip($0)
        if (waiting) {
          if (code ~ /^[[:space:]]*$/) next
          if (code ~ /^[[:space:]]*[}]/) printf "%s:%d\n", name, start
          waiting = 0
        }
        if (code ~ /catch[[:space:]]*([(][^)]*[)])?[[:space:]]*[{][[:space:]]*[}]/) {
          printf "%s:%d\n", name, NR
        } else if (code ~ /catch[[:space:]]*([(][^)]*[)])?[[:space:]]*[{][[:space:]]*$/) {
          waiting = 1; start = NR
        }
      }' "$file")"
    [[ -n "$hits" ]] && hits+=$'\n'
  done
  hits="$(grep -v '^$' <<<"$hits" || true)"
  [[ -z "$hits" ]] && return 0
  practice__set_detail <<<"$hits"
  return 1
}

# Parameter: list (file with "<Class>#<method>" lines, relative to the topic folder).
# Every listed test must still exist in a class of that name.
practice_original_tests_kept() {
  local list missing=() entry
  list="${SCORE_TOPIC_DIR}/$(practice_param '.list')"
  if [[ ! -f "$list" ]]; then
    PRACTICE_DETAIL="list file $(practice_param '.list') not found"
    return 1
  fi
  local actual
  actual="$(practice_list_tests "${PRACTICE_FILES[@]}")"
  while IFS= read -r entry; do
    [[ -z "$entry" || "$entry" == \#* ]] && continue
    grep -qxF -- "$entry" <<<"$actual" || missing+=("$entry")
  done <"$list"
  (( ${#missing[@]} == 0 )) && return 0
  PRACTICE_DETAIL="missing: $(printf '%s, ' "${missing[@]:0:4}")"
  PRACTICE_DETAIL="${PRACTICE_DETAIL%, }"
  (( ${#missing[@]} > 4 )) && PRACTICE_DETAIL+=" and $(( ${#missing[@]} - 4 )) more"
  return 1
}

# --- Track C (Playwright) ----------------------------------------------------

practice_no_wait_for_timeout() {
  local hits
  hits="$(practice__grep 'waitForTimeout[[:space:]]*[(]')"
  [[ -z "$hits" ]] && return 0
  practice__set_detail <<<"$hits"
  return 1
}

practice_no_test_only() {
  local hits
  hits="$(practice__grep '(test|describe)[.](only|skip|fixme)[[:space:]]*[(]')"
  [[ -z "$hits" ]] && return 0
  practice__set_detail <<<"$hits"
  return 1
}

# CSS or XPath selectors are only allowed for data-testid.
practice_accessible_locators() {
  local hits
  hits="$(practice__grep '[.]locator[[:space:]]*[(][[:space:]]*[^)[:space:]]' \
    | while IFS=: read -r name line; do
        local file
        for file in "${PRACTICE_FILES[@]}"; do
          [[ "${file##*/}" == "$name" ]] || continue
          sed -n "${line}p" "$file" | grep -qE 'locator[[:space:]]*[(][[:space:]]*.[[]data-testid' || echo "${name}:${line}"
        done
      done)"
  # page.$(...) / page.$$(...) / $eval: raw CSS selectors. [$] avoids backslashes (awk -v eats them).
  hits+="$(practice__grep '[.][$][$]?(eval)?[[:space:]]*[(]|xpath=|[(][[:space:]]*.//')"
  [[ -z "$hits" ]] && return 0
  practice__set_detail <<<"$hits"
  return 1
}

practice_no_hardcoded_base_url() {
  local hits
  hits="$(practice__grep 'https?://(localhost|127[.]0[.]0[.]1)|:4200([^0-9]|$)|:8080([^0-9]|$)')"
  [[ -z "$hits" ]] && return 0
  practice__set_detail <<<"$hits"
  return 1
}

# Spec files talk to page objects; only page objects touch page.getBy*/locator.
practice_page_objects() {
  local file hits=""
  for file in "${PRACTICE_FILES[@]}"; do
    [[ "$file" == *.spec.ts ]] || continue
    hits+="$(awk -v name="${file##*/}" '
      /^[[:space:]]*(\/\/|\*|\/\*)/ { next }
      /page[.](getBy[A-Za-z]+|locator)[[:space:]]*[(]/ { printf "%s:%d\n", name, NR }' "$file")"
  done
  [[ -z "$hits" ]] && return 0
  practice__set_detail <<<"$hits"
  return 1
}

# Test data is prepared through the API (Playwright's request fixture).
practice_api_data_setup() {
  [[ -n "$(practice__grep 'request[.]post[[:space:]]*[(]')" ]] && return 0
  PRACTICE_DETAIL="no request.post(...) in the topic folder"
  return 1
}

practice_stable_without_retries() {
  local attempt
  for attempt in 1 2; do
    score_progress "running the suite again without retries (${attempt}/2)"
    if ! runner_run; then
      PRACTICE_DETAIL="failed on extra run ${attempt} without retries"
      return 1
    fi
  done
  return 0
}

# --- Runtime rules -----------------------------------------------------------

practice_random_order_stable() {
  local seed
  for seed in "${PRACTICE_SEEDS[@]}"; do
    score_progress "random-order run (seed ${seed})"
    # shellcheck disable=SC2016 # "$Random" is a Java nested class name, not a variable.
    if ! runner_run \
      -Dsurefire.runOrder=random "-Dsurefire.runOrder.random.seed=${seed}" \
      '-Djunit.jupiter.testmethod.order.default=org.junit.jupiter.api.MethodOrderer$Random' \
      '-Djunit.jupiter.testclass.order.default=org.junit.jupiter.api.ClassOrderer$Random' \
      "-Djunit.jupiter.execution.order.random.seed=${seed}"; then
      PRACTICE_DETAIL="failed with random order seed ${seed}"
      return 1
    fi
  done
  return 0
}

practice_idempotent_data() {
  score_progress "running the suite again on the same environment"
  runner_run && return 0
  # shellcheck disable=SC2034 # read by standard.sh
  PRACTICE_DETAIL="second run on the same environment failed"
  return 1
}
