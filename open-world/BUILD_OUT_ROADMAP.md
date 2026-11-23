# Build-out roadmap: park, buildings, districts

Nov 22 2026. Act I (through the early cut, including 1.1–1.6 blockouts) and the intro placeholder are on main. This note is the order to finish the places the player actually skates through. It does not build them.

The round bowl and the Glitchport bounds landed with this note: the pool has a flat bottom, a 70° quarter-pipe transition, coping and a deck, and the plaza's open north side, the fence-gap seam and the dark arcade's city side no longer drop into the void. Recovery returns to the last grounded spot inside the playable volumes.

## How to read a phase

- **Priority** is what a player hits first on a New Game, then what they hit if they keep going.
- **Size** is how much of the project moves: which scenes, and whether a new district pack is involved. It is not a schedule.
- **Review** is the play-through that should look right before the next phase starts. Headless tests stay green; the review is with a person on the build.

Pack budgets stay where they are: main pack 50 MiB, each district pack at its cap in `data/districts.json` (none over 8 MiB). Phases 1–4 should not add textures. Reuse the quarter-pipe concrete, the cel shader, and Kenney where a mesh is already approved. Phase 7 is the one that has to be measured with `tools/pack-report.mjs` before it merges. No music and no audio files in any phase.

## Done, so later phases can assume it

- The yard bowl is a pool, not four banks. Riding it uses the quarter-pipe curve step. The four straight sides of the coping are grindable ledges; the rounded corners are not.
- World bounds: curbs on the Glass Row plaza and the yard/alley seam, a closed shell around the dark arcade, and a kill plane that restores the last safe position.
- The yard ground and the bowl deck use one tiling concrete texture (world-space, so the big slabs do not stretch). The deck tint is cooler than the yard. That texture is the exception to "phases 1–4 add no textures"; it was measured in the pack.

## Phase 1 — The rest of the skate park

**Size.** Small. `scripts/yard.gd`, the park pieces, and the quarter-pipe scene. No new district.

The bowl is rideable, and the funbox, its kickers, the bank, the down-rail run-up, the manual pad, and the quarter-deck stairs now wear the quarter-pipe face: dark ply, a caution band, steel coping, steel cheeks. Their collision is still the wedge, the box, or the access slope. The mini ramp is still two library quarters facing each other with a flat gap. Lanes are still strips. The practice line (bowl, quarter, rail) depends on the bowl floor staying below y = −2 and on the north lip staying south of the line spawn at z = 20.5.

**Review.** Free skate from the yard spawn: drop the bowl both ways, carve a corner, ride the mini ramp, the quarter, the funbox, the flat bar and the down rail. No snag on a transition, and each obstacle readable from the deck of the one before it. Then one P.1 line, start to the Zero Score.

## Phase 2 — Yard buildings

**Size.** Medium. The yard shells in `scripts/yard.gd` (workshop, resistance rooms, docks, plaza, gate yard). The warehouse exterior and the lit arcade interior stay as they are unless a wall of one of those rooms is what you are standing in.

Workshop, resistance, docks and the gate yard are open boxes with a few props. The in-yard plaza (benches, cart, stair) is the same kind of blockout. From the bowl deck they read as coloured crates, not buildings.

**Review.** Walk the workshop, the resistance rooms (Zero still stands where he does), the docks and the gate yard. From the south gate and from the bowl deck, each building should have a door you can find and a silhouette that is not a single box. Skate the dock ramp and the plaza stair without getting stuck.

## Phase 3 — Glass Row as a street

**Size.** Medium. `districts/glass_row_edge/` only. The approved bounds (x 82–202, z −80–102) stay; the playable street is the alley plus the plaza, which is what the curbs already fence.

P.2 is a chase down that street: fence gap, van, dock or parking ramp, plaza, grate, arcade side door. The buildings are boxes, the shoppers are capsules, the van is a slab. The north side of the plaza used to be open sky. The curb closes it, but the block still does not look like Glitchport.

**Review.** Play MISSION P.2 Run both ways (dock and ramp) through to the side door. You should not be able to leave the street, the two routes should both be obvious from the van, and the plaza should read as a dead end at the city edge rather than a floor that stops. The drain grate still hands off to P.3.

## Phase 4 — Solar Arcade, the fuses room

**Size.** Small. `districts/solar_arcade_dark/` and the P.3 mission script only where a prop moves.

The room is a dark box: sheet cubes, one slope, labels, practical lights. The three fuses and the breaker are findable in the autopilot because it knows the coordinates. A person in the dark is who got lost and walked out.

**Review.** Play P.3 with the lights as they are. Find each fuse without the autopilot, climb to the fixture, throw the breaker, and watch P.4's power-on in the same room. The shell outside the walls should stay invisible from inside. Falling through a cabinet or the west wall should put you back in the room, not in the void toward the yard.

## Phase 5 — Stillwater Flats

**Size.** Large. `districts/stillwater_flats/`. One street slab, four housing blocks, plank bridges, the community center, the ice locker, block people. 1.2 and 1.3 already play as fades onto this slab. There is no street from Glass Row to here.

**Review.** 1.2 from the first bag to the last drop, including a melt and a bail. 1.3 across the four roofs and the bridges, then step off: you should land back on the last painted roof, not in the void north of the street. The billboard should be readable from the roof it stands on.

## Phase 6 — Cold Row and the breaker

**Size.** Large. `districts/cold_row/`, plus the 1.5 script where a teleport stands in for a grind or a launch.

1.4 is a night blockout (asphalt, fences, three towers, a river wall, three marks). 1.5's fence crossing is a grind and the thermostat launch is the loading-bay quarter pipe. The boss phases play. The machine is not a ramp.

**Review.** 1.4: all three marks, once spotted and once not. 1.5: cameras, the fence, the panel, the hold-the-line, then the three boss phases. A fall off the machine or the fence should return to the last checkpoint inside Cold Row. The river stays out of bounds.

## Phase 7 — One Glitchport

**Size.** Large. This is the phase that joins the yards. Today the yard, Glass Row, the Flats and Cold Row are separate slabs and the story fades between them. Do this after phases 3–6, because the joins should meet streets that already have an edge.

Two acceptable shapes, pick one at the review and do not do both:

- Keep the fades, and build the skyline so the place you leave and the place you arrive agree (the towers you saw from the yard are the towers you land under).
- Or replace a fade with a skateable street. That street gets its own bounds volume and a curb until the next district exists. No new hole at the join.

**Review.** From the south gate, from the Glass Row plaza, and from each story arrival, name the next district by what you can see. Skate or fade there and check the ground meets. `AU_TEST_ONLY=bowl` still passes: edges, seam, arcade shell, bowl ride.

## Phase 8 — Surfaces, signs, plants

**Size.** Medium, and the first phase that can move the pack. `ASSET_MANIFEST.md` is still the list: murals, posters, signs that are not Label3D, concrete wear, plants that are not cubes. Kenney meshes are already in the repo for plants and a few city props; the yard does not use them yet. Generated murals need the band's OK one piece at a time. Nothing in this phase is audio.

**Review.** One daylight free-skate lap and one dawn P.1 lap, looking at the ground, the gate sign, the workshop face and the bowl deck. Then `node tools/pack-report.mjs` on the web export: main pack under 50 MiB, district packs under their caps. If a texture blows the budget, it waits.

## Act I completion checklist

The early cut already plays from New Game through 1.6B (`ACT1.md`, `ACT1_NOTES.md`, `data/missions/act1_scenes.json`). This is what is still missing for that cut to be the finished Act I, in story order. It is a review list. Nothing here is started.

1. **Intro.** A missing local file is probed and skipped in 2.5 s instead of waiting out the video load timeout. The ffmpeg stand-in, if it is what plays, is labelled PLACEHOLDER CUT and does not count as having seen the intro. The in-production card is still the last resort when every source fails. The hosted cut is unchanged.
2. **P.1 Practice Run.** The mini ramp has a flat and cheeks between the two low lips (the ride stays on the yard slab). Lanes are paint. The workshop, resistance rooms, docks and lookout have roofs and a readable door. The Glass Row billboard is a panel on poles; the words are the same forecast and Sunburn Open lines. **Open call:** P.1's script says the mission does not fail (`P1_FAIL_RULE = "none"`). A checkpoint fail was proposed for later missions and is not applied here.
3. **Cinematics P.2 The heat alert and P.3 Flagged.** The lines are unchanged. A chime, a billboard change, a shot and the drone's arrival now hold before the next line (`SHOT_READ_S`, `BILLBOARD_READ_S`, `CHIME_READ_S`, `DRONE_ARRIVE_S`). P.4 is not retimed.
4. **P.2 Run, Glass Row.** The alley backs have windows, the van has a cab, and the shoppers are capsules. The two routes are unchanged. **Open calls:** `P2_FAIL_RULE` stays `"checkpoint"` (caught, restart, no lives). `P2_ZERO_TIME_ROUND_S` is 5 and `P2_ZERO_TIME_MIN_S` is 30. `P2_CULVERT_IS_FADE` stays true: the grate has a mouth, then the fade. Drone speeds stay the first pass (`WELFARE_SPEED` 6.6, `ENFORCER_SPEED` 7.2). Placeholder lines (`start` gap, `camera`, `caught`, `zero_time_set`, `zero_time_beaten`) are marked PLACEHOLDER on screen. The words are unchanged.
5. **P.3 Power On, Solar Arcade.** The cabinets wear cloth. The toppled cabinet is still the walk-up, with a shell on that slope. **Open calls:** `P3_SWEEP_S` stays 100 and `P3_SWEEP_FAIL` stays `"last_fuse"`. `need_fuses`, `all_fuses`, `sweep_close`, and `found` stay the placeholder lines and are marked PLACEHOLDER. The script lines are unchanged.
6. **P.4 Zero.** Servo arms shrug the jacket on badly, then correctly, during boot. The body's back is the jacket (leather and a seam). The ZR-0 plate stays on the back of the CRT. **Open call:** `P4_TITLE_SONG` is empty. The title card calls that hook and plays nothing. The band picks the song. No audio file is loaded.
7. **1.1 Fine Print.** Taking the board back sets `upgrade_grip_tape` and the board keeps it. **Open call:** `GRIP_TAPE_FRICTION_MULT` 0.82 (quieter bearings) and `GRIP_TAPE_PUSH_MULT` 1.12. The workshop card is still the script's card. Scavenged upgrades stay unbuilt.
8. **1.1B The plan.** The dust sheet comes off GRIND THE TERMS and `cabinet_grind_the_terms` unlocks it. E on that cabinet opens the existing Punk Arcade page. The game files are untouched. The HQ arcade cabinets stay as they were.
9. **1.2 Water Run, Stillwater.** Five drops, melt, and Signal play on one slab with block people (phase 5). There is no street from Glass Row (the fade stays; that join is still an open call). Nana Ines's community-center line is unchanged. The review walk now looks along the leg, so the camera no longer shortens onto his back at that drop.
10. **1.3 Cool Roofs and 1.3B First night.** Four roofs, bridges, and the billboard tag play. A paint goal still accepts E, and it also accepts the spray button. A small can shows while one is in reach. The procession is narrated. Nana's and Zero's closing lines are placeholders. The night crowd in the arcade is block figures.
11. **1.4 Cold Row and 1.4B The Benefactor.** The three marks and the drone loops play on the night blockout (phase 6). Mark lines are placeholders. The hologram is boxes, not Halo. Zero Vision here is the first-use phone raise only. **Open calls:** the stealth-bonus formula, and a WATCH vision cone. WATCH stays a 5.5 m radius with no angle and no line of sight. Neither rule is invented here.
12. **Zero Vision in free roam.** The meter and the recharge are not built. After 1.4B it does not come back.
13. **1.5 The Breaker, 1.5B The Thermostat, 1.5C Lights on.** Cameras, the reroute, and the three boss phases play. The fence crossing is a grind on FenceRail. The loading bay is a quarter pipe whose lip launch lands on the machine. Frost does not slip. The machine is not a ramp. 1.5C is the same Flats slab with lit windows.
14. **1.6 Heat Break.** Four E prompts stand in for the day montage. Shade cloth, the water station, the cots, and the neighbors are placeholders, not activities.
15. **1.6B The rain.** The storm, the doorway, and the end card play. Nana's THE YARD mural is not a painted wall. Real art is still missing for Nana Ines, the residents, Egon, Halo, and Zero's face on the phone (the thread header only).
16. **One Glitchport.** The yard, Glass Row, the Flats, and Cold Row are separate slabs joined by fades (phase 7). A finished Act I shows the same skyline on both sides of a fade, or replaces a fade with a bounded street. No new hole at the join.
17. **Surfaces, signs, plants.** Phase 8, after the streets exist: signs that are not Label3D, plants that are not cubes, murals one approved piece at a time. Measure the pack before it merges.
18. **Saves.** Reloading an Act I scene restarts that scene. Mid-scene progress does not resume. The local save works; the site account bridge (FR-039) is still pending.

Act II starts after 1.6B and is not part of this list.

## Not in this roadmap

Act II is out of scope here. Workshop handling, free-roam Zero Vision, the real Grind the Terms cabinet, and the title song are items 6, 7, 8, and 12 of the checklist above, not extra phases.
