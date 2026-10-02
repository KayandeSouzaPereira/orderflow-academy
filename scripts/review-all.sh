#!/usr/bin/env bash
# Reviews every topic and prints a summary table.
#
#   ./scripts/review-all.sh [--quick] [--include-example]
#
# Each topic's full report is printed as it runs; the table at the end has one
# line per topic. JSON results go to results/. Exit code: 0 when every topic
# passed, 1 otherwise, 3 when a review hit an environment error.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/score.sh
source "${ROOT}/scripts/lib/score.sh"

QUICK=()
INCLUDE_EXAMPLE=0
for arg in "$@"; do
  case "$arg" in
    --quick) QUICK=(--quick) ;;
    --include-example) INCLUDE_EXAMPLE=1 ;;
    -h | --help) sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) score_fatal "unknown option '${arg}'" "Options: --quick, --include-example." ;;
  esac
done

command -v jq >/dev/null || score_fatal "required tool 'jq' not found" "Install jq 1.6+."

mapfile -t TOPICS < <(find "${ROOT}/tracks" -name topic.yml -not -path '*/bugs/*' \
  | sed -e "s#^${ROOT}/tracks/##" -e 's#/topic.yml$##' | sort)
if (( INCLUDE_EXAMPLE == 0 )); then
  mapfile -t TOPICS < <(printf '%s\n' "${TOPICS[@]}" | grep -v '^_' || true)
fi
(( ${#TOPICS[@]} > 0 )) || score_fatal "no topics found under tracks/" "Pull the latest main."

RESULTS_DIR="${SCORE_RESULTS_DIR:-${ROOT}/results}"
export SCORE_RESULTS_DIR="$RESULTS_DIR"
declare -A EXIT_CODES=()
for topic in "${TOPICS[@]}"; do
  printf '\n'
  code=0
  "${ROOT}/scripts/review.sh" "$topic" --json "${QUICK[@]}" || code=$?
  EXIT_CODES["$topic"]=$code
done

printf '\n══ Summary ══\n\n'
printf '%-45s %-9s %-9s %s\n' "Topic" "Score" "Status" "Missed bugs"
overall=0
for topic in "${TOPICS[@]}"; do
  code="${EXIT_CODES[$topic]}"
  file="${RESULTS_DIR}/$(printf '%s' "$topic" | tr '/' '-').json"
  if (( code == 3 )) || [[ ! -f "$file" ]]; then
    printf '%-45s %-9s %-9s %s\n' "$topic" "-" "ERROR" "environment or configuration error"
    overall=3
    continue
  fi
  read -r score max status missed < <(jq -r '[.score, .max, .status,
      ((.missedBugs | map(.id) | join(",")) | if . == "" then "-" else . end)] | @tsv' "$file")
  case "$status" in
    passed) label="PASSED" ;;
    gate-failed) label="GATE" ;;
    *) label="FAILED" ;;
  esac
  printf '%-45s %-9s %-9s %s\n' "$topic" "${score}/${max}" "$label" "$missed"
  if [[ "$label" != "PASSED" ]] && (( overall == 0 )); then overall=1; fi
done
exit "$overall"
