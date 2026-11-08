extends RefCounted

const CONTRACT := "au.minigame_result"
const VERSION := 1
const INPUT_MODES := ["keyboard", "gamepad", "unknown", "mixed"]
const BANNED := ["viewport", "node", "texture", "renderer", "audio_context", "canvas", "packed_scene", "audiostream"]

static func validate(result) -> Dictionary:
	if typeof(result) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "not_object"}
	var banned := _banned_key(result)
	if banned != "":
		return {"ok": false, "reason": "renderer_field", "key": banned}
	if not _json_types(result):
		return {"ok": false, "reason": "non_json_value"}
	if str(result.get("contract", "")) != CONTRACT:
		return {"ok": false, "reason": "contract"}
	if int(result.get("contract_version", -1)) != VERSION:
		return {"ok": false, "reason": "version"}
	if not _text(result.get("session_id")):
		return {"ok": false, "reason": "session_id"}
	if not _text(result.get("game_id")):
		return {"ok": false, "reason": "game_id"}
	if not _text(result.get("game_version")):
		return {"ok": false, "reason": "game_version"}
	if typeof(result.get("completed")) != TYPE_BOOL or typeof(result.get("aborted")) != TYPE_BOOL:
		return {"ok": false, "reason": "flags"}
	if bool(result.get("completed")) == bool(result.get("aborted")):
		return {"ok": false, "reason": "completion_state"}
	if not str(result.get("input_mode", "")) in INPUT_MODES:
		return {"ok": false, "reason": "input_mode"}
	if not _int_like(result.get("score")):
		return {"ok": false, "reason": "score"}
	if result.has("judgements") and typeof(result.get("judgements")) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "judgements"}
	var blob := JSON.stringify(result).to_lower()
	if "drive.google.com" in blob or "://" in blob:
		return {"ok": false, "reason": "locator"}
	for ext in [".mp3", ".wav", ".ogg", ".flac", ".mid", ".wasm"]:
		if ext in blob:
			return {"ok": false, "reason": "embedded_media"}
	return {"ok": true}

static func _text(value) -> bool:
	return typeof(value) == TYPE_STRING and not str(value).is_empty()

static func _int_like(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_equal_approx(float(value), floor(float(value)))
	return false

static func _json_types(value) -> bool:
	var kind := typeof(value)
	if kind == TYPE_NIL or kind == TYPE_BOOL or kind == TYPE_INT or kind == TYPE_FLOAT or kind == TYPE_STRING:
		return true
	if kind == TYPE_ARRAY:
		for item in value:
			if not _json_types(item):
				return false
		return true
	if kind == TYPE_DICTIONARY:
		for key in value.keys():
			if typeof(key) != TYPE_STRING or not _json_types(value[key]):
				return false
		return true
	return false

static func _banned_key(value) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return ""
	for key in value.keys():
		if str(key).to_lower() in BANNED:
			return str(key)
		var nested := _banned_key(value[key]) if typeof(value[key]) == TYPE_DICTIONARY else ""
		if nested != "":
			return nested
	return ""
