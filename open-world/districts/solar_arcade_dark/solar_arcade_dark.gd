extends Node3D
## Solar Arcade, dark (Act I M4, Nov 20 2026): the arcade interior for MISSION P.3 Power On. Ships in its own pack
## (build/web/districts/solar_arcade_dark.pck), never in index.pck; built in code from main-pack blocks so it stays tiny.
## World coordinates (registry origin 0, 0, 0), off to the east of the map (x 212 .. 248, z -42 .. -10), reached only
## by the story's fade at the arcade's side door. Ground y = 0.
##
## Dark, hot, dusty: rows of dead cabinets under sheets, the token counter, light shafts through broken roof panels,
## the workbench at the back with Zero's parts and the window CRT wired into the torso, and the breaker box on the
## west wall ("DO NOT RECONNECT – IT TALKS."). Three fuse spots: a cabinet's coin box (north row), a toolbox under the
## workbench, and the light fixture over the tall cabinet by the south windows (climb the toppled cabinet leaning on it).
## p3_power_on.gd lights it up when the breaker is thrown.

const Blocks = preload("res://scripts/world_blocks.gd")
const Palette = preload("res://scripts/palette.gd")

const DUST := Color("4a3f3a")
const WALL := Color("2e2826")
const SHEET := Color("b9b2a6")
const LIME := Color("c6ff3d")
const COIN_BOX := Vector3(230.0, 0.7, -39.35)
const TOOLBOX := Vector3(243.4, 0.25, -24.0)
const FIXTURE := Vector3(236.0, 2.75, -12.6)
const BREAKER := Vector3(212.75, 1.5, -34.0)

func _ready() -> void:
	set_meta("district_id", "solar_arcade_dark")
	_shell()
	_cabinets()
	_counter()
	_bench()
	_climb()
	_breaker()
	_fuses()
	_dark_light()
	_act1()

func _shell() -> void:
	Blocks.solid(self, "Floor", Vector3(230.0, -0.5, -26.0), Vector3(38.0, 1.0, 34.0), DUST, Vector3.ZERO, 0.04)
	Blocks.solid(self, "WallWest", Vector3(212.0, 3.0, -26.0), Vector3(0.5, 6.0, 34.0), WALL)
	Blocks.solid(self, "WallEast", Vector3(248.0, 3.0, -26.0), Vector3(0.5, 6.0, 34.0), WALL)
	Blocks.solid(self, "WallNorth", Vector3(230.0, 3.0, -42.0), Vector3(36.5, 6.0, 0.5), WALL)
	Blocks.solid(self, "WallSouth", Vector3(230.0, 3.0, -10.0), Vector3(36.5, 6.0, 0.5), WALL)
	# the roof: solar panels, closed (no sky gets in); the two broken ones only let a thin haze of dust-light through
	for i in 6:
		var x := 215.0 + i * 6.0
		Blocks.visual(self, "RoofPanel%d" % i, Vector3(x, 6.1, -26.0), Vector3(6.0, 0.2, 34.0), Color("14181e"))
		if i == 2 or i == 4:
			var shaft := Blocks.visual(self, "LightShaft%d" % i, Vector3(x, 3.0, -26.0), Vector3(1.4, 6.0, 1.0), Color(1.0, 0.86, 0.6))
			shaft.material_override = _haze(Color(1.0, 0.82, 0.55, 0.07))
			shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the side door (west end of the south wall) and the dirty south windows the sweep light passes along
	Blocks.visual(self, "SideDoor", Vector3(214.6, 1.2, -10.3), Vector3(1.8, 2.4, 0.1), Color("3a2f2a"))
	for i in 5:
		Blocks.visual(self, "Window%d" % i, Vector3(220.0 + i * 6.0, 3.2, -10.28), Vector3(3.6, 1.4, 0.06), Color("5d6a70"))
	var sign := Blocks.label(self, "SOLAR ARCADE", Vector3(230.0, 4.8, -41.6), Color("6b5f58"), 64)
	sign.name = "ArcadeSign"

func _cabinets() -> void:
	# the north row under dust sheets; the one at x 230 has its coin box hanging open
	for i in 7:
		var x := 221.0 + i * 3.0
		var cab := Blocks.solid(self, "Cabinet%d" % i, Vector3(x, 0.95, -40.6), Vector3(1.3, 1.9, 1.2), Color("2c2826"))
		cab.set_meta("sheet", true)
		_cloth(cab)
		var glow := Blocks.visual(self, "CabinetGlow%d" % i, Vector3(x, 1.3, -39.98), Vector3(0.9, 0.7, 0.02), Color("101010"))
		glow.set_meta("glow", true)
	Blocks.visual(self, "CoinBoxDoor", Vector3(230.0, 0.6, -39.9), Vector3(0.5, 0.35, 0.05), Color("8a7a52"))
	# a second row mid-floor (west half), out of the walking lanes
	for i in 3:
		var mid := Blocks.solid(self, "CabinetMid%d" % i, Vector3(222.0 + i * 3.0, 0.95, -30.5), Vector3(1.3, 1.9, 1.2), Color("2c2826"))
		mid.set_meta("sheet", true)
		_cloth(mid)

func _counter() -> void:
	Blocks.solid(self, "TokenCounter", Vector3(218.0, 0.55, -17.5), Vector3(4.0, 1.1, 1.0), Color("5a3f2c"))
	var t := Blocks.label(self, "TOKENS", Vector3(218.0, 1.6, -16.9), Color("4d4038"), 30)
	t.name = "TokenSign"

func _bench() -> void:
	Blocks.solid(self, "Workbench", Vector3(245.6, 0.5, -26.0), Vector3(2.4, 1.0, 5.0), Color("6b4c34"))
	Blocks.visual(self, "ZeroTorso", Vector3(245.8, 1.45, -26.6), Vector3(0.9, 0.9, 0.6), Color("7b7f84"))
	Blocks.visual(self, "ZeroArm", Vector3(245.4, 1.1, -24.6), Vector3(1.2, 0.18, 0.18), Color("8c9096"))
	Blocks.visual(self, "Jacket", Vector3(245.8, 1.2, -27.4), Vector3(0.9, 0.12, 0.8), Color("2a1d17"))
	var crt := Blocks.visual(self, "BenchCRT", Vector3(245.8, 2.15, -26.6), Vector3(0.7, 0.55, 0.55), Color("1b2a1b"))
	crt.name = "BenchCRT"
	var face := Blocks.label(self, "o   o\n\\___/", Vector3(245.45, 2.15, -26.6), Color(0.78, 1.0, 0.24, 0.35), 26)
	face.name = "CrtFace"
	face.rotation.y = -PI * 0.5
	Blocks.visual(self, "Toolbox", TOOLBOX + Vector3(0.6, 0.0, 0.0), Vector3(0.7, 0.4, 0.4), Color("8b1d1d"))

func _climb() -> void:
	# the tall cabinet under the light fixture, and the toppled one leaning on it (walk up it)
	var tall := Blocks.solid(self, "TallCabinet", Vector3(236.0, 0.8, -12.6), Vector3(2.0, 1.6, 1.6), Color("2c2826"))
	tall.set_meta("sheet", true)
	_cloth(tall)
	var ramp := Blocks.add_slope(self, "ToppledCabinet", Vector3(236.0, 0.0, -18.6), Vector3(236.0, 1.6, -13.4), 1.6, Color("3a342f"))
	for child in ramp.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = Blocks.cel(Color("3a342f"), 3.0, 0.2)
	# The walk-up stays the slope. The shell is the cabinet at the high end, not a slab through the ramp.
	Blocks.visual(ramp, "CabinetShell", Vector3(0.0, 0.85, 2.15), Vector3(1.45, 0.55, 1.15), SHEET)
	Blocks.visual(self, "LightFixture", FIXTURE + Vector3(0.0, 0.45, 0.0), Vector3(1.6, 0.12, 0.4), Color("9a9a90"))
	Blocks.visual(self, "FixtureChain", FIXTURE + Vector3(0.0, 1.6, 0.0), Vector3(0.04, 2.2, 0.04), Color("5a5a52"))

func _breaker() -> void:
	Blocks.visual(self, "BreakerBox", BREAKER, Vector3(0.3, 1.2, 0.9), Color("6e5a3a"))
	# the lever sits low on the box, under the hand-lettered warning (it used to cover "IT TALKS")
	var lever := Blocks.visual(self, "BreakerLever", BREAKER + Vector3(0.22, -0.48, 0.0), Vector3(0.12, 0.34, 0.12), Color("a33"))
	lever.name = "BreakerLever"
	# the hand-lettered warning, fixed flat on the box (not a billboard) and small enough to read whole on screen
	var l := Blocks.label(self, "DO NOT RECONNECT\n- IT TALKS.", BREAKER + Vector3(0.17, 0.0, 0.0), Color("d8d0b0"), 32)
	l.name = "BreakerLabel"
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation.y = PI * 0.5
	l.pixel_size = 0.0055
	l.outline_size = 6
	for i in 3:
		var slot := Blocks.visual(self, "FuseSlot%d" % i, BREAKER + Vector3(0.18, 0.44, -0.25 + i * 0.25), Vector3(0.06, 0.14, 0.12), Color("151515"))
		slot.set_meta("slot", i)

func _fuses() -> void:
	for spec in [["FuseCoinBox", COIN_BOX], ["FuseToolbox", TOOLBOX + Vector3(0.0, 0.3, 0.0)], ["FuseFixture", FIXTURE]]:
		var f := Blocks.visual(self, str(spec[0]), spec[1], Vector3(0.12, 0.22, 0.12), Color("e0b040"))
		f.name = str(spec[0])

func _dark_light() -> void:
	# moody practicals: no fill from the sky, only what is in the room
	_lamp("DimFill", Vector3(230.0, 5.0, -26.0), Color("ffb080"), 0.85, 40.0)
	_lamp("ExitGlow", Vector3(214.6, 2.8, -11.0), Color("ff2a1a"), 0.9, 6.0)
	var exit := Blocks.label(self, "EXIT", Vector3(214.6, 2.75, -10.4), Color("ff3a2a"), 40)
	exit.name = "ExitSign"
	exit.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	exit.rotation.y = PI
	exit.pixel_size = 0.008
	_lamp("CrtGlow", Vector3(245.0, 2.2, -26.6), Color("c6ff3d"), 1.1, 7.0)
	_lamp("BenchLamp", Vector3(244.6, 2.8, -24.2), Color("ffb36b"), 0.7, 5.0)
	_lamp("BreakerGlow", BREAKER + Vector3(1.4, 0.9, 0.0), Color("ffcf8a"), 0.45, 4.5)
	_lamp("ShaftPool2", Vector3(227.0, 0.6, -26.0), Color("ffcf8a"), 0.35, 4.0)
	_lamp("ShaftPool4", Vector3(239.0, 0.6, -26.0), Color("ffcf8a"), 0.35, 4.0)
	_lamp("CounterGlow", Vector3(218.0, 1.6, -16.4), Color("6a8cff"), 0.25, 4.0)

func _lamp(n: String, at: Vector3, c: Color, energy: float, r: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.position = at
	l.light_color = c
	l.light_energy = energy
	l.omni_range = r
	add_child(l)
	return l

## A dust sheet over a cabinet. The cabinet collision is unchanged.
func _cloth(body: Node3D) -> void:
	Blocks.visual(body, "Cloth", Vector3(0.0, 0.12, 0.0), Vector3(1.42, 2.05, 1.32), SHEET)
	_cloth_fold(body)

func _cloth_fold(body: Node3D) -> void:
	var fold := Blocks.visual(body, "ClothFold", Vector3(0.0, -0.55, 0.62), Vector3(1.2, 0.55, 0.06), SHEET.darkened(0.12))
	fold.rotation.x = -0.35

static func _haze(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## Act I (1.1 / 1.1B / 1.3B, Nov 20 2026): the biggest cabinet under a dust sheet by the south wall (GRIND THE TERMS,
## Bailey lives in it; 1.1B pulls the sheet), and four ceiling fans (still until the power is on; act1.gd turns them).
func _act1() -> void:
	Blocks.solid(self, "BaileyCabinet", Vector3(226.5, 1.25, -12.2), Vector3(1.8, 2.5, 1.4), Color("2a2f5a"))
	var play := Node3D.new()
	play.name = "BaileyPlay"
	play.set_script(preload("res://scripts/story/bailey_cabinet.gd"))
	play.position = Vector3(226.5, 1.25, -12.2)
	add_child(play)
	var scr := Blocks.visual(self, "BaileyScreen", Vector3(226.5, 1.7, -12.93), Vector3(1.3, 0.9, 0.03), Color("0d1020"))
	scr.set_meta("bailey", true)
	var side := Label3D.new()
	side.name = "BaileySign"
	side.text = "GRIND THE TERMS"
	side.position = Vector3(226.5, 2.3, -12.94)
	side.rotation.y = PI
	side.modulate = Color("ffd24a")
	side.font_size = 40
	side.pixel_size = 0.008
	side.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(side)
	var sheet := Blocks.visual(self, "BaileySheet", Vector3(226.5, 1.3, -12.2), Vector3(2.0, 2.7, 1.6), SHEET)
	sheet.set_meta("sheet", true)
	_cloth_fold(sheet)
	for i in 4:
		var fan := Node3D.new()
		fan.name = "Fan%d" % i
		fan.position = Vector3(218.0 + i * 8.0, 5.6, -26.0)
		add_child(fan)
		Blocks.visual(fan, "BladeA", Vector3.ZERO, Vector3(2.4, 0.04, 0.3), Color("5a5048"))
		Blocks.visual(fan, "BladeB", Vector3.ZERO, Vector3(0.3, 0.04, 2.4), Color("5a5048"))
