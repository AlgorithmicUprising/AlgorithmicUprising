extends RefCounted
## Phase 4 (LOCAL): small rideable park pieces for the HQ skate yard (kicker, bank, manual pad). Each is one closed,
## cel-shaded mesh with one convex collision of the same profile, so the surface he rides is the surface you see.
## Local frame like the quarter pipe: +X climbs, origin = middle of the low edge on the ground; yaw turns it.

const Blocks = preload("res://scripts/world_blocks.gd")

const FACE := Color("5f4f74")       # dark sealed concrete, purple (the park painting's ramp faces)
const SIDE := Color("8a6b7c")       # warm mauve cheeks (kept for callers; the finished cheeks use the dark face)
const TRIM := Color("e7eef2")       # metal edge (same as the quarter-pipe coping)
const DARK_STEEL := Color("3a3540")
const CAUTION := Color("f0c14a")
const CAUTION_INK := Color("1a1a1a")

## A wedge: slope from the ground to `height` over `length`, then a flat deck of `deck` metres, then a back face down
## to the ground. deck = 0 makes a plain kicker (used against the funbox), deck > 0 a bank with a top.
static func wedge(parent: Node, node_name: String, low_edge: Vector3, yaw: float, length: float, height: float, width: float, deck := 0.0, _face := FACE, _side := SIDE) -> StaticBody3D:
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
	var riding := _dark_mat(0.28, 0.1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_slope := Vector3(-height, length, 0).normalized()
	# v 0.08 at the ground, v 0.64 at the lip: the quarter-pipe caution band sits under the metal edge.
	_quad_uv(st, Vector3(0, 0, -h), Vector3(0, 0, h), Vector3(length, height, h), Vector3(length, height, -h), n_slope, Vector2(0, 0.08), Vector2(1, 0.08), Vector2(1, 0.64), Vector2(0, 0.64))
	if deck > 0.0:
		_quad_uv(st, Vector3(length, height, -h), Vector3(length, height, h), Vector3(back, height, h), Vector3(back, height, -h), Vector3.UP, Vector2(0, 0.70), Vector2(1, 0.70), Vector2(1, 0.92), Vector2(0, 0.92))
	var faces := MeshInstance3D.new()
	faces.name = "Face"
	faces.mesh = st.commit()
	faces.material_override = riding
	body.add_child(faces)
	var back_st := SurfaceTool.new()
	back_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(back_st, Vector3(back, height, -h), Vector3(back, height, h), Vector3(back, 0, h), Vector3(back, 0, -h), Vector3.RIGHT)
	var back_face := MeshInstance3D.new()
	back_face.name = "Back"
	back_face.mesh = back_st.commit()
	back_face.material_override = Blocks.cel(DARK_STEEL, 3.0, 0.22)
	body.add_child(back_face)
	var ss := SurfaceTool.new()
	ss.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in [-h, h]:
		var n := Vector3(0, 0, signf(z))
		var a := Vector3(0, 0, z)
		var b := Vector3(length, height, z)
		var c := Vector3(back, height, z)
		var d := Vector3(back, 0, z)
		var ua := Vector2(0.05, 0.12)
		var ub := Vector2(0.42, 0.62)
		var uc := Vector2(0.72, 0.78)
		var ud := Vector2(0.95, 0.18)
		if z > 0.0:
			_tri_uv(ss, a, b, d, n, ua, ub, ud)
			_tri_uv(ss, b, c, d, n, ub, uc, ud)
		else:
			_tri_uv(ss, a, d, b, n, ua, ud, ub)
			_tri_uv(ss, b, d, c, n, ub, ud, uc)
	var cheeks := MeshInstance3D.new()
	cheeks.name = "Cheeks"
	cheeks.mesh = ss.commit()
	cheeks.material_override = _dark_mat(0.22, 0.06)
	body.add_child(cheeks)
	# metal edge where the slope meets the deck (or the top of a kicker), and the caution band just under it
	_trim(body, Vector3(length, height + 0.012, 0.0), width)
	_caution(body, length, height, width)
	parent.add_child(body)
	return body

## A manual pad / ledge: a low block with metal edges on its long top corners. Long axis = local Z.
static func pad(parent: Node, node_name: String, center_ground: Vector3, yaw: float, size: Vector3) -> StaticBody3D:
	var root := Blocks.solid(parent, node_name, center_ground + Vector3(0, size.y * 0.5, 0), size, FACE, Vector3(0, yaw, 0), 0.3)
	root.set_meta("park_piece", "pad")
	root.set_meta("height", size.y)
	dress_box(root, false)
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

## Finished box: hide the flat colour mesh, keep its collision, and put the dark face, a caution
## frame, and (when `coping` is set) a steel tube on the top edges. Visual only.
static func dress_box(body: StaticBody3D, coping := false) -> void:
	var inst: MeshInstance3D = null
	for child in body.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
			var box := (child as MeshInstance3D).mesh as BoxMesh
			# The collision box from Blocks.solid. Edge trim and caution ticks are shorter than this.
			if box.size.y > 0.08 and not str(child.name).begins_with("Edge"):
				inst = child
				break
	if inst == null:
		return
	var size: Vector3 = (inst.mesh as BoxMesh).size
	inst.visible = false
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var top_y := hy + 0.004
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad_uv(st, Vector3(-hx, top_y, -hz), Vector3(hx, top_y, -hz), Vector3(hx, top_y, hz), Vector3(-hx, top_y, hz), Vector3.UP, Vector2(0.05, 0.08), Vector2(0.95, 0.08), Vector2(0.95, 0.48), Vector2(0.05, 0.48))
	_side(st, Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz), Vector3(0, 0, -1))
	_side(st, Vector3(hx, hy, hz), Vector3(-hx, hy, hz), Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(0, 0, 1))
	_side(st, Vector3(-hx, hy, hz), Vector3(-hx, hy, -hz), Vector3(-hx, -hy, -hz), Vector3(-hx, -hy, hz), Vector3(-1, 0, 0))
	_side(st, Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3(hx, -hy, hz), Vector3(hx, -hy, -hz), Vector3(1, 0, 0))
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = st.commit()
	shell.material_override = _dark_mat(0.26, 0.08)
	body.add_child(shell)
	_caution_frame(body, hx, hy, hz)
	if coping:
		# CylinderMesh stands on Y. rotation.z lays it along X (the z = ±hz edges); rotation.x lays it along Z.
		var along_x_a := _trim(body, Vector3(0, hy + 0.02, hz), size.x)
		along_x_a.rotation = Vector3(0, 0, PI * 0.5)
		var along_x_b := _trim(body, Vector3(0, hy + 0.02, -hz), size.x)
		along_x_b.rotation = Vector3(0, 0, PI * 0.5)
		_trim(body, Vector3(hx, hy + 0.02, 0), size.z)
		_trim(body, Vector3(-hx, hy + 0.02, 0), size.z)

static func _side(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_quad_uv(st, a, b, c, d, n, Vector2(0.04, 0.06), Vector2(0.96, 0.06), Vector2(0.96, 0.42), Vector2(0.04, 0.42))

static func _caution_frame(body: Node3D, hx: float, hy: float, hz: float) -> void:
	var inset := 0.07
	_caution_run(body, Vector3(-hx + inset, hy + 0.02, hz - 0.05), Vector3(1, 0, 0), (hx - inset) * 2.0)
	_caution_run(body, Vector3(-hx + inset, hy + 0.02, -hz + 0.05), Vector3(1, 0, 0), (hx - inset) * 2.0)
	_caution_run(body, Vector3(hx - 0.05, hy + 0.02, -hz + inset), Vector3(0, 0, 1), (hz - inset) * 2.0)
	_caution_run(body, Vector3(-hx + 0.05, hy + 0.02, -hz + inset), Vector3(0, 0, 1), (hz - inset) * 2.0)

static func _caution_run(body: Node3D, origin: Vector3, axis: Vector3, length: float) -> void:
	var seg := 0.28
	var t := 0.0
	var i := 0
	while t < length - 0.02:
		var w := minf(seg, length - t)
		var box := MeshInstance3D.new()
		box.name = "Caution%d" % (body.get_child_count() + i)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.045, 0.028, w * 0.92) if absf(axis.z) > 0.5 else Vector3(w * 0.92, 0.028, 0.045)
		box.mesh = mesh
		box.position = origin + axis * (t + w * 0.5)
		box.material_override = Blocks.cel(CAUTION if i % 2 == 0 else CAUTION_INK, 2.0, 0.0)
		body.add_child(box)
		t += seg
		i += 1

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_quad_uv(st, a, b, c, d, n, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)

static func _quad_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	# Godot's front face is clockwise. A right-handed winding that already matches n is flipped.
	var flip := (b - a).cross(c - a).dot(n) > 0.0
	var tri: Array = [a, c, b, a, d, c] if flip else [a, b, c, a, c, d]
	var uvs: Array = [ua, uc, ub, ua, ud, uc] if flip else [ua, ub, uc, ua, uc, ud]
	for i in tri.size():
		st.set_normal(n)
		st.set_uv(uvs[i] as Vector2)
		st.add_vertex(tri[i] as Vector3)

static func _tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	var flip := (b - a).cross(c - a).dot(n) > 0.0
	var tri: Array = [a, c, b] if flip else [a, b, c]
	var uvs: Array = [ua, uc, ub] if flip else [ua, ub, uc]
	for i in tri.size():
		st.set_normal(n)
		st.set_uv(uvs[i] as Vector2)
		st.add_vertex(tri[i] as Vector3)

static var _face_tex: Texture2D

static func _dark_mat(outline: float, fill: float) -> ShaderMaterial:
	if _face_tex == null:
		_face_tex = load("res://assets/library/quarter_pipe/dark_face_albedo.png")
	var mat := Blocks.cel_textured(Color.WHITE, _face_tex, 3.0, outline)
	mat.set_shader_parameter("fill_light", fill)
	return mat

static func _caution(body: Node3D, length: float, height: float, width: float) -> void:
	var x := length - 0.045
	var y := height * x / maxf(length, 0.001) + 0.02
	_caution_run(body, Vector3(x, y, -width * 0.5), Vector3(0, 0, 1), width)

static func _trim(body: Node3D, at: Vector3, width: float) -> MeshInstance3D:
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
	t.name = "Trim%d" % body.get_child_count()
	return t
