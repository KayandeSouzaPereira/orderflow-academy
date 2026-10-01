#!/usr/bin/env bash
# Maintainer/CI check: every topic and every planted bug is well formed.
#
#   ./scripts/dev/validate-structure.sh
#
# Topic: README.md with the six standard sections, valid topic.yml, executable
#        review.sh, known practice rules, 4 to 6 bugs (or bug_bank.min/max).
# Bug:   bug.yml (id, title, hint, side) and a patch.diff that applies to the
#        current tree (git apply --check).
# Exit code: 0 when everything is valid, 1 otherwise (all problems are listed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/score.sh
source "${ROOT}/scripts/lib/score.sh"
# shellcheck source=../lib/practices.sh
source "${ROOT}/scripts/lib/practices.sh"

for tool in git jq yq; do
  command -v "$tool" >/dev/null || score_fatal "required tool '${tool}' not found" "Install ${tool}."
done

README_SECTIONS=("Goal" "Context" "Your task" "How you are scored" "Hints" "Further reading")
KINDS=" backend frontend api e2e custom "
SIDES=" backend frontend "
ERRORS=()

error() {
  ERRORS+=("$1: $2")
}

# True when git records the file as executable (works on Windows checkouts too).
is_executable() {
  local file="$1" mode
  mode="$(git -C "$ROOT" ls-files -s -- "$file" | cut -d' ' -f1)"
  if [[ -n "$mode" ]]; then
    [[ "$mode" == "100755" ]]
  else
    [[ -x "${ROOT}/${file}" ]]
  fi
}

validate_readme() {
  local topic="$1" readme="${ROOT}/tracks/$1/README.md" section
  if [[ ! -f "$readme" ]]; then
    error "$topic" "missing README.md"
    return
  fi
  for section in "${README_SECTIONS[@]}"; do
    grep -qE "^## ${section}[[:space:]]*$" "$readme" || error "$topic" "README.md has no '## ${section}' section"
  done
}

validate_topic_yml() {
  local topic="$1" file="${ROOT}/tracks/$1/topic.yml" json kind field rule
  if ! json="$(yq -o json '.' "$file" 2>/dev/null)" || [[ "$json" == "null" ]]; then
    error "$topic" "topic.yml is not valid YAML"
    return
  fi
  for field in id title track kind; do
    [[ -n "$(jq -r ".${field} // empty" <<<"$json")" ]] || error "$topic" "topic.yml has no '${field}'"
  done
  kind="$(jq -r '.kind // empty' <<<"$json")"
  [[ "$KINDS" == *" ${kind} "* ]] || error "$topic" "topic.yml kind '${kind}' is not one of:${KINDS}"
  if [[ "$kind" != "custom" ]]; then
    [[ -n "$(jq -r '.test_package // .test_files // empty' <<<"$json")" ]] \
      || error "$topic" "topic.yml needs test_package (or test_files)"
  fi
  while IFS= read -r rule; do
    [[ -z "$rule" ]] && continue
    practice_known "$rule" || error "$topic" "unknown practice rule '${rule}'"
  done < <(jq -r '(.practices // [])[] | if type == "string" then . else .rule end' <<<"$json")

  local weight_mutation
  weight_mutation="$(jq -r '.weights.mutation // empty' <<<"$json")"
  if [[ -n "$weight_mutation" && "$weight_mutation" != "0" ]]; then
    [[ -n "$(jq -r '.mutation.target_classes // empty' <<<"$json")" ]] \
      || error "$topic" "weights.mutation is set but mutation.target_classes is missing"
  fi
}

# patch_applies <topic-dir> <patch>: checks the patch against the current tree,
# or, for topics with implementation_swap (TDD kata), against the reference
# implementation the review swaps in.
patch_applies() {
  local topic_dir="$1" patch="$2" swap_path swap_reference tmp status=0
  swap_path="$(yq -r '.implementation_swap.path // ""' "${topic_dir}/topic.yml")"
  if [[ -z "$swap_path" ]]; then
    git -C "$ROOT" apply --check "$patch" 2>/dev/null
    return
  fi
  swap_reference="${topic_dir}/$(yq -r '.implementation_swap.reference // ""' "${topic_dir}/topic.yml")"
  [[ -f "$swap_reference" ]] || return 1
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/orderflow-patch.XXXXXX")"
  mkdir -p "${tmp}/$(dirname "$swap_path")"
  cp "$swap_reference" "${tmp}/${swap_path}"
  (cd "$tmp" && git apply --check "$patch" 2>/dev/null) || status=$?
  rm -rf "$tmp"
  return "$status"
}

validate_bugs() {
  local topic="$1" dir="${ROOT}/tracks/$1" bug_dir id field side count=0 min max kind
  kind="$(yq -r '.kind // ""' "${dir}/topic.yml" 2>/dev/null || true)"
  for bug_dir in "${dir}"/bugs/BUG-*; do
    [[ -d "$bug_dir" ]] || continue
    count=$(( count + 1 ))
    id="$(basename "$bug_dir")"
    [[ "$id" =~ ^BUG-[0-9]{2}$ ]] || error "${topic}/${id}" "bug folders must be named BUG-NN"
    if [[ ! -f "${bug_dir}/bug.yml" ]]; then
      error "${topic}/${id}" "missing bug.yml"
    else
      [[ "$(yq -r '.id // ""' "${bug_dir}/bug.yml")" == "$id" ]] || error "${topic}/${id}" "bug.yml id does not match the folder"
      for field in title hint; do
        local value
        value="$(yq -r ".${field} // \"\"" "${bug_dir}/bug.yml")"
        [[ -n "$value" && "$value" != TODO* ]] || error "${topic}/${id}" "bug.yml '${field}' is empty or TODO"
      done
      side="$(yq -r '.side // ""' "${bug_dir}/bug.yml")"
      [[ "$SIDES" == *" ${side} "* ]] || error "${topic}/${id}" "bug.yml side '${side}' must be backend or frontend"
    fi
    if [[ ! -s "${bug_dir}/patch.diff" ]]; then
      error "${topic}/${id}" "missing or empty patch.diff"
    elif ! patch_applies "$dir" "${bug_dir}/patch.diff"; then
      error "${topic}/${id}" "patch.diff does not apply to the current tree"
    elif git -C "$ROOT" apply --numstat "${bug_dir}/patch.diff" | cut -f3 \
      | grep -qE '/src/test/|\.spec\.ts$|^app/(api-tests|e2e)/'; then
      error "${topic}/${id}" "patch.diff changes test code; bugs must change production code only"
    fi
  done

  [[ "$kind" == "custom" ]] && (( count == 0 )) && return
  min="$(yq -r '.bug_bank.min // 4' "${dir}/topic.yml")"
  max="$(yq -r '.bug_bank.max // 6' "${dir}/topic.yml")"
  if (( count < min || count > max )); then
    error "$topic" "has ${count} bugs; expected ${min} to ${max}"
  fi
}

mapfile -t TOPICS < <(find "${ROOT}/tracks" -name topic.yml -not -path '*/bugs/*' -not -path '*/app/*' \
  | sed -e "s#^${ROOT}/tracks/##" -e 's#/topic.yml$##' | sort)

for topic in "${TOPICS[@]}"; do
  validate_readme "$topic"
  validate_topic_yml "$topic"
  is_executable "tracks/${topic}/review.sh" || error "$topic" "review.sh is missing or not executable (git update-index --chmod=+x)"
  validate_bugs "$topic"
done

if (( ${#ERRORS[@]} > 0 )); then
  printf 'Structure: %d problem(s) in %d topic(s):\n' "${#ERRORS[@]}" "${#TOPICS[@]}"
  printf '  - %s\n' "${ERRORS[@]}"
  exit 1
fi
printf 'Structure: %d topic(s) valid.\n' "${#TOPICS[@]}"
