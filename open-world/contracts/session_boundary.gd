extends RefCounted

const Result = preload("res://contracts/minigame_result.gd")

var phase := "world"
var world_sim_enabled := true
var input_owner := "world"
var audio_focus := "world"
var session_id := ""
var last_result := {}
var enter_count := 0

func enter_session(id: String) -> Dictionary:
	if phase != "world":
		return {"ok": false, "reason": "busy", "phase": phase}
	if id.strip_edges().is_empty():
		return {"ok": false, "reason": "session_id"}
	phase = "in_session"
	world_sim_enabled = false
	input_owner = "session"
	audio_focus = "session"
	session_id = id
	enter_count += 1
	return {"ok": true}

func exit_session(result: Dictionary) -> Dictionary:
	if phase != "in_session":
		return {"ok": false, "reason": "no_session"}
	var check: Dictionary = Result.validate(result)
	if not bool(check.get("ok", false)):
		return check
	if str(result.get("session_id", "")) != session_id:
		return {"ok": false, "reason": "session_mismatch"}
	last_result = result.duplicate(true)
	_restore("world")
	return {"ok": true}

func force_reset() -> void:
	_restore("world")

func _restore(next_focus: String) -> void:
	phase = "world"
	world_sim_enabled = true
	input_owner = next_focus
	audio_focus = next_focus
	session_id = ""
