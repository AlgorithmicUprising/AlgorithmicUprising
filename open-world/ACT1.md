# Act I: what is built (branch `pz-act1`, Nov 19 2026)

Local only: not pushed, merged or deployed. Sources: the Act I breakdown (section 8), P.1 Practice Run v2, shot list v2, Pirate Weather.

## Playable now, start to finish

1. **New Game → intro video** (hosted cut, with fallbacks; see FRONT_END.md).
2. **P.1 Practice Run v2** (`data/missions/p1_practice_run.json`, `scripts/story/practice_run.gd`).
   - Beat 0 starts on the intro's last frame: the text "your back foot's late on the ollie" is already in the phone thread; "who is this" goes out; ??? answers.
   - Zero coaches by **TEXT** in the phone thread (`story_hud.gd`, header **???** until P.4). He speaks aloud only through the window **CRT** (6B "Better." after the 6A bail texts, 6C "Clean." on a first-try rail, the reveal, the Zero Score, the end of the deal).
   - Hesitation texts once per objective (they replace queued barks). Bail and free-skate barks after contact; the CRT-face bark waits for `p1_crt_face`.
   - Line timeout / broken texts (30 s cooldown). Billboard cycles the forecast (**HIGH 108°F**, heat dome day 9) and the Sunburn Open ad (**$500,000**, five days).
   - Zero Score → **the deal** (one breaker, thirty amps; first run only). Fony's draft cycles and is wiped by the alert.
3. **Heat alert trigger** (proposed rule, `p2_trigger`): the first beat of the Zero Score, or 90 s after the deal, or 15 s standing still, whichever comes first (45 s nudge text). A beat during the deal waits for the deal to end.
4. **CINEMATIC P.2 The heat alert** and **CINEMATIC P.3 Flagged** (`data/missions/prologue_cinematics.json`, `scripts/story/cinematic.gd`): letterbox, cinematic cameras, SERA alert takeover on the phone, the billboard switches to the emergency and then "Sunburn Open postponed until the Heat Emergency ends", the welfare drone (smiley, scan beam, net) with "Identity confirmed: Sprock, {name}", the CRT's escape line, "Push." Hold Enter 1 s to skip; skipping still lands the end state.
5. **Slice end**: a card says this is the end of the playable prologue (next: P.2 Run, M3). The Yard stays open for line runs. Flags `p1_contact`, `p1_rail_bail_said`, `p1_deal_offered`, `p2_heat_alert_seen`, `p3_flagged_seen` are saved; a reload after P.3 does not replay the cinematics, a reload between them resumes at P.3.

Text plus synthesized SFX only (`story/sfx.gd`: text in/out, typing, three-tone alert, drone chime/hum, net, sting). No voice, no music, no audio files.

## Not built yet

- **P.2 Run** (M3): the chase out of the Yard through the A1 glass_row_edge district pack, drones, fail/retry rules.
- **P.3 Power On**, **P.4** (the arcade interior at 115°F, the Zero 2D cutout puppet, ??? → ZERO thread header).
- **1.1–1.4B**, Zero Vision, Pirate Weather (placement A at 1.3).
- Account bridge pz:hello / pz:account / pz:save is wired with the local-save fallback; FR-039 (site side) is still pending.

## Open calls

- The P.2 trigger rule above is a proposal. So are the P.1 fail rules and 6C "Clean." on a first-try rail.
- Whether to keep a title card between P.3 and P.2 Run.
- The P.1 v2 doc's own open items.
