---
description: Set or inspect when claude-pa is allowed to fire. Two modes — recurring time-of-day windows (e.g. weekdays 9-5) or session-scoped ("active for the next 2 hours"). Outside the schedule the dispatcher is silent.
---

## Usage

- `/claude-pa:schedule` — show current schedule + active state
- `/claude-pa:schedule off` — clear schedule (always allowed unless explicitly muted)
- `/claude-pa:schedule during 90m` — active for the next 90 minutes (session mode — pairs with task-planning workflows)
- `/claude-pa:schedule during 2h --label "deep work"` — same, with a label
- `/claude-pa:schedule windows mon-fri:09:00-17:00` — recurring weekday business hours
- `/claude-pa:schedule windows weekdays:09:00-17:00 sat:10:00-12:00` — multiple windows
- `/claude-pa:schedule windows all:08:00-22:00` — every day, 8am-10pm

## Window spec

`DAYS:HH:MM-HH:MM`

`DAYS` accepts:
- comma list: `mon,wed,fri`
- range: `mon-fri`
- aliases: `weekdays`, `weekends`, `all`

## Steps

```bash
"$CLAUDE_PLUGIN_ROOT/bin/schedule.sh" "$@"
```

## How it interacts with mute

- An explicit mute (`/claude-pa:mute`) always wins.
- Outside an active schedule window, the dispatcher is silent (same effect as muted).
- Inside an active window, normal dispatch behaviour resumes.

## Pairs with task planning

Use `during <duration>` at the start of a focused work block — claude-pa stays loud while you work, then automatically falls silent when the session expires. Skip the manual unmute.
