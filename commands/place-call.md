---
description: Place an outbound Vapi call to the user or their spouse via the Claude-PA dispatcher assistant, with a context-rich reason (what Claude is stuck on, repo, idle time). Use the `place-call` skill — never invoke pa-phone-call.sh directly without first assembling a real reason.
---

Use the `place-call` skill.

Quick reference for the underlying script:

```bash
$CLAUDE_PLUGIN_ROOT/bin/pa-phone-call.sh <user|spouse> --confirm \
    --reason "<one or two sentences — what's Claude stuck on, why is the user needed>" \
    [--repo "<repo>"] [--idle-minutes <N>] [--last-tag "<tag>"]
```

`--reason` is required. The script exits 15 without it. The reason is
passed to the Vapi assistant as `assistantOverrides.variableValues.reason`
and substituted into the dispatcher's `{{reason}}` template at call time.
