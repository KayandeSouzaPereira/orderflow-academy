#!/usr/bin/env bash
# Prepares a participant checkout for an OFFICIAL review.
#
#   ./scripts/ci/sanitize.sh <trusted-dir> <work-dir> <head-sha>
#
# <trusted-dir>  checkout of main: the only source of scripts, topics, bugs and
#                production code. This script itself must run from there.
# <work-dir>     checkout of the participant's commit <head-sha>, with full
#                history (B-02 and the TDD kata read it).
#
# In <work-dir>, scripts/, tracks/, docs/ and app/ are replaced with the
# trusted copy; then only the paths listed in participant-paths.txt are taken
# back from the participant's commit. .github/ is left alone: reviews B-08 and
# C-05 read the participant's own workflow files, and workflows that run in CI
# always come from main anyway.
set -euo pipefail

TRUSTED="$(cd "${1:?usage: sanitize.sh <trusted-dir> <work-dir> <head-sha>}" && pwd)"
WORK="$(cd "${2:?missing work dir}" && pwd)"
HEAD_SHA="${3:?missing head sha}"
PATHS_FILE="${TRUSTED}/scripts/ci/participant-paths.txt"

[[ -f "$PATHS_FILE" ]] || { echo "sanitize: ${PATHS_FILE} not found" >&2; exit 3; }
git -C "$WORK" cat-file -e "${HEAD_SHA}^{commit}" 2>/dev/null \
  || { echo "sanitize: commit ${HEAD_SHA} is not in ${WORK}" >&2; exit 3; }

for dir in scripts tracks docs app; do
  rm -rf "${WORK:?}/${dir}"
  if [[ -d "${TRUSTED}/${dir}" ]]; then
    cp -R "${TRUSTED}/${dir}" "${WORK}/${dir}"
  fi
done

restored=0
pinned=()
while IFS= read -r path; do
  [[ -z "$path" || "$path" == \#* ]] && continue
  if [[ "$path" == '!'* ]]; then
    pinned+=("${path#!}")
    continue
  fi
  path="${path%/}"
  # Taken from the participant's commit only when it exists there.
  if git -C "$WORK" cat-file -e "${HEAD_SHA}:${path}" 2>/dev/null; then
    # Start from an empty folder, so nothing of main's copy mixes in.
    if [[ "$(git -C "$WORK" cat-file -t "${HEAD_SHA}:${path}")" == "tree" ]]; then
      rm -rf "${WORK:?}/${path}"
    fi
    git -C "$WORK" checkout "$HEAD_SHA" -- "$path"
    restored=$(( restored + 1 ))
  fi
done <"$PATHS_FILE"

# Files inside a participant folder that must stay as in main ("dest" or "dest=source").
for entry in "${pinned[@]}"; do
  path="${entry%%=*}"
  source_path="${entry#*=}"
  [[ "$entry" == *=* ]] || source_path="$path"
  if [[ -e "${TRUSTED}/${source_path}" ]]; then
    mkdir -p "$(dirname "${WORK}/${path}")"
    cp -R "${TRUSTED}/${source_path}" "${WORK}/${path}"
  else
    rm -rf "${WORK:?}/${path}"
  fi
done

echo "sanitize: scripts/, tracks/, docs/ and app/ come from main; ${restored} participant path(s) restored from ${HEAD_SHA:0:7}"
