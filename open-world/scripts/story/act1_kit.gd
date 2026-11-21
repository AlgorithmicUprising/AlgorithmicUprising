extends RefCounted
## Act I scenes 1.1 to 1.4B (Nov 20 2026): a tiny kit shared by the new district packs and act1.gd. PLACEHOLDER art:
## people are block figures with a floating name (the breakdown's "cheap resident kit"), roofs and signs are boxes and
## labels. Lives in the main pack (a few KB); the district packs preload it like they preload world_blocks.gd.

const Blocks = preload("res://scripts/world_blocks.gd")

## A block person: legs, body, head, a name over the head. h = height in metres (a kid ~1.1, an adult ~1.75).
static func person(parent: Node, node_name: String, label: String, at: Vector3, body: Color, h := 1.75, yaw := 0.0) -> Node3D:
	var p := Node3D.new()
	p.name = node_name
	p.position = at
	p.rotation.y = yaw
	parent.add_child(p)
	var s := h / 1.75
	Blocks.visual(p, "Legs", Vector3(0, 0.42 * s, 0), Vector3(0.36, 0.84, 0.24) * s, Color("2c2a33"))
	Blocks.visual(p, "Body", Vector3(0, 1.08 * s, 0), Vector3(0.5, 0.56, 0.3) * s, body)
	Blocks.visual(p, "Head", Vector3(0, 1.52 * s, 0), Vector3(0.26, 0.3, 0.26) * s, Color("8a5a3c"))
	if label != "":
		var l := Blocks.label(p, label, Vector3(0, h + 0.35, 0), Color("f2e8d0"), 26)
		l.name = "Name"
		l.pixel_size *= 0.5  # small enough not to fill the frame in the cinematic close-ups
		# and gone when the camera is right on top of them (they filled the boss and close-up shots); fades in from 5 m
		l.visibility_range_begin = 5.0
		l.visibility_range_begin_margin = 1.5
		l.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return p

## A flat sign (not billboarded): reads from the front (+Z of yaw).
static func sign(parent: Node, node_name: String, text: String, at: Vector3, yaw: float, color: Color, size := 40, px := 0.012) -> Label3D:
	var l := Label3D.new()
	l.name = node_name
	l.text = text
	l.position = at
	l.rotation.y = yaw
	l.modulate = color
	l.font_size = size
	l.pixel_size = px
	l.outline_size = 8
	l.outline_modulate = Color(0.05, 0.04, 0.04, 1)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	parent.add_child(l)
	return l

static func lamp(parent: Node, node_name: String, at: Vector3, c: Color, energy: float, r: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = node_name
	l.position = at
	l.light_color = c
	l.light_energy = energy
	l.omni_range = r
	parent.add_child(l)
	return l

static func unshaded(c: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## Recolour a box made by Blocks.solid / Blocks.visual (paint, spray marks).
static func paint(n: Node, c: Color) -> void:
	if n == null:
		return
	var mi: MeshInstance3D = n as MeshInstance3D
	if mi == null:
		for ch in n.get_children():
			if ch is MeshInstance3D:
				mi = ch
				break
	if mi != null:
		mi.material_override = unshaded(c)
