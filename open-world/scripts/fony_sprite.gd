extends Node3D

## Painted Fony as a Y-locked billboard. v3 is the only atlas.

const AnimScript = preload("res://scripts/fony_sprite_anim.gd")
const PIXEL := 0.007167

func _px(fr: Dictionary) -> float:
	return float(fr.get("pixel_size", PIXEL))

func _atlas_scale(fr: Dictionary) -> float:
	return float(fr.get("atlas_scale", AnimScript.ATLAS_SCALE))


var anim = AnimScript.new()
var sprite: Sprite3D
var tex: Texture2D
var tex_puppet: Texture2D
var tex_puppet_files := {}
var foot_local_y := 0.325
var _prev_speed := 0.0
## Phase 1d anchor depth fix. The 3D-lifted puppet views were baked with the anchor (the card's
## ground line) moved toward the camera so the near end of the board stays above the ground;
## the body's ground point is drawn body_px above that anchor. Stand the card that far toward
## the camera, by the distance that puts the drawn body point on the physics body along the
## real camera ray, so the board stays on the body when the view swaps. Sides have 0.
var depth_fix := true
## Phase 1d: anchor the card sideways in the billboard plane (false = pre-1d node-local X; probes only).
var plane_anchor := true
const DEPTH_MIN_ELEVATION := 0.14   # rad (~8 deg): below this the ray solve is unstable; use the baked depth
var depth_shift := 0.0
var depth_offset := Vector3.ZERO
## Phase 2 wall lean. The card normally turns only about Y. On the curve its up axis follows the surface normal: the full
## tilt in the card's own plane (side views: body square to the wall), and at most LEAN_MAX_PITCH toward / away from the
## camera (front and back views would otherwise lay the card flat). It pivots on the board's contact point.
const LEAN_MAX_PITCH := 0.35        # rad (~20 deg)
var lean_up := Vector3.UP
var anchor_extra := Vector3.ZERO
var lean_roll := 0.0                # applied in-plane tilt (rad), for tests / probes
var lean_pitch := 0.0

func _ready() -> void:
	name = "FonySprite"
	anim.ensure_loaded()
	tex = load("res://assets/library/fony2d/fony2d_v3_atlas.png")
	if ResourceLoader.exists("res://assets/library/fony2d/fony2d_puppet_v1_atlas.png"):
		tex_puppet = load("res://assets/library/fony2d/fony2d_puppet_v1_atlas.png")
	sprite = Sprite3D.new()
	sprite.name = "Card"
	sprite.texture = tex
	sprite.centered = true
	sprite.pixel_size = PIXEL
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.5
	sprite.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	sprite.region_enabled = true
	add_child(sprite)

func _physics_process(delta: float) -> void:
	var body = get_parent()
	if body == null or sprite == null:
		return
	var velocity: Vector3 = body.velocity
	var speed := Vector2(velocity.x, velocity.z).length()
	var accel := (speed - _prev_speed) / maxf(delta, 0.0001)
	_prev_speed = speed
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var camera_x := global_position.x
	var camera_z := global_position.z + 4.0
	if cam != null:
		camera_x = cam.global_position.x
		camera_z = cam.global_position.z
	var facing := 0.0
	if body.rig != null:
		facing = body.rig.global_rotation.y
	var ctx := {
		"facing_yaw": facing,
		"camera_x": camera_x,
		"camera_z": camera_z,
		"origin_x": global_position.x,
		"origin_z": global_position.z,
		"skating": bool(body.skating),
		"speed": speed,
		"accel": accel,
		"wish": float(body.wish_len),
		"on_floor": body.on_ground() if body.has_method("on_ground") else body.is_on_floor(),
		# Phase 2 transition riding
		"ramp": str(body.ramp_mode) if "ramp_mode" in body else "",
		"pumping": bool(body.pumping) if "pumping" in body else false,
		"ramp_deg": float(body.ramp_angle_deg()) if body.has_method("ramp_angle_deg") else 0.0,
		"ramp_v": float(body.ramp_v) if "ramp_v" in body else 0.0,
		"vy": velocity.y,
		"trick": str(body.trick),
		"trick_next": str(body.trick_next),
		"trick_time": float(body.trick_time),
		"flip_turns": float(body.flip_turns),
		"bail_time": float(body.bail_time),
		"grab_held": body.has_method("_grab_held") and body._grab_held(),
		"grind": body.grind != null,
		"pop_vy": float(body.OLLIE_POP_VELOCITY),
		"gravity": float(body.GRAVITY),
		"crouch_s": float(body.OLLIE_CROUCH_S),
		"jump_vy": float(body.JUMP_VELOCITY),
		# Phase 3 drop-in
		"qp": str(body.qp_state) if "qp_state" in body else "",
		"qp_time": float(body.qp_time) if "qp_time" in body else 0.0,
	}
	var frame_key: String = anim.step(delta, ctx)
	var grounded: bool = body.on_ground() if body.has_method("on_ground") else body.is_on_floor()
	lean_up = body.ramp_lean_up if "ramp_lean_up" in body else Vector3.UP
	anchor_extra = body.sprite_anchor_offset() if body.has_method("sprite_anchor_offset") else Vector3.ZERO
	_apply(not grounded, cam)
	body.sprite_frame = frame_key

func _apply(airborne: bool, cam: Camera3D = null) -> void:
	var fr := anim.current_frame()
	if fr.is_empty() or sprite == null:
		return
	var rect: Array = fr.get("rect", [0, 0, 1, 1])
	var off: Array = fr.get("anchor_offset", [0.0, 0.0])
	var w := float(rect[2])
	var h := float(rect[3])
	var px := _px(fr)
	sprite.texture = _puppet_tex(str(fr.get("atlas_file", ""))) if str(fr.get("atlas", "v3")) == "puppet" else tex
	sprite.pixel_size = px
	sprite.region_rect = Rect2(float(rect[0]), float(rect[1]), w, h)
	# anchor_offset is the rect top-left relative to the ground anchor, y down.
	var anchor_x := -float(off[0])
	var anchor_y := -float(off[1])
	var lift := float(fr.get("lift_atlas", 0.0))
	# The painting already raises airborne poses. The capsule is rising too,
	# so drop that gap while the body is in the air.
	if airborne:
		anchor_y -= lift
	var anchor_local := Vector3(0.0, foot_local_y - (lift * px if airborne else 0.0), 0.0)
	depth_shift = 0.0
	depth_offset = Vector3.ZERO
	if depth_fix and cam != null and is_inside_tree():
		var anchor_world := global_transform * anchor_local
		depth_shift = ground_shift(fr, anchor_world, cam.global_position)
		var to_cam := cam.global_position - anchor_world
		var flat := Vector3(to_cam.x, 0.0, to_cam.z)
		if depth_shift > 0.0 and flat.length() > 0.001:
			depth_offset = global_transform.basis.inverse() * (flat.normalized() * depth_shift)
	# Phase 1d: the sideways anchor shift belongs in the billboard plane (Sprite3D.offset is in card
	# pixels along the camera's right), not on the node's local X. On local X it only lined up while
	# the camera looked down -Z; from any other yaw the card slid sideways by a different amount
	# every frame and every view (up to ~0.3 m on the push).
	var side_px := -(anchor_x - w * 0.5)
	sprite.offset = Vector2(side_px if plane_anchor else 0.0, 0.0)
	lean_roll = 0.0
	lean_pitch = 0.0
	if anim.clip.begins_with("qp_"):
		_apply_qp(fr, side_px, anchor_y, h)
		return
	if cam != null and is_inside_tree() and (lean_up.angle_to(Vector3.UP) > 0.01 or anchor_extra.length() > 0.001):
		_apply_lean(cam, Vector3(0.0, foot_local_y, 0.0), (anchor_y - h * 0.5) * px)
		return
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.transform = Transform3D(Basis(), Vector3(
		0.0 if plane_anchor else side_px * px,
		foot_local_y + (anchor_y - h * 0.5) * px,
		0.0
	) + depth_offset)

## Phase 3: qp_ frames draw their rig origin at body_px (master px from the cell anchor, y down); the body hands over the world
## point it belongs on (the lip edge, or the board's contact on the wall) as anchor_extra. Upright Y billboard, no depth shift
## (the bake drew these frames with no shift along the view axis), no card lean (the lean is drawn).
func _apply_qp(fr: Dictionary, side_px: float, anchor_y: float, h: float) -> void:
	var px := _px(fr)
	var sc := _atlas_scale(fr)
	var bp: Array = fr.get("body_px", [0.0, 0.0])
	var bx := float(bp[0]) * sc if bp.size() >= 2 else 0.0
	var by := float(bp[1]) * sc if bp.size() >= 2 else 0.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.offset = Vector2((side_px - bx) if plane_anchor else 0.0, 0.0)
	var extra := global_transform.basis.inverse() * anchor_extra
	sprite.transform = Transform3D(Basis(), Vector3(0.0, foot_local_y + (anchor_y + by - h * 0.5) * px, 0.0) + extra)

## World point of the drawn deck centre (board_px) for the current frame and camera (tests / probes: drawn-board continuity).
func drawn_board_world(cam: Camera3D) -> Vector3:
	var fr := anim.current_frame()
	if fr.is_empty() or sprite == null or cam == null:
		return global_position
	var rect: Array = fr.get("rect", [0, 0, 1, 1])
	var off: Array = fr.get("anchor_offset", [0.0, 0.0])
	var bpx: Array = fr.get("board_px", [0.0, 0.0])
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var up := Vector3.UP
	if sprite.billboard == BaseMaterial3D.BILLBOARD_DISABLED:
		right = sprite.global_transform.basis.x.normalized()
		up = sprite.global_transform.basis.y.normalized()
	var px := _px(fr)
	var sc := _atlas_scale(fr)
	var center := sprite.global_transform.origin + right * sprite.offset.x * px
	var w := float(rect[2])
	var hh := float(rect[3])
	var anchor := center - right * (float(off[0]) + w * 0.5) * px + up * (float(off[1]) + hh * 0.5) * px
	return anchor + right * float(bpx[0]) * sc * px - up * float(bpx[1]) * sc * px

## Phase 2: stand the card on the contact point with its up axis along the (limited) surface normal, facing the camera.
func _apply_lean(cam: Camera3D, anchor_local: Vector3, up_m: float) -> void:
	var anchor_world := global_transform * anchor_local + anchor_extra
	var to_cam := cam.global_position - anchor_world
	var d := Vector3(to_cam.x, 0.0, to_cam.z)
	d = d.normalized() if d.length() > 0.001 else Vector3.BACK
	var x0 := Vector3.UP.cross(d).normalized()
	var u := lean_up.normalized()
	var roll := atan2(u.dot(x0), u.dot(Vector3.UP))
	var pitch := clampf(asin(clampf(u.dot(d), -1.0, 1.0)), -LEAN_MAX_PITCH, LEAN_MAX_PITCH)
	lean_roll = roll
	lean_pitch = pitch
	var y := (x0 * sin(roll) + Vector3.UP * cos(roll)) * cos(pitch) + d * sin(pitch)
	y = y.normalized()
	var z := (d - y * d.dot(y)).normalized()
	var x := y.cross(z).normalized()
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	var world_offset := global_transform.basis * depth_offset
	sprite.global_transform = Transform3D(Basis(x, y, z), anchor_world + y * up_m + world_offset)

## Metres to move the card toward the camera for this frame. The bake drew the body's ground point
## h metres above the anchor on the card; a card x metres nearer the camera shows that point on the
## body's ground spot when x = h * (horizontal camera distance) / (camera height above the anchor).
static func ground_shift(fr: Dictionary, anchor_world: Vector3, cam_pos: Vector3) -> float:
	var gd := float(fr.get("ground_depth_m", 0.0))
	var bp: Array = fr.get("body_px", [0.0, 0.0])
	var h := -float(bp[1]) * float(fr.get("pixel_size", PIXEL)) * float(fr.get("atlas_scale", AnimScript.ATLAS_SCALE)) if bp.size() >= 2 else 0.0
	if gd <= 0.0 or h <= 0.0:
		return 0.0
	var to_cam := cam_pos - anchor_world
	var dh := Vector2(to_cam.x, to_cam.z).length()
	if to_cam.y <= 0.0 or atan2(to_cam.y, dh) < DEPTH_MIN_ELEVATION:
		return gd
	return clampf(h * dh / to_cam.y, gd * 0.5, gd * 2.0)

func _puppet_tex(file: String) -> Texture2D:
	# LOCAL TEST ONLY: puppet-v1 ships one atlas per view group (sides / back / front).
	if file.is_empty():
		return tex_puppet if tex_puppet != null else tex
	if not tex_puppet_files.has(file):
		var path := "res://assets/library/fony2d/" + file
		tex_puppet_files[file] = load(path) if ResourceLoader.exists(path) else null
	var t: Texture2D = tex_puppet_files[file]
	return t if t != null else tex
