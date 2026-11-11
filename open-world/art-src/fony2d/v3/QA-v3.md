# Fony 2D v3: smoothing pass QA (2026-11-11)

Everything new is in this folder. v1 (parent folder) and v2 are untouched (no file there changed after 07:40 CT today).
New art came from the built-in image generator (no paid assets). Style stays the approved sheet: copper hair, black hoodie,
patched rust jacket with the magenta patch on HIS LEFT, olive cargos, magenta knee pads, beige shoes, plain push deck.
No whole-character mirroring anywhere. (walk_front's right-foot steps flip only the legs below the jacket hem, which have no
left/right markings. The torso, chest patch and board are never flipped.)

## Totals
- 52 animations, 316 frame slots, 277 unique drawings (v2: 32 animations, 169 slots).
- Atlas `fony2d_v3_atlas_q256.png`: 4096x1768, 256 colours, 1.56 MB (budget ~1.5 MB). Full-colour `fony2d_v3_atlas.png` (8 MB) has the same layout.
  Atlas scale went from 0.6 to 0.5 of master to stay in budget. The body is ~240 px tall in the atlas (v1 was ~230, v2 288).
- Master cells are 510x648 with a shared ground anchor at (255,632). pixel_size for the atlas = 0.007167 m/px.

## Priority checklist
1. **Back push is readable**: REDONE as an 8-step stroke with the right foot only: lift, step out right, foot down beside the deck, drive back, full extension, swing in, back on the board. Weak spot: the planted foot sits at deck height, not quite at wheel level.
2. **Back ollie board level and on the travel line**: REDONE. In every frame the deck is end-on (pointing away) and level. The body comes from a v3 render; its sideways deck was erased and replaced with the deck, trucks and wheels cut from the approved cruise_back art. The pop frame tilts the deck nose-up. Weak spot: his feet sit a little wider than the narrow deck.
3. **Walk leg swing (6-8 frames)**: walk_front, walk_left and walk_right are each 8 frames now, with real passing poses (knee lifted, foot off the ground) and up poses. walk_front alternates feet. In side view the same leg leads each contact (the generator would not alternate legs in profile across 6 tries); at game scale it reads as a walk, not a slide.
4. **Back grab 6 frames (was 4); front bail 6 frames (was 1)**: done.
5. **Missing art**: grind_right, kickup_right, dropin_right; kickflip_left/right and grab_left/right; ollie_back_left/right; idle breathing for all 8 directions; cruise_left/right/front replace the v1 stills. All new.
6. **Smoothness**: cruise and grind loops ping-pong so they close without a pop (6-8 steps). Scale was matched per strip against the v2 reference poses (heights within ~5%). The foot line is shared, and a jump check ran on every loop (`jumps.py`). The only big frame-to-frame head jumps left are in v2's grind_left (unchanged; its balance poses swing widely).

## Still weak
- push_front (v2, angle drifts toward front-left); kickup_left (v2, 4 frames); bail_back (v2, last frame board sideways); ollie_front_left (v2).
- grab_back holds the board diagonally (tweaked) during the grab. It lands end-on.
- Side walks reuse the same lead leg each contact (see 3). In walk_left/right the board sits a touch lower in the passing frames, which comes from a separate render.
- grind_left (v2) has large pose swings between frames.
- Back-diagonal kickflip/grab: none yet (fallback to back).
- The right-facing views show the grey arm patch on the near arm, same as v2 right-facing art. Magenta is never on his right chest (grind_right v3a was rejected for that).

## Animations
| anim | state | dir | frames | fps | mode | status | note |
|---|---|---|---|---|---|---|---|
| idle_back | idle | back | 6 (4 unique) | 4 | loop | new | Breathing loop built from the v1 still: upper body rises <=1.2% about the waist. Subtle by design. |
| idle_back_left | idle | back_left | 6 (4 unique) | 4 | loop | new | Breathing loop built from the v1 still: upper body rises <=1.2% about the waist. Subtle by design. |
| idle_back_right | idle | back_right | 6 (4 unique) | 4 | loop | new | Breathing loop built from the v1 still: upper body rises <=1.2% about the waist. Subtle by design. |
| idle_left | idle | left | 6 (4 unique) | 4 | loop | new | Breathing loop built from the v1 still: upper body rises <=1.2% about the waist. Subtle by design. |
| idle_right | idle | right | 6 (4 unique) | 4 | loop | new | Breathing loop built from the v1 still: upper body rises <=1.2% about the waist. Subtle by design. |
| idle_front | idle | front | 6 (4 unique) | 4 | loop | new | Breathing loop built from the v1 still: upper body rises <=1.2% about the waist. Subtle by design. |
| idle_front_left | idle | front_left | 6 (4 unique) | 4 | loop | new | Breathing loop built from the v1 still: upper body rises <=1.2% about the waist. Subtle by design. |
| idle_front_right | idle | front_right | 6 (4 unique) | 4 | loop | new | Breathing loop built from the v1 still: upper body rises <=1.2% about the waist. Subtle by design. |
| cruise_back | cruise | back | 8 (5 unique) | 6 | loop | pass | v2 drawings, now an 8-step ping-pong so the sway loops without a pop. |
| cruise_back_left | cruise | back_left | 8 (5 unique) | 6 | loop | pass | v2 drawings, 8-step ping-pong. |
| cruise_back_right | cruise | back_right | 6 (4 unique) | 6 | loop | pass | v2 drawings, 6-step ping-pong. |
| cruise_left | cruise | left | 6 (6 unique) | 6 | loop | new | NEW: replaces the v1 skate_left still. Knee-bend sway loop; magenta patch on his left (near) side. |
| cruise_right | cruise | right | 6 (6 unique) | 6 | loop | new | NEW: replaces the v1 skate_right still. No magenta patch visible (it is on his far side). |
| cruise_front | cruise | front | 6 (4 unique) | 6 | loop | new | NEW: replaces the v1 skate_front still. Board end-on toward camera. Frames 0 and 2 of the strip rejected (diagonal board / turned crouch). |
| push_back | push | back | 8 (8 unique) | 12 | loop | new | REDONE: 8-step stroke with his RIGHT foot only: ride, lift, step out right, foot down beside the deck, drive back, full extension, swing in, back on the tail. Mixed from two v3 renders; v3b frames that pushed with the left leg were rejected. |
| push_back_left | push | back_left | 5 (4 unique) | 10 | loop | pass | v2 unchanged. |
| push_back_right | push | back_right | 5 (4 unique) | 10 | loop | pass | v2 unchanged. |
| push_left | push | left | 6 (6 unique) | 10 | loop | pass | v2 unchanged. |
| push_right | push | right | 6 (6 unique) | 10 | loop | pass | v2 unchanged. |
| push_front | push | front | 6 (6 unique) | 10 | loop | weak | v2 unchanged; angle drifts toward front_left. |
| walk_back | walk | back | 6 (6 unique) | 8 | loop | pass | v2 unchanged. |
| walk_front | walk | front | 8 (8 unique) | 8 | loop | new | REDONE: 8 steps, both feet alternate: passing (left knee up), left-foot contact, down, cross, right-foot contact, down, passing, up. Right-foot steps flip ONLY the legs below the jacket hem; torso, chest patch and board are never mirrored. |
| walk_left | walk | left | 8 (7 unique) | 8 | loop | new | REDONE: 8 steps with a real passing pose (knee lifted, foot off the ground) and an up pose between strides. Same leg leads each contact (generator would not alternate in profile). |
| walk_right | walk | right | 8 (6 unique) | 8 | loop | new | REDONE: 8 steps with passing (knee lifted) and up poses between strides. |
| kickup_back | kickup | back | 6 (6 unique) | 12 | once | pass | v2 unchanged. |
| dropin_back | dropin | back | 6 (6 unique) | 12 | once | pass | v2 unchanged. |
| kickup_front | kickup | front | 6 (6 unique) | 12 | once | pass | v2 unchanged. |
| dropin_front | dropin | front | 6 (6 unique) | 12 | once | pass | v2 unchanged. |
| kickup_left | kickup | left | 4 (4 unique) | 12 | once | weak | v2 unchanged (4 frames). |
| dropin_left | dropin | left | 5 (5 unique) | 12 | once | pass | v2 unchanged. |
| kickup_right | kickup | right | 6 (6 unique) | 12 | once | new | NEW: ride, step off, tail stomp, board vertical, catch, tuck. A duplicate board the generator drew under his feet in frames 3-5 was erased by hand. |
| dropin_right | dropin | right | 6 (6 unique) | 12 | once | new | NEW: hold, lower, step on, both feet, push, roll. v3a rejected (two boards in frame 2). |
| ollie_back | ollie | back | 7 (7 unique) | 12 | once | new | REDONE: board is now end-on (pointing along his travel line) and level in every air frame. Body from a v3 render; its sideways deck was replaced with the end-on deck/trucks/wheels cut from the approved cruise_back art. |
| ollie_back_left | ollie | back_left | 5 (5 unique) | 12 | once | new | NEW: board points upper-left along travel. Strip frame 2 rejected (board on the wrong diagonal). |
| ollie_back_right | ollie | back_right | 6 (6 unique) | 12 | once | new | NEW: board points upper-right along travel in every frame. |
| ollie_front | ollie | front | 6 (6 unique) | 12 | once | pass | v2 unchanged. |
| ollie_left | ollie | left | 5 (5 unique) | 12 | once | pass | v2 unchanged. |
| ollie_right | ollie | right | 6 (6 unique) | 12 | once | pass | v2 unchanged. |
| ollie_front_left | ollie | front_left | 5 (5 unique) | 12 | once | weak | v2 unchanged. |
| kickflip_back | kickflip | back | 6 (6 unique) | 14 | once | pass | v2 unchanged. |
| kickflip_front | kickflip | front | 6 (6 unique) | 14 | once | pass | v2 unchanged. |
| kickflip_left | kickflip | left | 6 (6 unique) | 14 | once | new | NEW: profile kickflip, board shows edge then wooden underside then grip. |
| kickflip_right | kickflip | right | 6 (6 unique) | 14 | once | new | NEW: profile kickflip facing right. |
| grab_back | grab | back | 6 (6 unique) | 10 | once | new | REDONE: 6 frames (was 4): crouch, pop, reach, grab, hold, release to an end-on landing. Board is tweaked diagonally while grabbed. |
| grab_front | grab | front | 6 (6 unique) | 10 | once | pass | v2 unchanged. |
| grab_left | grab | left | 6 (6 unique) | 10 | once | new | NEW: profile indy grab facing left. |
| grab_right | grab | right | 6 (6 unique) | 10 | once | new | NEW: profile indy grab facing right, hand on the board in frames 2-4. |
| grind_back | grind | back | 6 (4 unique) | 8 | loop | pass | v2 drawings, 6-step ping-pong loop. |
| grind_left | grind | left | 6 (4 unique) | 8 | loop | pass | v2 drawings, 6-step ping-pong loop. |
| grind_right | grind | right | 6 (4 unique) | 8 | loop | new | NEW: right-facing 50-50 with sparks (no more patch-wrong fallback to grind_left). v3a rejected: magenta patch on his right chest. |
| bail_back | bail | back | 5 (5 unique) | 10 | once | weak | v2 unchanged (last frame board sideways). |
| bail_front | bail | front | 6 (6 unique) | 10 | once | new | REDONE: 6 frames (was 1): board slips out, tip back, stumble, sit-fall, wince, get up on one knee. |

## Rejected (kept in raw/, never used as final)
- push_back_strip_v3a: foot never leaves the deck (same problem as v2)
- push_back_strip_v3b idx0,2,4,5: idx2/idx4 push with the LEFT leg (inconsistent stroke); idx5 taller than the rest of the cycle (scale pop); idx0 unused
- ollie_back_strip_v3a, v3c: board diagonal / sideways across the travel line
- ollie_back_strip_v3b (board only): sideways deck replaced by the end-on deck from cruise_back; body kept
- walk_left_keys_v3b, walk_right_keys_v3b: 4 near-identical strides; no alternation
- walk_front_mirlegs_pass_v3c_0: seam mismatch on the lifted thigh
- grind_right_strip_v3a: magenta patch drawn on his RIGHT chest (would read as mirrored)
- dropin_right_strip_v3a: two boards in frame 2
- kickup_right_strip_v3a idx3-5 (as drawn): second board under his feet; erased in kickup_right_fix
- ollie_back_left_strip_v3a idx2: board on the wrong diagonal for one frame
- cruise_front_strip_v3a idx0,2: diagonal board / turned crouch

## Rebuild
`python3 cut_strips.py && python3 comp_ollie_back.py && python3 make_virtual.py && python3 fix_kickup_right.py && python3 build.py && python3 make_gifs.py`
(scale fixes in `mult_v3.json`, animation table in `anims_v3.py`).
