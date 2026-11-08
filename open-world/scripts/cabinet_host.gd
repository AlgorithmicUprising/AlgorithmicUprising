extends StaticBody3D

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 1
	var blocks = load("res://scripts/world_blocks.gd")
	if has_node("Body"):
		$Body.material_override = blocks.cel(Color("2a211c"), 3.0, 0.45)
	var screen := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 0.7, 0.06)
	screen.mesh = mesh
	screen.position = Vector3(0, 0.25, 0.38)
	screen.material_override = blocks.cel(Color("16343a"), 2.0, 0.15)
	add_child(screen)

func prompt() -> String:
	return "Cabinet placeholder"

func interact(flow: Node) -> void:
	flow.open_cabinet()
