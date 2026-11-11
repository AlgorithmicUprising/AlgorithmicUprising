# Fony v5-push: QA notes (Nov 11, 2026, ~3:05 PM CST)

v3 and v4-push are untouched; no file in either folder changed after 2:39 PM CST.
Everything new is in v5-push/:
- frames/push_<dir>_NN.png: 510x648 cells, anchor 255,632, never mirrored
- manifest_delta.json
- fony2d_v5_push_atlas.png: scale 0.5, push frames only
- review/
- work/qa_stats.json: per-frame head, baseline and foot numbers
- tools/: build5.py, legrot.py, front5.py, export5.py, review5.py, delta5.py, dirs5.json

## Methods used this pass
- The image generator refused the forward plant 6 more times. It kept putting the foot back behind the tail, even when given a layout guide. So the plant frames are now built by editing the leg from accepted frames:
  - back_right: lower leg rotated about the knee, with the knee pad re-laid on top to hide the joint.
  - left / right: whole push leg rotated about the hip, with the jacket hem and hand re-laid on top. On the left (far side) the leg is drawn behind the board.
  - front: the leg was edited directly on the v3 cruise_front_00 cell.
- Loop smoothing uses a lean/dip warp that is pinned at the ground row, so the board never moves. It does a horizontal shear plus a vertical scale about y=632. The head path gets eased with the v3 frame 0 locked.
- Crispness: each new frame is sharpened or softened until its edge sharpness (90th-percentile gradient) matches that direction's v3 frame 0 (now within about 3%).
- Board width: a horizontal stretch of only the board rows, by the measured gen/v3 board ratio. Back: 1.07-1.11. Right: 1.09-1.10.
- Clean-up: specks under 30 px removed, board baseline aligned to the v3 board, ground shadows removed.

## Per direction (v4 -> v5 frames; ground contact frames)
| dir | frames | contact | notes |
|---|---|---|---|
| back | 8 -> 8 | 2-4 | Dip/lean eased: largest head step is now 8px (v4: 23px at 1->2 and 5->6). Board widened to v3 width. Plant still beside the rear wheels: in an end-on view, moving the foot forward means moving it in depth, and a leg rotation can't do that. |
| back_left | 8 -> 8 | 3-6 | Torso drift cut from 35px to 15px and eased. The loop return is now 10px over 2 frames, not a 33px snap. Plant unchanged from v4 (beside/behind the deck). |
| back_right | 6 -> 8 | 2-5 | Foot swings in, plants on the ground in front of the tail beside the rear wheel, drags behind the tail, toe-off, extends, lifts. White blob removed from frame 0. One board in every frame. |
| left | 7 -> 8 | 2-5 | Plants on the far side of the board between the wheels (shoe shows above the deck and between the wheels below it), then drags, extends, lifts. Frames 1 and 7 ease the 16px height change from the v3 frame. |
| right | 7 -> 8 | 2-6 | New committed pose: deep front-knee bend and forward lean, arms working. Plant beside the rear truck on the near side. The crouch drops the head 39px, eased over frames 1 and 7 (about 20px per step). |
| front | 5 -> 6 | 2-3 | Board is pixel-identical to cruise frame 0 in every frame (no pop). Plant shoe sole at y=605, on the ground line beside the board's rear end. |

## Still weak (honest)
- No direction plants beside the FRONT trucks. Best reached:
  - right: beside the rear truck, slightly forward of it
  - left: just ahead of the rear wheels
  - back_right: beside the rear wheel
  - front: beside the rear end
  - back / back_left: unchanged, by the rear wheels
- The edited-leg frames keep the original shoe and pant drawing, just rotated. Up close the knee can look a touch stiff. On back_right frames 2-3 a faint lace line from the old frame is still visible on the tail.
- Front: only the push leg moves, so there's no body lean or weight shift.
- Right: the crouch is a clear posture change from the upright v3 cruise frame. It's eased, but at 12 fps you'll see him sink into it. Frames 1 and 7 are stretched up to 4.5% vertically to ease the crouch in and out.
- The smoothing warps stretch the body vertically by up to 2.6% (back) and 3.8% (back_left) in the crouch frames. I couldn't spot it at game size.
- back_left frame 5: the shoe lands at y=638, 6px below the board baseline (closer to the camera). Same as v4.
- push_back_right_00 and push_back_left_00 carry the blob/speck fix, so they differ from the untouched v3 cruise frames by those few pixels.
- In-park preview not rendered: Godot isn't on the box and the PR18 branch isn't checked out locally.

## Rejected this pass (work/gen/*_REJ)
- pbr5_mid_a, pbr5_mid_b, pbr5_mid_c, pbr5_plant_clean (foot back behind the tail or on the deck)
- pr5_3d (front foot floating; used only as the source of pr5_lift after a 17px body drop)
- pf5_plant_a (both feet on the board)

## Integration TODO (not done: no push, merge, or deploy)
- Repack the atlas, replacing the six push_* entries.
- PR test frame counts (v3 -> v5): back 8->8, back_left 5->8, back_right 5->8, left 6->8, right 6->8, front 6->6.
