#!/usr/bin/env bash
# Sync the rendered clip library to a Home Assistant instance's /config/www/
# so HA can serve clips at /local/claude-pa/voices/<pack>/<cat>/<file>.mp3.
#
# Reads HA host from config.home_assistant.base_url. Requires SSH access to
# HA as root (or set $CLAUDE_PA_HA_SSH_USER).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1

USER="${CLAUDE_PA_HA_SSH_USER:-root}"
HOST=$(jq -r '.home_assistant.base_url' "$CLAUDE_PA_CONFIG_FILE" \
       | sed -E 's|https?://||; s|:.*||')
[[ -n "$HOST" && "$HOST" != "null" ]] || { echo "claude-pa: no HA host in config" >&2; exit 1; }

DEST="/config/www/claude-pa"
echo "syncing $PLUGIN_ROOT/sounds/voices/ → $USER@$HOST:$DEST/voices/"
ssh "$USER@$HOST" "mkdir -p $DEST"
rsync -a --info=stats1 \
  "$PLUGIN_ROOT/sounds/voices/" \
  "$USER@$HOST:$DEST/voices/"
echo "done. media_host_url should be: http://$HOST:8123/local/claude-pa"
