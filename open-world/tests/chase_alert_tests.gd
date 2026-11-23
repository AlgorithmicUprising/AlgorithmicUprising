extends RefCounted
## Spraying one chase drone calls the others. Headless. AU_TEST_ONLY=chase runs it alone.

const JsonFile = preload("res://scripts/json_file.gd")
const Spray = preload("res://scripts/spray.gd")

var t: Node

func run(host: Node) -> void:
	t = host
	var data = JsonFile.read("res://data/missions/p2_run.json")
	var alert: Dictionary = data.get("drones", {}).get("spray_alert", {})
	ok(float(alert.get("disable_s", 0)) == Spray.DISABLE_S, "spray alert uses the existing 8 s disable")
	ok(float(alert.get("alert_radius", 0)) == 22.0 and float(alert.get("investigate_s", 0)) == 3.5 and float(alert.get("tracking_s", 0)) == 6.0, "alert radius, investigate time and tracking time are data")
	var parent := Node3D.new()
	host.add_child(parent)
	var player := Node3D.new()
	parent.add_child(player)
	player.global_position = Vector3(0, 0.5, 0)
	var chase = load("res://scripts/story/chase.gd").new()
	parent.add_child(chase)
	chase.setup({"altitude": 3.4, "search_speed": 2.5, "spray_alert": alert}, player, parent)
	chase.begin([[0.0, 0.0], [6.0, 0.0], [40.0, 0.0]], true)
	var near: Dictionary = chase.drones[1]
	var far: Dictionary = chase.drones[2]
	var down: Dictionary = chase.drones[0]
	down.node.global_position = Vector3(0, 3.4, 0)
	near.node.global_position = Vector3(6, 3.4, 0)
	far.node.global_position = Vector3(40, 3.4, 0)
	down.node.set_meta("spray_left", Spray.DISABLE_S)
	chase.tick(0.05)
	ok(str(near.get("mode", "")) == "investigate" and str(far.get("mode", "")) == "", "a drone inside the radius investigates; one outside does not")
	var before: float = near.node.global_position.x
	chase.tick(0.5)
	ok(near.node.global_position.x < before - 0.5, "the investigator moves toward the downed drone")
	far["active"] = false
	chase.tick(float(alert.get("investigate_s", 3.5)))
	ok(str(near.get("mode", "")) == "tracking", "after the investigate time it scans")
	near.node.global_position = Vector3(8, 3.4, 0)
	near.node.look_at(Vector3(0, 0.5, 0), Vector3.UP)
	near["mode"] = "tracking"
	near["mode_left"] = 5.0
	near["scan_acc"] = 0.99
	player.global_position = Vector3(0, 0.5, 0)
	chase.tick(0.02)
	ok(str(near.get("mode", "")) == "", "a scan that sees him sends that drone back to the chase")
	_miss(chase, near, player, alert)
	parent.queue_free()

func _miss(chase, near: Dictionary, player: Node3D, alert: Dictionary) -> void:
	near["mode"] = "tracking"
	near["mode_left"] = 0.2
	near["focus"] = Vector3(8, 0, 0)
	near["scan_acc"] = 0.0
	near.node.global_position = Vector3(8, 3.4, 0)
	near.node.look_at(Vector3(8, 3.4, 10), Vector3.UP)
	player.global_position = Vector3(0, 0.5, 40)
	chase.tick(0.05)
	ok(str(near.get("mode", "")) == "tracking", "a scan aimed away does not find him")
	chase.tick(0.3)
	ok(str(near.get("mode", "")) == "", "when tracking runs out it stops searching")

func ok(cond: bool, name: String) -> void:
	t.expect(cond, "chase: " + name)
