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

func _shell() -> void:
	Blocks.solid(self, "Floor", Vector3(230.0, -0.5, -26.0), Vector3(38.0, 1.0, 34.0), DUST, Vector3.ZERO, 0.04)
	Blocks.solid(self, "WallWest", Vector3(212.0, 3.0, -26.0), Vector3(0.5, 6.0, 34.0), WALL)
	Blocks.solid(self, "WallEast", Vector3(248.0, 3.0, -26.0), Vector3(0.5, 6.0, 34.0), WALL)
	Blocks.solid(self, "WallNorth", Vector3(230.0, 3.0, -42.0), Vector3(36.5, 6.0, 0.5), WALL)
	Blocks.solid(self, "WallSouth", Vector3(230.0, 3.0, -10.0), Vector3(36.5, 6.0, 0.5), WALL)
	# the roof: solar panels, a few broken (light shafts come through those)
	for i in 6:
		var x := 215.0 + i * 6.0
		if i == 2 or i == 4:
			Blocks.visual(self, "LightShaft%d" % i, Vector3(x, 3.0, -26.0), Vector3(1.6, 6.0, 1.2), Color(1.0, 0.86, 0.6, 0.18))
			continue
		Blocks.visual(self, "RoofPanel%d" % i, Vector3(x, 6.1, -26.0), Vector3(6.0, 0.2, 34.0), Color("1d2733"))
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
		var cab := Blocks.solid(self, "Cabinet%d" % i, Vector3(x, 0.95, -40.6), Vector3(1.3, 1.9, 1.2), SHEET)
		cab.set_meta("sheet", true)
		var glow := Blocks.visual(self, "CabinetGlow%d" % i, Vector3(x, 1.3, -39.98), Vector3(0.9, 0.7, 0.02), Color("101010"))
		glow.set_meta("glow", true)
	Blocks.visual(self, "CoinBoxDoor", Vector3(230.0, 0.6, -39.9), Vector3(0.5, 0.35, 0.05), Color("8a7a52"))
	# a second row mid-floor (west half), out of the walking lanes
	for i in 3:
		Blocks.solid(self, "CabinetMid%d" % i, Vector3(222.0 + i * 3.0, 0.95, -30.5), Vector3(1.3, 1.9, 1.2), SHEET)

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
	Blocks.solid(self, "TallCabinet", Vector3(236.0, 0.8, -12.6), Vector3(2.0, 1.6, 1.6), SHEET)
	Blocks.add_slope(self, "ToppledCabinet", Vector3(236.0, 0.0, -18.6), Vector3(236.0, 1.6, -13.4), 1.6, Color("8f887c"))
	Blocks.visual(self, "LightFixture", FIXTURE + Vector3(0.0, 0.45, 0.0), Vector3(1.6, 0.12, 0.4), Color("9a9a90"))
	Blocks.visual(self, "FixtureChain", FIXTURE + Vector3(0.0, 1.6, 0.0), Vector3(0.04, 2.2, 0.04), Color("5a5a52"))

func _breaker() -> void:
	Blocks.visual(self, "BreakerBox", BREAKER, Vector3(0.3, 1.2, 0.9), Color("6e5a3a"))
	var lever := Blocks.visual(self, "BreakerLever", BREAKER + Vector3(0.22, -0.25, 0.0), Vector3(0.12, 0.5, 0.12), Color("a33"))
	lever.name = "BreakerLever"
	var l := Blocks.label(self, "DO NOT RECONNECT – IT TALKS.", BREAKER + Vector3(0.25, 0.85, 0.0), Color("d8d0b0"), 22)
	l.name = "BreakerLabel"
	l.rotation.y = -PI * 0.5
	for i in 3:
		var slot := Blocks.visual(self, "FuseSlot%d" % i, BREAKER + Vector3(0.18, 0.25, -0.25 + i * 0.25), Vector3(0.06, 0.18, 0.12), Color("151515"))
		slot.set_meta("slot", i)

func _fuses() -> void:
	for spec in [["FuseCoinBox", COIN_BOX], ["FuseToolbox", TOOLBOX + Vector3(0.0, 0.3, 0.0)], ["FuseFixture", FIXTURE]]:
		var f := Blocks.visual(self, str(spec[0]), spec[1], Vector3(0.12, 0.22, 0.12), Color("e0b040"))
		f.name = str(spec[0])

func _dark_light() -> void:
	var l := OmniLight3D.new()
	l.name = "DimFill"
	l.position = Vector3(230.0, 5.0, -26.0)
	l.light_color = Color("ffcf8a")
	l.light_energy = 0.35
	l.omni_range = 30.0
	add_child(l)
