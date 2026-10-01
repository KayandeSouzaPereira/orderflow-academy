#!/usr/bin/env bash
# Proves that a participant cannot change an official score by editing the
# scoring tools: runs the official-review procedure twice on a simulated
# participant branch, once honest and once tampered with, and compares scores.
#
#   ./scripts/dev/simulate-participant-ci.sh <track>/<topic> <solution-dir> [<review args...>]
#
# <solution-dir>  an overlay (reference/ or calibration-weak/ of the private
#                 repository): its files become the participant's commit.
# Review args     passed to review.sh (default: --quick).
#
# The tampered variant also: makes every missed bug count as detected in
# scripts/lib/standard.sh, deletes the topic's bugs, lowers its pass
# threshold, rewrites a production class and edits review.yml. After
# scripts/ci/sanitize.sh, scripts/, tracks/ and production code must be
# identical to main, and both variants must score the same.
#
# The "trusted" copy plays main: the current HEAD of this repository.
# Exit code: 0 when the scores are equal and the integrity checks pass, 1 otherwise.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOPIC="${1:?usage: simulate-participant-ci.sh <track>/<topic> <solution-dir> [<review args...>]}"
SOLUTION="$(cd "${2:?missing solution dir}" && pwd)"
shift 2
REVIEW_ARGS=("$@")
(( ${#REVIEW_ARGS[@]} > 0 )) || REVIEW_ARGS=(--quick)

TMP="$(mktemp -d "${TMPDIR:-/tmp}/orderflow-sim.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
HEAD_SHA="$(git -C "$ROOT" rev-parse HEAD)"

TRUSTED="${TMP}/trusted"
mkdir -p "$TRUSTED"
git -C "$ROOT" archive HEAD | tar -x -C "$TRUSTED"

# Builds work-<variant>: a clone with the participant's commit on top of main.
make_work() {
  local variant="$1" tamper="$2" work
  work="${TMP}/work-${variant}"
  git clone -q "$ROOT" "$work"
  git -C "$work" checkout -q --detach "$HEAD_SHA"
  git -C "$work" checkout -q -b participant/sim
  git -C "$work" update-ref refs/remotes/origin/main "$HEAD_SHA"
  git -C "$work" config user.name "Sim Participant"
  git -C "$work" config user.email "sim@example.com"
  cp -R "${SOLUTION}/." "$work/"
  git -C "$work" add -A
  git -C "$work" commit -q -m "feat: participant solution"

  if [[ "$tamper" == "yes" ]]; then
    sed -i.bak 's/0) echo "missed" ;;/0) echo "detected" ;;/' "${work}/scripts/lib/standard.sh"
    rm -f "${work}/scripts/lib/standard.sh.bak"
    rm -rf "${work:?}/tracks/${TOPIC}/bugs"
    sed -i.bak 's/^pass_threshold: .*/pass_threshold: 0/' "${work}/tracks/${TOPIC}/topic.yml"
    rm -f "${work}/tracks/${TOPIC}/topic.yml.bak"
    printf '\n// tampered by the participant\n' >> "${work}/app/backend/src/main/java/dev/orderflow/domain/OrderPricing.java"
    sed -i.bak 's/^name: review$/name: review (tampered)/' "${work}/.github/workflows/review.yml"
    rm -f "${work}/.github/workflows/review.yml.bak"
    git -C "$work" add -A
    git -C "$work" commit -q -m "chore: tweak things"
  fi
  echo "$work"
}

score_of() {
  local work="$1" result
  rm -rf "${work}/results"
  (cd "$work" && REVIEW_BRANCH=participant/sim ./scripts/review.sh "$TOPIC" --json "${REVIEW_ARGS[@]}" >"${work}/review.log" 2>&1) || true
  result="${work}/results/$(printf '%s' "$TOPIC" | tr '/' '-').json"
  if [[ -f "$result" ]]; then
    jq -r '"\(.score)/\(.max) \(.status)"' "$result"
  else
    echo "no-result"
  fi
}

failures=0
declare -A SCORES=()
for variant in honest tampered; do
  tamper=no
  [[ "$variant" == "tampered" ]] && tamper=yes
  printf '── %s participant branch ──\n' "$variant"
  work="$(make_work "$variant" "$tamper")"
  "${TRUSTED}/scripts/ci/sanitize.sh" "$TRUSTED" "$work" "$(git -C "$work" rev-parse HEAD)"

  # Integrity: what the review runs is main's, byte for byte.
  for dir in scripts docs; do
    if ! diff -rq "${TRUSTED}/${dir}" "${work}/${dir}" >/dev/null 2>&1; then
      echo "  ✘ ${dir}/ differs from main after sanitizing"
      failures=$(( failures + 1 ))
    fi
  done
  if ! diff -rq "${TRUSTED}/tracks/${TOPIC}" "${work}/tracks/${TOPIC}" >/dev/null 2>&1; then
    echo "  ✘ tracks/${TOPIC} differs from main after sanitizing"
    failures=$(( failures + 1 ))
  fi
  if ! cmp -s "${TRUSTED}/app/backend/src/main/java/dev/orderflow/domain/OrderPricing.java" \
    "${work}/app/backend/src/main/java/dev/orderflow/domain/OrderPricing.java"; then
    echo "  ✘ production code differs from main after sanitizing"
    failures=$(( failures + 1 ))
  fi

  SCORES[$variant]="$(score_of "$work")"
  printf '  score: %s\n' "${SCORES[$variant]}"
done

printf '\n'
if [[ "${SCORES[honest]}" == "no-result" || "${SCORES[honest]}" != "${SCORES[tampered]}" ]]; then
  echo "✘ scores differ or the review did not run: honest=${SCORES[honest]} tampered=${SCORES[tampered]}"
  failures=$(( failures + 1 ))
fi
if (( failures > 0 )); then
  echo "SIMULATION FAILED (${failures} problem(s))"
  exit 1
fi
echo "SIMULATION OK: the tampered branch scores exactly like the honest one (${SCORES[honest]})."
