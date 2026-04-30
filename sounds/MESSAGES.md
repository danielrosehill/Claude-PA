# Seed message catalogue

Lines to render to WAV via Fish Audio. Each line below is a target clip — `slug` is the filename (saved as `sounds/<category>/<slug>.wav`), `voice` is the model tag from `VOICES.md`, `text` is the exact script.

After rendering, the file path goes into `sounds/manifest.json` keyed by tag.

---

## attention/

Short barks to grab the user's eye. Played first, before any status content.

| slug | voice | text |
|---|---|---|
| `user-user` | dispatcher | "User! User! Your approval is needed!" |
| `pick-up` | dispatcher | "Pick up. Pick up." |
| `oi` | dispatcher | "Oi! You there." |
| `hey-you` | dispatcher | "Hey, you. Yeah, you." |

## status/

Routine progress updates. Played alone or after an attention clip.

| slug | voice | text |
|---|---|---|
| `subagent-hurry-up` | dispatcher | "Subagent! Hurry up!" |
| `trying-subagent` | dispatcher | "Tryin' to get a hold of a subagent." |
| `running-plugin` | dispatcher | "Running a plugin." |
| `still-waiting` | dispatcher | "Still waitin' on driver four. Typical." |
| `subagent-done` | dispatcher | "Subagent's back. Job's done." |
| `blocker-hit` | dispatcher | "We got a blocker. Need you on the radio." |

## pa/

The whole-house, supermarket-announcer register. Flat, weary, professional. Used by the escalation tier.

| slug | voice | text |
|---|---|---|
| `pa-return-to-computer` | passive-aggressive-tired | "This is a message for the user from Claude Code. Kindly return to the computer where your input is needed." |
| `pa-attention-household` | passive-aggressive-tired | "Attention household. If anyone can hear this, Claude is looking for the user. Repeat — Claude is looking for the user. Thank you." |
| `pa-front-desk` | passive-aggressive-tired | "Would the owner of this Claude Code session please return to their workstation. Your sub-agent has been waiting." |
| `pa-customer-service` | passive-aggressive-tired | "This is a customer service announcement. Your AI assistant is at the front desk. Your AI assistant. At the front desk." |

## complete/

Project completion fanfare.

| slug | voice | text |
|---|---|---|
| `project-complete` | dj-fred | "The project has been successfully completed!" |
| `job-done-gruff` | dispatcher | "Job's done. Pull it forward." |

## catastrophe/

The clip you hope never plays. Solemn, professional, devastating.

| slug | voice | text |
|---|---|---|
| `codebase-destroyed` | passive-aggressive-tired | "This is a message for the user from Claude Code. Regrettably, due to circumstances beyond our control, your entire codebase has been destroyed and all progress has been irrevocably lost. We apologize sincerely for the inconvenience caused." |

## usage/

Usage-limit warnings. Fired by `bin/check-usage.sh` on threshold crossings (configurable via `usage_monitor.thresholds`). Tone: dispatcher, slightly concerned but professional.

| slug | voice | text |
|---|---|---|
| `halfway` | dispatcher | "Halfway through the tank. Just lettin' you know." |
| `three-quarters` | dispatcher | "Three-quarters used. Pace yourself." |
| `ninety-percent` | dispatcher | "Ninety percent. Wrap it up." |
| `limit-imminent` | dispatcher | "Almost out. Last call before the meter runs dry." |
| `limit-hit` | passive-aggressive-tired | "Usage limit reached. The taxi rank is closed for the evening. Please return tomorrow." |

## ambient/

Low-volume grumbling that fires randomly during long-running tasks for atmosphere. Plays only on the desk speaker.

| slug | voice | text |
|---|---|---|
| `ambient-typical` | dispatcher | "Typical." |
| `ambient-cmon` | dispatcher | "C'mon, c'mon." |
| `ambient-radio-check` | dispatcher | "Radio check, radio check." |

---

## Rendering workflow

1. Pick a voice in `VOICES.md`.
2. Visit `https://fish.audio/app/text-to-speech/?modelId=<id>&text=<urlencoded>`.
3. Render → download WAV.
4. Save to `sounds/<category>/<slug>.wav`.
5. Add the path to `manifest.json` under the matching tag.

Or batch via the Fish Audio API once `bin/render-clips.sh` is implemented (TODO).
