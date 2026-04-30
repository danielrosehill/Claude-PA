---
name: quiet-mode
description: Mute, pause, or schedule claude-pa from natural-language requests. Translates phrases like "shut up claude-pa", "pause for an hour", "be quiet until 5pm", "stay loud for the next 90 minutes", "active during work hours", or "resume" into the right mute / schedule call. Use when the user wants to silence the PA system, time-bound a quiet window, or define active hours — without making them remember the slash command syntax.
---

## When to fire

The user's message contains a request to silence, pause, schedule, or resume the PA system. Common phrasings:

| Intent | Phrasings | Action |
|---|---|---|
| Mute now, indefinite | "shut up", "be quiet", "disable PA", "mute claude-pa", "turn it off" | `bin/mute.sh indefinite` |
| Mute for a duration | "pause for 30m", "quiet for an hour", "mute for 2 hours" | `bin/mute.sh pause <duration>` |
| Mute until a clock time | "quiet until 5pm", "shut up until tomorrow morning" | `bin/mute.sh pause "until HH:MM"` |
| Resume | "unmute", "resume", "you can talk again", "wake up" | `bin/mute.sh off` |
| Active for next N | "stay loud for the next 90 min", "active for 2 hours" | `bin/schedule.sh during <duration>` |
| Recurring window | "active 9-5 weekdays", "only fire during work hours" | `bin/schedule.sh windows weekdays:09:00-17:00` |
| Clear schedule | "drop the schedule", "always allowed" | `bin/schedule.sh off` |
| Status | "is PA muted?", "what's the PA state?" | `bin/mute.sh status; bin/schedule.sh status` |

## Steps

1. **Parse the intent.** Map the user's phrasing to one of the rows above. If multiple intents are plausible, ask one short clarifying question; otherwise act.

2. **Convert duration phrases to canonical form**:
   - "an hour" / "1 hour" → `1h`
   - "half an hour" / "30 minutes" → `30m`
   - "the rest of the morning" → `until 12:00`
   - "the rest of the day" → `until 22:00` (or whatever feels right — confirm if ambiguous)
   - "tomorrow morning" → `until 09:00` (next-day semantics handled by `bin/mute.sh`)

3. **Run the command** via `$CLAUDE_PLUGIN_ROOT/bin/mute.sh` or `$CLAUDE_PLUGIN_ROOT/bin/schedule.sh`. Pass `--reason "<short reason>"` or `--label "<label>"` if the user gave one.

4. **Confirm in one line.** Echo back what was set, in human terms — e.g. "Muted until 5:00pm" or "Active for the next 90 minutes (deep work)". Don't dump JSON unless asked.

## Examples

User: *"hey shut up claude-pa, i'm in a meeting for the next hour"*
→ `bin/mute.sh pause 1h --reason "in a meeting"`
→ Reply: "Muted for 1 hour (in a meeting). Auto-resumes at 14:32."

User: *"only let it bark during work hours"*
→ `bin/schedule.sh windows weekdays:09:00-17:00`
→ Reply: "Active weekdays 09:00-17:00. Outside that, silent."

User: *"i'm starting a 2 hour focus block, keep it loud"*
→ `bin/schedule.sh during 2h --label "focus block"`
→ Reply: "Active for the next 2 hours (focus block). Auto-mutes at 16:32."

User: *"resume"*
→ `bin/mute.sh off`
→ Reply: "Unmuted."

## Don't

- Don't combine mute + schedule in one go unless the user explicitly asked. Pick the simplest tool for the request.
- Don't auto-set a reason/label unless the user gave one — don't fabricate context.
- Don't fire a confirmation dispatch on mute/pause (that would defeat the point). Firing one on `unmute` is fine and built into `/claude-pa:unmute`.

## Pairs with task planning

When the user says they're starting a task / planning session, prefer `schedule.sh during <duration>` over a permanent enable — the silence resumes automatically when the block ends. This is the recommended pattern for keeping claude-pa noisy *only* during deliberate working blocks.
