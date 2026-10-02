# shellcheck shell=bash
# -----------------------------------------------------------------------------
# Mutation testing restricted to the topic's target classes.
#
#   mutation_run <kind> <target-classes> <target-tests>
#
# Prints "<killed> <total>" on success. Target lists are comma-separated
# (e.g. "dev.orderflow.domain.*"). PIT is deterministic for the same code, so
# the same commit always gets the same score.
#
# Backend (PIT) is supported; the frontend (Stryker) runner comes with topic
# A-04 (phase 4).
# -----------------------------------------------------------------------------

MUTATION_LOG=""

mutation_run() {
  local kind="$1" target_classes="$2" target_tests="$3"
  case "$kind" in
    backend) mutation__pit "$target_classes" "$target_tests" ;;
    *) score_fatal "mutation testing is not available for kind '${kind}' yet" \
         "Remove 'mutation' from topic.yml or set weights.mutation to 0." ;;
  esac
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
