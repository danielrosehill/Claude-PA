---
description: First-run setup for Claude-PA. Creates $CLAUDE_PA_HOME, copies the config template, generates a 30s radio-static bed via ffmpeg, optionally renders a personalised name clip via Fish Audio if the API key is set, and offers to chain into the HA-entities setup agent. No API key required for the plugin to work — voice clips ship pre-rendered with the plugin.
---

## What you need

- `ffmpeg` (for static bed + clip mixing) — required
- `jq` — required
- `paplay` / `aplay` / `ffplay` — for local audio playback (PipeWire/PulseAudio)
- `python3-tk` (optional) — for the full-screen flash overlay; falls back to `notify-send` otherwise
- `mosquitto-clients` (optional) — only if using the MQTT transport
- `FISH_AUDIO_API_KEY` (optional) — only needed to render a personalised "[your name]!" prefix clip; the plugin works without it

## Steps

1. **Resolve and create the user data directory.** Default: `~/.local/share/claude-pa` (or `$XDG_DATA_HOME/claude-pa` if set, or `$CLAUDE_PA_HOME` if explicitly exported). Create subdirs: `sounds/{name,bed,attention,status,pa,complete,catastrophe,ambient}`, `logs/`, `scripts/`.

2. **Copy `config/config.example.json` → `$CLAUDE_PA_HOME/config.json`** if it doesn't already exist. Ask the user:
   - Their preferred display name (used for the optional name-clip prefix). Write to `user_name`.
   - Which voice pack to use. Defaults to `wildcard`. Other packs shipped with the plugin: `wildcard-2`, `dj-fred`, `alarmed-dispatcher` (usage warnings only). Write to `voice_pack`.
   - Whether to enable the screen-flash overlay (default: yes, mode `auto`).

3. **Generate the static-loop bed via ffmpeg.** No API needed:
   ```bash
   ffmpeg -y -loglevel error \
     -f lavfi -i "anoisesrc=color=white:duration=30:sample_rate=44100" \
     -af "bandpass=f=2000:width_type=h:w=1500,volume=-8dB" \
     -ac 2 -ar 44100 "$CLAUDE_PA_HOME/sounds/bed/static.wav"
   ```
   30 seconds is plenty — `play-local.sh` loops it under spoken clips.

4. **Optionally render a personalised name clip.** Only if `$FISH_AUDIO_API_KEY` is set. Use the voice ID at `fish_audio.name_clip_voice_id` (default: `6c7e5318ee04449b8b3c0a06ad57b5b0`) to render the line "{user_name}!" via the Fish Audio API. Save WAV to `$CLAUDE_PA_HOME/sounds/name/user.wav`. Render 2-3 variants if quota allows. **Skip with a one-line note if the key isn't set** — the plugin still works, just without the name prefix on dispatches.

5. **Smoke-test the dispatch path.** Fire one tier-0 dispatch with the cap and force flag in place (so this works even if the user has muted globally):
   ```bash
   CLAUDE_PA_FORCE=1 CLAUDE_PA_MAX_TIER=0 \
     "$CLAUDE_PLUGIN_ROOT/bin/dispatch.sh" attention:generic --tier 0 --no-signal --no-flash
   ```
   If the user's machine has working audio they should hear a bark. If `paplay` errors, surface it — local sink probably needs `local_audio.sink` set in the config.

6. **Offer to continue.** Two natural next steps:
   - `/claude-pa:setup-ha` — wire up Home Assistant entities for tiers 2-7 (chime, multi-room speakers, doorbell, signal bulb, bedroom strobe).
   - Manual MQTT config — if the user runs Mosquitto instead of HA, point them at the `mqtt.*` block in `~/.local/share/claude-pa/config.json`.
   - Skip both if they only want the local desk speaker (tier 0 works out of the box).

## Notes

- Voice clips ship pre-rendered in the plugin under `sounds/voices/<voice_pack>/`. The user dir doesn't need its own copies — the resolver falls back to the plugin's seed assets automatically.
- If the user later wants a different voice pack, just edit `voice_pack` in `~/.local/share/claude-pa/config.json` — no re-render needed.
- The plugin gracefully handles a missing name clip and a missing static bed (will play the raw spoken clip).
