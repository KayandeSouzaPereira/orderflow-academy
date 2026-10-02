#!/usr/bin/env bash
# Review of this topic: the standard flow with the settings in topic.yml.
set -euo pipefail

TOPIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$TOPIC_DIR"
while [[ ! -f "${ROOT}/scripts/lib/standard.sh" && "$ROOT" != "/" ]]; do ROOT="$(dirname "$ROOT")"; done
# shellcheck source=../../../scripts/lib/standard.sh
source "${ROOT}/scripts/lib/standard.sh"

review_standard "$TOPIC_DIR" "$@"
