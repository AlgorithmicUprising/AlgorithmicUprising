extends Node3D

const Parts = preload("res://scripts/block_parts.gd")

const THIGH := 0.42
const SHIN := 0.42
const SOLE_DROP := 0.065
const STAND_ANKLE_Y := 0.40
const SKATE_ANKLE_Y := 0.505

var pose_name := "idle"
var phase := 0.0
var land_time := 0.0
var was_airborne := false
var trick := ""
var trick_time := 0.0
var flip_turns := 0.0
var board_caught := true
var floor_normal := Vector3.UP
var skeleton: Skeleton3D
var bones: Dictionary = {}
var ankle_l: Node3D
var ankle_r: Node3D
var hand_r: Node3D
var board: Node3D
var anim: AnimationPlayer

var _ankle_y := STAND_ANKLE_Y
var _ankle_z := -0.02
var _lift_l := 0.0
var _lift_r := 0.0
var _step_l := 0.0
var _step_r := 0.0

func _ready() -> void:
	name = "Fony"
	_load_body()
	_build_board()
	_author_clips()
	_idle()
	_solve_legs()
	_sync_markers()
	_place_board(false)

func drive(delta: float, speed: float, skating: bool, airborne: bool, grinding: bool) -> void:
	phase += delta * (7.0 if speed > 0.5 else 1.6)
	if was_airborne and not airborne:
		land_time = 0.2
	was_airborne = airborne
	land_time = maxf(0.0, land_time - delta)
	var swing := sin(phase) if speed > 0.5 and not airborne and not grinding else 0.0
	if trick == "crouch":
		_crouch(clampf(trick_time / 0.62, 0.0, 1.0))
		pose_name = "crouch"
	elif trick == "ollie":
		_ollie_air(trick_time)
	elif trick == "flip":
		_flip_air(trick_time)
	elif trick == "grab":
		_grab()
	elif trick == "bail":
		_bail()
	elif trick == "land" or (land_time > 0.0 and not airborne and skating):
		_land_pose()
	elif land_time > 0.0 and not airborne:
		_idle()
		pose_name = "land"
	elif airborne:
		_jump()
	elif grinding or (skating and speed > 0.8):
		_skate(swing)
	elif speed > 0.5:
		_walk(swing)
	else:
		_idle()
	if not airborne and trick != "bail" and trick != "flip" and trick != "grab":
		var flat_n := Vector3(floor_normal.x, 0.0, floor_normal.z)
		_rot("Spine", Vector3(clampf(-flat_n.length() * 0.35, -0.25, 0.25), 0, 0))
	_solve_legs()
	_sync_markers()
	_place_board(skating or grinding)
	if skeleton != null:
		skeleton.force_update_all_bone_transforms()

func face_world(world_yaw: float) -> void:
	var parent_yaw := 0.0
	if get_parent() != null:
		parent_yaw = get_parent().rotation.y
	rotation.y = wrapf(world_yaw - parent_yaw, -PI, PI)

func sole_y() -> float:
	return ankle_l.global_position.y - SOLE_DROP

func deck_top_y() -> float:
	return board.global_position.y + 0.048

func preview_clip(clip_name: String, at: float) -> float:
	if anim == null or not anim.has_animation(clip_name):
		return -1.0
	anim.play(clip_name)
	anim.seek(at, true)
	return skeleton.get_bone_pose_position(bones.Hips).y

func _skate(_swing: float) -> void:
	pose_name = "skate"
	_hip(1.02)
	_rot("Chest", Vector3(0.35, 0, 0))
	_rot("Head", Vector3(-0.2, 0, 0))
	_arms(0.45, 0.45, -0.8)
	_feet(SKATE_ANKLE_Y, -0.04, 0.0, 0.0, 0.0, 0.0)

func _walk(swing: float) -> void:
	pose_name = "walk"
	_hip(1.08)
	_rot("Chest", Vector3(0.08, 0, 0))
	_rot("Head", Vector3(0, 0, 0))
	_arms(0.15, 0.25, -0.4, swing * 0.6)
	_feet(STAND_ANKLE_Y, -0.02, maxf(swing, 0.0) * 0.08, maxf(-swing, 0.0) * 0.08, -swing * 0.16, swing * 0.16)

func _jump() -> void:
	pose_name = "jump"
	_hip(1.16)
	_rot("Chest", Vector3(-0.2, 0, 0))
	_rot("Head", Vector3(0.1, 0, 0))
	_arms(-1.4, 0.4, -0.3)
	_feet(0.78, 0.02, 0.0, 0.0, 0.0, 0.0)

func _crouch(amount: float) -> void:
	_hip(lerpf(1.02, 0.72, amount))
	_rot("Chest", Vector3(lerpf(0.2, 0.9, amount), 0, 0))
	_rot("Head", Vector3(-0.15, 0, 0))
	_arms(lerpf(0.3, 1.15, amount), 0.35, -0.4)
	_feet(SKATE_ANKLE_Y, -0.06, 0.0, 0.0, 0.0, 0.0)

func _ollie_air(t: float) -> void:
	pose_name = "ollie"
	var tuck := clampf((t - 0.08) / 0.22, 0.0, 1.0)
	_hip(lerpf(0.78, 1.14, clampf(t / 0.16, 0.0, 1.0)))
	_rot("Chest", Vector3(lerpf(0.7, -0.45, clampf(t / 0.2, 0.0, 1.0)), 0, 0))
	_rot("Head", Vector3(0.15, 0, 0))
	_arms(lerpf(0.8, -2.35, clampf(t / 0.18, 0.0, 1.0)), 0.55, -0.25)
	_feet(lerpf(0.52, 0.78, tuck), 0.02, 0.0, 0.0, 0.0, 0.0)

func _flip_air(t: float) -> void:
	pose_name = "flip"
	var tuck := clampf(t / 0.18, 0.0, 1.0)
	_hip(1.12)
	_rot("Chest", Vector3(-0.15, 0, 0))
	_rot("Head", Vector3(0.2, 0, 0))
	_arms(-0.4, 0.9, -0.2, 0.35)
	_feet(lerpf(0.58, 0.8, tuck), 0.06, 0.0, 0.0, 0.0, 0.0)

func _grab() -> void:
	pose_name = "grab"
	_hip(1.05)
	_rot("Chest", Vector3(0.55, 0.2, 0))
	_rot("Head", Vector3(0.35, 0, 0))
	_rot("ArmL", Vector3(-1.2, 0, 0.4))
	_rot("ForeL", Vector3(-0.4, 0, 0))
	_rot("ArmR", Vector3(1.55, 0.35, -0.2))
	_rot("ForeR", Vector3(-1.85, 0, 0))
	_feet(0.74, 0.1, 0.0, 0.0, 0.0, 0.0)

func _land_pose() -> void:
	pose_name = "land"
	_hip(0.74)
	_rot("Chest", Vector3(0.85, 0, 0))
	_rot("Head", Vector3(-0.1, 0, 0))
	_arms(0.7, 0.7, -0.35)
	_feet(SKATE_ANKLE_Y, -0.02, 0.0, 0.0, 0.0, 0.0)

func _bail() -> void:
	pose_name = "bail"
	_hip(0.9)
	_rot("Chest", Vector3(1.0, 0, 0.4))
	_rot("Head", Vector3(0.4, 0, 0))
	_arms(1.1, 0.8, -0.2, 0.7)
	_feet(0.7, 0.15, 0.08, 0.0, 0.12, -0.08)

func _idle() -> void:
	pose_name = "idle"
	var breathe := sin(phase) * 0.03
	_hip(1.08)
	_rot("Chest", Vector3(breathe, 0, 0))
	_rot("Head", Vector3(-breathe, 0, 0))
	_arms(0.12, 0.28, -0.35)
	_feet(STAND_ANKLE_Y, -0.02, 0.0, 0.0, 0.0, 0.0)

func _feet(ankle_y: float, ankle_z: float, lift_l: float, lift_r: float, step_l: float, step_r: float) -> void:
	_ankle_y = ankle_y
	_ankle_z = ankle_z
	_lift_l = lift_l
	_lift_r = lift_r
	_step_l = step_l
	_step_r = step_r

func _arms(pitch: float, spread: float, elbow: float, oppose := 0.0) -> void:
	_rot("ArmL", Vector3(pitch - oppose, 0, spread))
	_rot("ArmR", Vector3(pitch + oppose, 0, -spread))
	_rot("ForeL", Vector3(elbow, 0, 0))
	_rot("ForeR", Vector3(elbow, 0, 0))

func _hip(y: float) -> void:
	skeleton.set_bone_pose_position(bones.Hips, Vector3(0, y, 0))

func _rot(bone_name: String, euler: Vector3) -> void:
	skeleton.set_bone_pose_rotation(bones[bone_name], Quaternion.from_euler(euler))

func _solve_legs() -> void:
	_aim("LegL", "ShinL", -0.08, _ankle_y + _lift_l, _ankle_z + _step_l)
	_aim("LegR", "ShinR", 0.08, _ankle_y + _lift_r, _ankle_z + _step_r)

func _aim(leg_name: String, shin_name: String, _side: float, ankle_y: float, ankle_z: float) -> void:
	var hip_y: float = skeleton.get_bone_pose_position(bones.Hips).y + skeleton.get_bone_pose_position(bones[leg_name]).y
	var target := Vector3(0.0, ankle_y - hip_y, ankle_z)
	var dist := clampf(target.length(), 0.12, THIGH + SHIN - 0.02)
	var dir := atan2(-target.z, -target.y)
	var cos_hip := (THIGH * THIGH + dist * dist - SHIN * SHIN) / (2.0 * THIGH * dist)
	var hip_bend := acos(clampf(cos_hip, -1.0, 1.0))
	_rot(leg_name, Vector3(dir + hip_bend, 0, 0))
	var cos_knee := (THIGH * THIGH + SHIN * SHIN - dist * dist) / (2.0 * THIGH * SHIN)
	var knee := acos(clampf(cos_knee, -1.0, 1.0))
	_rot(shin_name, Vector3(-(PI - knee), 0, 0))

func _sync_markers() -> void:
	ankle_l.position = Vector3(-0.08, _ankle_y + _lift_l, _ankle_z + _step_l)
	ankle_r.position = Vector3(0.08, _ankle_y + _lift_r, _ankle_z + _step_r)
	if skeleton != null:
		skeleton.force_update_all_bone_transforms()
		hand_r.position = skeleton.get_bone_global_pose(bones.HandR).origin

func _place_board(under_feet: bool) -> void:
	board.visible = true
	if trick == "flip" and not board_caught:
		board.position = Vector3(0.22, 0.42, 0.05)
		board.rotation = Vector3(0.0, 0.0, flip_turns * TAU)
		return
	if trick == "grab":
		board.position = hand_r.position + Vector3(0.02, -0.02, -0.04)
		board.rotation = Vector3(0.9, 0.3, 1.15)
		return
	if trick == "bail":
		board.position = Vector3(0.55, 0.28, 0.2)
		board.rotation = Vector3(0.4, 0.8, 1.4)
		return
	if under_feet:
		var deck_y := _ankle_y - SOLE_DROP - 0.048
		board.position = Vector3(0.0, deck_y, _ankle_z)
		board.rotation = Vector3.ZERO
	else:
		board.position = Vector3(0.34, 0.95, 0.02)
		board.rotation = Vector3(0.15, 0.5, 1.2)

func _apply_clip() -> void:
	if anim == null:
		return
	var clip_name := trick if trick != "" else ""
	if clip_name == "" or not anim.has_animation(clip_name):
		if anim.is_playing():
			anim.stop()
		return
	# The pose functions above are what the camera shows. Seeking the matching
	# clip first keeps the AnimationPlayer in sync; the pose is reapplied if a
	# track would otherwise leave the body in the bind pose.
	var hip_before: float = skeleton.get_bone_pose_position(bones.Hips).y
	if anim.current_animation != clip_name:
		anim.play(clip_name)
	var clip := anim.get_animation(clip_name)
	anim.seek(minf(trick_time, clip.length), true)
	if absf(skeleton.get_bone_pose_position(bones.Hips).y - hip_before) > 0.45:
		_hip(hip_before)

func _author_clips() -> void:
	anim = AnimationPlayer.new()
	anim.name = "Clips"
	anim.root_node = NodePath("..")
	add_child(anim)
	var lib := AnimationLibrary.new()
	lib.add_animation("crouch", _clip(0.62, 1.02, 0.72, Vector3(0.2, 0, 0), Vector3(0.9, 0, 0), Vector3(0.4, 0, 0.4), Vector3(1.1, 0, 0.35)))
	lib.add_animation("ollie", _clip(0.7, 0.78, 1.14, Vector3(0.6, 0, 0), Vector3(-0.45, 0, 0), Vector3(0.6, 0, 0.4), Vector3(-2.2, 0, 0.5)))
	lib.add_animation("flip", _clip(1.0, 1.02, 1.12, Vector3(0.2, 0, 0), Vector3(-0.15, 0, 0), Vector3(0.3, 0, 0.4), Vector3(-0.4, 0, 0.9)))
	lib.add_animation("grab", _clip(0.8, 1.02, 1.05, Vector3(0.2, 0, 0), Vector3(0.55, 0.2, 0), Vector3(0.3, 0, 0.3), Vector3(1.35, 0.2, -0.15)))
	lib.add_animation("land", _clip(0.48, 1.02, 0.74, Vector3(0.2, 0, 0), Vector3(0.85, 0, 0), Vector3(0.3, 0, 0.3), Vector3(0.7, 0, 0.7)))
	lib.add_animation("bail", _clip(0.7, 1.02, 0.9, Vector3(0.2, 0, 0), Vector3(1.0, 0, 0.4), Vector3(0.3, 0, 0.3), Vector3(1.1, 0, 0.8)))
	anim.add_animation_library("", lib)

func _clip(length: float, hip_a: float, hip_b: float, chest_a: Vector3, chest_b: Vector3, arm_a: Vector3, arm_b: Vector3) -> Animation:
	var clip := Animation.new()
	clip.length = length
	var pos := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(pos, NodePath("Skeleton:Hips"))
	clip.position_track_insert_key(pos, 0.0, Vector3(0, hip_a, 0))
	clip.position_track_insert_key(pos, length, Vector3(0, hip_b, 0))
	_rot_keys(clip, "Skeleton:Chest", chest_a, chest_b)
	_rot_keys(clip, "Skeleton:ArmL", arm_a, arm_b)
	_rot_keys(clip, "Skeleton:ArmR", Vector3(arm_a.x, arm_a.y, -arm_a.z), Vector3(arm_b.x, arm_b.y, -arm_b.z))
	return clip

func _rot_keys(clip: Animation, path: String, a: Vector3, b: Vector3) -> void:
	var track := clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(track, NodePath(path))
	clip.rotation_track_insert_key(track, 0.0, Quaternion.from_euler(a))
	clip.rotation_track_insert_key(track, clip.length, Quaternion.from_euler(b))

func _load_body() -> void:
	var packed: PackedScene = load("res://assets/library/fony/fony.glb")
	var model := packed.instantiate()
	model.name = "Model"
	add_child(model)
	skeleton = _find_skeleton(model)
	skeleton.name = "Skeleton"
	skeleton.reparent(self)
	var bone_names := ["Hips", "Spine", "Chest", "Neck", "Head", "ArmL", "ForeL", "HandL", "ArmR", "ForeR", "HandR", "LegL", "ShinL", "AnkleL", "LegR", "ShinR", "AnkleR"]
	for bone_name in bone_names:
		bones[bone_name] = skeleton.find_bone(bone_name)
	_paint(model)
	_paint(skeleton)
	for inst in _mesh_instances(model):
		inst.skeleton = inst.get_path_to(skeleton)
	for inst in _mesh_instances(skeleton):
		inst.skeleton = NodePath("..")
	ankle_l = Marker3D.new()
	ankle_l.name = "AnkleL"
	add_child(ankle_l)
	ankle_r = Marker3D.new()
	ankle_r.name = "AnkleR"
	add_child(ankle_r)
	hand_r = Marker3D.new()
	hand_r.name = "HandR"
	add_child(hand_r)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _mesh_instances(node: Node) -> Array:
	var found: Array = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_mesh_instances(child))
	return found

func _paint(node: Node) -> void:
	if node is MeshInstance3D:
		var color := Color("f0c9a0")
		var key := str(node.name)
		if key.contains("Hair"):
			color = Color("c4622d")
		elif key.contains("Hoodie"):
			color = Color("1a1a1e")
		elif key.contains("Jacket"):
			color = Color("c46a32")
		elif key.contains("Pants") or key.contains("Pocket"):
			color = Color("5c6b3a")
		elif key.contains("Pad") or key.contains("PatchPink"):
			color = Color("e23d78")
		elif key.contains("PatchGray"):
			color = Color("6a727a")
		elif key.contains("Shoe"):
			color = Color("c4b5a0")
		elif key.contains("Sole") or key.contains("Stripe") or key.contains("Strap"):
			color = Color("2a211c")
		elif key.contains("Brow"):
			color = Color("6a3a22")
		elif key.contains("Iris"):
			color = Color("4a2c1c")
		elif key.contains("Sclera"):
			color = Color("f4f0ea")
		elif key.contains("Lip"):
			color = Color("b85a52")
		node.material_override = load("res://scripts/world_blocks.gd").cel(color, 3.0, 0.22)
	for child in node.get_children():
		_paint(child)

func _build_board() -> void:
	board = Parts.pivot(self, "Deck", Vector3(0, 0.39, -0.02))
	Parts.box(board, "DeckWood", Vector3(0.22, 0.04, 0.78), Color("4a3428"), Vector3(0, 0.02, 0))
	Parts.box(board, "Nose", Vector3(0.2, 0.028, 0.1), Color("c46a32"), Vector3(0, 0.035, -0.34))
	Parts.box(board, "Tail", Vector3(0.2, 0.028, 0.1), Color("c46a32"), Vector3(0, 0.035, 0.34))
	Parts.box(board, "Grip", Vector3(0.18, 0.012, 0.52), Color("1c1b1a"), Vector3(0, 0.046, 0))
	Parts.box(board, "TruckF", Vector3(0.16, 0.028, 0.05), Color("c8c2b8"), Vector3(0, -0.01, -0.18))
	Parts.box(board, "TruckB", Vector3(0.16, 0.028, 0.05), Color("c8c2b8"), Vector3(0, -0.01, 0.18))
	for side in [-1.0, 1.0]:
		for axle in [-0.18, 0.18]:
			Parts.cylinder(board, "Wheel", 0.04, 0.045, Color("ece7df"), Vector3(side * 0.11, -0.03, axle), Vector3(0, 0, PI * 0.5))
