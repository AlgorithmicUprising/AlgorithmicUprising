extends RefCounted

const Blocks = preload("res://scripts/world_blocks.gd")
const Palette = preload("res://scripts/palette.gd")
const Pieces = preload("res://assets/library/skate_park/park_pieces.gd")
const ArcadeExterior = preload("res://scripts/arcade_exterior.gd")

# Wall centers sit on a 160 m square. The proposed map was 200 m and is not final.
# 160 m keeps the labeled 2 m pipe and 3 m bowl readable at a 9 m/s skate speed.
const HALF := 80.0
const WALL_T := 1.6
const WALL_H := 3.6
const GATE_X0 := 46.0
const GATE_X1 := 58.0

static func zone_at(point: Vector3) -> String:
	# Arcade Phase 1 (LOCAL): the separate interior scene sits far off-map (arcade_door.gd INTERIOR_ORIGIN).
	if point.x < -300.0 and point.z < -300.0:
		return "ARCADE"
	if point.z > HALF + 0.2:
		return "RUST AVENUE"
	if abs(point.x) > HALF + 2.0 or point.z < -HALF - 2.0:
		return "OUTSIDE"
	if point.x > 40.0 and point.z > 48.0:
		return "GATE"
	if point.x < -36.0 and point.z > 30.0 and point.z < 68.0:
		return "BOWL"
	if point.x < -32.0 and point.z < 18.0 and point.z > -42.0:
		return "SKATE YARD"
	if point.x < -32.0 and point.z <= -42.0:
		return "WORKSHOP"
	if point.z <= -46.0 and point.x >= -28.0:
		return "RESISTANCE"
	if point.x > 2.0 and point.z < -2.0 and point.z > -46.0:
		return "ARCADE"
	if point.z > 8.0:
		return "PLAZA"
	return "YARD"

static func build(parent: Node) -> void:
	_ground(parent)
	_bowl(parent)
	_walls(parent)
	_outside(parent)
	_workshop(parent)
	_rooms(parent)
	_warehouse(parent)
	_docks(parent)
	_skate(parent)
	_plaza(parent)
	_gate(parent)
	_plants(parent)
	_marks(parent)

static func _ground(parent: Node) -> void:
	# Slabs stop at the crest of each bowl bank. Corner pads fill the rest so the cut has no open void.
	_slab(parent, "GroundNorth", 0.0, -28.5, 158.0, 101.0, Palette.CONCRETE)
	_slab(parent, "GroundSouth", 0.0, 79.0, 158.0, 2.0, Palette.CONCRETE)
	_slab(parent, "GroundWest", -76.5, 50.0, 5.0, 56.0, Palette.CONCRETE)
	_slab(parent, "GroundEast", 29.5, 50.0, 99.0, 56.0, Palette.CONCRETE_DARK)
	_slab(parent, "BowlCornerNW", -64.0, 29.0, 24.0, 18.0, Palette.CONCRETE)
	_slab(parent, "BowlCornerNE", -30.0, 29.0, 24.0, 18.0, Palette.CONCRETE_DARK)
	_slab(parent, "BowlCornerSW", -64.0, 71.0, 24.0, 18.0, Palette.CONCRETE)
	_slab(parent, "BowlCornerSE", -30.0, 71.0, 24.0, 18.0, Palette.CONCRETE_DARK)
	Blocks.visual(parent, "ConcretePatchA", Vector3(-8, 0.03, 24), Vector3(14, 0.04, 9), Color("b5927c"))
	Blocks.visual(parent, "ConcretePatchB", Vector3(22, 0.03, 40), Vector3(10, 0.04, 16), Color("d0b09a"))
	Blocks.visual(parent, "ConcretePatchC", Vector3(-24, 0.03, -8), Vector3(12, 0.04, 8), Color("9a7468"))

static func _slab(parent: Node, node_name: String, x: float, z: float, sx: float, sz: float, color: Color) -> void:
	Blocks.solid(parent, node_name, Vector3(x, -0.5, z), Vector3(sx, 1.0, sz), color, Vector3.ZERO, 0.04)

static func _bowl(parent: Node) -> void:
	Blocks.solid(parent, "BowlFloor", Vector3(-48, -3.2, 50), Vector3(16, 0.4, 24), Palette.BOWL)
	Blocks.add_slope(parent, "BowlWest", Vector3(-56, -3.0, 50), Vector3(-77, 0.45, 50), 28.0, Palette.BOWL)
	Blocks.add_slope(parent, "BowlEast", Vector3(-40, -3.0, 50), Vector3(-19, 0.45, 50), 28.0, Palette.BOWL)
	Blocks.add_slope(parent, "BowlNorth", Vector3(-48, -3.0, 38), Vector3(-48, 0.45, 19), 20.0, Palette.BOWL)
	Blocks.add_slope(parent, "BowlSouth", Vector3(-48, -3.0, 62), Vector3(-48, 0.45, 81), 20.0, Palette.BOWL)
	Blocks.label(parent, "BOWL", Vector3(-48, 1.6, 50), Palette.LABEL_COOL, 48)

static func _walls(parent: Node) -> void:
	var y := WALL_H * 0.5
	Blocks.solid(parent, "YardWallNorth", Vector3(0, y, -HALF), Vector3(HALF * 2.0 + WALL_T, WALL_H, WALL_T), Palette.PARK_WALL)
	Blocks.solid(parent, "YardWallEast", Vector3(HALF, y, 0), Vector3(WALL_T, WALL_H, HALF * 2.0), Palette.PARK_WALL)
	Blocks.solid(parent, "YardWallWest", Vector3(-HALF, y, 0), Vector3(WALL_T, WALL_H, HALF * 2.0), Palette.PARK_WALL)
	var south_left := ( -HALF + GATE_X0 ) * 0.5
	Blocks.solid(parent, "YardWallSouthWest", Vector3(south_left, y, HALF), Vector3(GATE_X0 + HALF, WALL_H, WALL_T), Palette.PARK_WALL)
	var south_right := (GATE_X1 + HALF) * 0.5
	Blocks.solid(parent, "YardWallSouthEast", Vector3(south_right, y, HALF), Vector3(HALF - GATE_X1, WALL_H, WALL_T), Palette.PARK_WALL)
	Blocks.solid(parent, "GatePostWest", Vector3(GATE_X0 - 0.6, 2.2, HALF), Vector3(1.2, 4.4, 1.8), Palette.WAREHOUSE_RUST)
	Blocks.solid(parent, "GatePostEast", Vector3(GATE_X1 + 0.6, 2.2, HALF), Vector3(1.2, 4.4, 1.8), Palette.WAREHOUSE_RUST)
	var gate := Blocks.label(parent, "MAIN GATE", Vector3((GATE_X0 + GATE_X1) * 0.5, 4.6, HALF - 1.5), Palette.LABEL, 42)
	gate.name = "MainGate"

static func _outside(parent: Node) -> void:
	Blocks.solid(parent, "RustAvenue", Vector3(52, -0.5, 90), Vector3(36, 1.0, 18), Color("8d6f62"))
	Blocks.solid(parent, "FutureCurb", Vector3(52, 1.1, 100), Vector3(40, 2.2, 1.2), Palette.FENCE)
	Blocks.label(parent, "RUST AVENUE", Vector3(52, 2.4, 86), Palette.LABEL, 36)
	Blocks.label(parent, "FUTURE SECTIONS", Vector3(52, 3.2, 100), Palette.LABEL_COOL, 32)
	for i in 5:
		var height := 16.0 + float(i) * 6.0
		var tone := Palette.SKYLINE_TALL if i % 2 == 0 else Palette.SKYLINE
		if i == 1:
			tone = Palette.SKYLINE_COOL
		elif i == 3:
			tone = Palette.SKYLINE_MAGENTA
		Blocks.visual(parent, "FutureSkyline%d" % i, Vector3(108.0 + float(i) * 14.0, height * 0.5, -40.0 + float(i) * 22.0), Vector3(10, height, 12), tone)
	Blocks.visual(parent, "FutureFactoryA", Vector3(-112, 6, -20), Vector3(16, 12, 28), Palette.FACTORY)
	Blocks.visual(parent, "FutureFactoryB", Vector3(-118, 4, 30), Vector3(14, 8, 22), Palette.FACTORY)
	for i in 8:
		Blocks.visual(parent, "RailColumn%d" % i, Vector3(-70.0 + float(i) * 20.0, 4.0, -96), Vector3(1.2, 8.0, 1.2), Color("3a3540"))
	Blocks.visual(parent, "ElevatedRail", Vector3(0, 8.2, -96), Vector3(160, 1.2, 3.2), Color("2a2830"))
	Blocks.label(parent, "FUTURE RAIL CUT", Vector3(0, 10.2, -96), Palette.LABEL_COOL, 40)
	Blocks.label(parent, "FUTURE FACTORIES", Vector3(-112, 13, 0), Palette.LABEL, 36)
	Blocks.label(parent, "FUTURE SHOPS", Vector3(120, 16, 10), Palette.LABEL_COOL, 36)

static func _workshop(parent: Node) -> void:
	_shell(parent, "Workshop", -74.0, -40.0, -76.0, -52.0, 5.2, Palette.WORKSHOP, -57.0, -46.0)
	Blocks.visual(parent, "WorkshopFloor", Vector3(-57, 0.04, -64), Vector3(32, 0.05, 22), Color("a86a45"))
	for i in 5:
		Blocks.solid(parent, "Battery%d" % i, Vector3(-70.0 + float(i) * 4.2, 0.45, -70), Vector3(2.4, 0.9, 1.4), Color("2bd67b"))
	Blocks.solid(parent, "WorkBench", Vector3(-48, 0.55, -70), Vector3(6, 1.1, 1.6), Color("5c4034"))
	for i in 8:
		Blocks.visual(parent, "ContainerRib%d" % i, Vector3(-71.0 + float(i) * 3.8, 2.6, -51.55), Vector3(0.16, 4.8, 0.06), Color("7a3424"))
	Blocks.label(parent, "WORKSHOP", Vector3(-57, 5.8, -58), Palette.LABEL, 48)

static func _rooms(parent: Node) -> void:
	_shell(parent, "ResistanceRooms", -18.0, 58.0, -76.0, -50.0, 5.6, Palette.ROOM, -1.0, 5.0)
	Blocks.visual(parent, "ResistanceFloor", Vector3(20, 0.04, -63), Vector3(72, 0.05, 22), Color("5a3148"))
	Blocks.solid(parent, "Bunks", Vector3(40, 0.45, -68), Vector3(10, 0.9, 3.2), Color("8d5b6e"))
	Blocks.solid(parent, "KitchenCounter", Vector3(48, 0.5, -58), Vector3(6, 1.0, 1.4), Color("c4896a"))
	Blocks.label(parent, "RESISTANCE", Vector3(20, 6.2, -63), Palette.LABEL, 48)
	var zero = load("res://scripts/zero_actor.gd").new()
	zero.name = "NPCZero"
	zero.npc_id = "zero"
	zero.display_name = "Zero"
	zero.position = Vector3(-6, 0, -62)
	parent.add_child(zero)

static func _warehouse(parent: Node) -> void:
	# Arcade Phase 1 (LOCAL): the greybox shell keeps its collision; arcade_exterior.gd draws the building.
	_shell(parent, "WarehouseArcade", 8.0, 70.0, -44.0, -8.0, 9.0, Palette.WAREHOUSE, 28.0, 36.0)
	_hide_meshes(parent.get_node("WarehouseArcade"))
	_hide_meshes(Blocks.solid(parent, "WarehouseBand", Vector3(39, 6.2, -8.4), Vector3(62, 1.4, 0.4), Palette.WAREHOUSE_RUST))
	_hide_meshes(Blocks.solid(parent, "RoofDeck", Vector3(42, 9.15, -28), Vector3(70, 0.3, 36), Palette.SOLAR))
	Blocks.add_slope(parent, "RoofStair", Vector3(74, 0.08, -6), Vector3(74, 9.1, -34), 4.0, Palette.RAMP)
	Blocks.solid(parent, "RoofRail", Vector3(76.2, 1.2, -20), Vector3(0.2, 0.9, 22), Palette.RAIL)
	# Replaces the old billboard "ARCADE" label, TEMP TAG, solar cells, coping, marquee bar and eave lamps.
	ArcadeExterior.build(parent)
	# Arcade Phase 2 (LOCAL): the old greybox floor, decoys and posters are gone; the room is the separate
	# interior scene. The HQ placeholder cabinet (same scene, same hooks) moves into it by the token counter.
	var door = parent.get_node("ArcadeDoor")
	var interior: Node3D = door.ensure_interior()
	var cabinet = load("res://scenes/cabinet.tscn").instantiate()
	cabinet.name = "Cabinet"
	cabinet.position = door.INTERIOR_ORIGIN + interior.HQ_CABINET_LOCAL
	cabinet.ready.connect(_hide_meshes.bind(cabinet), CONNECT_ONE_SHOT)
	parent.add_child(cabinet)

static func _hide_meshes(node: Node) -> void:
	for c in node.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).visible = false

static func _docks(parent: Node) -> void:
	for i in 3:
		Blocks.solid(parent, "Dock%d" % i, Vector3(-2.0 + float(i) * 5.0, 0.6, -24), Vector3(3.4, 1.2, 6.0), Color("8d6248"))
	Blocks.add_slope(parent, "DockRamp", Vector3(-12, 0.08, -24), Vector3(-4, 1.2, -24), 4.0, Palette.RAMP)
	Blocks.label(parent, "DOCKS +1.2m", Vector3(2, 2.4, -20), Palette.LABEL, 28)

static func _skate(parent: Node) -> void:
	var pipe: Node3D = load("res://assets/library/quarter_pipe/quarter_pipe.tscn").instantiate()
	pipe.name = "SkateQuarter"
	pipe.position = Vector3(-54, 0, -12)
	pipe.rotation.y = PI
	pipe.finish = "dark"
	pipe.closed_back = true
	parent.add_child(pipe)
	_quarter_steps(parent, pipe)
	Blocks.solid(parent, "Funbox", Vector3(-48, 0.45, -2), Vector3(4.2, 0.9, 4.2), Palette.FUNBOX)
	_park_expansion(parent)
	for i in 4:
		Blocks.visual(parent, "SkateLane%d" % i, Vector3(-46, 0.03, -18.0 + float(i) * 8.0), Vector3(22, 0.02, 0.7), Color("8d5a48"))
	var rail = load("res://scenes/grind_rail.tscn").instantiate()
	rail.name = "GrindRail"
	rail.length = 12.0
	rail.position = Vector3(-50, 1.05, 8)
	parent.add_child(rail)
	Blocks.label(parent, "SKATE YARD", Vector3(-52, 3.4, -6), Palette.LABEL, 48)
	Blocks.label(parent, "RAIL", Vector3(-50, 1.8, 8), Palette.LABEL, 28)

## Phase 4 (LOCAL): more to ride. The two teal block quarters at z -30 become a mini ramp of library quarter pipes (same
## places, 6 m flat bottom, rideable transitions with the kickturn); the funbox gets kickers on its east and west faces; a
## manual pad east of the main quarter; a bank against the west side of the yard. Everything stays inside the skate yard
## (x < -32, -50 < z < 18) on the concept map, clear of the rail line and the bowl.
static func _park_expansion(parent: Node) -> void:
	for spec in [["HalfPipeWest", Vector3(-50, 0, -30), PI], ["HalfPipeEast", Vector3(-44, 0, -30), 0.0]]:
		var q: Node3D = load("res://assets/library/quarter_pipe/quarter_pipe.tscn").instantiate()
		q.name = spec[0]
		q.position = spec[1]
		q.rotation.y = spec[2]
		q.width = 6.5
		q.finish = "dark"
		q.closed_back = true
		q.add_to_group("mini_ramp")
		parent.add_child(q)
	_quarter_steps(parent, parent.get_node("HalfPipeEast"), "MiniRampSteps")
	Pieces.wedge(parent, "FunboxKickerEast", Vector3(-43.4, 0, -2), PI, 2.5, 0.9, 4.2)
	Pieces.wedge(parent, "FunboxKickerWest", Vector3(-52.6, 0, -2), 0.0, 2.5, 0.9, 4.2)
	Pieces.pad(parent, "ManualPad", Vector3(-38, 0, -12), 0.0, Vector3(1.6, 0.3, 7.0))
	Pieces.wedge(parent, "Bank", Vector3(-63.5, 0, -1), PI, 3.0, 1.2, 9.0, 1.6)
	Blocks.label(parent, "MINI RAMP", Vector3(-47, 3.0, -30), Palette.LABEL, 30)

## Phase 2 (LOCAL blockout): steps up the north cheek of SkateQuarter onto its deck (1.58 m). Collision is one smooth slope
## (like PlazaStair), so walking and skating both climb it; the treads are visual only.
static func _quarter_steps(parent: Node, pipe: Node3D, prefix := "QuarterDeck") -> void:
	var lip_x: float = pipe.radius * sin(deg_to_rad(pipe.climb_deg))
	var top: float = pipe.radius * (1.0 - cos(deg_to_rad(pipe.climb_deg)))
	var half: float = pipe.width * 0.5
	var mid_local := Vector3(lip_x + pipe.deck_length * 0.5, 0.0, half)
	var mid: Vector3 = pipe.position + pipe.basis * mid_local
	var out: Vector3 = (pipe.basis * Vector3(0, 0, 1)).normalized()
	var run := 2.9
	var count := 8
	var high := Vector3(mid.x, top, mid.z) - out * 0.02
	var low := high + out * run
	low.y = 0.08
	Blocks.add_slope(parent, prefix + "Steps" if prefix == "QuarterDeck" else prefix, low, high, pipe.deck_length - 0.1, Palette.RAMP)
	for i in count:
		var f := (float(i) + 0.5) / float(count)
		var c := low.lerp(high, f)
		var y_top: float = c.y
		Blocks.visual(parent, ("QuarterStep%d" if prefix == "QuarterDeck" else prefix + "Tread%d") % i, Vector3(c.x, y_top * 0.5, c.z), Vector3(pipe.deck_length - 0.1, y_top, run / float(count)), Color("b9a090"))

static func _plaza(parent: Node) -> void:
	Blocks.solid(parent, "MuralWall", Vector3(6, 1.3, 20), Vector3(0.4, 2.6, 8), Palette.PARK_WALL)
	_temp_tag(parent, Vector3(6.3, 1.5, 20), 2.2, 6.0)
	Blocks.solid(parent, "BenchA", Vector3(-2, 0.28, 32), Vector3(2.2, 0.45, 0.6), Color("6b4a3a"))
	Blocks.solid(parent, "BenchB", Vector3(14, 0.28, 36), Vector3(2.2, 0.45, 0.6), Color("6b4a3a"))
	Blocks.solid(parent, "FoodCart", Vector3(22, 0.7, 30), Vector3(2.2, 1.4, 1.4), Color("e0a15a"))
	Blocks.visual(parent, "CartAwning", Vector3(22, 1.7, 30), Vector3(3.2, 0.12, 2.2), Palette.WAREHOUSE_RUST)
	Blocks.add_slope(parent, "PlazaStair", Vector3(12, 0.08, 12), Vector3(12, 1.26, 4), 3.2, Palette.RAMP)
	for i in 7:
		Blocks.visual(parent, "Step%d" % i, Vector3(15.2, 0.1 + float(i) * 0.18, 11.2 - float(i) * 1.15), Vector3(2.4, 0.16, 0.9), Color("b9a090"))
	Blocks.solid(parent, "Handrail", Vector3(16.6, 1.0, 8), Vector3(0.12, 0.7, 8), Palette.RAIL)
	Blocks.label(parent, "PLAZA", Vector3(10, 2.8, 34), Palette.LABEL, 42)

static func _gate(parent: Node) -> void:
	Blocks.solid(parent, "Lookout", Vector3(66, 1.6, 62), Vector3(3.2, 3.2, 3.2), Color("5c4038"))
	for i in 6:
		Blocks.visual(parent, "DronePost%d" % i, Vector3(62, 1.3, 56.0 + float(i) * 2.2), Vector3(0.18, 2.6, 0.18), Palette.SURVEILLANCE)
	Blocks.visual(parent, "DroneNet", Vector3(62, 2.2, 61.5), Vector3(0.08, 1.2, 12), Color("7fd0e0"))
	Blocks.label(parent, "GATE YARD", Vector3(60, 3.6, 64), Palette.LABEL, 36)
	for i in 3:
		Blocks.solid(parent, "WallRide%d" % i, Vector3(72, 1.3 + float(i % 2) * 1.1, 8.0 + float(i) * 8.0), Vector3(2.4, 2.4, 6.2), Palette.WAREHOUSE_RUST if i != 1 else Palette.WAREHOUSE)

static func _plants(parent: Node) -> void:
	for spot in [Vector3(-16, 0, 28), Vector3(28, 0, 44), Vector3(-30, 0, -46), Vector3(64, 0, 48), Vector3(-70, 0, 16)]:
		Blocks.solid(parent, "Planter", Vector3(spot.x, 0.35, spot.z), Vector3(1.8, 0.7, 1.8), Palette.PLANTER)
		Blocks.visual(parent, "Shrub", Vector3(spot.x, 1.15, spot.z), Vector3(1.1, 0.9, 1.1), Palette.PLANT)
		Blocks.visual(parent, "ShrubTop", Vector3(spot.x, 1.7, spot.z), Vector3(0.7, 0.5, 0.7), Color("2f6a38"))

static func _shell(parent: Node, node_name: String, x0: float, x1: float, z0: float, z1: float, height: float, color: Color, door_x0: float, door_x1: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	var y := height * 0.5
	var t := 0.6
	Blocks.solid(root, "Back", Vector3((x0 + x1) * 0.5, y, z0), Vector3(x1 - x0, height, t), color)
	Blocks.solid(root, "West", Vector3(x0, y, (z0 + z1) * 0.5), Vector3(t, height, z1 - z0), color)
	Blocks.solid(root, "East", Vector3(x1, y, (z0 + z1) * 0.5), Vector3(t, height, z1 - z0), color)
	if door_x0 > x0 + 1.0:
		Blocks.solid(root, "FrontWest", Vector3((x0 + door_x0) * 0.5, y, z1), Vector3(door_x0 - x0, height, t), color)
	if door_x1 < x1 - 1.0:
		Blocks.solid(root, "FrontEast", Vector3((door_x1 + x1) * 0.5, y, z1), Vector3(x1 - door_x1, height, t), color)
	Blocks.solid(root, "Lintel", Vector3((door_x0 + door_x1) * 0.5, height - 0.6, z1), Vector3(door_x1 - door_x0, 1.2, t), color)

static func _marks(parent: Node) -> void:
	# Original flat marks. Not copies of the reference painting, and not collision.
	_mark(parent, "ShopMark", Vector3(-63.0, 2.9, -51.58), Vector3(7.0, 2.4, 0.05))
	Blocks.visual(parent, "YardCrackA", Vector3(10, 0.02, 24), Vector3(6.5, 0.012, 0.05), Color("8a6858"))
	Blocks.visual(parent, "YardCrackB", Vector3(-8, 0.02, 14), Vector3(0.05, 0.012, 4.5), Color("8a6858"))

static func _mark(parent: Node, node_name: String, origin: Vector3, size: Vector3) -> void:
	Blocks.visual(parent, node_name + "A", origin, size, Color("e23e8c"))
	Blocks.visual(parent, node_name + "B", origin + Vector3(size.x * 0.12, 0.15, 0.02), size * Vector3(0.42, 0.38, 1.0), Color("3d7ec4"))
	Blocks.visual(parent, node_name + "C", origin + Vector3(-size.x * 0.18, -0.25, 0.03), size * Vector3(0.28, 0.46, 1.0), Color("e0a15a"))

static func _temp_tag(parent: Node, origin: Vector3, width: float, height: float) -> void:
	var colors := [Color("e23e8c"), Color("3d7ec4"), Color("e0a15a"), Color("2f6d66")]
	var stripe := width / 4.0
	for i in 4:
		Blocks.visual(parent, "TempStripe", origin + Vector3(0, 0, (float(i) - 1.5) * stripe), Vector3(0.08, height, stripe * 0.92), colors[i])
	Blocks.label(parent, "TEMP TAG", origin + Vector3(0.2, 0, 0), Palette.LABEL, 32)
