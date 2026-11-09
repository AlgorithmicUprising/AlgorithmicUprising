extends RefCounted

## Skinned Fony body. Original low-poly mesh, not a capsule stack.
## Vertices are in skeleton space. Joints blend between two bones so elbows and knees deform.

static func attach(root: Node3D) -> Dictionary:
	var skel := Skeleton3D.new()
	skel.name = "Skeleton"
	root.add_child(skel)
	var bones := {}
	_bone(skel, bones, "Hips", -1, Vector3(0, 1.02, 0))
	_bone(skel, bones, "Spine", bones.Hips, Vector3(0, 0.16, 0))
	_bone(skel, bones, "Chest", bones.Spine, Vector3(0, 0.16, 0))
	_bone(skel, bones, "Neck", bones.Chest, Vector3(0, 0.18, 0))
	_bone(skel, bones, "Head", bones.Neck, Vector3(0, 0.10, 0))
	_bone(skel, bones, "ArmL", bones.Chest, Vector3(-0.20, 0.08, 0))
	_bone(skel, bones, "ForeL", bones.ArmL, Vector3(0, -0.26, 0))
	_bone(skel, bones, "HandL", bones.ForeL, Vector3(0, -0.22, 0))
	_bone(skel, bones, "ArmR", bones.Chest, Vector3(0.20, 0.08, 0))
	_bone(skel, bones, "ForeR", bones.ArmR, Vector3(0, -0.26, 0))
	_bone(skel, bones, "HandR", bones.ForeR, Vector3(0, -0.22, 0))
	_bone(skel, bones, "LegL", bones.Hips, Vector3(-0.08, -0.04, 0))
	_bone(skel, bones, "ShinL", bones.LegL, Vector3(0, -0.42, 0))
	_bone(skel, bones, "AnkleL", bones.ShinL, Vector3(0, -0.42, 0))
	_bone(skel, bones, "LegR", bones.Hips, Vector3(0.08, -0.04, 0))
	_bone(skel, bones, "ShinR", bones.LegR, Vector3(0, -0.42, 0))
	_bone(skel, bones, "AnkleR", bones.ShinR, Vector3(0, -0.42, 0))
	var skin := skel.create_skin_from_rest_transforms()
	var g := {}
	for name in bones:
		g[name] = _global_rest(skel, bones[name])
	var skin_c := Color("f0c9a0")
	var hair_c := Color("c4622d")
	var jacket := Color("c46a32")
	var hoodie := Color("1a1a1e")
	var pants := Color("5c6b3a")
	var pads := Color("e23d78")
	var shoes := Color("c4b5a0")
	var head: Vector3 = g.Head
	_ellipsoid(skel, skin, "HeadMesh", head, Vector3(0.105, 0.12, 0.108), bones.Head, skin_c, true)
	_face(skel, skin, head, bones.Head)
	_eyes(skel, skin, head, bones.Head)
	_hair(skel, skin, head, bones.Head, hair_c)
	_torso(skel, skin, g, bones, jacket, hoodie)
	_limb(skel, skin, g.ArmL, g.ForeL, g.HandL, 0.055, 0.045, 0.038, bones.ArmL, bones.ForeL, bones.HandL, jacket)
	_limb(skel, skin, g.ArmR, g.ForeR, g.HandR, 0.055, 0.045, 0.038, bones.ArmR, bones.ForeR, bones.HandR, jacket)
	_hand(skel, skin, g.HandL, bones.HandL, skin_c, -1.0)
	_hand(skel, skin, g.HandR, bones.HandR, skin_c, 1.0)
	_limb(skel, skin, g.LegL, g.ShinL, g.AnkleL, 0.085, 0.07, 0.055, bones.LegL, bones.ShinL, bones.AnkleL, pants)
	_limb(skel, skin, g.LegR, g.ShinR, g.AnkleR, 0.085, 0.07, 0.055, bones.LegR, bones.ShinR, bones.AnkleR, pants)
	_pad(skel, skin, g.ShinL, bones.ShinL, pads)
	_pad(skel, skin, g.ShinR, bones.ShinR, pads)
	_shoe(skel, skin, g.AnkleL, bones.AnkleL, shoes)
	_shoe(skel, skin, g.AnkleR, bones.AnkleR, shoes)
	var ankle_l := Marker3D.new()
	ankle_l.name = "AnkleL"
	root.add_child(ankle_l)
	var ankle_r := Marker3D.new()
	ankle_r.name = "AnkleR"
	root.add_child(ankle_r)
	var hand_r := Marker3D.new()
	hand_r.name = "HandR"
	root.add_child(hand_r)
	return {"skeleton": skel, "bones": bones, "skin": skin, "ankle_l": ankle_l, "ankle_r": ankle_r, "hand_r": hand_r}

static func _bone(skel: Skeleton3D, bones: Dictionary, bone_name: String, parent: int, origin: Vector3) -> void:
	var idx := skel.add_bone(bone_name)
	bones[bone_name] = idx
	if parent >= 0:
		skel.set_bone_parent(idx, parent)
	skel.set_bone_rest(idx, Transform3D(Basis.IDENTITY, origin))
	skel.set_bone_pose_position(idx, origin)
	skel.set_bone_pose_rotation(idx, Quaternion.IDENTITY)

static func _global_rest(skel: Skeleton3D, idx: int) -> Vector3:
	var chain: Array[int] = []
	var i := idx
	while i >= 0:
		chain.push_front(i)
		i = skel.get_bone_parent(i)
	var t := Transform3D.IDENTITY
	for bone_idx in chain:
		t = t * skel.get_bone_rest(bone_idx)
	return t.origin

static func _commit(skel: Skeleton3D, skin: Skin, node_name: String, surf: Dictionary, tex: Texture2D = null) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = surf.verts
	arrays[Mesh.ARRAY_NORMAL] = surf.norms
	arrays[Mesh.ARRAY_TEX_UV] = surf.uvs
	arrays[Mesh.ARRAY_BONES] = surf.bones
	arrays[Mesh.ARRAY_WEIGHTS] = surf.weights
	arrays[Mesh.ARRAY_INDEX] = surf.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.skin = skin
	inst.skeleton = NodePath("..")
	if tex != null:
		inst.material_override = load("res://scripts/world_blocks.gd").cel_textured(Color.WHITE, tex, 3.0, 0.16)
	else:
		inst.material_override = load("res://scripts/world_blocks.gd").cel(surf.color, 3.0, 0.2)
	skel.add_child(inst)
	return inst

static func _surf(color: Color) -> Dictionary:
	return {
		"color": color,
		"verts": PackedVector3Array(),
		"norms": PackedVector3Array(),
		"uvs": PackedVector2Array(),
		"bones": PackedInt32Array(),
		"weights": PackedFloat32Array(),
		"indices": PackedInt32Array(),
	}

static func _vert(surf: Dictionary, p: Vector3, n: Vector3, uv: Vector2, b0: int, b1: int, w0: float) -> int:
	surf.verts.append(p)
	surf.norms.append(n.normalized() if n.length() > 0.0001 else Vector3.UP)
	surf.uvs.append(uv)
	surf.bones.append_array(PackedInt32Array([b0, b1, 0, 0]))
	var w1 := 1.0 - w0
	surf.weights.append_array(PackedFloat32Array([w0, w1, 0.0, 0.0]))
	return surf.verts.size() - 1

static func _tri(surf: Dictionary, a: int, b: int, c: int) -> void:
	surf.indices.append_array(PackedInt32Array([a, b, c]))

static func _ellipsoid(skel: Skeleton3D, skin: Skin, node_name: String, center: Vector3, radii: Vector3, bone: int, color: Color, chin: bool) -> void:
	var surf := _surf(color)
	var stacks := 10
	var slices := 12
	for iy in stacks + 1:
		var v := float(iy) / stacks
		var phi := lerpf(-PI * 0.5, PI * 0.5, v)
		var ring := []
		for ix in slices:
			var u := float(ix) / slices
			var theta := u * TAU
			var cp := cos(phi)
			var nrm := Vector3(cos(theta) * cp, sin(phi), sin(theta) * cp)
			var p := center + Vector3(nrm.x * radii.x, nrm.y * radii.y, nrm.z * radii.z)
			if chin and nrm.y < 0.0:
				var pinch := 1.0 + nrm.y * 0.28
				p.x = center.x + (p.x - center.x) * pinch
				p.z = center.z + (p.z - center.z) * pinch
			ring.append(_vert(surf, p, nrm, Vector2(u, v), bone, bone, 1.0))
		if iy == 0:
			continue
		var prev: Array = ring # placeholder replaced below
		prev = []
	# rebuild with stored rings
	surf = _surf(color)
	var rings: Array = []
	for iy in stacks + 1:
		var v := float(iy) / stacks
		var phi := lerpf(-PI * 0.5, PI * 0.5, v)
		var ring: Array[int] = []
		for ix in slices:
			var u := float(ix) / slices
			var theta := u * TAU
			var cp := cos(phi)
			var nrm := Vector3(cos(theta) * cp, sin(phi), sin(theta) * cp)
			var p := center + Vector3(nrm.x * radii.x, nrm.y * radii.y, nrm.z * radii.z)
			if chin and nrm.y < 0.0:
				var pinch := 1.0 + nrm.y * 0.28
				p.x = center.x + (p.x - center.x) * pinch
				p.z = center.z + (p.z - center.z) * pinch
			ring.append(_vert(surf, p, nrm, Vector2(u, v), bone, bone, 1.0))
		rings.append(ring)
	for iy in stacks:
		for ix in slices:
			var i1 := ix
			var i2 := (ix + 1) % slices
			var a: int = rings[iy][i1]
			var b: int = rings[iy][i2]
			var c: int = rings[iy + 1][i2]
			var d: int = rings[iy + 1][i1]
			_tri(surf, a, d, b)
			_tri(surf, b, d, c)
	_commit(skel, skin, node_name, surf)

static func _face(skel: Skeleton3D, skin: Skin, center: Vector3, bone: int) -> void:
	var tex: Texture2D = load("res://assets/library/fony/face_albedo.png")
	var surf := _surf(Color.WHITE)
	var rows := 6
	var cols := 6
	var grid: Array = []
	for iy in rows:
		var row: Array[int] = []
		var v := float(iy) / (rows - 1)
		for ix in cols:
			var u := float(ix) / (cols - 1)
			var ang_y := lerpf(-0.55, 0.42, v)
			var ang_x := lerpf(-0.62, 0.62, u)
			var nrm := Vector3(sin(ang_x) * cos(ang_y), sin(ang_y), -cos(ang_x) * cos(ang_y)).normalized()
			var p := center + Vector3(nrm.x * 0.108, nrm.y * 0.122, nrm.z * 0.112 - 0.004)
			row.append(_vert(surf, p, nrm, Vector2(u, 1.0 - v), bone, bone, 1.0))
		grid.append(row)
	for iy in rows - 1:
		for ix in cols - 1:
			var a: int = grid[iy][ix]
			var b: int = grid[iy][ix + 1]
			var c: int = grid[iy + 1][ix + 1]
			var d: int = grid[iy + 1][ix]
			_tri(surf, a, b, d)
			_tri(surf, b, c, d)
	_commit(skel, skin, "Face", surf, tex)

static func _eyes(skel: Skeleton3D, skin: Skin, center: Vector3, bone: int) -> void:
	for side in [-1.0, 1.0]:
		var eye := center + Vector3(side * 0.038, 0.02, -0.09)
		_ellipsoid(skel, skin, "Eye", eye, Vector3(0.018, 0.014, 0.012), bone, Color("f7f1ea"), false)
		_ellipsoid(skel, skin, "Iris", eye + Vector3(0, 0, -0.01), Vector3(0.008, 0.008, 0.006), bone, Color("2a211c"), false)
		_ellipsoid(skel, skin, "Brow", eye + Vector3(0, 0.028, 0.004), Vector3(0.026, 0.006, 0.01), bone, Color("6a3a22"), false)
	_ellipsoid(skel, skin, "Nose", center + Vector3(0, -0.01, -0.108), Vector3(0.012, 0.016, 0.016), bone, Color("e7b48e"), false)
	_ellipsoid(skel, skin, "Mouth", center + Vector3(0, -0.045, -0.098), Vector3(0.028, 0.008, 0.01), bone, Color("a85a52"), false)

static func _hair(skel: Skeleton3D, skin: Skin, center: Vector3, bone: int, color: Color) -> void:
	var scalp := center + Vector3(0, 0.08, 0.01)
	var dirs := [
		Vector3(0.15, 0.92, -0.2), Vector3(-0.35, 0.85, -0.1), Vector3(0.45, 0.78, 0.05),
		Vector3(-0.1, 0.7, 0.45), Vector3(0.25, 0.75, 0.4), Vector3(-0.55, 0.7, 0.2),
		Vector3(0.05, 0.95, 0.15), Vector3(0.6, 0.55, -0.15),
	]
	for i in dirs.size():
		var dir: Vector3 = dirs[i].normalized()
		var length := 0.16 if i < 4 else 0.11
		_tube(skel, skin, "Hair" if i == 0 else "Tuft%d" % i, scalp + dir * 0.02, scalp + dir * length, 0.045, 0.012, bone, bone, color, 7)

static func _torso(skel: Skeleton3D, skin: Skin, g: Dictionary, bones: Dictionary, jacket: Color, hoodie: Color) -> void:
	var hip: Vector3 = g.Hips
	var chest: Vector3 = g.Chest
	var neck: Vector3 = g.Neck
	var sections := [
		hip + Vector3(0, -0.02, 0),
		hip.lerp(chest, 0.45) + Vector3(0, 0, 0.01),
		chest + Vector3(0, -0.02, 0),
		chest + Vector3(0, 0.08, 0),
	]
	var radii := [Vector2(0.15, 0.11), Vector2(0.13, 0.10), Vector2(0.17, 0.12), Vector2(0.24, 0.13)]
	var binds := [bones.Hips, bones.Spine, bones.Chest, bones.Chest]
	_loft(skel, skin, "Jacket", sections, radii, binds, jacket, 12)
	_loft(skel, skin, "Hoodie", [chest + Vector3(0, 0.02, 0.02), neck + Vector3(0, 0.02, 0.02)], [Vector2(0.09, 0.08), Vector2(0.07, 0.07)], [bones.Chest, bones.Neck], hoodie, 10)
	var head: Vector3 = g.Head
	_ellipsoid(skel, skin, "Hood", head + Vector3(0, 0.02, 0.06), Vector3(0.13, 0.11, 0.11), bones.Head, hoodie, false)
	var patch := _surf(Color("6a727a"))
	_plate(patch, chest + Vector3(0.08, 0.02, -0.125), Vector3(0.05, 0.045, 0.008), bones.Chest)
	_commit(skel, skin, "Patch", patch)
	var tape := _surf(Color("e23d78"))
	_plate(tape, chest + Vector3(-0.07, -0.02, -0.12), Vector3(0.035, 0.03, 0.008), bones.Chest)
	_commit(skel, skin, "Tape", tape)

static func _loft(skel: Skeleton3D, skin: Skin, node_name: String, sections: Array, radii: Array, binds: Array, color: Color, sides: int) -> void:
	var surf := _surf(color)
	var rings: Array = []
	for s in sections.size():
		var ring: Array[int] = []
		var center: Vector3 = sections[s]
		var rad: Vector2 = radii[s]
		var bone: int = binds[s]
		for i in sides:
			var a := TAU * float(i) / sides
			var nrm := Vector3(cos(a), 0, sin(a))
			var p := center + Vector3(nrm.x * rad.x, 0, nrm.z * rad.y)
			ring.append(_vert(surf, p, nrm, Vector2(float(i) / sides, float(s) / sections.size()), bone, bone, 1.0))
		rings.append(ring)
	for s in sections.size() - 1:
		for i in sides:
			var i2 := (i + 1) % sides
			var a: int = rings[s][i]
			var b: int = rings[s][i2]
			var c: int = rings[s + 1][i2]
			var d: int = rings[s + 1][i]
			_tri(surf, a, b, d)
			_tri(surf, b, c, d)
	_commit(skel, skin, node_name, surf)

static func _limb(skel: Skeleton3D, skin: Skin, a: Vector3, b: Vector3, c: Vector3, ra: float, rb: float, rc: float, ba: int, bb: int, bc: int, color: Color) -> void:
	_tube(skel, skin, "Upper", a, b, ra, rb, ba, bb, color, 8)
	_tube(skel, skin, "Lower", b, c, rb * 0.95, rc, bb, bc, color, 8)

static func _tube(skel: Skeleton3D, skin: Skin, node_name: String, a: Vector3, b: Vector3, ra: float, rb: float, ba: int, bb: int, color: Color, sides: int) -> void:
	var surf := _surf(color)
	var axis := b - a
	var length := axis.length()
	if length < 0.001:
		return
	var dir := axis / length
	var helper := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.92 else Vector3.FORWARD
	var side: Vector3 = dir.cross(helper).normalized()
	var bin := dir.cross(side).normalized()
	var rings := 5
	var ids: Array = []
	for r in rings:
		var t := float(r) / (rings - 1)
		var center := a.lerp(b, t)
		var rad := lerpf(ra, rb, t)
		var w0 := 1.0 - smoothstep(0.46, 0.54, t)
		var row: Array[int] = []
		for i in sides:
			var ang := TAU * float(i) / sides
			var nrm := (side * cos(ang) + bin * sin(ang)).normalized()
			row.append(_vert(surf, center + nrm * rad, nrm, Vector2(float(i) / sides, t), ba, bb, w0))
		ids.append(row)
	for r in rings - 1:
		for i in sides:
			var i2 := (i + 1) % sides
			var a0: int = ids[r][i]
			var b0: int = ids[r][i2]
			var c0: int = ids[r + 1][i2]
			var d0: int = ids[r + 1][i]
			_tri(surf, a0, d0, b0)
			_tri(surf, b0, d0, c0)
	_commit(skel, skin, node_name, surf)

static func _pad(skel: Skeleton3D, skin: Skin, knee: Vector3, bone: int, color: Color) -> void:
	_ellipsoid(skel, skin, "Pad", knee + Vector3(0, 0.02, -0.06), Vector3(0.055, 0.04, 0.035), bone, color, false)

static func _shoe(skel: Skeleton3D, skin: Skin, ankle: Vector3, bone: int, color: Color) -> void:
	_ellipsoid(skel, skin, "Shoe", ankle + Vector3(0, -0.03, -0.05), Vector3(0.05, 0.035, 0.12), bone, color, false)
	_ellipsoid(skel, skin, "Sole", ankle + Vector3(0, -0.055, -0.04), Vector3(0.052, 0.012, 0.125), bone, Color("2a211c"), false)
	_ellipsoid(skel, skin, "Stripe", ankle + Vector3(0, -0.01, -0.05), Vector3(0.02, 0.01, 0.09), bone, Color("1a1a1e"), false)

static func _hand(skel: Skeleton3D, skin: Skin, wrist: Vector3, bone: int, color: Color, side: float) -> void:
	var palm := wrist + Vector3(side * 0.01, -0.04, -0.01)
	_ellipsoid(skel, skin, "Palm", palm, Vector3(0.028, 0.04, 0.016), bone, color, false)
	for i in 4:
		var origin := palm + Vector3(side * lerpf(-0.02, 0.02, float(i) / 3.0), -0.035, -0.008)
		_tube(skel, skin, "Finger", origin, origin + Vector3(0, -0.03, -0.008), 0.007, 0.005, bone, bone, color, 5)
	var thumb_from := palm + Vector3(side * 0.03, -0.005, -0.008)
	_tube(skel, skin, "Thumb", thumb_from, thumb_from + Vector3(side * 0.02, -0.02, -0.012), 0.008, 0.006, bone, bone, color, 5)

static func _plate(surf: Dictionary, center: Vector3, size: Vector3, bone: int) -> void:
	var hx := size.x
	var hy := size.y
	var hz := size.z
	var corners := [
		center + Vector3(-hx, -hy, -hz), center + Vector3(hx, -hy, -hz),
		center + Vector3(hx, hy, -hz), center + Vector3(-hx, hy, -hz),
		center + Vector3(-hx, -hy, hz), center + Vector3(hx, -hy, hz),
		center + Vector3(hx, hy, hz), center + Vector3(-hx, hy, hz),
	]
	var ids: Array[int] = []
	for c in corners:
		ids.append(_vert(surf, c, Vector3(0, 0, -1), Vector2(0, 0), bone, bone, 1.0))
	var faces := [[0, 1, 2, 3], [4, 6, 5, 7], [0, 4, 5, 1], [3, 2, 6, 7], [0, 3, 7, 4], [1, 5, 6, 2]]
	for f in faces:
		_tri(surf, ids[f[0]], ids[f[1]], ids[f[2]])
		_tri(surf, ids[f[0]], ids[f[2]], ids[f[3]])
