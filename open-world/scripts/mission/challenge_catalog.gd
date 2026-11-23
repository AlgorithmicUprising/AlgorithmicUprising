extends RefCounted
## Loads the in-repo challenge catalog. No network. A later database can hand
## the same Dictionaries to ChallengeRunner.load_challenge.

const JsonFile = preload("res://scripts/json_file.gd")
const Schema = preload("res://scripts/mission/challenge_schema.gd")

const CATALOG_PATH := "res://data/challenges/catalog.json"
const DIR := "res://data/challenges/"

static func load_all() -> Dictionary:
	var catalog = JsonFile.read(CATALOG_PATH)
	var checked := Schema.validate_catalog(catalog)
	if not bool(checked.get("ok", false)):
		return checked
	var out: Array[Dictionary] = []
	var ids: Dictionary = {}
	for name in (catalog as Dictionary).get("challenges", []):
		var path := DIR + str(name)
		var body = JsonFile.read(path)
		var valid := Schema.validate(body)
		if not bool(valid.get("ok", false)):
			return {"ok": false, "reason": str(valid.get("reason", "challenge")), "file": str(name)}
		var id := str((body as Dictionary).get("id", ""))
		if ids.has(id):
			return {"ok": false, "reason": "duplicate_id", "file": str(name)}
		ids[id] = true
		out.append((body as Dictionary).duplicate(true))
	return {"ok": true, "challenges": out}

static func by_id(rows: Array, id: String) -> Dictionary:
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and str((row as Dictionary).get("id", "")) == id:
			return row
	return {}
