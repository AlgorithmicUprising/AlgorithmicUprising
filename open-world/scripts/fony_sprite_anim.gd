extends RefCounted

## Names a painted frame for the Y-locked billboard.
## v3 clips cover every direction that was painted. Nothing is mirrored:
## the magenta patch stays on his left chest.

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
const ATLAS_SCALE := 0.5
const POP_VY := 12.0
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
var source := "v3"
var atlas_size := Vector2i(4096, 1768)
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
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/library/fony2d/frames_v3.json"))
	if typeof(catalog) != TYPE_DICTIONARY:
		return
	var size: Array = catalog.get("atlas", {}).get("size", [4096, 1768])
	if size.size() >= 2:
		atlas_size = Vector2i(int(size[0]), int(size[1]))
	for anim_name in catalog.get("animations", {}):
		var anim: Dictionary = catalog.animations[anim_name]
		var frames: Array = []
		for fr in anim.get("frames", []):
			var rect: Array = fr.get("atlas_rect", [0, 0, 1, 1])
			var off: Array = fr.get("anchor_offset", [0, 0])
			frames.append({
				"rect": rect,
				"anchor_offset": off,
				"lift_atlas": float(fr.get("lift_px", 0.0)) * ATLAS_SCALE,
			})
		var phases: Dictionary = {}
		if typeof(anim.get("phases", null)) == TYPE_DICTIONARY:
			phases = anim.phases
		clips[str(anim_name)] = {
			"source": "v3",
			"fps": float(anim.get("fps", 8.0)),
			"loop": bool(anim.get("loop", false)),
			"frames": frames,
			"phases": phases,
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
	visual_state = state
	if state != "kickup" and state != "dropin":
		clip_time += delta
	frame_index = _index(state, ctx)
	if _end_push:
		push_phase = -1.0
		cruise_gap = CRUISE_GAP
		_end_push = false
	var info := _clip(clip)
	source = str(info.get("source", "v3"))
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
	out["source"] = info.get("source", "v3")
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
		if trick == "crouch":
			var nxt := str(ctx.get("trick_next", ""))
			if nxt == "grab":
				return "grab"
			if nxt == "flip":
				return "kickflip"
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
	for candidate in FALLBACK.get(dir, ["front"]):
		var anim_name: String = "%s_%s" % [state, candidate]
		if clips.has(anim_name):
			return anim_name
	# A few facings were never painted (front grind, side bail). Borrow another
	# clip of the same action. Right-facing views never take a left painting.
	for candidate in _last_resort(dir):
		var fallback_name: String = "%s_%s" % [state, str(candidate)]
		if clips.has(fallback_name):
			return fallback_name
	return "%s_%s" % [state, dir]

func _last_resort(dir: String) -> Array:
	if dir == "right" or dir == "front_right" or dir == "back_right":
		return ["right", "back_right", "back", "front"]
	if dir == "left" or dir == "front_left" or dir == "back_left":
		return ["left", "back_left", "back", "front"]
	if dir.begins_with("front"):
		return ["front", "back"]
	return ["back", "front"]

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
		var u := 1.0 - clampf(float(ctx.get("bail_time", 0.6)) / 0.6, 0.0, 1.0)
		return clampi(int(u * float(count)), 0, count - 1)
	if state == "kickup" or state == "dropin":
		return clampi(int(trans_time * _fps(clip)), 0, count - 1)
	var fps := _playback_fps(state, ctx)
	if bool(_clip(clip).get("loop", false)):
		return posmod(int(clip_time * fps), count)
	return clampi(int(clip_time * fps), 0, count - 1)

func _ollie_index(count: int, ctx: Dictionary) -> int:
	var phases: Dictionary = _clip(clip).get("phases", {})
	if phases.is_empty():
		return 0
	var trick := str(ctx.get("trick", ""))
	var vy := float(ctx.get("vy", 0.0))
	var t := float(ctx.get("trick_time", 0.0))
	if trick == "crouch":
		return clampi(_phase_one(phases, "crouch"), 0, count - 1)
	if trick == "land":
		if phases.has("recover") and land_hold >= 0.25:
			return clampi(_phase_one(phases, "recover"), 0, count - 1)
		return clampi(_phase_one(phases, "land"), 0, count - 1)
	if trick != "" and t < 0.1:
		return clampi(_phase_one(phases, "pop"), 0, count - 1)
	if vy > 0.0:
		var along := 1.0 - clampf(vy / POP_VY, 0.0, 1.0)
		return clampi(_phase_at(phases, "rise", along), 0, count - 1)
	return clampi(_phase_one(phases, "fall"), 0, count - 1)

func _grab_index(count: int, ctx: Dictionary) -> int:
	var phases: Dictionary = _clip(clip).get("phases", {})
	if phases.is_empty():
		return 0
	var trick := str(ctx.get("trick", ""))
	var vy := float(ctx.get("vy", 0.0))
	var t := float(ctx.get("trick_time", 0.0))
	if trick == "crouch":
		return clampi(_phase_one(phases, "crouch"), 0, count - 1)
	if vy < -3.0:
		return clampi(_phase_one(phases, "release"), 0, count - 1)
	if t < 0.1:
		return clampi(_phase_one(phases, "pop"), 0, count - 1)
	if t < 0.22:
		return clampi(_phase_one(phases, "reach"), 0, count - 1)
	var along := clampf((t - 0.22) / 0.45, 0.0, 0.999)
	return clampi(_phase_at(phases, "hold", along), 0, count - 1)

func _phase_list(phases: Dictionary, key: String) -> Array:
	var raw = phases.get(key, 0)
	if typeof(raw) == TYPE_ARRAY:
		return raw
	return [raw]

func _phase_at(phases: Dictionary, key: String, along: float) -> int:
	var frames := _phase_list(phases, key)
	if frames.is_empty():
		return 0
	var i := clampi(int(clampf(along, 0.0, 0.999) * float(frames.size())), 0, frames.size() - 1)
	return int(frames[i])

func _phase_one(phases: Dictionary, key: String) -> int:
	return _phase_at(phases, key, 0.0)

func _playback_fps(state: String, ctx: Dictionary) -> float:
	if state == "walk":
		var scale := float(maxi(_count(clip), 1)) / 6.0
		var speed_ratio := float(ctx.get("speed", 0.0)) / 4.5
		return clampf(scale * 8.0 * speed_ratio, scale * 4.0, scale * 10.0)
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
