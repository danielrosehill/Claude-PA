<p align="center">
  <img src="banner/banner.png" alt="Claude-PA" width="100%" />
</p>

# Claude-PA

A Claude Code plugin that turns Claude into a passive-aggressive PA system — barking status updates at you over a speaker, lighting up an RGB "Claude-signal" bulb on your desk, and, when you ignore all of that, escalating across your house via Home Assistant until somebody comes and finds you.

Two-way pun: **P**ersonal **A**ssistant / **P**ublic **A**ddress.

For people who spend all day in Claude Code and want a break from staring at the terminal waiting for "do you confirm?" prompts.

## The bit

Claude is the dispatcher. Sub-agents are the drivers. You are the absentee owner who keeps wandering off mid-shift.

When Claude needs your attention, it doesn't write a polite message — it grabs the radio and barks:

> *[static]* "[Your name]! Pick up. Sub-agent's been waiting four minutes." *[static]*

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

## On-screen flash

Same color taxonomy as the bulb, but on your monitor. A brief full-screen colored overlay (Python tkinter) flashes for ~600ms with the tag label. Falls back to a `notify-send` desktop notification if tkinter isn't available, or to nothing on headless boxes. Disabled in `config.screen_flash.enabled` if you'd rather not.

## Transports

Three independent ways to fire audio at a remote speaker — pick whichever matches your home stack:

- **Local PipeWire / PulseAudio** — desk speaker, no network needed. Always available.
- **Home Assistant** — REST API to `media_player.*` entities. Tier targets prefixed `ha:<key>`. Configured via `/claude-pa:setup-ha`.
- **MQTT (Mosquitto)** — direct publish to a configured topic, JSON payload with audio URL. Tier targets prefixed `mqtt:<key>`. Useful for ESP / Tasmota / custom subscribers, or anyone running a broker without HA.

## How it works

- **Pre-recorded clip library** — short barked lines rendered once via Fish Audio (model IDs in `sounds/VOICES.md`, scripts in `sounds/MESSAGES.md`), mixed under a radio-static bed at runtime. No live TTS = consistent character + zero latency. Multiple voice packs ship — switch via `voice_pack` in config.
- **Per-user name clip** generated at onboarding and prepended to most dispatches so every call addresses you by name.
- **`/dispatch <tag>`** is the main Claude-facing command. Tag taxonomy: `attention:*`, `status:*`, `complete:*`, `pa:*`, `catastrophe:*`. The router fans out to audio + signal bulb + screen flash in parallel.
- **`/setup-ha`** spawns an agent that uses the home-assistant MCP to discover entities, propose a mapping for every cascade slot, test each one live, and write the validated config.
- **CLAUDE.md snippet** appended per-repo — instructs Claude to call `/dispatch` whenever it would otherwise sit waiting silently.
- **Escalator daemon** — a `systemd --user` service (with a plain-`nohup` fallback) that watches an idle marker file. When Claude fires an `attention:*` dispatch at tier 0 and you don't reply, the daemon walks the manifest's `delay_seconds` ladder and re-fires `dispatch` at higher tiers (chime → kitchen → doorbell → whole-house PA → bedroom strobe) until a `UserPromptSubmit` hook clears the marker. Install with `/claude-pa:setup-escalator`. Without this the cascade can't escalate — Claude only fires once per dispatch and has no way to nag you on a timer.

## Where things live

The plugin folder ships **seed assets and scripts only**. User-specific state lives outside it:

```
$CLAUDE_PA_HOME           # default: ~/.local/share/claude-pa
├── config.json           # the live config (written by /setup-ha)
├── sounds/
│   ├── name/user.wav     # the personalised "[your name]!" clip
│   ├── bed/static.wav    # radio-static bed
│   └── attention/, status/, pa/, ...   # rendered character clips
├── logs/                 # dispatch history, spouse-call receipts
└── scripts/              # user-supplied custom scripts
```

Override with `$CLAUDE_PA_HOME` or follow `$XDG_DATA_HOME`.

## Quiet mode

`/claude-pa:mute 30m`, `/claude-pa:mute until 17:00`, `/claude-pa:mute indefinite`, `/claude-pa:unmute`. The dispatcher checks a sentinel before every fire — muted dispatches are logged but silent. Or just say "shut up claude-pa for an hour" and the `quiet-mode` skill picks it up.

## Schedule

`/claude-pa:schedule during 90m` for session-scoped active windows (pairs with task-planning workflows — the system auto-mutes when the block ends). `/claude-pa:schedule windows weekdays:09:00-17:00` for recurring time-of-day rules. Outside the schedule the dispatcher is silent without you having to mute manually.

## Status

Voice packs rendered (4 packs shipped). Core dispatch + screen flash + MQTT + HA transports working. Run `/claude-pa:onboard` then `/claude-pa:setup-ha` to wire up Home Assistant, or set the `mqtt.*` block in config to use Mosquitto instead.

## Trying it out

A pre-built test scaffold ships at `templates/test-scaffold/`. The `test-harness` skill copies it into a throwaway directory, hard-caps escalation at tier 0 (local desk speaker only), and gives you a synthetic stalling task to make Claude bark. No risk of accidentally firing the doorbell or whole-house PA while testing.

📻 *next available driver, come in.*
