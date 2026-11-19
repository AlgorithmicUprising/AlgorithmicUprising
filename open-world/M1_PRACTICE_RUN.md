# M1 — Practice Run (P.1)

Branch `pz-m1-practice-run`, built on main `88cb49a` (M0). Local and preview only.

## What plays

Press **P** in free roam, or open with `?story=p1` (web) or `-- story=p1` (desktop).

1. A flyer card for the Sunburn Open. "Five days."
2. Contextual objectives, each with a prompt that appears after the player hesitates: push up to speed → stop and kick the board up → drop it and step on → ollie → ride the quarter pipe → land a 50-50 on the rail.
3. The first bail on the rail wakes Zero's VOICE in the arcade window. It shows as on-screen text with a CRT face and a procedural "fony" blip, and it reads the real bail angle. After that, free-skate and bail barks run from pools that use cooldowns and avoid repeats.
4. The line runs bowl → quarter → rail, inside 60 s with no bail. The first clean line sets the **Zero Score** on the arcade marquee and on the HUD board. The optional objective is to beat it. When P.1 is done, the mission is saved and you go back to free skate.
5. **T** retries from the current checkpoint.

The park is dressed derelict: leaves and bags in the bowl, weeds, cracks, rust on the rail, chained doors, a padlock, a dusty marquee, a CRT in the window, and the Glass Row billboard. The lighting uses a dawn preset during the story, and free roam's lighting comes back when you stop.

## Framework (reusable for P.2+)

- `scripts/mission/mission_runner.gd` is a pure RefCounted runner driven by JSON (`au.mission_def` v1).
  - Required objectives run in order. Optional objectives can be gated with `after_done`.
  - `match` uses subset/minimum matching. Objectives also support `count` and `hesitate_s` (which drives `prompt_due()`).
  - Checkpoints are set when an objective starts. Retry, completion and lock state (`requires` flags) are handled.
  - Save hooks: `to_save`/`from_save` and the `save_requested` signal.
- `scripts/mission/combo_meter.gd`: the combo speed system.
- `scripts/mission/line_tracker.gd`: timed ordered lines.
- `scripts/mission/barks.gd`: voice line pools.
- `contracts/save_record.gd` is now **v2**. It reads v1 and migrates it. It adds a `story` section (missions, flags, day, time of day, signal). The story section is merged on load, so a free-roam save never wipes it.

## Combo speed system

- Banked points fill the meter (`FILL_PER_POINT` 1/3200). Grinds also fill it at 0.12/s.
- After a 2.5 s grace period with no landed tricks, the meter decays at 0.2/s. A bail empties it.
- A full meter gives +35% top speed (9 → 12.15 m/s) and +60% push power. The multiplier is 1 + chain, capped at ×8.
- The combo meter only runs in story mode (see the open questions).

## Provisional (flagged)

- **Fail/retry**: P.1 never fails ("none"). The plan's proposed checkpoint fail rule for P.2+ is built and tested, but marked `fail_rule_status: "proposed"`.
- **Zero Score rule**: the next 500 strictly above the first clean line's score. The autopilot run sets 3,500. A typical hand-played run sets about 4,000, which matches the script.
- **Point values** were scaled ×4 so a plain line scores about 3,200: OLLIE 400, KICKFLIP 1000, MELON 800, DROP IN 600, BS KICKTURN 600, BACKSIDE AIR 1600, TRANSITION 400, grind 400 + 160/m.
- **Line rule**: 60 s, no bail.
- **Keys**: P and T, keyboard only. See `CONTROLS.md`.
- **Dawn lighting values**: sun 1.15, ambient 0.3.
- **Autopilot** (`story_demo=1`) is a review and test aid only.
- **SFX** are generated procedurally in code (`scripts/story/sfx.gd`). There are no audio files, no voice audio and no music.

## Notes

- The bowl's north bank tops out 0.45 m above the yard slab, so dropping in from the yard needs a jump (Space), not an ollie. For that reason the line spawn sits on the slope.
- The marquee and the CRT are about 100 m from the skate yard, so they're seen on approach, not from the line.
- The 5-0 and boardslide are locked during P.1 so that the rail objective teaches the 50-50.

## Checks

- Headless: `AU_TEST_ONLY=m1` (framework, combo, line, barks, save v2, bindings, in-park run, autopilot). The full suite also runs `tests/m1_tests.gd`.
- Browser: `PORT=8097 AU_STORY_OUT=<dir> node tools/story-check.mjs`. Part A uses real keys. Part B records an autopilot video.
- Run the headless suite **before** `stage-composite`. The staged composite under `build/pages-composite` contains the arcade's music, and the M0 media guard scans it.
