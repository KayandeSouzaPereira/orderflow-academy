# shellcheck shell=bash
# -----------------------------------------------------------------------------
# Mutation testing restricted to the topic's target classes.
#
#   mutation_run <kind> <target-classes> <target-tests>
#
# Prints "<killed> <total>" on success. Target lists are comma-separated.
#
#   backend   PIT; targets are classes ("dev.orderflow.domain.*"), tests are
#             test classes. Deterministic for the same code.
#   frontend  Stryker (app/frontend/stryker.config.json); targets are source
#             files, tests are spec files. Stryker runs Vitest once per mutant
#             through its 'command' runner (its Vitest runner cannot activate
#             mutants when the Analog Angular plugin compiles the code).
# -----------------------------------------------------------------------------

MUTATION_LOG=""

mutation_run() {
  local kind="$1" target_classes="$2" target_tests="$3"
  case "$kind" in
    backend) mutation__pit "$target_classes" "$target_tests" ;;
    frontend) mutation__stryker "$target_classes" "$target_tests" ;;
    *) score_fatal "mutation testing is not available for kind '${kind}'" \
         "Remove 'mutation' from topic.yml or set weights.mutation to 0." ;;
  esac
}

mutation__stryker_run() {
  local module="$1" targets="$2" tests="$3"
  (cd "$module" && STRYKER_TEST_FILES="$tests" node node_modules/@stryker-mutator/core/bin/stryker.js run \
    --mutate "$targets" --concurrency "${MUTATION_THREADS:-4}")
}

mutation__stryker() {
  local targets="$1" tests="$2"
  local module="${REVIEW_WORKSPACE}/app/frontend"
  local report="${module}/reports/mutation/mutation.json"
  MUTATION_LOG="${REVIEW_WORKSPACE}/mutation.log"
  rm -rf "${module}/reports/mutation"

  if ! run_with_timeout "${MUTATION_TIMEOUT:-900}" mutation__stryker_run "$module" "$targets" "$tests" \
    >"$MUTATION_LOG" 2>&1; then
    return 1
  fi
  [[ -f "$report" ]] || return 1

  # Killed and timed-out mutants count as detected; ignored or invalid ones are left out.
  jq -r '[.files[].mutants[] | .status] as $all
    | ($all | map(select(. == "Killed" or . == "Timeout")) | length) as $killed
    | ($all | map(select(. == "Killed" or . == "Timeout" or . == "Survived" or . == "NoCoverage")) | length) as $total
    | "\($killed) \($total)"' "$report"
}

mutation__pit_maven() {
  local module="$1"; shift
  (cd "$module" && ./mvnw -B -ntp -q test-compile org.pitest:pitest-maven:mutationCoverage "$@")
}

mutation__pit() {
  local target_classes="$1" target_tests="$2"
  local module="${REVIEW_WORKSPACE}/app/backend"
  local report="${module}/target/pit-reports/mutations.xml"
  MUTATION_LOG="${REVIEW_WORKSPACE}/mutation.log"
  rm -rf "${module}/target/pit-reports"

  if ! run_with_timeout "${MUTATION_TIMEOUT:-600}" mutation__pit_maven "$module" \
    "-DtargetClasses=${target_classes}" \
    "-DtargetTests=${target_tests}" \
    -Dthreads="${MUTATION_THREADS:-2}" \
    -DfailWhenNoMutations=false \
    -DtimestampedReports=false >"$MUTATION_LOG" 2>&1; then
    return 1
  fi
  [[ -f "$report" ]] || return 1

  yq -p xml -o json '.' "$report" | jq -r '
    (.mutations.mutation // []) | (if type == "array" then . else [.] end)
    | "\(map(select(.["+@detected"] == "true")) | length) \(length)"'
}
