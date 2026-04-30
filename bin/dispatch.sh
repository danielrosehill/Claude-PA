#!/usr/bin/env bash
# claude-pa dispatcher — thin router. Fires the configured target for the
# given tier AND the matching signal-bulb pattern in parallel.
#
# Targets:
#   local           → bin/play-local.sh
#   chime           → bin/chime.sh
#   ha:<key>        → bin/pa-send.sh
#   doorbell        → bin/ring-doorbell.sh
#   wake:bedroom    → bin/wake-user.sh
#   twilio:spouse   → bin/pa-call-spouse.sh
#
# Usage: dispatch.sh <tag> [--tier N] [--no-name] [--no-signal]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1

TAG="${1:-}"; shift || true
TIER=0
NAME_FLAG=""
USE_SIGNAL=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier)      TIER="$2"; shift 2 ;;
    --no-name)   NAME_FLAG="--no-name"; shift ;;
    --no-signal) USE_SIGNAL=0; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$TAG" ]] || { echo "usage: dispatch.sh <tag> [--tier N] [--no-name] [--no-signal]" >&2; exit 2; }

MANIFEST="$CLAUDE_PA_MANIFEST"
TIER_DEF=$(jq -r --arg t "$TIER" '.escalation_tiers[$t] // empty' "$MANIFEST")
[[ -n "$TIER_DEF" ]] || { echo "claude-pa: unknown tier $TIER" >&2; exit 3; }

TARGET=$(echo   "$TIER_DEF" | jq -r '.target')
REGISTER=$(echo "$TIER_DEF" | jq -r '.register // "dispatcher"')
USE_NAME=$(echo "$TIER_DEF" | jq -r '.use_name // true')
[[ "$USE_NAME" == "false" ]] && NAME_FLAG="--no-name"

# Fire signal bulb in parallel (best-effort, non-blocking, swallows errors)
if [[ "$USE_SIGNAL" -eq 1 ]]; then
  PATTERN=$(jq -r --arg t "$TAG" '.tags[$t].signal_pattern // empty' "$MANIFEST")
  if [[ -n "$PATTERN" && "$PATTERN" != "null" ]]; then
    "$SCRIPT_DIR/signal-bulb.sh" "$PATTERN" >/dev/null 2>&1 &
  fi
fi

case "$TARGET" in
  local)         exec "$SCRIPT_DIR/play-local.sh"      "$TAG" $NAME_FLAG ;;
  chime)         exec "$SCRIPT_DIR/chime.sh" ;;
  ha:*)
    KEY="${TARGET#ha:}"
    exec "$SCRIPT_DIR/pa-send.sh" "$TAG" "$KEY" --register "$REGISTER" $NAME_FLAG ;;
  doorbell)      exec "$SCRIPT_DIR/ring-doorbell.sh" ;;
  wake:bedroom)  exec "$SCRIPT_DIR/wake-user.sh" ;;
  twilio:spouse) exec "$SCRIPT_DIR/pa-call-spouse.sh" --confirm ;;
  *) echo "claude-pa: unknown target '$TARGET' for tier $TIER" >&2; exit 4 ;;
esac
