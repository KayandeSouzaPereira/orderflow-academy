#!/usr/bin/env bash
# Maintainer helper: prints the "<Class>#<method>" test list of a topic's
# starter (starter/unit and starter/api), the format of original-tests.txt.
#
#   ./scripts/dev/list-tests.sh bonus-ai-review > tracks/bonus-ai-review/original-tests.txt
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/score.sh
source "${ROOT}/scripts/lib/score.sh"
# shellcheck source=../lib/practices.sh
source "${ROOT}/scripts/lib/practices.sh"

topic="${1:?usage: list-tests.sh <track-or-topic-folder under tracks/>}"
starter="${ROOT}/tracks/${topic#tracks/}/starter"
[[ -d "$starter" ]] || { echo "list-tests: ${starter} not found" >&2; exit 3; }

shopt -s nullglob
practice_list_tests "${starter}"/unit/*.java "${starter}"/api/*.java
