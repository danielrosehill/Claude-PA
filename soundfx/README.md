# Sound effects library

Pre-roll / ambient SFX shipped with the plugin. Distinct from `sounds/` (spoken character clips) — these are non-vocal stings used to flavour dispatches.

| File | Purpose | Used by |
|---|---|---|
| `airport-pa-bell.mp3` | Classic three-tone PA chime ("bing-bong"). Prepends every PA-register dispatch for that supermarket-announcement vibe. | `pa:*` tags |
| `freesound_community-ding-47489.mp3` | Sharp, clean ding. Default chime for tier-1 chime tier when chime entity is a `media_player`. | `chime` tier |
| `universfield-new-notification-036-485897.mp3` | Softer notification chime — alternative to the ding. | `chime` tier (alternative) |
| `success-chime.mp3` | Cheerful 3-note success chime. Prepends `complete:*` dispatches. | `complete:*` tags |
| `repeat_siren.mp3` | Looping warning siren. Pre-roll for `catastrophe:codebase-destroyed`. | `catastrophe:*` tags |
| `security-alamr.mp3` | Long security alarm. Used as the bed under the catastrophe tier instead of static. | `catastrophe:*` tier (bed override) |
| `freesound_community-alarm-clock-90867.mp3` | Alarm-clock buzzer. Plays alongside the bedroom-light flash on the wake tier (tier 7). | `wake` tier |
| `universfield-automobile-horn-153260.mp3` | Sharp taxi horn — fits the original taxi-rank pun. Pre-roll for generic attention barks. | `attention:generic` |
| `universfield-automobile-horn-02-352065.mp3` | Longer impatient honk. Pre-roll for "hurry up" subagent nags. | `status:subagent-hurry` |
| `universfield-ship-horn-352063.mp3` | Deep, grave ship-horn BWAAAAA. Pre-roll for the whole-house PA tier and certain catastrophe variants — sounds like the tannoy on a sinking ferry. | tier 6 (whole-house PA) |
| `u_rm9kk1yu9k-cymbal-crash-412547.mp3` | Cymbal crash. Punchline payoff for project-complete dispatches. | `complete:project` |
| `freesound_community-088524_walkie-talkie-83500.mp3` | Walkie-talkie key-up "kssht" click. Bookends every dispatcher-register transmission so it sounds like a real radio call. | `register_wrap.dispatcher.intro` + `outro` |
| `titigwen-mayday-mayday-392997.mp3` | "Mayday, mayday!" distress call. Pre-roll for genuine blocker situations. | `status:blocker` |
| `help.mp3` | Urgent "help" call. Pre-roll for approval-needed dispatches. | `attention:approval-needed` |
| `digitalstore07-hey-430371.mp3` | Sharp "HEY!" — classic attention grab. | `attention:generic` (random pool) |
| `freesound_community-shout-104972.mp3` | Generic male shout. | `attention:generic` (random pool) |
| `freesound_community-pandora-huuto1-108251.mp3` | Finnish-flavoured shout ("huuto"). | `attention:generic` (random pool) |
| `freesound_community-female_shout_02-40730.mp3` | Female shout — voice variety in the attention pool. | `attention:generic` (random pool) |
| `freesound_community-heavy-grunt-6969.mp3` | Exasperated grunt. Pre-roll for "subagent hurry up" dispatches. | `status:subagent-hurry` (random pool) |
| `11325622-glass-breaking-sound-effect-240679.mp3` | Glass shattering — the literal sound of a codebase breaking. | `catastrophe:codebase-destroyed` (random pool) |

## Random pools

When `tag_sfx` maps a key to an array, `play-local.sh` picks one entry at random per dispatch — so attention barks rotate through the shout pool instead of feeling repetitive.

The manifest's `sfx` block maps tag/tier → SFX file. `play-local.sh` and `chime.sh` resolve these to absolute paths via `paths.sh`.
