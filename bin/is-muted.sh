#!/usr/bin/env bash
# claude-pa muted-state check — combines mute.json + schedule.json into a
# single boolean. Exits 0 if the system should be silent, 1 if it should fire.
# Sourced by dispatch.sh as a fast gate.
#
# Decision order:
#   1. Explicit mute (mute.json with until==0 or until>now) → muted
#   2. Schedule mode == "session" with active_until>now      → ACTIVE
#   3. Schedule mode == "session" with active_until<=now     → muted (expired session)
#   4. Schedule mode == "windows" — check current weekday/time against windows → muted if outside
#   5. No mute, no schedule                                  → ACTIVE

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"

MUTE_FILE="$CLAUDE_PA_HOME/mute.json"
SCHED_FILE="$CLAUDE_PA_HOME/schedule.json"
now=$(date +%s)

# 1. Explicit mute
if [[ -f "$MUTE_FILE" ]]; then
  until_ts=$(jq -r '.until // 0' "$MUTE_FILE")
  if [[ "$until_ts" == "0" ]]; then
    [[ "${1:-}" == "--why" ]] && echo "muted indefinitely"
    exit 0
  elif (( until_ts > now )); then
    [[ "${1:-}" == "--why" ]] && echo "muted until $(date -d "@$until_ts" '+%H:%M:%S')"
    exit 0
  fi
fi

# 2-4. Schedule
if [[ -f "$SCHED_FILE" ]]; then
  mode=$(jq -r '.mode // ""' "$SCHED_FILE")
  case "$mode" in
    session)
      active_until=$(jq -r '.active_until // 0' "$SCHED_FILE")
      if (( active_until > now )); then
        [[ "${1:-}" == "--why" ]] && echo "active session until $(date -d "@$active_until" '+%H:%M:%S')"
        exit 1
      else
        [[ "${1:-}" == "--why" ]] && echo "session expired at $(date -d "@$active_until" '+%H:%M:%S')"
        exit 0
      fi
      ;;
    windows)
      today=$(date +%a | tr '[:upper:]' '[:lower:]')   # mon, tue, ...
      hhmm=$(date +%H:%M)
      hit=$(jq -r --arg day "$today" --arg now "$hhmm" '
        [.windows[]
          | select(.days | index($day))
          | select($now >= .start and $now < .end)
        ] | length' "$SCHED_FILE")
      if (( hit > 0 )); then
        [[ "${1:-}" == "--why" ]] && echo "inside active window"
        exit 1
      else
        [[ "${1:-}" == "--why" ]] && echo "outside active windows ($today $hhmm)"
        exit 0
      fi
      ;;
  esac
fi

# 5. Default: active
[[ "${1:-}" == "--why" ]] && echo "no mute, no schedule"
exit 1
