---
description: Clear any active claude-pa mute and resume normal dispatching. Does not affect the recurring schedule (use /claude-pa:schedule off for that).
---

## Steps

```bash
"$CLAUDE_PLUGIN_ROOT/bin/mute.sh" off
```

Then optionally fire a tier-0 confirmation dispatch so the user hears the system come back online:

```bash
"$CLAUDE_PLUGIN_ROOT/bin/dispatch.sh" status:thinking --tier 0 --no-flash >/dev/null 2>&1 || true
```
