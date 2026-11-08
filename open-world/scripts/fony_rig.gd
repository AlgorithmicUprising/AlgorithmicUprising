extends Node3D

const Parts = preload("res://scripts/block_parts.gd")

# Player capsule bottom in this rig's local space (shape at y=0.9, height 1.15).
const GROUND_Y := 0.325
const THIGH := 0.42
const SHIN := 0.42
const SOLE_DROP := 0.065
const STAND_ANKLE_Y := 0.40
const SKATE_ANKLE_Y := 0.505

var pose_name := "idle"
var phase := 0.0
var land_time := 0.0
var was_airborne := false
var hips: Node3D
var chest: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var ankle_l: Node3D
var ankle_r: Node3D
var board: Node3D
var trick := ""
var trick_time := 0.0
var flip_turns := 0.0
var board_caught := true
var floor_normal := Vector3.UP
var anim: AnimationPlayer

func _ready() -> void:
	name = "Fony"
	_build()

func drive(delta: float, speed: float, skating: bool, airborne: bool, grinding: bool) -> void:
	phase += delta * (7.0 if speed > 0.5 else 1.6)
	if was_airborne and not airborne:
		land_time = 0.2
	was_airborne = airborne
	land_time = max(0.0, land_time - delta)
	var swing := sin(phase) if speed > 0.5 and not airborne and not grinding else 0.0
	if trick == "crouch":
		_crouch(1.0)
		pose_name = "crouch"
	elif trick == "ollie":
		_ollie()
	elif trick == "flip":
		_ollie()
		pose_name = "flip"
		_feet(0.72, 0.08, 0.0, 0.0, 0.0, 0.0)
	elif trick == "grab":
		_grab()
	elif trick == "bail":
		_bail()
	elif trick == "land" or (land_time > 0.0 and not airborne):
		_crouch(0.85)
		pose_name = "land"
	elif airborne:
		_jump()
	elif grinding or (skating and speed > 0.8):
		_skate(swing)
	elif speed > 0.5:
		_walk(swing)
	else:
		_idle()
	_apply_authored(trick if trick != "" else pose_name)
	if trick == "flip":
		_feet(0.9, 0.04, 0.0, 0.0, 0.0, 0.0)
		_solve_legs()
	if not airborne and trick != "bail":
		var flat_n := Vector3(floor_normal.x, 0.0, floor_normal.z)
		rotation.x = clampf(-flat_n.length() * 0.45, -0.35, 0.35)
	_place_board(skating or grinding)
	if trick != "flip" and trick != "grab" and trick != "bail":
		_solve_legs()

func face_world(world_yaw: float) -> void:
	var parent_yaw := 0.0
	if get_parent() != null:
		parent_yaw = get_parent().rotation.y
	rotation.y = wrapf(world_yaw - parent_yaw, -PI, PI)

func sole_y() -> float:
	return ankle_l.global_position.y - SOLE_DROP

func deck_top_y() -> float:
	return board.global_position.y + 0.048

func _skate(_swing: float) -> void:
	pose_name = "skate"
	hips.position.y = 1.08
	chest.rotation.x = 0.28
	head.rotation.x = -0.16
	_arms(0.35, 0.55, -0.7)
	_feet(SKATE_ANKLE_Y, -0.04, 0.0, 0.0, 0.0, 0.0)

func _walk(swing: float) -> void:
	pose_name = "walk"
	hips.position.y = 1.20
	chest.rotation.x = 0.06
	head.rotation.x = 0.0
	_arms(0.1, 0.18, -0.45, swing * 0.55)
	_feet(STAND_ANKLE_Y, -0.02, max(swing, 0.0) * 0.1, max(-swing, 0.0) * 0.1, -swing * 0.2, swing * 0.2)

func _jump() -> void:
	pose_name = "jump"
	hips.position.y = 1.22
	chest.rotation.x = -0.12
	head.rotation.x = 0.08
	_arms(-0.9, 0.35, -0.45)
	_feet(0.78, 0.05, 0.0, 0.0, 0.0, 0.0)

func _crouch(amount: float) -> void:
	hips.position.y = lerpf(1.20, 1.00, amount)
	chest.rotation.x = 0.4 * amount
	head.rotation.x = -0.08
	_arms(0.35, 0.35, -0.5)
	_feet(STAND_ANKLE_Y, -0.05, 0.0, 0.0, 0.0, 0.0)

func _idle() -> void:
	pose_name = "idle"
	var breathe := sin(phase) * 0.03
	hips.position.y = 1.20
	chest.rotation.x = breathe
	head.rotation.x = -breathe
	_arms(0.12, 0.22, -0.45)
	_feet(STAND_ANKLE_Y, -0.02, 0.0, 0.0, 0.0, 0.0)

var _ankle_y := STAND_ANKLE_Y
var _ankle_z := -0.02
var _lift_l := 0.0
var _lift_r := 0.0
var _step_l := 0.0
var _step_r := 0.0

func _feet(ankle_y: float, ankle_z: float, lift_l: float, lift_r: float, step_l: float, step_r: float) -> void:
	_ankle_y = ankle_y
	_ankle_z = ankle_z
	_lift_l = lift_l
	_lift_r = lift_r
	_step_l = step_l
	_step_r = step_r

func _arms(pitch: float, spread: float, elbow: float, oppose := 0.0) -> void:
	arm_l.rotation = Vector3(pitch - oppose, 0.0, spread)
	arm_r.rotation = Vector3(pitch + oppose, 0.0, -spread)
	fore_l.rotation = Vector3(elbow, 0.0, 0.0)
	fore_r.rotation = Vector3(elbow, 0.0, 0.0)

func _solve_legs() -> void:
	_aim(leg_l, shin_l, _ankle_y + _lift_l, _ankle_z + _step_l)
	_aim(leg_r, shin_r, _ankle_y + _lift_r, _ankle_z + _step_r)

func _aim(leg: Node3D, shin: Node3D, ankle_y: float, ankle_z: float) -> void:
	var hip_y: float = hips.position.y + leg.position.y
	var target := Vector3(0.0, ankle_y - hip_y, ankle_z)
	var dist := clampf(target.length(), 0.12, THIGH + SHIN - 0.02)
	var dir := atan2(-target.z, -target.y)
	var cos_hip := (THIGH * THIGH + dist * dist - SHIN * SHIN) / (2.0 * THIGH * dist)
	var hip_bend := acos(clampf(cos_hip, -1.0, 1.0))
	leg.rotation = Vector3(dir + hip_bend, 0.0, 0.0)
	var cos_knee := (THIGH * THIGH + SHIN * SHIN - dist * dist) / (2.0 * THIGH * SHIN)
	var knee := acos(clampf(cos_knee, -1.0, 1.0))
	shin.rotation = Vector3(-(PI - knee), 0.0, 0.0)

func _ollie() -> void:
	pose_name = "ollie"
	hips.position.y = 1.16
	chest.rotation.x = -0.25
	head.rotation.x = 0.12
	_arms(-1.05, 0.35, -0.35)
	_feet(0.78, -0.02, 0.0, 0.0, 0.0, 0.0)

func _grab() -> void:
	pose_name = "grab"
	hips.position.y = 1.12
	chest.rotation.x = 0.35
	head.rotation.x = 0.1
	_arms(0.2, 0.2, -0.9, 0.8)
	_feet(0.7, 0.02, 0.0, 0.0, 0.0, 0.0)

func _bail() -> void:
	pose_name = "bail"
	hips.position.y = 1.05
	chest.rotation.x = 0.7
	head.rotation.x = 0.3
	_arms(0.8, 0.5, -0.2, 0.6)
	_feet(0.62, 0.12, 0.05, 0.0, 0.1, -0.05)

func _place_board(under_feet: bool) -> void:
	board.visible = true
	if trick == "flip" and not board_caught:
		board.position = Vector3(0.0, 0.42, 0.02)
		board.rotation = Vector3(flip_turns * TAU, 0.15, 0.0)
		return
	if trick == "grab":
		board.position = Vector3(0.28, 1.15, -0.12)
		board.rotation = Vector3(0.5, 0.4, 1.35)
		return
	if trick == "bail":
		board.position = Vector3(0.42, 0.35, 0.18)
		board.rotation = Vector3(1.1, 0.8, 0.6)
		return
	if under_feet:
		board.position = Vector3(0.0, 0.39, -0.02)
		board.rotation = Vector3.ZERO
	else:
		board.position = Vector3(0.36, 1.05, 0.02)
		board.rotation = Vector3(0.1, 0.4, 1.15)

func _torso(parent: Node, node_name: String, top: Vector3, bottom: Vector3, color: Color, at: Vector3) -> MeshInstance3D:
	var height := maxf(top.y, bottom.y)
	var y0 := -height * 0.5
	var y1 := height * 0.5
	var verts := PackedVector3Array([
		Vector3(-bottom.x * 0.5, y0, -bottom.z * 0.5), Vector3(bottom.x * 0.5, y0, -bottom.z * 0.5),
		Vector3(bottom.x * 0.5, y0, bottom.z * 0.5), Vector3(-bottom.x * 0.5, y0, bottom.z * 0.5),
		Vector3(-top.x * 0.5, y1, -top.z * 0.5), Vector3(top.x * 0.5, y1, -top.z * 0.5),
		Vector3(top.x * 0.5, y1, top.z * 0.5), Vector3(-top.x * 0.5, y1, top.z * 0.5),
	])
	var idx := PackedInt32Array([
		0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7,
		0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5,
		2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7,
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = _paint(color)
	parent.add_child(node)
	return node

func _paint(color: Color) -> Material:
	return load("res://scripts/world_blocks.gd").cel(color, 3.0, 0.2)

func _face(parent: Node) -> void:
	var tex: Texture2D = load("res://assets/library/fony/face_albedo.png")
	var quad := MeshInstance3D.new()
	quad.name = "Face"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.14, 0.16)
	quad.mesh = mesh
	quad.position = Vector3(0, 0.08, -0.09)
	if tex != null:
		quad.material_override = load("res://scripts/world_blocks.gd").cel_textured(Color.WHITE, tex, 2.0, 0.05)
	else:
		quad.material_override = _paint(Color("f0c9a0"))
	parent.add_child(quad)

func _hair(parent: Node, color: Color) -> void:
	_torso(parent, "Hair", Vector3(0.2, 0.1, 0.18), Vector3(0.18, 0.08, 0.16), color, Vector3(0, 0.14, 0.01))
	_torso(parent, "Tuft", Vector3(0.07, 0.12, 0.07), Vector3(0.05, 0.08, 0.05), color, Vector3(0.05, 0.18, -0.02))
	_torso(parent, "TuftSide", Vector3(0.06, 0.1, 0.06), Vector3(0.05, 0.06, 0.05), color, Vector3(-0.08, 0.14, 0.0))

func _author_clips() -> void:
	anim = AnimationPlayer.new()
	anim.name = "Clips"
	anim.root_node = NodePath("..")
	add_child(anim)
	var lib := AnimationLibrary.new()
	lib.add_animation("crouch", _pose_clip(0.16, 0.98, Vector3(0.5, 0, 0), Vector3(0.4, 0, 0.3), Vector3(0.9, 0, 0), Vector3(-1.2, 0, 0)))
	lib.add_animation("ollie", _pose_clip(0.45, 1.16, Vector3(-0.25, 0, 0), Vector3(-1.05, 0, 0.35), Vector3(-0.35, 0, 0), Vector3(0.85, 0, 0)))
	lib.add_animation("flip", _pose_clip(0.55, 1.16, Vector3(-0.2, 0, 0), Vector3(-0.4, 0, 0.8), Vector3(-0.2, 0, 0), Vector3(0.7, 0, 0)))
	lib.add_animation("grab", _pose_clip(0.4, 1.12, Vector3(0.35, 0, 0), Vector3(-0.3, 0, 0.9), Vector3(-0.2, 0, 0), Vector3(0.6, 0, 0)))
	lib.add_animation("land", _pose_clip(0.22, 1.0, Vector3(0.45, 0, 0), Vector3(0.35, 0, 0.3), Vector3(0.8, 0, 0), Vector3(-1.15, 0, 0)))
	lib.add_animation("bail", _pose_clip(0.6, 1.05, Vector3(0.7, 0, 0), Vector3(0.8, 0, 0.5), Vector3(0.4, 0, 0), Vector3(-0.4, 0, 0)))
	anim.add_animation_library("", lib)

func _pose_clip(length: float, hip_y: float, chest: Vector3, arm: Vector3, thigh: Vector3, shin: Vector3) -> Animation:
	var clip := Animation.new()
	clip.length = length
	var pos := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(pos, NodePath("Hips:position"))
	clip.position_track_insert_key(pos, 0.0, Vector3(0, hip_y, 0))
	clip.position_track_insert_key(pos, length, Vector3(0, hip_y, 0))
	_rot_key(clip, "Hips/Chest", chest)
	_rot_key(clip, "Hips/Chest/ArmL", arm)
	_rot_key(clip, "Hips/Chest/ArmR", Vector3(arm.x, arm.y, -arm.z))
	_rot_key(clip, "Hips/LegL", thigh)
	_rot_key(clip, "Hips/LegR", thigh)
	_rot_key(clip, "Hips/LegL/ShinL", shin)
	_rot_key(clip, "Hips/LegR/ShinR", shin)
	return clip

func _rot_key(clip: Animation, path: String, rot: Vector3) -> void:
	var track := clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(track, NodePath(path + ":rotation"))
	var quat := Quaternion.from_euler(rot)
	clip.rotation_track_insert_key(track, 0.0, quat)
	clip.rotation_track_insert_key(track, clip.length, quat)

func _apply_authored(which: String) -> void:
	if anim == null:
		return
	if trick == "" or not anim.has_animation(which):
		if anim.is_playing():
			anim.stop()
		return
	if anim.current_animation != which:
		anim.play(which)
	var clip := anim.get_animation(which)
	anim.seek(minf(trick_time, clip.length), true)

func _limb(parent: Node, node_name: String, radius: float, length: float, color: Color) -> MeshInstance3D:
	return Parts.capsule(parent, node_name, radius, length, color, Vector3(0, -length * 0.5, 0))

func _build() -> void:
	var skin := Color("f0c9a0")
	var hair := Color("c4622d")
	var jacket := Color("c46a32")
	var hoodie := Color("1a1a1e")
	var pants := Color("5c6b3a")
	var pads := Color("e23d78")
	var shoes := Color("8a7564")
	hips = Parts.pivot(self, "Hips", Vector3(0, 1.20, 0))
	_torso(hips, "Pelvis", Vector3(0.28, 0.16, 0.2), Vector3(0.22, 0.12, 0.16), pants, Vector3(0, 0.02, 0))
	chest = Parts.pivot(hips, "Chest", Vector3(0, 0.18, 0))
	_torso(chest, "Hoodie", Vector3(0.24, 0.42, 0.16), Vector3(0.2, 0.36, 0.14), hoodie, Vector3(0, -0.02, 0.01))
	_torso(chest, "Jacket", Vector3(0.4, 0.5, 0.24), Vector3(0.32, 0.42, 0.2), jacket, Vector3(0, -0.04, 0))
	Parts.box(chest, "Patch", Vector3(0.07, 0.06, 0.02), Color("6a727a"), Vector3(0.1, 0.08, -0.1))
	Parts.box(chest, "Tape", Vector3(0.05, 0.04, 0.02), pads, Vector3(-0.1, 0.0, -0.1))
	_torso(chest, "Neck", Vector3(0.09, 0.16, 0.09), Vector3(0.1, 0.14, 0.1), skin, Vector3(0, 0.2, 0))
	head = Parts.pivot(chest, "Head", Vector3(0, 0.26, 0))
	_torso(head, "Skull", Vector3(0.18, 0.2, 0.18), Vector3(0.16, 0.18, 0.17), skin, Vector3(0, 0.06, 0))
	_face(head)
	_hair(head, hair)
	_torso(head, "Hood", Vector3(0.18, 0.1, 0.16), Vector3(0.16, 0.08, 0.14), hoodie, Vector3(0, 0.06, 0.04))
	arm_l = Parts.pivot(chest, "ArmL", Vector3(-0.18, 0.12, 0))
	fore_l = Parts.pivot(arm_l, "ForeL", Vector3(0, -0.28, 0))
	_torso(arm_l, "SleeveL", Vector3(0.1, 0.28, 0.1), Vector3(0.08, 0.24, 0.08), jacket, Vector3(0, -0.14, 0))
	_torso(fore_l, "ForearmL", Vector3(0.08, 0.26, 0.08), Vector3(0.06, 0.22, 0.06), jacket, Vector3(0, -0.13, 0))
	Parts.box(fore_l, "HandL", Vector3(0.06, 0.07, 0.04), skin, Vector3(0, -0.26, -0.01))
	arm_r = Parts.pivot(chest, "ArmR", Vector3(0.18, 0.12, 0))
	fore_r = Parts.pivot(arm_r, "ForeR", Vector3(0, -0.28, 0))
	_torso(arm_r, "SleeveR", Vector3(0.1, 0.28, 0.1), Vector3(0.08, 0.24, 0.08), jacket, Vector3(0, -0.14, 0))
	_torso(fore_r, "ForearmR", Vector3(0.08, 0.26, 0.08), Vector3(0.06, 0.22, 0.06), jacket, Vector3(0, -0.13, 0))
	Parts.box(fore_r, "HandR", Vector3(0.06, 0.07, 0.04), skin, Vector3(0, -0.26, -0.01))
	leg_l = Parts.pivot(hips, "LegL", Vector3(-0.08, -0.04, 0))
	shin_l = Parts.pivot(leg_l, "ShinL", Vector3(0, -THIGH, 0))
	ankle_l = Parts.pivot(shin_l, "AnkleL", Vector3(0, -SHIN, 0))
	_torso(leg_l, "ThighL", Vector3(0.14, 0.42, 0.13), Vector3(0.11, 0.36, 0.11), pants, Vector3(0, -0.21, 0))
	Parts.box(leg_l, "CargoL", Vector3(0.08, 0.07, 0.04), Color("3f4a2c"), Vector3(-0.06, -0.12, -0.04))
	Parts.box(shin_l, "PadL", Vector3(0.1, 0.08, 0.04), pads, Vector3(0, -0.02, -0.06))
	_torso(shin_l, "ShinMeshL", Vector3(0.11, 0.42, 0.1), Vector3(0.08, 0.36, 0.08), pants, Vector3(0, -0.21, 0))
	Parts.box(ankle_l, "ShoeL", Vector3(0.1, 0.06, 0.24), shoes, Vector3(0, -0.02, -0.05))
	Parts.box(ankle_l, "StripeL", Vector3(0.04, 0.02, 0.16), Color("2a211c"), Vector3(0, 0.02, -0.04))
	leg_r = Parts.pivot(hips, "LegR", Vector3(0.08, -0.04, 0))
	shin_r = Parts.pivot(leg_r, "ShinR", Vector3(0, -THIGH, 0))
	ankle_r = Parts.pivot(shin_r, "AnkleR", Vector3(0, -SHIN, 0))
	_torso(leg_r, "ThighR", Vector3(0.14, 0.42, 0.13), Vector3(0.11, 0.36, 0.11), pants, Vector3(0, -0.21, 0))
	Parts.box(leg_r, "CargoR", Vector3(0.08, 0.07, 0.04), Color("3f4a2c"), Vector3(0.06, -0.12, -0.04))
	Parts.box(shin_r, "PadR", Vector3(0.1, 0.08, 0.04), pads, Vector3(0, -0.02, -0.06))
	_torso(shin_r, "ShinMeshR", Vector3(0.11, 0.42, 0.1), Vector3(0.08, 0.36, 0.08), pants, Vector3(0, -0.21, 0))
	Parts.box(ankle_r, "ShoeR", Vector3(0.1, 0.06, 0.24), shoes, Vector3(0, -0.02, -0.05))
	Parts.box(ankle_r, "StripeR", Vector3(0.04, 0.02, 0.16), Color("2a211c"), Vector3(0, 0.02, -0.04))
	board = Parts.pivot(self, "Deck", Vector3(0, 0.39, -0.02))
	Parts.box(board, "DeckWood", Vector3(0.32, 0.036, 0.9), Color("4a3428"), Vector3(0, 0.03, 0))
	Parts.box(board, "Nose", Vector3(0.3, 0.028, 0.12), Color("c46a32"), Vector3(0, 0.04, -0.36))
	Parts.box(board, "Tail", Vector3(0.3, 0.028, 0.12), Color("c46a32"), Vector3(0, 0.04, 0.36))
	Parts.box(board, "Grip", Vector3(0.26, 0.01, 0.6), Color("2c2a28"), Vector3(0, 0.052, 0))
	Parts.box(board, "TruckF", Vector3(0.18, 0.025, 0.05), Color("c8c2b8"), Vector3(0, 0.0, -0.22))
	Parts.box(board, "TruckB", Vector3(0.18, 0.025, 0.05), Color("c8c2b8"), Vector3(0, 0.0, 0.22))
	for side in [-1.0, 1.0]:
		for axle in [-0.22, 0.22]:
			Parts.cylinder(board, "Wheel", 0.042, 0.05, Color("ece7df"), Vector3(side * 0.15, -0.01, axle), Vector3(0, 0, PI * 0.5))
	_author_clips()
	_idle()
	_place_board(true)
	_solve_legs()
