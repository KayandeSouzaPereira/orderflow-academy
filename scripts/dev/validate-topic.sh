#!/usr/bin/env bash
# Maintainer/CI check of one topic's bug bank against its solutions.
#
#   ./scripts/dev/validate-topic.sh <track>/<topic> [--solutions <dir>]
#
# Solutions are looked up in <dir>/<track>/<topic>/ (the private repository's
# solutions/ folder) and then in tracks/<track>/<topic>/ (public example):
#
#   reference/          must detect 100% of the bugs, score >= 90, no warnings
#   calibration-weak/   optional; must score below the pass threshold
#
# It also checks that, without any test, the review stops at the gate (exit 2).
# Exit code: 0 when the topic is valid, 1 otherwise, 3 on setup errors.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# score.sh also makes jq/yq output plain LF on Windows.
# shellcheck source=../lib/score.sh
source "${ROOT}/scripts/lib/score.sh"
MIN_REFERENCE_SCORE=90

die() {
  printf 'validate-topic: %s\n' "$1" >&2
  exit 3
}

(( $# >= 1 )) || die "usage: ./scripts/dev/validate-topic.sh <track>/<topic> [--solutions <dir>]"
TOPIC="${1#tracks/}"
TOPIC="${TOPIC%/}"
shift
SOLUTIONS=""
while (( $# > 0 )); do
  case "$1" in
    --solutions) SOLUTIONS="${2:?--solutions needs a directory}"; shift ;;
    *) die "unknown option '$1'" ;;
  esac
  shift
done
[[ -f "${ROOT}/tracks/${TOPIC}/topic.yml" ]] || die "unknown topic '${TOPIC}'"

find_solution() {
  local name="$1" candidate
  for candidate in ${SOLUTIONS:+"${SOLUTIONS}/${TOPIC}/${name}"} "${ROOT}/tracks/${TOPIC}/${name}"; do
    [[ -d "$candidate" ]] && { (cd "$candidate" && pwd); return 0; }
  done
  return 1
}

RESULTS="$(mktemp -d "${TMPDIR:-/tmp}/orderflow-validate.XXXXXX")"
trap 'rm -rf "$RESULTS"' EXIT
export SCORE_RESULTS_DIR="$RESULTS" SCORE_QUIET_PROGRESS=1
RESULT_FILE="${RESULTS}/$(printf '%s' "$TOPIC" | tr '/' '-').json"
FAILURES=()

fail() {
  FAILURES+=("$1")
  printf '  ✘ %s\n' "$1"
}

ok() {
  printf '  ✔ %s\n' "$1"
}

# run_review <label> [review options...]: runs the review, keeps its output.
run_review() {
  local label="$1"; shift
  local code=0
  printf '\n── %s ──\n' "$label"
  rm -f "$RESULT_FILE"
  "${ROOT}/scripts/review.sh" "$TOPIC" --json "$@" || code=$?
  LAST_EXIT=$code
}

printf '══ Validating %s ══\n' "$TOPIC"

# 1. No tests: the gate must stop the review. Topics whose work is not files
#    (B-02 reads Git history) provide an 'empty' solution for this case.
if EMPTY="$(find_solution empty)"; then
  run_review "without tests (expect gate, exit 2)" --overlay "$EMPTY"
else
  run_review "without tests (expect gate, exit 2)"
fi
if (( LAST_EXIT == 2 )); then ok "no tests: gate failed with exit 2"; else fail "no tests: expected exit 2, got ${LAST_EXIT}"; fi

# 2. Reference solution: every bug detected, score >= 90, no warnings.
if REFERENCE="$(find_solution reference)"; then
  run_review "reference solution" --overlay "$REFERENCE"
  if (( LAST_EXIT == 3 )) || [[ ! -f "$RESULT_FILE" ]]; then
    fail "reference: review did not run (exit ${LAST_EXIT})"
  else
    read -r score missed warnings detail < <(jq -r '[.score,
        (.missedBugs | map(.id) | join(",") | if . == "" then "-" else . end),
        (.warnings | length),
        ((.criteria[] | select(.name == "Bug bank") | .detail) // "-")] | @tsv' "$RESULT_FILE")
    if [[ "$missed" == "-" ]]; then ok "reference detects every bug (${detail})"; else fail "reference misses ${missed}"; fi
    if (( score >= MIN_REFERENCE_SCORE )); then ok "reference scores ${score}"; else fail "reference scores ${score}, below ${MIN_REFERENCE_SCORE}"; fi
    if (( warnings == 0 )); then
      ok "no warnings (every patch applies and compiles)"
    else
      fail "warnings: $(jq -r '.warnings | join(" | ")' "$RESULT_FILE")"
    fi
  fi
else
  fail "no reference solution (looked in ${SOLUTIONS:-<none>}/${TOPIC}/reference and tracks/${TOPIC}/reference)"
fi

# 3. Weak calibration solution (happy path only): must not pass.
if WEAK="$(find_solution calibration-weak)"; then
  run_review "weak calibration solution" --overlay "$WEAK"
  if [[ -f "$RESULT_FILE" ]]; then
    read -r score threshold < <(jq -r '[.score, .threshold] | @tsv' "$RESULT_FILE")
    if (( score < threshold )); then ok "weak calibration scores ${score} (< ${threshold})"; else fail "weak calibration scores ${score}, should be below ${threshold}"; fi
  else
    fail "weak calibration: review did not run (exit ${LAST_EXIT})"
  fi
else
  printf '\n  – no calibration-weak solution (optional)\n'
fi

printf '\n'
if (( ${#FAILURES[@]} > 0 )); then
  printf '%s: INVALID (%d problem(s))\n' "$TOPIC" "${#FAILURES[@]}"
  exit 1
fi
printf '%s: VALID\n' "$TOPIC"
