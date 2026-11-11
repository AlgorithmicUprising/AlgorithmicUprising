extends RefCounted

## Names a painted frame for the Y-locked billboard.
## v2 clips cover the moving views. v1 stills fill the directions v2 does not
## have. Nothing is mirrored: the magenta patch stays on his left chest.

const DIRS := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
const FALLBACK := {
	"back": ["back"],
	"back_left": ["back_left", "back"],
	"back_right": ["back_right", "back"],
	"left": ["left", "back_left", "back"],
	"right": ["right", "back_right", "back"],
	"front": ["front"],
	"front_left": ["front_left", "front"],
	"front_right": ["front_right", "front", "right"],
}
const V2_PIXEL := 0.005972
const V1_PIXEL := 0.007674
const PUSH_START_SPEED := 7.2
const PUSH_STOP_SPEED := 8.4
const SKATE_SPEED := 9.0
const CRUISE_GAP := 0.35

var clips := {}
var clip := ""
var frame_index := 0
var key := ""
var visual_state := ""
var clip_time := 0.0
var trans_time := 0.0
var phase := ""
var push_phase := -1.0
var cruise_gap := 0.0
var land_hold := 0.0
var skating := true
var source := "v1"
var _prev_bail := false
var _ready_mode := false
var _loaded := false
var _end_push := false

func direction_index(facing_yaw: float, camera_x: float, camera_z: float, origin_x: float, origin_z: float) -> int:
	var to_cam := Vector2(camera_x - origin_x, camera_z - origin_z)
	if to_cam.length() < 0.001:
		return 0
	to_cam = to_cam.normalized()
	var face := Vector2(-sin(facing_yaw), -cos(facing_yaw))
	var cross_y := to_cam.y * face.x - to_cam.x * face.y
	var dot := to_cam.dot(face)
	var signed := atan2(cross_y, dot)
	return posmod(int(round(signed / (PI / 4.0))), 8)

func direction_name(facing_yaw: float, camera_x: float, camera_z: float, origin_x: float, origin_z: float) -> String:
	return DIRS[direction_index(facing_yaw, camera_x, camera_z, origin_x, origin_z)]

func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var v2 = JSON.parse_string(FileAccess.get_file_as_string("res://assets/library/fony2d/frames_v2.json"))
	if typeof(v2) == TYPE_DICTIONARY:
		for anim_name in v2.get("animations", {}):
			var anim: Dictionary = v2.animations[anim_name]
			var frames: Array = []
			for fr in anim.get("frames", []):
				var rect: Array = fr.get("atlas_rect", [0, 0, 1, 1])
				var off: Array = fr.get("anchor_offset", [0, 0])
				frames.append({
					"rect": rect,
					"anchor_offset": off,
					"lift_atlas": float(fr.get("lift_px", 0.0)) * 0.6,
				})
			clips[str(anim_name)] = {
				"source": "v2",
				"fps": float(anim.get("fps", 8.0)),
				"loop": bool(anim.get("loop", false)),
				"frames": frames,
			}
	var v1 = JSON.parse_string(FileAccess.get_file_as_string("res://assets/library/fony2d/frames.json"))
	if typeof(v1) != TYPE_DICTIONARY:
		return
	var anchor_x := float(v1.get("anchor_x", 106))
	var anchor_y := float(v1.get("anchor_y", 262))
	var pixel := float(v1.get("pixel_size", V1_PIXEL))
	for frame_name in v1.get("frames", {}):
		if clips.has(frame_name):
			continue
		var fr: Dictionary = v1.frames[frame_name]
		var lift_m := float(fr.get("lift_m", 0.0))
		clips[str(frame_name)] = {
			"source": "v1",
			"fps": 1.0,
			"loop": false,
			"frames": [{
				"rect": [fr.get("x", 0), fr.get("y", 0), fr.get("w", 1), fr.get("h", 1)],
				"anchor_offset": [-anchor_x, -anchor_y],
				"lift_atlas": lift_m / pixel,
			}],
		}

func step(delta: float, ctx: Dictionary) -> String:
	ensure_loaded()
	_notify(ctx)
	_advance_push(delta, ctx)
	if ctx.get("trick", "") == "land":
		land_hold += delta
	else:
		land_hold = 0.0
	var dir := _dir(ctx)
	if phase != "":
		trans_time += delta
		var tname := _resolve(phase, dir)
		if trans_time >= _duration(tname):
			phase = ""
			trans_time = 0.0
	var state := _state(ctx)
	var name := _resolve(state, dir)
	if name != clip:
		clip = name
		if state != visual_state:
			clip_time = 0.0
	elif state == visual_state or state == "kickup" or state == "dropin":
		pass
	visual_state = state
	if state != "kickup" and state != "dropin":
		clip_time += delta
	frame_index = _index(state, ctx)
	if _end_push:
		push_phase = -1.0
		cruise_gap = CRUISE_GAP
		_end_push = false
	var info := _clip(clip)
	source = str(info.get("source", "v1"))
	key = "%s#%d" % [clip, frame_index]
	return key

func current_frame() -> Dictionary:
	ensure_loaded()
	var info := _clip(clip)
	var frames: Array = info.get("frames", [])
	if frames.is_empty():
		return {}
	var fr: Dictionary = frames[clampi(frame_index, 0, frames.size() - 1)]
	var out := fr.duplicate()
	out["source"] = info.get("source", "v1")
	return out

func _notify(ctx: Dictionary) -> void:
	var next := bool(ctx.get("skating", true))
	var bail := str(ctx.get("trick", "")) == "bail" or float(ctx.get("bail_time", 0.0)) > 0.0
	if not _ready_mode:
		_ready_mode = true
		skating = next
		_prev_bail = bail
		return
	var blocked := bail or _prev_bail
	_prev_bail = bail
	if next == skating:
		return
	skating = next
	if blocked:
		phase = ""
		trans_time = 0.0
		return
	phase = "dropin" if next else "kickup"
	trans_time = 0.0
	push_phase = -1.0

func _advance_push(delta: float, ctx: Dictionary) -> void:
	if cruise_gap > 0.0:
		cruise_gap = maxf(0.0, cruise_gap - delta)
	var trick := str(ctx.get("trick", ""))
	var can := bool(ctx.get("skating", false)) and bool(ctx.get("on_floor", false)) and float(ctx.get("wish", 0.0)) > 0.2 and not bool(ctx.get("grind", false)) and trick == "" and phase == ""
	var speed := float(ctx.get("speed", 0.0))
	var accel := float(ctx.get("accel", 0.0))
	if push_phase < 0.0 and can and cruise_gap <= 0.0 and (speed < PUSH_START_SPEED or (accel > 0.25 and speed < PUSH_STOP_SPEED)):
		push_phase = 0.0
	if push_phase < 0.0:
		return
	var stroke := lerpf(0.6, 0.45, clampf(speed / SKATE_SPEED, 0.0, 1.0))
	push_phase += delta / maxf(stroke, 0.05)
	if push_phase >= 1.0:
		push_phase = 0.999
		_end_push = true

func _state(ctx: Dictionary) -> String:
	var trick := str(ctx.get("trick", ""))
	var on_floor := bool(ctx.get("on_floor", true))
	var speed := float(ctx.get("speed", 0.0))
	if trick == "bail":
		return "bail"
	if bool(ctx.get("grind", false)):
		return "grind"
	if trick == "crouch" or trick == "ollie" or trick == "flip" or trick == "grab" or trick == "land":
		if trick == "flip":
			return "kickflip"
		if trick == "grab":
			return "grab"
		if trick == "land" and land_hold > 0.25:
			return "cruise" if bool(ctx.get("skating", true)) else "idle"
		return "ollie"
	# A kick-up or drop-in keeps playing if the body leaves the floor for a frame.
	if phase != "":
		return phase
	if not on_floor and bool(ctx.get("skating", true)):
		return "ollie"
	if not bool(ctx.get("skating", true)):
		return "walk" if speed >= 0.3 else "idle"
	if push_phase >= 0.0:
		return "push"
	return "cruise"

func _dir(ctx: Dictionary) -> String:
	return direction_name(float(ctx.get("facing_yaw", 0.0)), float(ctx.get("camera_x", 0.0)), float(ctx.get("camera_z", 4.0)), float(ctx.get("origin_x", 0.0)), float(ctx.get("origin_z", 0.0)))

func _resolve(state: String, dir: String) -> String:
	# A right-facing grind has no painting. grind_left would turn him around
	# and put the chest patch on the wrong side, so the right view keeps the
	# still skate frame. Back and left use the new grind cycles.
	if state == "grind":
		if dir == "back" or dir.begins_with("back_"):
			return "grind_back" if clips.has("grind_back") else _still("skate_", dir)
		if dir == "left":
			return "grind_left" if clips.has("grind_left") else _still("skate_", dir)
		return _still("skate_", dir)
	for candidate in FALLBACK.get(dir, ["front"]):
		var anim_name: String = "%s_%s" % [state, candidate]
		if clips.has(anim_name):
			return anim_name
	if state == "cruise" or state == "push":
		return _still("skate_", dir)
	return _still("idle_", dir)

func _still(prefix: String, dir: String) -> String:
	var direct := prefix + dir
	if clips.has(direct):
		return direct
	for candidate in FALLBACK.get(dir, ["front"]):
		var alt: String = prefix + str(candidate)
		if clips.has(alt):
			return alt
	return direct

func _index(state: String, ctx: Dictionary) -> int:
	var count := _count(clip)
	if count <= 1:
		return 0
	if state == "ollie":
		return _ollie_index(count, ctx)
	if state == "kickflip":
		return clampi(int(float(ctx.get("flip_turns", 0.0)) * float(count)), 0, count - 1)
	if state == "grab":
		return _grab_index(count, ctx)
	if state == "push":
		return clampi(int(push_phase * float(count)), 0, count - 1)
	if state == "bail":
		if count == 1:
			return 0
		var u := 1.0 - clampf(float(ctx.get("bail_time", 0.6)) / 0.6, 0.0, 1.0)
		return clampi(int(u * float(count)), 0, count - 1)
	if state == "kickup" or state == "dropin":
		return clampi(int(trans_time * _fps(clip)), 0, count - 1)
	if state == "idle" or str(_clip(clip).get("source", "")) == "v1":
		return 0
	var fps := _playback_fps(state, ctx)
	if bool(_clip(clip).get("loop", false)):
		return posmod(int(clip_time * fps), count)
	return clampi(int(clip_time * fps), 0, count - 1)

func _ollie_index(count: int, ctx: Dictionary) -> int:
	var trick := str(ctx.get("trick", ""))
	var vy := float(ctx.get("vy", 0.0))
	var t := float(ctx.get("trick_time", 0.0))
	if trick == "crouch":
		return 0
	if trick == "land":
		return count - 1
	if trick == "":
		return mini(3, count - 1) if vy > 0.0 else mini(4, count - 1)
	if t < 0.1:
		return mini(1, count - 1)
	if vy > 0.0:
		return 2 if t < 0.28 else mini(3, count - 1)
	return mini(4, count - 1)

func _grab_index(count: int, ctx: Dictionary) -> int:
	if float(ctx.get("vy", 0.0)) < -3.0:
		return count - 1
	var t := float(ctx.get("trick_time", 0.0))
	if t < 0.3:
		return clampi(int(t * 10.0), 0, mini(2, count - 1))
	return clampi(count / 2, 0, count - 1)

func _playback_fps(state: String, ctx: Dictionary) -> float:
	if state == "walk":
		return clampf(8.0 * float(ctx.get("speed", 0.0)) / 4.5, 4.0, 10.0)
	if state == "cruise":
		return 6.0
	if state == "grind":
		return 8.0
	return _fps(clip)

func _clip(name: String) -> Dictionary:
	return clips.get(name, {})

func _count(name: String) -> int:
	var frames: Array = _clip(name).get("frames", [])
	return frames.size()

func _fps(name: String) -> float:
	return maxf(float(_clip(name).get("fps", 8.0)), 0.1)

func _duration(name: String) -> float:
	return float(maxi(_count(name), 1)) / _fps(name)
