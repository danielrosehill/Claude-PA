#!/usr/bin/env bash
# claude-pa mute control — pauses the entire dispatch system (audio + signal
# bulb + screen flash + HA + MQTT) by writing a sentinel file the dispatcher
# checks before firing.
#
# State file: $CLAUDE_PA_HOME/mute.json
#   { "until": <unix-ts>, "reason": "<text>", "set_at": <unix-ts> }
#
#   until == 0          → muted indefinitely
#   until > now         → muted until that timestamp (auto-resumes)
#   file absent / until <= now → not muted
#
# Usage:
#   mute.sh status                       — print current state, exit 0 if muted, 1 if not
#   mute.sh off                          — clear mute
#   mute.sh indefinite [--reason TEXT]   — mute until explicitly cleared
#   mute.sh <duration> [--reason TEXT]   — mute for duration (e.g. 30m, 2h, 90s, 1d, "until 17:00")

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_ensure_dirs

MUTE_FILE="$CLAUDE_PA_HOME/mute.json"

cmd="${1:-status}"; shift || true
REASON=""
DURATION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reason) REASON="$2"; shift 2 ;;
    *) DURATION="$1"; shift ;;
  esac
done

now=$(date +%s)

# Parse duration → seconds. Accepts: <N>s|m|h|d, plain N (seconds), or "until HH:MM".
parse_duration() {
  local d="$1"
  if [[ "$d" =~ ^until[[:space:]]+([0-9]{1,2}):([0-9]{2})$ ]]; then
    local hh="${BASH_REMATCH[1]}" mm="${BASH_REMATCH[2]}"
    local target
    target=$(date -d "today $hh:$mm" +%s 2>/dev/null) || return 1
    [[ "$target" -le "$now" ]] && target=$(date -d "tomorrow $hh:$mm" +%s)
    echo "$target"; return 0
  fi
  if [[ "$d" =~ ^([0-9]+)([smhd]?)$ ]]; then
    local n="${BASH_REMATCH[1]}" unit="${BASH_REMATCH[2]:-s}"
    case "$unit" in
      s) echo $(( now + n )) ;;
      m) echo $(( now + n * 60 )) ;;
      h) echo $(( now + n * 3600 )) ;;
      d) echo $(( now + n * 86400 )) ;;
    esac
    return 0
  fi
  return 1
}

case "$cmd" in
  status)
    if [[ ! -f "$MUTE_FILE" ]]; then
      echo "not muted"; exit 1
    fi
    local_until=$(jq -r '.until // 0' "$MUTE_FILE")
    local_reason=$(jq -r '.reason // ""' "$MUTE_FILE")
    if [[ "$local_until" == "0" ]]; then
      echo "muted indefinitely${local_reason:+ — $local_reason}"; exit 0
    elif (( local_until > now )); then
      remaining=$(( local_until - now ))
      until_human=$(date -d "@$local_until" "+%Y-%m-%d %H:%M:%S")
      echo "muted until $until_human (${remaining}s remaining)${local_reason:+ — $local_reason}"
      exit 0
    else
      echo "not muted (sentinel expired)"; exit 1
    fi
    ;;

  off|unmute|clear|resume)
    rm -f "$MUTE_FILE"
    echo "claude-pa: unmuted"
    ;;

  indefinite|forever|disable)
    jq -nc \
      --argjson until 0 \
      --argjson set_at "$now" \
      --arg reason "$REASON" \
      '{until:$until, set_at:$set_at, reason:$reason}' > "$MUTE_FILE"
    echo "claude-pa: muted indefinitely${REASON:+ — $REASON}"
    echo "           unmute with: $0 off"
    ;;

  pause|mute)
    [[ -n "$DURATION" ]] || { echo "usage: $0 pause <duration> [--reason TEXT]" >&2; exit 2; }
    until_ts=$(parse_duration "$DURATION") || {
      echo "claude-pa: invalid duration '$DURATION' (try: 30m, 2h, 90s, 1d, 'until 17:00')" >&2; exit 2; }
    jq -nc \
      --argjson until "$until_ts" \
      --argjson set_at "$now" \
      --arg reason "$REASON" \
      '{until:$until, set_at:$set_at, reason:$reason}' > "$MUTE_FILE"
    echo "claude-pa: muted until $(date -d "@$until_ts" "+%Y-%m-%d %H:%M:%S")${REASON:+ — $REASON}"
    ;;

  *)
    # Bare duration shortcut: `mute.sh 30m` == `mute.sh pause 30m`
    if until_ts=$(parse_duration "$cmd" 2>/dev/null); then
      jq -nc \
        --argjson until "$until_ts" \
        --argjson set_at "$now" \
        --arg reason "$REASON" \
        '{until:$until, set_at:$set_at, reason:$reason}' > "$MUTE_FILE"
      echo "claude-pa: muted until $(date -d "@$until_ts" "+%Y-%m-%d %H:%M:%S")${REASON:+ — $REASON}"
    else
      echo "usage: $0 {status|off|indefinite|pause <duration>} [--reason TEXT]" >&2
      exit 2
    fi
    ;;
esac
