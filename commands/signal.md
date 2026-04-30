---
description: Update the Claude-signal RGB bulb pattern (continuous status channel, separate from the audio cascade). Use when state changes — thinking, waiting, working, done, error, clear.
argument-hint: <thinking|waiting|working|done|error|clear>
---

```bash
${CLAUDE_PLUGIN_ROOT}/bin/signal-bulb.sh $ARGUMENTS
```

## Patterns

| Pattern | Colour | When |
|---|---|---|
| `thinking` | slow blue pulse | long reasoning beat |
| `waiting` | amber breathing | blocked on user input |
| `working` | soft cyan steady | task running |
| `done` | green flash 2× | finished cleanly |
| `error` | red strobe 3× | failure / blocker hit |
| `clear` | off | reset |

The signal bulb is **parallel** to `/dispatch` — `/dispatch` already fires the matching pattern via the manifest's `signal_pattern` field. Use this command directly only when you want to change the visual state without sending an audio dispatch (e.g. `/signal thinking` while you reason silently).

Requires `signal_bulb.enabled: true` and an RGB-capable light entity in `$CLAUDE_PA_HOME/config.json`.
