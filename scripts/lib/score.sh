# shellcheck shell=bash
# -----------------------------------------------------------------------------
# Scoring API shared by every topic. Every review prints the same report:
#
#   score_begin <topic-dir>                     reads topic.yml, prints the header
#   score_gate <ok> <detail>                    records the gate; exits 2 when it fails
#   score_criterion <name> <earned> <max> <detail> [ok|fail]
#                                               records one criterion line
#   score_skip <name> <reason>                  shows a skipped criterion (e.g. --quick)
#   score_hint <id> <text> [title]              queues a hint for the final block
#   score_warn <text>                           queues a warning for the maintainer
#   score_end                                   prints the total, hints, JSON; exits 0/1
#   score_fatal <message> [hint]                environment/configuration error; exits 3
#
# <ok> is "true"/"false" (or 1/0). Output is aligned on column 50 and coloured
# only when stdout is a terminal and NO_COLOR is not set.
#
# Environment:
#   SCORE_JSON=1          also write results/<track>-<topic>.json
#   SCORE_RESULTS_DIR     where JSON files go (default: <repo>/results)
#   SCORE_QUIET_PROGRESS  set to 1 to hide progress messages on stderr
# -----------------------------------------------------------------------------

# Loaded once per process: scripts/review.sh sources it and then sources the
# topic review, which sources it again.
[[ -n "${SCORE_SH_LOADED:-}" ]] && return 0
SCORE_SH_LOADED=1

readonly SCORE_COLUMN=50
readonly SCORE_EXIT_PASSED=0
readonly SCORE_EXIT_FAILED=1
readonly SCORE_EXIT_GATE=2
readonly SCORE_EXIT_ENV=3

# Native jq.exe/yq.exe on Windows (Git Bash, MSYS2, Cygwin) end lines with
# CRLF; strip the CR so values compare equal to plain strings.
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    jq() { command jq "$@" | tr -d '\r'; }
    yq() { command yq "$@" | tr -d '\r'; }
    ;;
esac

SCORE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORE_REPO_ROOT="$(cd "${SCORE_LIB_DIR}/../.." && pwd)"

SCORE_TOPIC_DIR=""
SCORE_TOPIC_NAME=""
SCORE_TOPIC_TITLE=""
SCORE_THRESHOLD=70
SCORE_EARNED=0
SCORE_MAX=0
SCORE_SKIPPED=()
SCORE_CRITERIA=()   # one compact JSON object per criterion
SCORE_HINTS=()      # "id<TAB>title<TAB>text"
SCORE_WARNINGS=()
SCORE_GATE_JSON='null'
SCORE_USER=""
SCORE_BRANCH=""
SCORE_COMMIT=""

# --- Colours -----------------------------------------------------------------

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  SCORE_C_OK=$'\e[32m'
  SCORE_C_FAIL=$'\e[31m'
  SCORE_C_WARN=$'\e[33m'
  SCORE_C_BOLD=$'\e[1m'
  SCORE_C_DIM=$'\e[2m'
  SCORE_C_RESET=$'\e[0m'
else
  SCORE_C_OK="" SCORE_C_FAIL="" SCORE_C_WARN="" SCORE_C_BOLD="" SCORE_C_DIM="" SCORE_C_RESET=""
fi

# --- Small helpers -----------------------------------------------------------

# Prints a progress message on stderr (kept out of the report).
score_progress() {
  [[ "${SCORE_QUIET_PROGRESS:-0}" == "1" ]] && return 0
  printf '%s   … %s%s\n' "$SCORE_C_DIM" "$*" "$SCORE_C_RESET" >&2
}

score__is_true() {
  [[ "$1" == "true" || "$1" == "1" || "$1" == "ok" ]]
}

# Prints "[✔] label ........ " padded so the dots end on column 50.
score__line_start() {
  local ok="$1" label="$2" mark colour dots_len dots
  if score__is_true "$ok"; then mark="✔" colour="$SCORE_C_OK"; else mark="✘" colour="$SCORE_C_FAIL"; fi
  # "[x] " takes 4 columns, then the label and one space.
  dots_len=$(( SCORE_COLUMN - 4 - ${#label} - 1 ))
  (( dots_len < 3 )) && dots_len=3
  printf -v dots '%*s' "$dots_len" ''
  printf '%s[%s]%s %s %s' "$colour" "$mark" "$SCORE_C_RESET" "$label" "${dots// /.}"
}

# Reads a value from the topic.yml (empty when missing).
score_topic_value() {
  local expr="$1"
  yq -r "${expr} // \"\"" "${SCORE_TOPIC_DIR}/topic.yml"
}

score__identity() {
  SCORE_BRANCH="$(git -C "$SCORE_REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
  SCORE_COMMIT="$(git -C "$SCORE_REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "none")"
  if [[ -n "$(git -C "$SCORE_REPO_ROOT" status --porcelain -- app 2>/dev/null)" ]]; then
    SCORE_COMMIT="${SCORE_COMMIT} (uncommitted changes)"
  fi
  if [[ "$SCORE_BRANCH" == participant/* ]]; then
    SCORE_USER="${SCORE_BRANCH#participant/}"
    SCORE_USER="${SCORE_USER%%/*}"
  else
    SCORE_USER="$(git -C "$SCORE_REPO_ROOT" config user.name 2>/dev/null || true)"
    SCORE_USER="${SCORE_USER:-${USER:-${USERNAME:-unknown}}}"
  fi
}

# --- Public API --------------------------------------------------------------

score_fatal() {
  local message="$1" hint="${2:-}"
  printf '%s[✘]%s Environment: %s\n' "$SCORE_C_FAIL" "$SCORE_C_RESET" "$message"
  [[ -n "$hint" ]] && printf '          Hint: %s\n' "$hint"
  exit "$SCORE_EXIT_ENV"
}

score_begin() {
  SCORE_TOPIC_DIR="$(cd "$1" && pwd)"
  [[ -f "${SCORE_TOPIC_DIR}/topic.yml" ]] || score_fatal "missing ${SCORE_TOPIC_DIR}/topic.yml" \
    "Every topic folder needs a topic.yml (see scripts/README.md)."
  yq -e '.id' "${SCORE_TOPIC_DIR}/topic.yml" >/dev/null 2>&1 \
    || score_fatal "invalid topic.yml in ${SCORE_TOPIC_DIR}" "Check the YAML syntax and the 'id' field."

  SCORE_TOPIC_NAME="${SCORE_TOPIC_DIR#"${SCORE_REPO_ROOT}/tracks/"}"
  SCORE_TOPIC_TITLE="$(score_topic_value '.title')"
  SCORE_THRESHOLD="$(score_topic_value '.pass_threshold')"
  SCORE_THRESHOLD="${SCORE_THRESHOLD:-70}"
  score__identity

  printf '%s══ Review: %s ══%s\n' "$SCORE_C_BOLD" "$SCORE_TOPIC_NAME" "$SCORE_C_RESET"
  printf '   user: %s  |  branch: %s  |  commit: %s\n\n' "$SCORE_USER" "$SCORE_BRANCH" "$SCORE_COMMIT"
}

score_gate() {
  local ok="$1" detail="$2"
  score__line_start "$ok" "Gate: ${detail}"
  if score__is_true "$ok"; then
    printf ' OK\n'
    SCORE_GATE_JSON="$(jq -nc --arg d "$detail" '{passed: true, detail: $d}')"
    return 0
  fi
  printf ' %sFAILED%s\n' "$SCORE_C_FAIL" "$SCORE_C_RESET"
  SCORE_GATE_JSON="$(jq -nc --arg d "$detail" '{passed: false, detail: $d}')"
  SCORE_EARNED=0
  SCORE_MAX=100
  score__print_total "FAILED (gate)"
  score__print_hints
  score__write_json "gate-failed" false
  exit "$SCORE_EXIT_GATE"
}

score_criterion() {
  local name="$1" earned="$2" max="$3" detail="$4" status="${5:-}" ok
  if [[ -n "$status" ]]; then
    ok="$status"
  elif (( earned * 100 >= SCORE_THRESHOLD * max )); then
    ok="true"
  else
    ok="false"
  fi
  score__line_start "$ok" "$name"
  if [[ -n "$detail" ]]; then
    printf ' %-6s %s/%s\n' "$detail" "$earned" "$max"
  else
    printf ' %s/%s\n' "$earned" "$max"
  fi
  SCORE_EARNED=$(( SCORE_EARNED + earned ))
  SCORE_MAX=$(( SCORE_MAX + max ))
  SCORE_CRITERIA+=("$(jq -nc --arg n "$name" --argjson e "$earned" --argjson m "$max" --arg d "$detail" \
    --argjson ok "$(score__is_true "$ok" && echo true || echo false)" \
    '{name: $n, earned: $e, max: $m, detail: $d, ok: $ok}')")
}

score_skip() {
  local name="$1" reason="$2" label
  label="${name}"
  printf '%s[–]%s %s %s %s\n' "$SCORE_C_WARN" "$SCORE_C_RESET" "$label" \
    "$(printf '%*s' $(( SCORE_COLUMN - 4 - ${#label} - 1 )) '' | tr ' ' '.')" "skipped (${reason})"
  SCORE_SKIPPED+=("$name")
  SCORE_CRITERIA+=("$(jq -nc --arg n "$name" --arg r "$reason" '{name: $n, skipped: true, reason: $r}')")
}

score_hint() {
  local id="$1" text="$2" title="${3:-}"
  SCORE_HINTS+=("${id}"$'\t'"${title}"$'\t'"${text}")
}

score_warn() {
  SCORE_WARNINGS+=("$1")
}

score_end() {
  local percent status
  if (( SCORE_MAX == 0 )); then
    score_fatal "the review recorded no criteria" "Check the topic's review.sh."
  fi
  percent=$(( (SCORE_EARNED * 100 + SCORE_MAX / 2) / SCORE_MAX ))
  if (( percent >= SCORE_THRESHOLD )); then status="PASSED"; else status="FAILED"; fi

  if (( ${#SCORE_SKIPPED[@]} > 0 )); then
    score__print_total "${status} (partial: $(score__join ', ' "${SCORE_SKIPPED[@]}") skipped; ${percent}% vs threshold ${SCORE_THRESHOLD}%)"
  else
    score__print_total "${status} (threshold ${SCORE_THRESHOLD})"
  fi
  score__print_hints
  score__write_json "$(echo "$status" | tr '[:upper:]' '[:lower:]')" "$([[ $status == PASSED ]] && echo true || echo false)"

  [[ "$status" == "PASSED" ]] && exit "$SCORE_EXIT_PASSED"
  exit "$SCORE_EXIT_FAILED"
}

# --- Report pieces -----------------------------------------------------------

score__join() {
  local separator="$1"; shift
  local result="" item
  for item in "$@"; do result+="${result:+$separator}${item}"; done
  printf '%s' "$result"
}

score__print_total() {
  local verdict="$1" colour="$SCORE_C_OK"
  [[ "$verdict" == PASSED* ]] || colour="$SCORE_C_FAIL"
  printf '\n%sTOTAL: %s/%s  %s%s\n' "$SCORE_C_BOLD$colour" "$SCORE_EARNED" "$SCORE_MAX" "$verdict" "$SCORE_C_RESET"
}

# Splits a queued hint ("id<TAB>title<TAB>text", text may span lines) into
# HINT_ID, HINT_TITLE and HINT_TEXT.
score__split_hint() {
  local entry="$1" rest tab=$'\t'
  HINT_ID="${entry%%"$tab"*}"
  rest="${entry#*"$tab"}"
  HINT_TITLE="${rest%%"$tab"*}"
  HINT_TEXT="${rest#*"$tab"}"
}

score__print_hints() {
  local entry id title text printed_bugs=0 printed_other=0
  for entry in "${SCORE_HINTS[@]}"; do
    score__split_hint "$entry"; id="$HINT_ID" title="$HINT_TITLE" text="$HINT_TEXT"
    if [[ "$id" == BUG-* ]]; then
      (( printed_bugs++ == 0 )) && printf '\nMissed bugs:\n'
      printf '  %-6s  %s\n          Hint: %s\n' "$id" "$title" "$text"
    fi
  done
  for entry in "${SCORE_HINTS[@]}"; do
    score__split_hint "$entry"; id="$HINT_ID" title="$HINT_TITLE" text="$HINT_TEXT"
    if [[ "$id" != BUG-* ]]; then
      (( printed_other++ == 0 )) && printf '\nTo improve:\n'
      if [[ -n "$title" ]]; then
        printf '  %s  %s\n          Hint: %s\n' "$id" "$title" "$text"
      else
        printf '  %s\n          Hint: %s\n' "$id" "$text"
      fi
    fi
  done
  if (( ${#SCORE_WARNINGS[@]} > 0 )); then
    printf '\n%sWarnings (please tell the maintainer):%s\n' "$SCORE_C_WARN" "$SCORE_C_RESET"
    printf '  - %s\n' "${SCORE_WARNINGS[@]}"
  fi
  return 0
}

score__write_json() {
  local status="$1" passed="$2" file dir
  [[ "${SCORE_JSON:-0}" == "1" ]] || return 0
  dir="${SCORE_RESULTS_DIR:-${SCORE_REPO_ROOT}/results}"
  mkdir -p "$dir"
  file="${dir}/$(printf '%s' "$SCORE_TOPIC_NAME" | tr '/' '-').json"

  local criteria hints warnings
  criteria="$(printf '%s\n' "${SCORE_CRITERIA[@]}" | jq -sc '.')"
  hints="$(for entry in "${SCORE_HINTS[@]}"; do
    score__split_hint "$entry"
    jq -nc --arg id "$HINT_ID" --arg t "$HINT_TITLE" --arg h "$HINT_TEXT" '{id: $id, title: $t, hint: $h}'
  done | jq -sc '.')"
  warnings="$(printf '%s\n' "${SCORE_WARNINGS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')"

  jq -n \
    --arg topic "$SCORE_TOPIC_NAME" --arg title "$SCORE_TOPIC_TITLE" \
    --arg user "$SCORE_USER" --arg branch "$SCORE_BRANCH" --arg commit "$SCORE_COMMIT" \
    --argjson earned "$SCORE_EARNED" --argjson max "$SCORE_MAX" --argjson threshold "$SCORE_THRESHOLD" \
    --arg status "$status" --argjson passed "$passed" \
    --argjson partial "$( (( ${#SCORE_SKIPPED[@]} > 0 )) && echo true || echo false)" \
    --argjson gate "$SCORE_GATE_JSON" --argjson criteria "$criteria" \
    --argjson hints "$hints" --argjson warnings "$warnings" \
    '{topic: $topic, title: $title, user: $user, branch: $branch, commit: $commit,
      score: $earned, max: $max, threshold: $threshold, status: $status, passed: $passed,
      partial: $partial, gate: $gate, criteria: $criteria,
      missedBugs: [$hints[] | select(.id | startswith("BUG-"))],
      practiceHints: [$hints[] | select(.id | startswith("BUG-") | not)],
      warnings: $warnings}' >"$file"
  printf '\nResults written to %s\n' "${file#"${SCORE_REPO_ROOT}/"}"
}
