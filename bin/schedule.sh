#!/usr/bin/env bash
# claude-pa active-window schedule — declares when the PA system is allowed
# to fire. Outside the active window the dispatcher treats the system as
# muted (silent no-op).
#
# Two flavours, both stored in $CLAUDE_PA_HOME/schedule.json:
#
# 1. Recurring time-of-day windows:
#    {
#      "mode": "windows",
#      "windows": [
#        {"start": "09:00", "end": "17:00",
#         "days": ["mon","tue","wed","thu","fri"]}
#      ]
#    }
#
# 2. Session-scoped "active for the next N minutes" (pairs naturally with
#    Claude's task-planning pattern: enable while planning/executing, fall
#    silent when the task wraps):
#    {
#      "mode": "session",
#      "active_until": <unix-ts>,
#      "label": "..."
#    }
#
# The dispatcher checks bin/is-muted.sh which combines mute.json + schedule.json.
#
# Usage:
#   schedule.sh status
#   schedule.sh off                                  — clear all schedule rules
#   schedule.sh during <duration> [--label TEXT]    — session mode (e.g. 90m, 2h)
#   schedule.sh windows <SPEC> [<SPEC> ...]          — recurring mode
#       SPEC := DAYS:HH:MM-HH:MM   e.g. mon-fri:09:00-17:00, sat:10:00-12:00
#       DAYS := comma list of mon|tue|wed|thu|fri|sat|sun, or DAY-DAY range,
#               or 'weekdays', 'weekends', 'all'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_ensure_dirs

SCHED_FILE="$CLAUDE_PA_HOME/schedule.json"
now=$(date +%s)

DAY_NAMES=(sun mon tue wed thu fri sat)

expand_days() {
  local input="$1" out=()
  case "$input" in
    all) out=(sun mon tue wed thu fri sat) ;;
    weekdays) out=(mon tue wed thu fri) ;;
    weekends) out=(sat sun) ;;
    *)
      IFS=',' read -ra parts <<<"$input"
      for p in "${parts[@]}"; do
        if [[ "$p" =~ ^([a-z]{3})-([a-z]{3})$ ]]; then
          local from="${BASH_REMATCH[1]}" to="${BASH_REMATCH[2]}"
          local fi=-1 ti=-1
          for i in "${!DAY_NAMES[@]}"; do
            [[ "${DAY_NAMES[$i]}" == "$from" ]] && fi=$i
            [[ "${DAY_NAMES[$i]}" == "$to"   ]] && ti=$i
          done
          [[ "$fi" -ge 0 && "$ti" -ge 0 ]] || { echo "bad day range: $p" >&2; return 1; }
          local i=$fi
          while :; do
            out+=("${DAY_NAMES[$i]}")
            [[ "$i" -eq "$ti" ]] && break
            i=$(( (i + 1) % 7 ))
          done
        else
          out+=("$p")
        fi
      done
      ;;
  esac
  printf '%s\n' "${out[@]}" | jq -R . | jq -sc .
}

parse_window_spec() {
  local spec="$1"
  if [[ "$spec" =~ ^(.+):([0-9]{1,2}:[0-9]{2})-([0-9]{1,2}:[0-9]{2})$ ]]; then
    local days="${BASH_REMATCH[1]}" start="${BASH_REMATCH[2]}" end="${BASH_REMATCH[3]}"
    local days_json
    days_json=$(expand_days "$days") || return 1
    jq -nc --arg start "$start" --arg end "$end" --argjson days "$days_json" \
      '{start:$start, end:$end, days:$days}'
  else
    echo "bad window spec: $spec (expected DAYS:HH:MM-HH:MM)" >&2; return 1
  fi
}

cmd="${1:-status}"; shift || true

case "$cmd" in
  status)
    if [[ ! -f "$SCHED_FILE" ]]; then
      echo "no schedule (PA always allowed unless muted)"; exit 0
    fi
    cat "$SCHED_FILE" | jq .
    "$SCRIPT_DIR/is-muted.sh" >/dev/null 2>&1 \
      && echo "currently: OUTSIDE active window (silent)" \
      || echo "currently: ACTIVE"
    ;;

  off|clear|disable)
    rm -f "$SCHED_FILE"
    echo "claude-pa: schedule cleared (always allowed unless muted)"
    ;;

  during|session)
    duration="${1:?usage: schedule.sh during <duration> [--label TEXT]}"; shift
    LABEL=""
    while [[ $# -gt 0 ]]; do
      case "$1" in --label) LABEL="$2"; shift 2 ;; *) shift ;; esac
    done
    until_ts=$("$SCRIPT_DIR/mute.sh" --print-duration "$duration" 2>/dev/null) || {
      # fall back: parse here
      if [[ "$duration" =~ ^([0-9]+)([smhd]?)$ ]]; then
        n="${BASH_REMATCH[1]}"; unit="${BASH_REMATCH[2]:-s}"
        case "$unit" in
          s) until_ts=$((now+n)) ;;
          m) until_ts=$((now+n*60)) ;;
          h) until_ts=$((now+n*3600)) ;;
          d) until_ts=$((now+n*86400)) ;;
        esac
      else
        echo "bad duration: $duration" >&2; exit 2
      fi
    }
    jq -nc \
      --arg mode "session" \
      --argjson active_until "$until_ts" \
      --arg label "$LABEL" \
      '{mode:$mode, active_until:$active_until, label:$label}' > "$SCHED_FILE"
    echo "claude-pa: active until $(date -d "@$until_ts" "+%Y-%m-%d %H:%M:%S")${LABEL:+ — $LABEL}"
    ;;

  windows|recurring)
    [[ $# -gt 0 ]] || { echo "usage: schedule.sh windows <SPEC> [<SPEC> ...]" >&2; exit 2; }
    windows="[]"
    for spec in "$@"; do
      win=$(parse_window_spec "$spec") || exit 2
      windows=$(jq -c --argjson w "$win" '. + [$w]' <<<"$windows")
    done
    jq -nc --arg mode "windows" --argjson windows "$windows" \
      '{mode:$mode, windows:$windows}' > "$SCHED_FILE"
    echo "claude-pa: recurring schedule set"
    jq . "$SCHED_FILE"
    ;;

  *)
    echo "usage: $0 {status|off|during <duration>|windows <SPEC>...}" >&2
    exit 2
    ;;
esac
