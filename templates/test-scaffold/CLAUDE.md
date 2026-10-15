# Claude-PA Test Repo

Throwaway repo wired up to exercise the claude-pa plugin end-to-end.

## Dispatch protocol

Call these instead of going silent:

| When you would... | Run |
|---|---|
| Pause and wait for the user | `/passive-aggressive-pa:dispatch attention:approval-needed` |
| Finish a task and go idle | `/passive-aggressive-pa:dispatch complete:project` |
| Kick off a sub-agent | `/passive-aggressive-pa:dispatch status:subagent-running` |
| Hit a blocker | `/passive-aggressive-pa:dispatch status:blocker` |

The dispatcher fires audio + (if configured) screen flash + signal bulb in parallel.

## Safety cap

`CLAUDE_PA_MAX_TIER=0` is set in `.claude/settings.json`. Tiers ≥1 silently downgrade to tier 0 (local desk speaker). This keeps testing inside the room — no chimes elsewhere in the house, no doorbell, no whole-house PA.

To exercise higher tiers, raise the cap in settings.json. Know what tier you're enabling before you do.

## The task

See `STALL.md`.
