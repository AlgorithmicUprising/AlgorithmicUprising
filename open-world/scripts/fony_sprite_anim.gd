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
# Phase 1a timing. Defaults match player_controller.gd; the live sprite passes the
# body's own values in ctx (pop_vy, gravity, crouch_s, jump_vy).
const POP_VY := 3.8
const GRAVITY := 18.0
const CROUCH_S := 0.2
const JUMP_VY := 6.2
# A new push stroke only starts below this ground speed (top speed is 9 m/s).
const PUSH_START_SPEED := 6.0
const SKATE_SPEED := 9.0
# The planted push sole glides back this far per authored frame, in game metres
# (puppet push_right #6-#12 soles in the atlas: about 11.1 px x PIXEL 0.007167).
const PUSH_FOOT_M_PER_FRAME := 0.0796
# Puppet push frames #6-#11 have the push foot on the ground (#12 lifts it). Every
# puppet view shares this window so the views stay in step when the camera swaps.
const PUPPET_PUSH_CONTACT := Vector2i(6, 12)
# Contact frames follow ground speed, within these multiples of the authored fps.
const PUSH_CONTACT_MIN_RATE := 0.5
const PUSH_CONTACT_MAX_RATE := 4.0
const CRUISE_GAP := 0.35
# Phase 2: the pump clip (8 frames, cruise #0 at both ends) spans this much wall angle (= player PUMP_MAX_DEG).
const PUMP_FULL_DEG := 50.0
const USE_PUPPET := true
const PUPPET_JSON := "res://assets/library/fony2d/frames_puppet_v1.json"

var clips := {}
var clip := ""
var frame_index := 0
var key := ""
var visual_state := ""
var clip_time := 0.0
var trans_time := 0.0
var phase := ""
var push_phase := -1.0
## Authored push frame (float) while a stroke plays; push_phase is this over the frame count.
var push_frame := -1.0
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


func _parse_json(path: String) -> Variant:
	if path.ends_with(".gz"):
		var bytes := FileAccess.get_file_as_bytes(path)
		var dec := bytes.decompress_dynamic(8 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
		if dec.is_empty():
			return null
		return JSON.parse_string(dec.get_string_from_utf8())
	return JSON.parse_string(FileAccess.get_file_as_string(path))

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
	_load_catalog(catalog, "v3")
	# LOCAL TEST ONLY: puppet-v1 Skeleton2D bakes override same-name clips (all 8 directions; per-frame atlas_file).
	if USE_PUPPET and FileAccess.file_exists(PUPPET_JSON):
		var pc = _parse_json(PUPPET_JSON)
		if typeof(pc) == TYPE_DICTIONARY:
			_load_catalog(pc, "puppet")

func _load_catalog(catalog: Dictionary, tag: String) -> void:
	for anim_name in catalog.get("animations", {}):
		var anim: Dictionary = catalog.animations[anim_name]
		var frames: Array = []
		var catalog_scale := float(catalog.get("atlas", {}).get("scale_from_master", ATLAS_SCALE))
		var catalog_px := float(catalog.get("atlas", {}).get("pixel_size_m", 0.007167))
		for fr in anim.get("frames", []):
			var rect: Array = fr.get("atlas_rect", [0, 0, 1, 1])
			var off: Array = fr.get("anchor_offset", [0, 0])
			frames.append({
				"rect": rect,
				"anchor_offset": off,
				"lift_atlas": float(fr.get("lift_px", 0.0)) * catalog_scale,
				"atlas": tag,
				"atlas_file": str(fr.get("atlas_file", "")),
				"atlas_scale": catalog_scale,
				"pixel_size": catalog_px,
				# Phase 1d ground depth (puppet bakes only; v3 paintings stand on the body).
				"ground_depth_m": float(fr.get("ground_depth_m", 0.0)),
				"body_px": fr.get("body_px", [0.0, 0.0]),
				"board_px": fr.get("board_px", [0.0, 0.0]),
				"body_scale": float(fr.get("body_scale", 1.0)),
			})
		var phases: Dictionary = {}
		if typeof(anim.get("phases", null)) == TYPE_DICTIONARY:
			phases = anim.phases
		clips[str(anim_name)] = {
			"source": tag,
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
		push_frame = -1.0
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
	# Phase 3: the drop-in clips own the board-on / board-off moments (no flat kick-up / drop-in phase on top of them)
	if str(ctx.get("qp", "")) != "":
		phase = ""
		trans_time = 0.0
		skating = next
		_prev_bail = false
		_ready_mode = true
		return
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
	push_frame = -1.0

func _advance_push(delta: float, ctx: Dictionary) -> void:
	if cruise_gap > 0.0:
		cruise_gap = maxf(0.0, cruise_gap - delta)
	var trick := str(ctx.get("trick", ""))
	var on_ramp := str(ctx.get("ramp", "")) != ""
	# Phase 2: no push strokes on the wall (the stick pumps there); a stroke in progress ends at the bottom of the curve
	if on_ramp and push_frame >= 0.0:
		push_frame = -1.0
		push_phase = -1.0
	var can := bool(ctx.get("skating", false)) and bool(ctx.get("on_floor", false)) and float(ctx.get("wish", 0.0)) > 0.2 and not bool(ctx.get("grind", false)) and trick == "" and phase == "" and not on_ramp
	var speed := float(ctx.get("speed", 0.0))
	if push_frame < 0.0 and can and cruise_gap <= 0.0 and speed < PUSH_START_SPEED:
		push_frame = 0.0
	if push_frame < 0.0:
		push_phase = -1.0
		return
	var push_clip := _resolve("push", _dir(ctx))
	var count := maxi(_count(push_clip), 1)
	var fps := _fps(push_clip)
	var window := _push_contact(push_clip)
	# Swing frames play at their authored length. While the push foot is down it
	# travels back with the ground, so those frames advance with ground speed.
	var remaining := delta
	while remaining > 0.0 and push_frame < float(count):
		var whole := int(push_frame)
		var rate := fps
		if whole >= window.x and whole < window.y:
			rate = clampf(speed / PUSH_FOOT_M_PER_FRAME, fps * PUSH_CONTACT_MIN_RATE, fps * PUSH_CONTACT_MAX_RATE)
		var to_next := (float(whole + 1) - push_frame) / rate
		if to_next >= remaining:
			push_frame += remaining * rate
			remaining = 0.0
		else:
			push_frame = float(whole + 1)
			remaining -= to_next
	if push_frame >= float(count):
		push_frame = float(count) - 0.001
		_end_push = true
	push_phase = push_frame / float(count)

func _push_contact(push_clip: String) -> Vector2i:
	var info := _clip(push_clip)
	if str(info.get("source", "")) == "puppet":
		return PUPPET_PUSH_CONTACT
	var contact: Array = _phase_list(info.get("phases", {}), "ground_contact")
	if contact.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(contact[0]), int(contact[contact.size() - 1]) + 1)

func _state(ctx: Dictionary) -> String:
	var qp := str(ctx.get("qp", ""))
	if qp != "" and clips.has("qp_setup_back"):
		if qp == "setup" or qp == "ready":
			return "qp_setup"
		if qp == "commit" or qp == "roll":
			return "qp_dropin"
		if qp == "bail":
			return "qp_bail"
		if qp == "kickturn" and clips.has("qp_kickturn_bs50_back"):
			return "qp_kickturn_bs%d" % int(ctx.get("kt_deg", 50))
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
	# Phase 2 pumping cue: hips drop entering the transition and rise through it (frame from the wall angle)
	if str(ctx.get("ramp", "")) == "ride" and bool(ctx.get("pumping", false)) and clips.has("pump_right"):
		return "pump"
	if not on_floor and bool(ctx.get("skating", true)):
		return "ollie"
	if not bool(ctx.get("skating", true)):
		return "walk" if speed >= 0.3 else "idle"
	if push_frame >= 0.0:
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
		# flip_turns still holds the last flip during the next crouch; wind up on #0.
		if str(ctx.get("trick", "")) == "crouch":
			return 0
		return clampi(int(float(ctx.get("flip_turns", 0.0)) * float(count)), 0, count - 1)
	if state == "grab":
		return _grab_index(count, ctx)
	if state == "push":
		return clampi(int(push_frame), 0, count - 1)
	if state == "pump":
		return clampi(int(clampf(float(ctx.get("ramp_deg", 0.0)) / PUMP_FULL_DEG, 0.0, 0.999) * float(count)), 0, count - 1)
	if state == "bail":
		var u := 1.0 - clampf(float(ctx.get("bail_time", 0.6)) / 0.6, 0.0, 1.0)
		return clampi(int(u * float(count)), 0, count - 1)
	if state == "kickup" or state == "dropin":
		return clampi(int(trans_time * _fps(clip)), 0, count - 1)
	if state == "qp_setup" or state == "qp_bail" or state.begins_with("qp_kickturn"):
		return clampi(int(float(ctx.get("qp_time", 0.0)) * _fps(clip) + 0.001), 0, count - 1)
	if state == "qp_dropin":
		return _qp_dropin_index(count, ctx)
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
		# Wind down from the ride pose (#0) into the crouch frame over the crouch time.
		var low := _phase_one(phases, "crouch")
		var c := clampf(float(ctx.get("trick_time", 0.0)) / maxf(float(ctx.get("crouch_s", CROUCH_S)), 0.01), 0.0, 0.999)
		return clampi(int(c * float(low + 1)), 0, count - 1)
	if trick == "land":
		# Absorb: land through recover at the authored rate, then hold the last frame.
		var first := _phase_one(phases, "land")
		return clampi(first + int(land_hold * _fps(clip)), first, count - 1)
	var air := _phase_list(phases, "pop") + _phase_list(phases, "rise") + _phase_list(phases, "fall")
	if trick != "":
		# Pick the frame by the fraction of the ballistic airtime elapsed, so pop,
		# rise and fall each get their share and no frame waits on the body.
		var pop := float(ctx.get("pop_vy", POP_VY))
		var g := maxf(float(ctx.get("gravity", GRAVITY)), 0.1)
		var u := t / maxf(2.0 * pop / g, 0.05)
		return clampi(int(air[clampi(int(u * float(air.size())), 0, air.size() - 1)]), 0, count - 1)
	# A plain jump or rolling off a ledge has no trick clock; follow the velocity.
	var jump := maxf(float(ctx.get("jump_vy", JUMP_VY)), 0.1)
	if vy > 0.0:
		return clampi(_phase_at(phases, "rise", 1.0 - clampf(vy / jump, 0.0, 1.0)), 0, count - 1)
	return clampi(_phase_at(phases, "fall", clampf(-vy / jump, 0.0, 1.0)), 0, count - 1)

func _grab_index(count: int, ctx: Dictionary) -> int:
	var phases: Dictionary = _clip(clip).get("phases", {})
	if phases.is_empty():
		return 0
	if phases.has("rise"):
		return _puppet_grab_index(count, phases, ctx)
	var trick := str(ctx.get("trick", ""))
	var vy := float(ctx.get("vy", 0.0))
	var t := float(ctx.get("trick_time", 0.0))
	if trick == "crouch":
		return clampi(_phase_one(phases, "crouch"), 0, count - 1)
	var pop := float(ctx.get("pop_vy", POP_VY))
	var u := t / maxf(2.0 * pop / maxf(float(ctx.get("gravity", GRAVITY)), 0.1), 0.05)
	if vy < -0.75 * pop or u >= 0.85:
		return clampi(_phase_one(phases, "release"), 0, count - 1)
	if u < 0.15:
		return clampi(_phase_one(phases, "pop"), 0, count - 1)
	if u < 0.35:
		return clampi(_phase_one(phases, "reach"), 0, count - 1)
	var along := clampf((u - 0.35) / 0.5, 0.0, 0.999)
	return clampi(_phase_at(phases, "hold", along), 0, count - 1)

## Phase 1e puppet grab (melon): crouch winds down like the ollie crouch; in the air the frame follows the fraction of the
## ballistic airtime already flown (from vy, so a grab started mid-ollie joins at the right height): pop, rise, reach, hold,
## release. After touchdown the game plays the ollie land frames (trick "land").
func _puppet_grab_index(count: int, phases: Dictionary, ctx: Dictionary) -> int:
	var trick := str(ctx.get("trick", ""))
	if trick == "crouch":
		var low := _phase_one(phases, "crouch")
		var c := clampf(float(ctx.get("trick_time", 0.0)) / maxf(float(ctx.get("crouch_s", CROUCH_S)), 0.01), 0.0, 0.999)
		return clampi(int(c * float(low + 1)), 0, count - 1)
	var air := _phase_list(phases, "pop") + _phase_list(phases, "rise") + _phase_list(phases, "reach") + _phase_list(phases, "hold") + _phase_list(phases, "release")
	var pop := maxf(float(ctx.get("pop_vy", POP_VY)), 0.1)
	var u := clampf((pop - float(ctx.get("vy", 0.0))) / (2.0 * pop), 0.0, 0.999)
	# a grab pressed late in the air still shows the reach for a moment before the hold
	if float(ctx.get("trick_time", 0.0)) < 0.05 and u > 0.3:
		return clampi(_phase_one(phases, "reach"), 0, count - 1)
	# still holding the grab key: keep the hand on the board (touching down like this is a bail)
	var hold := _phase_list(phases, "hold")
	var first_release := air.size() - _phase_list(phases, "release").size()
	if bool(ctx.get("grab_held", false)) and int(u * float(air.size())) >= first_release and not hold.is_empty():
		return clampi(int(hold[hold.size() - 1]), 0, count - 1)
	return clampi(int(air[clampi(int(u * float(air.size())), 0, air.size() - 1)]), 0, count - 1)

## Phase 3 drop-in: commit frames by the commit clock; roll-out frames by the wall angle under him (drawn at 70..0 deg).
func _qp_dropin_index(count: int, ctx: Dictionary) -> int:
	var phases: Dictionary = _clip(clip).get("phases", {})
	var commit := _phase_list(phases, "commit")
	var roll := _phase_list(phases, "roll")
	var degs := _phase_list(phases, "roll_deg")
	if commit.is_empty() or roll.is_empty() or degs.size() != roll.size():
		return 0
	if str(ctx.get("qp", "")) == "commit":
		var i := clampi(int(float(ctx.get("qp_time", 0.0)) * _fps(clip) + 0.001), 0, commit.size() - 1)
		return clampi(int(commit[i]), 0, count - 1)
	var deg := float(ctx.get("ramp_deg", 0.0))
	var best := 0
	for j in degs.size():
		if absf(float(degs[j]) - deg) < absf(float(degs[best]) - deg):
			best = j
	return clampi(int(roll[best]), 0, count - 1)

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
