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
| Solar warehouse arcade | **Arcade Phase 1 exterior (local branch `arcade-exterior-p1`)**: `scripts/arcade_exterior.gd` on a 1 m grid with 4 m bays. Ribbed teal sheet (procedural ribs with a distance fade), rust belly band, lit clerestory glazing, steel pilasters, coping/parapet, gutter and downpipes, a flat roof with a 4 × 7 slab solar array, tank, vent and AC units, our own staff door and lit windows, an entry deck with stairs, rails and skate wedges, three planters with Kenney bushes, weeds, and a Kenney container. One toon shader (`shaders/toon_world.gdshader`), one 512² trim sheet and one 2048×1024 art atlas (`assets/arcade/`) serve outside and inside. The greybox shell keeps its collision; its meshes are hidden. Inside the old shell: one real cabinet, four mute cabinet boxes (unchanged) |
| Arcade front shutter | `scripts/arcade_door.gd`: closed roll-up shutter (solid). Interact (E / pad X) rolls it up, fades to black and moves the player into `scenes/arcade_interior.tscn`, a separate placeholder interior shell; its exit fades back out and the shutter rolls down. Never opens on approach |
| Docks | 1.2 m decks and a ride-up slope |
| Plaza | Benches, cart, awning, stair wedge, seven step boxes, handrail |
| Gate yard | Lookout block, posts, a flat net quad, container stack |
| Outside, not playable | Cool tower blocks, west factory blocks, north rail beam |
| Plants | Five box planters with box shrubs |
| Lighting | Procedural sunset sky, warmer key, cooler ambient, three-band shader with a sharper edge darkening, one shadow map. Still not inked illustration |
| Park marks | Flat original panel on the workshop face, two poster quads, a cabinet face bar, and two crack lines. No collision. Not the reference painting. (The arcade front mark, marquee bar, eave lamps, billboard ARCADE label and TEMP TAG moved into the Phase 1 exterior) |
| Fony, the player | Painted sprite billboard. Idle, walk, cruise, tricks, grinds, and bails use the v3 clips. The six push cycles are the v5 strokes. The pivot mesh can be shown from the pause menu. Collision is still a separate capsule |
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

No music, no samples, no paid stock, and no franchise logos. The sunset reference painting was used as direction and is not a game texture.

**Exception pending review (Arcade Phase 1, local only):** `assets/arcade/arcade_art.png` packs three AI-generated mural *candidates* (sources in `art-src/arcade/murals/`) plus Algorithmic Uprising covers and the AU / PUNK ARCADE marquee. These are for the band's review and are not final. If the murals are rejected or replaced with hand-made art, rebuild the atlas with `tools/make_arcade_textures.py`. Third-party pieces are CC0 only (Kenney, Poly Haven); see `assets/thirdparty/kenney/README.md`.
