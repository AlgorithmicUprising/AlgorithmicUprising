extends RefCounted

## Skinned Fony body aimed at the Nov 9 2026 character sheet.
## Same bone rests as the gameplay rig. Original geometry, no third-party mesh.

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
	_bone(skel, bones, "ArmL", bones.Chest, Vector3(-0.22, 0.10, 0))
	_bone(skel, bones, "ForeL", bones.ArmL, Vector3(0, -0.26, 0))
	_bone(skel, bones, "HandL", bones.ForeL, Vector3(0, -0.22, 0))
	_bone(skel, bones, "ArmR", bones.Chest, Vector3(0.22, 0.10, 0))
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
	_body(skel, skin, g, bones)
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

static func _body(skel: Skeleton3D, skin: Skin, g: Dictionary, bones: Dictionary) -> void:
	var skin_c := Color("e7b898")
	var hair := Color("d4652a")
	var hair_tip := Color("e8a05a")
	var jacket := Color("c46a32")
	var hoodie := Color("1a1a1e")
	var pants := Color("5c6a38")
	var pad := Color("e23d78")
	var pad_core := Color("9a2458")
	var shoe := Color("d2c3a4")
	var head: Vector3 = g.Head
	_head(skel, skin, head, bones.Head, skin_c)
	_hair(skel, skin, head, bones.Head, hair, hair_tip)
	_neck(skel, skin, g.Neck, head, bones.Neck, bones.Head, skin_c, hoodie)
	_hoodie(skel, skin, bones, hoodie)
	_jacket(skel, skin, bones, jacket, hoodie)
	_arm(skel, skin, g.ArmL, g.ForeL, g.HandL, bones.ArmL, bones.ForeL, bones.HandL, jacket, hoodie, skin_c, -1.0)
	_arm(skel, skin, g.ArmR, g.ForeR, g.HandR, bones.ArmR, bones.ForeR, bones.HandR, jacket, hoodie, skin_c, 1.0)
	_leg(skel, skin, g.LegL, g.ShinL, g.AnkleL, bones.LegL, bones.ShinL, bones.AnkleL, pants, pad, pad_core, shoe, -1.0)
	_leg(skel, skin, g.LegR, g.ShinR, g.AnkleR, bones.LegR, bones.ShinR, bones.AnkleR, pants, pad, pad_core, shoe, 1.0)

static func _head(skel: Skeleton3D, skin: Skin, center: Vector3, bone: int, color: Color) -> void:
	var sections := [
		[0.0, Vector3(0, -0.105, 0.01), Vector2(0.045, 0.055)],
		[0.0, Vector3(0, -0.07, -0.005), Vector2(0.062, 0.072)],
		[0.0, Vector3(0, -0.03, -0.01), Vector2(0.074, 0.082)],
		[0.0, Vector3(0, 0.01, -0.012), Vector2(0.078, 0.086)],
		[0.0, Vector3(0, 0.05, -0.008), Vector2(0.08, 0.084)],
		[0.0, Vector3(0, 0.09, 0.0), Vector2(0.074, 0.078)],
		[0.0, Vector3(0, 0.125, 0.01), Vector2(0.05, 0.055)],
	]
	_head_loft(skel, skin, "Skull", center, sections, bone, color, 14)
	for side in [-1.0, 1.0]:
		var eye := center + Vector3(side * 0.032, 0.018, -0.096)
		_disc(skel, skin, "Sclera", eye, 0.015, 0.011, bone, Color("f4efe8"))
		_disc(skel, skin, "Iris", eye + Vector3(0, -0.001, -0.004), 0.0075, 0.0075, bone, Color("8a5424"))
		_disc(skel, skin, "Pupil", eye + Vector3(0, -0.001, -0.007), 0.0035, 0.0035, bone, Color("1c140f"))
		_box(skel, skin, "Brow", center + Vector3(side * 0.032, 0.042, -0.098), Vector3(0.024, 0.005, 0.006), bone, Color("5c321c"))
		_box(skel, skin, "Ear", center + Vector3(side * 0.078, -0.005, 0.0), Vector3(0.008, 0.018, 0.012), bone, color)
	_box(skel, skin, "Nose", center + Vector3(0, -0.012, -0.104), Vector3(0.011, 0.008, 0.01), bone, Color("d7a684"))
	_box(skel, skin, "Mouth", center + Vector3(0, -0.048, -0.098), Vector3(0.02, 0.004, 0.005), bone, Color("b85c56"))
	_box(skel, skin, "SmileL", center + Vector3(-0.018, -0.044, -0.096), Vector3(0.008, 0.003, 0.004), bone, Color("b85c56"))
	_box(skel, skin, "SmileR", center + Vector3(0.018, -0.044, -0.096), Vector3(0.008, 0.003, 0.004), bone, Color("b85c56"))

static func _hair(skel: Skeleton3D, skin: Skin, center: Vector3, bone: int, color: Color, tip: Color) -> void:
	_hair_cap(skel, skin, center, bone, color)
	for side in [-1.0, 1.0]:
		_box(skel, skin, "Bang", center + Vector3(side * 0.03, 0.055, -0.07), Vector3(0.028, 0.02, 0.018), bone, color)
	_box(skel, skin, "BangMid", center + Vector3(0, 0.07, -0.06), Vector3(0.02, 0.018, 0.016), bone, tip)
	var spikes := [
		[Vector3(0.0, 0.12, 0.0), Vector3(0.0, 0.20, -0.01), 0.04, true],
		[Vector3(-0.045, 0.11, 0.0), Vector3(-0.07, 0.18, -0.01), 0.034, false],
		[Vector3(0.048, 0.11, 0.01), Vector3(0.075, 0.17, 0.0), 0.032, false],
		[Vector3(-0.02, 0.12, 0.035), Vector3(-0.02, 0.19, 0.05), 0.034, false],
		[Vector3(0.025, 0.12, 0.04), Vector3(0.03, 0.18, 0.055), 0.03, true],
		[Vector3(0.0, 0.10, 0.055), Vector3(0.0, 0.15, 0.09), 0.036, false],
		[Vector3(-0.06, 0.08, 0.02), Vector3(-0.1, 0.13, 0.02), 0.026, false],
		[Vector3(0.06, 0.08, 0.02), Vector3(0.1, 0.13, 0.02), 0.026, true],
		[Vector3(-0.025, 0.10, -0.03), Vector3(-0.03, 0.15, -0.045), 0.024, false],
		[Vector3(0.02, 0.10, -0.03), Vector3(0.025, 0.145, -0.045), 0.022, true],
	]
	for i in spikes.size():
		var item: Array = spikes[i]
		var base: Vector3 = center + item[0]
		var end: Vector3 = center + item[1]
		var name := "Hair" if i == 0 else "Tuft%d" % i
		_spike(skel, skin, name, base, end - base, Vector3(item[2], item[2] * 0.7, item[2]), bone, tip if item[3] else color)

static func _hair_cap(skel: Skeleton3D, skin: Skin, center: Vector3, bone: int, color: Color) -> void:
	var sections := [
		[0.0, Vector3(0, 0.055, 0.008), Vector2(0.088, 0.09)],
		[0.0, Vector3(0, 0.07, 0.0), Vector2(0.086, 0.09)],
		[0.0, Vector3(0, 0.11, 0.005), Vector2(0.07, 0.075)],
		[0.0, Vector3(0, 0.145, 0.01), Vector2(0.04, 0.045)],
	]
	_head_loft(skel, skin, "HairCap", center, sections, bone, color, 12)

static func _neck(skel: Skeleton3D, skin: Skin, neck: Vector3, head: Vector3, neck_b: int, head_b: int, skin_c: Color, hoodie: Color) -> void:
	_volume(skel, skin, "Neck", neck + Vector3(0, -0.01, 0), head + Vector3(0, -0.06, 0.01), [[0.0, 0.04, 0.038], [1.0, 0.042, 0.04]], neck_b, head_b, skin_c, 8)
	_box(skel, skin, "Collar", neck + Vector3(0, 0.01, 0.01), Vector3(0.06, 0.035, 0.055), neck_b, hoodie)

static func _hoodie(skel: Skeleton3D, skin: Skin, bones: Dictionary, color: Color) -> void:
	_closed_y(skel, skin, "Hoodie", [
		[0.98, 0.12, 0.09, bones.Hips],
		[1.16, 0.115, 0.085, bones.Spine],
		[1.34, 0.135, 0.095, bones.Chest],
		[1.48, 0.07, 0.06, bones.Neck],
	], color, 12)

static func _jacket(skel: Skeleton3D, skin: Skin, bones: Dictionary, jacket: Color, hoodie: Color) -> void:
	_open_y(skel, skin, "Jacket", [
		[0.96, 0.17, 0.12, bones.Hips],
		[1.08, 0.15, 0.105, bones.Hips],
		[1.24, 0.155, 0.11, bones.Spine],
		[1.40, 0.20, 0.13, bones.Chest],
		[1.48, 0.175, 0.12, bones.Chest],
	], jacket, 12, 0.5)
	_box(skel, skin, "LapelL", Vector3(-0.045, 1.30, -0.125), Vector3(0.012, 0.09, 0.008), bones.Chest, jacket)
	_box(skel, skin, "LapelR", Vector3(0.045, 1.30, -0.125), Vector3(0.012, 0.09, 0.008), bones.Chest, jacket)
	# Character faces -Z. His right chest is -X, which is the viewer's left.
	_box(skel, skin, "PatchPink", Vector3(0.075, 1.30, -0.135), Vector3(0.026, 0.032, 0.008), bones.Chest, Color("e23d78"))
	_box(skel, skin, "PatchGray", Vector3(-0.1, 1.44, -0.09), Vector3(0.03, 0.026, 0.01), bones.Chest, Color("8a9096"))
	_box(skel, skin, "Button", Vector3(0.0, 1.18, -0.115), Vector3(0.012, 0.012, 0.008), bones.Spine, Color("c8c2b4"))
	_box(skel, skin, "ButtonLow", Vector3(0.0, 1.05, -0.11), Vector3(0.012, 0.012, 0.008), bones.Hips, Color("c8c2b4"))
	_box(skel, skin, "HemFray", Vector3(0, 0.95, -0.02), Vector3(0.16, 0.012, 0.11), bones.Hips, Color("a8562c"))

static func _arm(skel: Skeleton3D, skin: Skin, shoulder: Vector3, elbow: Vector3, wrist: Vector3, b0: int, b1: int, b2: int, jacket: Color, hoodie: Color, skin_c: Color, side: float) -> void:
	_volume(skel, skin, "Sleeve", shoulder + Vector3(-side * 0.02, 0.02, 0), elbow, [[0.0, 0.075, 0.065], [0.4, 0.058, 0.05], [1.0, 0.048, 0.044]], b0, b1, jacket, 8)
	_box(skel, skin, "ShoulderCap", shoulder + Vector3(-side * 0.01, 0.015, 0), Vector3(0.05, 0.04, 0.05), b0, jacket)
	_volume(skel, skin, "ForeSleeve", elbow, wrist, [[0.0, 0.05, 0.046], [0.6, 0.042, 0.04], [1.0, 0.036, 0.034]], b1, b2, jacket, 8)
	_box(skel, skin, "Cuff", wrist + Vector3(0, 0.02, 0), Vector3(0.042, 0.02, 0.038), b2, hoodie)
	_box(skel, skin, "Tape", elbow + Vector3(side * 0.01, -0.04, -0.03), Vector3(0.03, 0.04, 0.012), b1, Color("e6d2b0"))
	if side < 0.0:
		_box(skel, skin, "ShoulderPatch", shoulder + Vector3(0.0, 0.02, -0.045), Vector3(0.028, 0.022, 0.01), b0, Color("8a9096"))
	_hand(skel, skin, wrist, b2, skin_c, side)

static func _hand(skel: Skeleton3D, skin: Skin, wrist: Vector3, bone: int, color: Color, side: float) -> void:
	var palm := wrist + Vector3(side * 0.004, -0.05, -0.012)
	_box(skel, skin, "Palm", palm, Vector3(0.038, 0.03, 0.016), bone, color)
	for i in 4:
		var x := lerpf(-0.027, 0.027, float(i) / 3.0)
		_box(skel, skin, "Finger", palm + Vector3(x, -0.055, -0.006), Vector3(0.0065, 0.024, 0.007), bone, color)
	_box(skel, skin, "Thumb", palm + Vector3(side * 0.042, -0.012, -0.008), Vector3(0.014, 0.01, 0.008), bone, color)

static func _leg(skel: Skeleton3D, skin: Skin, hip: Vector3, knee: Vector3, ankle: Vector3, b0: int, b1: int, b2: int, pants: Color, pad: Color, core: Color, shoe: Color, side: float) -> void:
	_volume(skel, skin, "Thigh", hip, knee, [[0.0, 0.105, 0.085], [0.5, 0.09, 0.075], [1.0, 0.062, 0.058]], b0, b1, pants, 8)
	_volume(skel, skin, "Shin", knee, ankle, [[0.0, 0.055, 0.05], [0.4, 0.06, 0.052], [1.0, 0.04, 0.038]], b1, b2, pants, 8)
	_box(skel, skin, "Pocket", hip + Vector3(side * 0.07, -0.12, -0.02), Vector3(0.03, 0.045, 0.018), b0, Color("3f4a28"))
	var cap := knee + Vector3(0, 0.02, -0.06)
	_disc(skel, skin, "Pad", cap, 0.055, 0.045, b1, pad)
	_disc(skel, skin, "PadCore", cap + Vector3(0, 0, -0.006), 0.028, 0.022, b1, core)
	_shoe(skel, skin, ankle, b2, shoe)

static func _shoe(skel: Skeleton3D, skin: Skin, ankle: Vector3, bone: int, color: Color) -> void:
	var mid := ankle + Vector3(0, -0.04, -0.055)
	_box(skel, skin, "Shoe", mid, Vector3(0.055, 0.036, 0.12), bone, color)
	_box(skel, skin, "Toe", mid + Vector3(0, 0.006, -0.075), Vector3(0.05, 0.028, 0.045), bone, Color("cbb89a"))
	_box(skel, skin, "Sole", mid + Vector3(0, -0.032, -0.012), Vector3(0.06, 0.014, 0.135), bone, Color("c4a574"))
	_box(skel, skin, "Stripe", mid + Vector3(0, 0.008, -0.012), Vector3(0.058, 0.012, 0.09), bone, Color("2a211c"))

static func _head_loft(skel: Skeleton3D, skin: Skin, node_name: String, center: Vector3, sections: Array, bone: int, color: Color, sides: int) -> void:
	var surf := _surf(color)
	var rings: Array = []
	for section in sections:
		var offset: Vector3 = section[1]
		var rad: Vector2 = section[2]
		var row: Array[int] = []
		for i in sides:
			var a := TAU * float(i) / sides
			var p := center + offset + Vector3(sin(a) * rad.x, 0, -cos(a) * rad.y)
			var n := Vector3(sin(a), 0, -cos(a))
			row.append(_vert(surf, p, n, Vector2(float(i) / sides, 0), bone, bone, 1.0))
		rings.append(row)
	for r in rings.size() - 1:
		for i in sides:
			var j := (i + 1) % sides
			var a: int = rings[r][i]
			var b: int = rings[r][j]
			var c: int = rings[r + 1][j]
			var d: int = rings[r + 1][i]
			_tri(surf, a, b, d)
			_tri(surf, b, c, d)
	var top: int = rings[rings.size() - 1][0]
	var bot: int = rings[0][0]
	for i in sides - 1:
		_tri(surf, top, rings[rings.size() - 1][i], rings[rings.size() - 1][i + 1])
		_tri(surf, bot, rings[0][i + 1], rings[0][i])
	_commit(skel, skin, node_name, surf)

static func _closed_y(skel: Skeleton3D, skin: Skin, node_name: String, sections: Array, color: Color, sides: int) -> void:
	var surf := _surf(color)
	var rings: Array = []
	for section in sections:
		var y: float = section[0]
		var rx: float = section[1]
		var rz: float = section[2]
		var bone: int = section[3]
		var row: Array[int] = []
		for i in sides:
			var a := TAU * float(i) / sides
			var p := Vector3(sin(a) * rx, y, -cos(a) * rz)
			row.append(_vert(surf, p, Vector3(sin(a), 0, -cos(a)), Vector2(0, 0), bone, bone, 1.0))
		rings.append(row)
	for r in rings.size() - 1:
		for i in sides:
			var j := (i + 1) % sides
			var a: int = rings[r][i]
			var b: int = rings[r][j]
			var c: int = rings[r + 1][j]
			var d: int = rings[r + 1][i]
			_tri(surf, a, b, d)
			_tri(surf, b, c, d)
	_commit(skel, skin, node_name, surf)

static func _open_y(skel: Skeleton3D, skin: Skin, node_name: String, sections: Array, color: Color, sides: int, gap: float) -> void:
	var surf := _surf(color)
	var count := sides
	var outer: Array = []
	var inner: Array = []
	for section in sections:
		var y: float = section[0]
		var rx: float = section[1]
		var rz: float = section[2]
		var bone: int = section[3]
		var o: Array[int] = []
		var inn: Array[int] = []
		for i in count:
			var t := float(i) / (count - 1)
			var a := lerpf(gap, TAU - gap, t)
			var p := Vector3(sin(a) * rx, y, -cos(a) * rz)
			var q := Vector3(sin(a) * (rx - 0.015), y, -cos(a) * (rz - 0.012))
			var n := Vector3(sin(a), 0, -cos(a))
			o.append(_vert(surf, p, n, Vector2(0, 0), bone, bone, 1.0))
			inn.append(_vert(surf, q, -n, Vector2(0, 0), bone, bone, 1.0))
		outer.append(o)
		inner.append(inn)
	for r in outer.size() - 1:
		for i in count - 1:
			_tri(surf, outer[r][i], outer[r][i + 1], outer[r + 1][i])
			_tri(surf, outer[r][i + 1], outer[r + 1][i + 1], outer[r + 1][i])
			_tri(surf, inner[r][i + 1], inner[r][i], inner[r + 1][i])
			_tri(surf, inner[r][i + 1], inner[r + 1][i], inner[r + 1][i + 1])
	_commit(skel, skin, node_name, surf)

static func _volume(skel: Skeleton3D, skin: Skin, node_name: String, a: Vector3, b: Vector3, profile: Array, ba: int, bb: int, color: Color, sides: int) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 0.001:
		return
	var dir := axis / length
	var helper := Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var side := dir.cross(helper).normalized()
	var up := side.cross(dir).normalized()
	var surf := _surf(color)
	var rings: Array = []
	for sample in profile:
		var t: float = sample[0]
		var rx: float = sample[1]
		var rz: float = sample[2]
		var center := a + axis * t
		var w := 1.0 - clampf((t - 0.35) / 0.3, 0.0, 1.0)
		var row: Array[int] = []
		for i in sides:
			var ang := TAU * float(i) / sides
			var n := (side * cos(ang) + up * sin(ang)).normalized()
			row.append(_vert(surf, center + Vector3(n.x * rx, n.y * rx, n.z * rz), n, Vector2(0, t), ba, bb, w))
		rings.append(row)
	for r in rings.size() - 1:
		for i in sides:
			var j := (i + 1) % sides
			var ia: int = rings[r][i]
			var ib: int = rings[r][j]
			var ic: int = rings[r + 1][j]
			var id: int = rings[r + 1][i]
			_tri(surf, ia, ib, id)
			_tri(surf, ib, ic, id)
	_commit(skel, skin, node_name, surf)

static func _box(skel: Skeleton3D, skin: Skin, node_name: String, center: Vector3, size: Vector3, bone: int, color: Color) -> void:
	var surf := _surf(color)
	var hx := size.x
	var hy := size.y
	var hz := size.z
	var corners: Array[int] = []
	for z in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for x in [-1.0, 1.0]:
				var p := center + Vector3(x * hx, y * hy, z * hz)
				corners.append(_vert(surf, p, Vector3(x, y, z), Vector2(0, 0), bone, bone, 1.0))
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f in faces:
		_tri(surf, corners[f[0]], corners[f[1]], corners[f[2]])
		_tri(surf, corners[f[0]], corners[f[2]], corners[f[3]])
	_commit(skel, skin, node_name, surf)

static func _disc(skel: Skeleton3D, skin: Skin, node_name: String, center: Vector3, rx: float, ry: float, bone: int, color: Color) -> void:
	var surf := _surf(color)
	var n := Vector3(0, 0, -1)
	var hub := _vert(surf, center + Vector3(0, 0, -0.002), n, Vector2(0.5, 0.5), bone, bone, 1.0)
	var ring: Array[int] = []
	var sides := 10
	for i in sides:
		var a := TAU * float(i) / sides
		ring.append(_vert(surf, center + Vector3(cos(a) * rx, sin(a) * ry, -0.002), n, Vector2(0, 0), bone, bone, 1.0))
	for i in sides:
		_tri(surf, hub, ring[i], ring[(i + 1) % sides])
	_commit(skel, skin, node_name, surf)

static func _spike(skel: Skeleton3D, skin: Skin, node_name: String, base: Vector3, dir: Vector3, radii: Vector3, bone: int, color: Color) -> void:
	var surf := _surf(color)
	var axis := dir.normalized()
	var helper := Vector3.RIGHT if absf(axis.dot(Vector3.UP)) > 0.85 else Vector3.UP
	var side := axis.cross(helper).normalized()
	var up := side.cross(axis).normalized()
	var tip := _vert(surf, base + dir, axis, Vector2(0, 1), bone, bone, 1.0)
	var ring: Array[int] = []
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		var n := (side * cos(a) + up * sin(a)).normalized()
		var p := base + Vector3(n.x * radii.x, n.y * radii.y, n.z * radii.z)
		ring.append(_vert(surf, p, n, Vector2(0, 0), bone, bone, 1.0))
	for i in 4:
		_tri(surf, ring[i], tip, ring[(i + 1) % 4])
	_commit(skel, skin, node_name, surf)

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

static func _commit(skel: Skeleton3D, skin: Skin, node_name: String, surf: Dictionary) -> void:
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
	inst.material_override = load("res://scripts/world_blocks.gd").cel(surf.color, 3.0, 0.34)
	skel.add_child(inst)

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
	surf.weights.append_array(PackedFloat32Array([w0, 1.0 - w0, 0.0, 0.0]))
	return surf.verts.size() - 1

static func _tri(surf: Dictionary, a: int, b: int, c: int) -> void:
	surf.indices.append_array(PackedInt32Array([a, b, c]))
