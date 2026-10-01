#!/usr/bin/env bash
# Review of B-02: reads the Git history of the current branch (your
# participant branch) and checks the workflow described in the README.
#
#   ./scripts/review.sh b-integration-testing/02-git-workflow [--json] [--overlay <dir>]
#
# --overlay <dir> reviews <dir>/repo.bundle instead (branch participant/test),
# which is how maintainers check the reference and calibration histories.
set -euo pipefail

TOPIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$TOPIC_DIR"
while [[ ! -f "${ROOT}/scripts/lib/score.sh" && "$ROOT" != "/" ]]; do ROOT="$(dirname "$ROOT")"; done
# shellcheck source=../../../scripts/lib/score.sh
source "${ROOT}/scripts/lib/score.sh"
# shellcheck source=../../../scripts/lib/common.sh
source "${ROOT}/scripts/lib/common.sh"

OVERLAY=""
while (( $# > 0 )); do
  case "$1" in
    --json) export SCORE_JSON=1 ;;
    --quick) ;; # nothing slow to skip
    --overlay) OVERLAY="${2:?--overlay needs a directory}"; shift ;;
    *) score_fatal "unknown option '$1'" "Options: --json, --overlay <dir>." ;;
  esac
  shift
done

review_require_bash
review_require_tools git jq yq
review_install_traps
score_begin "$TOPIC_DIR"

setting() {
  yq -r ".git.$1 // \"\"" "${TOPIC_DIR}/topic.yml"
}

# --- Which repository and refs -----------------------------------------------

REPO="$SCORE_REPO_ROOT"
REMOTE_PREFIX="origin/"
if [[ -n "$OVERLAY" ]]; then
  [[ -f "${OVERLAY}/repo.bundle" ]] || score_fatal "no repo.bundle in ${OVERLAY}" "The overlay of B-02 is a Git bundle."
  review_workspace_create
  REPO="${REVIEW_WORKSPACE}/repo"
  git clone -q "${OVERLAY}/repo.bundle" "$REPO"
  git -C "$REPO" checkout -q participant/test
fi

# Resolves a branch as origin/<name>, or <name> when only the local one exists.
ref_of() {
  local name="$1"
  if git -C "$REPO" rev-parse -q --verify "${REMOTE_PREFIX}${name}^{commit}" >/dev/null; then
    echo "${REMOTE_PREFIX}${name}"
  elif git -C "$REPO" rev-parse -q --verify "${name}^{commit}" >/dev/null; then
    echo "$name"
  fi
}

MAIN="$(ref_of main)"
[[ -n "$MAIN" ]] || score_fatal "branch main not found" "Run 'git fetch origin' and try again."
BASE="$(git -C "$REPO" merge-base HEAD "$MAIN")"
RANGE="${BASE}..HEAD"

COMMITS="$(git -C "$REPO" rev-list --count --no-merges "$RANGE")"
if (( COMMITS == 0 )); then
  score_hint "start" "Commit your work on your topic branch (see the README), then review again."
  score_gate false "no commits of yours since main"
fi
score_gate true "${COMMITS} commits since main"

passed=0
checks=5

# 1. Conventional Commits
pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9._/-]+\))?!?: .+'
valid="$(git -C "$REPO" log --no-merges --format=%s "$RANGE" | grep -cE "$pattern" || true)"
min_commits="$(setting min_commits)"
percent=$(( valid * 100 / COMMITS ))
if (( COMMITS >= min_commits && percent >= $(setting conventional_percent) )); then
  passed=$(( passed + 1 ))
else
  wrong="$(git -C "$REPO" log --no-merges --format='%h %s' "$RANGE" | grep -vE "^[0-9a-f]+ ${pattern#^}" | head -n 3 | paste -sd ';' - | sed 's/;/; /g')"
  score_hint "conventional-commits" "Write commit messages as type(scope): summary, e.g. 'test(api-tests): cover order creation'. Not following it: ${wrong:-none}" \
    "${valid} of ${COMMITS} commits follow Conventional Commits (need ${min_commits}+ commits and $(setting conventional_percent)%)"
fi

# 2. Both exercise branches merged
missing=()
while IFS= read -r branch; do
  [[ -n "$branch" ]] || continue
  ref="$(ref_of "$branch")"
  if [[ -z "$ref" ]]; then
    score_fatal "branch ${branch} not found" "Run 'git fetch origin' to get the exercise branches."
  fi
  git -C "$REPO" merge-base --is-ancestor "$ref" HEAD || missing+=("$branch")
done < <(yq -r '.git.exercise_branches[]' "${TOPIC_DIR}/topic.yml")
if (( ${#missing[@]} == 0 )); then
  passed=$(( passed + 1 ))
else
  score_hint "exercise-branches" "Merge both exercise branches into your topic branch: git merge origin/<branch>." \
    "not merged yet: ${missing[*]}"
fi

# 3. Conflict resolved with the expected content
notes="$(setting notes_file)"
content="$(git -C "$REPO" show "HEAD:${notes}" 2>/dev/null || true)"
if grep -qE '^(<<<<<<<|=======|>>>>>>>)' <<<"$content"; then
  score_hint "conflict" "Remove the conflict markers (<<<<<<<, =======, >>>>>>>) and keep one line, as the README describes." \
    "${notes} still has conflict markers"
elif grep -qxF -- "$(setting expected_line)" <<<"$content"; then
  passed=$(( passed + 1 ))
else
  score_hint "conflict" "Resolve the conflict by keeping both pieces of information in one line, exactly as the README shows." \
    "${notes} does not have the expected resolved line"
fi

# 4. Topic branch integrated through a merge (pull request)
topic_branch="$(setting topic_branch)"
if git -C "$REPO" log --merges --format=%s "$RANGE" | grep -qiE "(pull request|merge branch).*${topic_branch}"; then
  passed=$(( passed + 1 ))
else
  score_hint "pull-request" "Open a pull request from your topic branch (…/${topic_branch}) to your participant branch and merge it after the review." \
    "no merge of a ${topic_branch} branch found"
fi

# 5. Only allowed paths changed
mapfile -t allowed < <(yq -r '.git.allowed_paths[]' "${TOPIC_DIR}/topic.yml")
outside=()
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  ok=0
  for prefix in "${allowed[@]}"; do
    [[ "$file" == "$prefix"* ]] && { ok=1; break; }
  done
  (( ok == 1 )) || outside+=("$file")
done < <(git -C "$REPO" diff --name-only "$BASE" HEAD)
if (( ${#outside[@]} == 0 )); then
  passed=$(( passed + 1 ))
else
  score_hint "paths" "Keep your changes in your own areas (${allowed[*]}). Revert the others." \
    "changed outside the allowed folders: ${outside[*]:0:3}"
fi

score_criterion "Git workflow" $(( passed * 100 / checks )) 100 "${passed}/${checks}"
score_end
