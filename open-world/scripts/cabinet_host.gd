extends StaticBody3D

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 1
	if has_node("Body"):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("2a211c")
		mat.roughness = 1.0
		$Body.material_override = mat
	var screen := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 0.7, 0.06)
	screen.mesh = mesh
	screen.position = Vector3(0, 0.25, 0.38)
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color("16343a")
	screen.material_override = screen_mat
	add_child(screen)

func prompt() -> String:
	return "Cabinet placeholder"

func interact(flow: Node) -> void:
	flow.open_cabinet()
