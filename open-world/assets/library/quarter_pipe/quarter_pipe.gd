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
## Phase 2 (LOCAL): self-lit fill on the shell. The face looks east and the sun is west of it, so the transition sits in the
## pipe's own shadow (measured 43/255 in a render). 0 = the pre-Phase-2 look.
@export var face_fill := 1.3
## Phase 4 (LOCAL): "dark" = the darker sealed-concrete riding finish from the park painting (deep mauve face, the transition
## paint goes blue-teal). "" keeps the original warm finish. The fill above still applies, so the face stays readable.
@export var finish := ""
## Phase 4 (LOCAL): close the open space under the deck with a back wall (visual and collision), for pipes that stand free.
@export var closed_back := false

const DARK_TINT := Color("ad97c8")    # Phase 4 tint (kept for reference; the finish pass draws the dark face in its own texture)
## Finish pass (Nov 17 2026): the "dark" finish is a finished surface, not a tint. Dark purple ply face with seams, scuffs and a
## caution band under the coping (dark_face_albedo.png, tools/make_quarter_textures.py), steel coping, light steel angle along
## both cheek edges (the park pieces' TRIM), dark steel cheek plates and a steel deck plate (the HQ arcade's STEEL).
const DARK_COPING := Color("8a8f96")
const DARK_TRIM := Color("e7eef2")
const DARK_STEEL := Color("3a3540")
const DARK_DECK := Color("4a4454")

var triangle_count := 0
var _built := false

func _ready() -> void:
	add_to_group("quarter_pipe")
	_build()

# --- Phase 2 (LOCAL): riding profile. Local frame: +X climbs, +Y up, Z across the width; origin = centre of the low lip on the
# ground. s = arc length up the curve from the bottom (0 .. lip_arc()); theta = s / radius.
func climb_rad() -> float:
	return deg_to_rad(climb_deg)

func lip_arc() -> float:
	return radius * climb_rad()

func lip_local() -> Vector3:
	var c := climb_rad()
	return Vector3(radius * sin(c), radius * (1.0 - cos(c)), 0.0)

func lip_height() -> float:
	return lip_local().y

func deck_end_x() -> float:
	return lip_local().x + deck_length

func half_width() -> float:
	return width * 0.5

func profile_point(s: float, z := 0.0) -> Vector3:
	var a := clampf(s, 0.0, lip_arc()) / radius
	return Vector3(radius * sin(a), radius * (1.0 - cos(a)), z)

func profile_tangent(s: float) -> Vector3:
	var a := clampf(s, 0.0, lip_arc()) / radius
	return Vector3(cos(a), sin(a), 0.0)

func profile_normal(s: float) -> Vector3:
	var a := clampf(s, 0.0, lip_arc()) / radius
	return Vector3(-sin(a), cos(a), 0.0)

## Arc length of the curve point under local x (clamped to the curve).
func arc_at_x(x: float) -> float:
	return radius * asin(clampf(x / radius, 0.0, sin(climb_rad())))

## Riding surface height under local x: flat ground before the curve, the curve, the deck, then ground behind the back wall.
func surface_y(x: float) -> float:
	var lip := lip_local()
	if x <= 0.0:
		return 0.0
	if x <= lip.x:
		return radius - sqrt(maxf(radius * radius - x * x, 0.0))
	if x <= lip.x + deck_length:
		return lip.y
	return 0.0

## World coping line (both ends of the coping tube's riding edge).
func coping_line() -> PackedVector3Array:
	var lip := lip_local()
	return PackedVector3Array([to_global(lip + Vector3(0, 0, -width * 0.5)), to_global(lip + Vector3(0, 0, width * 0.5))])

func profile_info() -> Dictionary:
	return {"radius": radius, "climb_deg": climb_deg, "lip_height": lip_height(), "lip_x": lip_local().x, "lip_arc": lip_arc(),
		"deck_length": deck_length, "width": width}

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
	var dark := finish == "dark"
	var concrete: Texture2D = load("res://assets/library/quarter_pipe/dark_face_albedo.png" if dark else "res://assets/library/quarter_pipe/concrete_albedo.png")
	var paint: Texture2D = load("res://assets/library/quarter_pipe/graffiti_albedo.png")
	var shell_mat := Blocks.cel_textured(Color.WHITE, concrete, 3.0, 0.34)
	shell_mat.set_shader_parameter("fill_light", face_fill)
	var metal_mat := Blocks.cel(DARK_COPING if dark else Color("e7eef2"), 3.0, 0.08)
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
	if dark:
		_dark_trim(outer, half)
	if closed_back:
		_back_wall(deck_in, half, Blocks.cel(DARK_STEEL, 3.0, 0.3) if dark else shell_mat)
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

## Back wall under the deck end, ground to the deck's underside (the deck slab itself already has collision).
func _back_wall(deck_in: Vector3, half: float, mat: Material) -> void:
	var x := deck_end_x()
	var top := deck_in.y
	var t := 0.12
	var wall := MeshInstance3D.new()
	wall.name = "BackWall"
	var box := BoxMesh.new()
	box.size = Vector3(t, top + 0.02, width)
	wall.mesh = box
	wall.position = Vector3(x - t * 0.5, (top - 0.02) * 0.5, 0.0)
	wall.material_override = mat
	add_child(wall)
	triangle_count += 12
	var body := StaticBody3D.new()
	body.name = "BackCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(t, top, width)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(x - t * 0.5, top * 0.5, 0.0)
	body.add_child(col)
	add_child(body)

## Finish pass: the dark finish's steel. Cheek plates over the side faces (just outside them), a light steel angle along the
## riding edge of each cheek (a flange on the face and one down the cheek), and a steel plate on the deck behind the coping.
## The thin parts are written double-sided so they read from any side whatever the winding.
func _dark_trim(outer: Array[Vector3], half: float) -> void:
	var lip := lip_local()
	var plate_mat := Blocks.cel(DARK_STEEL, 3.0, 0.0)
	var trim_mat := Blocks.cel(DARK_TRIM, 3.0, 0.0)
	var flange := 0.08
	for side in [-1.0, 1.0]:
		var tag := "L" if side > 0.0 else "R"
		var n := Vector3(0, 0, side)
		var cv := PackedVector3Array()
		var cn := PackedVector3Array()
		var tv := PackedVector3Array()
		var tn := PackedVector3Array()
		var zc: float = side * (half + 0.01)
		var zt: float = side * (half + 0.025)
		var zi: float = side * (half - flange)
		for i in outer.size() - 1:
			var a := outer[i]
			var b := outer[i + 1]
			# cheek plate: profile down to the ground
			_quad2(cv, cn, Vector3(a.x, a.y - 0.004, zc), Vector3(a.x, -0.01, zc), Vector3(b.x, -0.01, zc), Vector3(b.x, b.y - 0.004, zc), n)
			# side flange down the cheek
			_quad2(tv, tn, Vector3(a.x, a.y + 0.014, zt), Vector3(a.x, a.y - flange, zt), Vector3(b.x, b.y - flange, zt), Vector3(b.x, b.y + 0.014, zt), n)
			# face flange along the riding edge, lying on the surface
			var t := (b - a).normalized()
			var up := Vector3(-t.y, t.x, 0.0)
			var lift := up * 0.014
			_quad2(tv, tn, a + lift + Vector3(0, 0, zt), a + lift + Vector3(0, 0, zi), b + lift + Vector3(0, 0, zi), b + lift + Vector3(0, 0, zt), up)
		_add_mesh("Cheek" + tag, cv, cn, plate_mat)
		_add_mesh("EdgeTrim" + tag, tv, tn, trim_mat)
	var deck := MeshInstance3D.new()
	deck.name = "DeckPlate"
	var box := BoxMesh.new()
	var x0 := lip.x + 0.11
	var x1 := deck_end_x() - 0.02
	box.size = Vector3(maxf(x1 - x0, 0.05), 0.012, width - 0.04)
	deck.mesh = box
	deck.position = Vector3((x0 + x1) * 0.5, lip.y + 0.006, 0.0)
	deck.material_override = Blocks.cel(DARK_DECK, 3.0, 0.2)
	add_child(deck)
	triangle_count += 12

func _quad2(v: PackedVector3Array, nrm: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	v.append_array(PackedVector3Array([a, b, c, a, c, d, a, c, b, a, d, c]))
	nrm.append_array(PackedVector3Array([n, n, n, n, n, n, -n, -n, -n, -n, -n, -n]))

func _add_mesh(node_name: String, v: PackedVector3Array, n: PackedVector3Array, mat: Material) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	add_child(inst)
	triangle_count += v.size() / 3
