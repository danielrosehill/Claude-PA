#!/usr/bin/env bash
# claude-pa clip pipeline — two passes:
#
#   1. Render raw TTS  → sounds/voices-raw/<pack>/<category>/<slug>.mp3
#      (Fish Audio API call; idempotent; preserved forever as the master)
#   2. Mix static bed  → sounds/voices/<pack>/<category>/<slug>.mp3
#      (local ffmpeg; mono / 22kHz / 64kbps; can be re-run any time without
#      burning API quota — tweak STATIC_VOL_DB or swap the bed and re-mix)
#
# Output of pass 1 is the master. Pass 2 is reproducible from it.
#
# Usage: render-clips.sh [--pack <slug>] [--force-raw] [--force-mix]
#                        [--skip-render] [--skip-mix]
#
# Requires: $FISH_AUDIO_API_KEY for pass 1; ffmpeg for pass 2.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"

PRESETS="$PLUGIN_ROOT/sounds/voice-presets.json"
RECIPES="$PLUGIN_ROOT/sounds/clip-recipes.json"
RAW_BASE="$PLUGIN_ROOT/sounds/voices-raw"
OUT_BASE="$PLUGIN_ROOT/sounds/voices"
STATIC_BED="$PLUGIN_ROOT/soundfx/freesound_community-fm-radio-static-82334.mp3"
STATIC_VOL_DB="${STATIC_VOL_DB:--22}"
OUT_BITRATE="${OUT_BITRATE:-64k}"
OUT_RATE="${OUT_RATE:-22050}"
LEAD_SEC="${LEAD_SEC:-1.0}"      # static-only at the start before voice comes in
TAIL_SEC="${TAIL_SEC:-1.0}"      # static-only at the end after voice finishes
FADE_SEC="${FADE_SEC:-0.4}"      # subtle fade in/out on the whole mix

ONLY_PACK=""
FORCE_RAW=0
FORCE_MIX=0
SKIP_RENDER=0
SKIP_MIX=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pack)         ONLY_PACK="$2"; shift 2 ;;
    --force-raw)    FORCE_RAW=1; shift ;;
    --force-mix)    FORCE_MIX=1; shift ;;
    --force)        FORCE_RAW=1; FORCE_MIX=1; shift ;;
    --skip-render)  SKIP_RENDER=1; shift ;;
    --skip-mix)     SKIP_MIX=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Build pack list
if [[ -n "$ONLY_PACK" ]]; then
  PACKS=$(jq -c --arg s "$ONLY_PACK" '[.presets[], .celebration] | .[] | select(.slug == $s)' "$PRESETS")
else
  PACKS=$(jq -c '[.presets[], .celebration] | .[]' "$PRESETS")
fi

# ── Pass 1: render raw TTS ─────────────────────────────────────────────
render_raw_one() {
  local model_id="$1" text="$2" out="$3"
  if [[ "$FORCE_RAW" -eq 0 && -f "$out" && -s "$out" ]]; then
    return 2  # skipped
  fi
  : "${FISH_AUDIO_API_KEY:?FISH_AUDIO_API_KEY not set — needed for raw render}"
  local body http_code
  body=$(jq -nc --arg t "$text" --arg m "$model_id" '{text:$t, reference_id:$m, format:"mp3"}')
  http_code=$(curl -sS -o "$out.tmp" -w "%{http_code}" -X POST https://api.fish.audio/v1/tts \
    -H "Authorization: Bearer $FISH_AUDIO_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$body" || echo "000")
  if [[ "$http_code" != "200" ]]; then
    echo "    ✗ HTTP $http_code for $out" >&2
    [[ -f "$out.tmp" ]] && head -c 200 "$out.tmp" >&2 && echo >&2
    rm -f "$out.tmp"
    return 1
  fi
  mv "$out.tmp" "$out"
  return 0
}

if [[ "$SKIP_RENDER" -eq 0 ]]; then
  echo "═══ pass 1: render raw TTS → $RAW_BASE"
  total=0; rendered=0; skipped=0; failed=0
  while IFS= read -r pack_json; do
    [[ -z "$pack_json" ]] && continue
    slug=$(jq -r '.slug' <<<"$pack_json")
    model_id=$(jq -r '.model_id' <<<"$pack_json")
    [[ -z "$slug" || "$slug" == "null" || -z "$model_id" || "$model_id" == "null" ]] && continue
    echo
    echo "  pack: $slug ($model_id)"
    while IFS=$'\t' read -r category line_slug text; do
      out_dir="$RAW_BASE/$slug/$category"
      mkdir -p "$out_dir"
      out="$out_dir/$line_slug.mp3"
      total=$((total+1))
      set +e; render_raw_one "$model_id" "$text" "$out"; rc=$?; set -e
      case "$rc" in
        0) rendered=$((rendered+1)); echo "    ✓ raw $category/$line_slug.mp3" ;;
        2) skipped=$((skipped+1)) ;;
        *) failed=$((failed+1)) ;;
      esac
    done < <(jq -r '.lines[] | "\(.category)\t\(.slug)\t\(.text)"' "$RECIPES")
  done <<<"$PACKS"
  echo
  echo "  pass 1 summary: total=$total rendered=$rendered skipped=$skipped failed=$failed"
  [[ "$failed" -eq 0 ]] || { echo "  ✗ raw render had failures — aborting before mix" >&2; exit 1; }
fi

# ── Pass 2: mix static bed + transcode mono/lowbit ─────────────────────
mix_one() {
  local raw="$1" out="$2"
  if [[ "$FORCE_MIX" -eq 0 && -f "$out" && -s "$out" && "$out" -nt "$raw" ]]; then
    return 2
  fi
  # Compute timing so we can place the voice ~1s after the static starts
  # and leave ~1s of clean static at the tail. Result feels like Claude is
  # about to come over the air, then signs off.
  local voice_dur total fade_out_st delay_ms
  voice_dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$raw" 2>/dev/null)
  [[ -z "$voice_dur" ]] && voice_dur=2.5
  total=$(awk -v v="$voice_dur" -v l="$LEAD_SEC" -v t="$TAIL_SEC" 'BEGIN { printf "%.3f", v + l + t }')
  fade_out_st=$(awk -v T="$total" -v f="$FADE_SEC" 'BEGIN { printf "%.3f", T - f }')
  delay_ms=$(awk -v l="$LEAD_SEC" 'BEGIN { printf "%d", l * 1000 }')

  if [[ -f "$STATIC_BED" ]]; then
    # Looped static for the whole duration; voice delayed by LEAD_SEC and
    # tail-padded by TAIL_SEC; subtle fade in/out across the whole clip.
    ffmpeg -y -loglevel error \
      -stream_loop -1 -i "$STATIC_BED" \
      -i "$raw" \
      -filter_complex "
        [0:a]atrim=0:${total},asetpts=PTS-STARTPTS,volume=${STATIC_VOL_DB}dB[bed];
        [1:a]adelay=${delay_ms}|${delay_ms},apad=pad_dur=${TAIL_SEC}[voice];
        [bed][voice]amix=inputs=2:duration=longest:dropout_transition=0,
          afade=t=in:st=0:d=${FADE_SEC},
          afade=t=out:st=${fade_out_st}:d=${FADE_SEC}[out]
      " \
      -map "[out]" -ac 1 -ar "$OUT_RATE" -b:a "$OUT_BITRATE" -t "$total" "$out"
  else
    ffmpeg -y -loglevel error -i "$raw" -ac 1 -ar "$OUT_RATE" -b:a "$OUT_BITRATE" "$out"
  fi
}

if [[ "$SKIP_MIX" -eq 0 ]]; then
  echo
  echo "═══ pass 2: mix static bed → $OUT_BASE  (vol=${STATIC_VOL_DB}dB, ${OUT_BITRATE} mono)"
  total=0; mixed=0; skipped=0; failed=0
  while IFS= read -r pack_json; do
    [[ -z "$pack_json" ]] && continue
    slug=$(jq -r '.slug' <<<"$pack_json")
    [[ -z "$slug" || "$slug" == "null" ]] && continue
    raw_pack="$RAW_BASE/$slug"
    [[ -d "$raw_pack" ]] || { echo "  skip $slug (no raw dir)"; continue; }
    echo
    echo "  pack: $slug"
    while IFS= read -r raw_file; do
      rel="${raw_file#$raw_pack/}"
      out="$OUT_BASE/$slug/$rel"
      mkdir -p "$(dirname "$out")"
      total=$((total+1))
      set +e; mix_one "$raw_file" "$out"; rc=$?; set -e
      case "$rc" in
        0) mixed=$((mixed+1)); echo "    ✓ mix $slug/$rel" ;;
        2) skipped=$((skipped+1)) ;;
        *) failed=$((failed+1)); echo "    ✗ mix $slug/$rel" >&2 ;;
      esac
    done < <(find "$raw_pack" -type f -name '*.mp3' | sort)
  done <<<"$PACKS"
  echo
  echo "  pass 2 summary: total=$total mixed=$mixed skipped=$skipped failed=$failed"
fi
