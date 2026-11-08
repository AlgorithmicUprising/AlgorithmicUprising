extends Node

const BoundaryScript = preload("res://contracts/session_boundary.gd")
const SaveScript = preload("res://contracts/save_record.gd")

var boundary = BoundaryScript.new()
var save = SaveScript.new()
var world_sim: Node
var player: Node
var audio: Node
var session_panel: Node
var ui: Node
var dialogue_open := false
var paused := false
var speaker_id := ""
var dialogue_lines: PackedStringArray = []
var dialogue_index := 0
var session_serial := 0
var save_path := "user://au-open-world-save-v1.json"

func bind(world: Node, body: Node, audio_owner: Node, session: Node, announcer: Node) -> void:
	world_sim = world
	player = body
	audio = audio_owner
	session_panel = session
	ui = announcer
	if session_panel != null and "flow" in session_panel:
		session_panel.flow = self

func open_dialogue(id: String, speaker: String, lines: PackedStringArray) -> Dictionary:
	if boundary.phase != "world" or paused or dialogue_open:
		return {"ok": false, "reason": "busy"}
	if lines.is_empty():
		return {"ok": false, "reason": "lines"}
	dialogue_open = true
	speaker_id = id
	dialogue_lines = lines
	dialogue_index = 0
	player.input_enabled = false
	if ui != null and ui.has_method("show_dialogue"):
		ui.show_dialogue(speaker, lines[0])
	return {"ok": true}

func advance_dialogue() -> void:
	if not dialogue_open:
		return
	dialogue_index += 1
	if dialogue_index >= dialogue_lines.size():
		close_dialogue()
	elif ui != null and ui.has_method("show_dialogue_line"):
		ui.show_dialogue_line(dialogue_lines[dialogue_index])

func close_dialogue() -> void:
	if not dialogue_open:
		return
	dialogue_open = false
	save.note_meeting(speaker_id)
	player.input_enabled = true
	if ui != null and ui.has_method("hide_dialogue"):
		ui.hide_dialogue()
	persist()

func open_cabinet() -> Dictionary:
	if dialogue_open:
		return {"ok": false, "reason": "dialogue"}
	if paused:
		return {"ok": false, "reason": "paused"}
	session_serial += 1
	var id := "hq-cabinet-%03d" % session_serial
	var entered: Dictionary = boundary.enter_session(id)
	if not bool(entered.get("ok", false)):
		session_serial -= 1
		return entered
	if audio == null or not audio.handoff("world", "session"):
		boundary.force_reset()
		session_serial -= 1
		return {"ok": false, "reason": "audio"}
	player.input_enabled = false
	player.velocity = Vector3.ZERO
	player.grind = null
	world_sim.process_mode = Node.PROCESS_MODE_DISABLED
	if session_panel != null and session_panel.has_method("show_open"):
		session_panel.show_open()
	return {"ok": true, "session_id": id}

func finish_session(input_mode: String) -> Dictionary:
	return _close_session(true, input_mode)

func abort_session(input_mode: String) -> Dictionary:
	return _close_session(false, input_mode)

func set_paused(value: bool) -> Dictionary:
	if boundary.phase != "world":
		return {"ok": false, "reason": "session"}
	paused = value
	get_tree().paused = value
	if ui != null and ui.has_method("show_pause"):
		ui.show_pause(value)
	return {"ok": true}

func persist() -> void:
	save.save_user(save_path)

func _close_session(completed: bool, input_mode: String) -> Dictionary:
	if boundary.phase != "in_session":
		return {"ok": false, "reason": "no_session"}
	if not ["keyboard", "gamepad", "unknown", "mixed"].has(input_mode):
		input_mode = "unknown"
	var result := {
		"contract": "au.minigame_result",
		"contract_version": 1,
		"session_id": boundary.session_id,
		"game_id": "hq.placeholder_cabinet",
		"game_version": "0.1.0-greybox",
		"song_id": "",
		"chart_id": "",
		"chart_hash": "",
		"difficulty": "",
		"accuracy": null,
		"max_combo": 0,
		"judgements": {},
		"completed": completed,
		"aborted": not completed,
		"input_mode": input_mode,
		"score": 0,
		"integration": "placeholder_not_canvas",
		"note": "Placeholder cabinet session. Not the Punk Arcade Canvas runtime and not Bars per Watt.",
	}
	var exited: Dictionary = boundary.exit_session(result)
	if not bool(exited.get("ok", false)):
		return exited
	var handed := false
	if audio != null:
		handed = bool(audio.handoff("session", "world"))
	save.add_result(result)
	world_sim.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.input_enabled = true
	if session_panel != null and session_panel.has_method("hide_panel"):
		session_panel.hide_panel()
	persist()
	return {"ok": handed, "result": result}
