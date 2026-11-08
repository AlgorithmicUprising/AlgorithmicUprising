extends Node3D

const Parts = preload("res://scripts/block_parts.gd")

var pose_name := "idle"
var phase := 0.0
var hips: Node3D
var chest: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var bars: Array[MeshInstance3D] = []

func _ready() -> void:
	name = "CRT"
	_build()

func drive(delta: float, talking: bool) -> void:
	phase += delta * (2.4 if talking else 1.3)
	var bob := sin(phase) * 0.04
	hips.position.y = 0.96 + bob
	head.rotation.x = sin(phase * 0.7) * 0.08
	if talking:
		pose_name = "talk"
		arm_r.rotation = Vector3(-1.15, 0.2, -0.25)
		arm_l.rotation = Vector3(0.15, 0.0, 0.2)
		chest.rotation.x = 0.12
	else:
		pose_name = "idle"
		arm_r.rotation = Vector3(0.15, 0.0, -0.18)
		arm_l.rotation = Vector3(0.12, 0.0, 0.16)
		chest.rotation.x = bob
	for i in bars.size():
		var bar: MeshInstance3D = bars[i]
		var h: float = 0.04 + 0.05 * absf(sin(phase * 3.0 + float(i)))
		bar.scale = Vector3(1.0, h / 0.05, 1.0)

func _build() -> void:
	var cream := Color("e6dcc8")
	var leather := Color("1c1c22")
	var metal := Color("8a939c")
	var shirt := Color("f3efe4")
	hips = Parts.pivot(self, "Hips", Vector3(0, 0.96, 0))
	chest = Parts.pivot(hips, "Chest", Vector3(0, 0.12, 0))
	Parts.box(chest, "Shirt", Vector3(0.36, 0.28, 0.18), shirt, Vector3(0, 0.16, 0.02))
	for i in 5:
		Parts.box(chest, "Barcode%d" % i, Vector3(0.012, 0.08, 0.02), Color("1a1a1a"), Vector3(-0.04 + float(i) * 0.02, 0.14, 0.12))
	Parts.box(chest, "Jacket", Vector3(0.46, 0.36, 0.24), leather, Vector3(0, 0.2, 0))
	Parts.box(chest, "QuestionPatch", Vector3(0.09, 0.09, 0.03), Color("d42b3a"), Vector3(0.12, 0.22, 0.13))
	var mark := Label3D.new()
	mark.text = "?"
	mark.font_size = 64
	mark.pixel_size = 0.002
	mark.position = Vector3(0.12, 0.22, 0.15)
	mark.modulate = Color("fff4ea")
	chest.add_child(mark)
	head = Parts.pivot(chest, "Head", Vector3(0, 0.46, 0))
	Parts.box(head, "Neck", Vector3(0.1, 0.1, 0.1), metal, Vector3(0, -0.08, 0))
	Parts.box(head, "Bezel", Vector3(0.46, 0.36, 0.28), cream, Vector3(0, 0.1, 0))
	Parts.box(head, "Screen", Vector3(0.3, 0.2, 0.04), Color("10140c"), Vector3(0, 0.12, 0.14))
	for i in 3:
		var bar := Parts.box(head, "Wave%d" % i, Vector3(0.05, 0.05, 0.02), Color("b6ff3b"), Vector3(-0.08 + float(i) * 0.08, 0.12, 0.17))
		bars.append(bar)
	Parts.box(head, "Knob", Vector3(0.05, 0.05, 0.05), metal, Vector3(0.2, 0.02, 0.1))
	Parts.box(head, "Vent", Vector3(0.16, 0.03, 0.08), Color("6a645c"), Vector3(0, 0.28, 0))
	arm_l = Parts.pivot(chest, "ArmL", Vector3(-0.26, 0.28, 0))
	arm_r = Parts.pivot(chest, "ArmR", Vector3(0.26, 0.28, 0))
	Parts.box(arm_l, "SleeveL", Vector3(0.1, 0.26, 0.1), leather, Vector3(0, -0.12, 0))
	Parts.box(arm_l, "HandL", Vector3(0.08, 0.1, 0.08), metal, Vector3(0, -0.28, 0))
	Parts.box(arm_r, "SleeveR", Vector3(0.1, 0.26, 0.1), leather, Vector3(0, -0.12, 0))
	Parts.box(arm_r, "HandR", Vector3(0.08, 0.1, 0.08), metal, Vector3(0, -0.28, 0))
	for side in [-1.0, 1.0]:
		var leg := Parts.pivot(hips, "LegL" if side < 0.0 else "LegR", Vector3(side * 0.1, -0.04, 0))
		Parts.box(leg, "Trouser", Vector3(0.12, 0.4, 0.12), Color("2a2a30"), Vector3(0, -0.2, 0))
		Parts.box(leg, "Knee", Vector3(0.1, 0.08, 0.08), metal, Vector3(0, -0.36, 0.04))
		Parts.box(leg, "Boot", Vector3(0.12, 0.1, 0.2), Color("141414"), Vector3(0, -0.46, 0.04))
	var cable := Parts.pivot(chest, "Cable", Vector3(0.18, 0.34, -0.08))
	for i in 8:
		var ang := float(i) / 8.0 * TAU
		Parts.box(cable, "Coil%d" % i, Vector3(0.04, 0.04, 0.08), Color("1a1a1a"), Vector3(cos(ang) * 0.1, -float(i) * 0.05, sin(ang) * 0.1))
	Parts.box(cable, "Plug", Vector3(0.06, 0.08, 0.06), Color("222222"), Vector3(0.16, -0.45, 0.05))
