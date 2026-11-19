extends Node3D
## M0 test district (Nov 18 2026). Ships in its own pack (build/web/districts/test_district.pck), never in index.pck.
## A small skateable space built in code like the yard: it starts at the district edge (local x = 0, the east end of
## Rust Avenue in the world) and runs east. Local frame: +X away from the HQ, ground at y = 0, Rust Avenue's lane
## centred on z = 0. Pieces: a long flat run-in, a bank with a deck (rides up and rolls off the back), a 0.30 m ledge
## along the lane and a flat bar, so district loading is tested with skating across the boundary.
## Uses only main-pack building blocks (world_blocks, park_pieces, grind_rail.tscn), so the pack itself stays tiny.

const Blocks = preload("res://scripts/world_blocks.gd")
const Pieces = preload("res://assets/library/skate_park/park_pieces.gd")
const Palette = preload("res://scripts/palette.gd")

const LENGTH := 64.0
const WIDTH := 24.0
const GROUND := Color("7f8f8a")       # cooler street concrete, so the edge reads as a new place
const LINE := Color("e2ff5c")         # acid lane paint

func _ready() -> void:
	set_meta("district_id", "test_district")
	# Floor: one slab from the edge to the end. Its top is y = 0 like Rust Avenue and the edge apron, so wheels never drop.
	Blocks.solid(self, "TestDistrictFloor", Vector3(LENGTH * 0.5, -0.5, 0.0), Vector3(LENGTH, 1.0, WIDTH), GROUND, Vector3.ZERO, 0.04)
	for i in 8:
		Blocks.visual(self, "LanePaint%d" % i, Vector3(4.0 + i * 7.0, 0.03, 0.0), Vector3(3.0, 0.03, 0.18), LINE)
	# A ledge: a 0.30 m pad along the lane, its south metal edge grindable (rail axis along +X).
	var pad := Pieces.pad(self, "TestLedgePad", Vector3(22.0, 0.0, 3.2), PI * 0.5, Vector3(1.4, 0.3, 10.0))
	var ledge = load("res://scenes/grind_rail.tscn").instantiate()
	ledge.name = "TestLedge"
	ledge.kind = "ledge"
	ledge.length = 10.0
	ledge.position = Vector3(22.0, float(pad.get_meta("height")), 3.2 - 0.68)
	add_child(ledge)
	# A flat bar on the other side of the lane.
	var bar = load("res://scenes/grind_rail.tscn").instantiate()
	bar.name = "TestFlatBar"
	bar.length = 8.0
	bar.position = Vector3(24.0, 0.30, -3.4)
	add_child(bar)
	# A bank straight down the lane: 3 m up to 1.2 m, a 4 m deck, then a back slope down (rideable both ways).
	Pieces.wedge(self, "TestBank", Vector3(38.0, 0.0, 0.0), 0.0, 3.0, 1.2, 10.0, 4.0)
	Pieces.wedge(self, "TestBankBack", Vector3(48.0, 0.0, 0.0), PI, 3.0, 1.2, 10.0, 0.0)
	# Edges so a skater does not roll off the world: low walls along the sides and the far end.
	Blocks.solid(self, "TestWallNorth", Vector3(LENGTH * 0.5, 0.6, -WIDTH * 0.5), Vector3(LENGTH, 1.2, 0.6), Palette.PARK_WALL)
	Blocks.solid(self, "TestWallSouth", Vector3(LENGTH * 0.5, 0.6, WIDTH * 0.5), Vector3(LENGTH, 1.2, 0.6), Palette.PARK_WALL)
	Blocks.solid(self, "TestWallEnd", Vector3(LENGTH, 1.2, 0.0), Vector3(0.6, 2.4, WIDTH), Palette.PARK_WALL)
	var sign := Blocks.label(self, "TEST DISTRICT · PACK LOADED", Vector3(10.0, 3.2, 0.0), LINE, 40)
	sign.name = "TestDistrictSign"
