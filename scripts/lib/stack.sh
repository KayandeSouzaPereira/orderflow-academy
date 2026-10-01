# shellcheck shell=bash
# -----------------------------------------------------------------------------
# The full stack (Floci + aws-init + backend + frontend) built from the
# workspace, for black-box topics (tracks B and C).
#
#   stack_up               builds and starts everything, waits until healthy
#   stack_rebuild <side>   rebuilds and restarts backend or frontend only
#   stack_down             removes containers, network and volumes
#
# It runs as a separate compose project ("orderflow-review", or REVIEW_STACK_PROJECT) on its own ports,
# so it never clashes with the developer stack. After stack_up:
#   API_BASE_URL=http://localhost:${STACK_BACKEND_PORT}
#   E2E_BASE_URL=http://localhost:${STACK_FRONTEND_PORT}
# -----------------------------------------------------------------------------

STACK_PROJECT="${REVIEW_STACK_PROJECT:-orderflow-review}"
STACK_FLOCI_PORT="${REVIEW_FLOCI_PORT:-14566}"
STACK_BACKEND_PORT="${REVIEW_BACKEND_PORT:-18080}"
STACK_FRONTEND_PORT="${REVIEW_FRONTEND_PORT:-14200}"
STACK_PROCESSOR_DELAY_MS=3000
STACK_LOG=""
# Docker Desktop errors worth a retry (a dropped connection, not a build error).
STACK_TRANSIENT_ERRORS='error during connect|error reading from server|Unavailable|connection refused|TLS handshake timeout|i/o timeout|unexpected EOF|failed to receive status'

stack__compose() {
  FLOCI_PORT="$STACK_FLOCI_PORT" \
    BACKEND_PORT="$STACK_BACKEND_PORT" \
    FRONTEND_PORT="$STACK_FRONTEND_PORT" \
    ORDERFLOW_PROCESSOR_DELAY_MS="$STACK_PROCESSOR_DELAY_MS" \
    ORDERFLOW_ADMIN_ENABLED=true \
    docker compose -p "$STACK_PROJECT" -f "${REVIEW_WORKSPACE}/app/docker-compose.yml" --profile full "$@"
}

# Docker Desktop sometimes drops an API call ("error during connect ... EOF");
# one retry absorbs that without hiding real failures.
stack__up_with_retry() {
  local attempt
  for attempt in 1 2; do
    if run_with_timeout "${STACK_TIMEOUT:-900}" stack__compose up -d --build --wait >>"$STACK_LOG" 2>&1; then
      return 0
    fi
    grep -qE "$STACK_TRANSIENT_ERRORS" "$STACK_LOG" || return 1
    (( attempt == 1 )) && score_progress "Docker dropped a request; retrying once"
  done
  return 1
}

stack_up() {
  STACK_LOG="${REVIEW_WORKSPACE}/stack.log"
  : >"$STACK_LOG"
  # A previous review that crashed may have left containers behind.
  stack__compose down -v --remove-orphans >/dev/null 2>&1 || true
  review_on_cleanup stack_down
  score_progress "building and starting the stack (first run can take a few minutes)"
  if ! stack__up_with_retry; then
    # The workspace (and this log) is deleted on exit: show the end of it now.
    printf 'Last lines of the stack log:\n' >&2
    grep -vE '^#[0-9]+ (sha256|extracting|DONE|CACHED)' "$STACK_LOG" | tail -n 15 | sed 's/^/  | /' >&2
    score_fatal "the stack did not start" \
      "Check that ports ${STACK_FLOCI_PORT}, ${STACK_BACKEND_PORT} and ${STACK_FRONTEND_PORT} are free and Docker has 6 GB of RAM."
  fi
  export API_BASE_URL="http://localhost:${STACK_BACKEND_PORT}"
  export E2E_BASE_URL="http://localhost:${STACK_FRONTEND_PORT}"
}

# Returns 1 when the side does not build (the bug variant is then invalid).
stack_rebuild() {
  local side="$1"
  case "$side" in
    backend | frontend) ;;
    *) score_fatal "unknown bug side '${side}'" "bug.yml 'side' must be backend or frontend." ;;
  esac
  score_progress "rebuilding ${side}"
  # Several builds at once can make Docker Desktop drop a connection
  # ("error reading from server: EOF", registry lookups refused): retry those,
  # and only those, a few times. A real compile error fails at once.
  local attempt marker
  for attempt in 1 2 3 4; do
    marker="$(wc -c <"$STACK_LOG")"
    if run_with_timeout "${STACK_TIMEOUT:-900}" \
      stack__compose up -d --build --wait --no-deps "$side" >>"$STACK_LOG" 2>&1; then
      break
    fi
    tail -c +"$(( marker + 1 ))" "$STACK_LOG" | grep -qE "$STACK_TRANSIENT_ERRORS" || return 1
    (( attempt == 4 )) && return 1
    sleep $(( attempt * 8 ))
  done
  if [[ "$side" == "backend" ]]; then
    # nginx resolves the backend address at start-up: restart it too.
    stack__compose restart frontend >>"$STACK_LOG" 2>&1 || return 1
  fi
}

stack_down() {
  stack__compose down -v --remove-orphans >/dev/null 2>&1 || true
}
