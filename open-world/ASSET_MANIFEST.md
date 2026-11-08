# HQ yard asset manifest

This list is the visual pass on the 160 m yard. Nothing here is a finished illustration, a character design, or a licensed franchise asset. TEMP TAG stripes are placeholder geometry.

## Modeled in engine

| Piece | How it is made |
|---|---|
| Yard shell | 160 m wall square, one south gate, Rust Avenue apron, future-section curb |
| Ground | Warm concrete slabs and a few darker patch boxes. No crack texture |
| Drainage bowl | Floor at y = −3 m and four straight bank slopes |
| Skate yard | 2.2 m quarter, 0.9 m funbox, 2.0 m half-pipe, 12 m grind rail |
| Workshop | Open industrial shell, bench, five green battery blocks |
| Resistance rooms | Private shell, bunks, counter. Zero and Fony capsules inside |
| Solar warehouse arcade | Teal shell, rust band, blue roof cells, door, one real cabinet, four mute cabinet boxes |
| Docks | 1.2 m decks and a ride-up slope |
| Plaza | Benches, cart, awning, stair wedge, seven step boxes, handrail |
| Gate yard | Lookout block, posts, a flat net quad, container stack |
| Outside, not playable | Cool tower blocks, west factory blocks, north rail beam |
| Plants | Five box planters with box shrubs |
| Lighting | Procedural sunset sky, warm key light, cool ambient, three-band cel shader, one shadow map |
| Fony, the player | Articulated box rig: copper hair blocks, rust jacket, black hoodie, olive legs, magenta pads, worn shoes. Collision is still a separate capsule. The board is a child of the rig, under the feet while skating and at the side while walking |
| Zero | Articulated box rig: cream CRT, lime screen bars, knob, vent, leather jacket, red “?” patch, barcode blocks, metal neck, hands, and knees, coiled cable segments. Idle bob and a raised arm while talking |

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

What these rigs are: separate boxes parented to pivots for hips, chest, head, arms, and legs. Poses are code (idle, walk, skate, jump, land for Fony; idle and talk for Zero). They are not skinned meshes, not weighted to a production skeleton, and not animation clips from another program.

Still missing on the characters:

- A face, hair strands, and cloth folds
- Finger poses and a real cable curve
- Zero’s screen as anything beyond three moving bars
- Board graphics
- Hit reactions, grinds as a special body pose, and a get-up animation beyond the short land crouch

## Explicitly not in the repo

No music, no samples, no generated paintings, no paid stock, and no franchise logos. The sunset reference painting was used as direction and is not a game texture.
