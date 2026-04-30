#!/usr/bin/env bash
# claude-pa audition renderer — renders the curated preset matrix
# (voices × lines) from sounds/voice-presets.json into
# sounds/auditions/<voice-slug>/<line-slug>.mp3
#
# Output is committed to the plugin so end users can audition without
# burning their own Fish Audio quota.
#
# Requires: $FISH_AUDIO_API_KEY exported.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"

: "${FISH_AUDIO_API_KEY:?FISH_AUDIO_API_KEY not set — export it first}"

PRESETS="$PLUGIN_ROOT/sounds/voice-presets.json"
OUT_DIR="$PLUGIN_ROOT/sounds/auditions"

mkdir -p "$OUT_DIR"

render() {
  local model_id="$1" text="$2" out="$3"
  if [[ -f "$out" ]]; then
    echo "  · skip (exists): $out"
    return 0
  fi
  echo "  → $out"
  curl -sf -o "$out" -X POST https://api.fish.audio/v1/tts \
    -H "Authorization: Bearer $FISH_AUDIO_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -nc --arg t "$text" --arg m "$model_id" '{text:$t, reference_id:$m, format:"mp3"}')"
}

# Render dispatcher presets × audition lines
jq -r '.presets[] | "\(.slug)\t\(.model_id)"' "$PRESETS" | while IFS=$'\t' read -r slug model_id; do
  voice_dir="$OUT_DIR/$slug"
  mkdir -p "$voice_dir"
  echo "voice: $slug ($model_id)"
  jq -r '.audition_lines[] | "\(.slug)\t\(.text)"' "$PRESETS" | while IFS=$'\t' read -r line_slug text; do
    render "$model_id" "$text" "$voice_dir/$line_slug.mp3"
  done
done

# Always render the celebration line in the DJ Fred voice
echo "voice: dj-fred (celebration)"
DJ_ID=$(jq -r '.celebration.model_id' "$PRESETS")
DJ_DIR="$OUT_DIR/dj-fred"
mkdir -p "$DJ_DIR"
DJ_TEXT=$(jq -r '.audition_lines[] | select(.slug=="complete") | .text' "$PRESETS")
render "$DJ_ID" "$DJ_TEXT" "$DJ_DIR/complete.mp3"

echo
echo "Done. Audition matrix:"
find "$OUT_DIR" -type f -name '*.mp3' | sort
