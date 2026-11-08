# Fony

Low-poly skinned human for the HQ player. The game loads `fony.glb`, written by `tools/make_fony_glb.py`. About 4,400 triangles, flat colors, no texture atlas. The same file is the in-game mesh.

It is still an intermediate model. The face, ears, hair, open jacket, hoodie, patches, cargo legs, pads, and hands are modeled geometry. The arms and legs are still simple skinned tubes, the hair is a short cap with a few locks, and the hands are a palm plus sticks for fingers. It is not the approved illustration. Zero is unchanged.

## What is authored here

- `fony.glb`: head with a sculpted jaw, nose, and eye sockets, separate eyes, brows, lips, and ears, a copper hair cap and locks, an open rust jacket with lapels and patches over a black hoodie, olive cargo legs, magenta pads, and simple hands. Skin weights are in the file.
- Pose clips in `scripts/fony_rig.gd` for crouch, ollie, flip, grab, land, and bail. Gameplay applies those poses directly so a bad animation path cannot freeze the body. `preview_clip` checks that the crouch clip itself lowers the hips.
- Skate, walk, and idle feet stay procedural so the shoes meet the deck
- The board stays under the feet except during a kickflip, a grab, or a failed landing

No third-party animation library is used. A permissive mocap or skate library could later replace the short trick clips. It is not required for this slice.

## Provenance

Original geometry in `tools/make_fony_glb.py`, MIT with the rest of `open-world/`. The approved character drawing is direction only and is not stored as a texture. No third-party mesh.

## Not done

A finished portrait. The face is a low-poly sculpt with eyes, brows, a nose ridge, lips, and ears, not the illustrated teen. Hair is a short cap and a few locks, not a full tousled cut. Arms and legs are still tubes. Hands are a palm and finger sticks. Deep knee bends stay stiff because the skinning is linear.
