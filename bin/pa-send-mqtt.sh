#!/usr/bin/env bash
# claude-pa MQTT transport — publishes a dispatch payload to a Mosquitto (or
# any MQTT) broker. Alternative to the Home Assistant REST path for users who
# don't run HA but DO have an MQTT-capable speaker / ESP / Tasmota / custom
# subscriber.
#
# The published payload is a JSON object on the configured topic. Subscribers
# decide what to do with it — typically: download the audio_url and play it.
#
# Topic layout (configurable):
#   <base_topic>/<key>          — payload below
#
# Payload:
#   {
#     "tag": "attention:approval-needed",
#     "key": "desk",
#     "register": "dispatcher",
#     "message": "...optional override text...",
#     "audio_url": "http://media-host/<clip>.wav",   # optional
#     "ts": 1730000000
#   }
#
# Requires:
#   - `mosquitto_pub` on PATH (apt: mosquitto-clients)
#   - config.mqtt.{enabled,host,port,base_topic} set
#   - optional config.mqtt.{username,password_env,tls,client_id}
#
# Usage:
#   pa-send-mqtt.sh <tag> <key> [--register R] [--message TEXT] [--audio-url URL]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1

TAG="${1:?tag required}"; shift
KEY="${1:?key required}"; shift
REGISTER="dispatcher"
MESSAGE=""
AUDIO_URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --register)  REGISTER="$2"; shift 2 ;;
    --message)   MESSAGE="$2"; shift 2 ;;
    --audio-url) AUDIO_URL="$2"; shift 2 ;;
    --no-name)   shift ;;  # accepted for parity with pa-send.sh; no-op
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

CONFIG="$CLAUDE_PA_CONFIG_FILE"
ENABLED=$(jq -r '.mqtt.enabled // false' "$CONFIG")
[[ "$ENABLED" == "true" ]] || { echo "claude-pa: mqtt.enabled=false" >&2; exit 10; }

command -v mosquitto_pub >/dev/null 2>&1 || {
  echo "claude-pa: mosquitto_pub not found (install mosquitto-clients)" >&2; exit 11; }

HOST=$(jq -r '.mqtt.host // "localhost"' "$CONFIG")
PORT=$(jq -r '.mqtt.port // 1883' "$CONFIG")
BASE=$(jq -r '.mqtt.base_topic // "claude-pa"' "$CONFIG")
USERNAME=$(jq -r '.mqtt.username // ""' "$CONFIG")
PASSWORD_ENV=$(jq -r '.mqtt.password_env // ""' "$CONFIG")
TLS=$(jq -r '.mqtt.tls // false' "$CONFIG")
CLIENT_ID=$(jq -r '.mqtt.client_id // empty' "$CONFIG")
QOS=$(jq -r '.mqtt.qos // 0' "$CONFIG")
RETAIN=$(jq -r '.mqtt.retain // false' "$CONFIG")

TOPIC="$BASE/$KEY"

PAYLOAD=$(jq -nc \
  --arg tag "$TAG" \
  --arg key "$KEY" \
  --arg register "$REGISTER" \
  --arg message "$MESSAGE" \
  --arg audio_url "$AUDIO_URL" \
  --argjson ts "$(date +%s)" \
  '{tag:$tag, key:$key, register:$register, message:$message, audio_url:$audio_url, ts:$ts}')

ARGS=( -h "$HOST" -p "$PORT" -t "$TOPIC" -m "$PAYLOAD" -q "$QOS" )
[[ -n "$USERNAME" ]] && ARGS+=( -u "$USERNAME" )
if [[ -n "$PASSWORD_ENV" ]]; then
  PASSWORD="${!PASSWORD_ENV:-}"
  [[ -n "$PASSWORD" ]] && ARGS+=( -P "$PASSWORD" )
fi
[[ "$TLS" == "true" ]] && ARGS+=( --capath /etc/ssl/certs )
[[ -n "$CLIENT_ID" && "$CLIENT_ID" != "null" ]] && ARGS+=( -i "$CLIENT_ID" )
[[ "$RETAIN" == "true" ]] && ARGS+=( -r )

mosquitto_pub "${ARGS[@]}"
