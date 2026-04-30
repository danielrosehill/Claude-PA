#!/usr/bin/env bash
# claude-pa usage monitor — polls Claude Code session data and fires a
# dispatch on threshold crossings (50%, 75%, 90%, 95%, hit).
#
# Designed to be invoked from a Claude Code 'Stop' hook (so it runs after
# every assistant turn) or as a periodic cron.
#
# State: $CLAUDE_PA_HOME/state/usage-thresholds-fired.json
#   tracks which thresholds have already fired this session, so we don't
#   bark every turn. Reset when a new session starts.
#
# Usage source: Claude Code writes session data under
#   ~/.claude/projects/<encoded-cwd>/<session-id>.jsonl
# and exposes cost via the /cost slash command. Per-session token usage
# can be summed from those JSONL files. The HARD limit (account-level)
# is not directly exposed — config.usage_monitor.session_token_budget
# defines what 100% means for THIS session.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1

CONFIG="$CLAUDE_PA_CONFIG_FILE"
ENABLED=$(jq -r '.usage_monitor.enabled // false' "$CONFIG")
[[ "$ENABLED" == "true" ]] || exit 0

BUDGET=$(jq -r '.usage_monitor.session_token_budget // 200000' "$CONFIG")
SESSION_ID="${CLAUDE_SESSION_ID:-}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Resolve the session JSONL. Claude Code encodes cwd as the dir name with
# slashes replaced by dashes. If $CLAUDE_SESSION_ID isn't set, take the
# most recently modified JSONL under ~/.claude/projects/<encoded>/.
ENCODED=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
SESSIONS_DIR="$HOME/.claude/projects/${ENCODED#-}"
[[ -d "$SESSIONS_DIR" ]] || SESSIONS_DIR="$HOME/.claude/projects/$ENCODED"

if [[ -n "$SESSION_ID" && -f "$SESSIONS_DIR/$SESSION_ID.jsonl" ]]; then
  SESSION_FILE="$SESSIONS_DIR/$SESSION_ID.jsonl"
else
  SESSION_FILE=$(ls -t "$SESSIONS_DIR"/*.jsonl 2>/dev/null | head -1)
fi

[[ -n "$SESSION_FILE" && -f "$SESSION_FILE" ]] || { echo "claude-pa: no session file found" >&2; exit 0; }

# Sum usage tokens from assistant messages in the JSONL.
USED=$(jq -r '
  select(.type=="assistant") | .message.usage |
  ((.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))
' "$SESSION_FILE" 2>/dev/null | awk '{s+=$1} END {print s+0}')

PCT=$(awk -v u="$USED" -v b="$BUDGET" 'BEGIN { if (b > 0) printf "%d", (u*100)/b; else print 0 }')

# Threshold ladder
mkdir -p "$CLAUDE_PA_HOME/state"
STATE_FILE="$CLAUDE_PA_HOME/state/usage-thresholds-fired.json"
SESSION_KEY=$(basename "$SESSION_FILE" .jsonl)

# Reset state if session changed
PREV_KEY=$(jq -r '.session // ""' "$STATE_FILE" 2>/dev/null || echo "")
if [[ "$PREV_KEY" != "$SESSION_KEY" ]]; then
  echo "{\"session\":\"$SESSION_KEY\",\"fired\":[]}" > "$STATE_FILE"
fi

fire() {
  local tag="$1" threshold="$2"
  local already
  already=$(jq -r --arg t "$threshold" '.fired | index($t)' "$STATE_FILE")
  [[ "$already" == "null" ]] || return 0
  jq --arg t "$threshold" '.fired += [$t]' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
  "$SCRIPT_DIR/dispatch.sh" "$tag"
}

if   [[ "$PCT" -ge 95 ]]; then fire "usage:limit-imminent" "95"
elif [[ "$PCT" -ge 90 ]]; then fire "usage:warning-90"     "90"
elif [[ "$PCT" -ge 75 ]]; then fire "usage:warning-75"     "75"
elif [[ "$PCT" -ge 50 ]]; then fire "usage:warning-50"     "50"
fi

# Log
echo "$(date -Iseconds) session=$SESSION_KEY used=$USED budget=$BUDGET pct=$PCT" >> "$CLAUDE_PA_LOG_DIR/usage.log"
