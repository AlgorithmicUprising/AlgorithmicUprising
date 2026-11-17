extends RefCounted
## Phase 4 (LOCAL): small rideable park pieces for the HQ skate yard (kicker, bank, manual pad). Each is one closed,
## cel-shaded mesh with one convex collision of the same profile, so the surface he rides is the surface you see.
## Local frame like the quarter pipe: +X climbs, origin = middle of the low edge on the ground; yaw turns it.

const Blocks = preload("res://scripts/world_blocks.gd")

const FACE := Color("5f4f74")       # dark sealed concrete, purple (the park painting's ramp faces)
const SIDE := Color("8a6b7c")       # warm mauve cheeks
const TRIM := Color("e7eef2")       # metal edge (same as the quarter-pipe coping)

## A wedge: slope from the ground to `height` over `length`, then a flat deck of `deck` metres, then a back face down
## to the ground. deck = 0 makes a plain kicker (used against the funbox), deck > 0 a bank with a top.
static func wedge(parent: Node, node_name: String, low_edge: Vector3, yaw: float, length: float, height: float, width: float, deck := 0.0, face := FACE, side := SIDE) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = low_edge
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("park_piece", "bank" if deck > 0.0 else "kicker")
	body.set_meta("length", length)
	body.set_meta("height", height)
	body.set_meta("deck", deck)
	body.set_meta("width", width)
	var h := width * 0.5
	var back := length + deck
	var prof := [Vector2(0, 0), Vector2(length, height), Vector2(back, height), Vector2(back, 0)]
	var pts := PackedVector3Array()
	for z in [-h, h]:
		for p in prof:
			pts.append(Vector3(p.x, p.y, z))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_slope := Vector3(-height, length, 0).normalized()
	_quad(st, Vector3(0, 0, -h), Vector3(0, 0, h), Vector3(length, height, h), Vector3(length, height, -h), n_slope)
	if deck > 0.0:
		_quad(st, Vector3(length, height, -h), Vector3(length, height, h), Vector3(back, height, h), Vector3(back, height, -h), Vector3.UP)
	_quad(st, Vector3(back, height, -h), Vector3(back, height, h), Vector3(back, 0, h), Vector3(back, 0, -h), Vector3.RIGHT)
	var faces := MeshInstance3D.new()
	faces.name = "Face"
	faces.mesh = st.commit()
	faces.material_override = Blocks.cel(face, 3.0, 0.3)
	body.add_child(faces)
	var ss := SurfaceTool.new()
	ss.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in [-h, h]:
		var n := Vector3(0, 0, signf(z))
		var a := Vector3(0, 0, z)
		var b := Vector3(length, height, z)
		var c := Vector3(back, height, z)
		var d := Vector3(back, 0, z)
		var tris := [[a, b, d], [b, c, d]] if z > 0.0 else [[a, d, b], [b, d, c]]
		for t in tris:
			for v in t:
				ss.set_normal(n)
				ss.add_vertex(v)
	var cheeks := MeshInstance3D.new()
	cheeks.name = "Cheeks"
	cheeks.mesh = ss.commit()
	cheeks.material_override = Blocks.cel(side, 3.0, 0.3)
	body.add_child(cheeks)
	# metal edge where the slope meets the deck (or the top of a kicker)
	_trim(body, Vector3(length, height + 0.012, 0.0), width)
	parent.add_child(body)
	return body

## A manual pad / ledge: a low block with metal edges on its long top corners. Long axis = local Z.
static func pad(parent: Node, node_name: String, center_ground: Vector3, yaw: float, size: Vector3) -> StaticBody3D:
	var root := Blocks.solid(parent, node_name, center_ground + Vector3(0, size.y * 0.5, 0), size, FACE, Vector3(0, yaw, 0), 0.3)
	root.set_meta("park_piece", "pad")
	root.set_meta("height", size.y)
	for sx in [-1.0, 1.0]:
		var t := MeshInstance3D.new()
		t.name = "Edge%s" % ("E" if sx > 0.0 else "W")
		var m := BoxMesh.new()
		m.size = Vector3(0.06, 0.06, size.z + 0.02)
		t.mesh = m
		t.position = Vector3(sx * (size.x * 0.5 - 0.02), size.y * 0.5 - 0.02, 0.0)
		t.material_override = Blocks.cel(TRIM, 3.0, 0.08)
		root.add_child(t)
	return root

## Height of a wedge's riding surface at world point p (tests / probes). -1 outside its footprint.
static func surface_y(piece: Node3D, p: Vector3) -> float:
	var l: Vector3 = piece.to_local(p)
	var length := float(piece.get_meta("length"))
	var height := float(piece.get_meta("height"))
	var back := length + float(piece.get_meta("deck"))
	if l.x < 0.0 or l.x > back or absf(l.z) > float(piece.get_meta("width")) * 0.5:
		return -1.0
	return piece.global_position.y + (height * l.x / length if l.x < length else height)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	# wound so the face points along n
	var tri := [a, b, c, a, c, d]
	if (b - a).cross(c - a).dot(n) > 0.0:
		tri = [a, c, b, a, d, c]
	for v in tri:
		st.set_normal(n)
		st.add_vertex(v)

static func _trim(body: Node3D, at: Vector3, width: float) -> void:
	var t := MeshInstance3D.new()
	t.name = "Trim"
	var m := CylinderMesh.new()
	m.top_radius = 0.035
	m.bottom_radius = 0.035
	m.height = width
	m.radial_segments = 10
	t.mesh = m
	t.position = at
	t.rotation.x = PI * 0.5
	t.material_override = Blocks.cel(TRIM, 3.0, 0.08)
	body.add_child(t)
