#!/usr/bin/env bash
# claude-pa Vapi phone-call dispatcher.
#
# Two named call targets, both opt-in, both gated by --confirm:
#
#   user    — direct user escalation (rings the user's own phone)
#   spouse  — passive-aggressive spouse-call (final escalation tier)
#   friend  — call a named friend from the config .friends[] list
#   adhoc   — one-shot call to a number not in config (--name + --phone required)
#
# Usage:
#   pa-phone-call.sh <user|spouse> --confirm --reason "..." [...]
#   pa-phone-call.sh friend --confirm --name "Alex" --reason "..." [...]
#   pa-phone-call.sh adhoc  --confirm --name "Alex" --phone "+9725..." --reason "..."
#
# Optional flags (all targets):
#       --repo "..."             last repo Claude was working in
#       --idle-minutes N         minutes Claude has been idle
#       --last-tag "..."         e.g. attention:approval-needed
#
# Reads from $CLAUDE_PA_CONFIG_FILE:
#   .vapi.assistant_id            (top-level default)
#   .vapi.phone_number_id         (top-level default)
#   .user_call.{enabled,user_name,user_phone,vapi.{assistant_id,phone_number_id}}
#   .spouse_call.{enabled,spouse_name,spouse_phone,vapi.{assistant_id,phone_number_id}}
#
# Per-target .vapi.* overrides the top-level .vapi.* defaults.
#
# Requires $VAPI_API_KEY (loaded from $CLAUDE_PA_HOME/env).
# Logs to $CLAUDE_PA_LOG_DIR/phone-calls.log.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1
CONFIG="$CLAUDE_PA_CONFIG_FILE"

usage() {
  cat >&2 <<EOF
usage: pa-phone-call.sh <user|spouse> --confirm --reason "..." [--repo R] [--idle-minutes N] [--last-tag T]
  env VAPI_API_KEY required
EOF
}

TARGET="${1:-}"; shift || { usage; exit 2; }
case "$TARGET" in user|spouse|friend|adhoc) ;; *) usage; exit 2;; esac

CONFIRM=0
REASON=""
REPO=""
IDLE_MINUTES=""
LAST_TAG=""
FRIEND_NAME=""
ADHOC_PHONE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --confirm)        CONFIRM=1; shift;;
    --reason)         REASON="${2:-}"; shift 2;;
    --repo)           REPO="${2:-}"; shift 2;;
    --idle-minutes)   IDLE_MINUTES="${2:-}"; shift 2;;
    --last-tag)       LAST_TAG="${2:-}"; shift 2;;
    --name)           FRIEND_NAME="${2:-}"; shift 2;;
    --phone)          ADHOC_PHONE="${2:-}"; shift 2;;
    *) echo "claude-pa: unknown arg: $1" >&2; usage; exit 2;;
  esac
done

[[ "$CONFIRM" == "1" ]] || { echo "claude-pa: --confirm required" >&2; exit 10; }

if [[ -z "$REASON" ]]; then
  echo "claude-pa: --reason is REQUIRED — the assistant won't know why it's calling otherwise." >&2
  echo "           Provide a sentence or two: what's Claude stuck on, what does the user need to come do." >&2
  exit 15
fi

USER_NAME=$(jq -r '.user_name // "the user"' "$CONFIG")
CALLEE_NAME=""
CALLEE_PHONE=""
CALLEE_ROLE=""
ASSISTANT_ID=""
PHONE_NUMBER_ID=""

case "$TARGET" in
  user)
    ENABLED=$(jq -r '.user_call.enabled // false' "$CONFIG")
    [[ "$ENABLED" == "true" ]] || { echo "claude-pa: .user_call.enabled=false; aborting." >&2; exit 11; }
    CALLEE_NAME=$(jq -r '.user_call.user_name // ""' "$CONFIG")
    CALLEE_PHONE=$(jq -r '.user_call.user_phone // ""' "$CONFIG")
    ASSISTANT_ID=$(jq -r '.user_call.vapi.assistant_id // .vapi.assistant_id // ""' "$CONFIG")
    PHONE_NUMBER_ID=$(jq -r '.user_call.vapi.phone_number_id // .vapi.phone_number_id // ""' "$CONFIG")
    CALLEE_ROLE="the user themselves"
    ;;
  spouse)
    ENABLED=$(jq -r '.spouse_call.enabled // false' "$CONFIG")
    [[ "$ENABLED" == "true" ]] || { echo "claude-pa: .spouse_call.enabled=false; aborting." >&2; exit 11; }
    CALLEE_NAME=$(jq -r '.spouse_call.spouse_name // ""' "$CONFIG")
    CALLEE_PHONE=$(jq -r '.spouse_call.spouse_phone // ""' "$CONFIG")
    ASSISTANT_ID=$(jq -r '.spouse_call.vapi.assistant_id // .vapi.assistant_id // ""' "$CONFIG")
    PHONE_NUMBER_ID=$(jq -r '.spouse_call.vapi.phone_number_id // .vapi.phone_number_id // ""' "$CONFIG")
    CALLEE_ROLE="their spouse"
    ;;
  friend)
    [[ -n "$FRIEND_NAME" ]] || { echo "claude-pa: --name <friend_name> required for target=friend" >&2; exit 12; }
    FRIENDS_ENABLED=$(jq -r '.friends_calls.enabled // true' "$CONFIG")
    [[ "$FRIENDS_ENABLED" == "true" ]] || { echo "claude-pa: .friends_calls.enabled=false; aborting." >&2; exit 11; }
    ENTRY=$(jq -c --arg n "$FRIEND_NAME" '.friends[]? | select((.name // "") | ascii_downcase == ($n | ascii_downcase))' "$CONFIG" | head -n1)
    [[ -n "$ENTRY" ]] || { echo "claude-pa: no friend named '$FRIEND_NAME' in .friends[] — add them with /claude-pa:add-friend or edit \$CLAUDE_PA_HOME/config.json" >&2; exit 12; }
    CALLEE_NAME=$(echo "$ENTRY" | jq -r '.name // ""')
    CALLEE_PHONE=$(echo "$ENTRY" | jq -r '.phone // ""')
    ASSISTANT_ID=$(echo "$ENTRY" | jq -r '.vapi.assistant_id // empty')
    PHONE_NUMBER_ID=$(echo "$ENTRY" | jq -r '.vapi.phone_number_id // empty')
    [[ -n "$ASSISTANT_ID" ]]    || ASSISTANT_ID=$(jq -r '.vapi.assistant_id // ""' "$CONFIG")
    [[ -n "$PHONE_NUMBER_ID" ]] || PHONE_NUMBER_ID=$(jq -r '.vapi.phone_number_id // ""' "$CONFIG")
    CALLEE_ROLE=$(echo "$ENTRY" | jq -r '.role // "a friend of the user"')
    ;;
  adhoc)
    [[ -n "$FRIEND_NAME"  ]] || { echo "claude-pa: --name required for target=adhoc"  >&2; exit 12; }
    [[ -n "$ADHOC_PHONE"  ]] || { echo "claude-pa: --phone required for target=adhoc" >&2; exit 12; }
    CALLEE_NAME="$FRIEND_NAME"
    CALLEE_PHONE="$ADHOC_PHONE"
    ASSISTANT_ID=$(jq -r '.vapi.assistant_id // ""' "$CONFIG")
    PHONE_NUMBER_ID=$(jq -r '.vapi.phone_number_id // ""' "$CONFIG")
    CALLEE_ROLE="a contact"
    ;;
esac

[[ -n "$CALLEE_PHONE" ]]    || { echo "claude-pa: callee phone not set"  >&2; exit 12; }
[[ -n "$ASSISTANT_ID" ]]    || { echo "claude-pa: no assistant_id — run /claude-pa:setup-vapi-assistant" >&2; exit 13; }
[[ -n "$PHONE_NUMBER_ID" ]] || { echo "claude-pa: no phone_number_id"    >&2; exit 14; }

: "${VAPI_API_KEY:?VAPI_API_KEY not set (expected in \$CLAUDE_PA_HOME/env)}"

claude_pa_ensure_dirs
LOG="$CLAUDE_PA_LOG_DIR/phone-calls.log"

# Build assistantOverrides.variableValues — Vapi templates {{var}} from this map.
PAYLOAD=$(jq -n \
  --arg aid    "$ASSISTANT_ID" \
  --arg pid    "$PHONE_NUMBER_ID" \
  --arg num    "$CALLEE_PHONE" \
  --arg cnm    "$CALLEE_NAME" \
  --arg unm    "$USER_NAME" \
  --arg crole  "$CALLEE_ROLE" \
  --arg reason "$REASON" \
  --arg repo   "$REPO" \
  --arg idle   "$IDLE_MINUTES" \
  --arg ltag   "$LAST_TAG" \
  '{
     assistantId: $aid,
     phoneNumberId: $pid,
     customer: { number: $num, name: $cnm },
     assistantOverrides: {
       variableValues: {
         user_name:     $unm,
         callee_name:   $cnm,
         callee_role:   $crole,
         reason:        $reason,
         repo:          $repo,
         idle_minutes:  $idle,
         last_tag:      $ltag
       }
     }
   }')

echo "claude-pa: ☎️  vapi call → ${TARGET} (${CALLEE_NAME:-?} ${CALLEE_PHONE})  reason=\"${REASON:0:80}\"" >&2

RESP=$(curl -fsS -X POST https://api.vapi.ai/call \
  -H "Authorization: Bearer $VAPI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" 2>&1) || { echo "claude-pa: vapi call failed: $RESP" >&2; exit 20; }

CALL_ID=$(echo "$RESP" | jq -r '.id // empty' 2>/dev/null || true)
TS=$(date -Iseconds)
{
  printf '%s  target=%s  callee=%s  phone=%s  call_id=%s\n' \
    "$TS" "$TARGET" "$CALLEE_NAME" "$CALLEE_PHONE" "$CALL_ID"
  printf '    reason=%q  repo=%q  idle=%s  last_tag=%s\n' \
    "$REASON" "$REPO" "$IDLE_MINUTES" "$LAST_TAG"
} >> "$LOG"
echo "claude-pa: vapi call placed (id=$CALL_ID); logged to $LOG" >&2
echo "$CALL_ID"
