---
description: Add a friend (name + phone) to $CLAUDE_PA_HOME/config.json so Claude can call them via /claude-pa:place-call with target=friend. Optional fields: role (e.g. "a coworker"), per-friend Vapi overrides.
---

Append a new entry to `.friends[]` in `$CLAUDE_PA_HOME/config.json`. Each
entry looks like:

```json
{
  "name":  "Alex",
  "phone": "+972501234567",
  "role":  "a coworker",
  "vapi":  { "assistant_id": null, "phone_number_id": null }
}
```

`name` and `phone` (E.164) are required. `role` is what the dispatcher
assistant uses to set tone and explain the relationship to the callee
(defaults to `"a friend of the user"`). `vapi.*` overrides are optional —
omit to inherit from the top-level `vapi` block.

Use `jq` to write atomically — read the current config, append the entry,
write to a tmp file, then `mv` over. Don't blow away unrelated fields.

After adding, confirm by reading `.friends[].name` back and listing names
to the user.
