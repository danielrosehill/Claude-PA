---
name: setup-vapi-assistant
description: Provision (or update) the Claude-PA dispatcher assistant in Vapi using the shipped system prompt, then wire its assistant_id + phone_number_id into $CLAUDE_PA_HOME/config.json under user_call.vapi and spouse_call.vapi. Use when the user runs /claude-pa:setup-vapi-assistant or asks you to set up the Vapi side of Claude-PA.
---

# Setup the Claude-PA Vapi dispatcher assistant

The phone-call tiers (`user_call`, `spouse_call`) need a Vapi assistant whose
persona is **dispatcher calling about the user**, NOT a clone of the user.
This skill creates or updates that assistant and stores its id in config.

## Prerequisites

- `VAPI_API_KEY` exported (lives in `$CLAUDE_PA_HOME/env`, sourced by `~/.bashrc`).
- The `vapi` MCP server is registered in this repo's `.mcp.json`. The available
  tools you'll use:
  - `mcp__*__vapi__list_assistants`
  - `mcp__*__vapi__create_assistant`
  - `mcp__*__vapi__update_assistant`
  - `mcp__*__vapi__list_phone_numbers`
  - `mcp__*__vapi__get_assistant`

> The exact MCP tool name prefix depends on the host MCP namespace. Use
> whatever tool family is currently available; the function names above are
> the suffixes to match on.

## Steps

### 1. Load the system prompt

Read `templates/vapi/system-prompt.md` from the plugin root (resolve via
`$PLUGIN_ROOT` if needed; the file ships with the plugin). This is the
**dispatcher** persona prompt with `{{user_name}}` / `{{callee_name}}` /
`{{callee_role}}` placeholders that Vapi expands at call time via
`assistantOverrides.variableValues`.

### 2. Find or create the assistant

- Call `list_assistants` and look for one named `Claude-PA Dispatcher`.
- **If it exists**: call `update_assistant` to refresh the system prompt to
  the current shipped version (so re-running this skill always gets you the
  latest). Capture the existing `id`.
- **If not**: call `create_assistant` with:
  - `name`: `"Claude-PA Dispatcher"`
  - `firstMessage`: a short, in-character opener — e.g. `"Hi — this is dispatch calling on behalf of {{user_name}}'s computer. Is that {{callee_name}}?"`
  - `firstMessageMode`: `"assistant-speaks-first"`
  - `instructions`: the full content of `system-prompt.md`
  - `llm`: `{ "provider": "openai", "model": "gpt-4o" }` (or current best)
  - `voice`: pick a male, gruff, dispatcher-y voice (suggest `11labs` /
    `cartesia` — confirm with the user if multiple voices are reasonable)
  - `transcriber`: default

  Capture the new `id`.

### 3. Pick a phone number

Call `list_phone_numbers`. If exactly one is active, use it. If multiple,
ask the user which to use as the outbound caller for Claude-PA.

### 4. Write back to config

Edit `$CLAUDE_PA_HOME/config.json` with `jq` (atomic via tmp file). Write to
the **top-level** `vapi` block — both `user_call` and `spouse_call` inherit
from it:

```json
"vapi": { "api_key_env": "VAPI_API_KEY", "assistant_id": "<id>", "phone_number_id": "<id>" }
```

Per-target overrides (`user_call.vapi.assistant_id`, `spouse_call.vapi.assistant_id`)
are supported but should stay `null` unless the user explicitly wants a
different assistant for one target. Preserve all other fields (`enabled`,
`user_name`, `user_phone`, `spouse_name`, `spouse_phone`, etc.) — don't blow
them away.

`bin/pa-phone-call.sh` resolves the id via:

```
${BLOCK}.vapi.assistant_id // .vapi.assistant_id
```

so the top-level value is the default and per-target is the override.

### 5. (Optional) test call

Ask the user if they want to test. If yes, run:

```
bin/pa-phone-call.sh user --confirm
```

Their phone should ring from the Vapi number. The opening line should address
them by name and identify the caller as **dispatch**, not as the user.

If the persona is wrong, the most likely cause is that an older assistant is
still being reused — re-run this skill so the system prompt is updated, or
check the assistant in the Vapi dashboard.

## Notes

- The shipped `bin/pa-phone-call.sh` does **not** currently pass
  `assistantOverrides.variableValues`. The variables in the system prompt
  (`{{user_name}}`, `{{callee_name}}`, `{{callee_role}}`) will substitute as
  empty strings unless we extend the script to pass them. That's a follow-up
  — for now, the assistant should still behave as a dispatcher because the
  system prompt is unambiguous about the role even with blank variables.
  Track that as a known limitation.

- Never write `VAPI_API_KEY` (or any other secret) into `config.json`,
  `.mcp.json`, or any file inside the plugin repo. It belongs in
  `$CLAUDE_PA_HOME/env` only.
