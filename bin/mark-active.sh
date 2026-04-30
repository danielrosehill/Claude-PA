#!/usr/bin/env bash
# User responded — kill any active escalation by removing the idle marker.
# Wired into Claude Code via the UserPromptSubmit hook.
#
# Reads stdin (Claude passes hook payload as JSON) but ignores it — the mere
# fact that the hook fired means the user typed something.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"

# Drain stdin so Claude Code doesn't see a broken pipe.
[[ -t 0 ]] || cat >/dev/null 2>&1 || true

STATE="$CLAUDE_PA_HOME/escalator/state.json"
[[ -f "$STATE" ]] && rm -f "$STATE"
exit 0
