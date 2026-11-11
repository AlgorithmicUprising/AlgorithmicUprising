# Fony 2D v2: integration spec for the coding agent

Repo: `open-world/`. Current code is `scripts/fony_sprite.gd` and `scripts/fony_sprite_anim.gd`, with the atlas in `assets/library/fony2d/`. Keep it a 2D-in-3D Y-locked billboard Sprite3D. Do not change the engine or add 3D meshes.

## Files to bring in
- `fony2d_v2_atlas_q256.png` (1.4 MB, 256-color, visually checked; the same layout as the 7 MB full-color `fony2d_v2_atlas.png`) goes to `assets/library/fony2d/fony2d_v2_atlas.png`.
- `manifest.json` goes to `assets/library/fony2d/frames_v2.json`. Each animation has `state`, `direction`, `fps`, `loop`, and `frames[]`. Each frame has `atlas_rect` [x,y,w,h], `anchor_offset` [dx,dy] (the trimmed rect's top-left relative to the ground anchor, atlas px, y down), and `lift_px` (master px; multiply by 0.6 for atlas px).
- Keep the v1 atlas for idle_* and the skate_* cruise views that v2 doesn't cover. A single combined atlas is fine if you repack. `frames/*.png` are 510x588 master cells sharing anchor (255,572) for any repack.
- `pixel_size` for the v2 atlas is 0.005972 (1.72 m / 288 px). v1 uses 0.007674, so set pixel_size **per frame source** when mixing atlases.

## Placing a frame (Sprite3D, centered = false)
```
sprite.region_rect = Rect2(rect.x, rect.y, rect.w, rect.h)
# Sprite3D offset is in texture pixels with +Y up; anchor sits at the node origin
sprite.offset = Vector2(anchor_offset.x, -(anchor_offset.y + rect.h))
if body_is_airborne_from_physics:
    sprite.offset.y -= lift_px * 0.6   # the capsule already rises; don't double-lift
sprite.position = Vector3(0, foot_local_y, 0)   # foot_local_y = 0.325 as today
```
Verify the sign convention once in a headless capture. Fony's feet (wheels, when riding) should touch the capsule bottom in cruise_back_00 and walk_back_00.

## Direction
Keep `direction_index()` (8 sectors). Resolve `<state>_<dir>` through this fallback order. Never mirror, because the chest patch would swap sides.

| wanted dir | try in order |
|---|---|
| back | back |
| back_left | back_left, back |
| back_right | back_right, back |
| left | left, back_left, back |
| right | right, back_right, back |
| front | front |
| front_left | front_left, front |
| front_right | front_right, front, right |

For states with no v2 animation in a direction (for example cruise_left/right/front*), use the v1 single frame `skate_<dir>`. For idle, use `idle_<dir>`.

## State to animation
| state (controller) | animation | timing |
|---|---|---|
| on foot, speed < 0.3 | v1 `idle_<dir>` | static |
| on foot, moving | `walk_<dir>` | loop; fps = 8 * (speed / WALK_SPEED 4.5), clamp 4-10 |
| skating, on floor, not pushing | `cruise_<dir>` | loop at 6 fps; random start frame; fallback v1 `skate_<dir>` |
| skating, pushing | `push_<dir>` | see the push section |
| mode change skate to walk | `kickup_<dir>` | once at 12 fps (6 frames = 0.5 s); then walk/idle |
| mode change walk to skate | `dropin_<dir>` | once at 12 fps; then cruise/push |
| trick == "crouch" (0.62 s) | `ollie_<dir>` frame 0 | hold |
| trick in ollie/grab/flip, first 0.1 s | `ollie_<dir>` frame 1 (pop) | |
| trick == "ollie", airborne | `ollie_<dir>` frames 2-3 while velocity.y > 0, frame 4 while velocity.y <= 0 | |
| trick == "flip" | `kickflip_<dir>` | map frame = clamp(int(flip_turns * 6), 0, 5) so the board rotation tracks the 1.0 s flip; fallback kickflip_back/front by the back/front half |
| trick == "grab" | `grab_<dir>` | play 0..2 at 10 fps, hold the middle "holding" frame while airborne, last frame when velocity.y < -3 |
| trick == "land" (0.5 s) | last frame of `ollie_<dir>` for 0.25 s, then cruise | |
| trick == "bail" (0.6 s) | `bail_<dir>` | once, spread over bail_time; fallback bail_back/front |
| grind != null | `grind_<dir>` | loop 8 fps; fallback grind_back for back*, grind_left for left/right/front (patch side wrong for right; accept or keep v1 skate_right) |
| airborne, no trick | `ollie_<dir>` frame 3 rising, frame 4 falling | |
| ramp air | same as airborne rules | |

## Push cycle tied to speed
The push is a stroke and must finish once started. Never cut it mid-frame.
```
const PUSH_START_SPEED := 7.2    # start a stroke when below this with input held
const PUSH_STOP_SPEED := 8.4     # don't start new strokes above this
var push_phase := -1.0          # -1 = not in a stroke, else 0..1

if skating and on_floor and wish_len > 0.2 and grind == null and trick == "":
    if push_phase < 0.0 and (speed < PUSH_START_SPEED or accel > 0.25 and speed < PUSH_STOP_SPEED):
        push_phase = 0.0
if push_phase >= 0.0:
    # stroke length 0.6 s from a stop, 0.45 s near top speed
    var stroke := lerp(0.6, 0.45, clamp(speed / SKATE_SPEED, 0, 1))
    push_phase += delta / stroke
    frame = int(push_phase * frame_count)  # push_<dir> frames in order
    if push_phase >= 1.0:
        push_phase = -1.0           # back to cruise_<dir>; a new stroke may start next tick
```
- After a stroke, hold cruise for at least 0.35 s before the next stroke so he doesn't look like he's running on the board.
- Physics stays as it is. If you want the speed bump to land on the ground-contact frames (push_back 1-2, push_side 2-4, push_back_left/right 2-3), apply the acceleration impulse only while `push_phase` is in 0.25-0.7. That's optional.
- Starting from 0 speed, the first stroke can follow drop-in frame 4 or 5 directly.

## Things to keep
- Physics/rig untouched; the sprite only names a frame. Keep `body.sprite_frame = key` for tests and expose `anim + frame index`.
- Update `tests/test_main.gd` assertions that expect old names (`push_cycle_left_*`, `trick_*_front`, `kickup_1_hook`, ...).
- Arcade (/demo/) is untouched. Only main's combined Arcade+HQ artifact publishes.
