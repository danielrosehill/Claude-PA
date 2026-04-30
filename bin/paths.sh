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

# Resolve a clip path. Looks first in the user dir (rendered/custom) then
# falls back to the plugin's seed sounds dir.
claude_pa_resolve_clip() {
  local rel="$1"
  if [[ -f "$CLAUDE_PA_HOME/$rel" ]]; then
    echo "$CLAUDE_PA_HOME/$rel"
  elif [[ -f "$PLUGIN_ROOT/$rel" ]]; then
    echo "$PLUGIN_ROOT/$rel"
  else
    return 1
  fi
}

claude_pa_require_config() {
  if [[ ! -f "$CLAUDE_PA_CONFIG_FILE" ]]; then
    echo "claude-pa: no config at $CLAUDE_PA_CONFIG_FILE" >&2
    echo "           run /claude-pa:onboard or /claude-pa:setup-ha first" >&2
    return 1
  fi
}
