# Act I: what is built (branch `pz-act1`, Nov 19 2026; M3 added the same night)

Local only: not pushed, merged or deployed. Sources: the Act I breakdown (section 8, the P.2 Run row and A1), script v1.0 MISSION P.2 Run, P.1 Practice Run v2, shot list v2, Pirate Weather.

Polish (M3 round): no "Click to look" or other input prompt over a cutscene or a fade; the phone docks under the score stack at whatever height it has, so it never overlaps it (1280x720, 1920x1080 and narrow windows all lay out in the same 1280-wide space).

## Playable now, start to finish

1. **New Game → intro video** (hosted cut, with fallbacks; see FRONT_END.md).
2. **P.1 Practice Run v2** (`data/missions/p1_practice_run.json`, `scripts/story/practice_run.gd`).
   - Beat 0 starts on the intro's last frame: the text "your back foot's late on the ollie" is already in the phone thread; "who is this" goes out; ??? answers.
   - Zero coaches by **TEXT** in the phone thread (`story_hud.gd`, header **???** until P.4). He speaks aloud only through the window **CRT** (6B "Better." after the 6A bail texts, 6C "Clean." on a first-try rail, the reveal, the Zero Score, the end of the deal).
   - Hesitation texts once per objective (they replace queued barks). Bail and free-skate barks after contact; the CRT-face bark waits for `p1_crt_face`.
   - Line timeout / broken texts (30 s cooldown). Billboard cycles the forecast (**HIGH 108°F**, heat dome day 9) and the Sunburn Open ad (**$500,000**, five days).
   - Zero Score → **the deal** (one breaker, thirty amps; first run only). Fony's draft cycles and is wiped by the alert.
3. **Heat alert trigger** (accepted for now, `p2_trigger`): the first beat of the Zero Score, or 90 s after the deal, or 15 s standing still, whichever comes first (45 s nudge text). A beat during the deal waits for the deal to end.
4. **CINEMATIC P.2 The heat alert** and **CINEMATIC P.3 Flagged** (`data/missions/prologue_cinematics.json`, `scripts/story/cinematic.gd`): letterbox, cinematic cameras, SERA alert takeover on the phone, the billboard switches to the emergency and then "Sunburn Open postponed until the Heat Emergency ends", the welfare drone (smiley, scan beam, net) with "Identity confirmed: Sprock, {name}", the CRT's escape line, "Push." Hold Enter 1 s to skip; skipping still lands the end state.
5. **MISSION P.2 Run** (milestone M3; `data/missions/p2_run.json`, `scripts/story/p2_run.gd`, `scripts/story/chase.gd`).
   - Starts straight from P.3's "Push." The **A1 glass_row_edge** district (`districts/glass_row_edge/`, its own pack `districts/glass_row_edge.pck`, about 19 KB against the 8 MiB per-district cap) is armed and requested at the start, so it is in long before the fence; the edge apron holds the wheels meanwhile.
   - The Yard's east wall opens a 6 m gap behind a dumpster at z 26 to 32 for the run only (Prologue-only; it closes again when the story stops). A lime beacon marks the next target.
   - The welfare drone chases at once; two grey Warden enforcement drones join 4 s later. They follow his own trail (never through walls), catch up when he is far ahead, get a boost from the parking camera, and slow to a search when they lose sight of him.
   - The van blocks the alley's middle lane: **(A)** over the dumpster, up onto loading dock 3 and along its grindable ledge, down the stair set; or **(B)** up the parking ramp under the drone camera ("SPOTTED") and down the far side. Both are discovered into the save (`exploration`, flags `p2_route_dock` / `p2_route_ramp`).
   - Plaza: the boutique, shoppers, and the Silver-tier **mister kiosk** that switches off as he passes ("Comfort mist is available to Silver tier and above."). Zero's face hops across **three street screens** (parking meter, store window, bus shelter) with the script's lines, and each line also lands in the **???** thread.
   - **Fail rule (breakdown proposal):** caught by a net -> short fade -> restart at the last checkpoint (Yard, fence gap, plaza, culvert). No lives; the clock keeps running; T also restarts at the checkpoint.
   - The loose **drain grate** beside the stairs -> the culvert (a fade and a narration line) -> up in the Yard's NE corner -> across to the **arcade's side door** -> "The chain falls away. Something inside has unlocked it."
   - **Zero Score is time-based:** the first escape sets Zero's time (the next whole 5 s below it, never under 30 s); best and Zero times are saved in the mission record in ms. Beating it gets a text.
6. **MISSION P.3 Power On** (Act I M4, Nov 20 2026; `scripts/story/p3_power_on.gd`, `data/missions/p3_power_on.json`): the side door fades into the dark Solar Arcade, its own district pack **solar_arcade_dark** (`districts/solar_arcade_dark/`, off-map east at x 212 .. 248, z -42 .. -10; armed and requested when P.2 Run starts, a few KB against the 8 MiB cap). The script's INT. lines play (narration, Fony, the CRT on the workbench whispering: "You're ninety-eight point six. Everything else in here is a hundred and fifteen degrees."; the script's 37/46 were Celsius). Then on foot: **E** takes the fuse in reach: the cabinet coin box (north row), the toolbox under the workbench, the light fixture over the tall cabinet (walk up the toppled cabinet leaning on it). Each fuse gets the script's whispered line. **E** at the breaker ("DO NOT RECONNECT – IT TALKS.") with all three throws it (CLUNK, the roof hums). The thermal sweep is a light crossing the south windows plus a HUD bar (`sweep_s` 100); if it gets to the end the drone "finds a warm spot": fade, back to the last fuse found, fuses kept, sweep restarts (the breakdown's proposed rule). Save: mission `p3_power_on` (`done` = fuses found, `checkpoint` = last fuse), flags `p3_power_started`, `p3_fuse_<id>`, `p3_power_done`; reload mid-P.3 resumes with the fuses kept and skips the INT. lines. SFX: synthesized `pickup` and `breaker` cues.
   - Polish (Nov 20): the room is truly dark (interior preset: no sun, near-black sky, low warm ambient; roof closed; the broken-panel shafts are a thin haze) and lit by practicals (CRT glow, red EXIT, bench lamp, breaker lamp, shaft pools, a cold glow at the token counter). The score box shows **FUSES n/3** and **SWEEP [####------]** (ASCII, no tofu) instead of ZERO TIME; the breaker sign is flat on the box in two lines, sized to fit on screen. Dawn comes back when the story leaves the arcade.
7. **CINEMATIC P.4 Zero** (first pass, `prologue_cinematics.json` `p4_zero`; new cinematic ops `CAM` and `HOST`): beats 1 the breaker and the power cascade (tubes, the token sign, cabinets glowing through their sheets); 2 the drone outside logs a "voluntary disappearance"; 3 Zero boots on the workbench as a **2D cutout puppet** (`scripts/story/zero_puppet.gd`, the approved sheet's rig layers in `assets/zero_puppet/`: jacket with the red ? patch, cream CRT head, lime glyph face; slump → boot → awake), "Hi. I'm Zero.", the phone thread header **??? → ZERO**; 4 the **ZR-0 serial plate on the back of his CRT** (camera behind him); 5 the script's dialogue (Dusk, CLEARANCE, Fony's mom, "The contest will wait. The heat won't.", Stillwater; Fahrenheit: "under eighty-five degrees"); 6 the title card PROJECT ZERO: THE ALGORITHMIC UPRISING. Hold Enter skips and still lands power on, Zero awake and the ZERO header. Reload between the breaker and P.4 plays P.4; after it, straight to the slice end in the lit arcade.
   - Placeholders: no arm/servo rig or jacket-on animation (narrated), no ceiling fans, the billboard update is narrated, no music under the title card (text + SFX only), the body's back is a plain card.
8. **End card:** Act I 1.1 Fine Print is next (not built yet). **T runs P.2 again** (then P.3 and P.4).

Text plus synthesized SFX only (`story/sfx.gd`: text in/out, typing, three-tone alert, drone chime/hum, net, sting). No voice, no music, no audio files.

## Not built yet

- Act I 1.1 Fine Print onward; P.4's missing art (servo arms, jacket animation, fans, the first song under the title card).
- **1.1–1.4B**, Zero Vision, Pirate Weather (placement A at 1.3).
- Account bridge pz:hello / pz:account / pz:save is wired with the local-save fallback; FR-039 (site side) is still pending.

## Toggles for the open calls

- 6C "Clean." on a first-try rail: `toggles.first_try_clean` in `data/missions/p1_practice_run.json` (default true).
- A "MISSION P.2 · RUN" title card between P.3 and the run: `toggles.title_card` in `data/missions/p2_run.json` (default false).

## Open calls

- **P.3:** sweep length (100 s) and the reset-to-last-fuse fail rule are proposals; the placeholder lines (`need_fuses`, `all_fuses`, `sweep_close`, `found`) are not in the script; the interior is a blockout (no sheets cloth sim, no fans yet); Fony climbs a toppled cabinet (a ramp) rather than a climb animation.

- The heat-alert trigger rule is accepted for now (Nov 19 2026). Still open: the P.1 fail rules, 6C "Clean.", the P.2 title card.
- P.2 Run: the caught -> checkpoint rule and Zero's time rule are proposals; drone speeds are first-pass balance. A few lines are new placeholders, not in the script (listed in `p2_run.json` `line_notes`).
- The breakdown says to retire `test_district` (it sits inside A1). It is kept for now because M0's tests and district-check use it; both are armed only by flag, never together.
- The culvert is a fade for now, not a skateable tunnel.
- The P.1 v2 doc's own open items.
