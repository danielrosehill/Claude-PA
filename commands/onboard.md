---
description: First-run setup for Claude-PA. Creates $CLAUDE_PA_HOME, copies the config template, generates a personalised "[your name]!" clip via Fish Audio, and offers to run the HA-entities setup agent next.
---

## Steps

1. **Resolve and create the user data directory** — defaults to `~/.local/share/claude-pa` (or `$XDG_DATA_HOME/claude-pa` if set, or `$CLAUDE_PA_HOME` if explicitly exported). Create subdirs: `sounds/{name,bed,attention,status,pa,complete,catastrophe,ambient}`, `logs/`, `scripts/`.

2. **Copy `config/config.example.json` → `$CLAUDE_PA_HOME/config.json`** if it doesn't already exist. Ask the user for their preferred display name and write it to `user_name`. Also ask which voice pack to use (default: `wildcard`; other shipped options: `wildcard-2`, `dj-fred`, `alarmed-dispatcher`).

3. **Generate the personalised name clip.** Using the voice ID at `fish_audio.name_clip_voice_id` (default: `6c7e5318ee04449b8b3c0a06ad57b5b0`), render the line "{user_name}!" via the Fish Audio API. Requires `$FISH_AUDIO_API_KEY`. Save WAV to `$CLAUDE_PA_HOME/sounds/name/user.wav`. Render 2-3 variants if quota allows. Skip with a warning if the API key isn't set — the plugin still works, just without the name prefix.

4. **Render or seed the static-loop bed.** Either generate ~30s of radio static via `ffmpeg` (white noise + bandpass) or use a shipped seed at `$CLAUDE_PLUGIN_ROOT/sounds/bed/static.wav` if present. Save to `$CLAUDE_PA_HOME/sounds/bed/static.wav`.

5. **Test playback** by firing `bin/play-local.sh attention:generic` (will fail loudly if the attention clips haven't been rendered yet — that's fine, it tells the user what to do next).

6. **Offer to continue** with `/claude-pa:setup-ha` to wire up Home Assistant entities, or `/claude-pa:render-clips` to batch-render the seed message catalogue from `sounds/MESSAGES.md`.

## Required env vars

- `FISH_AUDIO_API_KEY` — for clip rendering
- `HASS_TOKEN` — for HA tiers (set later if needed)
