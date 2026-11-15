# Fony 2D v2: animation review and QA (2026-11-10)

All new work is in this folder. v1 files in the parent folder are untouched.
Generated with the built-in image generator (no paid assets). The max output was 1280x720, so frames came from 6-frame (or 4- and 2-frame) strips. Body height is about 330-540 px in the source. Frames are normalized to a standing height of 480 px in 510x588 master cells.

## Screenshot audit (01M746EYGSB68A2JY1SYPWB2G7.png)
Your read is **confirmed, with one correction**. Fony rides away from the camera in one static frame. That frame is `skate_back_left`/`skate_back` (arms out, both feet on the deck), and the deck crosses the screen instead of pointing into it. The cause is in code as well as art:
- `fony_sprite_anim.gd` only animates pushing for `dir == "left"` (`push_cycle_left_1..3`). Every other view, including back, shows one static `push_<dir>` frame.
- `update_push` stops pushing once speed is at or above 8.4 (SKATE_SPEED is 9). At cruise he therefore shows `skate_<dir>`, a single still frame, so a push cycle never plays for long even in the side view.
- In v1 `skate_back` the board is drawn sideways (QA.md: "side stance seen from behind"), so riding away shows the deck across the screen. `skate_back_left/right` angle it about 45 degrees.
- Correction: it isn't only the push cycle. Kick-up, drop-in, crouch, ollie, kickflip, grab, land, and bail are **front-only**. While riding away, any trick flips him around to face the camera for its duration.
- Other gaps found in code: walking has no cycle (`idle_<dir>` is shown while moving on foot), grinding has no art (it shows `skate_<dir>`), bail reuses `trick_land_front`, and descending air without a trick falls back to `skate_<dir>`.
- v1 art defects (still true): front_left is a near-duplicate of front, front_right reads as right, kickup_1 has odd foot placement, push_cycle_left_1 is close to push_left, and idle_back_right is close to back.

## Per-state review
| State (code) | v1 frames used now | Problem | v2 frames | Status |
|---|---|---|---|---|
| idle (on foot, still) | idle_<8 dirs>, 1 frame each | static but fine for standing | none new (keep v1) | v1 kept |
| walk (on foot, moving) | idle_<dir> | no walk cycle, he slides | walk_back 6, walk_front 6, walk_left 6, walk_right 6 | back pass; front/left/right weak |
| cruise (skating, not pushing) | skate_<dir>, 1 frame | static; back board sideways | cruise_back 5, cruise_back_left 5, cruise_back_right 4 | pass (sides/front keep v1 skate_*) |
| push | push_<dir> 1 frame; left 3 frames | no cycle except left | push_back 6, push_back_left 5, push_back_right 5, push_left 6, push_right 6, push_front 6 | back weak; others pass/weak |
| kickup | kickup_1..3 front only | front-only, weak kickup_1 | kickup_back 6, kickup_front 6, kickup_left 4 | pass, pass, weak |
| dropin | dropin_1..3 front only | front-only | dropin_back 6, dropin_front 6, dropin_left 5 | pass |
| crouch | trick_crouch_front | front-only | frame 0 of each ollie_* | pass |
| ollie / ramp air rising | trick_ollie_front | front-only, 1 frame | ollie_back 6, ollie_front 6, ollie_left 5, ollie_right 6, ollie_front_left 5 | back weak; others pass; front_left weak |
| kickflip | trick_kickflip_front | 1 frame, no rotation | kickflip_back 6, kickflip_front 6 | pass |
| grab | trick_grab_front | front-only | grab_back 4, grab_front 6 | weak, pass |
| land | trick_land_front | front-only | last frame of each ollie_* (or kickflip_back 5) | pass |
| bail | trick_land_front | wrong pose | bail_back 5, bail_front 1 | weak |
| grind | skate_<dir> | no art | grind_back 4, grind_left 4 | pass |
| air descending (no trick) | skate_<dir> | static | ollie_<dir> frame 4 | pass |

## v2 animations (32 animations, 169 frame slots)
| anim | state | dir | frames | fps | mode | status | note |
|---|---|---|---|---|---|---|---|
| cruise_back | cruise | back | 5 (5 unique) | 6 | loop | pass | Board points along travel (fixes sideways skate_back). Subtle sway. |
| cruise_back_left | cruise | back_left | 5 (5 unique) | 6 | loop | pass | Board along travel; near-static sway (5 close variants). |
| cruise_back_right | cruise | back_right | 4 (4 unique) | 6 | loop | pass | Board along travel; near-static sway (4 close variants). |
| push_back | push | back | 6 (6 unique) | 10 | loop | weak | 6 frames composited from two generations. Push foot touches the ground beside the deck in frames 2-3; from behind the push reads but is subtle; pushing foot side is ambiguous. |
| push_back_left | push | back_left | 5 (4 unique) | 10 | loop | pass | 5-step cycle, 4 unique drawings: ride, lift, ground contact, extension, recover. Keys came from a separate 2-frame generation. |
| push_back_right | push | back_right | 5 (4 unique) | 10 | loop | pass | 5-step cycle, 4 unique drawings like push_back_left. |
| push_left | push | left | 6 (6 unique) | 10 | loop | pass | Clean side push, back foot plants and extends with speed lines. |
| push_right | push | right | 6 (6 unique) | 10 | loop | pass | Clean side push; frame 5 extension with speed lines. |
| push_front | push | front | 6 (6 unique) | 10 | loop | weak | Push reads; angle drifts toward front_left (same drift as v1). |
| walk_back | walk | back | 6 (6 unique) | 8 | loop | pass | Board under left arm (viewer's left), alternating steps. |
| walk_front | walk | front | 6 (6 unique) | 8 | loop | weak | Board under left arm; leg alternation is small. |
| walk_left | walk | left | 6 (5 unique) | 8 | loop | weak | Generator kept repeating one stride; stride and passing keys from a 2-frame render give some up-down rhythm but legs do not truly alternate. |
| walk_right | walk | right | 6 (6 unique) | 8 | loop | weak | Small leg variation only; the passing-key render was rejected (marching knee). |
| kickup_back | kickup | back | 6 (6 unique) | 12 | once | pass | Ride, step off, tail stomp, board up, catch, tuck. Strip frames 5-6 rejected (turned to camera / wrong arm) and replaced by a 2-frame catch render. |
| dropin_back | dropin | back | 6 (6 unique) | 12 | once | pass | Board drops pointing away; step-on; roll. |
| kickup_front | kickup | front | 6 (6 unique) | 12 | once | pass | Replaces weak v1 kickup_1: tail press, board kicked up, catch, tuck. |
| dropin_front | dropin | front | 6 (6 unique) | 12 | once | pass | Clean 6-step drop and step-on. |
| kickup_left | kickup | left | 4 (4 unique) | 12 | once | weak | Frames 4-5 rejected (two boards drawn). 4 frames: jumps from tail-tip to tucked. |
| dropin_left | dropin | left | 5 (5 unique) | 12 | once | pass | Frame 3 of the strip had no character (board only), dropped. |
| ollie_back | ollie | back | 6 (6 unique) | 12 | once | weak | Strip crouch/land frames drew the board sideways and were replaced by cruise_back frames; air frames show the board at ~45 degrees. |
| kickflip_back | kickflip | back | 6 (6 unique) | 14 | once | pass | Board rotates through edge and upside-down. |
| grab_back | grab | back | 4 (4 unique) | 10 | once | weak | Frame 1 had no board, frame 6 sideways board: both rejected. 4 air frames. |
| ollie_front | ollie | front | 6 (6 unique) | 12 | once | pass | Crouch, pop, rise, peak, descend, land. |
| kickflip_front | kickflip | front | 6 (6 unique) | 14 | once | pass | Board flip reads; board sits low under feet in frame 1. |
| grab_front | grab | front | 6 (6 unique) | 10 | once | pass | Hand on board in frames 3-4. |
| ollie_left | ollie | left | 5 (5 unique) | 12 | once | pass | Strict profile. Strip frame 6 (sitting) rejected; frame 5 is the landing. |
| ollie_right | ollie | right | 6 (6 unique) | 12 | once | pass | Strict profile; jump height is modest. |
| ollie_front_left | ollie | front_left | 5 (5 unique) | 12 | once | weak | From a rejected side-view try that came out front-left; usable as a front-left ollie. |
| grind_back | grind | back | 4 (4 unique) | 8 | loop | pass | Board along the rail, sparks. try1 (sideways board) rejected. |
| grind_left | grind | left | 4 (4 unique) | 8 | loop | pass | Profile 50-50 with sparks and arm balance. |
| bail_back | bail | back | 5 (5 unique) | 10 | once | weak | Strip frame 4 turned to camera, rejected. Board in last frame lies sideways. |
| bail_front | bail | front | 1 (1 unique) | 1 | once | weak | Single sit-down pose salvaged from a rejected try. |
## Rejected generations (kept in raw/, never used as final)
- push_back_left_strip_try1/try2 as push: feet never leave the board; reused as cruise_back_left and lift frames
- push_back_right_strip_try1/try2 as push: feet never leave the board; reused as cruise_back_right and lift frames
- walk_left_strip_try1: six near-identical strides
- walk_right_strip_try1: six near-identical strides
- walk_right_pass_keys: marching knee, off-model gait
- kickup_back_strip_try1 idx4,5: turned to camera; board under the wrong arm
- ollie_back_strip_try1 (all) and try2 idx0,5: board drawn sideways on the ground
- grab_back_strip_try1 idx0,5: no board; sideways landing
- grind_back_strip_try1: board sideways for a grind going away
- ollie_left_strip_try1 as left: came out front-left; salvaged as ollie_front_left + bail_front
- ollie_right_strip_try1: came out front/three-quarter with a sitting frame
- kickup_left_strip_try1, dropin_left_strip_try1: came out front view (duplicate of front strips)
- kickup_left_strip_try2 idx3,4: two boards in frame
- dropin_left_strip_try2 idx2: board only, no character
- bail_back_strip_try1 idx3: turned to face the camera

## Production prep
- Alpha: cut from the cream paper with the repo's own `prepare_fony_sprites.cutout` (flood fill, shadow/speed-line removal, defringe). Alpha is hard-edged (0/255) with no cream halo. Small sparks and dashed motion arcs are dropped.
- Scale: per-strip scale from head width, corrected by eye against walk_back, walk_front and cruise_back (MULT table in build.py). The residual drift is about ±5-8%.
- Anchor: every master cell is 510x588, and the shared ground anchor is (255, 572), under the head axis. Airborne frames are raised by `lift_px` (recorded per frame in manifest.json).
- Atlas: `fony2d_v2_atlas.png` is 4096x1607, trimmed frames at 0.6x master (standing height 288 px, against 262 px in v1). The shelf-packed rects and anchor offsets are in the manifest.

## Honest gaps
- Back-view pushing is subtle. The generator kept both feet on the deck in 4 of 6 back/back-diagonal push tries. The back cycle is composited and the back-diagonal cycles have 4 unique drawings.
- Side walks do not truly alternate legs (the generator repeated one stride). walk_right and walk_front have small leg variation.
- No v2 art for: cruise left/right/front/front diagonals (v1 skate_* still used, static), push/walk/kickup/dropin in front_left/front_right/back diagonals beyond what's listed, kickup/dropin right, grind right/front, kickflip/grab side views, ramp-specific poses (it reuses ollie air), or idle breathing loops.
- Do not mirror left->right: the magenta patch would swap sides. Use the fallback table in INTEGRATION_SPEC.md.
- Within-strip drift is small, but across strips the patch and tape placement, the knee-pad brightness, and the exact jacket length vary a little. An artist cleanup pass would still help before calling this production-final.
- Not tested in Godot. The frames are packaged, not integrated.
- Atlas size: the full-color PNG is 7 MB. Ship `fony2d_v2_atlas_q256.png` (1.4 MB, same layout) or the `.webp` instead. Pages weight goes from about 1.4 MB (v1) to about 1.4 MB extra.
