extends Node3D
## Arcade interior (Phase 1 shell + Phase 2 furnishing, LOCAL). Its own scene, instanced off-map by arcade_door.gd,
## in the same local frame as the exterior (x 8..70, z -44..-8, 9 m), on the 1 m grid / 4 m bays.
## Same toon shader family and trim sheet as the outside; posters from the same art atlas;
## cabinet screens, marquees and signs from arcade_screens.png. Everything static is batched per material.
## Layout (PLAN.md §Phase 3/4): checker runway from the shutter to the featured ZERO GAME THING PRO 2K,
## two rows of six each side of the runway, an east-wall line of six, the token counter (back west) and the
## Bars per Watt corner (back east: power rack, bar, stools, lounge). Playable cabinets open the existing
## Punk Arcade games through arcade_overlay.gd; the HQ placeholder cabinet (cabinet.tscn) stands by the counter.

const M = preload("res://scripts/arcade_materials.gd")
const Batch = preload("res://scripts/arcade_batch.gd")
const Atlas = preload("res://scripts/arcade_atlas.gd")
const Trigger = preload("res://scripts/arcade_trigger.gd")
const Cabinet = preload("res://scripts/arcade_cabinet.gd")
const Overlay = preload("res://scripts/arcade_overlay.gd")

const X0 := 8.0
const X1 := 70.0
const Z0 := -44.0
const ZF := -8.0
const H := 9.0
const T := 0.3
const DOOR0 := 28.0
const DOOR1 := 36.0
## Where yard.gd puts the HQ placeholder cabinet (cabinet.tscn, unchanged hooks), local to this room.
const HQ_CABINET_LOCAL := Vector3(23.5, 0.85, -37.0)
const FEATURED := Vector3(32.0, 0.0, -25.0)

## Playable cabinets: links to the existing Punk Arcade pages on the same Pages origin (game code untouched).
const GAMES := {
	"grind-the-terms": {"title": "Grind the Terms", "path": "games/grind-the-terms/demo/embed.html", "screen": "s_grind", "marquee": "m_grind"},
	"tag-before-training": {"title": "Tag Before Training", "path": "games/tag-before-training/demo/embed.html", "screen": "s_tag", "marquee": "m_tag"},
	"cookie-wall": {"title": "Cookie Wall", "path": "games/cookie-wall/demo/embed.html?skin=au&orientation=auto", "screen": "s_cookie", "marquee": "m_cookie"},
	"bars-per-watt": {"title": "Bars per Watt", "path": "games/bars-per-watt/demo/embed.html", "screen": "s_bpw", "marquee": "m_bpw"},
	"punk-arcade": {"title": "ZERO GAME THING PRO 2K", "path": "demo/", "screen": "s_zgt", "marquee": "m_zgt"},
}

var spawn_local := Vector3(32.0, 0.5, -10.8)
var exit_trigger: Node3D
var door: Node
var overlay: Node
var cabinets := {}       # game id -> arcade_cabinet.gd node
var body: StaticBody3D
var stats := {}
var _b
var _n := 0

func _ready() -> void:
	overlay = Overlay.new()
	overlay.name = "ArcadeOverlay"
	add_child(overlay)
	var b := Batch.new()
	_b = b
	_materials(b)
	body = StaticBody3D.new()
	body.name = "InteriorShell"
	add_child(body)
	_shell(b)
	_lamps(b)
	_runway(b)
	_rows(b)
	_featured(b)
	_counter(b)
	_bpw_corner(b)
	_posters(b)
	var meshes := b.commit(self, "Interior")
	stats = {"batched_tris": b.tris(), "batched_meshes": meshes.size()}
	_lights()
	exit_trigger = Trigger.new()
	exit_trigger.name = "ArcadeExitTrigger"
	exit_trigger.kind = "leave"
	exit_trigger.position = Vector3((DOOR0 + DOOR1) * 0.5, 1.0, ZF - T - 1.0)
	add_child(exit_trigger)

func bind_door(d: Node) -> void:
	door = d
	exit_trigger.door = d

# ---------- materials ----------
func _materials(b) -> void:
	b.add_material("wall", M.ribbed(M.WALL_IN_DARK, M.WALL_IN, 0.22, M.TRIM_CONCRETE, 0.2), true, M.NO_OMNI_LAYER)
	b.add_material("ceiling", M.toon(Color("17161c"), Color("2c2a33"), M.TRIM_BOXPROFILE, 2.5, 0.0, 0.0, 0.8), false, M.NO_OMNI_LAYER)
	b.add_material("floor", M.toon(Color("1d2725"), Color("34413e"), M.TRIM_CONCRETE, 6.0, 0.0, 0.0, 0.3))
	b.add_material("props_ink", M.props(0.02))
	b.add_material("props", M.props(0.0, M.TRIM_CONCRETE, 2.0, 0.35))
	b.add_material("glow", M.glow_batch(), false)
	b.add_material("screen", M.screen_batch(), false)
	b.add_material("marq", M.art_vc_screens(), false, M.NO_OMNI_LAYER)
	b.add_material("artvc", M.art_vc(), false, M.NO_OMNI_LAYER)
	b.add_material("shutter", M.toon(Color("22272e"), Color("555e66"), M.TRIM_SHUTTER, 1.5, 0.0, 0.2), true, M.NO_OMNI_LAYER)
	for k in [["steel", M.STEEL], ["caution", M.CAUTION], ["dark", Color("15161a")], ["ink", Color("0e0e10")],
			["cab_black", Color("1c1a20")], ["cab_red", Color("5a1626")], ["cab_teal", Color("123c3a")], ["cab_purple", Color("2e1a40")],
			["cab_acid", Color("2a3010")], ["cab_zgt", Color("2b2d36")], ["deck", Color("24222a")], ["wood", Color("6a3f2a")], ["wood_dark", Color("3a2219")],
			["sofa", Color("7a2040")], ["cushion", Color("a2305a")], ["chrome", Color("8a8f96")], ["rack", Color("1d2a22")],
			["prize_a", Color("e23e8c")], ["prize_b", Color("3d7ec4")], ["prize_c", Color("e0a15a")], ["prize_d", Color("6fbf4a")]]:
		b.alias(k[0], "props_ink", k[1])
	for k in [["check_dark", Color("1a1a20")], ["check_light", Color("8d8577")], ["floor_green", Color("173322")], ["tape", M.CAUTION]]:
		b.alias(k[0], "props", k[1])
	b.alias("lamp", "glow", M.glow_vc(Color("ffd7a0"), 0.7))
	b.alias("neon", "glow", M.glow_vc(M.NEON_COOLANT, 1.2))
	b.alias("neon_acid", "glow", M.glow_vc(M.NEON_ACID, 1.3))
	b.alias("neon_pink", "glow", M.glow_vc(Color("ff3d7f"), 1.2))
	b.alias("neon_red", "glow", M.glow_vc(M.ALERT, 1.2))
	b.alias("neon_teal", "glow", M.glow_vc(M.NEON_COOLANT, 1.2))
	b.alias("btn_red", "glow", M.glow_vc(M.ALERT, 1.0))
	b.alias("btn_acid", "glow", M.glow_vc(M.NEON_ACID, 1.0))
	b.alias("btn_teal", "glow", M.glow_vc(M.NEON_COOLANT, 1.0))
	b.alias("coin", "glow", M.glow_vc(Color("ff9a3c"), 0.9))
	b.alias("art", "artvc", M.art_color(0.0, 0.92))
	b.alias("mural", "artvc", M.art_color(0.25, 0.95, 0.15))
	b.alias("side", "artvc", M.art_color(0.15, 0.95))
	b.alias("side_s", "marq", M.art_color(0.3, 0.95))
	b.alias("sign", "marq", M.art_color(1.6, 1.0))
	b.alias("marquee", "marq", M.art_color(1.2, 1.0))
	b.alias("decal", "marq", M.art_color(0.35, 0.9))

func _r(name: String) -> Rect2:
	return Atlas.RECTS[name]

func _s(name: String) -> Rect2:
	return Atlas.SCREENS[name]

func _solid(key: String, center: Vector3, size: Vector3) -> void:
	_b.box(key, center, size)
	_collide(center, size)

func _collide(center: Vector3, size: Vector3, basis := Basis()) -> void:
	var sh := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	sh.shape = bs
	sh.transform = Transform3D(basis, center)
	body.add_child(sh)

# ---------- shell ----------
func _shell(b) -> void:
	var cx := (X0 + X1) * 0.5
	var cz := (Z0 + ZF) * 0.5
	_solid("floor", Vector3(cx, -0.25, cz), Vector3(X1 - X0 + 1.0, 0.5, ZF - Z0 + 1.0))
	_solid("ceiling", Vector3(cx, H + 0.15, cz), Vector3(X1 - X0 + 1.0, 0.3, ZF - Z0 + 1.0))
	_solid("wall", Vector3(cx, H * 0.5, Z0), Vector3(X1 - X0, H, T * 2.0))
	_solid("wall", Vector3(X0, H * 0.5, cz), Vector3(T * 2.0, H, ZF - Z0))
	_solid("wall", Vector3(X1, H * 0.5, cz), Vector3(T * 2.0, H, ZF - Z0))
	_solid("wall", Vector3((X0 + DOOR0) * 0.5, H * 0.5, ZF), Vector3(DOOR0 - X0, H, T * 2.0))
	_solid("wall", Vector3((DOOR1 + X1) * 0.5, H * 0.5, ZF), Vector3(X1 - DOOR1, H, T * 2.0))
	_solid("wall", Vector3((DOOR0 + DOOR1) * 0.5, (6.1 + H) * 0.5, ZF), Vector3(DOOR1 - DOOR0, H - 6.1, T * 2.0))
	# inside face of the closed shutter, jambs and drum (the way back out)
	_solid("shutter", Vector3((DOOR0 + DOOR1) * 0.5, 3.05, ZF), Vector3(DOOR1 - DOOR0, 6.1, 0.2))
	for jx in [DOOR0 + 0.2, DOOR1 - 0.2]:
		b.box("caution", Vector3(jx, 3.05, ZF - T - 0.15), Vector3(0.4, 6.1, 0.3))
	b.box("steel", Vector3((DOOR0 + DOOR1) * 0.5, 6.3, ZF - T - 0.35), Vector3(DOOR1 - DOOR0 + 0.4, 0.7, 0.7))
	# kick plate + neon skirting round the room (gaps at the door)
	for seg in [[X0 + T, Z0 + T, X1 - T, Z0 + T, Vector3(0, 0, 1)], [X0 + T, Z0 + T, X0 + T, ZF - T, Vector3(1, 0, 0)], [X1 - T, Z0 + T, X1 - T, ZF - T, Vector3(-1, 0, 0)],
			[X0 + T, ZF - T, DOOR0, ZF - T, Vector3(0, 0, -1)], [DOOR1, ZF - T, X1 - T, ZF - T, Vector3(0, 0, -1)]]:
		var a := Vector3(seg[0], 0.0, seg[1])
		var c := Vector3(seg[2], 0.0, seg[3])
		var out: Vector3 = seg[4]
		var mid := (a + c) * 0.5
		var len := a.distance_to(c)
		var sz := Vector3(len, 0.0, 0.0) if absf(out.z) > 0.5 else Vector3(0.0, 0.0, len)
		b.box("dark", mid + out * 0.03 + Vector3(0, 0.3, 0), sz + Vector3(0, 0.6, 0) + (Vector3(0, 0, 0.06) if absf(out.z) > 0.5 else Vector3(0.06, 0, 0)))
		b.box("neon", mid + out * 0.07 + Vector3(0, 0.62, 0), sz + Vector3(0, 0.05, 0) + (Vector3(0, 0, 0.03) if absf(out.z) > 0.5 else Vector3(0.03, 0, 0)))
	# roof trusses on the 4 m bays (every second bay) with a lower chord + diagonals
	var tz := Z0 + 4.0
	while tz < ZF - 1.0:
		b.box("steel", Vector3(cx, H - 0.5, tz), Vector3(X1 - X0, 0.3, 0.25))
		b.box("steel", Vector3(cx, H - 1.6, tz), Vector3(X1 - X0, 0.18, 0.18))
		var x := X0 + 2.0
		while x < X1 - 1.0:
			b.box("steel", Vector3(x, H - 1.05, tz), Vector3(0.12, 1.1, 0.12), Basis(Vector3(0, 0, 1), 0.7 if int(x) % 8 == 2 else -0.7))
			x += 4.0
		tz += 8.0

func _lamps(b) -> void:
	# soft industrial lamps: dark housing, warm diffuser underneath (no bare white tubes)
	for lz in [-12.0, -20.0, -28.0, -36.0]:
		for lx in [18.0, 32.0, 46.0, 60.0]:
			b.box("steel", Vector3(lx, 6.78, lz), Vector3(1.8, 0.22, 0.7))
			b.box("dark", Vector3(lx, 6.62, lz), Vector3(1.9, 0.1, 0.8))
			b.panel("lamp", Vector3(lx, 6.56, lz), Vector2(1.5, 0.5), Vector3(0, -1, 0))
			b.box("steel", Vector3(lx - 0.7, 7.75, lz), Vector3(0.02, 1.8, 0.02))
			b.box("steel", Vector3(lx + 0.7, 7.75, lz), Vector3(0.02, 1.8, 0.02))

func _lights() -> void:
	# low, warm and wide: pools on the floor without blowing out the cabinets
	for l in [[20.0, 4.6, -21.0, Color("ffcf9a"), 1.1, 15.0], [44.0, 4.6, -21.0, Color("ffcf9a"), 1.1, 15.0],
			[32.0, 3.6, -22.5, Color("dbff6a"), 0.9, 8.0], [62.0, 3.8, -37.0, Color("7dffa8"), 1.1, 11.0],
			[16.0, 3.8, -36.0, Color("ff9ab8"), 0.9, 10.0], [66.0, 4.2, -18.0, Color("8fe8ff"), 0.8, 11.0]]:
		var o := OmniLight3D.new()
		o.position = Vector3(l[0], l[1], l[2])
		o.light_color = l[3]
		o.light_energy = l[4]
		o.omni_range = l[5]
		o.omni_attenuation = 1.4
		o.light_cull_mask = M.OMNI_MASK
		o.shadow_enabled = false
		add_child(o)

# ---------- floor ----------
func _runway(b) -> void:
	# checker runway from the shutter to the featured cabinet's dais
	for iz in range(int(ZF - T - 0.5), int(FEATURED.z + 2.0), -1):
		for ix in range(int(DOOR0 + 2.0), int(DOOR1 - 2.0)):
			var key := "check_dark" if (ix + iz) % 2 == 0 else "check_light"
			var x0 := float(ix)
			var z0 := float(iz)
			b.quad_up(key, Vector3(x0, 0.006, z0 - 1.0), Vector3(x0 + 1.0, 0.006, z0 - 1.0), Vector3(x0 + 1.0, 0.006, z0), Vector3(x0, 0.006, z0))
	for x in [DOOR0 + 1.9, DOOR1 - 1.9]:
		b.box("tape", Vector3(x, 0.008, (ZF - T - 0.5 + FEATURED.z + 2.0) * 0.5), Vector3(0.12, 0.012, ZF - T - 0.5 - FEATURED.z - 2.0))
	# Bars per Watt corner floor
	b.quad_up("floor_green", Vector3(55.0, 0.005, -44.0 + T), Vector3(X1 - T, 0.005, -44.0 + T), Vector3(X1 - T, 0.005, -29.0), Vector3(55.0, 0.005, -29.0))

# ---------- cabinets ----------
## One upright cabinet facing local +Z of `yaw`. screen/marquee are arcade_screens.png names; side is an
## arcade_art.png name for side art ("" for a plain stripe). s scales the whole body (featured = 1.2).
func _cab(b, pos: Vector3, yaw: float, color: String, screen: String, marquee: String, side := "", s := 1.0, accent := "btn_acid", draw_screen := true) -> void:
	var bas := Basis(Vector3.UP, yaw)
	var f := bas.z
	var r := bas.x
	var w := 0.86 * s
	var d := 0.78 * s
	var h := 1.9 * s
	b.box(color, pos + Vector3(0, h * 0.5, 0), Vector3(w, h, d), bas)
	b.box("ink", pos + Vector3(0, 0.25 * s, 0) + f * (d * 0.5 + 0.01), Vector3(w - 0.06, 0.5 * s, 0.03), bas)
	b.box("coin", pos + Vector3(0, 0.66 * s, 0) + f * (d * 0.5 + 0.02), Vector3(0.16 * s, 0.1 * s, 0.02), bas)
	# control deck, tilted toward the player
	var deck_basis := bas * Basis(Vector3.RIGHT, -0.28)
	b.box("deck", pos + Vector3(0, 1.02 * s, 0) + f * (d * 0.5 + 0.14 * s), Vector3(w, 0.1 * s, 0.34 * s), deck_basis)
	for k in 3:
		b.box(accent if k == 0 else ("btn_red" if k == 1 else "btn_teal"), pos + Vector3(0, 1.09 * s, 0) + f * (d * 0.5 + 0.12 * s) + r * ((0.06 + k * 0.1) * s), Vector3(0.06, 0.04, 0.06) * s, bas)
	b.box("ink", pos + Vector3(0, 1.12 * s, 0) + f * (d * 0.5 + 0.13 * s) - r * 0.2 * s, Vector3(0.03, 0.12, 0.03) * s, bas)
	# screen bezel and CRT, leaning back a little
	var scr_basis := bas * Basis(Vector3.RIGHT, -0.12)
	b.box("ink", pos + Vector3(0, 1.45 * s, 0) + f * (d * 0.5 + 0.005), Vector3(w - 0.08, 0.62 * s, 0.02), scr_basis)
	if draw_screen:
		b.panel_basis("screen", pos + Vector3(0, 1.45 * s, 0) + f * (d * 0.5 + 0.022), Vector2(0.68, 0.51) * s, scr_basis, _s(screen))
	# marquee box (overhangs the front) with the lit title
	b.box(color, pos + Vector3(0, h + 0.13 * s, 0) + f * 0.06 * s, Vector3(w, 0.26 * s, d - 0.08), bas)
	b.panel_basis("marquee", pos + Vector3(0, h + 0.13 * s, 0) + f * (0.06 * s + (d - 0.08) * 0.5 + 0.006), Vector2(w - 0.06, 0.22 * s), bas, _s(marquee))
	# sides: art or a stripe
	for sgn in [-1.0, 1.0]:
		var out: Vector3 = r * sgn
		var side_basis := Basis(-f * sgn, Vector3.UP, out)
		if side != "":
			var own := side.begins_with("side_")
			var rect: Rect2 = _s(side) if own else _r(side)
			b.panel_basis("side_s" if own else "side", pos + Vector3(0, 1.1 * s, 0) + out * (w * 0.5 + 0.006), Vector2(d * 0.85, 1.5 * s), side_basis, rect)
		else:
			b.box(accent.replace("btn_", "neon_") if accent != "btn_acid" else "neon_acid", pos + Vector3(0, 1.7 * s, 0) + out * (w * 0.5 + 0.004) + f * (d * 0.45), Vector3(0.01, 0.08, 0.08) * s, bas)
	_n += 1

func _decoy(b, pos: Vector3, yaw: float, color: String, screen: String, marquee: String, side := "", accent := "btn_acid") -> void:
	_cab(b, pos, yaw, color, screen, marquee, side, 1.0, accent)
	_collide(pos + Vector3(0, 0.95, 0), Vector3(0.86, 1.9, 0.78), Basis(Vector3.UP, yaw))

func _playable(b, id: String, pos: Vector3, yaw: float, color: String, side := "", s := 1.0, accent := "btn_acid", draw_screen := true) -> Node3D:
	var g: Dictionary = GAMES[id]
	_cab(b, pos, yaw, color, g.screen, g.marquee, side, s, accent, draw_screen)
	var c := Cabinet.new()
	c.name = "Cabinet_" + id.replace("-", "_")
	c.game_id = id
	c.title = g.title
	c.path = g.path
	c.overlay = overlay
	c.position = pos
	c.rotation.y = yaw
	var sh := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.86, 1.9, 0.78) * s
	sh.shape = bs
	sh.position = Vector3(0, 0.95 * s, 0)
	c.add_child(sh)
	add_child(c)
	cabinets[id] = c
	return c

func _rows(b) -> void:
	var colors := ["cab_black", "cab_red", "cab_teal", "cab_purple", "cab_black", "cab_acid"]
	var screens := ["s_soon", "s_hiscore", "s_zero", "s_soon", "s_hiscore", "s_zero"]
	var sides := ["do-not-feed-the-algorithm", "", "the-human-zoo", "", "the-alignment-problem", ""]
	var accents := ["btn_acid", "btn_red", "btn_teal", "btn_acid", "btn_red", "btn_teal"]
	# west of the runway: two rows of six, the playable one on the runway end of each row
	for row in [[-17.0, "tag-before-training"], [-26.0, "cookie-wall"]]:
		for i in 6:
			var x := 13.5 + float(i) * 2.5
			var p := Vector3(x, 0.0, row[0])
			if i == 5:
				_playable(b, row[1], p, 0.0, "cab_teal" if row[1] == "tag-before-training" else "cab_purple", "zero-cover-band" if row[1] == "cookie-wall" else "deadpan-flow", 1.0, "btn_teal")
			else:
				_decoy(b, p, 0.0, colors[posmod(i + int(row[0]), 6)], screens[i], "m_soon", sides[i], accents[i])
	# east of the runway
	for row in [[-17.0, "grind-the-terms"], [-26.0, ""]]:
		for i in 6:
			var x := 38.0 + float(i) * 2.5
			var p := Vector3(x, 0.0, row[0])
			if i == 0 and row[1] != "":
				_playable(b, row[1], p, 0.0, "cab_red", "the-alignment-problem", 1.0, "btn_red")
			else:
				_decoy(b, p, 0.0, colors[(i + 3) % 6], screens[(i + 2) % 6], "m_soon", sides[(i + 1) % 6], accents[(i + 1) % 6])
	# east-wall line of six, facing into the room
	for i in 6:
		var z := -11.5 - float(i) * 2.5
		_decoy(b, Vector3(X1 - T - 0.6, 0.0, z), -PI * 0.5, colors[i], screens[(i + 1) % 6], "m_soon", "", accents[i])

func _featured(b) -> void:
	# dais with caution edge, then the tall ZERO GAME THING PRO 2K with custom side art and the attract loop
	var p := FEATURED
	_solid("deck", p + Vector3(0, 0.06, 0), Vector3(2.6, 0.12, 2.6))
	for e in [[Vector3(0, 0.125, 1.3), Vector3(2.6, 0.01, 0.12)], [Vector3(0, 0.125, -1.3), Vector3(2.6, 0.01, 0.12)], [Vector3(1.3, 0.125, 0), Vector3(0.12, 0.01, 2.6)], [Vector3(-1.3, 0.125, 0), Vector3(0.12, 0.01, 2.6)]]:
		b.box("caution", p + e[0], e[1])
	var top := p + Vector3(0, 0.12, 0)
	var c := _playable(b, "punk-arcade", top, 0.0, "cab_zgt", "side_zgt", 1.25, "btn_acid", false)
	c.name = "FeaturedCabinet"
	# acid edge lights up the front corners
	for sx in [-0.54, 0.54]:
		b.box("neon_acid", top + Vector3(sx, 1.19, 0.49), Vector3(0.035, 2.375, 0.035))
	# the attract screen is its own mesh so the shader can cycle the cards (a light loop, no video)
	var scr := MeshInstance3D.new()
	scr.name = "AttractScreen"
	var q := QuadMesh.new()
	q.size = Vector2(0.68, 0.51) * 1.25
	scr.mesh = q
	scr.material_override = M.screen_attract([_s("s_zgt"), _s("s_grind"), _s("s_tag"), _s("s_cookie"), _s("s_bpw"), _s("s_zero")])
	scr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scr.transform = Transform3D(Basis(Vector3.RIGHT, -0.12), top + Vector3(0, 1.45 * 1.25, 0.78 * 1.25 * 0.5 + 0.024))
	add_child(scr)
	# acid halo on the floor behind it and a neon Zero above
	b.panel("sign", top + Vector3(0, 3.35, -0.2), Vector2(2.6, 0.62), Vector3(0, 0, 1), _s("m_zgt"))
	b.box("steel", top + Vector3(-1.1, 3.1, -0.3), Vector3(0.05, 1.2, 0.05))
	b.box("steel", top + Vector3(1.1, 3.1, -0.3), Vector3(0.05, 1.2, 0.05))

# ---------- token counter (back west) + the HQ placeholder cabinet ----------
func _counter(b) -> void:
	var z := -37.5
	_solid("wood_dark", Vector3(15.0, 0.52, z), Vector3(10.0, 1.04, 0.8))
	b.box("wood", Vector3(15.0, 1.08, z + 0.05), Vector3(10.3, 0.08, 1.0))
	b.panel("decal", Vector3(15.0, 0.55, z + 0.405), Vector2(6.0, 0.7), Vector3(0, 0, 1), _s("m_tokens"))
	_solid("wood_dark", Vector3(X0 + T + 0.4, 0.52, z + 2.6), Vector3(0.8, 1.04, 4.4))
	b.box("wood", Vector3(X0 + T + 0.4, 1.08, z + 2.6), Vector3(1.0, 0.08, 4.6))
	# register + bell
	b.box("dark", Vector3(13.0, 1.3, z), Vector3(0.6, 0.38, 0.45))
	b.box("btn_acid", Vector3(13.0, 1.45, z + 0.2), Vector3(0.45, 0.12, 0.02))
	b.box("chrome", Vector3(17.5, 1.16, z), Vector3(0.18, 0.08, 0.18))
	# prize shelves on the back wall
	for k in 3:
		var y := 1.0 + k * 0.85
		b.box("steel", Vector3(15.0, y, Z0 + T + 0.3), Vector3(9.0, 0.06, 0.55))
		for i in 12:
			var key: String = ["prize_a", "prize_b", "prize_c", "prize_d"][(i + k) % 4]
			var sz := 0.28 + 0.12 * float((i * 7 + k * 3) % 3)
			b.box(key, Vector3(11.0 + i * 0.72, y + 0.03 + sz * 0.5, Z0 + T + 0.3), Vector3(sz * 0.8, sz, sz * 0.7))
	b.panel("sign", Vector3(15.0, 4.6, Z0 + T + 0.03), Vector2(7.0, 1.62), Vector3(0, 0, 1), _s("counter_sign"))
	b.box("dark", Vector3(15.0, 4.6, Z0 + T + 0.015), Vector3(7.3, 1.9, 0.02))
	# the HQ placeholder cabinet (scenes/cabinet.tscn, positioned by yard.gd) gets a matching shell
	var hp := HQ_CABINET_LOCAL - Vector3(0, 0.85, 0)
	_cab(b, hp, 0.0, "cab_black", "s_zero", "m_hq", "", 1.0, "btn_red")

# ---------- Bars per Watt corner (back east) ----------
func _bpw_corner(b) -> void:
	var zb := Z0 + T
	# power rack wall: steel frame, three glowing battery-cell panels
	b.box("rack", Vector3(62.5, 2.2, zb + 0.35), Vector3(13.0, 4.0, 0.7))
	for i in 3:
		var x := 58.4 + i * 4.1
		b.panel("sign", Vector3(x, 2.25, zb + 0.715), Vector2(3.8, 1.8), Vector3(0, 0, 1), _s("rack"))
		b.box("steel", Vector3(x + 2.05, 2.2, zb + 0.74), Vector3(0.12, 4.0, 0.08))
	b.box("steel", Vector3(62.5, 4.25, zb + 0.74), Vector3(13.0, 0.14, 0.1))
	b.box("neon_acid", Vector3(62.5, 0.1, zb + 0.72), Vector3(13.0, 0.05, 0.05))
	for x in [57.6, 67.4]:
		b.box("steel", Vector3(x, 6.4, zb + 0.08), Vector3(0.1, 1.6, 0.1))
	b.box("dark", Vector3(62.5, 5.6, zb + 0.02), Vector3(9.4, 2.3, 0.04))
	b.panel("sign", Vector3(62.5, 5.6, zb + 0.05), Vector2(9.0, 2.1), Vector3(0, 0, 1), _s("bpw_sign"))
	_collide(Vector3(62.5, 2.2, zb + 0.35), Vector3(13.0, 4.4, 0.7))
	# bar counter + stools
	var bz := -38.6
	_solid("wood_dark", Vector3(61.0, 0.55, bz), Vector3(8.0, 1.1, 0.8))
	b.box("chrome", Vector3(61.0, 1.13, bz + 0.05), Vector3(8.3, 0.06, 1.0))
	b.box("neon_acid", Vector3(61.0, 0.12, bz + 0.41), Vector3(7.8, 0.04, 0.03))
	for i in 5:
		var sx := 57.8 + i * 1.6
		b.box("chrome", Vector3(sx, 0.38, bz + 1.1), Vector3(0.08, 0.76, 0.08))
		b.box("cushion", Vector3(sx, 0.8, bz + 1.1), Vector3(0.46, 0.1, 0.46))
		b.box("steel", Vector3(sx, 0.02, bz + 1.1), Vector3(0.4, 0.04, 0.4))
	# lounge: rug, sofa against the east wall, low table, speaker stacks
	b.panel("decal", Vector3(65.8, 0.012, -33.0), Vector2(4.2, 2.6), Vector3(0, 1, 0), _s("rug"))
	var sx0 := X1 - T - 0.55
	_solid("sofa", Vector3(sx0, 0.25, -33.0), Vector3(1.0, 0.5, 3.4))
	b.box("sofa", Vector3(sx0 + 0.35, 0.75, -33.0), Vector3(0.3, 0.6, 3.4))
	for zz in [-34.45, -31.55]:
		b.box("sofa", Vector3(sx0, 0.6, zz), Vector3(1.0, 0.25, 0.3))
	for zz in [-33.9, -32.1]:
		b.box("cushion", Vector3(sx0 - 0.05, 0.56, zz), Vector3(0.85, 0.12, 1.5))
	_solid("wood", Vector3(65.4, 0.22, -33.0), Vector3(1.2, 0.44, 0.7))
	b.box("btn_acid", Vector3(65.4, 0.47, -33.1), Vector3(0.12, 0.06, 0.12))
	for sp in [Vector3(X1 - T - 0.5, 0.0, -29.8), Vector3(56.0, 0.0, Z0 + T + 1.2)]:
		_solid("ink", sp + Vector3(0, 0.75, 0), Vector3(0.8, 1.5, 0.7))
		for k in 2:
			b.box("steel", sp + Vector3(0, 0.45 + k * 0.6, 0) + Vector3(-0.41 if sp.x > 60.0 else 0.0, 0, 0.36 if sp.x < 60.0 else 0.0), Vector3(0.04 if sp.x > 60.0 else 0.5, 0.42, 0.5 if sp.x > 60.0 else 0.04))
	# the Bars per Watt cabinet (the existing preview page), facing the room
	_playable(b, "bars-per-watt", Vector3(58.0, 0.0, -31.5), 0.0, "rack", "side_bpw", 1.0, "btn_acid")

# ---------- posters and murals (our art, same atlas as the outside) ----------
func _posters(b) -> void:
	# west wall: wheatpaste covers
	var wx := X0 + T + 0.012
	var covers := [["do-not-feed-the-algorithm", 1.4, 4.2], ["the-human-zoo", 1.4, 4.2], ["the-alignment-problem", 2.1, 4.2], ["zero-cover-band", 2.0, 2.6], ["deadpan-flow", 2.2, 1.24]]
	var z := -11.5
	for c in covers:
		var rect := _r(c[0])
		var w: float = c[1]
		var hgt: float = w * (rect.size.y * 1024.0) / (rect.size.x * 2048.0)
		b.panel("art", Vector3(wx, 2.9, z - w * 0.5), Vector2(w, hgt), Vector3(1, 0, 0), rect, 0.02 if int(z) % 2 == 0 else -0.02)
		z -= w + 0.9
	# west wall mural over the rows
	b.panel("mural", Vector3(wx, 3.4, -27.5), Vector2(7.6, 7.6 * 446.0 / 1012.0), Vector3(1, 0, 0), _r("mural_b"))
	# back wall mural between the counter and the BPW corner
	b.panel("mural", Vector3(37.5, 3.6, Z0 + T + 0.012), Vector2(13.0, 13.0 * 538.0 / 1012.0), Vector3(0, 0, 1), _r("mural_a"))
	# front wall (seen on the way out): mural east of the shutter, covers west of it
	var fz := ZF - T - 0.012
	b.panel("mural", Vector3(48.0, 3.6, fz), Vector2(12.0, 12.0 * 407.0 / 1012.0), Vector3(0, 0, -1), _r("mural_c"))
	for i in 3:
		var name: String = ["the-alignment-problem", "do-not-feed-the-algorithm", "zero-cover-band"][i]
		var rect := _r(name)
		var w := 1.8
		b.panel("art", Vector3(24.5 - i * 4.0, 3.0, fz), Vector2(w, w * (rect.size.y * 1024.0) / (rect.size.x * 2048.0)), Vector3(0, 0, -1), rect)
	# east wall above the cabinet line
	var ex := X1 - T - 0.012
	for i in 4:
		var name: String = ["the-human-zoo", "deadpan-flow", "the-alignment-problem", "zero_glyph"][i]
		var rect := _r(name)
		var w := 1.6 if name != "deadpan-flow" else 2.4
		b.panel("art", Vector3(ex, 3.4, -11.5 - i * 4.2), Vector2(w, w * (rect.size.y * 1024.0) / (rect.size.x * 2048.0)), Vector3(-1, 0, 0), rect)
