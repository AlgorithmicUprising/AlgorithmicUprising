extends RefCounted
## Ground friction from data/surfaces.json. A ride_surface node names a surface id.
## 1 is normal asphalt. Frost is lower so speed dies slower on the patch.
## OPEN: the frost number. This file is the only place it lives.

const DATA := "res://data/surfaces.json"

static var _loaded := false
static var _mult: Dictionary = {"asphalt": 1.0, "frost": 0.18}

static func load_data() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var rows = parsed.get("surfaces", {})
	if typeof(rows) != TYPE_DICTIONARY:
		return
	for id in rows:
		var spec = rows[id]
		if typeof(spec) != TYPE_DICTIONARY:
			continue
		_mult[str(id)] = clampf(float(spec.get("friction_mult", 1.0)), 0.02, 1.0)

static func reload() -> void:
	_loaded = false
	_mult = {"asphalt": 1.0, "frost": 0.18}
	load_data()

static func of(id: String) -> float:
	load_data()
	return float(_mult.get(id, 1.0))

## Smallest multiplier under this point. Overlapping patches use the slipperier one.
static func at(tree: SceneTree, pos: Vector3) -> float:
	load_data()
	if tree == null:
		return 1.0
	var slip := 1.0
	for node in tree.get_nodes_in_group("ride_surface"):
		if not (node is Node3D):
			continue
		var body := node as Node3D
		if not _covers(body, pos):
			continue
		slip = minf(slip, of(str(body.get_meta("surface_id", ""))))
	return slip

static func _covers(body: Node3D, pos: Vector3) -> bool:
	if absf(pos.y - body.global_position.y) > 1.6:
		return false
	var half: Vector2 = body.get_meta("surface_half", Vector2.ZERO)
	if half.x <= 0.0 or half.y <= 0.0:
		return false
	return absf(pos.x - body.global_position.x) <= half.x and absf(pos.z - body.global_position.z) <= half.y
