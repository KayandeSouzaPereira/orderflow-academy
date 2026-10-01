#!/usr/bin/env bash
# Maintainer helper for topic B-02: creates the two exercise branches whose
# merge produces a conflict in app/api-tests/TEAM-NOTES.md.
#
#   ./scripts/dev/create-b02-exercise.sh [--push] [<base-ref>]
#
# Both branches start from <base-ref> (default: main) and change the same
# line of TEAM-NOTES.md in different ways. --push sends them to origin.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PUSH=0
BASE="main"
for arg in "$@"; do
  case "$arg" in
    --push) PUSH=1 ;;
    *) BASE="$arg" ;;
  esac
done

NOTES="app/api-tests/TEAM-NOTES.md"
LINE="- API base URL: http://localhost:8080"

create_branch() {
  local branch="$1" replacement="$2" message="$3" worktree
  worktree="$(mktemp -d "${TMPDIR:-/tmp}/b02-exercise.XXXXXX")"
  git -C "$ROOT" worktree add -q -B "$branch" "$worktree" "$BASE"
  grep -qxF -- "$LINE" "${worktree}/${NOTES}" || { echo "line not found in ${NOTES} on ${BASE}" >&2; exit 3; }
  sed -i.bak "s|^- API base URL: http://localhost:8080\$|${replacement}|" "${worktree}/${NOTES}"
  rm -f "${worktree}/${NOTES}.bak"
  git -C "$worktree" commit -q -am "$message"
  git -C "$ROOT" worktree remove --force "$worktree"
  echo "created ${branch}"
}

create_branch exercise/b02-conflict-a \
  "- API base URL: http://localhost:8080 (set API_BASE_URL to change it)" \
  "docs(api-tests): explain how to change the API base URL"
create_branch exercise/b02-conflict-b \
  "- API base URL: http://localhost:8080 (review stack: http://localhost:18080)" \
  "docs(api-tests): document the review stack URL"

if (( PUSH == 1 )); then
  git -C "$ROOT" push -f origin exercise/b02-conflict-a exercise/b02-conflict-b
fi
