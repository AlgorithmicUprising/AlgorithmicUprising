extends RefCounted

const Blocks = preload("res://scripts/world_blocks.gd")

static func pivot(parent: Node, node_name: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = at
	parent.add_child(node)
	return node

static func box(parent: Node, node_name: String, size: Vector3, color: Color, at: Vector3) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = at
	mesh_node.material_override = Blocks.cel(color, 3.0, 0.18)
	parent.add_child(mesh_node)
	return mesh_node
