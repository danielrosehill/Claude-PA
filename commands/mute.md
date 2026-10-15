---
description: Mute the claude-pa system. Pass a duration (e.g. "30m", "2h", "until 17:00") to auto-resume, or "indefinite" to mute until explicitly cleared. With no argument, prints status.
---

## Usage

- `/passive-aggressive-pa:mute` — print current mute status
- `/passive-aggressive-pa:mute 30m` — silent for 30 minutes, then auto-resume
- `/passive-aggressive-pa:mute 2h` — silent for 2 hours
- `/passive-aggressive-pa:mute until 17:00` — silent until 5pm today (or tomorrow if it's already past)
- `/passive-aggressive-pa:mute indefinite` — silent until `/passive-aggressive-pa:unmute`
- `/passive-aggressive-pa:mute indefinite --reason "in a meeting"` — same, with a reason logged

## What this does

Writes a sentinel to `$CLAUDE_PA_HOME/mute.json`. The dispatcher checks it before every fire — if muted, the dispatch is logged to `$CLAUDE_PA_HOME/logs/dispatch.log` and silently skipped. No audio, no signal bulb, no screen flash, no HA, no MQTT.

## Steps

1. Parse arguments. Forward to `$CLAUDE_PLUGIN_ROOT/bin/mute.sh`.
2. Print the resulting status human-readably.

```bash
"$CLAUDE_PLUGIN_ROOT/bin/mute.sh" "$@"
```

## Notes

- The mute is global to claude-pa (all sessions, all repos).
- Schedules (`/passive-aggressive-pa:schedule`) are independent — an explicit mute always wins over the schedule.
- To resume immediately: `/passive-aggressive-pa:unmute`.
