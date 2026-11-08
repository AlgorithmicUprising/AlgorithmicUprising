extends RefCounted

const Palette = preload("res://scripts/palette.gd")

static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat

static func solid(parent: Node, node_name: String, center: Vector3, size: Vector3, color: Color, rotation := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.rotation = rotation
	body.collision_layer = 1
	body.collision_mask = 1
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material(color)
	body.add_child(inst)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body

static func visual(parent: Node, node_name: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.position = center
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.material_override = material(color)
	parent.add_child(inst)
	return inst

static func label(parent: Node, text: String, pos: Vector3, color: Color = Palette.LABEL, font_size := 56) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.position = pos
	node.modulate = color
	node.font_size = font_size
	node.pixel_size = 0.008
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.outline_size = 10
	node.outline_modulate = Color(0.08, 0.05, 0.04, 1)
	parent.add_child(node)
	return node

static func add_ramp(parent: Node, node_name: String, at: Vector3) -> StaticBody3D:
	# `at` is the low end on the ground. The wedge climbs toward -Z.
	var length := 6.0
	var height := 1.5
	var half := 2.1
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(-half, 0.02, 0.0), Vector3(half, 0.02, 0.0),
		Vector3(-half, 0.02, -length), Vector3(half, 0.02, -length),
		Vector3(-half, height, -length), Vector3(half, height, -length),
	])
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var vertices := PackedVector3Array([
		Vector3(-half, 0.02, 0.0), Vector3(half, 0.02, 0.0), Vector3(half, height, -length),
		Vector3(-half, 0.02, 0.0), Vector3(half, height, -length), Vector3(-half, height, -length),
	])
	var normal := Vector3(0, length, height).normalized()
	var normals := PackedVector3Array()
	for _i in vertices.size():
		normals.append(normal)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	var mat := material(Palette.RAMP)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	inst.material_override = mat
	body.add_child(inst)
	parent.add_child(body)
	return body
