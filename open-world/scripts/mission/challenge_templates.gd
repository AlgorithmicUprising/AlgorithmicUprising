extends RefCounted
## Mechanic templates. They score a run. They do not move the player or speak.
## Act I's story scripts still play the world. A challenge only says which events
## count and what a clear is worth.

const Schema = preload("res://scripts/mission/challenge_schema.gd")

static func points_for(data: Dictionary, key: String) -> int:
	var points = data.get("points", {})
	if typeof(points) == TYPE_DICTIONARY:
		return int((points as Dictionary).get(key, (points as Dictionary).get("clear", 0)))
	return int(points)

static func time_rank(clock_s: float, scoring: Dictionary) -> String:
	var par = scoring.get("par_s", {})
	if typeof(par) != TYPE_DICTIONARY:
		return ""
	var table: Dictionary = par
	if table.has("gold") and clock_s <= float(table.get("gold", 0.0)):
		return "gold"
	if table.has("silver") and clock_s <= float(table.get("silver", 0.0)):
		return "silver"
	if table.has("bronze") and clock_s <= float(table.get("bronze", 0.0)):
		return "bronze"
	return ""

static func chain_rank(peak: int, scoring: Dictionary) -> String:
	var steps = scoring.get("chain", {})
	if typeof(steps) != TYPE_DICTIONARY:
		return ""
	var table: Dictionary = steps
	var best := ""
	var best_n := -1
	for key in table.keys():
		var need := int(key)
		if peak >= need and need > best_n:
			best_n = need
			best = str(table[key])
	return best

static func known(mechanic: String) -> bool:
	return Schema.MECHANICS.has(mechanic)
