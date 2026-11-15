# Fony 2D v3: integration delta for PR 18 (branch cursor/fony-v2-anim-83e6)

Same rules as v2's INTEGRATION_SPEC.md: keep the 2D-in-3D Y-locked billboard Sprite3D. No engine change, no 3D meshes, no physics/rig change. Never mirror Fony. Do not merge or deploy.

## Files
- `fony2d_v3_atlas_q256.png` (1.56 MB, 256-colour) goes to `open-world/assets/library/fony2d/fony2d_v3_atlas.png`. This replaces the v2 atlas, because every v2 drawing still in use is repacked here.
- `manifest.json` goes to `open-world/assets/library/fony2d/frames_v3.json`. The format is the same as v2: `atlas_rect`, `anchor_offset` (atlas px, y down) and `lift_px` (master px, so multiply by 0.5 for atlas px). New optional keys are `phases` (per animation) and `status`.
- Atlas `scale_from_master` is now **0.5**, so `pixel_size` = **0.007167** (1.72 m / 240 px).
- v1 atlas: idle now comes from v3 (`idle_<dir>`, breathing). v1 is only needed if you keep `skate_front_left/right` as cruise fallbacks. Otherwise use `cruise_front` for front_left/front_right and drop the v1 atlas from the web pack, which saves ~1.4 MB. Please prefer dropping it, if the tests agree.

## State to animation changes vs v2 spec
| state | v3 |
|---|---|
| on foot, still | `idle_<dir>` loop at 4 fps (6-step ping-pong, all 8 dirs) |
| on foot, moving | `walk_<dir>`: front/left/right now 8 frames, back 6. Scale the fps by frame count: fps = (frames/6) * 8 * (speed/4.5), clamp to (frames/6)*[4,10] |
| cruise | `cruise_<dir>` now exists for back, back_left, back_right, left, right, front. front_left/front_right fall back to front |
| push | `push_back` is 8 frames. Keep the time-driven stroke (`frame = int(push_phase * frame_count)`). Optional impulse window = `phases.ground_contact` frames |
| kickup / dropin | right-side versions now exist (`kickup_right`, `dropin_right`) |
| ollie | use `phases` instead of fixed indices: crouch hold = `phases.crouch`; first 0.1 s = `phases.pop`; rising = `phases.rise` (step through by vertical velocity); falling = `phases.fall`; land = `phases.land`. `ollie_back` has an extra `recover` frame (6) to play during the 0.5 s land state after `land`. New: `ollie_back_left`, `ollie_back_right` |
| kickflip | `kickflip_left`, `kickflip_right` are new. Same mapping: frame = clamp(int(flip_turns*6),0,5) |
| grab | 6 frames everywhere (`grab_back` was 4). Use `phases`: crouch, pop, reach, then hold `phases.hold` while airborne, then `release` when velocity.y < -3. `grab_left`/`grab_right` are new |
| grind | `grind_right` is new. Drop the grind_left fallback for right (it had the patch on the wrong side). The loops are 6-step ping-pong at 8 fps |
| bail | `bail_front` is 6 frames now (spread over bail_time like bail_back) |

Direction fallback table: unchanged from v2, except that `right` now resolves to real right art for cruise, kickup, dropin, kickflip, grab and grind.

## Tests / evidence wanted
- Update `tests/test_main.gd` name and frame-count assertions for v3. Assert that every frame rect lies inside the atlas, and that every state resolves for all 8 dirs through the fallback table.
- Headless captures in the park: riding away (cruise_back), push_back mid-stroke (frame 4 or 5), ollie_back at peak, a side kickflip, walk_front and walk_left mid-stride, grind_right on a rail, bail_front. Save PNGs in a stable folder and list the paths.
- CI green on the PR. **Do not merge, do not deploy.**
