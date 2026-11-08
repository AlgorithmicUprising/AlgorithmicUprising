extends RefCounted

const Palette = preload("res://scripts/palette.gd")
static var _cel: Shader

static func material(color: Color) -> ShaderMaterial:
	return cel(color)

static func cel(color: Color, bands := 3.0, outline := 0.22) -> ShaderMaterial:
	if _cel == null:
		_cel = load("res://shaders/cel_block.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = _cel
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("bands", bands)
	mat.set_shader_parameter("outline_strength", outline)
	return mat

static func solid(parent: Node, node_name: String, center: Vector3, size: Vector3, color: Color, rotation := Vector3.ZERO, outline := 0.32) -> StaticBody3D:
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
	inst.material_override = cel(color, 3.0, outline)
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
	node.pixel_size = 0.018
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.outline_size = 10
	node.outline_modulate = Color(0.08, 0.05, 0.04, 1)
	parent.add_child(node)
	return node

static func add_slope(parent: Node, node_name: String, low: Vector3, high: Vector3, width: float, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	var mid := (low + high) * 0.5
	body.position = mid
	var flat := Vector3(high.x - low.x, 0.0, high.z - low.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	var forward := flat.normalized()
	var side := Vector3(-forward.z, 0.0, forward.x)
	var half := width * 0.5
	var low_local := low - mid
	var high_local := high - mid
	var bottom_y: float = minf(low_local.y, high_local.y) - 0.4
	var low_bottom := Vector3(low_local.x, bottom_y, low_local.z)
	var high_bottom := Vector3(high_local.x, bottom_y, high_local.z)
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		low_local + side * half, low_local - side * half,
		high_local + side * half, high_local - side * half,
		low_bottom + side * half, low_bottom - side * half,
		high_bottom + side * half, high_bottom - side * half,
	])
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var a := low_local + side * half
	var b := low_local - side * half
	var c := high_local + side * half
	var d := high_local - side * half
	var vertices := PackedVector3Array([a, b, c, b, d, c])
	var normal := (c - a).cross(b - a).normalized()
	if normal.y < 0.0:
		normal = -normal
		vertices = PackedVector3Array([a, c, b, b, c, d])
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
	inst.material_override = cel(color, 3.0, 0.35)
	body.add_child(inst)
	parent.add_child(body)
	return body

static func add_quarter(parent: Node, node_name: String, origin: Vector3, yaw: float, radius: float, width: float, color: Color) -> Node3D:
	# Flat at the origin, rising toward local +X onto a short deck. One mesh, shared-edge collision.
	var root := Node3D.new()
	root.name = node_name
	root.position = origin
	root.rotation.y = yaw
	parent.add_child(root)
	var steps := 12
	var depth := 0.7
	var climb := deg_to_rad(68.0)
	var deck := 1.5
	var half_w := width * 0.5
	var outer: Array[Vector3] = []
	var inner: Array[Vector3] = []
	for i in steps + 1:
		var ang := float(i) / float(steps) * climb
		var point := Vector3(radius * sin(ang), radius * (1.0 - cos(ang)), 0.0)
		var into := Vector3(sin(ang), -cos(ang), 0.0)
		outer.append(point)
		inner.append(point + into * depth)
	var deck_far := outer[steps] + Vector3(deck, 0.0, 0.0)
	outer.append(deck_far)
	inner.append(deck_far + Vector3(0.0, -depth, 0.0))
	steps += 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in steps:
		var edge := outer[i + 1] - outer[i]
		var normal := Vector3(-edge.y, edge.x, 0.0).normalized()
		var left := Vector3(0, 0, -half_w)
		var right := Vector3(0, 0, half_w)
		_quad(vertices, normals, outer[i] + left, outer[i + 1] + left, outer[i + 1] + right, outer[i] + right, normal)
		_quad(vertices, normals, inner[i] + right, inner[i + 1] + right, inner[i + 1] + left, inner[i] + left, -normal)
		var side_n := Vector3(0, 0, 1)
		_quad(vertices, normals, outer[i] + right, outer[i + 1] + right, inner[i + 1] + right, inner[i] + right, side_n)
		_quad(vertices, normals, outer[i + 1] + left, outer[i] + left, inner[i] + left, inner[i + 1] + left, -side_n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = cel(color, 3.0, 0.1)
	root.add_child(inst)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	for i in steps:
		var shape := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		for z in [-half_w, half_w]:
			var side := Vector3(0, 0, z)
			points.append(outer[i] + side)
			points.append(outer[i + 1] + side)
			points.append(inner[i] + side)
			points.append(inner[i + 1] + side)
		shape.points = points
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
	root.add_child(body)
	var lip := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.06
	cyl.height = width
	cyl.radial_segments = 8
	lip.mesh = cyl
	lip.position = outer[steps - 1] + Vector3(0.0, 0.05, 0.0)
	lip.rotation.x = PI * 0.5
	lip.material_override = cel(Color("e7e2da"), 2.0, 0.05)
	root.add_child(lip)
	return root

static func _quad(vertices: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	vertices.append_array(PackedVector3Array([a, b, c, a, c, d]))
	for _i in 6:
		normals.append(normal)

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
	inst.material_override = material(Palette.RAMP)
	body.add_child(inst)
	parent.add_child(body)
	return body
