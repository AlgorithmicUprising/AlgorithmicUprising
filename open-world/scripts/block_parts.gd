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

static func _paint(mesh_node: MeshInstance3D, color: Color) -> void:
	mesh_node.material_override = Blocks.cel(color, 3.0, 0.22)

static func capsule(parent: Node, node_name: String, radius: float, height: float, color: Color, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = max(height, radius * 2.0)
	mesh_node.mesh = mesh
	mesh_node.position = at
	mesh_node.rotation = rot
	_paint(mesh_node, color)
	parent.add_child(mesh_node)
	return mesh_node

static func sphere(parent: Node, node_name: String, radius: float, color: Color, at: Vector3) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh_node.mesh = mesh
	mesh_node.position = at
	_paint(mesh_node, color)
	parent.add_child(mesh_node)
	return mesh_node

static func cylinder(parent: Node, node_name: String, radius: float, height: float, color: Color, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh_node.mesh = mesh
	mesh_node.position = at
	mesh_node.rotation = rot
	_paint(mesh_node, color)
	parent.add_child(mesh_node)
	return mesh_node
