extends Node

const Result = preload("res://contracts/minigame_result.gd")
const Catalog = preload("res://contracts/song_catalog.gd")
const SaveScript = preload("res://contracts/save_record.gd")
const BoundaryScript = preload("res://contracts/session_boundary.gd")
const Blocks = preload("res://scripts/world_blocks.gd")
const Palette = preload("res://scripts/palette.gd")
const JsonFile = preload("res://scripts/json_file.gd")

var fails: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_contracts()
	await _input_map()
	await _look()
	await _heading()
	await _invert()
	await _movement()
	await _grind()
	await _body()
	await _quarter()
	await _art_quarter()
	await _tricks()
	await _district()
	print("SUMMARY failed=", fails.size())
	for item in fails:
		print("FAIL ", item)
	get_tree().quit(1 if fails.size() else 0)

func expect(cond: bool, name: String) -> void:
	if cond:
		print("ok ", name)
	else:
		fails.append(name)
		print("not ok ", name)

func frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame

func _contracts() -> void:
	var story = JsonFile.read("res://data/story_working.json")
	expect(typeof(story) == TYPE_DICTIONARY, "story loads")
	expect(story.get("graphic_trauma_scene") == false, "no graphic trauma scene")
	expect(story.get("protagonist", {}).get("name") == null, "protagonist name unset")
	expect(story.get("protagonist", {}).get("appearance") == null, "protagonist appearance unset")
	var lines = story.get("npc_lines", {})
	var spoken := JSON.stringify(lines).to_lower()
	var clean := true
	for word in ["blood", "gore", "corpse", "torture"]:
		if word in spoken:
			clean = false
	expect(clean, "spoken lines stay non-graphic")
	expect(story.get("inspiration", {}).get("role") == "confirmed_inspiration_only", "inspiration marked as inspiration")
	var catalog_text := FileAccess.get_file_as_string("res://data/song_catalog.json")
	var catalog = Catalog.new()
	var loaded: Dictionary = catalog.load_text(catalog_text)
	expect(bool(loaded.get("ok", false)), "catalog accepts placeholders")
	var songs: Array = catalog.document.get("songs", [])
	expect(songs.size() == 2, "two catalog placeholders")
	var enabled := false
	var separate_chart := false
	for song in songs:
		if song.get("enabled", true):
			enabled = true
		if song.get("changed_arrangement_requires_separate_bars_per_watt_chart", false):
			separate_chart = true
		expect(catalog.request_playback(str(song.get("id"))).get("played") == false, "playback disabled " + str(song.get("id")))
	expect(not enabled, "catalog entries start disabled")
	expect(separate_chart, "changed arrangement requires its own chart")
	var forged: Dictionary = catalog.document.duplicate(true)
	forged["songs"][0]["enabled"] = true
	expect(catalog.validate(forged).size() > 0, "enabled song without media is rejected")
	var audio = get_node("/root/AudioOwner")
	expect(audio.ready_ok, "audio owner loaded catalog")
	expect(audio.holder == "world", "audio starts with the world")
	expect(not audio.claim("other"), "second audio claimant is refused")
	expect(audio.handoff("world", "session"), "audio can hand to a session")
	expect(not audio.handoff("world", "other"), "audio handoff requires the current holder")
	expect(audio.handoff("session", "world"), "audio returns to the world")
	expect(AudioServer.bus_count == 1, "one audio bus and no music bus")
	expect(audio.request_song("catalog-placeholder-world-original").get("reason") == "disabled", "owner refuses playback")
	_scan("res://")
	expect(true, "media scan finished")
	var good := _sample_result("keyboard", true)
	expect(bool(Result.validate(good).get("ok")), "result accepts placeholder")
	var bad_mode := good.duplicate(true)
	bad_mode["input_mode"] = "mouse"
	expect(Result.validate(bad_mode).get("reason") == "input_mode", "mouse is not a claimed input mode")
	var both := good.duplicate(true)
	both["aborted"] = true
	expect(Result.validate(both).get("reason") == "completion_state", "result cannot be both finished and aborted")
	var with_node := good.duplicate(true)
	with_node["node"] = self
	expect(Result.validate(with_node).get("ok") == false, "result rejects a node reference")
	var boundary = BoundaryScript.new()
	expect(boundary.enter_session("").get("ok") == false, "session id required")
	expect(boundary.enter_session("s1").get("ok"), "session enters")
	expect(boundary.enter_session("s2").get("reason") == "busy", "session refuses overlap")
	var mismatch := good.duplicate(true)
	mismatch["session_id"] = "other"
	expect(boundary.exit_session(mismatch).get("reason") == "session_mismatch", "session id must match")
	good["session_id"] = "s1"
	expect(boundary.exit_session(good).get("ok"), "session exits")
	expect(boundary.phase == "world" and boundary.input_owner == "world", "session restores world focus")
	for i in 10:
		expect(boundary.enter_session("loop-%d" % i).get("ok"), "reenter %d" % i)
		var loop_result := _sample_result("unknown", false)
		loop_result["session_id"] = "loop-%d" % i
		expect(boundary.exit_session(loop_result).get("ok"), "reexit %d" % i)
	expect(boundary.enter_count == 11 and boundary.phase == "world", "ten extra sessions do not stick")
	var save = SaveScript.new()
	save.note_meeting("zero")
	expect(save.add_result(good).get("ok"), "save accepts result")
	var round = SaveScript.new()
	expect(round.apply_json(JSON.stringify(save.to_dict())).get("ok"), "save json roundtrip")
	expect(round.met.get("zero") == true and round.results.size() == 1, "save keeps meeting and result")
	expect(round.apply_dict({"contract": "au.world_save", "contract_version": 1, "renderer": "gl", "meetings": {}, "results": []}).get("reason") == "renderer_field", "save rejects renderer field")

func _sample_result(mode: String, completed: bool) -> Dictionary:
	return {
		"contract": "au.minigame_result",
		"contract_version": 1,
		"session_id": "sample",
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
		"input_mode": mode,
		"score": 0,
		"integration": "placeholder_not_canvas",
		"note": "Placeholder cabinet session. Not the Punk Arcade Canvas runtime and not Bars per Watt.",
	}

func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_directories():
		if name.begins_with("."):
			continue
		_scan(path.path_join(name))
	for name in dir.get_files():
		var lower := name.to_lower()
		for ext in [".mp3", ".wav", ".ogg", ".flac", ".aac", ".m4a", ".opus", ".mid", ".midi", ".webm", ".mp4"]:
			if lower.ends_with(ext):
				expect(false, "forbidden media file " + path.path_join(name))

func _input_map() -> void:
	var down := InputEventKey.new()
	down.physical_keycode = KEY_W
	down.keycode = KEY_W
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	expect(Input.is_action_pressed("move_forward"), "keyboard W maps to move forward")
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	expect(not Input.is_action_pressed("move_forward"), "keyboard W release clears move forward")
	var nudge := InputEventJoypadMotion.new()
	nudge.axis = JOY_AXIS_LEFT_X
	nudge.axis_value = 0.1
	Input.parse_input_event(nudge)
	await get_tree().process_frame
	expect(not Input.is_action_pressed("move_right"), "gamepad axis inside deadzone is ignored")
	nudge.axis_value = 1.0
	Input.parse_input_event(nudge)
	await get_tree().process_frame
	expect(Input.is_action_pressed("move_right"), "gamepad left stick maps to move right")
	var jump := InputEventJoypadButton.new()
	jump.button_index = JOY_BUTTON_A
	jump.pressed = true
	Input.parse_input_event(jump)
	await get_tree().process_frame
	expect(Input.is_action_pressed("jump"), "gamepad A maps to jump")
	nudge.axis_value = 0.0
	Input.parse_input_event(nudge)
	jump.pressed = false
	Input.parse_input_event(jump)
	Input.action_release("move_right")
	Input.action_release("jump")
	await get_tree().process_frame

func _look() -> void:
	var camera_keys := 0
	for action in ["camera_left", "camera_right", "camera_up", "camera_down"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				camera_keys += 1
	expect(camera_keys == 0, "Q/E/R/F are not camera keys")
	var interact_e := false
	for event in InputMap.action_get_events("interact"):
		if event is InputEventKey and event.physical_keycode == KEY_E:
			interact_e = true
	expect(interact_e, "E is interact")
	var stick_look := false
	for event in InputMap.action_get_events("camera_right"):
		if event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_X:
			stick_look = true
	expect(stick_look, "right stick still looks")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(20)
	var player = main.player
	expect(not player.look_captured, "pointer starts unlocked")
	var yaw0: float = player.camera_yaw
	player.push_mouse_look(Vector2(400, 0))
	await frames(2)
	expect(is_equal_approx(player.camera_yaw, yaw0), "mouse does nothing before the click")
	main._capture_look()
	expect(player.look_captured, "click capture is allowed in the world")
	player.look_invert_y = true
	var pitch_before: float = player.camera_pitch
	player.push_mouse_look(Vector2(400, -30))
	await frames(2)
	var yaw1: float = player.camera_yaw
	expect(yaw1 < yaw0 - 0.8, "mouse right turns the view yaw=%s" % yaw1)
	expect(player.camera_pitch > pitch_before, "default invert: mouse up looks down pitch=%s" % player.camera_pitch)
	var key_e := InputEventKey.new()
	key_e.physical_keycode = KEY_E
	key_e.keycode = KEY_E
	key_e.pressed = true
	Input.parse_input_event(key_e)
	await frames(2)
	key_e.pressed = false
	Input.parse_input_event(key_e)
	await frames(1)
	expect(is_equal_approx(player.camera_yaw, yaw1), "E does not rotate the view")
	var key_q := InputEventKey.new()
	key_q.physical_keycode = KEY_Q
	key_q.keycode = KEY_Q
	key_q.pressed = true
	Input.parse_input_event(key_q)
	await frames(2)
	key_q.pressed = false
	Input.parse_input_event(key_q)
	expect(is_equal_approx(player.camera_yaw, yaw1), "Q does not rotate the view")
	var before: Vector3 = player.global_position
	var cam_forward: Vector3 = player.camera_flat_forward()
	var hold := InputEventKey.new()
	hold.physical_keycode = KEY_W
	hold.keycode = KEY_W
	hold.pressed = true
	Input.parse_input_event(hold)
	await frames(20)
	hold.pressed = false
	Input.parse_input_event(hold)
	await frames(2)
	var flat := Vector3(player.global_position.x - before.x, 0.0, player.global_position.z - before.z)
	var aligned: float = flat.normalized().dot(cam_forward) if flat.length() > 0.2 else 0.0
	var face := Vector3(-player.rig.global_transform.basis.z.x, 0.0, -player.rig.global_transform.basis.z.z).normalized()
	expect(flat.length() > 0.8 and aligned > 0.98, "W matches the camera basis moved=%s forward=%s align=%s" % [flat, cam_forward, aligned])
	expect(face.dot(flat.normalized()) > 0.98, "Fony faces the travel direction face=%s" % face)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	var yaw_stick: float = player.camera_yaw
	await frames(6)
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	expect(player.camera_yaw < yaw_stick - 0.05, "right stick turns the view without the mouse")
	var yaw_pause: float = player.camera_yaw
	main._release_look()
	main.flow.set_paused(true)
	player.push_mouse_look(Vector2(500, 0))
	await frames(3)
	expect(main.flow.paused and not player.look_captured and is_equal_approx(player.camera_yaw, yaw_pause), "pause releases the pointer and ignores look")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main._on_look_catch(click)
	expect(not main.flow.paused and player.look_captured, "click resumes and captures again")
	main.flow.set_paused(false)
	player.look_captured = true
	var zero = main.world_sim.get_node("NPCZero")
	player.global_position = zero.global_position + Vector3(1.1, 0, 0)
	zero.interact(main.flow)
	var yaw_talk: float = player.camera_yaw
	player.push_mouse_look(Vector2(400, 0))
	await frames(2)
	expect(main.flow.dialogue_open and not player.input_enabled and is_equal_approx(player.camera_yaw, yaw_talk), "dialogue blocks look and movement input")
	main.flow.close_dialogue()
	main.queue_free()
	await frames(2)

func _heading() -> void:
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(80, 1, 80), Palette.GROUND)
	var player = _player(host, Vector3(0, 0.4, 0))
	await frames(15)
	player.rotation.y = 1.05
	player.camera_yaw = 1.05
	player._update_camera(0.0)
	await frames(1)
	var formula := Vector3(-sin(player.camera_yaw), 0.0, -cos(player.camera_yaw))
	var rendered: Vector3 = player.camera_flat_forward()
	var mismatch: float = formula.dot(rendered)
	expect(mismatch < 0.7, "spawn body yaw offsets the rendered camera from pivot-only math dot=%s rendered=%s formula=%s" % [mismatch, rendered, formula])
	for sample in [0.0, 0.9, -1.4, 2.2]:
		player.camera_yaw = sample
		player._update_camera(0.0)
		player.velocity = Vector3.ZERO
		await frames(1)
		var skate_row: Dictionary = await _sample_heading(player, true, "W")
		expect(float(skate_row["align"]) > 0.98 and float(skate_row["face"]) > 0.98, "skate W matches camera at yaw %s %s" % [sample, skate_row])
		player.velocity = Vector3.ZERO
		var walk_row: Dictionary = await _sample_heading(player, false, "W")
		expect(float(walk_row["align"]) > 0.98 and float(walk_row["face"]) > 0.98, "walk W matches camera at yaw %s %s" % [sample, walk_row])
	player.camera_yaw = 0.4
	player._update_camera(0.0)
	player.velocity = Vector3.ZERO
	var back: Dictionary = await _sample_heading(player, true, "S")
	expect(float(back["align"]) < -0.98, "S is straight back from the camera %s" % back)
	player.velocity = Vector3.ZERO
	var strafe: Dictionary = await _sample_heading(player, true, "D")
	expect(float(strafe["right"]) > 0.98 and absf(float(strafe["align"])) < 0.08, "D strafes without a forward component %s" % strafe)
	host.queue_free()
	await frames(2)

func _sample_heading(player, skating: bool, key_name: String) -> Dictionary:
	player.skating = skating
	player.velocity = Vector3.ZERO
	var origin: Vector3 = player.global_position
	var forward: Vector3 = player.camera_flat_forward()
	var right: Vector3 = player.camera_flat_right()
	var code := KEY_W
	if key_name == "S":
		code = KEY_S
	elif key_name == "D":
		code = KEY_D
	var hold := InputEventKey.new()
	hold.physical_keycode = code
	hold.keycode = code
	hold.pressed = true
	Input.parse_input_event(hold)
	await frames(18)
	hold.pressed = false
	Input.parse_input_event(hold)
	await frames(1)
	var flat := Vector3(player.global_position.x - origin.x, 0.0, player.global_position.z - origin.z)
	var unit := flat.normalized() if flat.length() > 0.05 else Vector3.ZERO
	var face_basis: Vector3 = -player.rig.global_transform.basis.z
	var face := Vector3(face_basis.x, 0.0, face_basis.z).normalized()
	return {
		"travel": flat.length(),
		"flat": flat,
		"forward": forward,
		"align": unit.dot(forward),
		"right": unit.dot(right),
		"face": face.dot(unit) if key_name != "D" else face.dot(right),
	}

func _invert() -> void:
	var path := "user://au-look-v1.json"
	DirAccess.remove_absolute(path)
	var fresh = _player(_host(), Vector3(0, 1, 0))
	expect(fresh.look_invert_y and not fresh.look_invert_chosen, "new users start with inverted mouse Y")
	fresh.get_parent().queue_free()
	var old := FileAccess.open(path, FileAccess.WRITE)
	old.store_string("{\"sensitivity\":0.004,\"invert_y\":false}")
	old.close()
	var legacy = _player(_host(), Vector3(0, 1, 0))
	expect(legacy.look_invert_y and is_equal_approx(legacy.look_sensitivity, 0.004), "a save without an invert choice stays inverted and keeps sensitivity")
	legacy.get_parent().queue_free()
	var chosen := FileAccess.open(path, FileAccess.WRITE)
	chosen.store_string("{\"sensitivity\":0.0028,\"invert_y\":false,\"invert_chosen\":true}")
	chosen.close()
	var explicit = _player(_host(), Vector3(0, 1, 0))
	expect(not explicit.look_invert_y and explicit.look_invert_chosen, "an explicit saved non-inverted choice reloads")
	explicit.get_parent().queue_free()
	DirAccess.remove_absolute(path)
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(5)
	expect(main.player.look_invert_y, "pause menu starts from the inverted default")
	main.flow.set_paused(true)
	var toggle: CheckButton = main.invert_check
	expect(toggle != null and toggle.button_pressed and toggle.text == "Invert mouse Y", "pause menu shows Invert mouse Y")
	toggle.button_pressed = false
	expect(not main.player.look_invert_y and main.player.look_invert_chosen, "the toggle stores the choice")
	main.queue_free()
	await frames(2)
	var reloaded = load("res://scenes/main.tscn").instantiate()
	add_child(reloaded)
	await frames(5)
	expect(not reloaded.player.look_invert_y, "the toggle survives a reload")
	reloaded.flow.set_paused(true)
	reloaded.invert_check.button_pressed = true
	expect(reloaded.player.look_invert_y, "the toggle can turn inversion back on")
	reloaded.flow.set_paused(false)
	var pitch0: float = reloaded.player.camera_pitch
	reloaded.player.look_captured = true
	reloaded.player.look_invert_y = true
	reloaded.player.push_mouse_look(Vector2(0, 40))
	await frames(1)
	var down_pitch: float = reloaded.player.camera_pitch
	reloaded.player.look_invert_y = false
	reloaded.player.push_mouse_look(Vector2(0, 40))
	await frames(1)
	var up_pitch: float = reloaded.player.camera_pitch
	expect(down_pitch < pitch0 and up_pitch > down_pitch, "mouse down looks up when inverted and down when not down=%s then=%s" % [down_pitch, up_pitch])
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_Y
	stick.axis_value = 1.0
	var stick_start: float = reloaded.player.camera_pitch
	reloaded.player.look_invert_y = true
	Input.parse_input_event(stick)
	await frames(4)
	var stick_inverted: float = reloaded.player.camera_pitch - stick_start
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await frames(1)
	stick_start = reloaded.player.camera_pitch
	reloaded.player.look_invert_y = false
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	await frames(4)
	var stick_plain: float = reloaded.player.camera_pitch - stick_start
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	expect(stick_inverted > 0.02 and absf(stick_inverted - stick_plain) < 0.03, "right stick pitch ignores the mouse invert setting inv=%s plain=%s" % [stick_inverted, stick_plain])
	reloaded.flow.set_paused(false)
	reloaded.queue_free()
	DirAccess.remove_absolute(path)
	await frames(2)

func _movement() -> void:
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(40, 1, 40), Palette.GROUND)
	var player = _player(host, Vector3(0, 0.4, 0))
	await frames(20)
	expect(player.is_on_floor(), "player lands on the ground")
	var y0: float = player.global_position.y
	player.external_jump = true
	await frames(8)
	expect(player.global_position.y > y0 + 0.25 and not player.is_on_floor(), "jump leaves the ground y=%s" % player.global_position.y)
	await frames(90)
	expect(player.is_on_floor(), "jump returns to the ground")
	player.camera_yaw = 0.0
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	var z0: float = player.global_position.z
	await frames(45)
	expect(player.global_position.z < z0 - 1.0, "skate moves forward z=%s" % player.global_position.z)
	host.queue_free()
	await frames(2)
	host = _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(40, 1, 40), Palette.GROUND)
	Blocks.solid(host, "Wall", Vector3(0, 1.5, -3), Vector3(6, 3, 1), Palette.FENCE)
	player = _player(host, Vector3(0, 0.4, 0))
	await frames(15)
	player.camera_yaw = 0.0
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	await frames(90)
	expect(player.global_position.z < -1.0 and player.global_position.z > -2.45, "wall stops the player z=%s" % player.global_position.z)
	host.queue_free()
	await frames(2)
	host = _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(50, 1, 50), Palette.GROUND)
	Blocks.add_ramp(host, "Ramp", Vector3(0, 0, -4))
	player = _player(host, Vector3(0, 0.4, -2.6))
	await frames(20)
	player.camera_yaw = 0.0
	player.skating = true
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	var max_y: float = player.global_position.y
	var climbed := false
	for _i in 180:
		await get_tree().physics_frame
		max_y = max(max_y, player.global_position.y)
		if player.is_on_floor() and player.global_position.y > 0.45:
			climbed = true
	expect(max_y > 0.7 and climbed, "ramp is rideable max_y=%s pos=%s" % [max_y, player.global_position])
	player.external_camera_yaw_delta = 0.0
	player.camera_yaw = 0.8
	await frames(1)
	expect(is_equal_approx(player.get_node("CameraPivot").rotation.y, player.camera_yaw), "camera yaw follows the rig")
	host.queue_free()
	await frames(2)

func _body() -> void:
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(30, 1, 30), Palette.GROUND)
	var player = _player(host, Vector3(0, 0.4, 0))
	await frames(20)
	player.skating = false
	player.external_move_active = true
	player.external_move = Vector2.ZERO
	player.rotation.y = 0.0
	player.rig.rotation.y = 0.0
	await frames(8)
	var ground_sole: float = player.global_position.y + 0.325
	var stand_gap: float = absf(player.rig.sole_y() - ground_sole)
	expect(stand_gap < 0.05, "standing soles meet the capsule bottom gap=%s" % stand_gap)
	var ankle: Vector3 = player.rig.ankle_l.global_position
	var wanted: Vector3 = player.to_global(Vector3(-0.08, 0.40, -0.02))
	expect(ankle.distance_to(wanted) < 0.04, "standing ankle stays on the leg target d=%s" % ankle.distance_to(wanted))
	player.skating = true
	player.camera_yaw = 0.0
	player.external_move = Vector2(0, 1)
	await frames(10)
	expect(player.rig.pose_name == "skate", "contact check uses the skate pose")
	var board_gap: float = absf(player.rig.sole_y() - player.rig.deck_top_y())
	expect(board_gap < 0.04, "skate soles sit on the deck gap=%s" % board_gap)
	host.queue_free()
	await frames(2)

func _quarter() -> void:
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(40, 1, 40), Palette.GROUND)
	Blocks.add_quarter(host, "Quarter", Vector3(0, 0, 0), 0.0, 2.4, 6.0, Palette.RAMP)
	var player = _player(host, Vector3(-2.2, 0.4, 0))
	await frames(20)
	var start_y: float = player.global_position.y
	player.skating = true
	player.camera_yaw = -PI * 0.5
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	var max_y: float = start_y
	var stuck := 0
	for _i in 150:
		await get_tree().physics_frame
		max_y = maxf(max_y, player.global_position.y)
		var gain: float = player.global_position.y - start_y
		var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
		if gain > 0.35 and gain < 1.2 and speed < 0.25:
			stuck += 1
	expect(max_y > start_y + 0.8, "quarter is rideable up max_y=%s start=%s pos=%s" % [max_y, start_y, player.global_position])
	expect(stuck < 12, "quarter face does not snag stuck_frames=%s pos=%s v=%s" % [stuck, player.global_position, player.velocity])
	var high_y: float = player.global_position.y
	player.camera_yaw = -PI * 0.5
	player.external_move = Vector2(0, -1)
	var low_y: float = high_y
	for _i in 120:
		await get_tree().physics_frame
		low_y = minf(low_y, player.global_position.y)
	expect(low_y < high_y - 0.45 or low_y < start_y + 0.4, "quarter rides back down low=%s high=%s" % [low_y, high_y])
	host.queue_free()
	await frames(2)

func _art_quarter() -> void:
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(40, 1, 40), Palette.GROUND)
	var pipe: Node3D = load("res://assets/library/quarter_pipe/quarter_pipe.tscn").instantiate()
	pipe.name = "LibraryQuarter"
	host.add_child(pipe)
	await frames(2)
	expect(pipe.triangle_count > 800 and pipe.triangle_count < 8000, "quarter pipe triangle budget %s" % pipe.triangle_count)
	expect(pipe.get_node_or_null("Shell") != null and pipe.get_node_or_null("Coping") != null, "quarter pipe has shell and coping")
	expect(pipe.get_node_or_null("GraffitiL") != null, "quarter pipe has a graffiti face")
	for skating in [true, false]:
		var player = _player(host, Vector3(-2.4, 0.5, 0))
		await frames(18)
		var start_y: float = player.global_position.y
		player.skating = skating
		player.camera_yaw = -PI * 0.5
		player.external_move_active = true
		player.external_move = Vector2(0, 1)
		var max_y: float = start_y
		var stuck := 0
		var reversed := false
		var high_y: float = start_y
		var low_y: float = start_y
		var turn_at: float = 0.8 if skating else 0.45
		for _i in 180:
			await get_tree().physics_frame
			max_y = maxf(max_y, player.global_position.y)
			var gain: float = player.global_position.y - start_y
			var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
			if not reversed and gain > 0.3 and gain < 1.15 and speed < 0.2:
				stuck += 1
			if not reversed and gain > turn_at:
				reversed = true
				high_y = player.global_position.y
				low_y = high_y
				player.external_move = Vector2(0, -1)
			elif reversed:
				low_y = minf(low_y, player.global_position.y)
		expect(max_y > start_y + turn_at, "library quarter %s climbs max_y=%s start=%s" % ["skate" if skating else "walk", max_y, start_y])
		expect(stuck < 12, "library quarter %s does not snag stuck=%s pos=%s" % ["skate" if skating else "walk", stuck, player.global_position])
		expect(reversed and low_y < high_y - 0.25, "library quarter %s comes back down low=%s high=%s" % ["skate" if skating else "walk", low_y, high_y])
		player.queue_free()
		await frames(2)
	host.queue_free()
	await frames(2)

func _tricks() -> void:
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(40, 1, 40), Palette.GROUND)
	var player = _player(host, Vector3(0, 0.4, 0))
	await frames(16)
	while not player.is_on_floor():
		await get_tree().physics_frame
	player.skating = true
	var clip_hip: float = player.rig.preview_clip("crouch", 0.62)
	expect(clip_hip < 0.85 and clip_hip > 0.5, "crouch clip lowers the hips y=%s" % clip_hip)
	player.rig._idle()
	player.rig._solve_legs()
	var y_ground: float = player.global_position.y
	player.request_trick("ollie")
	var saw_crouch := false
	var saw_air := false
	var left_floor := false
	for _i in 50:
		await get_tree().physics_frame
		if player.trick == "crouch" or player.rig.pose_name == "crouch":
			saw_crouch = true
		if not player.is_on_floor() and player.global_position.y > y_ground + 0.35:
			left_floor = true
			saw_air = player.trick == "ollie" or player.rig.pose_name == "ollie"
	expect(saw_crouch and left_floor and saw_air, "ollie crouches then leaves the ground crouch=%s air=%s y=%s" % [saw_crouch, saw_air, player.global_position.y])
	await frames(130)
	expect(player.is_on_floor() and (player.trick == "" or player.trick == "land" or player.rig.pose_name == "land" or player.rig.pose_name == "skate"), "ollie lands and recovers trick=%s pose=%s" % [player.trick, player.rig.pose_name])
	player.request_trick("flip")
	var spun := false
	var feet_clear := false
	var caught := false
	var full_turn := false
	for _i in 110:
		await get_tree().physics_frame
		if player.flip_turns > 0.35 and not player.board_caught:
			spun = true
			var gap: float = player.rig.sole_y() - player.rig.deck_top_y()
			player.set_meta("flip_gap", gap)
			player.set_meta("flip_z", player.rig.board.rotation.z)
			if gap > 0.25:
				feet_clear = true
			if absf(player.rig.board.rotation.z) > 2.8:
				full_turn = true
		if player.board_caught and player.flip_turns >= 0.99:
			caught = true
	expect(spun and feet_clear and full_turn and caught, "kickflip shows a full board turn off the feet then catches gap=%s spin=%s" % [player.get_meta("flip_gap", 0.0), player.get_meta("flip_z", 0.0)])
	await frames(40)
	while not player.is_on_floor() or player.trick != "":
		await get_tree().physics_frame
	player.request_trick("grab")
	var saw_grab := false
	var board_in_hand := false
	for _i in 100:
		await get_tree().physics_frame
		if player.trick == "grab":
			saw_grab = true
			var gap_hand: float = player.rig.hand_r.global_position.distance_to(player.rig.board.global_position)
			if gap_hand < 0.4 and player.rig.board.position.y > 0.65:
				board_in_hand = true
	expect(saw_grab and board_in_hand, "grab puts the board in the hand trick=%s pose=%s" % [player.trick, player.rig.pose_name])
	await frames(80)
	player.global_position = Vector3(0, 0.5, 0)
	player.velocity = Vector3.ZERO
	await frames(12)
	player.trick = "flip"
	player.board_caught = false
	player.flip_turns = 0.2
	player.trick_time = 0.3
	player.velocity = Vector3(0, -1, 0)
	await frames(20)
	expect(player.trick == "bail" or player.bail_time > 0.0 or player.rig.pose_name == "bail", "early landing bails instead of a silent catch pose=%s trick=%s" % [player.rig.pose_name, player.trick])
	await frames(50)
	expect(player.trick == "" and player.skating, "bail recovers to skating")
	player.queue_free()
	var pipe: Node3D = load("res://assets/library/quarter_pipe/quarter_pipe.tscn").instantiate()
	host.add_child(pipe)
	player = _player(host, Vector3(-2.2, 0.5, 0))
	await frames(16)
	player.skating = true
	player.camera_yaw = -PI * 0.5
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	var popped := false
	for _i in 80:
		await get_tree().physics_frame
		if not popped and player.global_position.y > 0.15:
			player.request_trick("ollie")
			popped = true
		if popped and not player.is_on_floor() and player.trick == "ollie":
			break
	expect(popped and player.trick == "ollie" and not player.is_on_floor(), "ollie leaves the quarter surface trick=%s y=%s floor=%s" % [player.trick, player.global_position.y, player.is_on_floor()])
	host.queue_free()
	await frames(2)

func _grind() -> void:
	var host := _host()
	Blocks.solid(host, "Pit", Vector3(0, -8, 0), Vector3(40, 1, 40), Palette.GROUND)
	var rail = load("res://scenes/grind_rail.tscn").instantiate()
	rail.length = 8.0
	rail.position = Vector3(0, 1.1, 0)
	host.add_child(rail)
	var player = _player(host, Vector3(-3.0, 1.75, 0))
	player.camera_yaw = -PI / 2.0
	player.skating = true
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	var attached := false
	for _i in 90:
		await get_tree().physics_frame
		if player.grind != null:
			attached = true
			break
	expect(attached, "airborne approach attaches to the rail y=%s v=%s" % [player.global_position.y, player.velocity])
	if attached:
		var x0: float = player.global_position.x
		await frames(15)
		expect(player.grind != null and player.global_position.x > x0 + 0.3, "grind travels along the rail")
		player.external_jump = true
		await frames(3)
		expect(player.grind == null, "jump leaves the rail")
	host.queue_free()
	await frames(2)
	host = _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(40, 1, 40), Palette.GROUND)
	rail = load("res://scenes/grind_rail.tscn").instantiate()
	rail.length = 8.0
	rail.position = Vector3(0, 1.1, 0)
	host.add_child(rail)
	player = _player(host, Vector3(-3.0, 0.4, 0))
	await frames(20)
	player.camera_yaw = -PI / 2.0
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	await frames(70)
	expect(player.grind == null and player.is_on_floor(), "grounded skating does not snap onto the rail")
	host.queue_free()
	await frames(2)

func _district() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(25)
	for node_name in ["YardWallNorth", "YardWallEast", "YardWallWest", "YardWallSouthWest", "YardWallSouthEast", "MainGate", "Workshop", "ResistanceRooms", "WarehouseArcade", "SolarRoof", "SkateQuarter", "Funbox", "HalfPipeWest", "GrindRail", "BowlFloor", "Cabinet", "NPCZero", "RustAvenue", "FutureSkyline0"]:
		expect(main.world_sim.get_node_or_null(node_name) != null, "yard has " + node_name)
	var player = main.player
	expect(player.input_enabled and main.zone_at(player.global_position) == "SKATE YARD", "spawn is in the skate yard")
	expect(main.zone_at(Vector3(32, 0, -20)) == "ARCADE", "arcade zone")
	expect(main.zone_at(Vector3(-50, 0, -10)) == "SKATE YARD", "skate yard zone")
	expect(main.zone_at(Vector3(10, 0, -60)) == "RESISTANCE", "resistance zone")
	expect(main.zone_at(Vector3(52, 0, 64)) == "GATE", "gate zone")
	expect(main.zone_at(Vector3(120, 0, 0)) == "OUTSIDE", "east skyline is outside the yard")
	var zero = main.world_sim.get_node("NPCZero")
	player.global_position = zero.global_position + Vector3(1.1, 0, 0)
	zero.interact(main.flow)
	expect(main.flow.dialogue_open and not player.input_enabled, "Zero opens dialogue and takes input")
	await frames(2)
	expect(zero.rig.pose_name == "talk", "Zero raises a pose while talking")
	main.flow.advance_dialogue()
	main.flow.advance_dialogue()
	expect(not main.flow.dialogue_open and player.input_enabled and main.flow.save.met.zero, "dialogue returns input and records Zero")
	expect(player.get_node_or_null("Fony") != null, "player visual is the Fony rig")
	expect(player.get_node("Fony").find_child("Hair", true, false) != null, "Fony rig has hair")
	expect(player.get_node("Fony").find_child("Body", true, false) != null, "Fony rig has the human body")
	expect(player.rig.skeleton.get_bone_count() == 17, "Fony keeps the 17 trick bones")
	expect(zero.find_child("Screen", true, false) != null, "Zero rig has a CRT screen")
	player.global_position = Vector3(-42, 0.6, 2)
	player.velocity = Vector3.ZERO
	await frames(25)
	expect(player.is_on_floor(), "Fony stands on the yard before skating")
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	player.skating = true
	await frames(12)
	expect(player.rig.pose_name == "skate", "skate pose while moving on the board")
	player.external_jump = true
	await frames(4)
	expect(player.rig.pose_name == "jump", "jump pose while airborne")
	player.external_move = Vector2.ZERO
	await frames(40)
	expect(player.rig.pose_name == "land" or player.rig.pose_name == "idle" or player.rig.pose_name == "skate", "landing returns to a grounded pose")
	var home: Vector3 = player.spawn_position
	player.global_position = home + Vector3(0, -20, 0)
	await frames(2)
	expect(player.global_position.distance_to(home) < 2.0, "falling out of the yard respawns at the start")
	var audio = get_node("/root/AudioOwner")
	audio.holder = "other"
	var blocked: Dictionary = main.flow.open_cabinet()
	expect(blocked.get("ok") == false and main.flow.boundary.phase == "world" and player.input_enabled, "cabinet does not open without the audio handoff")
	audio.holder = "world"
	var cabinet = main.world_sim.get_node("Cabinet")
	player.global_position = Vector3(cabinet.global_position.x, 0.2, cabinet.global_position.z + 2.0)
	expect(main._nearest(2.5) == cabinet, "cabinet is in interact range")
	cabinet.interact(main.flow)
	expect(main.flow.boundary.phase == "in_session", "cabinet opens a placeholder session")
	expect(main.flow.boundary.phase == "in_session" and main.flow.boundary.input_owner == "session", "session owns input")
	expect(main.world_sim.process_mode == Node.PROCESS_MODE_DISABLED and not player.input_enabled, "world sim and player input pause")
	expect(audio.holder == "session", "session holds the only audio owner")
	var finished: Dictionary = main.flow.finish_session("keyboard")
	expect(finished.get("ok") == true and main.flow.boundary.phase == "world", "finish returns to the world")
	expect(player.input_enabled and main.world_sim.process_mode == Node.PROCESS_MODE_PAUSABLE, "world input and sim resume")
	expect(audio.holder == "world", "audio owner returns to the world")
	expect(str(finished.get("result", {}).get("integration", "")) == "placeholder_not_canvas", "result says this is not the canvas runtime")
	for i in 10:
		expect(main.flow.open_cabinet().get("ok") == true, "cabinet reenter %d" % i)
		expect(main.flow.abort_session("unknown").get("ok") == true, "cabinet reabort %d" % i)
	expect(main.flow.boundary.phase == "world" and audio.holder == "world" and player.input_enabled, "repeated cabinet use does not stick")
	expect(main.flow.save.results.size() == 11, "results stay bounded and recorded")
	var loaded = SaveScript.new()
	expect(loaded.load_user(main.flow.save_path).get("ok") == true and loaded.results.size() == 11, "save file reloads")
	player.global_position = Vector3(0, 0.5, 40)
	player.velocity = Vector3.ZERO
	player.camera_yaw = 0.0
	await frames(8)
	var z_before: float = player.global_position.z
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	main.flow.set_paused(true)
	await frames(20)
	expect(main.get_tree().paused and is_equal_approx(player.global_position.z, z_before), "pause freezes the player")
	main.flow.set_paused(false)
	await frames(20)
	expect(not main.get_tree().paused and player.global_position.z < z_before - 0.15, "resume lets the player skate")

func _host() -> Node3D:
	var host := Node3D.new()
	add_child(host)
	return host

func _player(host: Node, pos: Vector3):
	var player = load("res://scenes/player.tscn").instantiate()
	player.position = pos
	host.add_child(player)
	return player
