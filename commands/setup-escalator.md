---
description: Install and start the claude-pa escalator daemon — the watchdog that fires higher cascade tiers when you don't respond. Idempotent; safe to re-run.
---

```bash
${CLAUDE_PLUGIN_ROOT}/bin/escalator-ctl.sh install && \
  ${CLAUDE_PLUGIN_ROOT}/bin/escalator-ctl.sh start && \
  ${CLAUDE_PLUGIN_ROOT}/bin/escalator-ctl.sh status
```

## What this does

1. Renders `templates/systemd/claude-pa-escalator.service` to `~/.config/systemd/user/` with the plugin path and `$CLAUDE_PA_HOME` baked in.
2. Enables + starts the unit (or runs a fallback `nohup` background process if `systemd --user` isn't available — common in containers / WSL).
3. Prints the daemon status and any active idle marker.

## How escalation actually works

- When Claude calls `/dispatch attention:* --tier 0`, `dispatch.sh` writes `$CLAUDE_PA_HOME/escalator/state.json` (the idle marker).
- The daemon polls this file every ~2 seconds and fires `dispatch.sh <stored-tag> --tier N` once each `delay_seconds` threshold from `sounds/manifest.json` is crossed (tier 1 at 30s, tier 2 at 90s, …).
- A `UserPromptSubmit` hook in your project's `.claude/settings.json` runs `bin/mark-active.sh`, which deletes the marker — that's how typing a reply silences the cascade.

## Required project hook

Add this to any repo's `.claude/settings.json` (the test-scaffold already has it):

```json
"hooks": {
  "UserPromptSubmit": [
    { "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/bin/mark-active.sh" }] }
  ]
}
```

Without this hook, the daemon will keep escalating even after you reply, because nothing tells it the user came back.

## Diagnostics

```bash
${CLAUDE_PLUGIN_ROOT}/bin/escalator-ctl.sh status   # is it running? any active idle?
${CLAUDE_PLUGIN_ROOT}/bin/escalator-ctl.sh logs     # tail the firing log
${CLAUDE_PLUGIN_ROOT}/bin/escalator-ctl.sh stop     # disable the cascade entirely
```
