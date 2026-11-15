extends Node3D
## Arcade Phase 1 (LOCAL): placeholder interior, its own scene. An empty shell in the same local frame
## as the exterior (x 8..70, z -44..-8, 9 m), so Phase 2 can drop the room in on the same grid.
## Uses the same shader, trim sheet and atlas as the outside, with the darker interior palette pairs.
## Cabinets and the Bars per Watt corner are out of scope here.

const M = preload("res://scripts/arcade_materials.gd")
const Batch = preload("res://scripts/arcade_batch.gd")
const Trigger = preload("res://scripts/arcade_trigger.gd")

const X0 := 8.0
const X1 := 70.0
const Z0 := -44.0
const ZF := -8.0
const H := 9.0
const T := 0.3
const DOOR0 := 28.0
const DOOR1 := 36.0

var spawn_local := Vector3(32.0, 0.5, -10.8)
var exit_trigger: Node3D
var door: Node

func _ready() -> void:
	var b := Batch.new()
	b.add_material("wall", M.ribbed(M.WALL_IN_DARK, M.WALL_IN, 0.22, M.TRIM_CONCRETE, 0.2))
	b.add_material("floor", M.toon(Color("1a2422"), Color("33403d"), M.TRIM_CONCRETE, 4.0, 0.0, 0.0, 0.7))
	b.add_material("ceiling", M.toon(Color("15151a"), Color("2a2a33"), M.TRIM_BOXPROFILE, 2.5, 0.0, 0.0, 0.8))
	b.add_material("steel", M.flat(M.STEEL, 0.02))
	b.add_material("caution", M.flat(M.CAUTION, 0.0))
	b.add_material("lamp", M.glow(Color("fff0d0"), 1.5), false)
	b.add_material("neon", M.glow(M.NEON_COOLANT, 1.8), false)
	b.add_material("shutter", _static_shutter())
	var cx := (X0 + X1) * 0.5
	var cz := (Z0 + ZF) * 0.5
	# floor + walls + ceiling (solid)
	var body := StaticBody3D.new()
	body.name = "InteriorShell"
	add_child(body)
	_solid(b, body, "floor", Vector3(cx, -0.25, cz), Vector3(X1 - X0 + 1.0, 0.5, ZF - Z0 + 1.0))
	_solid(b, body, "ceiling", Vector3(cx, H + 0.15, cz), Vector3(X1 - X0 + 1.0, 0.3, ZF - Z0 + 1.0))
	_solid(b, body, "wall", Vector3(cx, H * 0.5, Z0), Vector3(X1 - X0, H, T * 2.0))
	_solid(b, body, "wall", Vector3(X0, H * 0.5, cz), Vector3(T * 2.0, H, ZF - Z0))
	_solid(b, body, "wall", Vector3(X1, H * 0.5, cz), Vector3(T * 2.0, H, ZF - Z0))
	_solid(b, body, "wall", Vector3((X0 + DOOR0) * 0.5, H * 0.5, ZF), Vector3(DOOR0 - X0, H, T * 2.0))
	_solid(b, body, "wall", Vector3((DOOR1 + X1) * 0.5, H * 0.5, ZF), Vector3(X1 - DOOR1, H, T * 2.0))
	_solid(b, body, "wall", Vector3((DOOR0 + DOOR1) * 0.5, (6.1 + H) * 0.5, ZF), Vector3(DOOR1 - DOOR0, H - 6.1, T * 2.0))
	# inside face of the closed shutter, jambs and drum (the way back out)
	_solid(b, body, "shutter", Vector3((DOOR0 + DOOR1) * 0.5, 3.05, ZF), Vector3(DOOR1 - DOOR0, 6.1, 0.2))
	for jx in [DOOR0 + 0.2, DOOR1 - 0.2]:
		b.box("caution", Vector3(jx, 3.05, ZF - T - 0.15), Vector3(0.4, 6.1, 0.3))
	b.box("steel", Vector3((DOOR0 + DOOR1) * 0.5, 6.3, ZF - T - 0.35), Vector3(DOOR1 - DOOR0 + 0.4, 0.7, 0.7))
	# roof trusses + hanging lamps on the 4 m grid (every second bay)
	var tz := Z0 + 4.0
	while tz < ZF - 1.0:
		b.box("steel", Vector3(cx, H - 0.6, tz), Vector3(X1 - X0, 0.35, 0.3))
		for lx in [18.0, 32.0, 46.0, 60.0]:
			b.box("lamp", Vector3(lx, 6.6, tz), Vector3(1.4, 0.16, 0.5))
			b.box("steel", Vector3(lx, 7.6, tz), Vector3(0.03, 1.9, 0.03))
		tz += 8.0
	# floor tape: where the Phase 3 cabinet rows and the Bars per Watt corner will go (placeholder only)
	for r in [[20.0, -22.0, 14.0, 3.0], [44.0, -22.0, 14.0, 3.0], [20.0, -32.0, 14.0, 3.0], [44.0, -32.0, 14.0, 3.0], [62.0, -38.0, 12.0, 8.0]]:
		_tape(b, Vector3(r[0], 0.012, r[1]), Vector2(r[2], r[3]))
	b.box("neon", Vector3(cx, 0.25, Z0 + T + 0.04), Vector3(X1 - X0 - 1.0, 0.06, 0.04))
	b.commit(self, "Interior")
	for l in [[20.0, -20.0, Color("ffd9a8")], [44.0, -20.0, Color("ffd9a8")], [32.0, -34.0, Color("7fe8dc")]]:
		var o := OmniLight3D.new()
		o.position = Vector3(l[0], 5.5, l[1])
		o.light_color = l[2]
		o.light_energy = 2.4
		o.omni_range = 20.0
		add_child(o)
	var sign := Label3D.new()
	sign.name = "InteriorPlaceholder"
	sign.text = "ARCADE\ninterior: Phase 2"
	sign.font_size = 96
	sign.pixel_size = 0.012
	sign.modulate = M.NEON_ACID
	sign.outline_size = 12
	sign.outline_modulate = M.INK
	sign.position = Vector3(cx, 4.5, Z0 + T + 0.05)
	add_child(sign)
	exit_trigger = Trigger.new()
	exit_trigger.name = "ArcadeExitTrigger"
	exit_trigger.kind = "leave"
	exit_trigger.position = Vector3((DOOR0 + DOOR1) * 0.5, 1.0, ZF - T - 1.0)
	add_child(exit_trigger)

func bind_door(d: Node) -> void:
	door = d
	exit_trigger.door = d

func _solid(b, body: StaticBody3D, key: String, center: Vector3, size: Vector3) -> void:
	b.box(key, center, size)
	var sh := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	sh.shape = bs
	sh.position = center
	body.add_child(sh)

func _tape(b, c: Vector3, s: Vector2) -> void:
	var w := 0.12
	b.box("caution", c + Vector3(0, 0, -s.y * 0.5), Vector3(s.x, 0.01, w))
	b.box("caution", c + Vector3(0, 0, s.y * 0.5), Vector3(s.x, 0.01, w))
	b.box("caution", c + Vector3(-s.x * 0.5, 0, 0), Vector3(w, 0.01, s.y))
	b.box("caution", c + Vector3(s.x * 0.5, 0, 0), Vector3(w, 0.01, s.y))

func _static_shutter() -> ShaderMaterial:
	var m := M.toon(Color("22272e"), Color("555e66"), M.TRIM_SHUTTER, 1.5, 0.0, 0.2)
	# world-space trim on a box; slats need to run horizontally, so rotate via tile choice only
	return m
