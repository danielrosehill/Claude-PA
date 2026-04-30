---
description: Walk through wiring Claude-PA to Home Assistant — discovers candidate entities (speakers, chime, doorbell, lights, RGB signal-bulb), tests each one live, and writes the validated config to $CLAUDE_PA_HOME/config.json.
---

Spawn the `setup-ha-entities` agent. It will:

1. Read the existing `$CLAUDE_PA_HOME/config.json` (or seed from `config/config.example.json`).
2. Discover Home Assistant entities via the home-assistant MCP.
3. Propose a mapping for each cascade slot (chime, desk/kitchen/living-room/whole-house speakers, doorbell, bedroom-flash light, RGB signal-bulb).
4. Test each accepted mapping live (play a test clip, flash a light, ring the chime).
5. Write the validated config back to `$CLAUDE_PA_HOME/config.json`.

The wake-user (bedroom lights at night) and spouse-call tiers default OFF and require explicit opt-in.

> Use the Agent tool with `subagent_type=setup-ha-entities`.
