# Claude-PA

A Claude Code plugin that turns Claude into a passive-aggressive PA system — barking status updates at you over a speaker, lighting up an RGB "Claude-signal" bulb on your desk, and, when you ignore all of that, escalating across your house via Home Assistant until somebody comes and finds you.

Two-way pun: **P**ersonal **A**ssistant / **P**ublic **A**ddress.

For people who spend all day in Claude Code and want a break from staring at the terminal waiting for "do you confirm?" prompts.

## The bit

Claude is the dispatcher. Sub-agents are the drivers. You are the absentee owner who keeps wandering off mid-shift.

When Claude needs your attention, it doesn't write a polite message — it grabs the radio and barks:

> *[static]* "Daniel! Pick up. Sub-agent's been waiting four minutes." *[static]*

If you don't respond, it escalates.

## The escalation cascade

| Tier | Pathway | Vibe |
|---|---|---|
| 0 | Local desk speaker | gruff dispatcher (default) |
| 1 | 🔔 Gentle chime (HA) | "ahem" |
| 2 | HA desk speaker (louder) | dispatcher, but louder |
| 3 | HA kitchen speaker | dispatcher, in the next room |
| 4 | 🚪 Doorbell ring (HA) | Pavlovian — you'll run before you remember |
| 5 | HA living room (PA register) | weary supermarket-announcer voice |
| 6 | 📢 Whole-house PA | "would the owner of this Claude Code session please return…" |
| 7 | 🌙 Bedroom lights flash (night, opt-in) | strobes you awake |
| 8 | ☎️ Twilio spouse call (opt-in, planned) | passive-aggressively rings your spouse to ask why you're not answering |

Tiers 7 and 8 default OFF. Each has hard config gates. The Twilio tier is a planned stub.

## The Claude-signal

Parallel to the audio cascade — a dedicated RGB bulb that Claude updates as state changes:

- 🔵 slow blue pulse — thinking
- 🟠 amber breathing — waiting on you
- 🩵 soft cyan — task running
- 🟢 green flash — done
- 🔴 red strobe — error

Peripheral-vision status without looking at the terminal. Fires automatically alongside any `/dispatch`, or directly via `/signal <pattern>`.

## How it works

- **Pre-recorded clip library** — short barked lines rendered once via Fish Audio (model IDs in `sounds/VOICES.md`, scripts in `sounds/MESSAGES.md`), mixed under a radio-static bed at runtime. No live TTS = consistent character + zero latency.
- **Per-user name clip** generated at onboarding and prepended to most dispatches so every call addresses you by name.
- **`/dispatch <tag>`** is the main Claude-facing command. Tag taxonomy: `attention:*`, `status:*`, `complete:*`, `pa:*`, `catastrophe:*`. The router fans out to audio + signal bulb in parallel.
- **`/setup-ha`** spawns an agent that uses the home-assistant MCP to discover entities, propose a mapping for every cascade slot, test each one live, and write the validated config.
- **CLAUDE.md snippet** appended per-repo — instructs Claude to call `/dispatch` whenever it would otherwise sit waiting silently.

## Where things live

The plugin folder ships **seed assets and scripts only**. User-specific state lives outside it:

```
$CLAUDE_PA_HOME           # default: ~/.local/share/claude-pa
├── config.json           # the live config (written by /setup-ha)
├── sounds/
│   ├── name/user.wav     # the personalised "[Daniel]!" clip
│   ├── bed/static.wav    # radio-static bed
│   └── attention/, status/, pa/, ...   # rendered character clips
├── logs/                 # dispatch history, spouse-call receipts
└── scripts/              # user-supplied custom scripts
```

Override with `$CLAUDE_PA_HOME` or follow `$XDG_DATA_HOME`.

## Status

Scaffolded. Voice clips need to be generated (see `sounds/MESSAGES.md`). Run `/claude-pa:onboard` then `/claude-pa:setup-ha` to wire it up.

📻 *next available driver, come in.*
