#!/usr/bin/env bash
# Builds the Job Summary of an official review from the JSON results.
#
#   ./scripts/ci/summary.sh <results-dir> [<branch> <commit>] > summary.md
#
# Exit code: 0 when every topic passed (or none ran), 1 otherwise.
set -euo pipefail

DIR="${1:?usage: summary.sh <results-dir> [<branch> <commit>]}"
BRANCH="${2:-}"
COMMIT="${3:-}"
command -v jq >/dev/null || { echo "summary: jq not found" >&2; exit 3; }

mapfile -t FILES < <(find "$DIR" -name '*.json' 2>/dev/null | sort)

TICK='`'
printf '## Official review'
[[ -n "$BRANCH" ]] && printf ': %s%s%s' "$TICK" "$BRANCH" "$TICK"
[[ -n "$COMMIT" ]] && printf ' @ %s%s%s' "$TICK" "${COMMIT:0:7}" "$TICK"
printf '\n\n'

if (( ${#FILES[@]} == 0 )); then
  printf 'No topic had to be reviewed for this push.\n'
  exit 0
fi

printf '| Topic | Score | Status | Missed bugs |\n| --- | --- | --- | --- |\n'
failed=0
for file in "${FILES[@]}"; do
  row="$(jq -r '[.topic, "\(.score)/\(.max)" + (if .partial then " (partial)" else "" end),
      (if .status == "passed" then "PASSED" elif .status == "gate-failed" then "GATE FAILED" else "FAILED" end),
      ((.missedBugs | map(.id) | join(", ")) | if . == "" then "-" else . end)] | @tsv' "$file")"
  IFS=$'\t' read -r topic score status missed <<<"$row"
  printf '| %s | %s | %s | %s |\n' "$topic" "$score" "$status" "$missed"
  [[ "$status" == "PASSED" ]] || failed=1
done

printf '\n70 points or more completes a topic. The score is feedback for you, not a ranking.\n'
printf 'Hints for each missed bug are in the log of its job.\n'

exit "$failed"
