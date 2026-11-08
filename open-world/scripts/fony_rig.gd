extends Node3D

const Parts = preload("res://scripts/block_parts.gd")

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

func face_world(world_yaw: float) -> void:
	var parent_yaw := 0.0
	if get_parent() != null:
		parent_yaw = get_parent().rotation.y
	rotation.y = wrapf(world_yaw - parent_yaw, -PI, PI)

func _skate(swing: float) -> void:
	pose_name = "skate"
	chest.rotation.x = 0.35
	head.rotation.x = -0.2
	arm_l.rotation = Vector3(0.2, 0.0, 0.7 + swing * 0.15)
	arm_r.rotation = Vector3(0.2, 0.0, -0.7 - swing * 0.15)
	fore_l.rotation.x = -0.6
	fore_r.rotation.x = -0.6
	leg_l.rotation.x = 0.42
	leg_r.rotation.x = 0.36
	shin_l.rotation.x = -0.62
	shin_r.rotation.x = -0.5

func _walk(swing: float) -> void:
	pose_name = "walk"
	chest.rotation.x = 0.08
	head.rotation.x = 0.0
	arm_l.rotation = Vector3(-swing * 0.7, 0.0, 0.15)
	arm_r.rotation = Vector3(swing * 0.7, 0.0, -0.15)
	fore_l.rotation.x = -0.4
	fore_r.rotation.x = -0.4
	leg_l.rotation.x = swing * 0.7
	leg_r.rotation.x = -swing * 0.7
	shin_l.rotation.x = -max(0.0, swing) * 0.8
	shin_r.rotation.x = -max(0.0, -swing) * 0.8

func _jump() -> void:
	pose_name = "jump"
	chest.rotation.x = -0.15
	head.rotation.x = 0.1
	arm_l.rotation = Vector3(-1.0, 0.0, 0.3)
	arm_r.rotation = Vector3(-1.0, 0.0, -0.3)
	fore_l.rotation.x = -0.4
	fore_r.rotation.x = -0.4
	leg_l.rotation.x = -0.45
	leg_r.rotation.x = -0.4
	shin_l.rotation.x = 0.9
	shin_r.rotation.x = 0.85

func _crouch(amount: float) -> void:
	chest.rotation.x = 0.45 * amount
	head.rotation.x = -0.1
	arm_l.rotation = Vector3(0.4, 0.0, 0.4)
	arm_r.rotation = Vector3(0.4, 0.0, -0.4)
	fore_l.rotation.x = -0.5
	fore_r.rotation.x = -0.5
	leg_l.rotation.x = 0.8 * amount
	leg_r.rotation.x = 0.8 * amount
	shin_l.rotation.x = -1.3 * amount
	shin_r.rotation.x = -1.3 * amount

func _idle() -> void:
	pose_name = "idle"
	var breathe := sin(phase) * 0.04
	chest.rotation.x = breathe
	head.rotation.x = -breathe
	arm_l.rotation = Vector3(0.1, 0.0, 0.12)
	arm_r.rotation = Vector3(0.1, 0.0, -0.12)
	fore_l.rotation.x = -0.25
	fore_r.rotation.x = -0.25
	leg_l.rotation.x = 0.0
	leg_r.rotation.x = 0.0
	shin_l.rotation.x = 0.0
	shin_r.rotation.x = 0.0

func _place_board(under_feet: bool) -> void:
	board.visible = true
	if under_feet:
		board.position = Vector3(0.0, 0.045, 0.0)
		board.rotation = Vector3(0.0, 0.0, 0.0)
	else:
		board.position = Vector3(0.34, 1.05, 0.02)
		board.rotation = Vector3(0.1, 0.5, 1.15)

func _build() -> void:
	var skin := Color("f0c9a0")
	var hair := Color("c4622d")
	var jacket := Color("c46a32")
	var hoodie := Color("1a1a1e")
	var pants := Color("5c6b3a")
	var pads := Color("e23d78")
	var shoes := Color("8a7564")
	hips = Parts.pivot(self, "Hips", Vector3(0, 0.92, 0))
	chest = Parts.pivot(hips, "Chest", Vector3(0, 0.18, 0))
	Parts.capsule(chest, "Hoodie", 0.1, 0.46, hoodie, Vector3(0, 0.02, 0.02))
	Parts.capsule(chest, "Jacket", 0.15, 0.56, jacket, Vector3(0, 0.02, 0))
	Parts.sphere(chest, "ShoulderL", 0.08, jacket, Vector3(-0.2, 0.22, 0))
	Parts.sphere(chest, "ShoulderR", 0.08, jacket, Vector3(0.2, 0.22, 0))
	Parts.box(chest, "Patch", Vector3(0.07, 0.06, 0.025), Color("6a727a"), Vector3(0.1, 0.24, -0.14))
	Parts.box(chest, "Tape", Vector3(0.05, 0.045, 0.025), pads, Vector3(-0.1, 0.12, -0.14))
	head = Parts.pivot(chest, "Head", Vector3(0, 0.36, 0))
	Parts.sphere(head, "Face", 0.09, skin, Vector3(0, 0.05, -0.04))
	Parts.sphere(head, "Nose", 0.022, skin, Vector3(0, 0.04, -0.13))
	Parts.sphere(head, "EyeL", 0.024, Color("2a211c"), Vector3(-0.038, 0.08, -0.125))
	Parts.sphere(head, "EyeR", 0.024, Color("2a211c"), Vector3(0.038, 0.08, -0.125))
	Parts.capsule(head, "Mouth", 0.012, 0.05, Color("a56858"), Vector3(0, 0.0, -0.13), Vector3(0, 0, PI * 0.5))
	Parts.sphere(head, "Hair", 0.1, hair, Vector3(0, 0.14, 0.05))
	Parts.sphere(head, "Tuft", 0.055, hair, Vector3(0.06, 0.18, 0.0))
	Parts.sphere(head, "TuftSide", 0.05, hair, Vector3(-0.07, 0.13, 0.02))
	Parts.sphere(head, "Hood", 0.08, hoodie, Vector3(0, 0.08, 0.08))
	arm_l = Parts.pivot(chest, "ArmL", Vector3(-0.26, 0.22, 0))
	fore_l = Parts.pivot(arm_l, "ForeL", Vector3(0, -0.28, 0))
	Parts.capsule(arm_l, "SleeveL", 0.065, 0.28, jacket, Vector3(0, -0.12, 0))
	Parts.capsule(fore_l, "ForearmL", 0.05, 0.24, jacket, Vector3(0, -0.1, 0))
	Parts.sphere(fore_l, "HandL", 0.048, skin, Vector3(0, -0.22, 0))
	arm_r = Parts.pivot(chest, "ArmR", Vector3(0.26, 0.22, 0))
	fore_r = Parts.pivot(arm_r, "ForeR", Vector3(0, -0.28, 0))
	Parts.capsule(arm_r, "SleeveR", 0.065, 0.28, jacket, Vector3(0, -0.12, 0))
	Parts.capsule(fore_r, "ForearmR", 0.05, 0.24, jacket, Vector3(0, -0.1, 0))
	Parts.sphere(fore_r, "HandR", 0.048, skin, Vector3(0, -0.22, 0))
	leg_l = Parts.pivot(hips, "LegL", Vector3(-0.09, -0.02, 0))
	shin_l = Parts.pivot(leg_l, "ShinL", Vector3(0, -0.46, 0))
	Parts.capsule(leg_l, "ThighL", 0.065, 0.48, pants, Vector3(0, -0.18, 0))
	Parts.capsule(shin_l, "ShinMeshL", 0.05, 0.34, pants, Vector3(0, -0.14, 0))
	Parts.sphere(shin_l, "PadL", 0.06, pads, Vector3(0, -0.02, -0.05))
	Parts.capsule(shin_l, "ShoeL", 0.05, 0.26, shoes, Vector3(0, -0.32, -0.06), Vector3(PI * 0.5, 0, 0))
	leg_r = Parts.pivot(hips, "LegR", Vector3(0.09, -0.02, 0))
	shin_r = Parts.pivot(leg_r, "ShinR", Vector3(0, -0.46, 0))
	Parts.capsule(leg_r, "ThighR", 0.065, 0.48, pants, Vector3(0, -0.18, 0))
	Parts.capsule(shin_r, "ShinMeshR", 0.05, 0.34, pants, Vector3(0, -0.14, 0))
	Parts.sphere(shin_r, "PadR", 0.06, pads, Vector3(0, -0.02, -0.05))
	Parts.capsule(shin_r, "ShoeR", 0.05, 0.26, shoes, Vector3(0, -0.32, -0.06), Vector3(PI * 0.5, 0, 0))
	board = Parts.pivot(self, "Deck", Vector3(0, 0.05, 0.08))
	Parts.box(board, "DeckWood", Vector3(0.32, 0.04, 0.92), Color("4a3428"), Vector3(0, 0.03, 0))
	Parts.box(board, "Nose", Vector3(0.3, 0.03, 0.12), Color("c46a32"), Vector3(0, 0.045, 0.38))
	Parts.box(board, "Tail", Vector3(0.3, 0.03, 0.12), Color("c46a32"), Vector3(0, 0.045, -0.38))
	Parts.box(board, "Grip", Vector3(0.26, 0.012, 0.62), Color("2c2a28"), Vector3(0, 0.055, 0))
	Parts.box(board, "TruckF", Vector3(0.2, 0.03, 0.06), Color("c8c2b8"), Vector3(0, 0.0, 0.24))
	Parts.box(board, "TruckB", Vector3(0.2, 0.03, 0.06), Color("c8c2b8"), Vector3(0, 0.0, -0.24))
	for side in [-1.0, 1.0]:
		for axle in [-0.24, 0.24]:
			Parts.cylinder(board, "Wheel", 0.045, 0.05, Color("ece7df"), Vector3(side * 0.16, -0.02, axle), Vector3(0, 0, PI * 0.5))
	_idle()
	_place_board(true)
