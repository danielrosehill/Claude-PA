# Claude-PA Test Scaffold

Drop-in throwaway repo for verifying claude-pa works on your machine without disturbing the household.

## Usage

```bash
cp -r <path-to-claude-pa-plugin>/templates/test-scaffold /tmp/claude-pa-test
cd /tmp/claude-pa-test
claude
```

Then read `STALL.md` to Claude and watch the dispatcher fire when it pauses.

Cleanup: `rm -rf /tmp/claude-pa-test`.

## What's pre-wired

- `.claude/settings.json` — enables the plugin, sets `CLAUDE_PA_MAX_TIER=0` (caps escalation at local desk speaker), sets `CLAUDE_PA_AUTOINIT=1` (auto-bootstraps user config from defaults if missing).
- `CLAUDE.md` — instructs Claude to call `/claude-pa:dispatch` on waits / completions instead of going silent.
- `STALL.md` — a synthetic task designed to make Claude pause and ping.
