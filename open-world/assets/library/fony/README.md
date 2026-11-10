# Fony

Playable human for the HQ player. The body is the CC0 Quaternius superhero male from the free Standard pack, rebound onto the existing 17-bone skate skeleton, with a painted costume and a Compatibility toon shader. It is not a finished illustration. Zero is unchanged.

The game loads `human/fony_human.gltf`. It does not load `fony.glb`.

## What is in the rig

- `scripts/fony_mesh.gd` instances the baked human and assigns toon materials plus inverted-hull outlines on the closed meshes.
- `scripts/fony_rig.gd` still poses that skeleton in code: idle, walk, skate, crouch, ollie, kickflip, grab, land, and bail. The board stays under the feet except during a kickflip, a grab, or a failed landing.
- `tools/bake_fony_human.py` rebuilds the glTF from `quaternius/`.

## Quaternius subset

`quaternius/` is an excerpt of the Universal Base Characters **free Standard** pack only (CC0 1.0). `License_Standard.txt` is in that folder. The paid Source pack was not used. Normals and roughness maps were not in the excerpt; the glTF materials point at the albedo files that were.

Used in the bake:

- `body/Superhero_Male_FullBody` for the body, eyes, and brows. The free pack has no separate teen mesh. The male is muscular, so torso and arm girth are scaled down around the trick-skeleton joints. Limb lengths are fit to the existing thigh (0.42) and shin (0.42) so the shoes still meet the deck.
- `hair/Hair_Long` (albedo `T_Hair_2`), recolored copper and folded upward into messy spikes. The pack has no spiky or mohawk mesh. The long groom is tied to a different body size than the superhero male, so it is anchored to Fony's head and then reshaped. The spikes are deformed hair volume, not a sculpted groom, and the bangs only partly cover the forehead.
- `textures/T_Eye_Brown.png`, with the red surround pushed toward sclera so the eyeball reads as an eye.
- The superhero albedo is sampled for the face and then posterized. Hands, hoodie, olive cargos, and shoes are painted in UV space from bone weights. The face is that pack's stylized head, not a new teen sculpt.

Costume pieces that are not the base mesh: an inflated torso-and-sleeve shell for the rust jacket, a short hood cowl, circular knee pads (the character's left pad is duller), a magenta chest patch, tan tape, grey shoulder patches, cargo pockets, and shoe shells with dark stripes. The skateboard is the one the rig already carries.

## Why not RetargetModifier3D

The trick rig writes absolute poses on a 17-bone skeleton whose rests are identity rotations and whose leg lengths are fixed (the board and the ankle markers use those lengths). The Quaternius skeleton is a T-pose with its own bone rolls. Driving that skeleton from the trick poses would keep the adult limb lengths and the T-pose shoulder, so the feet would miss the deck. The mesh is rebound onto the trick skeleton instead. `RetargetModifier3D` would fit a clip library later; it does not fit this pose code.

## Not done

Cloth, a sculpted teen face, and a real spike groom. The jacket is an open shell, so it is not outlined (an inverted hull on the cut edges grows fins). Knee bends are linear skinning. The poses are authored timing, not motion capture.
