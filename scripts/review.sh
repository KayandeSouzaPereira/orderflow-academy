#!/usr/bin/env bash
# Reviews one topic and prints its score.
#
#   ./scripts/review.sh <track>/<topic> [--quick] [--json] [--overlay <dir>]
#
#   ./scripts/review.sh a-unit-testing/01-test-anatomy
#   ./scripts/review.sh b-integration-testing/04-api-testing --quick
#   ./scripts/review.sh _example --json
#
# Exit codes: 0 passed, 1 below the threshold, 2 gate failed, 3 environment
# or configuration error.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/score.sh
source "${ROOT}/scripts/lib/score.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/review.sh <track>/<topic> [--quick] [--json] [--overlay <dir>]

  --quick          skip mutation testing (faster; the score is partial)
  --json           also write results/<track>-<topic>.json
  --overlay <dir>  copy <dir>/app over the reviewed copy (maintainers)

Topics:
EOF
  find "${ROOT}/tracks" -name topic.yml -not -path '*/bugs/*' 2>/dev/null \
    | sed -e "s#^${ROOT}/tracks/##" -e 's#/topic.yml$##' | sort | sed 's/^/  /'
}

child=""

# Sends TERM to the running topic review (a background subshell ignores
# SIGINT, so Ctrl+C is forwarded as TERM).
# shellcheck disable=SC2329 # invoked by the trap below
forward_signal() {
  kill -TERM "$child" 2>/dev/null || true
}

main() {
  if (( $# == 0 )) || [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit $(( $# == 0 ? 3 : 0 ))
  fi
  local topic="${1#tracks/}"
  topic="${topic%/}"
  shift
  local topic_dir="${ROOT}/tracks/${topic}"
  [[ -f "${topic_dir}/topic.yml" ]] || score_fatal "unknown topic '${topic}'" \
    "Run ./scripts/review.sh --help to list the topics."
  [[ -f "${topic_dir}/review.sh" ]] || score_fatal "topic '${topic}' has no review.sh" \
    "Tell the maintainer: every topic needs tracks/<track>/<topic>/review.sh."
  # Run the topic review in a subshell (a fork, no 'exec') and forward Ctrl+C
  # and TERM to it. On Windows (MSYS) every exec leaves an intermediate process
  # that swallows signals; a forked subshell is always the real process, so the
  # review's cleanup (containers, temporary folders) always runs.
  (
    # shellcheck source=/dev/null
    source "${topic_dir}/review.sh" "$@"
  ) &
  child=$!
  local status=0
  trap forward_signal INT TERM
  wait "$child" || status=$?
  # After a forwarded signal, wait until the review has cleaned up.
  while kill -0 "$child" 2>/dev/null; do
    status=0
    wait "$child" || status=$?
  done
  exit "$status"
}

main "$@"
