extends RefCounted
## Frost is a friction multiplier from data/surfaces.json. Headless. AU_TEST_ONLY=surfaces.

const JsonFile = preload("res://scripts/json_file.gd")
const Friction = preload("res://scripts/surface_friction.gd")

var t: Node

func run(host: Node) -> void:
	t = host
	Friction.reload()
	var data = JsonFile.read("res://data/surfaces.json")
	ok(str(data.get("open_call", "")).begins_with("OPEN"), "frost slip is marked as an open owner call")
	var rows: Dictionary = data.get("surfaces", {})
	var frost: Dictionary = rows.get("frost", {})
	ok(is_equal_approx(float(frost.get("friction_mult", 0)), 0.18) and is_equal_approx(Friction.of("frost"), 0.18), "frost friction is the data value")
	ok(is_equal_approx(Friction.of("asphalt"), 1.0) and is_equal_approx(Friction.of("nope"), 1.0), "asphalt and an unknown surface stay at 1")
	var patch := MeshInstance3D.new()
	patch.position = Vector3(4, 0.03, -2)
	patch.set_meta("surface_id", "frost")
	patch.set_meta("surface_half", Vector2(1.5, 1.0))
	patch.add_to_group("ride_surface")
	host.add_child(patch)
	ok(is_equal_approx(Friction.at(host.get_tree(), Vector3(4.2, 0.4, -2.1)), 0.18), "standing on the patch uses frost")
	ok(is_equal_approx(Friction.at(host.get_tree(), Vector3(8, 0.4, -2)), 1.0), "off the patch is asphalt")
	patch.queue_free()

func ok(cond: bool, name: String) -> void:
	t.expect(cond, "surface: " + name)
