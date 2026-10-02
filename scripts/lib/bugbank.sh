# shellcheck shell=bash
# -----------------------------------------------------------------------------
# Bug bank: variants of the app with one planted bug each.
#
#   tracks/<track>/<topic>/bugs/BUG-NN/bug.yml     id, title, hint, side, files
#   tracks/<track>/<topic>/bugs/BUG-NN/patch.diff  git diff made from the repo root
#
#   bugbank_list <topic-dir>          prints the bug folders, sorted
#   bugbank_field <bug-dir> <field>   reads a field of bug.yml
#   bugbank_apply <bug-dir>           applies the patch to the workspace (returns 1 if it does not apply)
#   bugbank_restore                   puts back the files the last patch touched
# -----------------------------------------------------------------------------

BUGBANK_BACKUP=""
BUGBANK_TOUCHED=()

bugbank_list() {
  local dir="$1/bugs"
  [[ -d "$dir" ]] || return 0
  find "$dir" -mindepth 1 -maxdepth 1 -type d -name 'BUG-*' | sort
}

bugbank_field() {
  local bug_dir="$1" field="$2"
  yq -r ".${field} // \"\"" "${bug_dir}/bug.yml"
}

bugbank_apply() {
  local bug_dir="$1" patch file
  patch="$(cd "$bug_dir" && pwd)/patch.diff"
  [[ -f "$patch" && -f "${bug_dir}/bug.yml" ]] || return 1

  # Files the patch touches, relative to the repository root.
  mapfile -t BUGBANK_TOUCHED < <(cd "$REVIEW_WORKSPACE" && git apply --numstat "$patch" 2>/dev/null | cut -f3)
  (( ${#BUGBANK_TOUCHED[@]} > 0 )) || return 1

  BUGBANK_BACKUP="${REVIEW_WORKSPACE}/.bugbank-backup"
  rm -rf "$BUGBANK_BACKUP"
  mkdir -p "$BUGBANK_BACKUP"
  for file in "${BUGBANK_TOUCHED[@]}"; do
    if [[ -f "${REVIEW_WORKSPACE}/${file}" ]]; then
      mkdir -p "${BUGBANK_BACKUP}/$(dirname "$file")"
      cp "${REVIEW_WORKSPACE}/${file}" "${BUGBANK_BACKUP}/${file}"
    fi
  done

  (cd "$REVIEW_WORKSPACE" && git apply -p1 --whitespace=nowarn "$patch" 2>/dev/null)
}

bugbank_restore() {
  local file
  for file in "${BUGBANK_TOUCHED[@]}"; do
    if [[ -f "${BUGBANK_BACKUP}/${file}" ]]; then
      cp "${BUGBANK_BACKUP}/${file}" "${REVIEW_WORKSPACE}/${file}"
    else
      # The patch created this file.
      rm -f "${REVIEW_WORKSPACE}/${file}"
    fi
  done
  BUGBANK_TOUCHED=()
  rm -rf "$BUGBANK_BACKUP"
}
