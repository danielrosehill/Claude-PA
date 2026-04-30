#!/usr/bin/env bash
# claude-pa chime — gentle "ding" via a Home Assistant entity. Tier 1 of the
# escalation cascade: a soft notification before Claude starts actually
# barking at you over the speaker.
#
# Refuses to fire unless config.chime.enabled == true and an entity is set.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1

CONFIG="$CLAUDE_PA_CONFIG_FILE"

ENABLED=$(jq -r '.chime.enabled // false' "$CONFIG")
[[ "$ENABLED" == "true" ]] || { echo "claude-pa: chime.enabled=false" >&2; exit 10; }

ENTITY=$(jq -r '.chime.entity // ""' "$CONFIG")
[[ -n "$ENTITY" ]] || { echo "claude-pa: chime.entity not set" >&2; exit 12; }

BASE_URL=$(jq -r '.home_assistant.base_url' "$CONFIG")
TOKEN_ENV=$(jq -r '.home_assistant.token_env // "HASS_TOKEN"' "$CONFIG")
TOKEN="${!TOKEN_ENV:-}"
[[ -n "$TOKEN" ]] || { echo "claude-pa: \$$TOKEN_ENV not set" >&2; exit 1; }

DOMAIN="${ENTITY%%.*}"
case "$DOMAIN" in
  script)              SERVICE="script/turn_on" ;;
  switch)              SERVICE="switch/turn_on" ;;
  button|input_button) SERVICE="$DOMAIN/press" ;;
  automation)          SERVICE="automation/trigger" ;;
  media_player)
    # If chime is a media_player, play the chime sound URL instead
    SOUND=$(jq -r '.chime.sound_url // ""' "$CONFIG")
    [[ -n "$SOUND" ]] || { echo "claude-pa: chime is a media_player but chime.sound_url not set" >&2; exit 13; }
    curl -sf -X POST \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"entity_id\":\"$ENTITY\",\"media_content_id\":\"$SOUND\",\"media_content_type\":\"music\"}" \
      "$BASE_URL/api/services/media_player/play_media" >/dev/null
    echo "claude-pa: 🔔 chime ($ENTITY)"
    exit 0 ;;
  *) SERVICE=$(jq -r '.chime.service // "homeassistant/turn_on"' "$CONFIG") ;;
esac

curl -sf -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"entity_id\":\"$ENTITY\"}" \
  "$BASE_URL/api/services/$SERVICE" >/dev/null

echo "claude-pa: 🔔 chime ($ENTITY)"
