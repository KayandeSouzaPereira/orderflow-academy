# shellcheck shell=bash
# -----------------------------------------------------------------------------
# The standard review used by topics of kind backend and api:
#
#   1. pre-checks             tools, Java, Docker           (exit 3 on failure)
#   2. isolated workspace     copy of app/ in a temp dir
#   3. required practices     e.g. black-box-only           (exit 2 on failure)
#      then the stack, for topics with requires_stack: true
#   4. gate                   topic tests pass on the real code (exit 2 on failure)
#   5. practices              static and runtime rules from topic.yml
#   6. bug bank               one run per planted bug
#   7. mutation testing       PIT on the target classes (skipped with --quick)
#
# A topic's review.sh only does:
#   source "<repo>/scripts/lib/standard.sh"
#   review_standard "<topic-dir>" "$@"
#
# Options: --quick (no mutation testing), --json (write results/*.json),
#          --overlay <dir> (copy <dir>/app over the workspace; used to check
#          reference and calibration solutions).
# -----------------------------------------------------------------------------

STANDARD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=score.sh
source "${STANDARD_LIB_DIR}/score.sh"
# shellcheck source=common.sh
source "${STANDARD_LIB_DIR}/common.sh"
# shellcheck source=runner.sh
source "${STANDARD_LIB_DIR}/runner.sh"
# shellcheck source=bugbank.sh
source "${STANDARD_LIB_DIR}/bugbank.sh"
# shellcheck source=mutation.sh
source "${STANDARD_LIB_DIR}/mutation.sh"
# shellcheck source=practices.sh
source "${STANDARD_LIB_DIR}/practices.sh"
# shellcheck source=stack.sh
source "${STANDARD_LIB_DIR}/stack.sh"

STANDARD_QUICK=0
STANDARD_OVERLAY=""
TOPIC_JSON=""

# Reads a jq expression from topic.yml (converted to JSON once).
topic() {
  jq -r "$1 // empty" <<<"$TOPIC_JSON"
}

standard__parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --quick) STANDARD_QUICK=1 ;;
      --json) export SCORE_JSON=1 ;;
      --overlay)
        [[ -n "${2:-}" ]] || score_fatal "--overlay needs a directory" "Usage: --overlay <dir>"
        STANDARD_OVERLAY="$(cd "$2" 2>/dev/null && pwd)" || score_fatal "overlay '$2' not found" "Pass an existing directory."
        shift ;;
      *) score_fatal "unknown option '$1'" "Options: --quick, --json, --overlay <dir>." ;;
    esac
    shift
  done
}

review_standard() {
  local topic_dir="$1"; shift
  review_require_bash
  review_require_tools jq yq git tar
  standard__parse_args "$@"
  review_install_traps

  TOPIC_JSON="$(yq -o json '.' "${topic_dir}/topic.yml" 2>/dev/null)" \
    || score_fatal "cannot read ${topic_dir}/topic.yml" "Check the YAML syntax."
  score_begin "$topic_dir"

  local kind
  kind="$(topic '.kind')"
  standard__prechecks "$kind"

  review_workspace_create
  [[ -n "$STANDARD_OVERLAY" ]] && review_workspace_overlay "$STANDARD_OVERLAY"

  local -a specs=()
  mapfile -t specs < <(topic '(.test_files // ([.test_dir] | map(select(. != null))))[]')
  runner_init "$kind" "$(topic '.test_package')" "${specs[@]}"
  [[ "$kind" == "frontend" ]] && runner_frontend_dependencies
  [[ "$kind" == "e2e" ]] && runner_e2e_dependencies
  RUNNER_TIMEOUT="$(topic '.timeouts.test_run_seconds')"
  RUNNER_TIMEOUT="${RUNNER_TIMEOUT:-300}"
  mapfile -t PRACTICE_FILES < <(runner_test_files)
  local assertions
  assertions="$(topic '.assertion_patterns // [] | join("|")')"
  [[ -n "$assertions" ]] && PRACTICE_ASSERTIONS="$assertions"

  # Static prerequisites first: they fail in seconds, before any stack starts.
  standard__require_test_files
  standard__required_practices

  if [[ "$(topic '.requires_stack')" == "true" ]]; then
    STACK_PROCESSOR_DELAY_MS="$(topic '.stack.processor_delay_ms')"
    STACK_PROCESSOR_DELAY_MS="${STACK_PROCESSOR_DELAY_MS:-3000}"
    stack_up
  fi

  standard__gate

  # Runtime practices need the original code, so they run before the bug bank.
  standard__evaluate_practices
  standard__swap_in_reference "$topic_dir"
  standard__bug_bank "$topic_dir"
  standard__swap_back
  standard__mutation

  standard__report
  score_end
}

standard__prechecks() {
  local kind="$1"
  case "$kind" in
    backend | api) review_require_java ;;
    frontend | e2e) review_require_tools node ;;
    *) score_fatal "topic kind '${kind}' cannot use the standard review" \
         "Use kind backend, api or frontend, or write a custom review.sh with the score.sh API." ;;
  esac
  if [[ "$(topic '.requires_stack')" == "true" || "$(topic '.requires_docker')" == "true" ]]; then
    review_require_docker
  fi
}

# --- Practices ---------------------------------------------------------------

# Rules as TSV lines: rule, weight, required, the rule's JSON (parameters).
standard__practice_rules() {
  jq -r '(.practices // [])[]
    | if type == "string" then {rule: .} else . end
    | [.rule, (.weight // 1), (.required // false), tojson] | @tsv' <<<"$TOPIC_JSON"
}

standard__required_practices() {
  local rule weight required
  while IFS=$'\t' read -r rule weight required PRACTICE_RULE_JSON; do
    [[ -n "$rule" ]] || continue
    # black-box-only is always a prerequisite.
    [[ "$required" == "true" || "$rule" == "black-box-only" ]] || continue
    practice_known "$rule" || score_fatal "unknown practice rule '${rule}' in topic.yml" "See scripts/lib/practices.sh."
    if ! practice_run "$rule"; then
      score_hint "$rule" "$(practice_hint "$rule")" "${PRACTICE_DETAIL}"
      score_gate false "required practice '${rule}' failed"
    fi
  done < <(standard__practice_rules)
}

standard__require_test_files() {
  (( ${#PRACTICE_FILES[@]} > 0 )) && return 0
  local where
  where="$(topic '.test_package // .test_dir // (.test_files // [] | join(", "))')"
  score_hint "no-tests" "Write your tests in ${where} (see the topic README)."
  score_gate false "no test files in ${where}"
}

standard__gate() {
  score_progress "running your tests against the real code"
  local status=0
  runner_run || status=$?
  case "$status" in
    0)
      if (( RUNNER_TESTS == 0 )); then
        score_hint "no-tests" "Add at least one @Test method in $(topic '.test_package')."
        score_gate false "no tests ran"
      fi
      score_gate true "${RUNNER_TESTS} tests passing" ;;
    1)
      score_hint "gate" "Your tests must pass against the correct code before bugs are planted. Failing:
$(runner_failure_summary)"
      score_gate false "$RUNNER_FAILED of $RUNNER_TESTS tests failing" ;;
    2) score_gate false "the application does not compile (did you change app code?)" ;;
    3)
      score_hint "gate" "Fix the compilation errors:
$(runner_failure_summary)"
      score_gate false "tests do not compile" ;;
    124) score_gate false "tests timed out after ${RUNNER_TIMEOUT}s" ;;
  esac
}

STANDARD_PRACTICES_PASSED=0
STANDARD_PRACTICES_TOTAL=0
STANDARD_PRACTICES_WEIGHT_PASSED=0
STANDARD_PRACTICES_WEIGHT_TOTAL=0

standard__evaluate_practices() {
  local rule weight required
  while IFS=$'\t' read -r rule weight required PRACTICE_RULE_JSON; do
    [[ -n "$rule" ]] || continue
    [[ "$required" == "true" || "$rule" == "black-box-only" ]] && continue
    practice_known "$rule" || score_fatal "unknown practice rule '${rule}' in topic.yml" "See scripts/lib/practices.sh."
    # An overlay (reference/calibration solution) has no Git history to judge.
    [[ -n "$STANDARD_OVERLAY" ]] && practice_is_history_rule "$rule" && continue
    STANDARD_PRACTICES_TOTAL=$(( STANDARD_PRACTICES_TOTAL + 1 ))
    STANDARD_PRACTICES_WEIGHT_TOTAL=$(( STANDARD_PRACTICES_WEIGHT_TOTAL + weight ))
    if practice_run "$rule"; then
      STANDARD_PRACTICES_PASSED=$(( STANDARD_PRACTICES_PASSED + 1 ))
      STANDARD_PRACTICES_WEIGHT_PASSED=$(( STANDARD_PRACTICES_WEIGHT_PASSED + weight ))
    else
      score_hint "$rule" "$(practice_hint "$rule")" "${PRACTICE_DETAIL:-$(practice_title "$rule")}"
    fi
  done < <(standard__practice_rules)
}

# --- Implementation swap (TDD kata) ------------------------------------------
#
# topic.yml: implementation_swap: { path: <repo-relative file>, reference: <file in the topic dir> }
# The participant writes the implementation. Bugs are planted in a reference
# implementation instead, so the participant's tests must also pass on it.

STANDARD_SWAP_TARGET=""

standard__swap_in_reference() {
  local topic_dir="$1" path reference
  path="$(topic '.implementation_swap.path')"
  [[ -n "$path" ]] || return 0
  reference="${topic_dir}/$(topic '.implementation_swap.reference')"
  [[ -f "$reference" ]] || score_fatal "reference implementation ${reference} not found" \
    "Check implementation_swap in topic.yml."

  STANDARD_SWAP_TARGET="${REVIEW_WORKSPACE}/${path}"
  cp "$STANDARD_SWAP_TARGET" "${REVIEW_WORKSPACE}/.participant-implementation"
  cp "$reference" "$STANDARD_SWAP_TARGET"

  score_progress "running your tests against the reference implementation"
  local status=0
  runner_run || status=$?
  if (( status == 0 )); then
    score_gate true "tests also pass on the reference ${path##*/}"
    return 0
  fi
  score_hint "reference" "Bugs are planted in a reference implementation that follows the README spec. Tests that fail on it check behaviour the spec does not ask for:
$(runner_failure_summary)"
  score_gate false "tests fail on the reference ${path##*/}"
}

standard__swap_back() {
  [[ -n "$STANDARD_SWAP_TARGET" ]] || return 0
  cp "${REVIEW_WORKSPACE}/.participant-implementation" "$STANDARD_SWAP_TARGET"
}

# --- Bug bank ----------------------------------------------------------------

STANDARD_BUGS_VALID=0
STANDARD_BUGS_DETECTED=0

# Bug folders of the topic plus, with topic.yml 'bug_sources', those of other
# topics (B-09 reuses the banks of B-03 to B-07).
standard__bug_dirs() {
  local topic_dir="$1" source
  bugbank_list "$topic_dir"
  while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    [[ -d "${SCORE_REPO_ROOT}/tracks/${source}" ]] || score_fatal "bug source '${source}' not found" \
      "Check bug_sources in topic.yml."
    bugbank_list "${SCORE_REPO_ROOT}/tracks/${source}"
  done < <(topic '(.bug_sources // [])[]')
}

# Bug id shown in the report: BUG-NN, or BUG-<topic id>-NN for borrowed bugs.
standard__bug_id() {
  local topic_dir="$1" bug_dir="$2" owner
  owner="$(cd "${bug_dir}/../.." && pwd)"
  if [[ "$owner" == "$(cd "$topic_dir" && pwd)" ]]; then
    basename "$bug_dir"
  else
    printf 'BUG-%s-%s' "$(yq -r '.id' "${owner}/topic.yml")" "$(basename "$bug_dir" | sed 's/^BUG-//')"
  fi
}

standard__bug_bank() {
  local topic_dir="$1" bug_dir id title hint side status index=0 total
  local -a bugs
  mapfile -t bugs < <(standard__bug_dirs "$topic_dir")
  total=${#bugs[@]}
  for bug_dir in "${bugs[@]}"; do
    index=$(( index + 1 ))
    id="$(standard__bug_id "$topic_dir" "$bug_dir")"
    title="$(bugbank_field "$bug_dir" title)"
    hint="$(bugbank_field "$bug_dir" hint)"
    side="$(bugbank_field "$bug_dir" side)"
    score_progress "bug ${index}/${total}: ${id}"

    if ! bugbank_apply "$bug_dir"; then
      score_warn "${id}: patch.diff does not apply to the current app; bug ignored."
      continue
    fi
    if [[ "$(topic '.requires_stack')" == "true" ]] && ! stack_rebuild "${side:-backend}"; then
      score_warn "${id}: the ${side:-backend} does not build with this bug; bug ignored."
      bugbank_restore
      continue
    fi

    status=0
    runner_run || status=$?
    bugbank_restore

    case "$status" in
      0)
        STANDARD_BUGS_VALID=$(( STANDARD_BUGS_VALID + 1 ))
        score_hint "$id" "$hint" "$title" ;;
      1 | 124)
        STANDARD_BUGS_VALID=$(( STANDARD_BUGS_VALID + 1 ))
        STANDARD_BUGS_DETECTED=$(( STANDARD_BUGS_DETECTED + 1 )) ;;
      *)
        score_warn "${id}: the app does not compile with this bug; bug ignored." ;;
    esac
  done
}

# --- Mutation ----------------------------------------------------------------

STANDARD_MUTATION=""   # "<killed> <total>" or empty

standard__mutation() {
  (( $(standard__weight mutation) > 0 )) || return 0
  (( STANDARD_QUICK == 0 )) || return 0
  local classes tests
  classes="$(topic '.mutation.target_classes // [] | join(",")')"
  tests="$(topic '.mutation.target_tests // [] | join(",")')"
  if [[ -z "$tests" ]]; then
    if [[ "$(topic '.kind')" == "frontend" ]]; then
      tests="$(topic '.test_files // [] | join(",")')"
    else
      tests="$(topic '.test_package').*"
    fi
  fi
  [[ -n "$classes" ]] || score_fatal "topic.yml has a mutation weight but no mutation.target_classes" \
    "Add mutation: { target_classes: [\"dev.orderflow.domain.*\"] }."
  score_progress "mutation testing on ${classes} (this is the slow part; use --quick to skip)"
  STANDARD_MUTATION="$(mutation_run "$(topic '.kind')" "$classes" "$tests")" || {
    score_warn "mutation testing failed to run (see ${MUTATION_LOG}); counted as 0%."
    STANDARD_MUTATION="0 0"
  }
}

# --- Report ------------------------------------------------------------------

# Weight of a criterion: topic.yml weights, or the defaults for the kind.
standard__weight() {
  local name="$1" value kind
  value="$(topic ".weights.${name}")"
  if [[ -z "$value" ]]; then
    kind="$(topic '.kind')"
    case "${kind}:${name}" in
      backend:bugs | frontend:bugs) value=50 ;;
      backend:mutation | frontend:mutation) value=25 ;;
      backend:practices | frontend:practices) value=25 ;;
      api:bugs | e2e:bugs) value=70 ;;
      api:practices | e2e:practices) value=30 ;;
      *) value=0 ;;
    esac
  fi
  echo "$value"
}

standard__report() {
  local weight earned

  weight="$(standard__weight bugs)"
  if (( weight > 0 )); then
    if (( STANDARD_BUGS_VALID == 0 )); then
      score_warn "no valid bugs in the bug bank; the bug criterion was not scored."
      score_skip "Bug bank" "no valid bugs"
    else
      earned="$(review_round_ratio "$weight" "$STANDARD_BUGS_DETECTED" "$STANDARD_BUGS_VALID")"
      score_criterion "Bug bank" "$earned" "$weight" "${STANDARD_BUGS_DETECTED}/${STANDARD_BUGS_VALID}"
    fi
  fi

  weight="$(standard__weight mutation)"
  if (( weight > 0 )); then
    if (( STANDARD_QUICK == 1 )); then
      score_skip "Mutation score" "--quick"
    else
      local killed total percent target status
      read -r killed total <<<"$STANDARD_MUTATION"
      percent="$(review_round_ratio 100 "$killed" "$total")"
      target="$(topic '.mutation.target_score')"
      target="${target:-80}"
      if (( percent >= target )); then
        earned="$weight" status=ok
      else
        earned="$(review_round_ratio "$weight" "$percent" "$target")" status=fail
      fi
      score_criterion "Mutation score (${percent}%, target ${target}%)" "$earned" "$weight" "" "$status"
    fi
  fi

  weight="$(standard__weight practices)"
  if (( weight > 0 && STANDARD_PRACTICES_TOTAL > 0 )); then
    earned="$(review_round_ratio "$weight" "$STANDARD_PRACTICES_WEIGHT_PASSED" "$STANDARD_PRACTICES_WEIGHT_TOTAL")"
    score_criterion "Practices" "$earned" "$weight" "${STANDARD_PRACTICES_PASSED}/${STANDARD_PRACTICES_TOTAL}"
  fi
}
