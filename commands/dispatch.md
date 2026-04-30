---
description: Bark a status update at the user via the PA cascade. Audio + signal-bulb fire together. Use whenever you'd otherwise sit silent waiting for input or finish a long task.
argument-hint: <tag> [--tier N]
---

```bash
${CLAUDE_PLUGIN_ROOT}/bin/dispatch.sh $ARGUMENTS
```

## Tag taxonomy

- `attention:approval-needed` — you're blocked on user input
- `attention:generic` — generic "look up at the screen"
- `status:subagent-running` — a sub-agent is mid-task
- `status:subagent-hurry` — you're waiting on a sub-agent that's been slow
- `status:subagent-done` — sub-agent finished
- `status:plugin-running` — a plugin command is executing
- `status:blocker` — hit a blocker, need user
- `status:thinking` — long planning beat (signal bulb only — no audio)
- `complete:project` — task finished
- `complete:gruff` — task finished, low-key
- `catastrophe:codebase-destroyed` — use sparingly

## Tiers

`--tier 0` (default) is the desk speaker. Higher tiers escalate across the house — the escalator daemon raises the tier automatically when the user doesn't respond, so most calls should pass tier 0 and let the system handle escalation.

## Don't spam it

Once per attention-worthy event. Not for every tool call, not for every file edit.
