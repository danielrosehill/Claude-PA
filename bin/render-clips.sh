#!/usr/bin/env bash
# claude-pa clip renderer — renders the full message catalogue
# (sounds/clip-recipes.json) in every voice pack listed in
# sounds/voice-presets.json. Output is committed to the plugin so end
# users get a ready-to-use library without burning their own quota.
#
# Output layout: sounds/voices/<pack-slug>/<category>/<slug>.mp3
#
# Usage: render-clips.sh [--pack <slug>] [--force]
#   --pack <slug>  render only this pack (default: all)
#   --force        re-render even if output already exists
#
# Requires: $FISH_AUDIO_API_KEY exported.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"

: "${FISH_AUDIO_API_KEY:?FISH_AUDIO_API_KEY not set — export it first}"

PRESETS="$PLUGIN_ROOT/sounds/voice-presets.json"
RECIPES="$PLUGIN_ROOT/sounds/clip-recipes.json"
OUT_BASE="$PLUGIN_ROOT/sounds/voices"
STATIC_BED="$PLUGIN_ROOT/soundfx/freesound_community-fm-radio-static-82334.mp3"
STATIC_VOL_DB="${STATIC_VOL_DB:--22}"
OUT_BITRATE="${OUT_BITRATE:-64k}"

ONLY_PACK=""
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pack)  ONLY_PACK="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT_BASE"

render_one() {
  local model_id="$1" text="$2" out="$3"
  if [[ "$FORCE" -eq 0 && -f "$out" && -s "$out" ]]; then
    return 2  # skipped
  fi
  local body http_code raw="$out.raw.mp3"
  body=$(jq -nc --arg t "$text" --arg m "$model_id" '{text:$t, reference_id:$m, format:"mp3"}')
  http_code=$(curl -sS -o "$raw" -w "%{http_code}" -X POST https://api.fish.audio/v1/tts \
    -H "Authorization: Bearer $FISH_AUDIO_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$body" || echo "000")
  if [[ "$http_code" != "200" ]]; then
    echo "    ✗ HTTP $http_code for $out" >&2
    [[ -f "$raw" ]] && head -c 200 "$raw" >&2 && echo >&2
    rm -f "$raw"
    return 1
  fi

  # Mix the radio-static bed under the voice and downmix to mono at a low
  # bitrate. Output sounds like Claude is talking through a walkie-talkie.
  if [[ -f "$STATIC_BED" ]]; then
    ffmpeg -y -loglevel error \
      -i "$raw" -stream_loop -1 -i "$STATIC_BED" \
      -filter_complex "[1:a]volume=${STATIC_VOL_DB}dB[bed];[0:a][bed]amix=inputs=2:duration=first:dropout_transition=0[out]" \
      -map "[out]" -ac 1 -ar 22050 -b:a "$OUT_BITRATE" "$out"
  else
    # No static bed available — just transcode mono/low-bitrate
    ffmpeg -y -loglevel error -i "$raw" -ac 1 -ar 22050 -b:a "$OUT_BITRATE" "$out"
  fi
  rm -f "$raw"
  return 0
}

# Iterate packs
if [[ -n "$ONLY_PACK" ]]; then
  ALL_PACKS=$(jq -c --arg s "$ONLY_PACK" '[.presets[], .celebration] | .[] | select(.slug == $s)' "$PRESETS")
else
  ALL_PACKS=$(jq -c '[.presets[], .celebration] | .[]' "$PRESETS")
fi

total=0; rendered=0; skipped=0; failed=0

while IFS= read -r pack_json; do
  slug=$(jq -r '.slug' <<<"$pack_json")
  model_id=$(jq -r '.model_id' <<<"$pack_json")
  label=$(jq -r '.label' <<<"$pack_json")
  echo
  echo "═══ pack: $slug ($label) — $model_id"

  while IFS=$'\t' read -r category line_slug text; do
    out_dir="$OUT_BASE/$slug/$category"
    mkdir -p "$out_dir"
    out="$out_dir/$line_slug.mp3"
    total=$((total+1))
    set +e
    render_one "$model_id" "$text" "$out"
    rc=$?
    set -e
    case "$rc" in
      0) rendered=$((rendered+1)); echo "    ✓ $category/$line_slug.mp3" ;;
      2) skipped=$((skipped+1)) ;;
      *) failed=$((failed+1)) ;;
    esac
  done < <(jq -r '.lines[] | "\(.category)\t\(.slug)\t\(.text)"' "$RECIPES")
done <<<"$ALL_PACKS"

echo
echo "═══ done. total=$total rendered=$rendered skipped=$skipped failed=$failed"
[[ "$failed" -eq 0 ]]
