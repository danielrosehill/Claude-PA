# Voice catalogue (Fish Audio)

Daniel-curated voices. Pick per clip in `manifest.json`. Render via the Fish Audio web UI or API; save the resulting WAV/MP3 into `sounds/<category>/<slug>.wav`.

| Tag | Model ID | Vibe / suggested role |
|---|---|---|
| `crazy-energetic` | `8fe7d1ff3ed145bb93645806edc21298` | Loud, alarmed — emergency / "stop right there" register |
| `passive-aggressive-tired` | `6c7e5318ee04449b8b3c0a06ad57b5b0` | Worn-down, sighing — "I've been cleaning up after you all night" energy. Backbone of the PA pack. |
| `voice-03` | `7fedfdbd6ae64740b32c621ed907609a` | (TBD — audition) |
| `voice-04` | `ead241ca12c64514a5acc9e97106fe82` | (TBD — audition) |
| `voice-05` | `2b5baf5e904d43c785e24dc3fa22f87e` | (TBD — audition) |
| `voice-06` | `7676e3b1b88e4b72a768b85a912f3a2d` | (TBD — audition) |
| `voice-07` | `168dca1915364fd5bf61bdf441facd3f` | (TBD — audition) |
| `voice-08` | `57edb16ea01a4d12adaf5e7ea518be0e` | (TBD — audition) |
| `voice-09` | `7505ddc54a33488cb793abb3c682f4b5` | (TBD — audition) |
| `voice-10` | `d334e6ab4be74251b5ff0c9965cbb4ef` | (TBD — audition) |
| `voice-11` | `81ce150b91574e6698161cc2f5765349` | (TBD — audition) |
| `voice-12` | `e600e46129be4b5aa018f5ef2960c759` | (TBD — audition) |
| `dj-fred` | `29e4b6f5c8ea4db8bbcfb7ca9720bc6c` | High-energy DJ — for "the project has been successfully completed" celebration drop |
| `voice-14` | `7db28f1d6f70496e92a6c4b23e2ed5fc` | (TBD — audition) |

## URL pattern

`https://fish.audio/app/text-to-speech/?modelId=<MODEL_ID>&text=<URL_ENCODED_TEXT>`

## Casting suggestions

- **Dispatcher (default barker)** — gruff, gravelly, slightly impatient. Audition voices 03–12 to find one.
- **Supermarket-PA narrator** — flat, weary, professional. Use `passive-aggressive-tired` or audition for something even flatter.
- **Emergency voice** — `crazy-energetic` for "codebase destroyed" type events.
- **Celebration voice** — `dj-fred` for project completion fanfare.
