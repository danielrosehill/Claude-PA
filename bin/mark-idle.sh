#!/usr/bin/env bash
# Mark Claude as waiting on the user. Writes the escalator state file so the
# daemon will fire higher tiers if the user doesn't respond. Idempotent —
# repeated calls within an active idle window do NOT reset the clock unless
# --reset is passed.
#
# Usage:
#   mark-idle.sh <tag>            # start an idle window for <tag>, or no-op if already idle
#   mark-idle.sh <tag> --reset    # always reset the timer to now
#
# Called by:
#   - bin/dispatch.sh (auto, on attention:* tags)
#   - Notification hook (if user wires it)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"

TAG="${1:-}"
RESET=0
if [[ "${2:-}" == "--reset" ]]; then RESET=1; fi
[[ -n "$TAG" ]] || { echo "usage: mark-idle.sh <tag> [--reset]" >&2; exit 2; }

ESC_DIR="$CLAUDE_PA_HOME/escalator"
STATE="$ESC_DIR/state.json"
mkdir -p "$ESC_DIR"

NOW=$(date +%s.%N)

if [[ -f "$STATE" && "$RESET" -eq 0 ]]; then
  # Refresh tag only — preserve idle_since and fired list.
  jq --arg tag "$TAG" '.tag = $tag' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
else
  jq -n --arg tag "$TAG" --argjson since "$NOW" \
    '{idle_since: $since, tag: $tag, fired: []}' > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
fi
