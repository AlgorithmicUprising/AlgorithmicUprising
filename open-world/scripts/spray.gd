extends RefCounted
## Spray paint / attack. RT on a pad, left click once the mouse is captured.
## The color comes from data/spray_slot.json (one default). Hitting a drone in the
## cone sets its spray_left meta; patrol and chase code treat that as disabled.

const DATA := "res://data/spray_slot.json"
const RANGE := 14.0
const CONE := 0.62
const COOLDOWN_S := 0.38
const DISABLE_S := 8.0

static var _color := Color("c8ff3a")
static var _name := "Yard lime"
static var _slot := "default"
static var _loaded := false

static func load_slot() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_slot = str(parsed.get("slot", "default"))
	var colors = parsed.get("colors", {})
	if typeof(colors) != TYPE_DICTIONARY or not colors.has(_slot):
		return
	var spec: Dictionary = colors[_slot]
	_name = str(spec.get("name", _name))
	_color = Color(str(spec.get("hex", "c8ff3a")))

static func color() -> Color:
	load_slot()
	return _color

static func color_name() -> String:
	load_slot()
	return _name

static func slot_id() -> String:
	load_slot()
	return _slot

static func in_cone(origin: Vector3, dir: Vector3, point: Vector3, reach := RANGE) -> bool:
	var to := point - origin
	var dist := to.length()
	if dist < 0.2 or dist > reach:
		return false
	if dir.length() < 0.001:
		return false
	return dir.normalized().dot(to / dist) >= CONE

## Paint every spray_target in the cone. Returns how many were disabled.
static func fire(tree: SceneTree, origin: Vector3, dir: Vector3) -> int:
	load_slot()
	if tree == null:
		return 0
	var hits := 0
	for node in tree.get_nodes_in_group("spray_target"):
		if not (node is Node3D):
			continue
		var body := node as Node3D
		if not in_cone(origin, dir, body.global_position):
			continue
		body.set_meta("spray_left", DISABLE_S)
		body.set_meta("spray_color", _color)
		hits += 1
	return hits

static func left(node: Node) -> float:
	if node == null or not is_instance_valid(node):
		return 0.0
	return float(node.get_meta("spray_left", 0.0))

static func tick_disable(node: Node, delta: float) -> float:
	var remain := left(node)
	if remain <= 0.0:
		return 0.0
	remain = maxf(0.0, remain - delta)
	node.set_meta("spray_left", remain)
	return remain
