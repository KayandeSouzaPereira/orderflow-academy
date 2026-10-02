#!/usr/bin/env bash
# Prints, as a JSON array, the topics an official review must run.
#
#   ./scripts/ci/detect-topics.sh <work-dir> <before> <after> [<filter>]
#
# <before>  previous head of the branch, or empty/zeros for "unknown": the
#           merge-base with origin/main is used then
# <after>   head being reviewed
# <filter>  "all" (every topic), a topic id such as c-e2e-testing/01-playwright-basics,
#           or empty/"changed" (default): only topics whose files changed
#
# A topic "owns" the test folder or files of its kind plus the extra
# watch_paths of its topic.yml; topics of tracks starting with "_" (the
# example) are never listed. Topic definitions are read from the folder this
# script lives in (main), never from <work-dir>.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(cd "${1:?usage: detect-topics.sh <work-dir> <before> <after> [<filter>]}" && pwd)"
BEFORE="${2:-}"
AFTER="${3:?missing after sha}"
FILTER="${4:-changed}"

for tool in git jq yq; do
  command -v "$tool" >/dev/null || { echo "detect-topics: ${tool} not found" >&2; exit 3; }
done

# Native jq.exe/yq.exe on Windows end lines with CRLF (same fix as score.sh).
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    jq() { command jq "$@" | tr -d '\r'; }
    yq() { command yq "$@" | tr -d '\r'; }
    ;;
esac

mapfile -t ALL < <(find "${ROOT}/tracks" -name topic.yml -not -path '*/bugs/*' \
  | sed -e "s#^${ROOT}/tracks/##" -e 's#/topic.yml$##' | grep -v '^_' | sort)

emit() {
  if (( $# == 0 )); then
    echo '[]'
  else
    printf '%s\n' "$@" | jq -R . | jq -sc .
  fi
}

case "$FILTER" in
  all) emit "${ALL[@]}"; exit 0 ;;
  changed | "") ;;
  *)
    for topic in "${ALL[@]}"; do
      [[ "$topic" == "$FILTER" ]] && { emit "$topic"; exit 0; }
    done
    echo "detect-topics: unknown topic '${FILTER}'" >&2
    exit 3 ;;
esac

# Base of the comparison: the previous head when it is known and reachable.
zeros='^0+$'
if [[ -z "$BEFORE" || "$BEFORE" =~ $zeros ]] || ! git -C "$WORK" cat-file -e "${BEFORE}^{commit}" 2>/dev/null; then
  BEFORE="$(git -C "$WORK" merge-base "origin/main" "$AFTER" 2>/dev/null || true)"
fi
if [[ -z "$BEFORE" ]]; then
  emit "${ALL[@]}"
  exit 0
fi
mapfile -t CHANGED < <(git -C "$WORK" diff --name-only "$BEFORE" "$AFTER")

# Prefixes a topic owns, one per line.
watched() {
  local topic="$1" file="${ROOT}/tracks/$1/topic.yml" json kind package
  json="$(yq -o json '.' "$file")"
  kind="$(jq -r '.kind // ""' <<<"$json")"
  package="$(jq -r '.test_package // ""' <<<"$json")"
  case "$kind" in
    backend)
      echo "app/backend/src/test/java/${package//.//}/"
      jq -r '.implementation_swap.path // empty' <<<"$json" ;;
    api) echo "app/api-tests/src/test/java/${package//.//}/" ;;
    frontend)
      while IFS= read -r spec; do
        [[ -n "$spec" ]] && echo "app/frontend/${spec}"
      done < <(jq -r '(.test_files // [])[]' <<<"$json") ;;
    e2e) echo "app/e2e/$(jq -r '.test_dir // ""' <<<"$json")/" ;;
  esac
  jq -r '(.watch_paths // [])[]' <<<"$json"
}

selected=()
for topic in "${ALL[@]}"; do
  hit=0
  while IFS= read -r prefix; do
    [[ -n "$prefix" ]] || continue
    for file in "${CHANGED[@]}"; do
      if [[ "$file" == "$prefix"* ]]; then hit=1; break; fi
    done
    (( hit == 1 )) && break
  done < <(watched "$topic")
  (( hit == 1 )) && selected+=("$topic")
done
emit "${selected[@]}"
