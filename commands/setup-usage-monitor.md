---
description: Wire bin/check-usage.sh into a Claude Code Stop hook so usage warnings fire automatically on threshold crossings (50/75/90/95%).
---

## What this does

Adds a `Stop` hook to project-level `.claude/settings.json` that runs `${CLAUDE_PLUGIN_ROOT}/bin/check-usage.sh` after every assistant turn. The script:

- Reads the session's JSONL transcript under `~/.claude/projects/<encoded-cwd>/<session>.jsonl`
- Sums `input_tokens + output_tokens + cache_*_tokens` across all assistant messages
- Compares against `usage_monitor.session_token_budget` in `$CLAUDE_PA_HOME/config.json`
- On the first crossing of each threshold (50/75/90/95%), fires `/dispatch usage:warning-XX` so Claude barks the matching pre-recorded warning
- Tracks fired thresholds in `$CLAUDE_PA_HOME/state/usage-thresholds-fired.json` so each warning fires once per session

## Steps

1. Set `usage_monitor.enabled: true` in `$CLAUDE_PA_HOME/config.json`. Adjust `session_token_budget` if the default 200k doesn't match your plan.

2. Add a `Stop` hook to `.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/bin/check-usage.sh || true"
          }
        ]
      }
    ]
  }
}
```

The `|| true` keeps a hook failure from blocking Claude's turn — usage monitoring is best-effort.

3. Verify by running `bin/check-usage.sh` directly inside an active session — it should log to `$CLAUDE_PA_HOME/logs/usage.log` and fire a dispatch if you've already crossed a threshold.

## Notes

- `session_token_budget` is local — Claude Code doesn't expose your account's hard limit, so this is a self-imposed soft budget. Tune it to match how long your sessions actually run before you hit the wall.
- For account-level rate-limit warnings (the 5-hour rolling window on the Pro/Max plans), this hook can't see them directly — Claude Code surfaces those via its own UI. A future iteration could parse the `/cost` output instead.
