#!/usr/bin/env bash
# Maintainer helper for the pilot (phase 8): runs the full official review of
# every topic with its reference solution, timing each one against the limits
# of the SDD, and writes a CSV and a Markdown report.
#
#   ./scripts/dev/pilot.sh --solutions <dir> [--out <dir>] [<topic>...]
#   ./scripts/dev/pilot.sh --checklist          # Markdown checklist of every topic
#
# --solutions  the private repository's solutions/ folder (reference/ of each topic)
# --out        where the reports go (default: pilot-results/ in the repository, git-ignored)
# <topic>...   only these topics (default: all, in track order)
#
# Limits (full review, no --quick): 10 minutes; 15 for tracks B and C; 25 for
# the bonus challenge (not covered by the SDD limit, it is a live session).
# Exit code: 0 when every topic passed and stayed within its limit, 1 otherwise.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/score.sh
source "${ROOT}/scripts/lib/score.sh"

SOLUTIONS=""
OUT="${ROOT}/pilot-results"
CHECKLIST=0
TOPICS=()
while (( $# > 0 )); do
  case "$1" in
    --solutions) SOLUTIONS="$(cd "${2:?--solutions needs a directory}" && pwd)"; shift ;;
    --out) OUT="${2:?--out needs a directory}"; shift ;;
    --checklist) CHECKLIST=1 ;;
    -h | --help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) TOPICS+=("${1#tracks/}") ;;
  esac
  shift
done

all_topics() {
  find "${ROOT}/tracks" -name topic.yml -not -path '*/bugs/*' \
    | sed -e "s#^${ROOT}/tracks/##" -e 's#/topic.yml$##' | grep -v '^_' | sort
}

limit_minutes() {
  case "$1" in
    b-* | c-*) echo 15 ;;
    bonus-*) echo 25 ;;
    *) echo 10 ;;
  esac
}

if (( CHECKLIST == 1 )); then
  printf '| Topic | Review time ok | Hints read and clear | README clear | Notes |\n| --- | --- | --- | --- | --- |\n'
  while IFS= read -r topic; do
    printf '| %s | [ ] | [ ] | [ ] | |\n' "$topic"
  done < <(all_topics)
  exit 0
fi

[[ -n "$SOLUTIONS" ]] || score_fatal "--solutions is required" "Pass the solutions/ folder of orderflow-academy-private."
(( ${#TOPICS[@]} > 0 )) || mapfile -t TOPICS < <(all_topics)

mkdir -p "$OUT"
STAMP="$(date +%Y%m%d-%H%M)"
CSV="${OUT}/pilot-${STAMP}.csv"
REPORT="${OUT}/pilot-${STAMP}.md"
JSON_DIR="${OUT}/json-${STAMP}"
mkdir -p "$JSON_DIR"
printf 'topic,score,max,status,minutes,limit_minutes,within_limit,missed_bugs\n' >"$CSV"

failed=0
for topic in "${TOPICS[@]}"; do
  overlay="${SOLUTIONS}/${topic}/reference"
  if [[ ! -d "$overlay" ]]; then
    printf 'pilot: no reference solution for %s, skipped\n' "$topic" >&2
    continue
  fi
  printf '\n▶ %s\n' "$topic"
  start="$(date +%s)"
  code=0
  SCORE_RESULTS_DIR="$JSON_DIR" SCORE_QUIET_PROGRESS=1 "${ROOT}/scripts/review.sh" "$topic" --json --overlay "$overlay" \
    >"${JSON_DIR}/$(printf '%s' "$topic" | tr '/' '-').log" 2>&1 || code=$?
  seconds=$(( $(date +%s) - start ))
  minutes=$(( (seconds + 59) / 60 ))
  limit="$(limit_minutes "$topic")"
  json="${JSON_DIR}/$(printf '%s' "$topic" | tr '/' '-').json"

  if [[ -f "$json" ]]; then
    row="$(jq -r '[.score, .max, .status, ((.missedBugs | map(.id) | join(" ")) | if . == "" then "-" else . end)] | @csv' "$json")"
  else
    row='"","","error (exit '"$code"')","-"'
  fi
  within=yes
  (( minutes <= limit )) || within=no
  IFS=',' read -r score max status missed <<<"$row"
  printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$topic" "$score" "$max" "${status//\"/}" "$minutes" "$limit" "$within" "${missed//\"/}" >>"$CSV"
  printf '  score %s/%s, %s min (limit %s), %s\n' "$score" "$max" "$minutes" "$limit" "${status//\"/}"
  if [[ "${status//\"/}" != "passed" || "$within" == "no" ]]; then failed=1; fi
done

{
  printf '# Pilot %s\n\n' "$STAMP"
  printf '| Topic | Score | Status | Minutes | Limit | Within limit | Missed bugs |\n| --- | --- | --- | --- | --- | --- | --- |\n'
  tail -n +2 "$CSV" | while IFS=',' read -r topic score max status minutes limit within missed; do
    printf '| %s | %s/%s | %s | %s | %s | %s | %s |\n' "$topic" "$score" "$max" "$status" "$minutes" "$limit" "$within" "$missed"
  done
  printf '\n## Reading checklist\n\nFill in while reading each topic as a participant would (README first, hints only after a failed review).\n\n'
  "${BASH_SOURCE[0]}" --checklist
} >"$REPORT"

printf '\nReport: %s\nCSV:    %s\n' "$REPORT" "$CSV"
exit "$failed"
