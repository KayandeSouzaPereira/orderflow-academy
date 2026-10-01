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

# Sends TERM to the running topic review. On Windows (MSYS) the review may
# run under an intermediate process that does not pass signals on: signal its
# children instead (the intermediate one exits by itself when they do).
# shellcheck disable=SC2329 # invoked by the trap below
forward_signal() {
  local pid sent=0
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
      for pid in $(ps -ef 2>/dev/null | awk -v parent="$child" '$3 == parent { print $2 }'); do
        kill -TERM "$pid" 2>/dev/null && sent=1
      done ;;
  esac
  (( sent == 1 )) || kill -TERM "$child" 2>/dev/null || true
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
  # Run the topic review as a child and forward Ctrl+C / TERM to it, instead of
  # 'exec': on Windows (MSYS) exec leaves a stub process behind, so a signal
  # sent to this PID would never reach the review and its cleanup.
  bash "${topic_dir}/review.sh" "$@" &
  child=$!
  local status=0
  # A background child ignores SIGINT, so forward TERM in both cases.
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
