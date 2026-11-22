extends Node3D
## Yard drainage bowl. A flat bottom, a 70° quarter-pipe transition (same profile the Fony quarter-pipe
## rides: height = R (1 - cos theta), normal = (-sin theta, cos theta)), metal coping, and a deck that
## fills the old bank cut. The player rides it with the quarter-pipe curve step (player_controller.gd,
## ramp_mode "bowl"): gravity along the wall, pump on the lower transition, a vertical lip launch.
## Local frame: origin on the deck plane at the bowl centre. +X east, +Z north, y up. Floor at FLOOR_Y.

const Blocks = preload("res://scripts/world_blocks.gd")

const HX := 3.6
const HZ := 4.0
const CORNER_R := 1.6
const DEPTH := 2.15
const CLIMB_DEG := 70.0
## Deep enough that the line check (player y < -2) fires, shallow enough that a 9 m/s push
## rides back out to the quarter pipe. A 3 m pool trapped the P.1 line.
const FLOOR_Y := -2.15
## Deck rectangle, local metres. Overlaps the yard slabs by a hand's width so the cut has no crack.
const OUTER_MIN_X := -26.4
const OUTER_MAX_X := 28.4
const OUTER_MIN_Z := -28.4
const OUTER_MAX_Z := 28.4
const SIDE_SEGS := 8
const CORNER_SEGS := 6
const RADIAL_STEPS := 14
const SHELL := 0.5

func _ready() -> void:
	add_to_group("skate_bowl")
	_build()

func climb_rad() -> float:
	return deg_to_rad(CLIMB_DEG)

func radius() -> float:
	return DEPTH / (1.0 - cos(climb_rad()))

func lip_u() -> float:
	return radius() * sin(climb_rad())

## Signed distance outside the flat rounded rectangle. Negative on the flat bottom.
func sdf(lx: float, lz: float) -> float:
	var qx := absf(lx) - (HX - CORNER_R)
	var qz := absf(lz) - (HZ - CORNER_R)
	var outside := Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length()
	var inside := minf(maxf(qx, qz), 0.0)
	return outside + inside - CORNER_R

## Unit gradient of sdf in the local xz plane (points up the wall, out of the flat).
func gradient(lx: float, lz: float) -> Vector2:
	var qx := absf(lx) - (HX - CORNER_R)
	var qz := absf(lz) - (HZ - CORNER_R)
	var sx := 1.0 if lx >= 0.0 else -1.0
	var sz := 1.0 if lz >= 0.0 else -1.0
	if qx > 0.0 and qz > 0.0:
		var len := Vector2(qx, qz).length()
		if len < 0.0001:
			return Vector2(sx, 0.0)
		return Vector2(sx * qx / len, sz * qz / len)
	if qx > qz:
		return Vector2(sx, 0.0)
	return Vector2(0.0, sz)

## Surface under a world point. kind is "flat", "wall", or "deck".
func sample(world_point: Vector3) -> Dictionary:
	var local := to_local(world_point)
	var u := sdf(local.x, local.z)
	var g := gradient(local.x, local.z)
	var out := Vector3(g.x, 0.0, g.y)
	if out.length() < 0.001:
		out = Vector3.RIGHT
	else:
		out = out.normalized()
	var around := Vector3(-out.z, 0.0, out.x)
	var lip := lip_u()
	var r := radius()
	var theta := 0.0
	var y := FLOOR_Y
	var normal := Vector3.UP
	var kind := "flat"
	if u >= lip:
		y = 0.0
		kind = "deck"
	elif u > 0.0:
		var s := clampf(u / r, 0.0, sin(climb_rad()))
		theta = asin(s)
		y = FLOOR_Y + r * (1.0 - cos(theta))
		kind = "wall"
		normal = (-sin(theta) * out + Vector3.UP * cos(theta)).normalized()
	var tangent := out
	if kind == "wall":
		tangent = (cos(theta) * out + sin(theta) * Vector3.UP).normalized()
	return {
		"u": u, "theta": theta, "y": y, "kind": kind,
		"normal": normal, "tangent": tangent, "out": out, "around": around,
		"point": to_global(Vector3(local.x, y, local.z)),
		"lip_u": lip, "floor_y": FLOOR_Y,
	}

## Same radial line as world_point, moved to horizontal distance target_u from the flat edge.
func sample_toward(world_point: Vector3, target_u: float) -> Dictionary:
	var s: Dictionary = sample(world_point)
	var local := to_local(world_point)
	var out := s.out as Vector3
	var shifted := Vector3(local.x, 0.0, local.z) + out * (target_u - float(s.u))
	return sample(to_global(shifted))

## Samples around the bowl at a fixed distance up the transition, in loop order. Tests use this.
func debug_ring(u: float) -> Array:
	var out: Array = []
	for pt in _loop():
		out.append(sample(to_global(_at(pt, u, 0.0))))
	return out

func _build() -> void:
	var loop := _loop()
	var faces := PackedVector3Array()
	var flat_v := PackedVector3Array()
	var flat_n := PackedVector3Array()
	var flat_uv := PackedVector2Array()
	var wall_v := PackedVector3Array()
	var wall_n := PackedVector3Array()
	var wall_uv := PackedVector2Array()
	var band_v := PackedVector3Array()
	var band_n := PackedVector3Array()
	var band_uv := PackedVector2Array()
	var deck_v := PackedVector3Array()
	var deck_n := PackedVector3Array()
	var deck_uv := PackedVector2Array()
	_fill_flat(loop, flat_v, flat_n, flat_uv, faces)
	var lip: Array = _fill_wall(loop, wall_v, wall_n, wall_uv, band_v, band_n, band_uv, faces)
	_fill_deck(loop, lip, deck_v, deck_n, deck_uv, faces)
	var concrete: Texture2D = load("res://assets/library/quarter_pipe/concrete_albedo.png")
	var wall_mat := _face(Color("d5ebe4"), 0.34, 0.42, concrete)
	var band_mat := _face(Color("e7e4dc"), 0.12, 0.55)
	var deck_mat := Blocks.cel(Color("c4a48c"), 3.0, 0.18)
	deck_mat.set_shader_parameter("fill_light", 0.12)
	var flat_mat := _face(Color("3c5962"), 0.16, 0.28)
	_mesh("Flat", flat_v, flat_n, flat_uv, flat_mat)
	_mesh("Transition", wall_v, wall_n, wall_uv, wall_mat)
	_mesh("LipBand", band_v, band_n, band_uv, band_mat)
	_mesh("Deck", deck_v, deck_n, deck_uv, deck_mat)
	_coping(lip)
	_approach()
	var body := StaticBody3D.new()
	body.name = "BowlFloor"
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := ConcavePolygonShape3D.new()
	shape.data = faces
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

## Double-sided cel, so the transition reads from the deck as well as from inside the pool.
func _face(color: Color, outline: float, fill: float, tex: Texture2D = null) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cel_bowl.gdshader")
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("bands", 3.0)
	mat.set_shader_parameter("outline_strength", outline)
	mat.set_shader_parameter("fill_light", fill)
	if tex != null:
		mat.set_shader_parameter("albedo_tex", tex)
		mat.set_shader_parameter("texture_mix", 1.0)
	return mat

## A smooth box over the north deck. The ground slab ends on this seam, and a capsule landing
## on that edge was sticking. The box stops short of the coping so the roll-in still catches.
func _approach() -> void:
	var coping_z := -(HZ + lip_u())
	# North deck is the negative local Z side. Stop just short of the coping so the roll-in still catches.
	var z1 := coping_z - 0.08
	var z0 := -40.0
	var body := StaticBody3D.new()
	body.name = "BowlApproach"
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := BoxShape3D.new()
	var depth := z1 - z0
	shape.size = Vector3(HX * 2.0 + 6.0, 1.0, depth)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, -0.5, (z0 + z1) * 0.5)
	body.add_child(col)
	add_child(body)
	# Smooth flat bottom, slightly above the sunk trimesh.
	var floor_body := StaticBody3D.new()
	floor_body.name = "BowlFlat"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 1
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(HX * 2.0, 0.4, HZ * 2.0)
	var floor_col := CollisionShape3D.new()
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0.0, FLOOR_Y - 0.2, 0.0)
	floor_body.add_child(floor_col)
	add_child(floor_body)

func _mesh(node_name: String, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, mat: Material) -> void:
	if verts.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	add_child(inst)

func _fill_flat(loop: Array, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, faces: PackedVector3Array) -> void:
	var center := Vector3(0.0, FLOOR_Y, 0.0)
	var n := loop.size()
	for i in n:
		var a := _at(loop[i], 0.0, FLOOR_Y)
		var b := _at(loop[(i + 1) % n], 0.0, FLOOR_Y)
		_tri(verts, norms, uvs, faces, center, a, b, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(0.5, 0.5), Vector2(0.5, 0.15), Vector2(0.5, 0.15))

## Returns the lip ring: [{p, n, out}] in loop order. The last two radial steps are the light band under the coping.
func _fill_wall(loop: Array, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, band_v: PackedVector3Array, band_n: PackedVector3Array, band_uv: PackedVector2Array, faces: PackedVector3Array) -> Array:
	var r := radius()
	var climb := climb_rad()
	var prev: Array = []
	var lip: Array = []
	var n := loop.size()
	for step in RADIAL_STEPS + 1:
		var th := climb * float(step) / float(RADIAL_STEPS)
		var u := r * sin(th)
		var y := FLOOR_Y + r * (1.0 - cos(th))
		var ring: Array = []
		for i in n:
			var pt: Dictionary = loop[i]
			var out: Vector3 = pt.out
			var normal := Vector3.UP if step == 0 else (-sin(th) * out + Vector3.UP * cos(th)).normalized()
			ring.append({"p": _at(pt, u, y), "n": normal, "out": out, "uv": Vector2(float(i) / float(n), 0.08 + 0.72 * th / climb)})
		if step > 0:
			var into_band := step > RADIAL_STEPS - 2
			for i in n:
				var j := (i + 1) % n
				var dest_v := band_v if into_band else verts
				var dest_n := band_n if into_band else norms
				var dest_uv := band_uv if into_band else uvs
				_quad(dest_v, dest_n, dest_uv, faces,
					prev[i].p, prev[j].p, ring[j].p, ring[i].p,
					prev[i].n, prev[j].n, ring[j].n, ring[i].n,
					prev[i].uv, prev[j].uv, ring[j].uv, ring[i].uv)
		prev = ring
		lip = ring
	return lip

func _fill_deck(loop: Array, lip: Array, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, faces: PackedVector3Array) -> void:
	var n := loop.size()
	var hits: Array[Vector3] = []
	for i in n:
		var o: Vector3 = lip[i].out
		hits.append(_ray_rect(lip[i].p, Vector2(o.x, o.z)))
	for i in n:
		var j := (i + 1) % n
		var a: Vector3 = lip[i].p
		var b: Vector3 = lip[j].p
		a.y = 0.0
		b.y = 0.0
		var ha: Vector3 = hits[i]
		var hb: Vector3 = hits[j]
		var corner: Variant = _shared_corner(_side_of(ha), _side_of(hb))
		if corner == null:
			_quad(verts, norms, uvs, faces, a, b, hb, ha, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP,
				Vector2(0.1, 0.9), Vector2(0.2, 0.9), Vector2(0.2, 0.1), Vector2(0.1, 0.1))
			_skirt(verts, norms, uvs, faces, ha, hb)
		else:
			var c: Vector3 = corner
			_tri(verts, norms, uvs, faces, a, b, hb, Vector3.UP, Vector3.UP, Vector3.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
			_tri(verts, norms, uvs, faces, a, hb, c, Vector3.UP, Vector3.UP, Vector3.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
			_tri(verts, norms, uvs, faces, a, c, ha, Vector3.UP, Vector3.UP, Vector3.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
			_skirt(verts, norms, uvs, faces, ha, c)
			_skirt(verts, norms, uvs, faces, c, hb)

func _skirt(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, faces: PackedVector3Array, a: Vector3, b: Vector3) -> void:
	if a.distance_to(b) < 0.02:
		return
	var a2 := Vector3(a.x, -0.45, a.z)
	var b2 := Vector3(b.x, -0.45, b.z)
	# Loop is counter-clockwise from above, so the right perpendicular of a->b points out of the deck.
	var out := Vector3(b.z - a.z, 0.0, a.x - b.x)
	# Skirt faces out of the deck. The helper flips to match this normal.
	if out.length() < 0.001:
		out = Vector3.RIGHT
	_quad(verts, norms, uvs, faces, a, b, b2, a2, out, out, out, out, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)

func _coping(lip: Array) -> void:
	var sides := 7
	var radius := 0.06
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var rings: Array = []
	var n := lip.size()
	for i in n:
		var prev: Vector3 = lip[(i + n - 1) % n].p
		var next: Vector3 = lip[(i + 1) % n].p
		var axis := next - prev
		if axis.length() < 0.001:
			axis = Vector3.FORWARD
		axis = axis.normalized()
		var out: Vector3 = lip[i].out
		var up := axis.cross(out)
		if up.y < 0.0:
			up = -up
		up = up.normalized()
		var side := up.cross(axis).normalized()
		var center: Vector3 = lip[i].p + Vector3.UP * 0.045 + out * 0.02
		var ring: Array[Vector3] = []
		for s in sides:
			var a := TAU * float(s) / float(sides)
			ring.append(center + (side * cos(a) + up * sin(a)) * radius)
		rings.append(ring)
	for i in n:
		var j := (i + 1) % n
		for s in sides:
			var t := (s + 1) % sides
			var na: Vector3 = rings[i][s] - (lip[i].p + Vector3.UP * 0.045)
			var nb: Vector3 = rings[i][t] - (lip[i].p + Vector3.UP * 0.045)
			var nc: Vector3 = rings[j][t] - (lip[j].p + Vector3.UP * 0.045)
			var nd: Vector3 = rings[j][s] - (lip[j].p + Vector3.UP * 0.045)
			_tri_visual(verts, norms, uvs, rings[i][s], rings[j][s], rings[j][t], na, nd, nc)
			_tri_visual(verts, norms, uvs, rings[i][s], rings[j][t], rings[i][t], na, nc, nb)
	var mat := Blocks.cel(Color("d5dbe2"), 3.0, 0.06)
	mat.set_shader_parameter("fill_light", 0.7)
	_mesh("Coping", verts, norms, uvs, mat)

func _loop() -> Array:
	var pts: Array = []
	var ix := HX - CORNER_R
	var iz := HZ - CORNER_R
	for i in SIDE_SEGS:
		var z := lerpf(-iz, iz, float(i) / float(SIDE_SEGS))
		pts.append({"xz": Vector2(HX, z), "out": Vector3(1, 0, 0)})
	for i in CORNER_SEGS:
		var a := lerpf(0.0, PI * 0.5, float(i) / float(CORNER_SEGS))
		var o := Vector3(cos(a), 0.0, sin(a))
		pts.append({"xz": Vector2(ix, iz) + Vector2(o.x, o.z) * CORNER_R, "out": o})
	for i in SIDE_SEGS:
		var x := lerpf(ix, -ix, float(i) / float(SIDE_SEGS))
		pts.append({"xz": Vector2(x, HZ), "out": Vector3(0, 0, 1)})
	for i in CORNER_SEGS:
		var a := lerpf(PI * 0.5, PI, float(i) / float(CORNER_SEGS))
		var o := Vector3(cos(a), 0.0, sin(a))
		pts.append({"xz": Vector2(-ix, iz) + Vector2(o.x, o.z) * CORNER_R, "out": o})
	for i in SIDE_SEGS:
		var z := lerpf(iz, -iz, float(i) / float(SIDE_SEGS))
		pts.append({"xz": Vector2(-HX, z), "out": Vector3(-1, 0, 0)})
	for i in CORNER_SEGS:
		var a := lerpf(PI, PI * 1.5, float(i) / float(CORNER_SEGS))
		var o := Vector3(cos(a), 0.0, sin(a))
		pts.append({"xz": Vector2(-ix, -iz) + Vector2(o.x, o.z) * CORNER_R, "out": o})
	for i in SIDE_SEGS:
		var x := lerpf(-ix, ix, float(i) / float(SIDE_SEGS))
		pts.append({"xz": Vector2(x, -HZ), "out": Vector3(0, 0, -1)})
	for i in CORNER_SEGS:
		var a := lerpf(PI * 1.5, TAU, float(i) / float(CORNER_SEGS))
		var o := Vector3(cos(a), 0.0, sin(a))
		pts.append({"xz": Vector2(ix, -iz) + Vector2(o.x, o.z) * CORNER_R, "out": o})
	return pts

func _at(pt: Dictionary, u: float, y: float) -> Vector3:
	var xz: Vector2 = pt.xz
	var o: Vector3 = pt.out
	return Vector3(xz.x + o.x * u, y, xz.y + o.z * u)

func _ray_rect(origin: Vector3, dir: Vector2) -> Vector3:
	var t := 1.0e6
	if absf(dir.x) > 0.00001:
		var x_bound := OUTER_MAX_X if dir.x > 0.0 else OUTER_MIN_X
		var tx := (x_bound - origin.x) / dir.x
		if tx > 0.0:
			t = minf(t, tx)
	if absf(dir.y) > 0.00001:
		var z_bound := OUTER_MAX_Z if dir.y > 0.0 else OUTER_MIN_Z
		var tz := (z_bound - origin.z) / dir.y
		if tz > 0.0:
			t = minf(t, tz)
	return Vector3(origin.x + dir.x * t, 0.0, origin.z + dir.y * t)

func _side_of(p: Vector3) -> String:
	var e := 0.08
	if absf(p.x - OUTER_MAX_X) <= e:
		return "e"
	if absf(p.x - OUTER_MIN_X) <= e:
		return "w"
	if absf(p.z - OUTER_MAX_Z) <= e:
		return "n"
	if absf(p.z - OUTER_MIN_Z) <= e:
		return "s"
	return ""

func _shared_corner(sa: String, sb: String) -> Variant:
	if sa == "" or sb == "" or sa == sb:
		return null
	var key := sa + sb
	if key == "en" or key == "ne":
		return Vector3(OUTER_MAX_X, 0.0, OUTER_MAX_Z)
	if key == "nw" or key == "wn":
		return Vector3(OUTER_MIN_X, 0.0, OUTER_MAX_Z)
	if key == "ws" or key == "sw":
		return Vector3(OUTER_MIN_X, 0.0, OUTER_MIN_Z)
	if key == "se" or key == "es":
		return Vector3(OUTER_MAX_X, 0.0, OUTER_MIN_Z)
	return null

func _tri(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	_tri_visual(verts, norms, uvs, a, b, c, na, nb, nc, ua, ub, uc)
	_thicken(faces, a, b, c)

func _quad(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	_tri(verts, norms, uvs, faces, a, b, c, na, nb, nc, ua, ub, uc)
	_tri(verts, norms, uvs, faces, a, c, d, na, nc, nd, ua, uc, ud)

func _tri_visual(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ua: Vector2 = Vector2.ZERO, ub: Vector2 = Vector2.ZERO, uc: Vector2 = Vector2.ZERO) -> void:
	var want := na + nb + nc
	if want.length() < 0.001:
		want = Vector3.UP
	if (b - a).cross(c - a).dot(want) < 0.0:
		var tb := b
		b = c
		c = tb
		var tnb := nb
		nb = nc
		nc = tnb
		var tub := ub
		ub = uc
		uc = tub
	verts.append(a)
	verts.append(b)
	verts.append(c)
	norms.append(na.normalized())
	norms.append(nb.normalized())
	norms.append(nc.normalized())
	uvs.append(ua)
	uvs.append(ub)
	uvs.append(uc)

## A thick prism under the triangle so a fast skate can't tunnel the shell.
func _thicken(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var down := Vector3(0.0, -SHELL, 0.0)
	var a2 := a + down
	var b2 := b + down
	var c2 := c + down
	if (b - a).cross(c - a).y < 0.0:
		var tb := b
		b = c
		c = tb
		var tb2 := b2
		b2 = c2
		c2 = tb2
	var sink := Vector3(0.0, -0.12, 0.0)
	faces.append(a + sink)
	faces.append(b + sink)
	faces.append(c + sink)
	faces.append(a2)
	faces.append(c2)
	faces.append(b2)
	_face_quad(faces, a, b, b2, a2)
	_face_quad(faces, b, c, c2, b2)
	_face_quad(faces, c, a, a2, c2)

func _face_quad(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	faces.append(a)
	faces.append(b)
	faces.append(c)
	faces.append(a)
	faces.append(c)
	faces.append(d)
