---
name: place-call
description: Place an outbound Vapi phone call to the user, their spouse, a named friend from the config, or an ad-hoc number. ALWAYS attaches a context-rich `reason` (what Claude is stuck on, why the user is needed) plus optional repo / idle-minutes / last-tag. Supports round-robin calling — Claude can dial through a list of friends in sequence until someone picks up. Use when the in-room escalation cascade has failed, when the user has explicitly asked to be phoned, or when Claude has a status update important enough to warrant a phone call. NEVER place a call without a real reason — a generic "they're not at their desk" call is worse than not calling.
---

# Place a Claude-PA phone call

The dispatcher assistant in Vapi (`vapi.assistant_id` in config) only knows
*who* it's calling and *what about* via the variables we pass at call time.
Without a `reason`, it falls back to a generic line. Always assemble a real
reason **before** firing the call.

## Targets

- `user`   — rings the user's own phone (direct escalation)
- `spouse` — rings their spouse to passive-aggressively pass on the message
- `friend` — rings a named entry from `config.friends[]`
- `adhoc`  — one-shot call to a number not in config (use sparingly)

## Inputs

- `target`: one of the above
- `reason` (REQUIRED): one or two plain-English sentences. Examples:
  - "Claude needs approval to push a PR to Claude-PA — has been waiting twelve minutes."
  - "Daniel's still wrestling with that Python bug and hasn't moved in a while."
- For `friend`: `name` (must match a `friends[].name` in config; case-insensitive)
- For `adhoc`:  `name` AND `phone` (E.164, e.g. `+972...`)
- Optional for any target: `repo`, `idle_minutes`, `last_tag`.

## Steps

1. **Decide the target.** If the user explicitly named one ("call my wife",
   "call Alex", "call me"), use that. Otherwise default to `user` — calling
   the spouse or a friend is more invasive.
2. **For friend calls**: read `$CLAUDE_PA_HOME/config.json` and confirm the
   named friend exists in `.friends[]`. If they don't, ask the user for the
   phone number first and either add via `/claude-pa:add-friend` or use
   `target=adhoc` for a one-shot call.
3. **Assemble the reason** from the live conversation context:
   - What is Claude blocked on right now? (approval, a question, an error)
   - How long has Claude been waiting? (rough minutes is fine)
   - Which repo / project? (basename of `cwd` is usually enough)
   Write it as a short, factual sentence — the assistant will paraphrase.
4. **Confirm gates** in `$CLAUDE_PA_HOME/config.json`:
   - `vapi.assistant_id` is set (otherwise tell the user to run
     `/claude-pa:setup-vapi-assistant` first).
   - The target's `*.enabled` is `true` (or `friends_calls.enabled` for
     friend/adhoc).
5. **Fire the call.** Run:
   ```bash
   $CLAUDE_PLUGIN_ROOT/bin/pa-phone-call.sh <target> --confirm \
       --reason "<assembled reason>" \
       [--name "<friend or adhoc name>"] \
       [--phone "<E.164 number, adhoc only>"] \
       [--repo "<repo>"] [--idle-minutes <N>] [--last-tag "<tag>"]
   ```
6. **Report.** Show the user the Vapi `call_id` returned by the script.

## Round-robin calling

When the user says "round-robin everyone" or "keep calling people until
someone picks up", iterate through `.friends[]` (and optionally spouse +
user) in order:

1. Place the call.
2. Wait ~60 seconds (use `Bash` with a sleep — but offer to skip the wait
   if the user wants to fire all at once).
3. Check `$CLAUDE_PA_LOG_DIR/phone-calls.log` and, if needed, the Vapi
   dashboard to see if the previous call connected.
4. If still no response, move to the next target.

The same `reason` string can be passed to every call, or you can tailor it
("you're being escalated to because nobody else picked up") on later calls.

Do NOT machine-gun every contact in parallel — that's a bad idea both
socially and for the Vapi rate limit. One call at a time, with a beat in
between.

## Hard rules

- **Never** call without a `--reason`. The script will exit 15 if you try.
- **Never** invent project status. Only convey what's actually true.
- **Never** call the spouse or a friend without thinking — default to
  `user` unless the user has explicitly asked to escalate further.
- **Never** write `VAPI_API_KEY` into config or any repo file.
