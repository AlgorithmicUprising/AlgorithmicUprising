# Build-out roadmap: park, buildings, districts

Nov 22 2026. Act I (through the early cut, including 1.1–1.6 blockouts) and the intro placeholder are on main. This note is the order to finish the places the player actually skates through. It does not build them.

The round bowl and the Glitchport bounds landed with this note: the pool has a flat bottom, a 70° quarter-pipe transition, coping and a deck, and the plaza's open north side, the fence-gap seam and the dark arcade's city side no longer drop into the void. Recovery returns to the last grounded spot inside the playable volumes.

## How to read a phase

- **Priority** is what a player hits first on a New Game, then what they hit if they keep going.
- **Size** is how much of the project moves: which scenes, and whether a new district pack is involved. It is not a schedule.
- **Review** is the play-through that should look right before the next phase starts. Headless tests stay green; the review is with a person on the build.

Pack budgets stay where they are: main pack 50 MiB, each district pack at its cap in `data/districts.json` (none over 8 MiB). Phases 1–4 should not add textures. Reuse the quarter-pipe concrete, the cel shader, and Kenney where a mesh is already approved. Phase 7 is the one that has to be measured with `tools/pack-report.mjs` before it merges. No music and no audio files in any phase.

## Done, so later phases can assume it

- The yard bowl is a pool, not four banks. Riding it uses the quarter-pipe curve step.
- World bounds: curbs on the Glass Row plaza and the yard/alley seam, a closed shell around the dark arcade, and a kill plane that restores the last safe position.

## Phase 1 — The rest of the skate park

**Size.** Small. `scripts/yard.gd`, the park pieces, and the quarter-pipe scene. No new district.

The bowl is rideable. Around it, the funbox and its kickers, the bank, the down-rail run-up and the manual pad are still wedges and boxes. The mini ramp is two library quarters facing each other with a flat gap. Lanes are strips. The practice line (bowl, quarter, rail) depends on the bowl floor staying below y = −2 and on the north lip staying south of the line spawn at z = 20.5.

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

1.4 is a night blockout (asphalt, fences, three towers, a river wall, three marks). 1.5's fence crossing and the thermostat launch are still teleports, called out as placeholders in `ACT1_NOTES.md`. The boss phases play, but the machine is not a ramp.

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

## Not in this roadmap

Act II, workshop upgrades that change handling, Zero Vision in free roam, the real Grind the Terms cabinet, and any music. Those are tracked in `ACT1.md` and `ACT1_NOTES.md`.
