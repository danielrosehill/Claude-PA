#!/usr/bin/env bash
# claude-pa Twilio passive-aggressive spouse-call — PLANNED FEATURE / STUB.
#
# When the user has ignored every previous escalation tier — desk speaker,
# kitchen, living room, whole-house PA, *and* bedroom light flash — Claude's
# final move is to ring the user's spouse on Twilio and politely complain.
#
# The spouse hears something like:
#
#   "Hi, sorry to bother you. This is Claude calling from your husband's
#    workstation. We've been trying to reach Daniel for some time now —
#    he is needed at the computer. If you happen to see him, would you
#    mind letting him know? Thank you so much. Have a lovely day."
#
# Refuses to fire unless ALL of these are true:
#   - config.spouse_call.enabled == true (explicit opt-in)
#   - config.spouse_call.spouse_phone is set
#   - $TWILIO_ACCOUNT_SID and $TWILIO_AUTH_TOKEN are exported
#   - --confirm flag is passed (no accidental fires)
#
# Implementation: TODO. Sketch:
#   1. Render the apology script via Fish Audio → upload to a public URL
#      (or use a TwiML Bin with <Play> pointing at sounds/spouse/<slug>.wav).
#   2. POST to https://api.twilio.com/2010-04-01/Accounts/$SID/Calls.json
#      with To=$SPOUSE_PHONE, From=$TWILIO_NUMBER, Url=<TwiML URL>.
#   3. Log the call SID + timestamp to ~/.claude-pa/spouse-calls.log
#      so the user has receipts (and can apologise later).
#
# This is the nuclear tier. Treat it accordingly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1
CONFIG="$CLAUDE_PA_CONFIG_FILE"

if [[ "${1:-}" != "--confirm" ]]; then
  echo "claude-pa: pa-call-spouse.sh requires --confirm flag" >&2
  echo "           (this is the nuclear escalation tier)" >&2
  exit 10
fi

ENABLED=$(jq -r '.spouse_call.enabled // false' "$CONFIG")
[[ "$ENABLED" == "true" ]] || { echo "claude-pa: spouse_call.enabled=false; aborting." >&2; exit 11; }

SPOUSE=$(jq -r '.spouse_call.spouse_phone // ""' "$CONFIG")
[[ -n "$SPOUSE" ]] || { echo "claude-pa: spouse_call.spouse_phone not set" >&2; exit 12; }

: "${TWILIO_ACCOUNT_SID:?TWILIO_ACCOUNT_SID not set}"
: "${TWILIO_AUTH_TOKEN:?TWILIO_AUTH_TOKEN not set}"

echo "claude-pa: ☎️  spouse-call tier — NOT YET IMPLEMENTED."
echo "           Would call: $SPOUSE"
echo "           See script header for implementation sketch."
exit 99
