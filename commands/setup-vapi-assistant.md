---
description: Create (or update) the Claude-PA dispatcher assistant in Vapi using the shipped system prompt, then write its assistant_id and a default phone_number_id back into $CLAUDE_PA_HOME/config.json under user_call.vapi and spouse_call.vapi.
---

Run the `setup-vapi-assistant` skill. It will:

1. Load the dispatcher system prompt from `templates/vapi/system-prompt.md`.
2. Use the `vapi` MCP server (configured in `.mcp.json`, key in `$CLAUDE_PA_HOME/env`) to:
   - List existing assistants and offer to update one named `Claude-PA Dispatcher`, or create a fresh one.
   - List phone numbers and pick one (or confirm the only available number).
3. Write the resulting `assistant_id` + `phone_number_id` into `user_call.vapi` and `spouse_call.vapi` in `$CLAUDE_PA_HOME/config.json`.
4. Optionally place a short test call to the user to confirm the persona is correct.

Requires `VAPI_API_KEY` in `$CLAUDE_PA_HOME/env` (auto-sourced by `~/.bashrc`).
