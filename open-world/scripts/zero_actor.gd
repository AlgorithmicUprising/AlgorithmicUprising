extends StaticBody3D

@export var npc_id := "zero"
@export var display_name := "Zero"
@export var lines: PackedStringArray = []
var rig: Node3D

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 1
	var shape_node := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.15
	shape_node.shape = shape
	shape_node.position.y = 0.8
	add_child(shape_node)
	rig = load("res://scripts/zero_rig.gd").new()
	add_child(rig)
	var label := Label3D.new()
	label.name = "NameLabel"
	label.text = "ZERO"
	label.position = Vector3(0, 2.05, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.0032
	label.modulate = Color("fff8ef")
	label.outline_size = 8
	add_child(label)

func _process(delta: float) -> void:
	if rig == null:
		return
	var talking := false
	var flow := get_tree().root.find_child("Flow", true, false)
	if flow != null and flow.dialogue_open and str(flow.speaker_id) == npc_id:
		talking = true
	rig.drive(delta, talking)

func prompt() -> String:
	return "Talk to " + display_name

func interact(flow: Node) -> void:
	flow.open_dialogue(npc_id, display_name, lines)
