extends RefCounted
## Arcade Phase 1 (LOCAL): the Arcade warehouse exterior. Visual dressing over the greybox shell in yard.gd,
## which keeps its collision. 1 m snap, 4 m structural bays, 9 m tall, front faces +Z into the yard.
## Everything static is merged per material by ArcadeBatch. Posters/murals are flat quads from one atlas.

const Blocks = preload("res://scripts/world_blocks.gd")
const Palette = preload("res://scripts/palette.gd")
const M = preload("res://scripts/arcade_materials.gd")
const Batch = preload("res://scripts/arcade_batch.gd")
const Atlas = preload("res://scripts/arcade_atlas.gd")

const X0 := 8.0
const X1 := 70.0
const Z0 := -44.0
const ZF := -8.0
const H := 9.0
const T := 0.3            # half the greybox wall thickness (0.6)
const FACE := ZF + T      # outer face of the front wall
const DOOR0 := 28.0
const DOOR1 := 36.0
const OPEN_H := 6.1       # bay opening height under the shutter drum
const SHEET_TOP := 6.2
const BAND_TOP := 6.9
const ROOF_TOP := 9.3     # top of the greybox RoofDeck collision
const BAY := 4.0
const MURAL_FRONT := Vector2(38.5, 50.5)   # x span of the east-of-door mural
const MURAL_WEST := Vector2(-34.0, -18.0)  # z span on the west wall
const MURAL_BACK := Vector2(34.0, 44.0)    # x span on the back wall
const KENNEY := "res://assets/thirdparty/kenney/"

static var stats := {}

static func build(parent: Node) -> Node3D:
	var root := Node3D.new()
	root.name = "ArcadeExterior"
	parent.add_child(root)
	var b := Batch.new()
	_materials(b)
	_shell(b)
	_bay_door(b, root, parent)
	_marquee(b, root)
	_front_art(b, root)
	_side_door(b, root)
	_windows(b)
	_pipes(b)
	_roof(b, root, parent)
	_deck(b, root)
	_landscaping(b, root)
	var meshes := b.commit(root, "Arcade")
	stats = {"batched_tris": b.tris(), "batched_meshes": meshes.size()}
	return root

static func _materials(b) -> void:
	# Physical batches (one draw call each, plus an ink pass where noted). Big batches skip omni lights.
	b.layers = M.NO_OMNI_LAYER
	var ribs := M.ribbed(Color.WHITE, Color.WHITE, 0.22)
	ribs.set_shader_parameter("use_vertex_color", true)
	ribs.set_shader_parameter("vc_dark", 0.55)
	b.add_material("ribs", ribs)
	b.add_material("roof", M.toon(Color("2b2b33"), Color("4a4a55"), M.TRIM_BOXPROFILE, 2.5, 0.0, 0.0, 0.8))
	b.add_material("props_ink", M.props(0.025))
	b.add_material("glow", M.glow_batch(), false)
	b.add_material("artvc", M.art_vc(), false)
	# the deck and kerbs take the marquee light pool
	b.add_material("deck", M.toon(Color("7d6f6a"), Color("b8a59a"), M.TRIM_CONCRETE, 3.0, 0.0, 0.0, 0.7), true, 1)
	b.add_material("concrete_vc", M.props(0.025, M.TRIM_CONCRETE, 2.0, 0.6), true, 1)
	# logical keys -> shared batches
	for k in [["steel", M.STEEL], ["coping", Color("241c18")], ["caution", M.CAUTION], ["pipe", Color("8a8f96")], ["dark", Color("15161a")], ["unit", Color("b9b3a7")], ["rail", Palette.RAIL]]:
		b.alias(k[0], "props_ink", k[1])
	b.alias("door", "props_ink", Color("2a5f66"))
	b.alias("wall", "ribs", M.WALL)
	b.alias("band", "ribs", M.BAND)
	for k in [["soil", Color("3a2a22")], ["panel_frame", Color("c9ccd2")]]:
		b.alias(k[0], "props_ink", k[1])
	for k in [["deck_edge", Color("9a8a80")], ["planter", Palette.PLANTER], ["rust", Palette.WAREHOUSE_RUST]]:
		b.alias(k[0], "concrete_vc", k[1])
	b.alias("glass", "glow", M.glow_vc(Color("ffc070"), 0.9))
	b.alias("glass_low", "glow", M.glow_vc(Color("ffa85a"), 1.0))
	b.alias("lamp", "glow", M.glow_vc(Color("ffe0b8"), 2.0))
	b.alias("bulb", "glow", M.glow_vc(Color("fff1b8"), 2.2))
	b.alias("alert", "glow", M.glow_vc(M.ALERT, 1.2))
	b.alias("art", "artvc", M.art_color(0.0, 0.9))
	b.alias("mural", "artvc", M.art_color(0.0, 0.95, 0.3))
	b.alias("art_glow", "artvc", M.art_color(1.3, 1.0))
	b.alias("neon", "artvc", M.art_color(2.6, 1.0))

static func _rect(name: String) -> Rect2:
	return Atlas.RECTS[name]

static func _in(x: float, span: Vector2) -> bool:
	return x > span.x - 0.3 and x < span.y + 0.3

# ---------- shell ----------
static func _shell(b) -> void:
	var zc := ZF
	var fw := X1 - X0
	# front: lower sheet split round the bay, wall above the bay, band, clerestory
	b.box("wall", Vector3((X0 + DOOR0) * 0.5, SHEET_TOP * 0.5, zc), Vector3(DOOR0 - X0, SHEET_TOP, T * 2.0))
	b.box("wall", Vector3((DOOR1 + X1) * 0.5, SHEET_TOP * 0.5, zc), Vector3(X1 - DOOR1, SHEET_TOP, T * 2.0))
	b.box("wall", Vector3((DOOR0 + DOOR1) * 0.5, (OPEN_H + SHEET_TOP) * 0.5, zc), Vector3(DOOR1 - DOOR0, SHEET_TOP - OPEN_H, T * 2.0))
	b.box("wall", Vector3((X0 + X1) * 0.5, (BAND_TOP + H) * 0.5, zc), Vector3(fw, H - BAND_TOP, T * 2.0))
	# back, west, east: full height
	b.box("wall", Vector3((X0 + X1) * 0.5, H * 0.5, Z0), Vector3(fw + T * 2.0, H, T * 2.0))
	b.box("wall", Vector3(X0, H * 0.5, (Z0 + ZF) * 0.5), Vector3(T * 2.0, H, ZF - Z0))
	b.box("wall", Vector3(X1, H * 0.5, (Z0 + ZF) * 0.5), Vector3(T * 2.0, H, ZF - Z0))
	# rust belly band round all four sides
	var bh := BAND_TOP - SHEET_TOP
	var by := (BAND_TOP + SHEET_TOP) * 0.5
	b.box("band", Vector3((X0 + X1) * 0.5, by, ZF + 0.05), Vector3(fw + T * 2.0 + 0.2, bh, T * 2.0 + 0.1))
	b.box("band", Vector3((X0 + X1) * 0.5, by, Z0 - 0.05), Vector3(fw + T * 2.0 + 0.2, bh, T * 2.0 + 0.1))
	b.box("band", Vector3(X0 - 0.05, by, (Z0 + ZF) * 0.5), Vector3(T * 2.0 + 0.1, bh, ZF - Z0))
	b.box("band", Vector3(X1 + 0.05, by, (Z0 + ZF) * 0.5), Vector3(T * 2.0 + 0.1, bh, ZF - Z0))
	# coping / parapet (front, back, west; east stays open to the roof-stair landing)
	b.box("coping", Vector3((X0 + X1) * 0.5, H + 0.3, ZF + 0.05), Vector3(fw + 0.9, 0.6, 0.75))
	b.box("coping", Vector3((X0 + X1) * 0.5, H + 0.3, Z0 - 2.0), Vector3(fw + 0.9, 0.6, 0.5))
	b.box("coping", Vector3(X0 - 0.05, H + 0.3, (Z0 - 2.0 + ZF) * 0.5), Vector3(0.6, 0.6, ZF - Z0 + 2.0))
	b.box("coping", Vector3(X1 + 0.05, H + 0.12, (Z0 - 2.0 + ZF) * 0.5), Vector3(0.6, 0.24, ZF - Z0 + 2.0))
	# steel pilasters every 4 m (front skips the bay door and the mural panel)
	var x := X0
	while x <= X1 + 0.01:
		if not (x > DOOR0 - 0.6 and x < DOOR1 + 0.6) and not _in(x, MURAL_FRONT):
			b.box("steel", Vector3(x, H * 0.5, FACE + 0.15), Vector3(0.35, H, 0.3))
		if not _in(x, MURAL_BACK):
			b.box("steel", Vector3(x, H * 0.5, Z0 - T - 0.15), Vector3(0.35, H, 0.3))
		x += BAY
	var z := Z0
	while z <= ZF + 0.01:
		if not _in(z, MURAL_WEST):
			b.box("steel", Vector3(X0 - T - 0.15, H * 0.5, z), Vector3(0.3, H, 0.35))
		b.box("steel", Vector3(X1 + T + 0.15, H * 0.5, z), Vector3(0.3, H, 0.35))
		z += BAY
	# clerestory glazing: one lit strip per bay, front and sides (skip behind the marquee)
	x = X0 + 2.0
	while x < X1:
		if x < 25.0 or x > 39.0:
			_clerestory(b, Vector3(x, 7.9, FACE + 0.01), Vector3(0, 0, 1))
		_clerestory(b, Vector3(x, 7.9, Z0 - T - 0.01), Vector3(0, 0, -1))
		x += BAY
	z = Z0 + 2.0
	while z < ZF:
		_clerestory(b, Vector3(X0 - T - 0.01, 7.9, z), Vector3(-1, 0, 0))
		_clerestory(b, Vector3(X1 + T + 0.01, 7.9, z), Vector3(1, 0, 0))
		z += BAY

static func _clerestory(b, c: Vector3, out: Vector3) -> void:
	b.panel("glass", c, Vector2(2.8, 0.9), out)
	var right := Vector3.UP.cross(out).normalized()
	b.box("steel", c + out * 0.03, _oriented(Vector3(0.08, 0.9, 0.05), out))
	b.box("steel", c + out * 0.03 + Vector3(0, 0.5, 0), _oriented(Vector3(3.0, 0.1, 0.06), out))
	b.box("steel", c + out * 0.03 - Vector3(0, 0.5, 0), _oriented(Vector3(3.0, 0.12, 0.1), out))
	for s in [-1.0, 1.0]:
		b.box("steel", c + out * 0.03 + right * 1.45 * s, _oriented(Vector3(0.1, 1.0, 0.06), out))

## Size given as (along wall, up, out of wall); rotate into world axes for a wall facing `out`.
static func _oriented(size: Vector3, out: Vector3) -> Vector3:
	if absf(out.x) > 0.5:
		return Vector3(size.z, size.y, size.x)
	return size

# ---------- bay door ----------
static func _bay_door(b, root: Node3D, parent: Node) -> void:
	var cx := (DOOR0 + DOOR1) * 0.5
	# heavy caution jambs and a header over the opening
	for jx in [DOOR0 - 0.25, DOOR1 + 0.25]:
		b.box("caution", Vector3(jx, OPEN_H * 0.5, FACE + 0.2), Vector3(0.5, OPEN_H, 0.4))
		for k in 6:
			b.panel("art", Vector3(jx, 0.35 + k * 0.5, FACE + 0.41), Vector2(0.44, 0.44), Vector3(0, 0, 1), _rect("caution"))
	b.box("steel", Vector3(cx, OPEN_H + 0.12, FACE + 0.2), Vector3(DOOR1 - DOOR0 + 1.0, 0.24, 0.4))
	# shutter drum housing (the shutter itself is animated, see arcade_door.gd)
	b.box("steel", Vector3(cx, OPEN_H - 0.25, FACE + 0.35), Vector3(DOOR1 - DOOR0, 0.5, 0.5))
	# threshold plate
	b.box("steel", Vector3(cx, 0.47, FACE + 0.15), Vector3(DOOR1 - DOOR0, 0.04, 0.5))
	_vestibule(b)
	var door = load("res://scripts/arcade_door.gd").new()
	door.name = "ArcadeDoor"
	parent.add_child(door)
	door.setup(Vector3(cx, 0.0, FACE - 0.08), DOOR1 - DOOR0, OPEN_H - 0.5)

## Phase 2 (LOCAL): a dark entry bay behind the shutter, so the roll-up shows a dim lit room glimpse
## instead of the empty greybox shell (whose meshes are hidden) and the sky through it.
static func _vestibule(b) -> void:
	var cx := (DOOR0 + DOOR1) * 0.5
	var zb := ZF - 3.2
	var zi := ZF - T
	var w := DOOR1 - DOOR0 + 0.6
	b.box("dark", Vector3(cx, OPEN_H * 0.5, zb), Vector3(w, OPEN_H + 0.4, 0.1))
	for sx in [DOOR0 - 0.25, DOOR1 + 0.25]:
		b.box("dark", Vector3(sx, OPEN_H * 0.5, (zb + zi) * 0.5), Vector3(0.1, OPEN_H + 0.4, zi - zb))
	b.box("dark", Vector3(cx, OPEN_H + 0.15, (zb + zi) * 0.5), Vector3(w, 0.1, zi - zb))
	b.box("dark", Vector3(cx, 0.02, (zb + zi) * 0.5), Vector3(w, 0.04, zi - zb))
	# far glow: cabinet screens and the coolant skirting, as seen from the deck
	for i in 4:
		var x := DOOR0 + 1.2 + i * 1.9
		b.box("glass_low", Vector3(x, 1.45, zb + 0.07), Vector3(0.6, 0.45, 0.02))
		b.box("alert" if i % 2 == 0 else "glass", Vector3(x, 2.0, zb + 0.07), Vector3(0.7, 0.16, 0.02))
	b.box("lamp", Vector3(cx, 0.6, zb + 0.07), Vector3(w - 0.4, 0.05, 0.02))
	b.box("glass_low", Vector3(cx, OPEN_H + 0.08, (zb + zi) * 0.5), Vector3(1.6, 0.03, 0.5))

# ---------- marquee (as approved in mockup A) ----------
static func _marquee(b, root: Node3D) -> void:
	var z := FACE + 0.15
	b.box("dark", Vector3(32, 8.0, z + 0.4), Vector3(11.2, 1.9, 0.3))
	b.panel("art_glow", Vector3(32, 8.0, z + 0.57), Vector2(10.6, 1.66), Vector3(0, 0, 1), _rect("marquee"))
	for i in 15:
		b.box("bulb", Vector3(26.9 + i * 0.73, 9.05, z + 0.57), Vector3(0.14, 0.14, 0.14))
		b.box("bulb", Vector3(26.9 + i * 0.73, 6.95, z + 0.57), Vector3(0.14, 0.14, 0.14))
	var ml := OmniLight3D.new()
	ml.name = "MarqueeLight"
	ml.position = Vector3(32, 7.0, FACE + 3.1)
	ml.light_color = Color("ffd59a")
	ml.light_energy = 1.4
	ml.omni_range = 10.0
	ml.light_cull_mask = M.OMNI_MASK
	root.add_child(ml)

# ---------- posters, murals, neon ----------
static func _front_art(b, root: Node3D) -> void:
	var z := FACE + 0.012
	var n := Vector3(0, 0, 1)
	# wheatpaste wall west of the bay, pasted between the pilasters
	var layout := [
		[10.0, 2.5, "the-alignment-problem", Vector2(1.6, 1.6), -1.5],
		[13.2, 2.6, "do-not-feed-the-algorithm", Vector2(1.2, 1.8), 2.0],
		[15.0, 2.4, "the-alignment-problem", Vector2(1.5, 1.5), -1.0],
		[17.0, 2.6, "the-human-zoo", Vector2(1.2, 1.8), 1.5],
		[18.8, 2.3, "deadpan-flow", Vector2(1.9, 1.07), -2.0],
		[18.8, 3.25, "deadpan-flow", Vector2(1.5, 0.84), 1.0],
		[21.2, 2.4, "zero-cover-band", Vector2(2.0, 1.5), 1.0],
		[23.05, 2.6, "do-not-feed-the-algorithm", Vector2(1.1, 1.65), -2.0],
		[25.1, 2.5, "the-alignment-problem", Vector2(1.5, 1.5), 1.5],
		[26.75, 2.6, "the-human-zoo", Vector2(1.1, 1.65), -1.0],
	]
	var k := 0
	for p in layout:
		b.panel("art", Vector3(p[0], p[1], z + k * 0.002), p[3], n, _rect(p[2]), deg_to_rad(p[4]))
		k += 1
	# mural candidate B east of the bay (one painted infill panel, no pilasters across it)
	var mw: float = MURAL_FRONT.y - MURAL_FRONT.x
	var r := _rect("mural_b")
	var mh: float = mw * (r.size.y * 1024.0) / (r.size.x * 2048.0)
	b.panel("mural", Vector3((MURAL_FRONT.x + MURAL_FRONT.y) * 0.5, 0.35 + mh * 0.5, z), Vector2(mw, mh), n, r)
	# mural candidate C on the west wall (faces the docks)
	r = _rect("mural_c")
	mw = MURAL_WEST.y - MURAL_WEST.x
	mh = mw * (r.size.y * 1024.0) / (r.size.x * 2048.0)
	b.panel("mural", Vector3(X0 - T - 0.012, 0.3 + mh * 0.5, (MURAL_WEST.x + MURAL_WEST.y) * 0.5), Vector2(mw, mh), Vector3(-1, 0, 0), r)
	# mural candidate A on the back wall (faces the Resistance rooms)
	r = _rect("mural_a")
	mw = MURAL_BACK.y - MURAL_BACK.x
	mh = mw * (r.size.y * 1024.0) / (r.size.x * 2048.0)
	b.panel("mural", Vector3((MURAL_BACK.x + MURAL_BACK.y) * 0.5, 0.3 + mh * 0.5, Z0 - T - 0.012), Vector2(mw, mh), Vector3(0, 0, -1), r)
	# Zero glyph neon in the far east bay
	b.box("dark", Vector3(66, 4.0, FACE + 0.05), Vector3(2.9, 2.9, 0.1))
	b.panel("neon", Vector3(66, 4.0, FACE + 0.11), Vector2(2.6, 2.6), n, _rect("zero_glyph"))
	var gl := OmniLight3D.new()
	gl.name = "NeonLight"
	gl.position = Vector3(66, 4.0, FACE + 1.6)
	gl.light_color = M.NEON_ACID
	gl.light_energy = 0.8
	gl.omni_range = 6.0
	gl.light_cull_mask = M.OMNI_MASK
	root.add_child(gl)

# ---------- side door (staff door; visual only for now) ----------
static func _side_door(b, root: Node3D) -> void:
	var dx := 54.0
	# our own steel staff door (Kenney's door piece read as an open doorway at this scale)
	b.box("steel", Vector3(dx, 1.35, FACE + 0.05), Vector3(1.6, 2.7, 0.1))
	b.box("door", Vector3(dx, 1.15, FACE + 0.11), Vector3(1.2, 2.3, 0.06))
	b.box("steel", Vector3(dx, 0.2, FACE + 0.15), Vector3(1.2, 0.3, 0.03))
	b.box("caution", Vector3(dx, 1.05, FACE + 0.17), Vector3(0.9, 0.07, 0.06))
	b.panel("glass_low", Vector3(dx, 1.85, FACE + 0.145), Vector2(0.4, 0.55), Vector3(0, 0, 1))
	b.box("steel", Vector3(dx, 1.85, FACE + 0.15), Vector3(0.03, 0.55, 0.02))
	b.panel("art", Vector3(dx + 0.25, 0.75, FACE + 0.145), Vector2(0.42, 0.6), Vector3(0, 0, 1), _rect("do-not-feed-the-algorithm"), deg_to_rad(-4.0))
	b.box("rust", Vector3(dx, 3.05, FACE + 0.75), Vector3(2.8, 0.12, 1.3), Basis(Vector3.RIGHT, 0.18))
	for sx in [dx - 1.2, dx + 1.2]:
		b.box("steel", Vector3(sx, 3.25, FACE + 0.5), Vector3(0.05, 0.05, 0.9), Basis(Vector3.RIGHT, -0.5))
	b.box("lamp", Vector3(dx, 3.35, FACE + 0.15), Vector3(0.5, 0.22, 0.25))
	# no omni here: the lamp is emissive only (keeps the per-object light passes down on the web build)

# ---------- ground-floor windows (our own frames; lit from inside) ----------
static func _windows(b) -> void:
	for wx in [58.0, 62.0]:
		var c := Vector3(wx, 2.2, FACE + 0.015)
		b.panel("glass_low", c, Vector2(2.3, 2.1), Vector3(0, 0, 1))
		b.box("steel", c + Vector3(0, 1.1, 0.05), Vector3(2.6, 0.14, 0.12))
		b.box("steel", c - Vector3(0, 1.12, -0.12), Vector3(2.7, 0.12, 0.3))
		for s in [-1.0, 1.0]:
			b.box("steel", c + Vector3(1.22 * s, 0, 0.05), Vector3(0.14, 2.3, 0.12))
		b.box("steel", c + Vector3(0, 0, 0.04), Vector3(0.07, 2.1, 0.06))
		b.box("steel", c + Vector3(0, 0.25, 0.04), Vector3(2.3, 0.07, 0.06))
	# eave lamps between pilasters
	for ex in [10.0, 14.0, 18.0, 22.0, 42.0, 46.0, 50.0, 58.0, 62.0, 66.0]:
		b.box("lamp", Vector3(ex, 5.9, FACE + 0.22), Vector3(0.9, 0.14, 0.4))
		b.box("steel", Vector3(ex, 6.0, FACE + 0.1), Vector3(0.12, 0.12, 0.25))

static func _pipes(b) -> void:
	for gx in [X0 + 0.6, DOOR1 + 0.95, X1 - 0.7]:
		b.box("pipe", Vector3(gx, H * 0.5, FACE + 0.2), Vector3(0.22, H, 0.22))
		b.box("pipe", Vector3(gx, 0.15, FACE + 0.35), Vector3(0.24, 0.24, 0.5))
	b.box("pipe", Vector3((X0 + X1) * 0.5, H - 0.05, FACE + 0.48), Vector3(X1 - X0 + 0.6, 0.25, 0.35))
	# utility box + conduit in the half bay at the east end
	b.box("unit", Vector3(69.0, 1.3, FACE + 0.2), Vector3(0.9, 1.3, 0.4))
	b.box("alert", Vector3(69.0, 1.5, FACE + 0.41), Vector3(0.45, 0.1, 0.02))
	b.box("steel", Vector3(69.0, 4.2, FACE + 0.1), Vector3(0.1, 4.4, 0.1))

# ---------- roof (flat) ----------
static func _roof(b, root: Node3D, parent: Node) -> void:
	# roof membrane over the greybox RoofDeck collision footprint (x 7..77, z -46..-10) plus the strip to the front wall
	b.box("roof", Vector3((X0 + X1) * 0.5, ROOF_TOP - 0.15, (Z0 - 2.0 + ZF) * 0.5), Vector3(X1 - X0 + 0.6, 0.3, ZF - Z0 + 2.0))
	# east landing between the roof and the roof stair (the deck already extends to x 77)
	b.box("steel", Vector3(73.8, ROOF_TOP - 0.1, -28.0), Vector3(6.4, 0.2, 36.0))
	for lz in [-11.0, -45.0]:
		b.box("steel", Vector3(76.6, ROOF_TOP * 0.5, lz), Vector3(0.3, ROOF_TOP, 0.3))
	# collision strip so the front 2.3 m of roof (missing from the greybox deck) is walkable
	var strip := StaticBody3D.new()
	strip.name = "ArcadeRoofFront"
	var sh := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(X1 - X0, 0.3, 2.4)
	sh.shape = bs
	strip.add_child(sh)
	strip.position = Vector3((X0 + X1) * 0.5, ROOF_TOP - 0.15, -8.9)
	parent.add_child(strip)
	# solar array: clean flat slab panels, tilted toward the yard (+Z). Node name kept for tests.
	var solar := Node3D.new()
	solar.name = "SolarRoof"
	parent.add_child(solar)
	var sb = Batch.new()
	sb.layers = M.NO_OMNI_LAYER
	sb.add_material("artvc", M.art_vc(), false)
	sb.add_material("props", M.props())
	sb.alias("solar", "artvc", M.art_color(0.08, 0.92, 0.0, 0.55))
	sb.alias("frame", "props", Color("c9ccd2"))
	sb.alias("legs", "props", Color("2a2f3a"))
	var tilt := Basis(Vector3.RIGHT, 0.3)
	var cell := _rect("solar")
	for r in 4:
		for c in 7:
			var p := Vector3(15.0 + c * 8.0, ROOF_TOP + 0.95, -38.0 + r * 7.2)
			sb.box("frame", p, Vector3(7.2, 0.1, 4.4), tilt)
			for half in [-1.0, 1.0]:
				sb.panel_basis("solar", p + tilt.y * 0.056 + tilt.x * 1.775 * half, Vector2(3.5, 4.2), Basis(tilt.x, -tilt.z, tilt.y), cell)
			sb.box("legs", p + Vector3(0, -0.5, -1.7), Vector3(6.6, 0.85, 0.1))
			sb.box("legs", p + Vector3(0, -0.85, 1.6), Vector3(6.6, 0.15, 0.1))
	sb.commit(solar, "Solar")
	stats["solar_tris"] = sb.tris()
	# rooftop kit: tank, vent stack, our own AC units, hatch
	var city_map: Texture2D = load(KENNEY + "city/Textures/colormap.png")
	_kit(root, KENNEY + "city/detail-tank.glb", Vector3(12, ROOF_TOP, -16), 2.4, M.kit(Color("6b4a3a"), Color("e0a15a"), city_map, 0.0))
	_kit(root, KENNEY + "city/chimney-small.glb", Vector3(20, ROOF_TOP, -12), 2.0, M.kit(Color("4a4f58"), Color("a9b2b8"), city_map, 0.0))
	for i in 3:
		var ac := Vector3(60.0 + i * 3.0, ROOF_TOP, -13.0)
		b.box("unit", ac + Vector3(0, 0.6, 0), Vector3(2.0, 1.2, 1.6))
		b.box("dark", ac + Vector3(0, 1.22, 0), Vector3(1.2, 0.04, 1.2))
		b.box("steel", ac + Vector3(0, 0.05, 0), Vector3(2.2, 0.1, 1.8))
	b.box("steel", Vector3(30, ROOF_TOP + 0.3, -12), Vector3(1.4, 0.6, 1.4))

# ---------- entry deck: stairs in the middle, skate wedges to the sides ----------
const DECK_X0 := 22.0
const DECK_X1 := 42.0
const DECK_Z1 := FACE + 5.0
const DECK_Y := 0.45

static func _deck(b, root: Node3D) -> void:
	var cx := (DECK_X0 + DECK_X1) * 0.5
	var depth := DECK_Z1 - FACE
	var body := StaticBody3D.new()
	body.name = "ArcadeDeck"
	_collider(body, Vector3(cx, DECK_Y * 0.5, FACE + depth * 0.5), Vector3(DECK_X1 - DECK_X0, DECK_Y, depth))
	root.add_child(body)
	b.box("deck", Vector3(cx, DECK_Y * 0.5, FACE + depth * 0.5), Vector3(DECK_X1 - DECK_X0, DECK_Y, depth))
	b.box("deck_edge", Vector3(cx, DECK_Y + 0.01, DECK_Z1 - 0.1), Vector3(DECK_X1 - DECK_X0, 0.03, 0.2))
	# one smooth collision slope across the front (walk + skate), drawn as stairs in the middle
	var run := 2.6
	var low_z := DECK_Z1 + run
	var slope := Blocks.add_slope(root, "ArcadeDeckFront", Vector3(cx, 0.05, low_z), Vector3(cx, DECK_Y, DECK_Z1), DECK_X1 - DECK_X0, Palette.RAMP)
	for c in slope.get_children():
		if c is MeshInstance3D:
			c.visible = false
	var sx0 := cx - 3.0
	var sx1 := cx + 3.0
	for s in 3:
		var y := DECK_Y * float(3 - s) / 3.0
		var zz := DECK_Z1 + run * (float(s) + 0.5) / 3.0
		b.box("deck", Vector3(cx, y * 0.5, zz), Vector3(sx1 - sx0, y, run / 3.0))
	for wx in [[DECK_X0, sx0], [sx1, DECK_X1]]:
		var x0: float = wx[0]
		var x1: float = wx[1]
		b.quad_up("deck", Vector3(x0, DECK_Y, DECK_Z1), Vector3(x1, DECK_Y, DECK_Z1), Vector3(x1, 0.05, low_z), Vector3(x0, 0.05, low_z))
	# side wedges off each end of the deck
	for side in [-1.0, 1.0]:
		var edge: float = DECK_X0 if side < 0.0 else DECK_X1
		var far: float = edge + side * 2.6
		var zc := FACE + depth * 0.5
		var w := Blocks.add_slope(root, "ArcadeDeckWedge%s" % ("W" if side < 0.0 else "E"), Vector3(far, 0.05, zc), Vector3(edge, DECK_Y, zc), depth, Palette.RAMP)
		for c in w.get_children():
			if c is MeshInstance3D:
				c.visible = false
		b.quad_up("deck", Vector3(edge, DECK_Y, FACE), Vector3(edge, DECK_Y, DECK_Z1), Vector3(far, 0.05, DECK_Z1), Vector3(far, 0.05, FACE))
		b.quad4("deck_edge", Vector3(far, 0.05, DECK_Z1), Vector3(edge, DECK_Y, DECK_Z1), Vector3(edge, 0.0, DECK_Z1), Vector3(far, 0.0, DECK_Z1), Rect2(0, 0, 1, 1), Vector3(0, 0, 1))
	# rails between the stairs and the wedges (solid, so you don't walk through them)
	for rx in [sx0 - 0.05, sx1 + 0.05]:
		b.box("rail", Vector3(rx, DECK_Y + 0.95, DECK_Z1 - 1.2), Vector3(0.07, 0.07, 2.4))
		b.box("rail", Vector3(rx, 0.55, DECK_Z1 + 1.5), Vector3(0.07, 0.07, 2.9), Basis(Vector3.RIGHT, atan2(DECK_Y, run)))
		for k in 3:
			var pz := DECK_Z1 - 2.3 + k * 1.15
			b.box("rail", Vector3(rx, DECK_Y + 0.475, pz), Vector3(0.06, 0.95, 0.06))
		var rb := StaticBody3D.new()
		rb.name = "ArcadeDeckRail"
		_collider(rb, Vector3(rx, DECK_Y + 0.5, DECK_Z1 - 1.2), Vector3(0.08, 1.0, 2.4))
		root.add_child(rb)

static func _collider(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var sh := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	sh.shape = bs
	sh.position = center
	body.add_child(sh)

# ---------- landscaping ----------
static func _landscaping(b, root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "ArcadePlanters"
	root.add_child(body)
	var bushes := {"plant_bushLarge": [], "plant_bushDetailed": [], "grass_leafsLarge": []}
	var i := 0
	for spec in [[13.0, -5.0, 6.0], [49.5, -5.0, 4.0], [60.0, -5.0, 6.0]]:
		var px: float = spec[0]
		var pz: float = spec[1]
		var w: float = spec[2]
		b.box("planter", Vector3(px, 0.4, pz), Vector3(w, 0.8, 1.6))
		b.box("soil", Vector3(px, 0.81, pz), Vector3(w - 0.3, 0.02, 1.3))
		_collider(body, Vector3(px, 0.4, pz), Vector3(w, 0.8, 1.6))
		var n := int(w / 1.1)
		for k in n:
			var sx := px - w * 0.5 + 0.6 + k * 1.1
			var model := "plant_bushLarge" if (k + i) % 2 == 0 else "plant_bushDetailed"
			bushes[model].append(Transform3D(Basis(Vector3.UP, float(k * 7 + i) * 1.3).scaled(Vector3.ONE * (0.9 + float((k + i) % 3) * 0.22)), Vector3(sx, 0.8, pz + (0.15 if k % 2 == 0 else -0.15))))
			if k % 2 == 1:
				bushes["grass_leafsLarge"].append(Transform3D(Basis(Vector3.UP, float(k)).scaled(Vector3.ONE * 0.5), Vector3(sx + 0.45, 0.8, pz + 0.4)))
		i += 1
	# weeds in the slab cracks along the wall
	for p in [Vector3(20.0, 0, -7.2), Vector3(44.5, 0, -2.0), Vector3(46.0, 0, -7.4), Vector3(67.5, 0, -7.4), Vector3(9.0, 0, -7.3), Vector3(56.5, 0, -7.3), Vector3(7.2, 0, -30.0), Vector3(7.2, 0, -14.0)]:
		bushes["grass_leafsLarge"].append(Transform3D(Basis(Vector3.UP, p.x).scaled(Vector3.ONE * 0.45), p))
	var greens := {"plant_bushLarge": [Color("234a2c"), Color("4a7f45")], "plant_bushDetailed": [Color("1f4428"), Color("3f7a45")], "grass_leafsLarge": [Color("3b6b37"), Color("8fb85c")]}
	for model in bushes:
		_multimesh(root, KENNEY + "nature/%s.glb" % model, bushes[model], greens[model][0], greens[model][1])
	# a Kenney container as side storage by the west wall (solid)
	var cont := _kit(root, KENNEY + "city/shipping-container-a.glb", Vector3(3.0, 0, -38.0), 2.9, M.kit(Color("7a3424"), Palette.WAREHOUSE_RUST, load(KENNEY + "city/Textures/colormap.png"), 0.0), PI * 0.5)
	var cb := StaticBody3D.new()
	cb.name = "ArcadeContainer"
	var box := _aabb(cont)
	_collider(cb, box.get_center(), box.size)
	root.add_child(cb)

## Fit a CC0 kit piece to a target height and re-skin every surface with one toon material.
static func _kit(root: Node3D, path: String, pos: Vector3, height: float, mat: Material, yaw := 0.0) -> Node3D:
	var scene: PackedScene = load(path)
	var n: Node3D = scene.instantiate()
	root.add_child(n)
	var bb := _aabb(n)
	n.scale = Vector3.ONE * (height / maxf(bb.size.y, 0.001))
	n.rotation.y = yaw
	n.position = pos
	for c in n.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).material_override = mat
		(c as MeshInstance3D).layers = M.NO_OMNI_LAYER
	return n

static func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var xf: Transform3D = n.global_transform.affine_inverse() * mi.global_transform if n.is_inside_tree() else mi.transform
		var bb: AABB = xf * mi.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	if n.is_inside_tree():
		out = n.global_transform * out
	return out

static func _multimesh(root: Node3D, path: String, xforms: Array, dark: Color, light: Color) -> void:
	if xforms.is_empty():
		return
	var scene: PackedScene = load(path)
	var src: Node = scene.instantiate()
	var mis := src.find_children("*", "MeshInstance3D", true, false)
	if mis.is_empty():
		src.free()
		return
	var mesh: Mesh = (mis[0] as MeshInstance3D).mesh
	var base_scale: float = 1.0 / maxf(mesh.get_aabb().size.y, 0.001)
	src.free()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		var xf: Transform3D = xforms[k]
		mm.set_instance_transform(k, Transform3D(xf.basis.scaled(Vector3.ONE * base_scale), xf.origin))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Arcade_" + path.get_file().get_basename()
	mmi.multimesh = mm
	mmi.material_override = M.toon(dark, light, -1, 1.0, 0.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.layers = M.NO_OMNI_LAYER
	root.add_child(mmi)
