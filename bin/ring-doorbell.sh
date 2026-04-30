#!/usr/bin/env bash
# claude-pa doorbell tier — triggers a Home Assistant entity that rings the
# physical doorbell (or a smart-plug-attached chime, or a script.doorbell).
#
# Pavlovian gold: you will run to the front door before you remember you live
# with an AI dispatcher.
#
# Refuses to fire unless ALL of these are true:
#   - config.doorbell.enabled == true (explicit opt-in)
#   - config.doorbell.entity is set
#   - config.home_assistant.enabled == true
#   - $HASS_TOKEN is set

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1
CONFIG="$CLAUDE_PA_CONFIG_FILE"

ENABLED=$(jq -r '.doorbell.enabled // false' "$CONFIG")
[[ "$ENABLED" == "true" ]] || { echo "claude-pa: doorbell.enabled=false; skipping." >&2; exit 10; }

HA_ENABLED=$(jq -r '.home_assistant.enabled // false' "$CONFIG")
[[ "$HA_ENABLED" == "true" ]] || { echo "claude-pa: HA disabled; cannot ring doorbell." >&2; exit 11; }

ENTITY=$(jq -r '.doorbell.entity // ""' "$CONFIG")
[[ -n "$ENTITY" ]] || { echo "claude-pa: doorbell.entity not set" >&2; exit 12; }

# Service depends on entity domain (script, switch, button, etc.)
DOMAIN="${ENTITY%%.*}"
case "$DOMAIN" in
  script)            SERVICE="script/turn_on" ;;
  switch)            SERVICE="switch/turn_on" ;;
  button|input_button) SERVICE="$DOMAIN/press" ;;
  automation)        SERVICE="automation/trigger" ;;
  *)                 SERVICE=$(jq -r '.doorbell.service // "homeassistant/turn_on"' "$CONFIG") ;;
esac

BASE_URL=$(jq -r '.home_assistant.base_url' "$CONFIG")
TOKEN_ENV=$(jq -r '.home_assistant.token_env // "HASS_TOKEN"' "$CONFIG")
TOKEN="${!TOKEN_ENV:-}"
[[ -n "$TOKEN" ]] || { echo "claude-pa: \$$TOKEN_ENV not set" >&2; exit 1; }

RINGS=$(jq -r '.doorbell.rings // 1' "$CONFIG")
INTERVAL=$(jq -r '.doorbell.interval_seconds // 1.5' "$CONFIG")

ring() {
  curl -sf -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"entity_id\": \"$ENTITY\"}" \
    "$BASE_URL/api/services/$SERVICE" >/dev/null
}

echo "claude-pa: 🔔 ringing doorbell ($ENTITY) × $RINGS"
for ((i=0; i<RINGS; i++)); do
  ring
  (( i + 1 < RINGS )) && sleep "$INTERVAL"
done
