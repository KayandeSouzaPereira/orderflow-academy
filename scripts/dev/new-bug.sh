#!/usr/bin/env bash
# Maintainer helper: turns the uncommitted changes in app/ into a planted bug.
#
#   1. Change the production code in app/ to introduce the bug (do not commit).
#   2. ./scripts/dev/new-bug.sh <track>/<topic> <BUG-NN>
#   3. Fill in bugs/<BUG-NN>/bug.yml (title and hint) and restore the files.
#
# Every uncommitted change in app/ goes into the patch: commit unrelated work
# before running it.
#
# The patch is a 'git diff' from the repository root, so it applies to the
# reviewed copy with 'git apply -p1'.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

die() {
  printf 'new-bug: %s\n' "$1" >&2
  exit 3
}

(( $# == 2 )) || die "usage: ./scripts/dev/new-bug.sh <track>/<topic> <BUG-NN>"
topic="${1#tracks/}"
topic="${topic%/}"
bug_id="$2"
[[ "$bug_id" =~ ^BUG-[0-9]{2}$ ]] || die "bug id must look like BUG-01"

topic_dir="${ROOT}/tracks/${topic}"
[[ -f "${topic_dir}/topic.yml" ]] || die "unknown topic '${topic}' (no ${topic_dir}/topic.yml)"
bug_dir="${topic_dir}/bugs/${bug_id}"
[[ ! -e "$bug_dir" ]] || die "${bug_dir#"${ROOT}/"} already exists"

cd "$ROOT"
mapfile -t files < <(git diff --name-only -- app/)
(( ${#files[@]} > 0 )) || die "no uncommitted changes in app/ (introduce the bug first)"
for file in "${files[@]}"; do
  if [[ "$file" == */src/test/* || "$file" == *.spec.ts || "$file" == app/e2e/* || "$file" == app/api-tests/* ]]; then
    die "the change touches test code (${file}); a bug must change production code only"
  fi
done

side="backend"
for file in "${files[@]}"; do
  [[ "$file" == app/frontend/* ]] && side="frontend"
done

mkdir -p "$bug_dir"
git diff --no-color -- app/ >"${bug_dir}/patch.diff"
{
  printf 'id: %s\n' "$bug_id"
  printf 'title: TODO one line describing the wrong behaviour (shown only when the bug is missed)\n'
  printf 'hint: TODO what to test, without giving the answer away\n'
  printf 'side: %s              # backend | frontend (what the review rebuilds)\n' "$side"
  printf 'files:\n'
  printf '  - %s\n' "${files[@]}"
} >"${bug_dir}/bug.yml"

printf 'Created %s from these changed files:\n' "${bug_dir#"${ROOT}/"}"
printf '  %s\n' "${files[@]}"
printf 'Check that they all belong to the bug, fill in bug.yml (title, hint), then restore them:\n'
printf '  git checkout --'
printf ' %q' "${files[@]}"
printf '\n'
