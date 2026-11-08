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
	if airborne:
		_jump()
	elif grinding or (skating and speed > 0.8):
		_skate(swing)
	elif land_time > 0.0:
		_crouch(0.7)
		pose_name = "land"
	elif speed > 0.5:
		_walk(swing)
	else:
		_idle()
	_place_board(skating or grinding)
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

func _place_board(under_feet: bool) -> void:
	board.visible = true
	if under_feet:
		board.position = Vector3(0.0, 0.39, -0.02)
		board.rotation = Vector3.ZERO
	else:
		board.position = Vector3(0.36, 1.05, 0.02)
		board.rotation = Vector3(0.1, 0.4, 1.15)

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
	Parts.sphere(hips, "Pelvis", 0.13, pants, Vector3(0, 0.02, 0))
	chest = Parts.pivot(hips, "Chest", Vector3(0, 0.20, 0))
	Parts.capsule(chest, "Hoodie", 0.09, 0.42, hoodie, Vector3(0, -0.02, 0.01))
	Parts.capsule(chest, "Jacket", 0.15, 0.50, jacket, Vector3(0, -0.02, 0))
	Parts.box(chest, "Patch", Vector3(0.07, 0.06, 0.02), Color("6a727a"), Vector3(0.08, 0.12, -0.14))
	Parts.box(chest, "Tape", Vector3(0.05, 0.04, 0.02), pads, Vector3(-0.08, 0.02, -0.14))
	Parts.capsule(chest, "Collar", 0.1, 0.24, hoodie, Vector3(0, 0.16, 0))
	Parts.capsule(chest, "Neck", 0.06, 0.26, skin, Vector3(0, 0.2, 0))
	head = Parts.pivot(chest, "Head", Vector3(0, 0.28, 0))
	Parts.sphere(head, "Face", 0.12, skin, Vector3(0, 0.05, -0.015))
	Parts.sphere(head, "Nose", 0.022, skin, Vector3(0, 0.03, -0.13))
	Parts.sphere(head, "EyeL", 0.022, Color("2a211c"), Vector3(-0.04, 0.07, -0.12))
	Parts.sphere(head, "EyeR", 0.022, Color("2a211c"), Vector3(0.04, 0.07, -0.12))
	Parts.capsule(head, "Mouth", 0.01, 0.045, Color("a56858"), Vector3(0, -0.01, -0.125), Vector3(0, 0, PI * 0.5))
	Parts.sphere(head, "Hair", 0.11, hair, Vector3(0, 0.1, 0.03))
	Parts.sphere(head, "Tuft", 0.05, hair, Vector3(0.05, 0.16, 0.0))
	Parts.sphere(head, "TuftSide", 0.045, hair, Vector3(-0.07, 0.11, 0.0))
	Parts.sphere(head, "Hood", 0.07, hoodie, Vector3(0, 0.06, 0.07))
	arm_l = Parts.pivot(chest, "ArmL", Vector3(-0.14, 0.12, 0))
	fore_l = Parts.pivot(arm_l, "ForeL", Vector3(0, -0.30, 0))
	Parts.sphere(chest, "ShoulderL", 0.08, jacket, arm_l.position)
	_limb(arm_l, "SleeveL", 0.058, 0.30, jacket)
	Parts.sphere(arm_l, "ElbowL", 0.065, jacket, fore_l.position)
	_limb(fore_l, "ForearmL", 0.05, 0.28, jacket)
	Parts.sphere(fore_l, "HandL", 0.048, skin, Vector3(0, -0.28, 0))
	arm_r = Parts.pivot(chest, "ArmR", Vector3(0.14, 0.12, 0))
	fore_r = Parts.pivot(arm_r, "ForeR", Vector3(0, -0.30, 0))
	Parts.sphere(chest, "ShoulderR", 0.08, jacket, arm_r.position)
	_limb(arm_r, "SleeveR", 0.058, 0.30, jacket)
	Parts.sphere(arm_r, "ElbowR", 0.065, jacket, fore_r.position)
	_limb(fore_r, "ForearmR", 0.05, 0.28, jacket)
	Parts.sphere(fore_r, "HandR", 0.048, skin, Vector3(0, -0.28, 0))
	leg_l = Parts.pivot(hips, "LegL", Vector3(-0.08, -0.04, 0))
	shin_l = Parts.pivot(leg_l, "ShinL", Vector3(0, -THIGH, 0))
	ankle_l = Parts.pivot(shin_l, "AnkleL", Vector3(0, -SHIN, 0))
	Parts.sphere(hips, "HipL", 0.085, pants, leg_l.position)
	_limb(leg_l, "ThighL", 0.072, THIGH, pants)
	Parts.sphere(leg_l, "KneeL", 0.075, pants, shin_l.position)
	Parts.sphere(leg_l, "PadL", 0.055, pads, shin_l.position + Vector3(0, 0, -0.03))
	_limb(shin_l, "ShinMeshL", 0.055, SHIN, pants)
	Parts.capsule(ankle_l, "ShoeL", 0.05, 0.26, shoes, Vector3(0, -0.015, -0.06), Vector3(PI * 0.5, 0, 0))
	leg_r = Parts.pivot(hips, "LegR", Vector3(0.08, -0.04, 0))
	shin_r = Parts.pivot(leg_r, "ShinR", Vector3(0, -THIGH, 0))
	ankle_r = Parts.pivot(shin_r, "AnkleR", Vector3(0, -SHIN, 0))
	Parts.sphere(hips, "HipR", 0.085, pants, leg_r.position)
	_limb(leg_r, "ThighR", 0.072, THIGH, pants)
	Parts.sphere(leg_r, "KneeR", 0.075, pants, shin_r.position)
	Parts.sphere(leg_r, "PadR", 0.055, pads, shin_r.position + Vector3(0, 0, -0.03))
	_limb(shin_r, "ShinMeshR", 0.055, SHIN, pants)
	Parts.capsule(ankle_r, "ShoeR", 0.05, 0.26, shoes, Vector3(0, -0.015, -0.06), Vector3(PI * 0.5, 0, 0))
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
	_idle()
	_place_board(true)
	_solve_legs()
