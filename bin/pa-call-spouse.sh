#!/usr/bin/env bash
# claude-pa Vapi spouse-call — final escalation tier.
#
# Thin compatibility wrapper around bin/pa-phone-call.sh (target=spouse).
# Forwards all args after --confirm — in particular --reason, --repo,
# --idle-minutes, --last-tag.
#
# Example:
#   pa-call-spouse.sh --confirm --reason "Claude needs approval to push a PR" \
#                              --repo Claude-PA --idle-minutes 12

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" != "--confirm" ]]; then
  echo "claude-pa: pa-call-spouse.sh requires --confirm flag (this is the nuclear escalation tier)" >&2
  exit 10
fi
shift

exec "$SCRIPT_DIR/pa-phone-call.sh" spouse --confirm "$@"
