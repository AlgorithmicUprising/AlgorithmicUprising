extends CharacterBody3D

const TrickSelect = preload("res://scripts/trick_select.gd")
const BoostMeter = preload("res://scripts/boost_meter.gd")
const Spray = preload("res://scripts/spray.gd")
const SurfaceFriction = preload("res://scripts/surface_friction.gd")

const WALK_SPEED := 4.5
const SKATE_SPEED := 9.0
const JUMP_VELOCITY := 6.2
const GRAVITY := 18.0
# Phase 1a trick timing (LOCAL puppet test). Real ollies spend 0.36 +/- 0.09 s in the
# air; the puppet ollie clip has 0.42 s of board air. 3.8 m/s at 18 m/s^2 gives a
# 0.40 m apex and 0.42 s of air.
const OLLIE_CROUCH_S := 0.2
const OLLIE_POP_VELOCITY := 3.8
const FLIP_SPIN_S := 0.36
const LAND_S := 0.25
# Ignore the floor for this long after the pop so the launch tick never counts as a landing.
const AIR_GUARD_S := 0.1
# Phase 2 transition riding (LOCAL puppet test). On a quarter pipe ("quarter_pipe" group) the body rides the curve as one
# number: s = arc length up the profile, ramp_v = speed along it (+ = climbing). Gravity acts along the curve
# (a = -g sin(theta)), so he slows going up and speeds up coming down. Facing never follows velocity on the wall, so
# running out of speed rolls him back down fakie. Reaching the coping with speed launches him straight up (the lip is
# 70 deg; plan: "fake a vertical launch in code") with a small inward drift so he comes back down into the transition.
const RAMP_ROLL_DECEL := 0.35       # m/s^2 rolling resistance on the wall (flat skating keeps its own friction)
const PUMP_ACCEL := 3.0             # m/s^2 gained while pumping (stick held) on the lower transition
const PUMP_MAX_DEG := 50.0          # pumping works below this wall angle
const PUMP_MIN_SPEED := 0.8
const LIP_DRIFT := 0.6              # m/s back toward the flat at the lip launch
const RAMP_STEER_ACCEL := 3.0       # m/s^2 across the wall from the stick
const RAMP_STEER_MAX := 2.5
const RAMP_EDGE := 0.3              # leave the curve this close to the side of the pipe
const CAPSULE_R := 0.35             # player.tscn capsule: radius 0.35, lower sphere centre 0.675 m above the origin
const CAPSULE_LOW := 0.675

# Phase 3 quarter-pipe drop-in (LOCAL puppet test). Plan: stand on the deck within 0.5 m of the coping facing the ramp within
# 35 deg with the board in hand, press Shift: qp_setup sets the tail on the coping (S or Shift backs out). W commits: qp_dropin
# stomps the nose down; letting go of W (or pressing S) in the first 0.15 s of the commit is a bail (he falls back, then
# picks the board up with his left hand and returns to carrying it). After the commit he is placed on the transition with the board's centre 0.294 m below the coping and rides the
# Phase 2 curve physics down to the flat.
const QP_SPOT_MAX := 0.5            # m behind the coping
const QP_FACE_MAX_DEG := 35.0
const QP_STAND_BACK := 0.08         # qp_setup draws him 40 rig px behind the lip edge before he sets the board
const QP_APPROACH_S := 0.25         # slide / turn onto that mark over the first frames of qp_setup
const QP_SETUP_S := 23.0 / 24.0     # qp_setup: 23 frames at 24 fps (the last one = ready)
const QP_COMMIT_S := 8.0 / 24.0     # qp_dropin commit frames 0-8: the board tips -14 -> 70 deg over the coping
const QP_HESITATE_S := 0.15
const QP_ROLL_START_M := 0.2943     # board centre along the wall from the lip at the commit's last frame (tools/anim_qp.py)
const QP_ROLL_V0 := 1.2             # m/s down the wall as the front wheels land
const QP_BAIL_S := 36.0 / 24.0
const QP_KICKUP_S := 20.0 / 24.0    # puppet kickup clip length (rolling up to the coping: kick up, then set the board)
const KT_S := 15.0 / 24.0           # Phase 4 backside kickturn: qp_kickturn_bs clip, 15 frames at 24 fps (tools/anim_qp.py); the last (wheels down) shows one frame
const KT_PIVOT_UP := 0.255          # back truck (the pivot) along the wall above the rig origin
const KT_START_UP := 0.51           # board centre above the rig origin at frame 0 (origin = board centre at the last frame)
const KT_MIN_Y := 0.63              # the window opens this high up the transition (about 42 deg on the 2.4 m pipe)
const KT_LIP_GAP := 0.28            # ... and closes this far below the coping, so the drawn nose never pokes over it
const KT_MAX_V := 3.0               # slower than this along the wall (near the top of his line)
const KT_EXIT_V := 1.2              # m/s down the wall, rolling forward, as the front wheels set down
const KT_VARIANTS := [40, 50, 60]   # wall angles the clip is baked at (the lean is drawn); nearest is used
# turn (deg past the start heading) against clip time, from the tyaw keys in tools/anim_qp.py
const KT_TURN_KEYS := [[0.0, 0.0], [0.16, 6.0], [0.25, 52.0], [0.33, 110.0], [0.42, 162.0], [0.46, 180.0]]
const QP_RIDE_MAX := 1.5            # rolling slower than this at the spot: Shift kicks up and sets up
# Phase 3b: ease the spring-arm length so the pipe deck never snaps the camera in or out.
# Before the fix the arm stayed at 5.2 m through set-up and commit, then hit the deck mid-roll
# (5.20 -> 1.24 m in one frame) and popped back to 5.20 m on the flat. The close target sits
# just under that 1.24 m hit so the arm is already short when the deck crosses the ray.
const CAM_SPRING_DEFAULT := 5.2
const CAM_SPRING_QP := 1.20
const CAM_SPRING_SLEW := 2.8        # m/s, ~0.047 m per 60 fps tick

# Grind round (LOCAL, Nov 16 2026): frontside 50-50 on a flat bar or a ledge edge ("grind_rail" group, scripts/grind_rail.gd).
# Reference: Trick Dojo "How to 50-50 Grind", Skate Labs "50-50 Grind", Braille "How to Frontside 50-50 a Rail": approach close
# and nearly parallel at steady speed, ollie a little higher than the edge, land both trucks at once, weight centred, knees bent,
# board flat and parallel to the rail, roll off the end or pop out; too slow and the trucks catch.
# Lock: airborne, the board's contact point coming down through the rail top (GRIND_CATCH_UP above .. GRIND_CATCH_DOWN below),
# within GRIND_SNAP_R of the axis sideways, inside the rail. Then the approach decides: within GRIND_MAX_ANGLE of the axis and at
# least GRIND_MIN_SPEED along it locks a 50-50; anything else is a bail. On the rail the speed along it carries through, minus the
# rail's friction (and plus gravity along a down rail). Below GRIND_STALL_SPEED the trucks catch: bail. Off the end he rolls off
# with his speed; Q (ollie) or Space (jump) pops out with a small sideways drift back to the side he came from.
# Running into a rail below its top (on the ground or too low in the air) is a bail too ("clipped").
const GRIND_SNAP_R := 0.32          # m sideways from the axis (rail default; grind_rail.gd catch_r, ledges 0.5)
const GRIND_CATCH_UP := 0.12        # contact point at most this far above the top ...
const GRIND_CATCH_DOWN := 0.10      # ... or this far below it while coming down (one 60 Hz tick at 6 m/s is 0.1 m)
const GRIND_MAX_ANGLE := 25.0       # deg between the approach and the rail ("nearly parallel")
const GRIND_MIN_SPEED := 2.0        # m/s along the rail to lock
const GRIND_STALL_SPEED := 0.6      # m/s: the trucks catch and he falls off
const GRIND_END_MARGIN := 0.15      # m of rail needed past the lock point
const GRIND_SINK := 0.04            # wheel bottoms sit this far below the rail top (trucks' hangers on the bar)
const GRIND_POP_DRIFT := 0.9        # m/s sideways when popping out
const GRIND_LOCKOUT_S := 0.3
const GRIND_OUT_S := 4.0 / 24.0     # grind clip "out" frames shown at the start of a pop-out
const GRIND_IN_S := 4.0 / 24.0      # grind clip "in" frames (touchdown + absorb) before the hold loop
const GRIND_CLIP_R := 0.12          # m: inside this of the axis and below the top = ran into the rail
const GRIND_CLIP_DEPTH := 0.6       # ... unless the top is more than this above his contact point (riding under it)
# Finish pass (Nov 17 2026). Lock-in ease: the board used to jump straight onto the riding line on the lock tick (up to the
# catch radius sideways and the catch window up or down). Now the gap at the lock eases out over GRIND_SNAP_S (smoothstep).
const GRIND_DOWN_CATCH := 0.6      # extra catch height per unit of down-rail slope (0.4 slope -> 0.24 m more)
const GRIND_SNAP_S := 0.12
# Grinds on the rail. 50-50 by default; F (trick_grab) switches to a 5-0 (back truck, nose up), R (trick_flip) to a boardslide
# (deck across the bar); pressing the same key again goes back to the 50-50. References: The Trickonomicon "5-0", Hooked "Backside
# 5-0" (5-0s run faster than 50-50s), Skate Labs "Boardslide", Braille "How to Backside Boardslide" (the deck slides on the bar).
const GRIND_TRICKS := {
	"5050": {"name": "50-50", "friction": 1.0, "sink": 0.04},
	"5o": {"name": "5-0", "friction": 0.7, "sink": 0.04},
	# the deck sits on the bar: wheel bottoms hang 0.13 m under its top (puppet board deck_y 73.9 rig px at 502 px/m, minus the deck)
	"board": {"name": "BOARDSLIDE", "friction": 1.8, "sink": 0.13},
}
# Phase 5: backside air off the coping. F (trick_grab) in a lip air grabs the heel edge with the front hand and turns 180 backside
# (clockwise from above, like the Phase 4 kickturn); he lands forward. Tap F: the hand lets go at BSAIR_RELEASE_U of the air;
# hold F: he keeps the grab, and still holding it at re-entry is a bail (Phase 1e rule). References: MasterClass "How to Backside
# Air", sk8tricktip "Backside Air", Land The Trick "Melon": let go and extend only once the wheels clear the coping.
const BSAIR_START_MAX_U := 0.4      # the grab has to start in the first part of the air
const BSAIR_RISE_U := 0.15          # air fraction from the grab to the hand on the board (frames 0-3)
const BSAIR_RELEASE_U := 0.72       # the turn is done and the hand lets go here (frames 12-15 after it)
const BSAIR_MIN_AIR_S := 0.3        # predicted lip air shorter than this cannot fit the trick: the grab stays a plain grab

## M1 (Practice Run): every _event() and say() is also emitted here so the story layer (scripts/story/) can score
## tricks, feed the combo meter and track mission objectives without reaching into the physics. Free roam has no listener.
signal skate_event(what: String, info: Dictionary)
## M1 combo speed system: multipliers on the flat skate top speed and push acceleration, set every frame by the story
## layer from the combo meter (scripts/mission/combo_meter.gd). 1.0 = unchanged; free roam never changes them.
var combo_top_mult := 1.0
var combo_push_mult := 1.0
## Set when 1.1 hands the board back (upgrade_grip_tape). Off until then.
var grip_tape := false
## OPEN: how much the control-panel grip tape changes the board. Bearings quieter (less rolling
## resistance) and a firmer push. The story does not give a number.
const GRIP_TAPE_FRICTION_MULT := 0.82
const GRIP_TAPE_PUSH_MULT := 1.12
## M1 move gating: grind tricks (GRIND_TRICKS keys) that cannot be switched into yet (story mode locks 5-0 and boardslide).
var locked_grinds: Array = []
var skating := true
var input_enabled := true
var qp_state := ""                  # "" / setup / ready / commit / roll / bail / kickturn (Phase 4)
var kt_deg := 50                    # baked wall angle of the kickturn clip in use
var kt_origin_s := 0.0              # arc length of the rig origin (board centre at the last frame)
var kt_from_yaw := 0.0
var kt_to_yaw := 0.0
var kt_count := 0
var kt_last := {}                   # tests / probes: the last kickturn (entry, angles, timing, exit)
var qp_time := 0.0
var qp_reverse := false
var qp_pipe: Node3D = null
var qp_z := 0.0
var qp_from := Vector3.ZERO
var qp_to := Vector3.ZERO
var qp_from_yaw := 0.0
var qp_to_yaw := 0.0
var qp_pending := 0.0               # kick-up running before a set-up (rolling entry)
var qp_commit_msec := 0
var qp_exit_speed := 0.0
var qp_exit_s := 0.0                # seconds from the commit to rolling on the flat
var qp_runs := 0
var qp_elapsed := 0.0                # simulated seconds since the commit (commit + roll-out)
var _cam_arm_len := CAM_SPRING_DEFAULT
var camera_yaw := 0.0
var camera_pitch := -0.18
var grind = null
var grind_progress := 0.0
var grind_lockout := 0.0
var grind_along := 0.0              # m from the rail start along its axis
var grind_v := 0.0                  # m/s along the rail (+ = toward its end)
var grind_time := 0.0               # s since the lock
var grind_out_time := -1.0          # s since popping / rolling out (-1 = not just out); drives the clip's out frames
var grind_side := 0.0               # which side of the axis he came from (+1 / -1)
var grind_land_pending := false     # rolled off the end: the next touchdown plays the land frames
var grind_trick := "5050"
var grind_count := 0
var grind_last := {}                # tests / probes: the last grind or grind bail (trick, entry, distance, time, exit)
var grind_pop_side := Vector3.ZERO  # unit sideways drift held through a pop-out's air (cleared on touchdown)
var grind_left_rail = null          # the rail he just left: no re-lock onto it before touching down
var grind_snap := Vector3.ZERO      # lock-in offset still easing out (world m)
var grind_snap_t := 0.0             # s since that offset started easing
var grind_clip_t := 0.0             # s since the current grind trick started (drives that clip's in / hold frames)
var grind_tricks_done: Array = []   # the grinds of this rail visit, in order
var grind_switches := 0
# Trick name popup (scripts/trick_popup.gd reads these): callout_id bumps on every new name
var callout := ""
var callout_kind := ""              # trick / grind / bail
var callout_id := 0
var callout_log: Array = []
# Phase 5 backside air
var air_kind := ""                  # "lip" (off the coping) / "pop" (ollie or jump off the wall) while pipe_air
var air_time := 0.0                 # s since leaving the wall
var air_total := 0.0                # predicted lip air (s) back down to the take-off height
var bsair_u0 := 0.0                 # air fraction when the grab started
var bsair_release_u := -1.0         # air fraction when the hand let go (-1 = still on the board)
var bsair_from_yaw := 0.0
var bsair_count := 0
var bsair_last := {}
var _grind_prev := {}               # rail -> last lateral offset (crossing check)
var external_move := Vector2.ZERO
var external_move_active := false
var external_jump := false
var external_camera_yaw_delta := 0.0
var look_captured := false
var look_sensitivity := 0.0028
var look_invert_y := true
var look_invert_x := false
var stick_invert_y := false
var look_invert_chosen := false
var pad_menu := false
var boost = null
var spray_cool := 0.0
var spray_puff: Node3D
var spray_puff_t := 0.0
var _boost_was := false
var _mouse_pending := Vector2.ZERO
var spawn_position := Vector3.ZERO
var spawn_yaw := 0.0
## Last grounded spot inside the playable volumes. A kill-plane fall or a step off the map returns here.
var last_safe_position := Vector3.ZERO
var last_safe_yaw := 0.0
var last_safe_valid := false
var bounds_enabled := true
var bowl_xz := Vector3.ZERO         # surface point the bowl rider integrates (the body origin sits off it)
var bowl_theta := 0.0
var rig: Node3D
var painted_sprite: Node3D
var use_painted_sprite := true
var wish_len := 0.0
var sprite_frame := ""
# Phase 2 transition state
var ramp: Node3D = null
var ramp_mode := ""                 # "" = flat physics, "ride" = quarter pipe, "bowl" = the yard pool (same curve step)
var ramp_s := 0.0
var ramp_v := 0.0
var ramp_z := 0.0
var ramp_vz := 0.0
var pipe_air := false               # airborne after leaving the curve: ballistic, no air steering
var pipe_air_pipe: Node3D = null
var pumping := false
var ramp_lean_up := Vector3.UP      # card up for the sprite (surface normal on the wall, eases back to vertical in the air)
var ramp_events: Array = []         # [{"t": msec, "what": ..., ...}] for tests and captures
var ramp_entry_speed := 0.0
var ramp_peak_y := 0.0              # highest riding-surface point of this visit (pipe local y, m)
var air_peak_above_lip := 0.0
var lip_launch_speed := 0.0
var last_landing := ""              # "transition" / "deck" / "flat" after a pipe air
var _reentry := false
var air_from_y := 0.0
var air_anchor := Vector3.ZERO      # sprite anchor offset held through a pipe air (the contact point at take-off)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(76.0)
	camera_yaw = rotation.y
	_load_look()
	boost = BoostMeter.new()
	spawn_position = global_position
	spawn_yaw = rotation.y
	last_safe_position = spawn_position
	last_safe_yaw = spawn_yaw
	last_safe_valid = true
	_style_body()
	_update_camera(0.0)

func _style_body() -> void:
	if has_node("Body"):
		$Body.visible = false
	if has_node("Board"):
		$Board.visible = false
	rig = load("res://scripts/fony_rig.gd").new()
	add_child(rig)
	painted_sprite = load("res://scripts/fony_sprite.gd").new()
	painted_sprite.name = "FonySprite"
	add_child(painted_sprite)
	_apply_painted_sprite()
	var label := Label3D.new()
	label.name = "NameLabel"
	label.text = "FONY"
	label.position = Vector3(0, 2.05, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.0035
	label.modulate = Color("fff8ef")
	label.outline_size = 6
	add_child(label)

func update_board() -> void:
	pass

func set_painted_sprite(enabled: bool) -> void:
	use_painted_sprite = enabled
	_apply_painted_sprite()

func _apply_painted_sprite() -> void:
	if rig != null:
		rig.visible = not use_painted_sprite
	if painted_sprite != null:
		painted_sprite.visible = use_painted_sprite

func push_mouse_look(relative: Vector2) -> void:
	if not look_captured or not input_enabled or external_move_active:
		return
	if get_tree() != null and get_tree().paused:
		return
	var vertical := -relative.y if look_invert_y else relative.y
	var horizontal := -relative.x if look_invert_x else relative.x
	_mouse_pending += Vector2(horizontal, vertical)

func clear_mouse_look() -> void:
	_mouse_pending = Vector2.ZERO

func adjust_look_sensitivity(step: float) -> void:
	look_sensitivity = clampf(look_sensitivity + step, 0.0008, 0.008)
	_save_look()

func choose_invert_y(value: bool) -> void:
	look_invert_y = value
	look_invert_chosen = true
	_save_look()

func choose_invert_x(value: bool) -> void:
	look_invert_x = value
	_save_look()

func choose_stick_invert_y(value: bool) -> void:
	stick_invert_y = value
	_save_look()

func camera_flat_forward() -> Vector3:
	return _camera_flat_axes()[0]

func camera_flat_right() -> Vector3:
	return _camera_flat_axes()[1]

func _camera_flat_axes() -> Array:
	var fallback_forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var cam := get_node_or_null("CameraPivot/SpringArm/Camera") as Camera3D
	if cam == null:
		return [fallback_forward, Vector3(fallback_forward.z, 0.0, -fallback_forward.x)]
	var basis := cam.global_transform.basis
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z)
	var right := Vector3(basis.x.x, 0.0, basis.x.z)
	if forward.length() < 0.001:
		forward = fallback_forward
	else:
		forward = forward.normalized()
	if right.length() < 0.001:
		right = Vector3(forward.z, 0.0, -forward.x)
	else:
		right = right.normalized()
	return [forward, right]

func _load_look() -> void:
	var text := FileAccess.get_file_as_string("user://au-look-v1.json") if FileAccess.file_exists("user://au-look-v1.json") else ""
	var parsed = JSON.parse_string(text) if text.strip_edges() != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if parsed.has("sensitivity"):
		look_sensitivity = clampf(float(parsed.get("sensitivity", look_sensitivity)), 0.0008, 0.008)
	# Older saves wrote invert_y false as the implicit default. That is not a choice.
	if bool(parsed.get("invert_chosen", false)):
		look_invert_y = bool(parsed.get("invert_y", true))
		look_invert_chosen = true
	look_invert_x = bool(parsed.get("invert_x", false))
	stick_invert_y = bool(parsed.get("stick_invert_y", false))
	if parsed.has("stick_look"):
		InputBindings.stick_look = clampf(float(parsed.get("stick_look", 1.0)), 0.4, 2.2)

func _save_look() -> void:
	var file := FileAccess.open("user://au-look-v1.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"sensitivity": look_sensitivity,
		"invert_y": look_invert_y,
		"invert_x": look_invert_x,
		"stick_invert_y": stick_invert_y,
		"invert_chosen": look_invert_chosen,
		"stick_look": InputBindings.stick_look,
	}))

func respawn() -> void:
	velocity = Vector3.ZERO
	grind = null
	grind_lockout = 0.2
	grind_out_time = -1.0
	grind_land_pending = false
	grind_pop_side = Vector3.ZERO
	grind_left_rail = null
	ramp_mode = ""
	ramp = null
	pipe_air = false
	pipe_air_pipe = null
	qp_state = ""
	qp_pending = 0.0
	_cam_arm_len = CAM_SPRING_DEFAULT
	global_position = spawn_position
	rotation.y = spawn_yaw
	camera_yaw = spawn_yaw
	last_safe_position = spawn_position
	last_safe_yaw = spawn_yaw
	last_safe_valid = true
	bowl_xz = spawn_position

## Lock onto `rail` at `along` (0..1, older callers) with the current velocity; grind_check() is the normal way in.
func begin_grind(rail, along: float) -> void:
	_grind_lock(rail, along * float(rail.length), "direct")

func _physics_process(delta: float) -> void:
	if qp_state == "commit" or qp_state == "roll":
		qp_elapsed += delta
	if boost != null:
		boost.tick(delta)
	spray_cool = maxf(0.0, spray_cool - delta)
	_tick_spray_puff(delta)
	_simulate(delta)
	_keep_in_bounds()
	_pose(delta)

func start_visual_demo(kind: String) -> void:
	visual_demo = kind
	demo_clock = 0.0
	external_move_active = true
	external_move = Vector2.ZERO
	skating = true
	input_enabled = true
	Engine.time_scale = 0.5
	var label := get_node_or_null("NameLabel")
	if label != null:
		label.visible = false
	demo_cam = Camera3D.new()
	demo_cam.name = "DemoCam"
	demo_cam.fov = 40.0
	demo_cam.current = true
	get_parent().add_child(demo_cam)
	if kind == "ramp":
		global_position = Vector3(-51.4, 0.45, -12.0)
		velocity = Vector3.ZERO
		rotation.y = 0.0
		camera_yaw = PI * 0.5
	elif DEMO_LINES.has(kind):
		var line: Dictionary = DEMO_LINES[kind]
		global_position = line.start
		velocity = line.dir * float(line.speed)
		demo_switched = false
		if rig != null:
			rig.face_world(atan2(-line.dir.x, -line.dir.z))

func _demo_drive(delta: float) -> void:
	if visual_demo == "" or demo_cam == null or rig == null:
		return
	demo_clock += delta
	var focus := rig.global_position + Vector3(0, 0.85, 0)
	if DEMO_LINES.has(visual_demo):
		_demo_line(DEMO_LINES[visual_demo], focus)
	elif visual_demo == "ramp":
		demo_cam.global_position = global_position + Vector3(3.2, 1.5, 4.2)
		external_move = Vector2(0, 1)
		if trick == "" and is_on_floor() and global_position.y > 1.05 and demo_clock > 0.35:
			request_trick("ollie")
	else:
		var side: Vector3 = rig.global_transform.basis.x
		demo_cam.global_position = focus + side * 3.15 + Vector3(0, 0.2, 0)
		external_move = Vector2(0, 0.4)
		if trick == "" and demo_clock > 0.4 and demo_clock < 0.55:
			request_trick(visual_demo)
	demo_cam.look_at(focus)

func _simulate(delta: float) -> void:
	_demo_drive(delta)
	if grind_lockout > 0.0:
		grind_lockout = max(0.0, grind_lockout - delta)
	if input_enabled:
		_update_camera(delta)
	if not input_enabled:
		if grind != null:
			grind = null
		_fall(delta)
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		move_and_slide()
		return
	if grind != null:
		_step_grind(delta)
		return
	if _qp_step(delta):
		return
	if ramp_mode == "ride":
		_ramp_step(delta)
		return
	if ramp_mode == "bowl":
		_bowl_step(delta)
		return
	var jumping := _wants_jump()
	external_jump = false
	if is_on_floor() and jumping:
		velocity.y = JUMP_VELOCITY
	else:
		_fall(delta)
	_tricks(delta)
	var wish := _wish()
	wish_len = wish.length()
	var speed := SKATE_SPEED * combo_top_mult if skating else WALK_SPEED
	var accel := 22.0 * combo_push_mult if skating else 40.0
	var friction := 7.0 if skating else 30.0
	if grip_tape and skating:
		accel *= GRIP_TAPE_PUSH_MULT
		friction *= GRIP_TAPE_FRICTION_MULT
	if is_on_floor():
		friction *= SurfaceFriction.at(get_tree(), global_position)
	if input_enabled and not external_move_active and not pad_menu:
		var push := Input.get_action_strength("push") if InputMap.has_action("push") else 0.0
		var brake := Input.get_action_strength("brake") if InputMap.has_action("brake") else 0.0
		if skating and push > 0.0:
			accel *= 1.0 + 0.35 * push
		if brake > 0.0:
			friction *= 1.0 + 2.2 * brake
		var power := 0.0
		if boost != null and skating:
			power = boost.spend(delta, Input.is_action_pressed("boost"))
			speed *= boost.speed_mult(power)
		if power > 0.0 and not _boost_was:
			InputBindings.rumble(0.25, 0.55, 0.12)
		_boost_was = power > 0.0
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if pipe_air:
		pass    # Phase 2: off the curve he flies ballistic; no air steering, no turning to the stick
	elif wish.length() < 0.01:
		horizontal = horizontal.move_toward(Vector3.ZERO, friction * delta)
	else:
		horizontal = horizontal.move_toward(Vector3(wish.x, 0.0, wish.z) * speed, accel * delta)
		if rig != null and rig.has_method("face_world"):
			rig.face_world(atan2(-wish.x, -wish.z))
	if grind_pop_side != Vector3.ZERO:
		# popping out of a grind: the sideways drift off the rail survives the air steering until touchdown
		var lat := horizontal.dot(grind_pop_side)
		if lat < GRIND_POP_DRIFT:
			horizontal += grind_pop_side * (GRIND_POP_DRIFT - lat)
		if is_on_floor() and velocity.y <= 0.0:
			grind_pop_side = Vector3.ZERO
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var was_air := pipe_air
	if pipe_air:
		air_time += delta
	move_and_slide()
	if pipe_air:
		# the board left the wall at air_from_y (body height at take-off): the rise since then is the board's height above
		# the point it left (the coping, for a lip launch)
		air_peak_above_lip = maxf(air_peak_above_lip, global_position.y - air_from_y)
	if pipe_air:
		ramp_lean_up = ramp_lean_up.slerp(Vector3.UP, clampf(delta * 6.0, 0.0, 1.0)).normalized()
	else:
		ramp_lean_up = Vector3.UP
	if is_on_floor():
		if was_air:
			_pipe_air_landed()
		_try_bowl_entry()
		if grind_land_pending:
			grind_land_pending = false
			if trick == "":
				trick = "land"
				trick_time = 0.0
		_try_ramp_entry()
	if grind_out_time >= 0.0:
		grind_out_time += delta
		if grind_out_time > GRIND_OUT_S:
			grind_out_time = -1.0
	_try_grind()
	update_board()

func _fall(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.2
	else:
		velocity.y -= GRAVITY * delta

func _wish() -> Vector3:
	var move := external_move if external_move_active else _hardware_move()
	var axes := _camera_flat_axes()
	var forward: Vector3 = axes[0]
	var right: Vector3 = axes[1]
	var wish := right * move.x + forward * move.y
	if wish.length() > 1.0:
		wish = wish.normalized()
	return wish

func _wants_jump() -> bool:
	return external_jump or (not external_move_active and not pad_menu and Input.is_action_just_pressed("jump"))

func _hardware_move() -> Vector2:
	var vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return Vector2(InputBindings.curve(vector.x), -InputBindings.curve(vector.y))

func _update_camera(delta: float) -> void:
	camera_yaw += external_camera_yaw_delta
	external_camera_yaw_delta = 0.0
	if not external_move_active:
		var stick_right := InputBindings.curve(Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left"))
		var stick_down := InputBindings.curve(Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up"))
		var yaw_sign := -1.0 if look_invert_x else 1.0
		var pitch_sign := -1.0 if stick_invert_y else 1.0
		camera_yaw -= stick_right * 1.7 * InputBindings.stick_look * yaw_sign * delta
		camera_pitch += stick_down * 1.0 * InputBindings.stick_look * pitch_sign * delta
		camera_yaw -= _mouse_pending.x * look_sensitivity
		camera_pitch += _mouse_pending.y * look_sensitivity
	_mouse_pending = Vector2.ZERO
	camera_pitch = clampf(camera_pitch, -0.95, 0.5)
	if has_node("CameraPivot"):
		$CameraPivot.rotation.y = camera_yaw
		if has_node("CameraPivot/SpringArm"):
			$CameraPivot/SpringArm.rotation.x = camera_pitch
			_update_cam_arm(delta)

## Metres from the camera pivot to the game camera (tests / probes: spring-arm smoothness).
func camera_distance() -> float:
	if not has_node("CameraPivot/SpringArm/Camera"):
		return 0.0
	return $CameraPivot/SpringArm/Camera.global_position.distance_to($CameraPivot.global_position)

## True while a drop-in or a walk-in on the pipe deck should keep the camera close.
func _cam_qp_close() -> bool:
	if qp_state == "setup" or qp_state == "ready" or qp_state == "commit" or qp_state == "bail" or qp_state == "roll":
		return true
	return _on_qp_deck()

## Standing on a quarter-pipe deck (walk-in before Shift, or after a bail / back-out).
func _on_qp_deck() -> bool:
	if not is_on_floor() or ramp_mode != "" or pipe_air:
		return false
	if not is_inside_tree():
		return false
	for pipe in get_tree().get_nodes_in_group("quarter_pipe"):
		if not pipe.has_method("lip_local"):
			continue
		var c: Vector3 = pipe.to_local(global_position + Vector3.UP * 0.325)
		var lip: Vector3 = pipe.lip_local()
		if absf(c.y - lip.y) > 0.2:
			continue
		if c.x < lip.x - 0.05 or c.x > lip.x + pipe.deck_length:
			continue
		if absf(c.z) > pipe.half_width():
			continue
		return true
	return false

func _cam_hit_length() -> float:
	var pivot: Node3D = $CameraPivot
	var arm: SpringArm3D = $CameraPivot/SpringArm
	var space := get_world_3d().direct_space_state
	if space == null:
		return CAM_SPRING_DEFAULT
	var from: Vector3 = pivot.global_position
	var dir: Vector3 = -arm.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * CAM_SPRING_DEFAULT, 1)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return CAM_SPRING_DEFAULT
	return maxf(arm.margin, from.distance_to(hit.position) - arm.margin)

func _update_cam_arm(delta: float) -> void:
	var arm: SpringArm3D = $CameraPivot/SpringArm
	var target := CAM_SPRING_QP if _cam_qp_close() else CAM_SPRING_DEFAULT
	var hit := _cam_hit_length()
	var goal: float = minf(target, hit)
	if delta <= 0.0:
		_cam_arm_len = goal
	else:
		_cam_arm_len = move_toward(_cam_arm_len, goal, CAM_SPRING_SLEW * delta)
	# never sit longer than the collision hit (that would put the camera in the deck)
	if _cam_arm_len > hit:
		_cam_arm_len = hit
	arm.spring_length = _cam_arm_len

func _try_grind() -> void:
	if grind != null or grind_lockout > 0.0 or not skating or bail_time > 0.0 or ramp_mode != "" or qp_state != "":
		_grind_prev.clear()
		return
	if not is_inside_tree():
		return
	if grind_left_rail != null and is_on_floor():
		grind_left_rail = null
	for node in get_tree().get_nodes_in_group("grind_rail"):
		if not node.has_method("locate") or node == grind_left_rail:
			continue
		var verdict := grind_check(node)
		if verdict == "lock" or verdict.begins_with("bail"):
			return

## One rail against the body this tick: "" (nothing), "lock" (now grinding), or "bail:<reason>" (now bailing).
func grind_check(rail) -> String:
	var contact := global_position + Vector3.UP * 0.325
	var at: Dictionary = rail.locate(contact)
	var along := float(at.along)
	var lateral := float(at.lateral)
	var above := float(at.above)
	var length := float(rail.length)
	var prev = _grind_prev.get(rail, null)
	_grind_prev[rail] = lateral
	if along < 0.0 or along > length:
		return ""
	# ran into a rail below its top: lateral crossing this tick (or riding along inside it) with the board under the top
	if str(rail.kind) == "rail" and above < -0.05 and above > -GRIND_CLIP_DEPTH and Vector2(velocity.x, velocity.z).length() > 1.0:
		var crossed: bool = prev != null and signf(float(prev)) != signf(lateral) and absf(float(prev)) < 0.6
		if absf(lateral) < GRIND_CLIP_R or crossed:
			_grind_bail(rail, "clipped", along, lateral)
			return "bail:clipped"
	if is_on_floor():
		return ""
	# a down rail falls away under an ollie's arc (at 9 m/s a 0.4 slope drops 3.6 m/s), so it catches from higher up; the lock
	# then eases him down onto it (GRIND_SNAP_S) instead of a pop
	var up_window: float = GRIND_CATCH_UP + GRIND_DOWN_CATCH * absf(float(rail.drop)) / maxf(length, 0.001)
	var catch_r: float = float(rail.catch_r)
	if _grind_held():
		catch_r += 0.45
		up_window += 0.25
	if absf(lateral) > catch_r or above > up_window or above < -GRIND_CATCH_DOWN or velocity.y > 0.5:
		return ""
	if along < GRIND_END_MARGIN * 0.5 or along > length - GRIND_END_MARGIN:
		return ""
	var flat_dir: Vector3 = Vector3(rail.direction.x, 0.0, rail.direction.z).normalized()
	var vh := Vector3(velocity.x, 0.0, velocity.z)
	var along_v := vh.dot(flat_dir)
	var angle := rad_to_deg(acos(clampf(absf(along_v) / maxf(vh.length(), 0.001), 0.0, 1.0))) if vh.length() > 0.05 else 90.0
	if angle > GRIND_MAX_ANGLE:
		_grind_bail(rail, "bad_angle", along, lateral, angle)
		return "bail:bad_angle"
	if absf(along_v) < GRIND_MIN_SPEED:
		_grind_bail(rail, "too_slow", along, lateral, angle)
		return "bail:too_slow"
	# a trick still going wrong in the air lands on the rail as badly as on the ground
	if trick == "flip" and not board_caught:
		_grind_bail(rail, "flip_not_caught", along, lateral, angle)
		return "bail:flip_not_caught"
	if trick == "grab" and _grab_held():
		_grind_bail(rail, "grab_held", along, lateral, angle)
		return "bail:grab_held"
	grind_side = signf(lateral) if absf(lateral) > 0.01 else 1.0
	_grind_lock(rail, along, "ollie" if trick != "" else "air", angle)
	return "lock"

func _grind_lock(rail, along_m: float, how: String, angle := 0.0) -> void:
	var flat_dir: Vector3 = Vector3(rail.direction.x, 0.0, rail.direction.z).normalized()
	grind = rail
	grind_along = clampf(along_m, 0.0, float(rail.length))
	grind_progress = grind_along / float(rail.length)
	grind_v = Vector3(velocity.x, 0.0, velocity.z).dot(flat_dir)
	if absf(grind_v) < 0.01:
		grind_v = float(rail.speed)
	grind_time = 0.0
	grind_out_time = -1.0
	grind_land_pending = false
	grind_pop_side = Vector3.ZERO
	trick = ""
	trick_next = ""
	trick_time = 0.0
	board_caught = true
	grind_trick = "5050"
	grind_clip_t = 0.0
	grind_tricks_done = ["5050"]
	grind_switches = 0
	grind_count += 1
	grind_last = {"trick": grind_trick, "rail": str(rail.name), "kind": str(rail.kind), "entry_speed": absf(grind_v),
		"angle_deg": angle, "start_along": grind_along, "how": how, "msec": Time.get_ticks_msec()}
	_event("grind_lock", {"rail": str(rail.name), "speed": absf(grind_v), "angle": angle})
	_note_boost_trick()
	InputBindings.rumble(0.35, 0.55, 0.08)
	var before := global_position
	grind_snap = Vector3.ZERO
	grind_snap_t = 0.0
	_grind_place()
	# start from where he really was and ease onto the riding line (no pop on the lock tick)
	grind_snap = before - global_position
	global_position = before
	say(GRIND_TRICKS[grind_trick].name, "grind")

## Board on the riding line, facing the way he travels.
func _grind_place() -> void:
	var rail = grind
	var sink := float(GRIND_TRICKS.get(grind_trick, GRIND_TRICKS["5050"]).sink)
	global_position = rail.line_point(grind_along) + Vector3.UP * (-0.325 - sink) + grind_snap_left()
	var dir: Vector3 = rail.line_dir() * signf(grind_v if absf(grind_v) > 0.001 else 1.0)
	velocity = dir * absf(grind_v)
	if rig != null and rig.has_method("face_world"):
		rig.face_world(atan2(-dir.x, -dir.z))

func _step_grind(delta: float) -> void:
	var rail = grind
	if rail == null or not is_instance_valid(rail):
		grind = null
		return
	var jumping := _wants_jump()
	external_jump = false
	var popping := trick_request == "ollie"
	var asked := trick_request
	trick_request = ""
	wish_len = 0.0
	if jumping or popping:
		_leave_grind(true, JUMP_VELOCITY if jumping else OLLIE_POP_VELOCITY)
		return
	if asked == "grab" or asked == "flip":
		var want := "5o" if asked == "grab" else "board"
		set_grind_trick("5050" if grind_trick == want else want)
	elif asked == "" and not external_move_active and not pad_menu and Input.is_action_just_pressed("trick"):
		_apply_trick_button()
	grind_time += delta
	grind_clip_t += delta
	grind_snap_t += delta
	# rolling resistance against the travel, gravity along a down rail
	var slope_a: float = GRAVITY * float(rail.drop) / maxf(float(rail.length), 0.001)
	grind_v += slope_a * delta
	grind_v = move_toward(grind_v, 0.0, float(rail.friction) * float(GRIND_TRICKS[grind_trick].friction) * delta)
	if absf(grind_v) < GRIND_STALL_SPEED:
		_grind_bail(rail, "stalled", grind_along, grind_side * 0.2)
		return
	grind_along += grind_v * delta
	grind_progress = grind_along / float(rail.length)
	if grind_along >= float(rail.length) or grind_along <= 0.0:
		grind_along = clampf(grind_along, 0.0, float(rail.length))
		_leave_grind(false)
		return
	_grind_place()

## Lock-in / switch offset not yet eased out (world m).
func grind_snap_left() -> Vector3:
	if grind_snap == Vector3.ZERO or grind_snap_t >= GRIND_SNAP_S:
		return Vector3.ZERO
	return grind_snap * (1.0 - smoothstep(0.0, 1.0, grind_snap_t / GRIND_SNAP_S))

## Switch grinds on the rail ("5050" / "5o" / "board"): the new clip plays its lock-in frames, the board's height on the bar follows.
func set_grind_trick(kind: String) -> void:
	if grind == null or not GRIND_TRICKS.has(kind) or kind == grind_trick or locked_grinds.has(kind):
		return
	var old_sink := float(GRIND_TRICKS[grind_trick].sink)
	grind_trick = kind
	grind_clip_t = 0.0
	grind_switches += 1
	grind_tricks_done.append(kind)
	grind_last["trick"] = kind
	grind_last["tricks"] = grind_tricks_done.duplicate()
	# ease the height change too (a boardslide sits lower on the bar than the trucks)
	grind_snap = grind_snap_left() + Vector3.UP * (float(GRIND_TRICKS[kind].sink) - old_sink)
	grind_snap_t = 0.0
	_event("grind_switch", {"trick": kind})
	say(GRIND_TRICKS[kind].name, "grind")

## Name a trick on screen (scripts/trick_popup.gd). kind: trick / grind / bail.
func say(text: String, kind := "trick") -> void:
	callout = text
	callout_kind = kind
	callout_id += 1
	callout_log.append(text)
	if callout_log.size() > 32:
		callout_log.pop_front()
	skate_event.emit("callout", {"text": text, "kind": kind})

## Off the rail: popped (Q / Space) or rolled off the end.
func _leave_grind(jumped: bool, pop := JUMP_VELOCITY) -> void:
	var rail = grind
	var dir: Vector3 = rail.line_dir() * signf(grind_v if absf(grind_v) > 0.001 else 1.0)
	var speed := absf(grind_v)
	grind = null
	grind_lockout = GRIND_LOCKOUT_S
	grind_left_rail = rail
	_grind_prev.clear()
	grind_last["time"] = grind_time
	grind_last["distance"] = absf(grind_along - float(grind_last.get("start_along", 0.0)))
	grind_last["exit_speed"] = speed
	grind_last["tricks"] = grind_tricks_done.duplicate()
	grind_snap = Vector3.ZERO
	var names: Array = []
	for t in grind_tricks_done:
		if names.is_empty() or names[names.size() - 1] != GRIND_TRICKS[t].name:
			names.append(GRIND_TRICKS[t].name)
	say("%s  %.1f M" % [" + ".join(names), float(grind_last["distance"])], "grind")
	if jumped:
		var side: Vector3 = rail.locate(global_position).side
		var flat := Vector3(dir.x, 0.0, dir.z)
		velocity = flat * speed + side * (grind_side * GRIND_POP_DRIFT) + Vector3.UP * pop
		grind_pop_side = side * grind_side
		global_position += Vector3.UP * 0.05
		grind_out_time = 0.0
		board_caught = true
		if pop == OLLIE_POP_VELOCITY:
			trick = "ollie"         # Q: an ollie out; lands through _finish_trick like any ollie
			trick_time = 0.0
		else:
			trick = ""              # Space: the plain jump (frames follow the velocity), lands with the land frames
			grind_land_pending = true
		grind_last["exit"] = "pop"
		_event("grind_pop", {"speed": speed})
	else:
		global_position = rail.line_point(grind_along) + Vector3.UP * (-0.325 + 0.02) + Vector3(dir.x, 0.0, dir.z) * 0.05
		velocity = dir * speed
		velocity.y = minf(velocity.y, 0.0)
		grind_out_time = 0.0
		grind_land_pending = true
		grind_last["exit"] = "end"
		_event("grind_end", {"speed": speed})
		if boost != null:
			boost.note_grind(float(grind_last.get("distance", 0.0)))

## Bad approach, a stall, or running into the rail: same bail as a bad landing (Phase 1e), he ends up beside the rail.
func _grind_bail(rail, reason: String, along: float, lateral: float, angle := -1.0) -> void:
	var was_on := grind != null
	grind = null
	grind_lockout = 0.6
	_grind_prev.clear()
	grind_out_time = -1.0
	grind_land_pending = false
	last_bail_reason = "grind_" + reason
	trick = "bail"
	trick_time = 0.0
	bail_time = 0.6
	skating = false
	var side: Vector3 = rail.locate(global_position).side
	var s := signf(lateral) if absf(lateral) > 0.01 else 1.0
	if was_on:
		# fall off the side he came from, onto the ground beside the rail
		global_position = rail.line_point(along) + side * (s * 0.45) + Vector3.UP * (-0.325)
	elif str(rail.kind) == "rail" and absf(lateral) < 0.45:
		# hit it: knocked back out to the side he came from (never left standing inside the bar)
		global_position += side * (s * 0.45 - lateral)
	velocity.x *= 0.35
	velocity.z *= 0.35
	velocity += side * (s * 1.2)
	velocity.y = minf(velocity.y, 0.0)
	grind_last = {"trick": "bail", "reason": reason, "rail": str(rail.name), "angle_deg": angle, "along": along,
		"was_grinding": was_on, "msec": Time.get_ticks_msec()}
	grind_snap = Vector3.ZERO
	_event("grind_bail", {"reason": reason, "angle": angle})
	if boost != null:
		boost.note_bail()
	InputBindings.rumble(0.85, 0.4, 0.16)
	say("BAIL!", "bail")

var trick := ""
var trick_time := 0.0
var trick_next := ""
var flip_turns := 0.0
var board_caught := true
var bail_time := 0.0
## Phase 1e (LOCAL puppet test): a grab still held at touchdown is a bail (plan: "still grabbing at touchdown: bail").
## Scripted tests set grab_hold instead of holding the key.
var grab_hold := false
var last_bail_reason := ""
var trick_request := ""
var visual_demo := ""
var demo_clock := 0.0
var demo_cam: Camera3D

func _input(event: InputEvent) -> void:
	InputBindings.note(event)
	if event.is_action_pressed("spray") and look_captured and input_enabled and not pad_menu and not external_move_active:
		try_spray()

func request_trick(kind: String) -> void:
	trick_request = kind

func _trick_context() -> String:
	if grind != null:
		return "grind"
	if ramp_mode == "ride" or ramp_mode == "bowl" or (qp_state != "" and qp_state != "roll"):
		return "ramp"
	if not is_on_floor() or pipe_air:
		return "air"
	return "flat"

## The one trick button. On a rail it picks the grind for this tier. Everywhere else it returns
## ollie / flip / grab for the existing trick starter. A backside air fires itself.
func _apply_trick_button() -> String:
	var chain: int = boost.chain if boost != null else 0
	var picked: String = TrickSelect.pick(_trick_context(), chain)
	if grind != null:
		if picked in ["5050", "5o", "board"]:
			var before := grind_trick
			set_grind_trick(picked)
			if grind_trick != before:
				_note_boost_trick()
		return ""
	if picked == "bs_air":
		if bsair_ready():
			_bsair_begin()
			return ""
		return "grab"
	return picked

func _note_boost_trick() -> void:
	if boost == null:
		return
	boost.note_trick(TrickSelect.tier_for(boost.chain))

func try_spray() -> int:
	if spray_cool > 0.0 or get_tree() == null:
		return 0
	spray_cool = Spray.COOLDOWN_S
	var origin := global_position + Vector3.UP * 1.15
	var dir := camera_flat_forward()
	var cam := get_node_or_null("CameraPivot/SpringArm/Camera") as Camera3D
	if cam != null:
		dir = -cam.global_transform.basis.z
	var hits := Spray.fire(get_tree(), origin, dir)
	_spray_puff(origin + dir.normalized() * 1.1)
	if hits > 0:
		InputBindings.rumble(0.15, 0.4, 0.08)
	return hits

func _spray_puff(at: Vector3) -> void:
	if spray_puff != null and is_instance_valid(spray_puff):
		spray_puff.queue_free()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(Spray.color(), 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inst.material_override = mat
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(inst)
	inst.global_position = at
	spray_puff = inst
	spray_puff_t = 0.22

func _tick_spray_puff(delta: float) -> void:
	if spray_puff == null or not is_instance_valid(spray_puff):
		return
	spray_puff_t -= delta
	var mat := spray_puff.material_override as StandardMaterial3D
	if mat != null:
		var c := mat.albedo_color
		c.a = clampf(spray_puff_t / 0.22, 0.0, 0.85)
		mat.albedo_color = c
	if spray_puff_t <= 0.0:
		spray_puff.queue_free()
		spray_puff = null

func _grind_held() -> bool:
	return not external_move_active and not pad_menu and InputMap.has_action("grind") and Input.is_action_pressed("grind")

func _tricks(delta: float) -> void:
	if bail_time > 0.0:
		bail_time = maxf(0.0, bail_time - delta)
		trick = "bail"
		if bail_time <= 0.0 and is_on_floor():
			trick = ""
			board_caught = true
			skating = true
		_push_trick()
		return
	var asked := trick_request
	trick_request = ""
	if asked == "" and not external_move_active and not pad_menu and Input.is_action_just_pressed("trick"):
		asked = _apply_trick_button()
	if asked == "ollie" and is_on_floor() and skating and trick == "":
		trick = "crouch"
		trick_next = "ollie"
		trick_time = 0.0
	elif asked == "flip" and skating and (trick == "" or trick == "ollie" or trick == "crouch"):
		if is_on_floor() and trick == "":
			trick = "crouch"
			trick_next = "flip"
			trick_time = 0.0
		else:
			_start_air("flip")
	elif asked == "grab" and skating and trick != "bail":
		if is_on_floor() and trick == "":
			trick = "crouch"
			trick_next = "grab"
			trick_time = 0.0
		elif not is_on_floor() and bsair_ready():
			_bsair_begin()
		elif not is_on_floor():
			trick = "grab"
			board_caught = true
			trick_time = 0.0
			say("MELON")
	if trick == "crouch":
		trick_time += delta
		if trick_time >= OLLIE_CROUCH_S:
			_start_air(trick_next if trick_next != "" else "ollie")
	elif trick == "ollie" or trick == "flip" or trick == "grab":
		trick_time += delta
		if trick == "flip" and not board_caught:
			flip_turns += delta / FLIP_SPIN_S
			if flip_turns >= 0.99:
				board_caught = true
				flip_turns = 1.0
		if is_on_floor() and trick_time > AIR_GUARD_S:
			_finish_trick()
	elif trick == "bs_air":
		trick_time += delta
		if bsair_release_u < 0.0 and air_u() >= BSAIR_RELEASE_U and not _grab_held():
			bsair_release_u = air_u()
		if is_on_floor() and not pipe_air and trick_time > AIR_GUARD_S:
			trick = "land"          # safety: touched down without the pipe-air landing (respawn, a ledge)
			trick_time = 0.0
	elif trick == "land":
		trick_time += delta
		if trick_time >= LAND_S:
			trick = ""
	_push_trick()

func _start_air(kind: String) -> void:
	say({"ollie": "OLLIE", "flip": "KICKFLIP", "grab": "MELON"}.get(kind, kind.to_upper()))
	trick = kind
	trick_next = ""
	trick_time = 0.0
	if ramp_mode == "ride":
		_ramp_leave(OLLIE_POP_VELOCITY, "pop")
	elif ramp_mode == "bowl":
		_bowl_leave(OLLIE_POP_VELOCITY, "pop")
	else:
		velocity.y = OLLIE_POP_VELOCITY
	if kind == "flip":
		board_caught = false
		flip_turns = 0.0
	else:
		board_caught = true

func _grab_held() -> bool:
	if grab_hold:
		return true
	return not external_move_active and InputMap.has_action("trick") and Input.is_action_pressed("trick")

func _finish_trick() -> void:
	var grab_bail := trick == "grab" and _grab_held()
	if (trick == "flip" and not board_caught) or grab_bail:
		last_bail_reason = "grab_held" if grab_bail else "flip_not_caught"
		say("BAIL!", "bail")
		if boost != null:
			boost.note_bail()
		InputBindings.rumble(0.7, 0.35, 0.14)
		trick = "bail"
		bail_time = 0.6
		skating = false
		velocity.x *= 0.35
		velocity.z *= 0.35
		ramp_v *= 0.35
	else:
		var landed_trick := trick
		trick = "land"
		trick_time = 0.0
		board_caught = true
		_note_boost_trick()
		_event("trick_land", {"trick": landed_trick})
	_push_trick()

func _push_trick() -> void:
	if rig == null:
		return
	rig.trick = trick
	rig.trick_time = trick_time
	rig.flip_turns = flip_turns
	rig.board_caught = board_caught
	if is_on_floor():
		rig.floor_normal = get_floor_normal()
	else:
		rig.floor_normal = Vector3.UP

func _pose(delta: float) -> void:
	if rig == null or not rig.has_method("drive"):
		return
	_push_trick()
	var speed := Vector2(velocity.x, velocity.z).length()
	rig.drive(delta, speed, skating, not on_ground(), grind != null)

# ---------------------------------------------------------------- Phase 2: transition riding (LOCAL puppet test)

## True while the board is on something: flat ground or the curve.
func on_ground() -> bool:
	return grind != null or qp_state != "" or ramp_mode == "ride" or ramp_mode == "bowl" or is_on_floor()

## Rolling backwards relative to where he faces (fakie). Facing comes from the stick on the flat only.
func is_fakie() -> bool:
	var face := Vector3.FORWARD
	if rig != null:
		face = -rig.global_transform.basis.z
	var v := Vector3(velocity.x, 0.0, velocity.z)
	return v.length() > 0.3 and v.normalized().dot(Vector3(face.x, 0.0, face.z).normalized()) < -0.2

## World offset from the default sprite anchor (capsule bottom) to the board's contact point on the curve. The capsule
## stays upright, so on a steep wall its bottom sits off the surface; the card is drawn on the surface instead. Through a
## pipe air the take-off offset is held so the card does not jump when the board leaves the wall.
func sprite_anchor_offset() -> Vector3:
	if qp_state != "" and qp_state != "roll" and qp_pipe != null:
		return qp_ref_world() - (global_position + Vector3.UP * 0.325)
	if pipe_air:
		return air_anchor
	if ramp_mode == "bowl" and ramp != null and ramp.has_method("sample"):
		var surfaced: Dictionary = ramp.sample(bowl_xz)
		return surfaced.point - (global_position + Vector3.UP * 0.325)
	if ramp_mode != "ride" or ramp == null:
		return Vector3.ZERO
	var contact: Vector3 = ramp.to_global(ramp.profile_point(ramp_s, ramp_z))
	return contact - (global_position + Vector3.UP * 0.325)

## Wall angle under him in degrees (0 on the flat).
func ramp_angle_deg() -> float:
	if ramp_mode == "bowl":
		return rad_to_deg(bowl_theta)
	if ramp_mode != "ride" or ramp == null:
		return 0.0
	return rad_to_deg(ramp_s / ramp.radius)

func _event(what: String, extra := {}) -> void:
	var e := {"t": Time.get_ticks_msec(), "what": what, "s": ramp_s, "v": ramp_v}
	e.merge(extra, true)
	ramp_events.append(e)
	if ramp_events.size() > 64:
		ramp_events.pop_front()
	skate_event.emit(what, e)

## Sphere centre of the capsule's lower end in pipe space -> arc length, distance off the surface.
func _pipe_contact(pipe: Node3D) -> Dictionary:
	var c: Vector3 = pipe.to_local(global_position + Vector3.UP * CAPSULE_LOW)
	var r: float = pipe.radius
	var d: Vector2 = Vector2(c.x, r - c.y)
	var theta: float = atan2(c.x, r - c.y)
	return {"local": c, "theta": theta, "gap": r - d.length() - CAPSULE_R}

func _try_ramp_entry() -> void:
	if ramp_mode != "" or not skating or grind != null:
		return
	for pipe in get_tree().get_nodes_in_group("quarter_pipe"):
		if not pipe.has_method("profile_point"):
			continue
		var pc: Dictionary = _pipe_contact(pipe)
		var c: Vector3 = pc.local
		if absf(c.z) > pipe.half_width() - RAMP_EDGE:
			continue
		var theta: float = pc.theta
		if theta <= deg_to_rad(0.5) or theta >= pipe.climb_rad() - 0.001 or c.x <= 0.0:
			continue
		if absf(float(pc.gap)) > 0.12:
			continue
		_ramp_enter(pipe, theta * pipe.radius, c.z)
		return

func _ramp_enter(pipe: Node3D, s: float, z: float) -> void:
	ramp = pipe
	ramp_mode = "ride"
	ramp_s = s
	ramp_z = z
	var b: Basis = pipe.global_transform.basis
	var t_w: Vector3 = (b * pipe.profile_tangent(s)).normalized()
	ramp_v = velocity.dot(t_w)
	ramp_vz = velocity.dot(b.z.normalized())
	if not _reentry:
		ramp_entry_speed = Vector3(velocity.x, 0.0, velocity.z).length()
		ramp_peak_y = 0.0
	_reentry = false
	pipe_air = false
	pipe_air_pipe = null
	_event("enter", {"speed": ramp_entry_speed, "pipe": str(pipe.name)})
	_ramp_place()

func _ramp_step(delta: float) -> void:
	var pipe: Node3D = ramp
	if pipe == null or not is_instance_valid(pipe):
		ramp_mode = ""
		ramp = null
		return
	var jumping := _wants_jump()
	external_jump = false
	_tricks(delta)
	if ramp_mode != "ride":
		return              # a trick popped him off the wall this tick
	if jumping and bail_time <= 0.0:
		_ramp_leave(JUMP_VELOCITY, "jump")
		return
	if _qp_stick() < -0.4 and kickturn_window():
		_kickturn_begin()
		return
	var wish: Vector3 = _wish()
	wish_len = wish.length()
	var r: float = pipe.radius
	var theta: float = ramp_s / r
	var a: float = -GRAVITY * sin(theta)
	if absf(ramp_v) > 0.05:
		a -= signf(ramp_v) * RAMP_ROLL_DECEL
	pumping = qp_state != "roll" and wish_len > 0.2 and theta < deg_to_rad(PUMP_MAX_DEG) and absf(ramp_v) > PUMP_MIN_SPEED and (trick == "" or trick == "land") and bail_time <= 0.0
	if pumping:
		a += signf(ramp_v) * PUMP_ACCEL
	ramp_v += a * delta
	var b: Basis = pipe.global_transform.basis
	var zaxis: Vector3 = b.z.normalized()
	var lateral: float = wish.dot(zaxis)
	if absf(lateral) > 0.1 and bail_time <= 0.0:
		ramp_vz = move_toward(ramp_vz, lateral * RAMP_STEER_MAX, RAMP_STEER_ACCEL * delta)
	else:
		ramp_vz = move_toward(ramp_vz, 0.0, RAMP_ROLL_DECEL * delta)
	ramp_s += ramp_v * delta
	ramp_z += ramp_vz * delta
	ramp_peak_y = maxf(ramp_peak_y, pipe.profile_point(ramp_s).y)
	if ramp_s <= 0.0:
		# back on the flat: keep the speed (rolling away fakie if he came down backwards)
		var over: float = ramp_s
		ramp_s = 0.0
		_ramp_place()
		velocity = b * Vector3(ramp_v, 0.0, ramp_vz)
		global_position += (b * Vector3(1, 0, 0)).normalized() * over
		_event("exit_flat", {"fakie": is_fakie(), "peak": ramp_peak_y})
		if qp_state == "roll":
			_qp_rolled_out()
		ramp_mode = ""
		ramp = null
		pumping = false
		move_and_slide()
		return
	if ramp_s >= pipe.lip_arc():
		if ramp_v > 0.0:
			qp_state = ""
			_lip_launch()
			return
		ramp_s = pipe.lip_arc()
	if absf(ramp_z) > pipe.half_width() - RAMP_EDGE:
		_event("off_side")
		qp_state = ""
		ramp_mode = ""
		ramp = null
		pumping = false
		velocity = b * (pipe.profile_tangent(ramp_s) * ramp_v + Vector3(0, 0, ramp_vz))
		return
	_ramp_place()
	update_board()

## Put the capsule's lower sphere on the curve (tangent to it), set velocity along the wall, and the card lean.
func _ramp_place() -> void:
	var pipe: Node3D = ramp
	var b: Basis = pipe.global_transform.basis
	var contact: Vector3 = pipe.to_global(pipe.profile_point(ramp_s, ramp_z))
	var n: Vector3 = (b * pipe.profile_normal(ramp_s)).normalized()
	global_position = contact + n * CAPSULE_R - Vector3.UP * CAPSULE_LOW
	velocity = b * (pipe.profile_tangent(ramp_s) * ramp_v + Vector3(0, 0, ramp_vz))
	# Phase 3: the drop-in roll-out frames are drawn at the wall angle (all 8 views), so the card itself stays upright
	ramp_lean_up = Vector3.UP if qp_state == "roll" or qp_state == "kickturn" else n

## Off the coping going up: straight up with a small drift back over the transition (plan: vertical launch faked in code).
func _lip_launch() -> void:
	var pipe: Node3D = ramp
	var b: Basis = pipe.global_transform.basis
	var over: float = ramp_s - pipe.lip_arc()
	# speed left at the coping (the overshoot this tick climbed against gravity at the lip angle)
	var v_lip: float = sqrt(maxf(ramp_v * ramp_v - 2.0 * GRAVITY * sin(pipe.climb_rad()) * maxf(over, 0.0), 0.0))
	ramp_s = pipe.lip_arc()
	_ramp_place()
	lip_launch_speed = v_lip
	air_peak_above_lip = 0.0
	air_from_y = global_position.y
	air_anchor = sprite_anchor_offset()
	# Park pipes pop straight up and drift back into the transition. A pipe that names
	# launch_forward carries that many m/s along its climb instead, so a story ramp can
	# clear the gap past its own coping. Every other pipe keeps the park drift.
	var along := -LIP_DRIFT
	if pipe.has_meta("launch_forward"):
		along = float(pipe.get_meta("launch_forward"))
	var up := v_lip
	if pipe.has_meta("launch_up"):
		up = maxf(up, float(pipe.get_meta("launch_up")))
	set_meta("last_lip_pipe", str(pipe.name))
	velocity = b * Vector3(along, up, ramp_vz)
	air_kind = "lip"
	air_time = 0.0
	air_total = 2.0 * v_lip / GRAVITY
	_event("lip_launch", {"speed": v_lip, "pipe": str(pipe.name)})
	ramp_mode = ""
	pipe_air = true
	pipe_air_pipe = pipe
	ramp = null
	pumping = false
	move_and_slide()

## Leave the wall along its normal (ollie pop or jump), keeping the speed along it.
func _ramp_leave(pop: float, why: String) -> void:
	var pipe: Node3D = ramp
	var b: Basis = pipe.global_transform.basis
	var n: Vector3 = (b * pipe.profile_normal(ramp_s)).normalized()
	velocity = b * (pipe.profile_tangent(ramp_s) * ramp_v + Vector3(0, 0, ramp_vz)) + n * pop
	air_kind = "pop"
	air_time = 0.0
	air_total = 0.0
	air_peak_above_lip = 0.0
	air_from_y = global_position.y
	air_anchor = sprite_anchor_offset()
	_event(why)
	ramp_mode = ""
	pipe_air = true
	pipe_air_pipe = pipe
	ramp = null
	pumping = false
	move_and_slide()

func _pipe_air_landed() -> void:
	pipe_air = false
	if trick == "bs_air":
		_bsair_land()
	air_kind = ""
	var pipe: Node3D = pipe_air_pipe
	pipe_air_pipe = null
	if pipe != null and is_instance_valid(pipe) and pipe.is_in_group("skate_bowl"):
		_bowl_air_landed(pipe)
		return
	if pipe == null or not is_instance_valid(pipe):
		last_landing = "flat"
		return
	var c: Vector3 = pipe.to_local(global_position + Vector3.UP * 0.325)
	var lip: Vector3 = pipe.lip_local()
	if c.x > lip.x - 0.05 and c.x < pipe.deck_end_x() + 0.3 and c.y > lip.y - 0.3:
		last_landing = "deck"
		_event("landed_deck")
		# plan: landing on the deck counts as a bail
		if trick != "bail":
			last_bail_reason = "deck_landing"
			trick = "bail"
			bail_time = 0.6
			skating = false
			velocity.x *= 0.35
			velocity.z *= 0.35
	elif c.x > 0.02 and c.y > 0.02:
		last_landing = "transition"
		_reentry = true
		_event("landed_transition", {"x": c.x, "y": c.y})
	else:
		last_landing = "flat"
		_event("landed_flat")

# ---------------------------------------------------------------- Bowl: the yard pool, same curve step as the quarter pipe

const Bounds = preload("res://scripts/world_bounds.gd")

## Remember a grounded in-bounds spot. Dropping through the kill plane, or ending up clear of every
## playable volume, puts him back there instead of letting him fall out of Glitchport.
func _keep_in_bounds() -> void:
	if not bounds_enabled:
		return
	if Bounds.is_safe(self):
		last_safe_position = global_position
		last_safe_yaw = rotation.y
		last_safe_valid = true
		return
	if global_position.y < Bounds.KILL_Y or Bounds.outside(global_position):
		_recover_safe()

func _recover_safe() -> void:
	var back := last_safe_position if last_safe_valid else spawn_position
	var yaw := last_safe_yaw if last_safe_valid else spawn_yaw
	velocity = Vector3.ZERO
	grind = null
	grind_pop_side = Vector3.ZERO
	ramp_mode = ""
	ramp = null
	pipe_air = false
	pipe_air_pipe = null
	qp_state = ""
	qp_pending = 0.0
	pumping = false
	global_position = back
	rotation.y = yaw

## Roll onto the pool wall. From the deck, keep the approach speed (a steep projection would eat it).
## From the flat, the slope is still shallow, so the tangent projection is the whole speed.
func _try_bowl_entry() -> void:
	if ramp_mode != "" or not skating or grind != null or pipe_air or not is_on_floor():
		return
	for bowl in get_tree().get_nodes_in_group("skate_bowl"):
		if not bowl.has_method("sample"):
			continue
		var s: Dictionary = bowl.sample(global_position)
		var out: Vector3 = s.out
		if out.length() < 0.5:
			continue
		var speed := Vector2(velocity.x, velocity.z).length()
		var inward := -Vector3(velocity.x, 0.0, velocity.z).dot(out)
		if str(s.kind) == "flat" and float(s.u) > -0.75 and Vector3(velocity.x, 0.0, velocity.z).dot(out) > 1.2:
			var up: Dictionary = bowl.sample_toward(global_position, 0.2)
			_bowl_enter(bowl, up, false, speed)
			return
		if str(s.kind) == "wall" and float(s.u) > 0.15 and float(s.u) < float(s.lip_u) - 0.02:
			if absf(global_position.y + 0.325 - float(s.y)) < 0.5:
				_bowl_enter(bowl, s, inward > 0.3, speed)
				return
		elif str(s.kind) == "deck" and float(s.u) < float(s.lip_u) + 0.6 and inward > 1.2:
			var lip: Dictionary = bowl.sample_toward(global_position, float(s.lip_u) - 0.15)
			_bowl_enter(bowl, lip, true, speed)
			return

func _bowl_enter(bowl: Node3D, s: Dictionary, descending: bool, speed: float) -> void:
	ramp = bowl
	ramp_mode = "bowl"
	bowl_xz = s.point
	bowl_theta = float(s.theta)
	var tangent: Vector3 = s.tangent
	if descending:
		ramp_v = -maxf(speed, 1.2)
	else:
		ramp_v = velocity.dot(tangent)
	ramp_vz = velocity.dot(s.around)
	ramp_entry_speed = speed
	ramp_peak_y = float(s.y)
	pipe_air = false
	pipe_air_pipe = null
	_event("bowl_enter", {"speed": speed, "pipe": str(bowl.name)})
	_bowl_place(s)

func _bowl_step(delta: float) -> void:
	var bowl: Node3D = ramp
	if bowl == null or not is_instance_valid(bowl):
		ramp_mode = ""
		ramp = null
		return
	# A mission retry or a test teleports the body. Drop the curve instead of dragging him back onto it.
	if global_position.distance_to(bowl_xz) > 4.0:
		ramp_mode = ""
		ramp = null
		pumping = false
		return
	var s: Dictionary = bowl.sample(bowl_xz)
	var jumping := _wants_jump()
	external_jump = false
	_tricks(delta)
	if ramp_mode != "bowl":
		return
	if jumping and bail_time <= 0.0:
		_bowl_leave(JUMP_VELOCITY, "jump")
		return
	var theta: float = float(s.theta)
	var a := -GRAVITY * sin(theta)
	if absf(ramp_v) > 0.05:
		a -= signf(ramp_v) * RAMP_ROLL_DECEL
	var wish: Vector3 = _wish()
	wish_len = wish.length()
	# The pool is deeper than a quarter pipe. A held stick pumps higher up the wall, so a push
	# from the flat still rides out to the deck (the P.1 line leaves this way).
	pumping = qp_state != "roll" and wish_len > 0.2 and theta < deg_to_rad(62.0) and absf(ramp_v) > PUMP_MIN_SPEED and (trick == "" or trick == "land") and bail_time <= 0.0
	if pumping:
		a += signf(ramp_v) * 4.5
	ramp_v += a * delta
	var around: Vector3 = s.around
	var lateral: float = wish.dot(around)
	if absf(lateral) > 0.1 and bail_time <= 0.0:
		ramp_vz = move_toward(ramp_vz, lateral * RAMP_STEER_MAX, RAMP_STEER_ACCEL * delta)
	else:
		ramp_vz = move_toward(ramp_vz, 0.0, RAMP_ROLL_DECEL * delta)
	var out: Vector3 = s.out
	var horiz := out * (ramp_v * cos(theta) * delta) + around * (ramp_vz * delta)
	var nxt: Dictionary = bowl.sample(bowl_xz + horiz)
	if ramp_v > 0.15 and (str(nxt.kind) == "deck" or float(nxt.u) >= float(nxt.lip_u) - 0.001):
		if ramp_v < 3.2:
			_bowl_roll_out(s)
		else:
			_bowl_launch(s)
		return
	if ramp_v < 0.0 and float(nxt.u) <= 0.05:
		_bowl_exit_flat(nxt)
		return
	bowl_xz = nxt.point
	ramp_peak_y = maxf(ramp_peak_y, float(nxt.y))
	_bowl_place(nxt)
	update_board()

func _bowl_place(s: Dictionary) -> void:
	var n: Vector3 = s.normal
	bowl_theta = float(s.theta)
	bowl_xz = s.point
	global_position = s.point + n * CAPSULE_R - Vector3.UP * CAPSULE_LOW
	var tangent: Vector3 = s.tangent
	velocity = tangent * ramp_v + s.around * ramp_vz
	ramp_lean_up = n

func _bowl_exit_flat(s: Dictionary) -> void:
	var out: Vector3 = s.out
	var around: Vector3 = s.around
	velocity = out * ramp_v + around * ramp_vz
	velocity.y = 0.0
	var floor_y: float = float(s.floor_y)
	# Land on the flat just inside the curve. The re-entry gap (u > 0.15) keeps this from grabbing him again.
	global_position = Vector3(s.point.x, floor_y - 0.325, s.point.z) - out * 0.08
	ramp_mode = ""
	ramp = null
	pumping = false
	ramp_lean_up = Vector3.UP
	_event("bowl_exit", {"peak": ramp_peak_y})

## A modest crest rolls out onto the deck. A fast one takes the quarter-pipe vertical launch.
func _bowl_roll_out(s: Dictionary) -> void:
	var bowl: Node3D = ramp
	var out: Vector3 = s.out
	var deck: Dictionary = bowl.sample_toward(bowl_xz, float(s.lip_u) + 0.45)
	velocity = out * maxf(ramp_v, 1.4) + s.around * ramp_vz
	velocity.y = 0.0
	var p: Vector3 = deck.point
	global_position = Vector3(p.x, -0.325, p.z)
	ramp_mode = ""
	ramp = null
	pumping = false
	ramp_lean_up = Vector3.UP
	_event("bowl_exit", {"peak": ramp_peak_y})

## Off the coping going up: straight up, with a small drift back into the pool (the quarter-pipe lip launch).
func _bowl_launch(s: Dictionary) -> void:
	var bowl: Node3D = ramp
	var lip: Dictionary = bowl.sample_toward(bowl_xz, float(s.lip_u) - 0.04)
	ramp_v = maxf(ramp_v, 0.0)
	_bowl_place(lip)
	var out: Vector3 = lip.out
	var around: Vector3 = lip.around
	var v_lip := ramp_v
	lip_launch_speed = v_lip
	air_peak_above_lip = 0.0
	air_from_y = global_position.y
	air_anchor = sprite_anchor_offset()
	velocity = -out * LIP_DRIFT + Vector3.UP * v_lip + around * ramp_vz
	air_kind = "lip"
	air_time = 0.0
	air_total = 2.0 * v_lip / GRAVITY
	_event("bowl_lip", {"speed": v_lip})
	ramp_mode = ""
	pipe_air = true
	pipe_air_pipe = bowl
	ramp = null
	pumping = false
	move_and_slide()

func _bowl_leave(pop: float, why: String) -> void:
	var bowl: Node3D = ramp
	var s: Dictionary = bowl.sample(bowl_xz)
	velocity = s.tangent * ramp_v + s.around * ramp_vz + s.normal * pop
	air_kind = "pop"
	air_time = 0.0
	air_total = 0.0
	air_from_y = global_position.y
	air_anchor = sprite_anchor_offset()
	_event(why)
	ramp_mode = ""
	pipe_air = true
	pipe_air_pipe = bowl
	ramp = null
	pumping = false
	move_and_slide()

func _bowl_air_landed(bowl: Node3D) -> void:
	var s: Dictionary = bowl.sample(global_position)
	if str(s.kind) == "deck":
		last_landing = "deck"
		_event("landed_deck")
		if trick != "bail":
			last_bail_reason = "deck_landing"
			trick = "bail"
			bail_time = 0.6
			skating = false
			velocity.x *= 0.35
			velocity.z *= 0.35
		return
	if str(s.kind) == "wall" and float(s.u) > 0.12:
		last_landing = "transition"
		_reentry = true
		_event("bowl_reentry", {"u": s.u})
		var speed := Vector2(velocity.x, velocity.z).length()
		_bowl_enter(bowl, s, velocity.dot(s.tangent) < 0.0, maxf(speed, absf(velocity.y)))
		return
	last_landing = "flat"
	_event("landed_flat")

# ---------------------------------------------------------------- Phase 3: quarter-pipe drop-in (LOCAL puppet test)

## Shift (skate_toggle). On the drop-in spot it sets up / backs out instead of the flat kick-up / drop.
func skate_toggle_pressed() -> void:
	if grind != null:
		return              # grind round: Shift does nothing on a rail (no kick-up mid-grind)
	if qp_state == "setup" or qp_state == "ready":
		_qp_back_out()
		return
	if qp_state != "" or qp_pending > 0.0:
		return
	var spot := qp_spot()
	if not spot.is_empty():
		if not skating:
			_qp_begin(spot)
			return
		if Vector2(velocity.x, velocity.z).length() < QP_RIDE_MAX:
			# rolling up to the coping: kick the board up (the kickup clip plays), then set it on the coping
			skating = false
			qp_pending = QP_KICKUP_S
			_event("qp_kickup")
			update_board()
			return
	skating = not skating
	update_board()
	_event("drop_on" if skating else "kick_up", {"speed": Vector2(velocity.x, velocity.z).length()})

## The drop-in spot under him, or {}: on a quarter pipe's deck within QP_SPOT_MAX of the coping, facing the ramp.
func qp_spot() -> Dictionary:
	if grind != null or ramp_mode != "" or pipe_air or bail_time > 0.0 or trick != "" or not is_on_floor():
		return {}
	var face := Vector3.FORWARD
	if rig != null:
		face = -rig.global_transform.basis.z
	face.y = 0.0
	if face.length() < 0.001:
		return {}
	face = face.normalized()
	for pipe in get_tree().get_nodes_in_group("quarter_pipe"):
		if not pipe.has_method("lip_local"):
			continue
		var c: Vector3 = pipe.to_local(global_position + Vector3.UP * 0.325)
		var lip: Vector3 = pipe.lip_local()
		var behind: float = c.x - lip.x
		if absf(c.y - lip.y) > 0.15 or behind < 0.0 or behind > QP_SPOT_MAX:
			continue
		if absf(c.z) > pipe.half_width() - 0.45:
			continue
		var into: Vector3 = (pipe.global_transform.basis * Vector3(-1, 0, 0))
		into.y = 0.0
		into = into.normalized()
		var off_deg := rad_to_deg(acos(clampf(face.dot(into), -1.0, 1.0)))
		if off_deg > QP_FACE_MAX_DEG:
			continue
		return {"pipe": pipe, "z": c.z, "behind": behind, "off_deg": off_deg, "into": into}
	return {}

## World point the qp_ frames pin their rig origin on (the lip edge at deck height at his z), carried along while he slides
## onto his mark at the start of qp_setup so the drawing never jumps.
func qp_ref_world() -> Vector3:
	if qp_pipe == null or not is_instance_valid(qp_pipe):
		return global_position + Vector3.UP * 0.325
	var lip: Vector3 = qp_pipe.lip_local()
	if qp_state == "kickturn":
		return qp_pipe.to_global(qp_pipe.profile_point(kt_origin_s, qp_z))
	var ref: Vector3 = qp_pipe.to_global(Vector3(lip.x, lip.y, qp_z))
	if qp_state == "setup" or qp_state == "ready":
		ref += global_position - qp_to
	return ref

func _qp_stick() -> float:
	var move := external_move if external_move_active else _hardware_move()
	return move.y

func _qp_begin(spot: Dictionary) -> void:
	var pipe: Node3D = spot.pipe
	qp_pipe = pipe
	qp_z = float(spot.z)
	qp_state = "setup"
	qp_time = 0.0
	qp_reverse = false
	skating = false
	velocity = Vector3.ZERO
	var lip: Vector3 = pipe.lip_local()
	qp_from = global_position
	qp_to = pipe.to_global(Vector3(lip.x + QP_STAND_BACK, lip.y, qp_z)) - Vector3.UP * 0.325
	qp_from_yaw = rig.global_rotation.y if rig != null else rotation.y
	var into: Vector3 = spot.into
	qp_to_yaw = atan2(-into.x, -into.z)
	_event("qp_setup", {"behind": spot.behind, "off_deg": spot.off_deg})

func _qp_back_out() -> void:
	qp_state = "setup"
	qp_reverse = true
	qp_time = minf(qp_time, QP_SETUP_S)
	_event("qp_back_out")

func _qp_face(yaw: float) -> void:
	if rig != null and rig.has_method("face_world"):
		rig.face_world(yaw)

## Runs the drop-in states. Returns true when it owned this tick (no flat movement, no tricks).
func _qp_step(delta: float) -> bool:
	if qp_pending > 0.0:
		qp_pending = maxf(0.0, qp_pending - delta)
		if qp_pending <= 0.0 and qp_state == "":
			var spot := qp_spot()
			if not spot.is_empty():
				_qp_begin(spot)
		if qp_state == "":
			return false
	if qp_state == "" or qp_state == "roll":
		return false
	if qp_state == "kickturn":
		_kickturn_step(delta)
		return true
	external_jump = false
	trick_request = ""
	wish_len = 0.0
	var stick := _qp_stick()
	if qp_state == "setup":
		qp_time += -delta if qp_reverse else delta
		var u := smoothstep(0.0, 1.0, clampf(qp_time / QP_APPROACH_S, 0.0, 1.0))
		global_position = qp_from.lerp(qp_to, u)
		_qp_face(lerp_angle(qp_from_yaw, qp_to_yaw, u))
		velocity = Vector3.ZERO
		if qp_reverse:
			if qp_time <= 0.0:
				qp_time = 0.0
				qp_state = ""
				qp_reverse = false
				_event("qp_backed_out")
		else:
			if stick < -0.5:
				_qp_back_out()
			elif qp_time >= QP_SETUP_S:
				qp_time = QP_SETUP_S
				qp_state = "ready"
				_event("qp_ready")
		return true
	if qp_state == "ready":
		velocity = Vector3.ZERO
		if stick > 0.5:
			qp_state = "commit"
			qp_time = 0.0
			qp_commit_msec = Time.get_ticks_msec()
			qp_elapsed = 0.0
			qp_from = global_position
			var pipe: Node3D = qp_pipe
			var s0: float = pipe.lip_arc() - QP_ROLL_START_M
			var n: Vector3 = (pipe.global_transform.basis * pipe.profile_normal(s0)).normalized()
			qp_to = pipe.to_global(pipe.profile_point(s0, qp_z)) + n * CAPSULE_R - Vector3.UP * CAPSULE_LOW
			_event("qp_commit")
		elif stick < -0.5:
			_qp_back_out()
		return true
	if qp_state == "commit":
		qp_time += delta
		if qp_time <= QP_HESITATE_S and stick < 0.3:
			_qp_bail("qp_hesitate" if stick > -0.5 else "qp_lean_back")
			return true
		# the body (and the game camera) glide toward the roll-out start; the drawing stays pinned on the coping
		global_position = qp_from.lerp(qp_to, smoothstep(0.0, 1.0, clampf(qp_time / QP_COMMIT_S, 0.0, 1.0)))
		velocity = Vector3.ZERO
		if qp_time >= QP_COMMIT_S:
			_qp_roll_start()
		return true
	if qp_state == "bail":
		qp_time += delta
		velocity = Vector3.ZERO
		# he falls back onto his mark behind the coping (the drawing stays pinned on the coping)
		global_position = qp_from.lerp(qp_to, smoothstep(0.0, 1.0, clampf(qp_time / 0.2, 0.0, 1.0)))
		if qp_time >= QP_BAIL_S:
			qp_state = ""
			skating = false
			board_caught = true
			_event("qp_bail_done")
		return true
	return false

func _qp_bail(reason: String) -> void:
	last_bail_reason = reason
	qp_state = "bail"
	qp_time = 0.0
	qp_from = global_position
	qp_to = qp_to_stand()
	_event("qp_bail", {"reason": reason})

## The mark he stands on behind the coping (bail falls back onto it).
func qp_to_stand() -> Vector3:
	var lip: Vector3 = qp_pipe.lip_local()
	return qp_pipe.to_global(Vector3(lip.x + QP_STAND_BACK, lip.y, qp_z)) - Vector3.UP * 0.325

func _qp_roll_start() -> void:
	var pipe: Node3D = qp_pipe
	ramp = pipe
	ramp_mode = "ride"
	ramp_s = pipe.lip_arc() - QP_ROLL_START_M
	ramp_z = qp_z
	ramp_v = -QP_ROLL_V0
	ramp_vz = 0.0
	ramp_entry_speed = 0.0
	ramp_peak_y = pipe.profile_point(ramp_s).y
	pipe_air = false
	pipe_air_pipe = null
	skating = true
	trick = ""
	qp_state = "roll"
	_event("qp_roll", {"t": qp_time})
	say("DROP IN")
	_ramp_place()

func _qp_rolled_out() -> void:
	qp_state = ""
	qp_exit_speed = Vector2(velocity.x, velocity.z).length()
	qp_exit_s = qp_elapsed
	qp_runs += 1
	_event("qp_rolled_out", {"speed": qp_exit_speed, "fakie": is_fakie()})

# ---------------------------------------------------------------- Phase 4: backside kickturn (LOCAL puppet test)

## Riding up a library quarter-pipe near the top of his line: holding back (S) here kickturns.
func kickturn_window() -> bool:
	if ramp_mode != "ride" or ramp == null or qp_state != "" or not skating or bail_time > 0.0 or trick != "":
		return false
	if not ramp.has_method("lip_arc"):
		return false
	if ramp.profile_point(ramp_s).y < KT_MIN_Y or ramp_s > ramp.lip_arc() - KT_LIP_GAP:
		return false
	return ramp_v > -0.3 and ramp_v < KT_MAX_V

## Turn so far (deg) at clip time t.
func kt_turn_deg(t: float) -> float:
	var keys: Array = KT_TURN_KEYS
	if t <= 0.0:
		return 0.0
	for i in range(1, keys.size()):
		if t <= float(keys[i][0]):
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			return lerpf(float(a[1]), float(b[1]), (t - float(a[0])) / (float(b[0]) - float(a[0])))
	return 180.0

func _kickturn_begin() -> void:
	var pipe: Node3D = ramp
	var r: float = pipe.radius
	# the clip starts with the board at the wall angle under it (roll_params(deg) in tools/anim_qp.py): nearest baked angle
	var wall_deg := rad_to_deg(ramp_s / r)
	kt_deg = KT_VARIANTS[0]
	for d in KT_VARIANTS:
		if absf(float(d) - wall_deg) < absf(float(kt_deg) - wall_deg):
			kt_deg = d
	qp_pipe = pipe
	qp_z = ramp_z
	kt_origin_s = ramp_s - KT_START_UP
	# facing up the wall -> facing down it, clockwise from above (backside for his regular stance)
	var up_wall: Vector3 = pipe.global_transform.basis * Vector3(1, 0, 0)   # +X climbs the library pipe
	kt_from_yaw = atan2(-up_wall.x, -up_wall.z)
	kt_to_yaw = kt_from_yaw - PI
	# the drawing carries the spin in every view; the facing (which picks the view) goes straight to the exit heading
	if rig != null and rig.has_method("face_world"):
		rig.face_world(kt_to_yaw)
	kt_last = {"entry_speed": ramp_entry_speed, "start_s": ramp_s, "start_v": ramp_v, "wall_deg": wall_deg, "deg": kt_deg,
		"start_y": pipe.profile_point(ramp_s).y, "msec": Time.get_ticks_msec()}
	qp_state = "kickturn"
	qp_time = 0.0
	ramp_v = 0.0
	ramp_vz = 0.0
	pumping = false
	wish_len = 0.0
	_event("kickturn", {"deg": kt_deg, "wall_deg": wall_deg})
	say("BS KICKTURN")
	_ramp_place()

## The board swings about the back truck: its centre goes from KT_START_UP above the origin to the origin.
func _kickturn_step(delta: float) -> void:
	var pipe: Node3D = qp_pipe
	if pipe == null or not is_instance_valid(pipe):
		qp_state = ""
		return
	external_jump = false
	trick_request = ""
	qp_time += delta
	var turn := kt_turn_deg(qp_time)
	ramp_s = kt_origin_s + KT_PIVOT_UP + KT_PIVOT_UP * cos(deg_to_rad(turn))
	ramp_v = 0.0
	_ramp_place()
	update_board()
	if qp_time >= KT_S:
		ramp_s = kt_origin_s
		ramp_v = -KT_EXIT_V
		qp_state = ""
		kt_count += 1
		_ramp_place()
		kt_last["end_s"] = ramp_s
		kt_last["time"] = qp_time
		kt_last["fakie"] = is_fakie()
		_event("kickturn_end", {"fakie": is_fakie()})

# ---------------------------------------------------------------- Phase 5: backside air (finish pass, Nov 17 2026)

## Fraction of the predicted lip air flown (0 at the coping, 1 back at the take-off height).
func air_u() -> float:
	if air_total <= 0.0:
		return 0.0
	return clampf(air_time / air_total, 0.0, 1.5)

## A grab pressed now turns into a backside air: off the coping (not an ollie off the wall), enough air, early enough in it.
func bsair_ready() -> bool:
	return pipe_air and air_kind == "lip" and air_total >= BSAIR_MIN_AIR_S and air_u() <= BSAIR_START_MAX_U \
		and (trick == "" or trick == "ollie") and bail_time <= 0.0

func _bsair_begin() -> void:
	trick = "bs_air"
	trick_next = ""
	trick_time = 0.0
	board_caught = true
	bsair_u0 = air_u()
	bsair_release_u = -1.0
	# the drawing carries the 180 in every view (air_bs_<view>, tyaw 0 -> 180); the facing that picks the view stays on the
	# take-off heading until he lands, then turns to the landing heading (_bsair_land)
	bsair_from_yaw = rig.global_rotation.y if rig != null else rotation.y
	bsair_last = {"start_u": bsair_u0, "air_total": air_total, "lip_speed": lip_launch_speed, "msec": Time.get_ticks_msec()}
	_event("bs_air", {"u": bsair_u0, "air": air_total})
	say("BACKSIDE AIR")

## Re-entry (or any touchdown) during a backside air: let go in time = land forward; still on the board = bail.
func _bsair_land() -> void:
	var u := air_u()
	bsair_last["land_u"] = u
	bsair_last["release_u"] = bsair_release_u
	if bsair_release_u < 0.0:
		bsair_last["result"] = "bail"
		last_bail_reason = "bs_air_grab_held" if u >= BSAIR_RELEASE_U else "bs_air_short"
		say("BAIL!", "bail")
		if boost != null:
			boost.note_bail()
		trick = "bail"
		bail_time = 0.6
		skating = false
		velocity.x *= 0.35
		velocity.z *= 0.35
		_event("bs_air_bail", {"u": u})
		return
	_note_boost_trick()
	bsair_count += 1
	bsair_last["result"] = "landed"
	if rig != null and rig.has_method("face_world"):
		rig.face_world(wrapf(bsair_from_yaw - PI, -PI, PI))
	trick = "land"
	trick_time = 0.0
	_event("bs_air_land", {"u": u})

# ---------------------------------------------------------------- finish pass: browser demos (?demo=<kind>)
## Scripted runs at the new tricks for the web build's checks (hq_main.gd _maybe_demo): start point, travel direction, entry
## speed, stick, a fixed camera, and the trick to press on the way.
const DEMO_LINES := {
	"rail5050": {"start": Vector3(-41.0, -0.325, 8.2), "dir": Vector3(-1, 0, 0), "speed": 5.6, "stick": 0.62, "cam": Vector3(-51.5, 1.3, 12.8), "ollie_x": -46.4, "switch": ""},
	"rail5o": {"start": Vector3(-41.0, -0.325, 8.2), "dir": Vector3(-1, 0, 0), "speed": 5.6, "stick": 0.62, "cam": Vector3(-51.5, 1.3, 12.8), "ollie_x": -46.4, "switch": "grab"},
	"railboard": {"start": Vector3(-41.0, -0.325, 8.2), "dir": Vector3(-1, 0, 0), "speed": 5.6, "stick": 0.62, "cam": Vector3(-51.5, 1.3, 12.8), "ollie_x": -46.4, "switch": "flip"},
	"downrail": {"start": Vector3(-72.0, 0.895, 2.15), "dir": Vector3(1, 0, 0), "speed": 9.0, "stick": 1.0, "cam": Vector3(-64.6, 2.2, 8.6), "ollie_x": -70.1, "switch": ""},
	"bsair": {"start": Vector3(-46.0, -0.325, -12.0), "dir": Vector3(-1, 0, 0), "speed": 9.0, "stick": 1.0, "cam": Vector3(-49.0, 2.4, -15.8), "ollie_x": INF, "switch": ""},
	"kickturn": {"start": Vector3(-49.0, -0.3, -12.0), "dir": Vector3(-1, 0, 0), "speed": 6.5, "stick": 0.0, "cam": Vector3(-50.2, 2.6, -16.6), "ollie_x": INF, "switch": ""},
}
var demo_switched := false

func _demo_line(line: Dictionary, focus: Vector3) -> void:
	var dir: Vector3 = line.dir
	camera_yaw = atan2(-dir.x, -dir.z) - rotation.y
	demo_cam.global_position = line.cam
	external_move = Vector2(0, float(line.stick))
	var along := global_position.dot(dir)
	if visual_demo == "kickturn":
		if ramp_mode == "" and qp_state == "" and kt_count == 0 and not pipe_air:
			velocity = Vector3(dir.x * float(line.speed), velocity.y, dir.z * float(line.speed))
		if ramp_mode == "ride" and ramp != null and qp_state == "" and kt_count == 0 and ramp.profile_point(ramp_s).y > 0.5:
			external_move = Vector2(0, -1)
		elif ramp_mode == "ride" or kt_count > 0:
			external_move = Vector2.ZERO
	if visual_demo == "bsair":
		if ramp_mode == "ride" or pipe_air:
			external_move = Vector2.ZERO
		if not demo_switched and pipe_air and air_kind == "lip" and air_u() >= 0.05:
			request_trick("grab")
			demo_switched = true
	if trick == "" and grind == null and grind_count == 0 and float(line.ollie_x) < INF and along > float(line.ollie_x) * dir.x:
		request_trick("ollie")
	if str(line.switch) != "" and grind != null and not demo_switched and grind_clip_t > 0.05:
		request_trick(str(line.switch))
		demo_switched = true
