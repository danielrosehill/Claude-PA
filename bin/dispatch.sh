#!/usr/bin/env bash
# claude-pa dispatcher — thin router. Fires the configured target for the
# given tier AND the matching signal-bulb pattern in parallel.
#
# Targets:
#   local           → bin/play-local.sh
#   chime           → bin/chime.sh
#   ha:<key>        → bin/pa-send.sh
#   doorbell        → bin/ring-doorbell.sh
#   wake:bedroom    → bin/wake-user.sh
#   twilio:spouse   → bin/pa-call-spouse.sh
#
# Usage: dispatch.sh <tag> [--tier N] [--no-name] [--no-signal]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1

TAG="${1:-}"; shift || true
TIER=0
NAME_FLAG=""
USE_SIGNAL=1
USE_FLASH=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier)      TIER="$2"; shift 2 ;;
    --no-name)   NAME_FLAG="--no-name"; shift ;;
    --no-signal) USE_SIGNAL=0; shift ;;
    --no-flash)  USE_FLASH=0; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$TAG" ]] || { echo "usage: dispatch.sh <tag> [--tier N] [--no-name] [--no-signal] [--no-flash]" >&2; exit 2; }

# Mute / schedule gate. Silent no-op if the system is muted or outside its
# active window. Bypass with CLAUDE_PA_FORCE=1 (used by the test harness, or
# when explicitly running a smoke test from CLI).
if [[ "${CLAUDE_PA_FORCE:-0}" != "1" ]]; then
  if "$SCRIPT_DIR/is-muted.sh" >/dev/null 2>&1; then
    # Optional: log skipped dispatches so the user can see them later.
    if [[ -d "$CLAUDE_PA_LOG_DIR" ]]; then
      printf '%s skip tag=%s tier=%s reason=%s\n' \
        "$(date -Iseconds)" "$TAG" "$TIER" \
        "$("$SCRIPT_DIR/is-muted.sh" --why 2>/dev/null || echo muted)" \
        >> "$CLAUDE_PA_LOG_DIR/dispatch.log" 2>/dev/null || true
    fi
    exit 0
  fi
fi

# Apply tier cap (test harness / safety override)
TIER=$(claude_pa_cap_tier "$TIER")

# Auto-mark idle on attention:* tags fired at tier 0 — this is the signal that
# Claude is now waiting on the user. The escalator daemon picks it up and
# fires higher tiers if no user prompt arrives. Higher-tier calls are assumed
# to come FROM the daemon, so don't rewrite the marker.
if [[ "$TIER" == "0" && "$TAG" == attention:* && "${CLAUDE_PA_FORCE:-0}" != "1" ]]; then
  "$SCRIPT_DIR/mark-idle.sh" "$TAG" >/dev/null 2>&1 || true
fi

MANIFEST="$CLAUDE_PA_MANIFEST"
TIER_DEF=$(jq -r --arg t "$TIER" '.escalation_tiers[$t] // empty' "$MANIFEST")
[[ -n "$TIER_DEF" ]] || { echo "claude-pa: unknown tier $TIER" >&2; exit 3; }

TARGET=$(echo   "$TIER_DEF" | jq -r '.target')
REGISTER=$(echo "$TIER_DEF" | jq -r '.register // "dispatcher"')
USE_NAME=$(echo "$TIER_DEF" | jq -r '.use_name // true')
[[ "$USE_NAME" == "false" ]] && NAME_FLAG="--no-name"

# Fire visual channels in parallel (best-effort, non-blocking, swallows errors).
# signal-bulb (HA RGB lamp) and screen-flash (desktop overlay/notification) both
# read the same per-tag signal_pattern.
PATTERN=$(jq -r --arg t "$TAG" '.tags[$t].signal_pattern // empty' "$MANIFEST")
if [[ -n "$PATTERN" && "$PATTERN" != "null" ]]; then
  if [[ "$USE_SIGNAL" -eq 1 ]]; then
    "$SCRIPT_DIR/signal-bulb.sh" "$PATTERN" >/dev/null 2>&1 &
  fi
  if [[ "$USE_FLASH" -eq 1 ]]; then
    "$SCRIPT_DIR/screen-flash.sh" "$PATTERN" >/dev/null 2>&1 &
  fi
fi

case "$TARGET" in
  local)         exec "$SCRIPT_DIR/play-local.sh"      "$TAG" $NAME_FLAG ;;
  chime)         exec "$SCRIPT_DIR/chime.sh" ;;
  ha:*)
    KEY="${TARGET#ha:}"
    exec "$SCRIPT_DIR/pa-send.sh" "$TAG" "$KEY" --register "$REGISTER" $NAME_FLAG ;;
  mqtt:*)
    KEY="${TARGET#mqtt:}"
    exec "$SCRIPT_DIR/pa-send-mqtt.sh" "$TAG" "$KEY" --register "$REGISTER" $NAME_FLAG ;;
  doorbell)      exec "$SCRIPT_DIR/ring-doorbell.sh" ;;
  wake:bedroom)  exec "$SCRIPT_DIR/wake-user.sh" ;;
  twilio:spouse) exec "$SCRIPT_DIR/pa-call-spouse.sh" --confirm ;;
  *) echo "claude-pa: unknown target '$TARGET' for tier $TIER" >&2; exit 4 ;;
esac
