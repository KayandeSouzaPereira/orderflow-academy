#!/usr/bin/env bash
# Review of the fundamentals quiz: compares answers.yml with the hashed
# answers in quiz.yml. 10 points per correct answer; hints for wrong ones.
#
#   ./scripts/review.sh 00-fundamentals [--json] [--overlay <dir>]
#
# --overlay <dir> reads <dir>/answers.yml instead (maintainers' reference check).
set -euo pipefail

TOPIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$TOPIC_DIR"
while [[ ! -f "${ROOT}/scripts/lib/score.sh" && "$ROOT" != "/" ]]; do ROOT="$(dirname "$ROOT")"; done
# shellcheck source=../../scripts/lib/score.sh
source "${ROOT}/scripts/lib/score.sh"
# shellcheck source=../../scripts/lib/common.sh
source "${ROOT}/scripts/lib/common.sh"

ANSWERS="${TOPIC_DIR}/answers.yml"
while (( $# > 0 )); do
  case "$1" in
    --json) export SCORE_JSON=1 ;;
    --quick) ;; # nothing slow to skip
    --overlay) ANSWERS="${2:?--overlay needs a directory}/answers.yml"; shift ;;
    *) score_fatal "unknown option '$1'" "Options: --json, --overlay <dir>." ;;
  esac
  shift
done

review_require_tools jq yq
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | cut -d' ' -f1
  else
    printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1
  fi
}

score_begin "$TOPIC_DIR"

if [[ ! -f "$ANSWERS" ]]; then
  score_hint "answers" "Copy answers.template.yml to answers.yml in tracks/00-fundamentals/ and fill it in."
  score_gate false "answers.yml not found"
fi
ANSWERED="$(yq -r 'to_entries | map(select(.value | test("^[a-d]$"))) | length' "$ANSWERS" 2>/dev/null || echo 0)"
if (( ANSWERED == 0 )); then
  score_hint "answers" "Replace each ? in answers.yml with a, b, c or d."
  score_gate false "answers.yml has no answers"
fi
score_gate true "${ANSWERED} of 10 questions answered"

correct=0
total=0
while IFS=$'\t' read -r id expected hint question; do
  total=$(( total + 1 ))
  answer="$(yq -r ".${id} // \"\"" "$ANSWERS" | tr '[:upper:]' '[:lower:]')"
  if [[ "$answer" =~ ^[a-d]$ && "$(sha256 "${id}:${answer}")" == "$expected" ]]; then
    correct=$(( correct + 1 ))
  else
    score_hint "$id" "$hint" "$question"
  fi
done < <(yq -o json '.questions' "${TOPIC_DIR}/quiz.yml" \
  | jq -r '.[] | [.id, .answer_sha256, .hint, .question] | @tsv')

score_criterion "Quiz" $(( correct * 10 )) $(( total * 10 )) "${correct}/${total}"
score_end
