#!/usr/bin/env bash
# claude-pa night-time wake — flashes bedroom lights via Home Assistant.
#
# Refuses to fire unless ALL of these are true:
#   - config.wake.enabled == true (explicit opt-in)
#   - current time is within config.wake.night_hours (default 23:00–07:00)
#   - config.home_assistant.enabled == true
#   - $HASS_TOKEN is set
#
# Usage: wake-user.sh [--force]
#   --force  bypass the night-hours check (still requires wake.enabled=true)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1
CONFIG="$CLAUDE_PA_CONFIG_FILE"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

WAKE_ENABLED=$(jq -r '.wake.enabled // false' "$CONFIG")
if [[ "$WAKE_ENABLED" != "true" ]]; then
  echo "claude-pa: wake.enabled=false; refusing to flash lights." >&2
  exit 10
fi

HA_ENABLED=$(jq -r '.home_assistant.enabled // false' "$CONFIG")
[[ "$HA_ENABLED" == "true" ]] || { echo "claude-pa: HA disabled; cannot reach lights." >&2; exit 11; }

# Night-hours gate
if [[ "$FORCE" -eq 0 ]]; then
  START=$(jq -r '.wake.night_hours.start // "23:00"' "$CONFIG")
  END=$(jq -r '.wake.night_hours.end // "07:00"' "$CONFIG")
  NOW=$(date +%H:%M)
  # Window may wrap midnight
  if [[ "$START" < "$END" ]]; then
    [[ "$NOW" > "$START" && "$NOW" < "$END" ]] || { echo "claude-pa: outside night hours ($START–$END); skipping wake."; exit 12; }
  else
    [[ "$NOW" > "$START" || "$NOW" < "$END" ]] || { echo "claude-pa: outside night hours ($START–$END); skipping wake."; exit 12; }
  fi
fi

BASE_URL=$(jq -r '.home_assistant.base_url' "$CONFIG")
TOKEN_ENV=$(jq -r '.home_assistant.token_env // "HASS_TOKEN"' "$CONFIG")
TOKEN="${!TOKEN_ENV:-}"
[[ -n "$TOKEN" ]] || { echo "claude-pa: \$$TOKEN_ENV not set" >&2; exit 1; }

LIGHT=$(jq -r '.wake.bedroom_light_entity // ""' "$CONFIG")
[[ -n "$LIGHT" ]] || { echo "claude-pa: wake.bedroom_light_entity not set" >&2; exit 2; }

FLASH_COUNT=$(jq -r '.wake.flash_count // 4' "$CONFIG")
FLASH_INTERVAL=$(jq -r '.wake.flash_interval_seconds // 0.6' "$CONFIG")

call_ha() {
  local service="$1" body="$2"
  curl -sf -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$body" "$BASE_URL/api/services/$service" >/dev/null
}

# Capture initial state so we can restore
INITIAL=$(curl -sf -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/states/$LIGHT" | jq -r '.state // "off"')

echo "claude-pa: 🌙 wake sequence — flashing $LIGHT $FLASH_COUNT times"
for ((i=0; i<FLASH_COUNT; i++)); do
  call_ha "light/turn_on"  "{\"entity_id\": \"$LIGHT\", \"brightness\": 255}"
  sleep "$FLASH_INTERVAL"
  call_ha "light/turn_off" "{\"entity_id\": \"$LIGHT\"}"
  sleep "$FLASH_INTERVAL"
done

# Restore
if [[ "$INITIAL" == "on" ]]; then
  call_ha "light/turn_on" "{\"entity_id\": \"$LIGHT\"}"
fi

echo "claude-pa: wake complete (restored to $INITIAL)"
