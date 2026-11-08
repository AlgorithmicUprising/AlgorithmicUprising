extends StaticBody3D

@export var npc_id := ""
@export var display_name := ""
@export var body_color := Color("f2d2a2")
@export var lines: PackedStringArray = []

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 1
	if has_node("Body"):
		$Body.material_override = load("res://scripts/world_blocks.gd").cel(body_color, 3.0, 0.4)
	var label := Label3D.new()
	label.text = display_name
	label.position = Vector3(0, 1.55, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.008
	label.modulate = Color("fff8ef")
	label.outline_size = 8
	add_child(label)

func prompt() -> String:
	return "Talk to " + display_name

func interact(flow: Node) -> void:
	flow.open_dialogue(npc_id, display_name, lines)
