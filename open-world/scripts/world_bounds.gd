extends RefCounted
## Playable footprint for the yard and the districts that sit off the edge of Glitchport.
##
## The fuses run (P.2 through Glass Row, then P.3 in the dark arcade) could leave the map: the plaza's
## north side is open beside the boutique, the yard/alley seam north and south of the fence gap has no
## floor once the district apron is removed, and the off-map arcade apron has no wall on the city side.
## Shells below close those edges. The player also keeps the last grounded in-bounds position and returns
## there if they drop through the kill plane or end up clear of every volume.

const Blocks = preload("res://scripts/world_blocks.gd")
const Palette = preload("res://scripts/palette.gd")

## Kill plane. The bowl floor sits near y = -3.3, so this is below every rideable surface.
const KILL_Y := -6.0
## How far (m) past every volume counts as out of the world. Inside this margin a curb is still "in".
const OUTSIDE_M := 2.5

# Rect2 is (x, z, width, depth). Each one is ground the player is allowed to stand on.
const VOLUMES: Array[Rect2] = [
	Rect2(-88.0, -88.0, 176.0, 196.0),   # yard, Rust Avenue, the south curb
	Rect2(68.0, 76.0, 70.0, 30.0),       # test district, east of Rust Avenue
	Rect2(76.0, 18.0, 56.0, 22.0),       # fence gap + Glass Row alley
	Rect2(124.0, -1.0, 58.0, 55.0),      # Glass Row plaza
	Rect2(208.0, -46.0, 44.0, 40.0),     # dark Solar Arcade (P.3)
	Rect2(264.0, -96.0, 92.0, 94.0),     # Stillwater Flats
	Rect2(364.0, -100.0, 94.0, 96.0),    # Cold Row
	Rect2(-420.0, -470.0, 110.0, 80.0),  # lit arcade interior, off-map
]

static func build(parent: Node) -> void:
	var curb := Color("6a5c52")
	var cap := Color("c4b4a4")
	# North and south of the 6 m run gap (z 26..32): the seam between the yard wall and the alley.
	Blocks.solid(parent, "SeamCurbNorth", Vector3(81.5, 1.2, 22.15), Vector3(3.4, 2.4, 8.3), curb)
	Blocks.solid(parent, "SeamCurbSouth", Vector3(81.5, 1.2, 35.1), Vector3(3.4, 2.4, 6.8), curb)
	# Plaza north edge, the two openings beside the boutique. This is the hole out of Glitchport.
	Blocks.solid(parent, "PlazaCurbNorthWest", Vector3(130.0, 1.25, 0.4), Vector3(8.6, 2.5, 0.9), curb)
	Blocks.solid(parent, "PlazaCurbNorthEast", Vector3(168.2, 1.25, 0.4), Vector3(20.6, 2.5, 0.9), curb)
	Blocks.visual(parent, "PlazaCurbCapWest", Vector3(130.0, 2.55, 0.4), Vector3(8.6, 0.12, 0.9), cap)
	Blocks.visual(parent, "PlazaCurbCapEast", Vector3(168.2, 2.55, 0.4), Vector3(20.6, 0.12, 0.9), cap)
	var edge := Blocks.label(parent, "CITY EDGE", Vector3(168.2, 3.15, 0.4), Palette.LABEL, 28)
	edge.name = "CityEdgeLabel"
	# South and east ends of the plaza. The built south wall is only 1.2 m, low enough to pop over.
	Blocks.solid(parent, "PlazaCurbSouth", Vector3(152.0, 1.6, 50.9), Vector3(54.0, 3.2, 0.9), curb)
	Blocks.solid(parent, "PlazaCurbEast", Vector3(178.9, 1.6, 25.0), Vector3(0.8, 3.2, 52.0), curb)
	# Dark arcade: a closed shell just outside the room, so clipping a wall still lands on something.
	# The floor sits 0.25 m under the district floor so the two don't fight.
	Blocks.solid(parent, "ArcadeShellFloor", Vector3(230.0, -0.75, -26.0), Vector3(44.0, 1.0, 40.0), Color("3a332e"), Vector3.ZERO, 0.04)
	var shell := Color("2a2624")
	Blocks.solid(parent, "ArcadeShellWest", Vector3(209.0, 1.7, -26.0), Vector3(0.8, 3.4, 40.0), shell)
	Blocks.solid(parent, "ArcadeShellEast", Vector3(251.0, 1.7, -26.0), Vector3(0.8, 3.4, 40.0), shell)
	Blocks.solid(parent, "ArcadeShellNorth", Vector3(230.0, 1.7, -45.4), Vector3(43.0, 3.4, 0.8), shell)
	Blocks.solid(parent, "ArcadeShellSouth", Vector3(230.0, 1.7, -6.6), Vector3(43.0, 3.4, 0.8), shell)

## Metres from the xz point to the nearest playable volume. 0 when inside one.
static func clearance(point: Vector3) -> float:
	var q := Vector2(point.x, point.z)
	var best := 1.0e9
	for rect in VOLUMES:
		if rect.has_point(q):
			return 0.0
		var cx := clampf(q.x, rect.position.x, rect.end.x)
		var cz := clampf(q.y, rect.position.y, rect.end.y)
		best = minf(best, q.distance_to(Vector2(cx, cz)))
	return best

static func outside(point: Vector3) -> bool:
	return clearance(point) > OUTSIDE_M

## Grounded, above the bowl, and not past the curb. Safe to remember as a return point.
static func is_safe(player) -> bool:
	var p: Vector3 = player.global_position
	if p.y < -4.2 or outside(p):
		return false
	if bool(player.get("pipe_air")):
		return false
	if str(player.get("ramp_mode")) != "":
		return true
	if player.get("grind") != null:
		return true
	if str(player.get("qp_state")) != "":
		return true
	return player.is_on_floor()
