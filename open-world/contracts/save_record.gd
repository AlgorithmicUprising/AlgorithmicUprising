extends RefCounted

const Result = preload("res://contracts/minigame_result.gd")
const CONTRACT := "au.world_save"
const VERSION := 1
const MAX_RESULTS := 20
const BANNED := ["viewport", "node", "texture", "renderer", "audio_context", "canvas"]

var met := {"zero": false, "fony": false}
var results: Array = []

func note_meeting(id: String) -> void:
	if met.has(id):
		met[id] = true

func add_result(result: Dictionary) -> Dictionary:
	var check: Dictionary = Result.validate(result)
	if not bool(check.get("ok", false)):
		return check
	results.append(result.duplicate(true))
	while results.size() > MAX_RESULTS:
		results.pop_front()
	return {"ok": true}

func to_dict() -> Dictionary:
	return {
		"contract": CONTRACT,
		"contract_version": VERSION,
		"slot": "local",
		"meetings": met.duplicate(true),
		"results": results.duplicate(true),
	}

func apply_dict(data: Dictionary) -> Dictionary:
	for key in BANNED:
		if data.has(key):
			return {"ok": false, "reason": "renderer_field", "key": key}
	if str(data.get("contract", "")) != CONTRACT or int(data.get("contract_version", -1)) != VERSION:
		return {"ok": false, "reason": "contract"}
	var meetings = data.get("meetings", null)
	if typeof(meetings) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "meetings"}
	met = {"zero": bool(meetings.get("zero", false)), "fony": bool(meetings.get("fony", false))}
	results.clear()
	var incoming = data.get("results", [])
	if typeof(incoming) != TYPE_ARRAY:
		return {"ok": false, "reason": "results"}
	for item in incoming:
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "result_type"}
		var added := add_result(item)
		if not bool(added.get("ok", false)):
			return added
	return {"ok": true}

func apply_json(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "not_object"}
	return apply_dict(parsed)

func save_user(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "write"}
	file.store_string(JSON.stringify(to_dict()))
	return {"ok": true}

func load_user(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "fresh": true}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "read"}
	return apply_json(file.get_as_text())
