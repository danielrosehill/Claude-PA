# claude-pa path resolver — sourced by every bin/ script.
#
# User data lives OUTSIDE the plugin folder (per Daniel's plugin-data-storage
# rule). The plugin folder ships seed assets + scripts only; user-specific
# state — live config, rendered clips, generated name clip, logs, custom
# scripts — lives under $CLAUDE_PA_HOME.
#
# Resolution order:
#   $CLAUDE_PA_HOME (if set)
#   $XDG_DATA_HOME/claude-pa (if XDG_DATA_HOME set)
#   $HOME/.local/share/claude-pa (default)

# shellcheck shell=bash

if [[ -z "${CLAUDE_PA_HOME:-}" ]]; then
  if [[ -n "${XDG_DATA_HOME:-}" ]]; then
    CLAUDE_PA_HOME="$XDG_DATA_HOME/claude-pa"
  else
    CLAUDE_PA_HOME="$HOME/.local/share/claude-pa"
  fi
fi
export CLAUDE_PA_HOME

# Standard sub-paths under the user dir
export CLAUDE_PA_CONFIG_FILE="${CLAUDE_PA_CONFIG:-$CLAUDE_PA_HOME/config.json}"
export CLAUDE_PA_SOUNDS_DIR="$CLAUDE_PA_HOME/sounds"        # rendered + custom clips
export CLAUDE_PA_LOG_DIR="$CLAUDE_PA_HOME/logs"
export CLAUDE_PA_SCRIPTS_DIR="$CLAUDE_PA_HOME/scripts"      # user-supplied scripts
export CLAUDE_PA_NAME_CLIP="$CLAUDE_PA_SOUNDS_DIR/name/user.wav"

# Plugin root (read-only seed assets ship here)
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PLUGIN_ROOT
export CLAUDE_PA_MANIFEST="$PLUGIN_ROOT/sounds/manifest.json"
export CLAUDE_PA_SEED_SOUNDS="$PLUGIN_ROOT/sounds"

claude_pa_ensure_dirs() {
  mkdir -p \
    "$CLAUDE_PA_HOME" \
    "$CLAUDE_PA_SOUNDS_DIR/name" \
    "$CLAUDE_PA_SOUNDS_DIR/bed" \
    "$CLAUDE_PA_SOUNDS_DIR/attention" \
    "$CLAUDE_PA_SOUNDS_DIR/status" \
    "$CLAUDE_PA_SOUNDS_DIR/pa" \
    "$CLAUDE_PA_SOUNDS_DIR/complete" \
    "$CLAUDE_PA_SOUNDS_DIR/catastrophe" \
    "$CLAUDE_PA_SOUNDS_DIR/ambient" \
    "$CLAUDE_PA_LOG_DIR" \
    "$CLAUDE_PA_SCRIPTS_DIR"
}

# Resolve a clip path. Resolution order:
#   1. $CLAUDE_PA_HOME/$rel exact (user-rendered/custom clip)
#   2. $PLUGIN_ROOT/$rel exact (seed asset shipped with plugin)
#   3. Voice-pack remap: rewrite "sounds/<category>/<name>.<ext>" →
#      "sounds/voices/<voice_pack>/<category>/<name>.mp3" and try (1) then (2).
#      <voice_pack> comes from $CLAUDE_PA_CONFIG_FILE .voice_pack (default "wildcard").
#   4. Strip soundfx/ prefix and try plugin root (sfx live at top-level soundfx/).
claude_pa_resolve_clip() {
  local rel="$1"

  [[ -f "$CLAUDE_PA_HOME/$rel" ]] && { echo "$CLAUDE_PA_HOME/$rel"; return 0; }
  [[ -f "$PLUGIN_ROOT/$rel" ]]   && { echo "$PLUGIN_ROOT/$rel";   return 0; }

  # Voice-pack remap for sounds/<category>/<file>
  if [[ "$rel" =~ ^sounds/([^/]+)/(.+)\.(wav|mp3|ogg|flac)$ ]]; then
    local cat="${BASH_REMATCH[1]}" file="${BASH_REMATCH[2]}"
    local pack="wildcard"
    if [[ -f "$CLAUDE_PA_CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
      pack=$(jq -r '.voice_pack // "wildcard"' "$CLAUDE_PA_CONFIG_FILE" 2>/dev/null || echo "wildcard")
    fi
    local remapped="sounds/voices/$pack/$cat/$file.mp3"
    [[ -f "$CLAUDE_PA_HOME/$remapped" ]] && { echo "$CLAUDE_PA_HOME/$remapped"; return 0; }
    [[ -f "$PLUGIN_ROOT/$remapped" ]]   && { echo "$PLUGIN_ROOT/$remapped";   return 0; }
  fi

  return 1
}

# Auto-bootstrap a default config from the shipped example if missing AND
# CLAUDE_PA_AUTOINIT=1 (set by the test-harness, /onboard, or any caller that
# wants "just work" semantics). Writes nothing if config already exists.
claude_pa_autoinit_config() {
  [[ -f "$CLAUDE_PA_CONFIG_FILE" ]] && return 0
  [[ "${CLAUDE_PA_AUTOINIT:-0}" == "1" ]] || return 1
  claude_pa_ensure_dirs
  local example="$PLUGIN_ROOT/config/config.example.json"
  [[ -f "$example" ]] || return 1
  cp "$example" "$CLAUDE_PA_CONFIG_FILE"
  return 0
}

claude_pa_require_config() {
  if [[ ! -f "$CLAUDE_PA_CONFIG_FILE" ]]; then
    claude_pa_autoinit_config && return 0
    echo "claude-pa: no config at $CLAUDE_PA_CONFIG_FILE" >&2
    echo "           run /claude-pa:onboard, or set CLAUDE_PA_AUTOINIT=1 to bootstrap from defaults" >&2
    return 1
  fi
}

# Tier cap — used by the test harness to prevent escalation past tier N.
# If $CLAUDE_PA_MAX_TIER is set, dispatcher silently downgrades any higher tier.
claude_pa_cap_tier() {
  local requested="$1"
  local cap="${CLAUDE_PA_MAX_TIER:-}"
  [[ -z "$cap" ]] && { echo "$requested"; return; }
  if (( requested > cap )); then
    echo "$cap"
  else
    echo "$requested"
  fi
}
