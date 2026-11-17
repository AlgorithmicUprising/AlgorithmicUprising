extends Area3D
## Grindable edge (LOCAL grind round, Nov 16 2026). The node origin is the middle of the riding line at its top (where the
## trucks sit); its local +X is the rail axis. kind "rail" draws a round flat bar on two legs in the park's metal trim;
## kind "ledge" draws nothing (it marks the metal edge of a pad / ledge that already has its own mesh and collision).
## `drop` lowers the far (+X) end by that many metres (a down rail); 0 = flat. The rail has no collision: the player
## controller owns lock-on, the grind and the bails (player_controller.gd `_try_grind()` / `_step_grind()`).

const Blocks = preload("res://scripts/world_blocks.gd")
const TRIM := Color("e7eef2")       # same metal as the quarter-pipe coping and the pad edges
const LEG := Color("5f4f74")        # legs / feet in the park's dark purple face colour

@export var length := 8.0
@export var kind := "rail"          # "rail" / "ledge"
@export var drop := 0.0
## Rolling resistance on the grind (m/s^2). Waxed metal on a round bar is slippery; a ledge edge drags a little more.
@export var friction := -1.0
## Sideways catch distance (m) from the axis. Beside a ledge the capsule (0.35 m) cannot get closer than ~0.4 m, so ledges catch wider.
@export var catch_r := -1.0
## Kept for older callers; the grind keeps the approach speed now.
@export var speed := 8.0
var direction := Vector3.RIGHT
var mount_y := 0.0

func _ready() -> void:
	monitoring = false
	monitorable = false
	add_to_group("grind_rail")
	direction = global_transform.basis.x.normalized()
	if direction.length() < 0.1:
		direction = Vector3.RIGHT
	mount_y = global_position.y
	if friction < 0.0:
		friction = 0.55 if kind == "rail" else 0.9
	if catch_r < 0.0:
		catch_r = 0.32 if kind == "rail" else 0.5
	set_meta("park_piece", "grind_" + kind)
	if kind == "rail":
		_build_rail()

## Flat bar: 5 cm round tube, square legs 0.45 m in from each end, flat base plates on the ground (y = 0 under the rail).
func _build_rail() -> void:
	var slope := atan2(drop, length)
	var tube := MeshInstance3D.new()
	tube.name = "Tube"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.025
	cyl.height = sqrt(length * length + drop * drop)
	cyl.radial_segments = 12
	tube.mesh = cyl
	tube.position = Vector3(0, -0.025, 0)
	tube.rotation = Vector3(0, 0, PI * 0.5 - slope)
	tube.material_override = Blocks.cel(TRIM, 3.0, 0.08)
	add_child(tube)
	for i in 2:
		var x := (-1.0 if i == 0 else 1.0) * (length * 0.5 - 0.45)
		var top := top_local_y(x + length * 0.5) - 0.04
		var ground := -global_position.y
		var leg := MeshInstance3D.new()
		leg.name = "Leg%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(0.05, maxf(top - ground, 0.02), 0.05)
		leg.mesh = box
		leg.position = Vector3(x, (top + ground) * 0.5, 0)
		leg.material_override = Blocks.cel(LEG, 3.0, 0.1)
		add_child(leg)
		var foot := MeshInstance3D.new()
		foot.name = "Foot%d" % i
		var plate := BoxMesh.new()
		plate.size = Vector3(0.22, 0.03, 0.42)
		foot.mesh = plate
		foot.position = Vector3(x, ground + 0.015, 0)
		foot.material_override = Blocks.cel(TRIM, 3.0, 0.08)
		add_child(foot)

## Height of the riding line above the node origin at `along` metres from the start (-X end).
func top_local_y(along: float) -> float:
	return -drop * clampf(along / maxf(length, 0.001), 0.0, 1.0) + drop * 0.5

func start_point() -> Vector3:
	return global_position - direction * (length * 0.5) + Vector3.UP * (drop * 0.5)

## World point on the riding line at `along` metres from the start (clamped to the rail).
func line_point(along: float) -> Vector3:
	var a := clampf(along, 0.0, length)
	var flat := global_position - direction * (length * 0.5) + direction * a
	return Vector3(flat.x, global_position.y + top_local_y(a), flat.z)

## Older API: 0..1 along the rail.
func point_at(along: float) -> Vector3:
	return line_point(length * clampf(along, 0.0, 1.0))

## Unit vector along the riding line (includes the slope of a down rail), start -> end.
func line_dir() -> Vector3:
	return (line_point(length) - line_point(0.0)).normalized()

## Where a world point sits relative to the rail: along (m from the start, horizontal), lateral (signed horizontal metres,
## + = the rail's local +Z side), above (m above the riding line at that point).
func locate(p: Vector3) -> Dictionary:
	var flat_dir := Vector3(direction.x, 0.0, direction.z).normalized()
	var side := Vector3(-flat_dir.z, 0.0, flat_dir.x)
	var s := global_position - direction * (length * 0.5)
	var d := Vector3(p.x - s.x, 0.0, p.z - s.z)
	var along := d.dot(flat_dir)
	return {"along": along, "lateral": d.dot(side), "above": p.y - (global_position.y + top_local_y(along)), "side": side}

## Older entry point (tests / callers that drive the rail directly): the player decides.
func try_attach(player: CharacterBody3D) -> bool:
	if player == null or not player.has_method("grind_check"):
		return false
	return player.grind_check(self) == "lock"
