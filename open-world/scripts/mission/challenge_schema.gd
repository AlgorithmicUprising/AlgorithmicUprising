extends RefCounted
## Versioned challenge contract. A challenge is a plain Dictionary that JSON can
## round-trip, so a later database can store the same object. Godot Resources are
## not the source of truth.

const CONTRACT := "au.challenge"
const CATALOG_CONTRACT := "au.challenge_catalog"
const STATE_CONTRACT := "au.challenge_state"
const VERSION := 1
const MECHANICS: Array[String] = ["timed", "sneak", "combo", "camera-prep", "chase", "objectives"]

static func validate(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return _bad("type")
	var body: Dictionary = data
	if str(body.get("contract", "")) != CONTRACT:
		return _bad("contract")
	if int(body.get("contract_version", -1)) != VERSION:
		return _bad("version")
	var id := str(body.get("id", ""))
	if not _slug(id):
		return _bad("id")
	if str(body.get("title", "")) == "":
		return _bad("title")
	var mechanic := str(body.get("mechanic", ""))
	if not MECHANICS.has(mechanic):
		return _bad("mechanic")
	if str(body.get("district", "")) == "":
		return _bad("district")
	if typeof(body.get("spawn", null)) != TYPE_DICTIONARY:
		return _bad("spawn")
	var goals = body.get("goals", null)
	if typeof(goals) != TYPE_ARRAY or (goals as Array).is_empty() or (goals as Array).size() > 8:
		return _bad("goals")
	var seen: Dictionary = {}
	for goal in goals:
		var checked := _goal(goal)
		if not bool(checked.get("ok", false)):
			return checked
		var gid := str((goal as Dictionary).get("id", ""))
		if seen.has(gid):
			return _bad("duplicate_goal")
		seen[gid] = true
	if body.has("scoring") and typeof(body.get("scoring")) != TYPE_DICTIONARY:
		return _bad("scoring")
	var points = body.get("points", {})
	if typeof(points) != TYPE_DICTIONARY and typeof(points) != TYPE_INT and typeof(points) != TYPE_FLOAT:
		return _bad("points")
	if body.has("story"):
		var story = body.get("story")
		if typeof(story) != TYPE_ARRAY:
			return _bad("story")
		for line in story:
			if typeof(line) != TYPE_DICTIONARY or str((line as Dictionary).get("text", "")) == "":
				return _bad("story")
	if bool(body.get("placeholder", false)):
		var marked := false
		for line in body.get("story", []):
			if "PLACEHOLDER" in str((line as Dictionary).get("text", "")):
				marked = true
		if not marked:
			return _bad("placeholder")
	if body.has("source") and typeof(body.get("source")) != TYPE_DICTIONARY:
		return _bad("source")
	if body.has("parameters") and typeof(body.get("parameters")) != TYPE_DICTIONARY:
		return _bad("parameters")
	if body.has("reward"):
		var reward = body.get("reward")
		if typeof(reward) != TYPE_DICTIONARY:
			return _bad("reward")
		var spec: Dictionary = reward
		if str(spec.get("type", "")) == "" or str(spec.get("id", "")) == "":
			return _bad("reward")
	return {"ok": true}

static func validate_catalog(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return _bad("type")
	var body: Dictionary = data
	if str(body.get("contract", "")) != CATALOG_CONTRACT:
		return _bad("contract")
	if int(body.get("contract_version", -1)) != VERSION:
		return _bad("version")
	var files = body.get("challenges", null)
	if typeof(files) != TYPE_ARRAY or (files as Array).is_empty():
		return _bad("challenges")
	var seen: Dictionary = {}
	for name in files:
		var file := str(name)
		if file == "" or not file.ends_with(".json") or seen.has(file):
			return _bad("challenges")
		seen[file] = true
	return {"ok": true}

static func _goal(goal: Variant) -> Dictionary:
	if typeof(goal) != TYPE_DICTIONARY:
		return _bad("goal")
	var body: Dictionary = goal
	if not _slug(str(body.get("id", ""))):
		return _bad("goal")
	if str(body.get("event", "")) == "":
		return _bad("goal")
	if body.has("count") and int(body.get("count", 0)) < 1:
		return _bad("goal")
	if body.has("match") and typeof(body.get("match")) != TYPE_DICTIONARY:
		return _bad("goal")
	return {"ok": true}

static func _slug(text: String) -> bool:
	if text.length() < 1 or text.length() > 64:
		return false
	for i in text.length():
		var c := text.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 97 and c <= 122) or c == 45 or c == 95
		if not ok:
			return false
	return true

static func _bad(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
