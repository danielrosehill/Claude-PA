#!/usr/bin/env bash
# claude-pa local playback — pure local PipeWire/PulseAudio path.
# Resolves a tag → clip, optionally prepends the name clip, mixes a static bed
# under it, and plays it through the configured local sink.
#
# Knows nothing about Home Assistant.
#
# Usage: play-local.sh <tag> [--no-name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1
CONFIG="$CLAUDE_PA_CONFIG_FILE"
MANIFEST="$CLAUDE_PA_MANIFEST"

TAG="${1:-}"; shift || true
USE_NAME=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-name) USE_NAME=0; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$TAG" ]] || { echo "usage: play-local.sh <tag> [--no-name]" >&2; exit 2; }

CLIP_REL=$(jq -r --arg t "$TAG" '
  .tags[$t].clips // [] | if length == 0 then "" else .[(now*1000|floor) % length] end
' "$MANIFEST")
[[ -n "$CLIP_REL" ]] || { echo "claude-pa: no clip for tag '$TAG'" >&2; exit 3; }

CLIP=$(claude_pa_resolve_clip "$CLIP_REL") || { echo "claude-pa: clip missing: $CLIP_REL (render via Fish Audio per sounds/MESSAGES.md)" >&2; exit 4; }
NAME_CLIP_REL=$(jq -r '.name_clip' "$MANIFEST")
STATIC_REL=$(jq -r '.static_loop' "$MANIFEST")
NAME_CLIP=$(claude_pa_resolve_clip "$NAME_CLIP_REL" 2>/dev/null || echo "")
STATIC=$(claude_pa_resolve_clip "$STATIC_REL" 2>/dev/null || echo "")

TMPDIR="$(mktemp -d)"; trap 'rm -rf "$TMPDIR"' EXIT

# Resolve optional SFX pre-roll for this tag (longest matching prefix)
SFX=""
SFX_KEY=$(jq -r --arg t "$TAG" '
  [.tag_sfx | to_entries[] | select(.key != "_comment") | select($t | startswith(.key)) | .key] | sort_by(length) | last // ""
' "$MANIFEST")
if [[ -n "$SFX_KEY" ]]; then
  # Value can be a string or an array — array means random pick
  SFX_NAME=$(jq -r --arg k "$SFX_KEY" '
    .tag_sfx[$k] |
    if type == "array" then .[(now*1000|floor) % length] else . end
  ' "$MANIFEST")
  SFX_REL=$(jq -r --arg n "$SFX_NAME" '.sfx[$n] // ""' "$MANIFEST")
  [[ -n "$SFX_REL" ]] && SFX=$(claude_pa_resolve_clip "$SFX_REL" 2>/dev/null || echo "")
fi

# Resolve register wrap (e.g. walkie-talkie click bookends for dispatcher register).
# Local playback is always the 'dispatcher' register.
WRAP_INTRO=""; WRAP_OUTRO=""
WRAP_INTRO_NAME=$(jq -r '.register_wrap.dispatcher.intro // ""' "$MANIFEST")
WRAP_OUTRO_NAME=$(jq -r '.register_wrap.dispatcher.outro // ""' "$MANIFEST")
if [[ -n "$WRAP_INTRO_NAME" ]]; then
  WRAP_INTRO_REL=$(jq -r --arg n "$WRAP_INTRO_NAME" '.sfx[$n] // ""' "$MANIFEST")
  [[ -n "$WRAP_INTRO_REL" ]] && WRAP_INTRO=$(claude_pa_resolve_clip "$WRAP_INTRO_REL" 2>/dev/null || echo "")
fi
if [[ -n "$WRAP_OUTRO_NAME" ]]; then
  WRAP_OUTRO_REL=$(jq -r --arg n "$WRAP_OUTRO_NAME" '.sfx[$n] // ""' "$MANIFEST")
  [[ -n "$WRAP_OUTRO_REL" ]] && WRAP_OUTRO=$(claude_pa_resolve_clip "$WRAP_OUTRO_REL" 2>/dev/null || echo "")
fi

# Concat: walkie-intro + optional tag SFX + optional name + clip + walkie-outro
SPOKEN="$TMPDIR/spoken.wav"
CONCAT="$TMPDIR/concat.txt"
: > "$CONCAT"
[[ -n "$WRAP_INTRO" && -f "$WRAP_INTRO" ]] && printf "file '%s'\n" "$WRAP_INTRO" >> "$CONCAT"
[[ -n "$SFX" && -f "$SFX" ]] && printf "file '%s'\n" "$SFX" >> "$CONCAT"
[[ "$USE_NAME" -eq 1 && -n "$NAME_CLIP" && -f "$NAME_CLIP" ]] && printf "file '%s'\n" "$NAME_CLIP" >> "$CONCAT"
printf "file '%s'\n" "$CLIP" >> "$CONCAT"
[[ -n "$WRAP_OUTRO" && -f "$WRAP_OUTRO" ]] && printf "file '%s'\n" "$WRAP_OUTRO" >> "$CONCAT"

PARTS=$(wc -l < "$CONCAT")
if [[ "$PARTS" -eq 1 ]]; then
  cp "$CLIP" "$SPOKEN"
else
  ffmpeg -y -loglevel error -f concat -safe 0 -i "$CONCAT" -ar 44100 -ac 2 "$SPOKEN"
fi

# Mix with static bed
OUT="$TMPDIR/out.wav"
STATIC_VOL_DB=$(jq -r '.local_audio.static_volume_db // -18' "$CONFIG")
if [[ -n "$STATIC" && -f "$STATIC" ]]; then
  ffmpeg -y -loglevel error \
    -i "$SPOKEN" -stream_loop -1 -i "$STATIC" \
    -filter_complex "[1:a]volume=${STATIC_VOL_DB}dB[bed];[0:a][bed]amix=inputs=2:duration=first:dropout_transition=0[out]" \
    -map "[out]" -ar 44100 -ac 2 "$OUT"
else
  cp "$SPOKEN" "$OUT"
fi

# Mark "user has been pinged" for the escalator daemon
MARKER=$(jq -r '.escalation.idle_marker_path // "/tmp/claude-pa-pending"' "$CONFIG")
date +%s > "$MARKER" 2>/dev/null || true

PLAYER=$(jq -r '.local_audio.player // "paplay"' "$CONFIG")
SINK=$(jq -r '.local_audio.sink // empty' "$CONFIG")
case "$PLAYER" in
  paplay) [[ -n "$SINK" ]] && paplay --device="$SINK" "$OUT" || paplay "$OUT" ;;
  ffplay) ffplay -nodisp -autoexit -loglevel quiet "$OUT" ;;
  aplay)  aplay -q "$OUT" ;;
  *)      "$PLAYER" "$OUT" ;;
esac
