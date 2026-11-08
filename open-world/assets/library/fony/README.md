# Fony

Intermediate stylized human for the HQ player. Not a finished illustration and not a capsule stand-in. Zero is a different asset and is not changed here.

## What is authored here

- Tapered meshes for the jacket, hoodie, cargo pants, pads, shoes, and hair, parented to pivots for hips, chest, head, arms, and legs
- `face_albedo.png`, an original face card (brows, eyes, mouth) from `tools/make_fony_face.py`
- `Clips` on the rig: crouch, ollie, flip, grab, land, bail. Those keys are written in `scripts/fony_rig.gd` and played by the trick state
- Skate, walk, and idle feet stay procedural so the shoes meet the deck or the ground
- The board stays under the feet except during a kickflip, a grab, or a failed landing

No third-party animation library is used. A permissive mocap or skate library could later replace the short trick clips. It is not required for this slice.

## Provenance

Original geometry and the face card, MIT with the rest of `open-world/`. The approved character drawing is direction only and is not stored as a texture.

## Not done

Skin-weighted deformation, cloth, fingers, and a polished face. The motion is a short authored pose plus procedural board contact, not a realistic skate animation.
