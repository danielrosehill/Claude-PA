#!/usr/bin/env bash
# claude-pa Home Assistant broadcast — sends a clip to a HA media_player.
#
# Pure HA path. Knows nothing about local playback.
# Caller picks the speaker key + register; this script does not decide policy.
#
# Usage: pa-send.sh <tag> <speaker_key> [--register dispatcher|pa] [--no-name]
#   speaker_key  matches a key in config.home_assistant.speakers (e.g. desk, kitchen, whole_house)
#   --register   'pa' rewrites the tag to a pa:* clip (whole-house announcer voice)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1
CONFIG="$CLAUDE_PA_CONFIG_FILE"
MANIFEST="$CLAUDE_PA_MANIFEST"

TAG="${1:?usage: pa-send.sh <tag> <speaker_key> [--register R] [--no-name]}"
SPEAKER_KEY="${2:?speaker_key required}"
shift 2

REGISTER="dispatcher"
USE_NAME=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --register) REGISTER="$2"; shift 2 ;;
    --no-name)  USE_NAME=0; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

HA_ENABLED=$(jq -r '.home_assistant.enabled // false' "$CONFIG")
[[ "$HA_ENABLED" == "true" ]] || { echo "claude-pa: home_assistant.enabled=false in config" >&2; exit 5; }

BASE_URL=$(jq -r '.home_assistant.base_url' "$CONFIG")
TOKEN_ENV=$(jq -r '.home_assistant.token_env // "HASS_TOKEN"' "$CONFIG")
TOKEN="${!TOKEN_ENV:-}"
MEDIA_HOST=$(jq -r '.home_assistant.media_host_url' "$CONFIG")

[[ -n "$TOKEN" ]] || { echo "claude-pa: \$$TOKEN_ENV not set" >&2; exit 1; }

ENTITY=$(jq -r --arg k "$SPEAKER_KEY" '.home_assistant.speakers[$k] // ""' "$CONFIG")
[[ -n "$ENTITY" ]] || { echo "claude-pa: no speaker mapped for '$SPEAKER_KEY'" >&2; exit 2; }

# Register override: PA register uses pa:* clips instead of attention/status
if [[ "$REGISTER" == "pa" ]]; then
  case "$TAG" in
    attention:*|status:*) TAG="pa:return" ;;
  esac
fi

CLIP_REL=$(jq -r --arg t "$TAG" '.tags[$t].clips[0] // ""' "$MANIFEST")
[[ -n "$CLIP_REL" ]] || { echo "claude-pa: no clip for tag $TAG" >&2; exit 3; }

# Voice-pack URL remap — manifest references sounds/<category>/<file>.<ext> but
# rendered clips actually live at sounds/voices/<pack>/<category>/<file>.mp3.
# The MEDIA_HOST is expected to point at the served root that mirrors the
# `voices/<pack>/<cat>/<file>.mp3` tree (e.g. HA's /config/www/claude-pa/).
if [[ "$CLIP_REL" =~ ^sounds/([^/]+)/(.+)\.(wav|mp3|ogg|flac)$ ]]; then
  CAT="${BASH_REMATCH[1]}"
  FILE="${BASH_REMATCH[2]}"
  PACK=$(jq -r '.voice_pack // "wildcard"' "$CONFIG" 2>/dev/null || echo "wildcard")
  CLIP_REL="voices/$PACK/$CAT/$FILE.mp3"
fi

CLIP_URL="${MEDIA_HOST}/${CLIP_REL}"

curl -sf -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"entity_id\": \"$ENTITY\", \"media_content_id\": \"$CLIP_URL\", \"media_content_type\": \"music\"}" \
  "$BASE_URL/api/services/media_player/play_media" >/dev/null

echo "claude-pa: sent $TAG → $ENTITY (register=$REGISTER)"
