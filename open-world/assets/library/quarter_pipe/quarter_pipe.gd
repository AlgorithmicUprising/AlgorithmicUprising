extends Node3D

const Blocks = preload("res://scripts/world_blocks.gd")

## Riding-surface radius in metres. The pivot is the centre of the low lip, on the ground.
@export var radius := 2.4
## Distance across the riding surface, along local Z.
@export var width := 7.0
## How far the curve climbs before the deck. Kept under the player's floor limit.
@export var climb_deg := 70.0
@export var deck_length := 1.6
@export var thickness := 0.42
@export var curve_steps := 36

var triangle_count := 0
var _built := false

func _ready() -> void:
	_build()

func _build() -> void:
	if _built:
		return
	_built = true
	var half := width * 0.5
	var climb := deg_to_rad(climb_deg)
	var outer: Array[Vector3] = []
	var inner: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var along: Array[float] = []
	var travelled := 0.0
	for i in curve_steps + 1:
		var ang := float(i) / float(curve_steps) * climb
		var point := Vector3(radius * sin(ang), radius * (1.0 - cos(ang)), 0.0)
		var into := Vector3(sin(ang), -cos(ang), 0.0)
		if i > 0:
			travelled += outer[i - 1].distance_to(point)
		outer.append(point)
		inner.append(point + into * thickness)
		normals.append(Vector3(-sin(ang), cos(ang), 0.0))
		along.append(travelled)
	var lip: Vector3 = outer[curve_steps]
	var deck_out := lip + Vector3(deck_length, 0.0, 0.0)
	var deck_in := inner[curve_steps] + Vector3(deck_length, 0.0, 0.0)
	travelled += deck_length
	outer.append(deck_out)
	inner.append(deck_in)
	normals.append(Vector3.UP)
	along.append(travelled)
	var span := maxf(travelled, 0.001)
	var concrete: Texture2D = load("res://assets/library/quarter_pipe/concrete_albedo.png")
	var paint: Texture2D = load("res://assets/library/quarter_pipe/graffiti_albedo.png")
	var shell_mat := Blocks.cel_textured(Color.WHITE, concrete, 3.0, 0.2)
	var metal_mat := Blocks.cel(Color("d5dde2"), 3.0, 0.1)
	var paint_mat := Blocks.cel_textured(Color.WHITE, paint, 3.0, 0.16)
	var shell := _shell(outer, inner, normals, along, span, half)
	var shell_mesh := ArrayMesh.new()
	shell_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shell)
	var shell_node := MeshInstance3D.new()
	shell_node.name = "Shell"
	shell_node.mesh = shell_mesh
	shell_node.material_override = shell_mat
	add_child(shell_node)
	triangle_count += shell[Mesh.ARRAY_VERTEX].size() / 3
	_collision(outer, inner, half)
	var coping := MeshInstance3D.new()
	coping.name = "Coping"
	var tube := CylinderMesh.new()
	tube.top_radius = 0.05
	tube.bottom_radius = 0.05
	tube.height = width + 0.36
	tube.radial_segments = 12
	tube.cap_top = true
	tube.cap_bottom = true
	coping.mesh = tube
	coping.position = lip + Vector3(0.055, 0.028, 0.0)
	coping.rotation.x = PI * 0.5
	coping.material_override = metal_mat
	add_child(coping)
	triangle_count += tube.get_faces().size() / 3
	_poster(paint_mat, lip, half, 1.0)
	_poster(paint_mat, lip, -half, -1.0)

func _shell(outer: Array[Vector3], inner: Array[Vector3], normals: Array[Vector3], along: Array[float], span: float, half: float) -> Array:
	var vertices := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var strips := 8
	for i in outer.size() - 1:
		var v0 := along[i] / span
		var v1 := along[i + 1] / span
		for s in strips:
			var u0 := float(s) / float(strips)
			var u1 := float(s + 1) / float(strips)
			var z0 := lerpf(-half, half, u0)
			var z1 := lerpf(-half, half, u1)
			_quad(vertices, norms, uvs,
				outer[i] + Vector3(0, 0, z0), outer[i] + Vector3(0, 0, z1),
				outer[i + 1] + Vector3(0, 0, z1), outer[i + 1] + Vector3(0, 0, z0),
				normals[i], normals[i], normals[i + 1], normals[i + 1],
				Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1))
			_quad(vertices, norms, uvs,
				inner[i] + Vector3(0, 0, z0), inner[i + 1] + Vector3(0, 0, z0),
				inner[i + 1] + Vector3(0, 0, z1), inner[i] + Vector3(0, 0, z1),
				-normals[i], -normals[i + 1], -normals[i + 1], -normals[i],
				Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0))
		for side in [-1.0, 1.0]:
			var z: float = side * half
			var n := Vector3(0, 0, side)
			var a := outer[i] + Vector3(0, 0, z)
			var b := outer[i + 1] + Vector3(0, 0, z)
			var c := Vector3(outer[i + 1].x, -0.02, z)
			var d := Vector3(outer[i].x, -0.02, z)
			if side > 0.0:
				_quad(vertices, norms, uvs, a, d, c, b, n, n, n, n, Vector2(v0, 0.15), Vector2(v0, 0.92), Vector2(v1, 0.92), Vector2(v1, 0.15))
			else:
				_quad(vertices, norms, uvs, a, b, c, d, n, n, n, n, Vector2(v0, 0.15), Vector2(v1, 0.15), Vector2(v1, 0.92), Vector2(v0, 0.92))
			var e0 := inner[i] + Vector3(0, 0, z)
			var e1 := inner[i + 1] + Vector3(0, 0, z)
			if side > 0.0:
				_quad(vertices, norms, uvs, a, e0, e1, b, n, n, n, n, Vector2(v0, 0.02), Vector2(v0, 0.12), Vector2(v1, 0.12), Vector2(v1, 0.02))
			else:
				_quad(vertices, norms, uvs, a, b, e1, e0, n, n, n, n, Vector2(v0, 0.02), Vector2(v1, 0.02), Vector2(v1, 0.12), Vector2(v0, 0.12))
	var last := outer.size() - 1
	var back_n := Vector3(1, 0, 0)
	_quad(vertices, norms, uvs,
		outer[last] + Vector3(0, 0, -half), inner[last] + Vector3(0, 0, -half),
		inner[last] + Vector3(0, 0, half), outer[last] + Vector3(0, 0, half),
		back_n, back_n, back_n, back_n,
		Vector2(0, 1), Vector2(0, 0.7), Vector2(1, 0.7), Vector2(1, 1))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	return arrays

func _quad(vertices: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	vertices.append_array(PackedVector3Array([a, b, c, a, c, d]))
	norms.append_array(PackedVector3Array([na, nb, nc, na, nc, nd]))
	uvs.append_array(PackedVector2Array([ua, ub, uc, ua, uc, ud]))

func _collision(outer: Array[Vector3], inner: Array[Vector3], half: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 1
	for i in outer.size() - 1:
		var shape := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		for z in [-half, half]:
			var side := Vector3(0, 0, z)
			points.append(outer[i] + side)
			points.append(outer[i + 1] + side)
			points.append(inner[i] + side)
			points.append(inner[i + 1] + side)
		shape.points = points
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
	add_child(body)

func _poster(material: Material, lip: Vector3, z: float, facing: float) -> void:
	var poster := MeshInstance3D.new()
	poster.name = "GraffitiL" if facing > 0.0 else "GraffitiR"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.35, 1.15)
	poster.mesh = quad
	poster.position = Vector3(lip.x + 0.55, lip.y * 0.48, z + facing * 0.03)
	poster.rotation.y = 0.0 if facing > 0.0 else PI
	poster.material_override = material
	add_child(poster)
	triangle_count += 2
