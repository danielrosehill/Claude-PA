#!/usr/bin/env bash
# claude-pa Claude-signal bulb — continuous visual status channel.
#
# Distinct from the audio escalation cascade. The signal bulb is an RGB lamp
# (or group of lamps) that Claude updates AS STATE CHANGES, so the user has
# peripheral-vision awareness of what Claude is doing without looking at the
# terminal:
#
#   thinking  → slow blue pulse
#   waiting   → amber breathing (Claude is blocked on the user)
#   working   → soft cyan steady (a task is running)
#   done      → green flash 2× then off
#   error     → red strobe 3× then off
#   clear     → turn off / restore
#
# Refuses to fire unless config.signal_bulb.enabled == true and an entity
# is configured.
#
# Usage: signal-bulb.sh <pattern>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1

PATTERN="${1:?usage: signal-bulb.sh <thinking|waiting|working|done|error|clear>}"
CONFIG="$CLAUDE_PA_CONFIG_FILE"

ENABLED=$(jq -r '.signal_bulb.enabled // false' "$CONFIG")
[[ "$ENABLED" == "true" ]] || { echo "claude-pa: signal_bulb.enabled=false" >&2; exit 10; }

ENTITY=$(jq -r '.signal_bulb.entity // ""' "$CONFIG")
[[ -n "$ENTITY" ]] || { echo "claude-pa: signal_bulb.entity not set" >&2; exit 12; }

BASE_URL=$(jq -r '.home_assistant.base_url' "$CONFIG")
TOKEN_ENV=$(jq -r '.home_assistant.token_env // "HASS_TOKEN"' "$CONFIG")
TOKEN="${!TOKEN_ENV:-}"
[[ -n "$TOKEN" ]] || { echo "claude-pa: \$$TOKEN_ENV not set" >&2; exit 1; }

ha() {
  local service="$1" body="$2"
  curl -sf -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$body" "$BASE_URL/api/services/$service" >/dev/null
}

# RGB triplets (kept simple — HA flux/effect would be richer but less portable)
case "$PATTERN" in
  thinking)
    ha "light/turn_on" "{\"entity_id\":\"$ENTITY\",\"rgb_color\":[40,90,255],\"brightness\":120,\"transition\":2}"
    ;;
  waiting)
    ha "light/turn_on" "{\"entity_id\":\"$ENTITY\",\"rgb_color\":[255,170,30],\"brightness\":180,\"transition\":1}"
    ;;
  working)
    ha "light/turn_on" "{\"entity_id\":\"$ENTITY\",\"rgb_color\":[60,200,200],\"brightness\":90,\"transition\":1}"
    ;;
  done)
    for _ in 1 2; do
      ha "light/turn_on"  "{\"entity_id\":\"$ENTITY\",\"rgb_color\":[40,255,80],\"brightness\":255,\"transition\":0}"
      sleep 0.3
      ha "light/turn_off" "{\"entity_id\":\"$ENTITY\",\"transition\":0}"
      sleep 0.2
    done
    ;;
  error)
    for _ in 1 2 3; do
      ha "light/turn_on"  "{\"entity_id\":\"$ENTITY\",\"rgb_color\":[255,30,30],\"brightness\":255,\"transition\":0}"
      sleep 0.15
      ha "light/turn_off" "{\"entity_id\":\"$ENTITY\",\"transition\":0}"
      sleep 0.15
    done
    ;;
  clear|off)
    ha "light/turn_off" "{\"entity_id\":\"$ENTITY\",\"transition\":1}"
    ;;
  *)
    echo "claude-pa: unknown pattern '$PATTERN'" >&2
    echo "available: thinking, waiting, working, done, error, clear" >&2
    exit 2 ;;
esac

echo "claude-pa: 💡 signal-bulb → $PATTERN"
