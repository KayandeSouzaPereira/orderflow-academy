# shellcheck shell=bash
# -----------------------------------------------------------------------------
# Shared plumbing for reviews: tool checks, portable timeout, the isolated
# workspace (a copy of app/) and cleanup on exit or Ctrl+C.
#
# Requires score.sh to be sourced first (uses score_fatal / score_progress).
# -----------------------------------------------------------------------------

REVIEW_WORKSPACE=""
REVIEW_CLEANUP_FNS=()

# --- Tool checks -------------------------------------------------------------

# review_require_tools <tool>...: exits 3 when a tool is missing.
review_require_tools() {
  local tool hint
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 && continue
    case "$tool" in
      jq) hint="Install jq 1.6+ (https://jqlang.org/download/)." ;;
      yq) hint="Install mikefarah/yq v4 (https://github.com/mikefarah/yq#install), not the Python yq." ;;
      git) hint="Install Git." ;;
      java) hint="Install a JDK 21+ and put it on the PATH." ;;
      docker) hint="Install Docker (Docker Desktop on macOS/Windows)." ;;
      node | npm | npx) hint="Install Node.js 22.22+ (https://nodejs.org)." ;;
      *) hint="Install ${tool} and put it on the PATH." ;;
    esac
    score_fatal "required tool '${tool}' not found" "$hint"
  done
}

review_require_bash() {
  (( BASH_VERSINFO[0] >= 4 )) && return 0
  score_fatal "Bash ${BASH_VERSION} is too old (Bash 5 is required)" \
    "On macOS run 'brew install bash' and use /opt/homebrew/bin/bash (or /usr/local/bin/bash)."
}

review_require_java() {
  review_require_tools java
  if [[ -n "${JAVA_HOME:-}" && ! -x "${JAVA_HOME}/bin/java" && ! -x "${JAVA_HOME}/bin/java.exe" ]]; then
    score_fatal "JAVA_HOME points to '${JAVA_HOME}', which has no bin/java" \
      "Fix JAVA_HOME (no quotes, no trailing slash) or unset it so the java on the PATH is used."
  fi
  local version
  version="$(java -version 2>&1 | awk -F'"' '/version/ {print $2; exit}')"
  if [[ "${version%%.*}" =~ ^[0-9]+$ ]] && (( ${version%%.*} < 21 )); then
    score_fatal "Java ${version} found, but Java 21+ is required" "Install a JDK 21+ and point JAVA_HOME to it."
  fi
}

review_require_docker() {
  review_require_tools docker
  if ! run_with_timeout 30 docker info >/dev/null 2>&1; then
    score_fatal "Docker is not running or does not answer" \
      "Start Docker (Docker Desktop on macOS/Windows) and check 'docker run --rm alpine echo ok'."
  fi
}

# --- Portable timeout (macOS has no 'timeout') -------------------------------

# run_with_timeout <seconds> <command>...: returns 124 when the time runs out.
run_with_timeout() {
  local seconds="$1"; shift
  local marker
  marker="$(mktemp "${TMPDIR:-/tmp}/orderflow-timeout.XXXXXX")"
  rm -f "$marker"
  "$@" &
  local pid=$!
  (
    # Kill our own sleep when we are stopped, so no orphan 'sleep' is left.
    sleeper=""
    trap 'kill "$sleeper" 2>/dev/null; exit 0' TERM
    sleep "$seconds" &
    sleeper=$!
    wait "$sleeper"
    if kill -0 "$pid" 2>/dev/null; then
      : >"$marker"
      kill -TERM "$pid" 2>/dev/null
      sleep 5
      kill -KILL "$pid" 2>/dev/null
    fi
  ) >/dev/null 2>&1 &
  local watcher=$!
  local status=0
  wait "$pid" || status=$?
  kill "$watcher" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true
  if [[ -e "$marker" ]]; then
    rm -f "$marker"
    return 124
  fi
  return "$status"
}

# --- Cleanup -----------------------------------------------------------------

# review_on_cleanup <function>: runs <function> when the review ends, however it ends.
review_on_cleanup() {
  REVIEW_CLEANUP_FNS+=("$1")
}

review__run_cleanup() {
  local fn i
  for (( i = ${#REVIEW_CLEANUP_FNS[@]} - 1; i >= 0; i-- )); do
    fn="${REVIEW_CLEANUP_FNS[i]}"
    "$fn" >/dev/null 2>&1 || true
  done
  REVIEW_CLEANUP_FNS=()
}

review__on_signal() {
  trap - INT TERM
  # The signal may arrive while stderr is redirected to a log: use the saved one.
  printf '\nInterrupted: cleaning up containers and temporary files...\n' >&"${REVIEW_STDERR_FD:-2}"
  # Stop whatever is still running in the background (Maven, npm, timers).
  local job
  for job in $(jobs -p); do kill "$job" 2>/dev/null || true; done
  review__run_cleanup
  exit 130
}

review_install_traps() {
  exec {REVIEW_STDERR_FD}>&2
  trap review__run_cleanup EXIT
  trap review__on_signal INT TERM
}

# --- Workspace ---------------------------------------------------------------

# Creates a temporary directory with a copy of <repo>/app (without build
# output and dependencies). The participant's working tree is never touched.
review_workspace_create() {
  REVIEW_WORKSPACE="$(mktemp -d "${TMPDIR:-/tmp}/orderflow-review.XXXXXX")"
  review_on_cleanup review__workspace_remove
  score_progress "copying app/ to ${REVIEW_WORKSPACE}"
  tar -C "$SCORE_REPO_ROOT" \
    --exclude='node_modules' --exclude='target' --exclude='dist' --exclude='.angular' \
    --exclude='test-results' --exclude='playwright-report' --exclude='blob-report' \
    -cf - app | tar -C "$REVIEW_WORKSPACE" -xf -
}

# review_workspace_overlay <dir>: copies <dir>/app over the workspace (used to
# apply reference or calibration solutions).
review_workspace_overlay() {
  local overlay="$1"
  [[ -d "${overlay}/app" ]] || score_fatal "overlay '${overlay}' has no app/ folder" \
    "An overlay mirrors the repository root, e.g. <overlay>/app/backend/src/test/..."
  score_progress "applying overlay ${overlay}"
  tar -C "$overlay" -cf - app | tar -C "$REVIEW_WORKSPACE" -xf -
}

review__workspace_remove() {
  [[ -n "$REVIEW_WORKSPACE" && -d "$REVIEW_WORKSPACE" ]] || return 0
  # On Windows a just-finished JVM may still hold files for a moment.
  local attempt
  for attempt in 1 2 3 4 5; do
    rm -rf "$REVIEW_WORKSPACE" 2>/dev/null && return 0
    sleep "$attempt"
  done
  rm -rf "$REVIEW_WORKSPACE"
}

# Rounds a*b/c to the nearest integer (all non-negative integers).
review_round_ratio() {
  local a="$1" b="$2" c="$3"
  (( c == 0 )) && { echo 0; return; }
  echo $(( (2 * a * b + c) / (2 * c) ))
}
