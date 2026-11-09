# Fony

Low-poly skinned human for the HQ player. Intermediate model: shaped head, painted face, copper hair, jacket, hoodie, cargo legs, pads, shoes, and simple hands on one skeleton. Elbows and knees deform. It is not the approved illustration and not a finished character. Zero is unchanged. The game builds the mesh in `scripts/fony_mesh.gd`. It does not load `fony.glb`.

## What is authored here

- A skinned mesh in `scripts/fony_mesh.gd`: head, face card, hair, jacket, hoodie, cargo legs, pads, shoes, and simple hands. Joint vertices blend between two bones.
- `face_albedo.png`, an original face card from `tools/make_fony_face.py`
- Pose clips in `scripts/fony_rig.gd` for crouch, ollie, flip, grab, land, and bail. Gameplay applies those poses directly so a bad animation path cannot freeze the body. `preview_clip` checks that the crouch clip itself lowers the hips.
- Skate, walk, and idle feet stay procedural so the shoes meet the deck
- The board stays under the feet except during a kickflip, a grab, or a failed landing

No third-party animation library is used. A permissive mocap or skate library could later replace the short trick clips. It is not required for this slice.

## Provenance

Original geometry and the face card, MIT with the rest of `open-world/`. The approved character drawing is direction only and is not stored as a texture.

## Not done

Cloth, a sculpted face, and realistic skate motion. The hands are simple. The legs are still tubular. Knee bends are linear skinning, so a very deep fold can look stiff. The poses are authored timing, not motion capture.
