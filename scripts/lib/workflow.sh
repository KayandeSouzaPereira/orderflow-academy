# shellcheck shell=bash
# -----------------------------------------------------------------------------
# Static checks of a participant's GitHub Actions workflow (topics B-08, C-05).
#
#   workflow_load <file>             parses the workflow (returns 1 if it is not valid YAML)
#   workflow_push_branches           branches of 'on.push.branches', one per line
#   workflow_any_run <ERE>...        true when one step's 'run' matches every ERE
#   workflow_any_step <jq-filter>    true when one step matches the jq filter
#
# Steps of every job are flattened into WORKFLOW_STEPS (a JSON array), each
# with the job's defaults.run.working-directory when the step has none.
# -----------------------------------------------------------------------------

WORKFLOW_JSON=""
WORKFLOW_STEPS="[]"

workflow_load() {
  local file="$1"
  WORKFLOW_JSON="$(yq -o json '.' "$file" 2>/dev/null)" || return 1
  [[ -n "$WORKFLOW_JSON" && "$WORKFLOW_JSON" != "null" ]] || return 1
  WORKFLOW_STEPS="$(jq -c '[.jobs // {} | to_entries[] | .value as $job
      | ($job.steps // [])[]
      | . + {"working-directory": (.["working-directory"] // $job.defaults.run["working-directory"] // "")}]' \
    <<<"$WORKFLOW_JSON")"
}

workflow_push_branches() {
  # "on" may be read as a boolean key by YAML 1.1 parsers.
  jq -r '(.on // .true // {}) | if type == "object" then (.push.branches // [])[] else empty end' <<<"$WORKFLOW_JSON"
}

workflow_any_run() {
  local filter='.[] | (.run // "") | select(length > 0)'
  local pattern
  for pattern in "$@"; do
    filter+=" | select(test(\"${pattern}\"))"
  done
  [[ -n "$(jq -r "$filter" <<<"$WORKFLOW_STEPS" | head -n 1)" ]]
}

workflow_any_step() {
  [[ "$(jq -r "[.[] | select($1)] | length" <<<"$WORKFLOW_STEPS")" != "0" ]]
}
