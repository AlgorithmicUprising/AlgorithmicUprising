# HQ yard asset manifest

This list is the visual pass on the 160 m yard. Nothing here is a finished illustration, a character design, or a licensed franchise asset. TEMP TAG stripes are placeholder geometry.

## Modeled in engine

| Piece | How it is made |
|---|---|
| Yard shell | 160 m wall square, one south gate, Rust Avenue apron, future-section curb |
| Ground | Warm concrete slabs and a few darker patch boxes. No crack texture |
| Drainage bowl | Floor at y = −3 m and four straight bank slopes |
| Skate yard | The west quarter is `assets/library/quarter_pipe/quarter_pipe.tscn`: a 2.4 m textured concrete shell, deck, metal coping, and two graffiti panels. Half-pipes, funbox, lanes, and the 12 m rail are still the simpler ramps |
| Workshop | Open industrial shell, bench, five green battery blocks, eight container ribs on the south face |
| Resistance rooms | Private shell, bunks, counter. Zero stands here |
| Solar warehouse arcade | **Arcade Phase 1 exterior (local branch `arcade-exterior-p1`)**: `scripts/arcade_exterior.gd` on a 1 m grid with 4 m bays. Ribbed teal sheet (procedural ribs with a distance fade), rust belly band, lit clerestory glazing, steel pilasters, coping/parapet, gutter and downpipes, a flat roof with a 4 × 7 slab solar array, tank, vent and AC units, our own staff door and lit windows, an entry deck with stairs, rails and skate wedges, three planters with Kenney bushes, weeds, and a Kenney container. One toon shader (`shaders/toon_world.gdshader`), one 512² trim sheet and one 2048×1024 art atlas (`assets/arcade/`) serve outside and inside. The greybox shell keeps its collision; its meshes are hidden. The old greybox interior (floor, decoys, posters) is removed; the room is the separate interior scene below |
| Arcade front shutter | `scripts/arcade_door.gd`: closed roll-up shutter (solid). Interact (E / pad X) rolls it up, fades to black and moves the player into `scenes/arcade_interior.tscn`, the separate interior scene; its exit fades back out and the shutter rolls down. Never opens on approach. A dark entry bay with a far glow sits behind the shutter so the roll-up never shows the empty shell |
| Arcade interior | `scripts/arcade_interior.gd` (Phase 2, local): same toon shader and trim sheet. Checker runway to the featured ZERO GAME THING PRO 2K (custom side art, attract loop done in `shaders/arcade_screen.gdshader`, no video), two rows of six cabinets each side of the runway, an east-wall line of six, a token counter with prize shelves, and the Bars per Watt corner (power-rack wall, BPW sign, bar and stools, lounge). Soft warm lamps. Playable cabinets (Grind the Terms, Tag Before Training, Cookie Wall, Bars per Watt preview, and the featured cabinet opening the Punk Arcade lab page) open the existing game pages on the same Pages origin in an HTML overlay with a "Back to the Arcade" button (`scripts/arcade_overlay.gd`, `scripts/arcade_cabinet.gd`); game code untouched. The HQ placeholder cabinet (`cabinet.tscn`, same hooks) stands by the counter |
| Docks | 1.2 m decks and a ride-up slope |
| Plaza | Benches, cart, awning, stair wedge, seven step boxes, handrail |
| Gate yard | Lookout block, posts, a flat net quad, container stack |
| Outside, not playable | Cool tower blocks, west factory blocks, north rail beam |
| Plants | Five box planters with box shrubs |
| Lighting | Procedural sunset sky, warmer key, cooler ambient, three-band shader with a sharper edge darkening, one shadow map. Still not inked illustration |
| Park marks | Flat original panel on the workshop face and two crack lines. No collision. Not the reference painting. (The arcade front mark, marquee bar, eave lamps, billboard ARCADE label and TEMP TAG moved into the Phase 1 exterior; the old poster quads and cabinet face bar went with the greybox interior) |
| Fony, the player | Painted sprite billboard. Idle, walk, cruise, tricks, grinds, and bails use the v3 clips (LOCAL puppet-v1 test build: the puppet bake overrides most of them; grind round, Nov 16 2026: the 50-50 grind is a puppet clip in all 8 views, `fony2d_puppet_v1_grind_atlas.png`). The six push cycles are the v5 strokes. The pivot mesh can be shown from the pause menu. Collision is still a separate capsule |
| Zero | Articulated pivots, not a skin rig. Larger cream CRT, lime screen bars, knob, vent, capsule jacket and limbs, red “?” patch, barcode blocks, metal neck, hands, and knees, coiled cable segments. Idle bob and a raised arm while talking |

## Still needed before this can look like the concept

Original art, made for Algorithmic Uprising, not copied from Grand Theft Auto, Jet Set Radio, or any other game:

- Graffiti murals for the warehouse front, the plaza wall, and the container faces. The stripes labeled TEMP TAG are only there so the walls are not blank.
- Posters and handbills for the arcade interior and the workshop. None are drawn.
- Cabinet faces: marquees, screens, and side art for the real cabinet and the mute cabinets. The screen is a flat teal rectangle.
- Signage that is not default 3D text: gate, arcade, workshop, resistance, Rust Avenue. Current words are Label3D.
- Solar panels as a designed surface, not a grid of boxes.
- Concrete: cracks, patches, paint wear, and lane markings as textures or decals.
- Plants that are not cubes.
- Container markings and the drone-net pattern.
- A smooth bowl surface if the plate banks are not the desired shape.

## Characters

Fony is the playable teen. Zero is the NPC in the resistance rooms. The approved drawing was used as direction and is not stored as a texture.

What these rigs are: capsules, spheres, and cylinders parented to pivots. Fony’s legs are a two-bone solve so the shoes meet the ground or the deck. Poses are code (idle, walk, skate, jump, land for Fony; idle and talk for Zero). They are not skinned meshes and not animation clips from another program. The face and hair are still primitive geometry.

Still missing on the characters:

- Hair strands, ears, cloth folds, and a jacket that is not a single capsule
- Finger poses and a real cable curve
- Zero’s screen as anything beyond three moving bars
- Board graphics
- Hit reactions, grinds as a special body pose, and a get-up animation beyond the short land crouch

## Explicitly not in the repo

No music, no samples, no generated audio, no paid stock, and no franchise logos. The sunset reference painting was used as direction and is not a game texture.

**Generated art is allowed for murals and posters, with the band's approval.** The earlier "no generated paintings" line described the first greybox prototype only; it was never a GitHub or legal rule. AI-generated mural and poster art may go in the game once the band approves each piece (approved Sun Nov 15, 2026 for the Arcade). The rule on sound does not change: no music or audio is generated, and no AI processing of music. Current generated and AU art, all Algorithmic Uprising, all rights reserved (see `NOTICE.md`):

| Piece | Where in game | Source |
|---|---|---|
| Mural "Insert Human to Continue" | exterior back wall, interior back wall | AI-generated with Grok Bot image generation from our prompt, Nov 15, 2026; original `art-src/arcade/murals/mural_A_insert_human_raw.jpg` |
| Mural "Press Start to Resist / Game Over" | exterior front east of the shutter, interior west wall | AI-generated, same tool and date; `art-src/arcade/murals/mural_B_press_start_raw.jpg` |
| Mural "High Score: Zero Privacy" | exterior west wall, interior front wall | AI-generated, same tool and date; `art-src/arcade/murals/mural_C_high_score_raw.jpg` |
| Wheatpaste covers, AU / PUNK ARCADE marquee, Zero glyph | exterior and interior posters | Algorithmic Uprising release art and logos (`art-src/arcade/covers/`) |
| Cabinet screens and marquees, ZERO GAME THING PRO 2K side art, Bars per Watt sign, token-counter sign, power-rack cells, rug | interior (`assets/arcade/arcade_screens.png`) | Built by `tools/make_arcade_textures.py` from the Punk Arcade cover art on algorithmicuprising.com (`/assets/zero-tv/arcade-covers/`), the Zero screen face from the site art, and text set in URW Nimbus Sans Narrow Bold (rasterized; no font file in the pck); sources in `art-src/arcade/screens/` |

All three atlases are rebuilt by `tools/make_arcade_textures.py`. Third-party pieces are CC0 only (Kenney, Poly Haven); see `assets/thirdparty/kenney/README.md`.
