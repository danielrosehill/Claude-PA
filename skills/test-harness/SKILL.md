---
name: test-harness
description: Drop the pre-built Claude-PA test scaffold into a chosen location so the user can verify dispatch + escalation cascade end-to-end without disturbing the household. The scaffold ships with the plugin at templates/test-scaffold/ — this skill just copies it, sanity-checks it, and prints the next command. Tier cap is hard-coded to 0 (local desk speaker only). Use when the user says "test claude-pa", "is this working?", "let's try the PA system", etc.
---

## What this is

The plugin ships a pre-built throwaway repo at `${CLAUDE_PLUGIN_ROOT}/templates/test-scaffold/` containing `.claude/settings.json` (plugin enabled, `CLAUDE_PA_MAX_TIER=0`, `CLAUDE_PA_AUTOINIT=1`), a `CLAUDE.md` with the dispatch protocol, and a `STALL.md` synthetic stalling task. This skill just gets it onto disk where the user wants it.

## Steps

1. **Pick a destination.** Default: `/tmp/claude-pa-test-$(date +%s)`. If the user names a path, use that. If they say "right here" / "current dir", use `$PWD/claude-pa-test`.

2. **Resolve the source.** `SRC="${CLAUDE_PLUGIN_ROOT}/templates/test-scaffold"`. If `CLAUDE_PLUGIN_ROOT` isn't set, walk up from this skill file two levels.

3. **Copy.** `cp -r "$SRC" "$DEST"`. Refuse and ask for confirmation if `$DEST` already exists.

4. **Bootstrap user config** if missing. The settings.json sets `CLAUDE_PA_AUTOINIT=1` so the dispatcher self-bootstraps on first call, but doing it eagerly surfaces problems before Claude is summoned:
   ```bash
   CLAUDE_PA_AUTOINIT=1 bash -c 'source "$0/bin/paths.sh" && claude_pa_autoinit_config' "$CLAUDE_PLUGIN_ROOT"
   ```

5. **Smoke-test the dispatch path.** Fire one tier-0 dispatch with the tier cap already in place:
   ```bash
   CLAUDE_PA_AUTOINIT=1 CLAUDE_PA_MAX_TIER=0 \
     "$CLAUDE_PLUGIN_ROOT/bin/dispatch.sh" attention:generic --tier 0 --no-signal --no-flash
   ```
   If that errors, surface the error verbatim — fix it before handing off, since the user's session will hit the same wall.

6. **Print the handover.** Tell the user:
   - The destination path
   - Exact command: `cd "$DEST" && claude`
   - That the cap is hard-locked at tier 0 inside the scaffold's settings.json
   - That cleanup is `rm -rf "$DEST"`

## Don't

- Don't auto-launch Claude in the scratch dir — let the user do it.
- Don't raise `CLAUDE_PA_MAX_TIER` in the scaffold. If the user wants to test higher tiers, they edit `.claude/settings.json` themselves so they understand what they're enabling.
- Don't auto-cleanup. The scaffold is throwaway but the user might want to inspect logs after.

## Failure modes

- **Clips not found in smoke test**: voice-pack remap failed. Confirm `ls "$CLAUDE_PLUGIN_ROOT/sounds/voices/wildcard/attention/"` shows the rendered MP3s.
- **`paplay` fails / no audio**: the dispatch path is fine but the local sink isn't reachable. Suggest setting `local_audio.sink` in `~/.local/share/claude-pa/config.json` (or running `pactl list short sinks` to find the right name).
- **Screen flash doesn't fire**: needs `python3-tk` for overlay mode, or `libnotify-bin` for notify mode. Check the resolved mode by running `bin/screen-flash.sh waiting` directly.
