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
	leg_l.rotation.x = 0.55
	leg_r.rotation.x = 0.5
	shin_l.rotation.x = -1.05
	shin_r.rotation.x = -0.95

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
		board.position = Vector3(0.0, 0.06, 0.05)
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
	chest = Parts.pivot(hips, "Chest", Vector3(0, 0.16, 0))
	Parts.box(chest, "Hoodie", Vector3(0.34, 0.28, 0.18), hoodie, Vector3(0, 0.16, 0.01))
	Parts.box(chest, "Jacket", Vector3(0.42, 0.32, 0.22), jacket, Vector3(0, 0.18, 0))
	Parts.box(chest, "Patch", Vector3(0.08, 0.07, 0.03), Color("6a727a"), Vector3(0.12, 0.22, 0.12))
	Parts.box(chest, "Tape", Vector3(0.06, 0.05, 0.03), pads, Vector3(-0.12, 0.12, 0.12))
	head = Parts.pivot(chest, "Head", Vector3(0, 0.34, 0))
	Parts.box(head, "Face", Vector3(0.18, 0.2, 0.16), skin, Vector3(0, 0.08, 0.02))
	Parts.box(head, "Hair", Vector3(0.22, 0.12, 0.2), hair, Vector3(0, 0.18, -0.01))
	Parts.box(head, "Tuft", Vector3(0.1, 0.1, 0.1), hair, Vector3(0.06, 0.24, 0.04))
	Parts.box(head, "Hood", Vector3(0.24, 0.16, 0.18), hoodie, Vector3(0, 0.12, -0.04))
	arm_l = Parts.pivot(chest, "ArmL", Vector3(-0.24, 0.26, 0))
	fore_l = Parts.pivot(arm_l, "ForeL", Vector3(0, -0.22, 0))
	Parts.box(arm_l, "SleeveL", Vector3(0.1, 0.24, 0.1), jacket, Vector3(0, -0.1, 0))
	Parts.box(fore_l, "HandL", Vector3(0.08, 0.2, 0.08), skin, Vector3(0, -0.1, 0))
	arm_r = Parts.pivot(chest, "ArmR", Vector3(0.24, 0.26, 0))
	fore_r = Parts.pivot(arm_r, "ForeR", Vector3(0, -0.22, 0))
	Parts.box(arm_r, "SleeveR", Vector3(0.1, 0.24, 0.1), jacket, Vector3(0, -0.1, 0))
	Parts.box(fore_r, "HandR", Vector3(0.08, 0.2, 0.08), skin, Vector3(0, -0.1, 0))
	leg_l = Parts.pivot(hips, "LegL", Vector3(-0.1, -0.02, 0))
	shin_l = Parts.pivot(leg_l, "ShinL", Vector3(0, -0.36, 0))
	Parts.box(leg_l, "ThighL", Vector3(0.12, 0.36, 0.12), pants, Vector3(0, -0.18, 0))
	Parts.box(shin_l, "ShinMeshL", Vector3(0.1, 0.32, 0.1), pants, Vector3(0, -0.16, 0))
	Parts.box(shin_l, "PadL", Vector3(0.12, 0.1, 0.08), pads, Vector3(0, -0.08, 0.06))
	Parts.box(shin_l, "ShoeL", Vector3(0.1, 0.08, 0.2), shoes, Vector3(0, -0.34, 0.04))
	leg_r = Parts.pivot(hips, "LegR", Vector3(0.1, -0.02, 0))
	shin_r = Parts.pivot(leg_r, "ShinR", Vector3(0, -0.36, 0))
	Parts.box(leg_r, "ThighR", Vector3(0.12, 0.36, 0.12), pants, Vector3(0, -0.18, 0))
	Parts.box(shin_r, "ShinMeshR", Vector3(0.1, 0.32, 0.1), pants, Vector3(0, -0.16, 0))
	Parts.box(shin_r, "PadR", Vector3(0.12, 0.1, 0.08), pads, Vector3(0, -0.08, 0.06))
	Parts.box(shin_r, "ShoeR", Vector3(0.1, 0.08, 0.2), shoes, Vector3(0, -0.34, 0.04))
	board = Parts.pivot(self, "Deck", Vector3(0, 0.06, 0.05))
	Parts.box(board, "DeckWood", Vector3(0.22, 0.04, 0.72), Color("3a2a22"), Vector3(0, 0, 0))
	Parts.box(board, "Grip", Vector3(0.2, 0.015, 0.5), Color("2a2a28"), Vector3(0, 0.025, 0))
	for side in [-1.0, 1.0]:
		for axle in [-0.22, 0.22]:
			Parts.box(board, "Wheel", Vector3(0.06, 0.06, 0.06), Color("d8d2c8"), Vector3(side * 0.12, -0.04, axle))
	_idle()
	_place_board(true)
