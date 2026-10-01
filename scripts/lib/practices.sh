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
# -----------------------------------------------------------------------------

PRACTICE_FILES=()
PRACTICE_DETAIL=""
# EREs below avoid backslashes ([(] instead of \(): awk -v would eat them.
PRACTICE_ASSERTIONS='assertThat|assert[A-Z][A-Za-z]*[[:space:]]*[(]|verify[A-Za-z]*[[:space:]]*[(]|[.]statusCode[[:space:]]*[(]|[.]body[[:space:]]*[(]|expect[[:space:]]*[(]'
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
    *) echo "$1" ;;
  esac
}

practice_hint() {
  case "$1" in
    no-thread-sleep) echo "Wait for a condition, not for time: await().atMost(...).untilAsserted(...) (Awaitility)." ;;
    no-disabled-tests) echo "Remove @Disabled/@Ignore: a skipped test protects nothing. Fix it or delete it." ;;
    every-test-asserts) echo "A test without an assertion only checks that nothing throws. Assert the result you expect." ;;
    no-hardcoded-endpoints) echo "Read hosts and ports from configuration (TestApi, @ConfigProperty, injected clients), never from literals." ;;
    naming-convention) echo "Rename tests to should<Result>When<Condition>, e.g. shouldReturn409WhenStockIsInsufficient." ;;
    random-order-stable) echo "A test relies on state left by another one. Give each test its own data and no shared mutable fields." ;;
    idempotent-data) echo "Running the suite again fails. Create unique data per run (new products, random e-mails) instead of fixed ids." ;;
    black-box-only) echo "Talk to the system only through HTTP: no backend classes, no AWS SDK, no direct database checks." ;;
    *) echo "See the topic README." ;;
  esac
}

practice_known() {
  declare -F "practice_${1//-/_}" >/dev/null
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
  missing="$(practice__java_tests | awk -F'\t' '$2 == 0 { print $1 }')"
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
