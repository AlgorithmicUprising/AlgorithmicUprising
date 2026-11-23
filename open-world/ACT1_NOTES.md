# Act I scenes 1.1 to 1.6B: first-pass notes (Nov 20 2026)

Branch `pz-act1-s1`, local only. Runner `scripts/story/act1.gd`, data `data/missions/act1_scenes.json`, cinematics `a1_plan`, `a1_first_night`, `a1_benefactor` in `data/missions/prologue_cinematics.json`. New district packs `stillwater_flats` and `cold_row`; the arcade pack gains the GRIND THE TERMS cabinet and ceiling fans. Tests `tests/m5_tests.gd` (AU_TEST_ONLY=m5); browser run `tools/act1-scenes-check.mjs` (`AU_ACT1_FROM=1.1`, uses the dev jump `?story=p1&story_demo=1&act1_from=<scene>`). Intro and Prologue cinematic timing untouched.

Every guess below is a first pass, for you to change.

## Flow
- After CINEMATIC P.4's title card, 1.1 starts straight away in the lit arcade (no fade to a menu). Scenes chain: 1.1 (+1.1B) -> 1.2 -> 1.3 (+1.3B) -> 1.4 (+1.4B and Zero Vision) -> the end card ("ACT I · EARLY CUT ... Next: ACT I · 1.5 THE BREAKER (not built yet)").
- Between scenes: a cut (fade from black at the next place). No travel between districts; the Flats and Cold Row are off-map blockouts reached by the fade.
- Save: one mission record per scene (`a1_fine_print`, `a1_water_run`, `a1_cool_roofs`, `a1_cold_row`) and a flag per scene (`a1_*_done`). A reload restarts the first unfinished scene from its top (mid-scene progress is not resumed yet).
- T (retry) does nothing in the Act I scenes; falls and drones reset to the last checkpoint.

## 1.1 Fine Print (+ 1.1B The plan)
- Topic menu: keys 1-4 ask a topic (each once, all optional), E takes the board back. Not a dialogue wheel; the prompt line lists the choices.
- Upgrade one (control-panel grip tape): a flag only (`upgrade_grip_tape`), no handling change yet.
- Workshop: one E at the bench shows a WORKSHOP card (upgrade one installed; "more upgrades need parts scavenged in the world, not built yet"). Flag `workshop_unlocked`.
- 1.1B: the dust sheet comes off GRIND THE TERMS (a cabinet blockout by the south wall); flag `cabinet_grind_the_terms` is the unlock. The real cabinet game is not wired to it yet.

## 1.2 Water Run
- 40 bags in 5 loads of 8 (one load per drop point: Mr. Delacroix, Mrs. Okonkwo, the kid on the stairs, the rooftop gardener, the community center). Money for 48 bags (one spare load).
- Melt timer 75 s per load; Zero's "rude" line at 30% left. A melted load is lost. A bail drops one bag (Zero's "confusing and correct" line, first time).
- Out of money with drops left: refill to what is left and back to the last delivery (the breakdown's proposal).
- Score: 250 per bag + 10 per second of melt left; Zero Score 12,000 (shown, saved as zero_score).
- Signal: +1 per bag delivered (story.signal); the SIGNAL tutorial card after the first delivery.
- Placeholder line: Nana Ines at the community center drop ("Inside. Necks and wrists first..."), not in the script.

## 1.3 Cool Roofs (+ 1.3B First night)
- Four tar roofs in a row at y 6 with plank bridges; E coats a roof white; each building's readout drops 104°F -> 97°F (guess: -7°F). 3,750 per roof (Zero Score 15,000), the optional billboard tag +2,000.
- Falling off a roof (below y 3): back on the last white roof (breakdown proposal). Spray is E at a spot, not a held spray can.
- Billboard: Zero's anatomy-of-a-lie line when you get near; tag = E at the billboard (the camera disappears, the text becomes "AU / ZERO X HUMANS").
- Placeholder lines after the last roof: Nana Ines "Four roofs..." and Zero "Top floors are down seven degrees...".
- 1.3B: the procession is narrated (no walking crowd); in the arcade 24 block figures on blankets, three kids at Bailey's cabinet, Nana Ines, Mr. Delacroix, the little girl; Zero moved by the entrance.

## 1.4 Cold Row (+ 1.4B The Benefactor, Zero Vision)
- Three marks (lawn, substation, water intake), any order; the workers' smoke break plays when you walk near them (optional).
- Drones: three fixed loops; WATCH fills when within 5.5 m (no cone, no line of sight), full in 2.5 s, drains at 0.35/s. The mist boxes under the towers hide you. Full WATCH = SPOTTED, back to the last mark (or the start).
- 5,000 per mark (Zero Score 18,000 shown).
- OPEN owner call: the mist/stealth bonus has no formula, and WATCH has no vision cone. Both stay unbuilt until those rules are written. Do not invent an angle or a bonus.
- Placeholder lines: Zero at the substation ("Maintenance line. It runs toward the Flats."), at the intake ("Sustaining is doing a lot of work..."), after all three ("Get under a tower..."), and when spotted.
- 1.4B: the hologram is a placeholder (translucent boxes, red eyes, lime fingertips, a white Halo sphere with a ring) over the river; the studio stage is narrated; screens switch to FEEDLINE LIVE.
- Zero Vision: E raises the phone; a dark green screen tint plus 600 lime lines from the fingertips into the City (random endpoints), then the unlock card. It's the first use only; Zero Vision in free roam (the meter, recharging) isn't built.

## Fahrenheit swaps (script -> game)
- 1.4: "a comfortable twenty-something degrees" -> "seventy-something degrees"; "the Flats are at forty" -> "a hundred and four".

## P.4 placeholders
- Ceiling fans added to the arcade (they turn once the power is on). Arm rig, jacket-on and title music still not built.

## 1.5 The Breaker (+ 1.5B The Thermostat, BOSS The Thermostat, 1.5C Lights on in the Flats)
- Six cameras on poles around the substation; E sprays a lens black (1,500 each). Two drones patrol (WATCH as in 1.4, range 4.5 m).
- Open the gate: grind the ollie-height fence rail (FenceRail) from the south end of the substation fence to the switch house. The goal completes when that grind delivers him. No teleport.
- Zero's part: E at the switch-house panel; the panel reads ZERO; script lines.
- Hold the line: 30 s reroute. Drones fly in from the edges every 3.5 s (max 4) toward the switch house; touching one knocks it down (+500); one that flies into tower mist drops; one that reaches the house costs 5%. Zero's barks at 30/60/90% (60% is the script's, the others placeholder).
- Boss, three phases as goal steps:
  - Phase 1: stomp three vents (E at each, 2,000). Frost patches slip. The multiplier is `data/surfaces.json` (`frost`). **Open call:** how slippery. The default 0.18 is a stand-in.
  - Phase 2: the dial reads HEAT; steam blows 2 s on / 2.5 s off within 6 m of the machine; inside it while it blows fills WATCH (full in 4 s) unless you're in the tower mist. Spray two sensor eyes (2,000 each).
  - Phase 3: the dial reads HOT · COLD · HOT. He rides the loading-bay quarter pipe. Its lip launch carries him onto the machine's top (`launch_forward` and `launch_up` on that pipe only; park pipes still drift back into the transition). E stomps the dial (3,000). The machine itself is still not a ramp.
- Zero Score 22,000 (the script's); a full run scores about 25,000.
- Egon's four boss barks are spread over the vents and eyes; Zero's three over the reroute and phases.
- 1.5C: the machine stops, the Capsule flies off, Zero on the panel; then the Flats at night: lit windows, people on the roofs, the billboard shows Zero's message.

## 1.6 Heat Break (+ 1.6B The rain) — END OF ACT I
- The four days are skated. Paint takes the spray button in front of the community center (the existing spot; he is not put on the roof). Aid, salvage, and the cabinet complete when he skates onto them. Signal +5 each. The lines stay PLACEHOLDER. **Open call:** digging the cabinet out as a played restore, and a real path onto the roof. Neither is in this scene.
- The Yard, days later: shade cloth over the bowl, a water station by the gate, cots in the resistance rooms, kids on the quarter pipe; meet the neighbors, two teen skaters and the free-clinic woman (placeholder lines).
- 1.6B: storm sky, falling rain streaks, the Yard in the rain, Zero in the arcade doorway (a block figure). Nana paints THE YARD on the arcade wall just west of the bay door: a yard-lime panel and block letters. PLACEHOLDER, not a finished mural. Script dialogue. Then the card "END OF ACT I. / RUST & SIGNAL", then the end card: "Next: ACT II · 2.1 BACK TO PRACTICE (not built yet)." **Open call:** the real lettering. Real art is still missing for Nana Ines, the residents, Egon, Halo, and Zero's face on the phone.

## Fixes this round
- Zero Vision strings now render on the web build: thin unshaded boxes in one MultiMesh (ImmediateMesh GL lines drew nothing on the Compatibility renderer), no depth test, no fog; raising the phone tilts the camera up at the hologram. The camera pitch resets on every scene spawn.
- The skate-combo SCORE box is hidden during the Act I scenes (they score in the box above).

## Not built / next
- Act II onward (2.1 Back to Practice is next).
- Real art for Nana Ines, residents, Egon, the Halo; Zero's face on the phone (the thread header only).
- Workshop upgrades and parts; the Grind the Terms cabinet unlock in the arcade; Zero Vision in free roam.

## Known rough spots (seen in the browser runs)
- The lower SCORE box (the skate combo) reads 0 through the Act I scenes; the scene score is in the box above it (e.g. ROOFS 3/4 · SCORE 11,250).
- At the community center drop in 1.2 the review walk used to leave the camera pointed at the wall, so it shortened onto Fony's back. The walk now looks along the leg.
- The 1.1 camera starts very close to the dust-sheeted cabinet on the dev jump.
- Name labels over the block people were halved in size after they filled the 1.3B close-ups.

## Review runs
`AU_ACT1_FROM=1.2 AU_ACT1_OUT=... node tools/act1-scenes-check.mjs` after `tools/export-web.mjs` + `tools/stage-composite.mjs`. Note: the full test suite's media guard scans `build/`, so run the suite before exporting (as CI does) or on a copy without `build/`.
