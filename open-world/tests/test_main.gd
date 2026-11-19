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
	if OS.get_environment("AU_TEST_ONLY") == "grind1":
		await _grind_round()
		print("SUMMARY failed=", fails.size())
		get_tree().quit(1 if fails.size() else 0)
		return
	if OS.get_environment("AU_TEST_ONLY") == "grind":
		# quick loop for the grind round (the full suite below is what counts)
		await _grind()
		await _grind_round()
		await _grind_park()
		print("SUMMARY failed=", fails.size())
		for item in fails:
			print("FAIL ", item)
		get_tree().quit(1 if fails.size() else 0)
		return
	if OS.get_environment("AU_TEST_ONLY") == "finish":
		await _finish_pass()
		print("SUMMARY failed=", fails.size())
		for item in fails:
			print("FAIL ", item)
		get_tree().quit(1 if fails.size() else 0)
		return
	if OS.get_environment("AU_TEST_ONLY") == "m0":
		_contracts()
		await _m0_packs()
		print("SUMMARY failed=", fails.size())
		for item in fails:
			print("FAIL ", item)
		get_tree().quit(1 if fails.size() else 0)
		return
	if OS.get_environment("AU_TEST_ONLY") == "m1" or OS.get_environment("AU_TEST_ONLY") == "m1pilot":
		var m1 = preload("res://tests/m1_tests.gd").new()
		if OS.get_environment("AU_TEST_ONLY") == "m1pilot":
			m1.t = self
			await m1.autopilot_run()
		else:
			await m1.run(self)
		print("SUMMARY failed=", fails.size())
		for item in fails:
			print("FAIL ", item)
		get_tree().quit(1 if fails.size() else 0)
		return
	if OS.get_environment("AU_TEST_ONLY") == "front":
		await preload("res://tests/front_tests.gd").new().run(self)
		print("SUMMARY failed=", fails.size())
		for item in fails:
			print("FAIL ", item)
		get_tree().quit(1 if fails.size() else 0)
		return
	if OS.get_environment("AU_TEST_ONLY") == "phase4":
		# quick loop while working on Phase 4 (the full suite below is what counts)
		await _kickturn()
		await _park()
		print("SUMMARY failed=", fails.size())
		for item in fails:
			print("FAIL ", item)
		get_tree().quit(1 if fails.size() else 0)
		return
	_contracts()
	await _boot()
	await _input_map()
	await _look()
	await _heading()
	await _invert()
	await _movement()
	await _grind()
	await _grind_round()
	await _grind_park()
	await _body()
	await _quarter()
	await _art_quarter()
	await _transition()
	await _dropin()
	await _kickturn()
	await _park()
	await _finish_pass()
	await _tricks()
	await _fony_sprite()
	await _district()
	await _m0_packs()
	await preload("res://tests/m1_tests.gd").new().run(self)
	await preload("res://tests/front_tests.gd").new().run(self)
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

## The reloaded yard can still be importing when the first joypad event arrives, so that
## sample moves no pitch. Hold the stick until pitch actually changes (bounded), release
## it, and put the camera back. The measured samples below stay a fixed 4 frames.
func _prime_stick(player, stick: InputEventJoypadMotion) -> void:
	var origin: float = player.camera_pitch
	await get_tree().process_frame
	await get_tree().process_frame
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	for _i in 45:
		await get_tree().process_frame
		await get_tree().physics_frame
		if absf(player.camera_pitch - origin) > 0.02:
			break
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await get_tree().process_frame
	await frames(2)
	player.camera_pitch = origin

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
	reloaded.player.look_invert_y = true
	await _prime_stick(reloaded.player, stick)
	var stick_start: float = reloaded.player.camera_pitch
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	await frames(4)
	var stick_inverted: float = reloaded.player.camera_pitch - stick_start
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await frames(1)
	reloaded.player.look_invert_y = false
	await frames(2)
	stick_start = reloaded.player.camera_pitch
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
	# Phase 1a: time a flat ollie on the live body at 60 Hz.
	var ground_y: float = player.global_position.y
	player.request_trick("ollie")
	var crouch_ticks := 0
	var air_ticks := 0
	var apex := 0.0
	var launch := 0.0
	var impact := 0.0
	var land_ticks := 0
	for _i in 120:
		await get_tree().physics_frame
		if player.trick == "crouch":
			crouch_ticks += 1
		if not player.is_on_floor():
			if air_ticks == 0:
				launch = player.velocity.y
			air_ticks += 1
			impact = player.velocity.y
			apex = maxf(apex, player.global_position.y - ground_y)
		if player.trick == "land":
			land_ticks += 1
		if air_ticks > 0 and player.is_on_floor() and player.trick == "":
			break
	var tick := 1.0 / 60.0
	expect(absf(crouch_ticks * tick - 0.2) <= 0.034, "ollie crouch lasts about 0.2 s got %s" % (crouch_ticks * tick))
	expect(absf(air_ticks * tick - 0.42) <= 0.05, "ollie stays up about 0.42 s got %s" % (air_ticks * tick))
	expect(apex > 0.33 and apex < 0.48, "ollie apex is about 0.4 m got %s" % apex)
	expect(absf(launch - 3.8) < 0.31 and impact > -4.6, "ollie pops at 3.8 m/s and lands soft launch=%s impact=%s" % [launch, impact])
	expect(land_ticks > 0 and land_ticks * tick <= 0.3, "ollie landing absorbs then hands back got %s s" % (land_ticks * tick))
	player.request_trick("flip")
	var spin_ticks := 0
	var spun := false
	var feet_clear := false
	var caught := false
	var full_turn := false
	for _i in 110:
		await get_tree().physics_frame
		if player.trick == "flip" and not player.board_caught:
			spin_ticks += 1
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
	expect(spin_ticks * (1.0 / 60.0) >= 0.3 and spin_ticks * (1.0 / 60.0) <= 0.41 and player.trick != "bail", "kickflip spins in about 0.4 s and is caught inside the new air got %s s trick=%s" % [spin_ticks / 60.0, player.trick])
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
	# Phase 1e: a grab still held at touchdown bails (plan: "still grabbing at touchdown: bail"); let go in time and he lands.
	await frames(10)
	player.grab_hold = true
	player.request_trick("grab")
	var held_bail := false
	for _i in 90:
		await get_tree().physics_frame
		if player.trick == "bail":
			held_bail = true
			break
	player.grab_hold = false
	expect(held_bail and player.last_bail_reason == "grab_held", "a grab held through touchdown bails got trick=%s reason=%s" % [player.trick, player.last_bail_reason])
	await frames(50)
	expect(player.trick == "" and player.skating, "grab bail recovers to skating")
	player.request_trick("grab")
	var released_land := false
	for _i in 90:
		await get_tree().physics_frame
		if player.trick == "bail":
			break
		if player.trick == "land":
			released_land = true
			break
	expect(released_land, "a released grab lands")
	await frames(30)
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

## Grind round: a 0.30 m flat bar (top of the tube) along X at the origin, ground at y = 0. Body origin = contact - 0.325.
func _grind_bar(host: Node, len := 7.0, drop := 0.0, friction := -1.0) -> Node:
	var rail = load("res://scenes/grind_rail.tscn").instantiate()
	rail.length = len
	rail.drop = drop
	if friction >= 0.0:
		rail.friction = friction
	rail.position = Vector3(0, 0.30 + drop * 0.5, 0)
	host.add_child(rail)
	return rail

## Ride +X along z = lateral at `speed` and ollie when the board is `lead` m before the rail start; returns the player.
func _grind_ride(host: Node, speed: float, lateral := 0.2, lead := 2.6, ollie := true):
	var player = _player(host, Vector3(-8.0, -0.3, lateral))
	await frames(8)
	player.skating = true
	player.camera_yaw = -PI / 2.0
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	player.global_position = Vector3(-8.0, -0.325, lateral)
	player.velocity = Vector3(speed, 0, 0)
	var popped := not ollie
	for _i in 160:
		await get_tree().physics_frame
		if not popped and player.global_position.x > -3.5 - lead:
			player.request_trick("ollie")
			popped = true
		if OS.get_environment("AU_GRIND_DEBUG") == "1":
			print("dbg x=%.2f y=%.3f vy=%.2f vx=%.2f floor=%s trick=%s" % [player.global_position.x, player.global_position.y, player.velocity.y, player.velocity.x, player.is_on_floor(), player.trick])
		if player.grind != null or player.trick == "bail":
			break
	return player

func _grind_round() -> void:
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(60, 1, 60), Palette.GROUND)
	var rail = _grind_bar(host)
	await frames(2)
	expect(rail.kind == "rail" and absf(rail.line_point(0.0).y - 0.30) < 0.001 and rail.get_node_or_null("Tube") != null and rail.get_node_or_null("Leg0") != null, "grind: flat bar top at 0.30 m with a tube and legs")
	# 1. ollie onto the bar, nearly parallel: locks a 50-50, board on the bar, speed carries, rolls off the end and lands
	var player = await _grind_ride(host, 6.5)
	expect(player.grind == rail and player.grind_trick == "5050" and player.grind_last.get("how", "") == "ollie", "grind: an ollie onto the bar locks a 50-50 last=%s y=%s" % [player.grind_last, player.global_position.y])
	if player.grind != null:
		var entry: float = absf(player.grind_v)
		# finish pass: the lock eases onto the bar (no pop on the lock tick), then sits on the riding line
		var snap0: float = player.grind_snap.length()
		var step_max := 0.0
		var prev: Vector3 = player.global_position
		for _i in 9:
			await get_tree().physics_frame
			var d: Vector3 = player.global_position - prev
			step_max = maxf(step_max, Vector2(d.y, d.z).length())
			prev = player.global_position
		expect(snap0 > 0.01 and step_max < 0.06, "grind: the lock eases onto the bar (lateral/vertical step per tick %.3f m, snap %.3f m)" % [step_max, snap0])
		var y_ok: bool = absf(player.global_position.y + 0.325 - (0.30 - player.GRIND_SINK)) < 0.005
		var z_ok: bool = absf(player.global_position.z) < 0.001
		expect(y_ok and z_ok and player.on_ground() and player.trick == "", "grind: wheels on the bar top, centred on the axis y=%s z=%s" % [player.global_position.y, player.global_position.z])
		expect(entry > 5.5, "grind: the approach speed carries onto the bar entry=%s" % entry)
		player.skate_toggle_pressed()
		expect(player.skating and player.grind != null, "grind: Shift (kick-up) is ignored on the bar")
		await frames(21)
		expect(player.grind != null and absf(player.grind_v) < entry and absf(player.grind_v) > entry - 0.5, "grind: slow friction along the bar v=%s entry=%s" % [player.grind_v, entry])
		var left := false
		for _i in 120:
			await get_tree().physics_frame
			if player.grind == null:
				left = true
				break
		expect(left and player.grind_last.get("exit", "") == "end" and player.global_position.x > 3.4, "grind: rolls off the end last=%s x=%s" % [player.grind_last, player.global_position.x])
		var landed := false
		for _i in 40:
			await get_tree().physics_frame
			if player.is_on_floor():
				landed = true
				break
		await frames(2)
		expect(landed and player.skating and player.bail_time <= 0.0 and player.velocity.x > 4.0, "grind: lands off the end still skating vx=%s" % player.velocity.x)
		expect(player.trick == "land" or player.trick == "", "grind: touchdown off the end plays the land frames trick=%s" % player.trick)
		expect(player.grind_count == 1, "grind: one grind counted got %s" % player.grind_count)
	player.queue_free()
	await frames(2)
	# 2. ollie out mid-bar: pops up and drifts back to the side he came from, lands clear of the bar without re-locking
	player = await _grind_ride(host, 6.5)
	if player.grind != null:
		await frames(12)
		player.request_trick("ollie")
		await frames(2)
		expect(player.grind == null and player.grind_last.get("exit", "") == "pop" and player.trick == "ollie" and player.velocity.y > 0.0, "grind: Q pops out of the grind trick=%s vy=%s" % [player.trick, player.velocity.y])
		expect(player.grind_out_time >= 0.0, "grind: pop-out starts the out frames")
		var relock := false
		for _i in 60:
			await get_tree().physics_frame
			if player.grind != null:
				relock = true
		expect(not relock and player.is_on_floor() and absf(player.global_position.z) > 0.3 and player.skating and player.bail_time <= 0.0, "grind: lands beside the bar after the pop z=%s" % player.global_position.z)
	else:
		expect(false, "grind: second ride locks for the pop-out test")
	player.queue_free()
	await frames(2)
	# 3. bad approaches: across the bar at 45 deg, too slow, and riding into it on the ground
	player = _player(host, Vector3(-1.0, 0.2, 0.1))
	await frames(2)
	player.skating = true
	player.external_move_active = true
	player.external_move = Vector2.ZERO
	player.global_position = Vector3(-1.0, 0.30 + 0.06 - 0.325, 0.1)
	player.velocity = Vector3(4.0, -1.0, -4.0)
	await frames(3)
	expect(player.grind == null and player.trick == "bail" and player.last_bail_reason == "grind_bad_angle", "grind: landing on the bar at 45 deg bails reason=%s" % player.last_bail_reason)
	player.queue_free()
	await frames(2)
	player = _player(host, Vector3(-1.0, 0.2, 0.1))
	await frames(2)
	player.skating = true
	player.external_move_active = true
	player.external_move = Vector2.ZERO
	player.global_position = Vector3(-1.0, 0.30 + 0.06 - 0.325, 0.1)
	player.velocity = Vector3(1.0, -1.0, 0.0)
	await frames(3)
	expect(player.grind == null and player.trick == "bail" and player.last_bail_reason == "grind_too_slow", "grind: landing on the bar too slow bails reason=%s" % player.last_bail_reason)
	player.queue_free()
	await frames(2)
	player = _player(host, Vector3(0.0, -0.3, -2.0))
	await frames(8)
	player.skating = true
	player.camera_yaw = PI
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	player.velocity = Vector3(0, 0, 6.0)
	var clipped := false
	for _i in 60:
		await get_tree().physics_frame
		if player.trick == "bail":
			clipped = true
			break
	expect(clipped and player.last_bail_reason == "grind_clipped", "grind: riding into the bar without an ollie bails reason=%s z=%s" % [player.last_bail_reason, player.global_position.z])
	player.queue_free()
	await frames(2)
	# 4. no ollie, approach parallel beside it: nothing happens
	player = await _grind_ride(host, 6.0, 0.6, 0.0, false)
	await frames(60)
	expect(player.grind == null and player.trick != "bail" and player.grind_count == 0, "grind: rolling past beside the bar does nothing")
	player.queue_free()
	host.queue_free()
	await frames(2)
	# 5. stall: a sticky bar and a slow entry: the trucks catch and he falls off beside it
	host = _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(60, 1, 60), Palette.GROUND)
	rail = _grind_bar(host, 7.0, 0.0, 4.0)
	await frames(2)
	player = _player(host, Vector3(-2.5, 0.2, 0.1))
	await frames(2)
	player.skating = true
	player.external_move_active = true
	player.external_move = Vector2.ZERO
	player.global_position = Vector3(-2.5, 0.30 + 0.06 - 0.325, 0.1)
	player.velocity = Vector3(2.4, -0.5, 0.0)
	await frames(2)
	expect(player.grind == rail, "grind: slow but aligned entry still locks")
	var stalled := false
	for _i in 90:
		await get_tree().physics_frame
		if player.trick == "bail":
			stalled = true
			break
	expect(stalled and player.last_bail_reason == "grind_stalled" and player.grind == null, "grind: running out of speed on the bar bails reason=%s" % player.last_bail_reason)
	await frames(30)
	expect(player.global_position.y < -0.2 and absf(player.global_position.z) > 0.3, "grind: the stall drops him beside the bar y=%s z=%s" % [player.global_position.y, player.global_position.z])
	host.queue_free()
	await frames(2)
	# 6. down rail: gravity along it speeds him up
	host = _host()
	Blocks.solid(host, "Ground", Vector3(0, -2.5, 0), Vector3(60, 1, 60), Palette.GROUND)
	rail = _grind_bar(host, 6.0, 1.0)
	await frames(2)
	player = _player(host, Vector3(-12.0, -1.0, 0.1))
	await frames(2)
	player.skating = true
	player.external_move_active = true
	player.external_move = Vector2.ZERO
	var top0: Vector3 = rail.line_point(0.5)
	player.global_position = top0 + Vector3(0, 0.06 - 0.325, 0.1)
	player.velocity = Vector3(4.0, -0.5, 0.0)
	await frames(2)
	var v0: float = absf(player.grind_v) if player.grind != null else 0.0
	await frames(20)
	expect(player.grind == rail and absf(player.grind_v) > v0 + 0.5, "grind: a down rail speeds him up v0=%s v=%s" % [v0, player.grind_v])
	expect(player.grind != null and absf(player.global_position.y + 0.325 + player.GRIND_SINK - rail.line_point(player.grind_along).y) < 0.01, "grind: follows the slope of a down rail")
	host.queue_free()
	await frames(2)

## Grind round: the yard has a flat bar and two ledge edges, and both are reachable from a pushed run-up.
func _grind_park() -> void:
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(-50, -0.5, 0), Vector3(80, 1, 80), Palette.GROUND)
	load("res://scripts/yard.gd").build(host)
	await frames(3)
	var bar = host.get_node_or_null("GrindRail")
	expect(bar != null and bar.kind == "rail" and absf(bar.line_point(0.0).y - 0.30) < 0.001 and absf(bar.length - 7.0) < 0.001, "park: GrindRail is a 0.30 m flat bar")
	var pad: Node3D = host.get_node("ManualPad")
	for n in ["ManualPadLedgeE", "ManualPadLedgeW"]:
		var e = host.get_node_or_null(n)
		var ok: bool = e != null and e.kind == "ledge" and absf(e.line_point(1.0).y - float(pad.get_meta("height"))) < 0.001
		if ok:
			var mid: Vector3 = e.line_point(e.length * 0.5)
			ok = absf(mid.z - pad.position.z) < 0.01 and absf(absf(mid.x - pad.position.x) - 0.78) < 0.01
		expect(ok, "park: %s runs along the pad's metal edge at its height" % n)
	# flat bar: push west down the z = 6 lane side from x -40, ollie in, lock
	var player = _player(host, Vector3(-40.0, -0.3, 8.2))
	await frames(8)
	player.skating = true
	player.camera_yaw = PI / 2.0
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	player.global_position = Vector3(-40.0, -0.325, 8.2)
	player.velocity = Vector3(-4.0, 0, 0)
	var locked := false
	var popped := false
	for _i in 200:
		await get_tree().physics_frame
		if not popped and player.global_position.x < -55.5 + 7.0 + 2.6:
			player.request_trick("ollie")
			popped = true
		if player.grind != null:
			locked = player.grind == bar
			break
		if player.trick == "bail":
			break
	expect(locked, "park: pushing west and ollieing locks onto the flat bar last=%s x=%s" % [player.grind_last, player.global_position.x])
	player.queue_free()
	await frames(2)
	# ledge: ride south along the pad's east side, ollie up onto the east edge
	var east = host.get_node("ManualPadLedgeE")
	player = _player(host, Vector3(-36.8, -0.3, -3.0))
	await frames(8)
	player.skating = true
	player.camera_yaw = 0.0
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	player.global_position = Vector3(-36.8, -0.325, -3.0)
	player.velocity = Vector3(0, 0, -5.0)
	locked = false
	popped = false
	for _i in 200:
		await get_tree().physics_frame
		if not popped and player.global_position.z < -8.5 + 2.4:
			player.request_trick("ollie")
			popped = true
		if player.grind != null:
			locked = player.grind == east
			break
		if player.trick == "bail":
			break
	expect(locked, "park: riding south beside the pad and ollieing locks onto its east ledge last=%s pos=%s" % [player.grind_last, player.global_position])
	if locked:
		var left := false
		for _i in 150:
			await get_tree().physics_frame
			if player.grind == null:
				left = true
				break
		expect(left and player.grind_last.get("exit", "") == "end", "park: rides the ledge off its end last=%s" % [player.grind_last])
	player.queue_free()
	await frames(2)
	# ledge pop-out: Q mid-ledge pops him back out to the side he came from, onto the ground beside the pad
	player = _player(host, Vector3(-36.8, -0.3, -3.0))
	await frames(8)
	player.skating = true
	player.camera_yaw = 0.0
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	player.global_position = Vector3(-36.8, -0.325, -3.0)
	player.velocity = Vector3(0, 0, -5.0)
	popped = false
	for _i in 200:
		await get_tree().physics_frame
		if not popped and player.global_position.z < -8.5 + 2.4:
			player.request_trick("ollie")
			popped = true
		if OS.get_environment("AU_GRIND_DEBUG") == "1":
			print("dbg2 pos=%s v=%s floor=%s trick=%s req=%s" % [player.global_position, player.velocity, player.is_on_floor(), player.trick, player.trick_request])
		if player.grind != null or player.trick == "bail":
			break
	if player.grind == east:
		await frames(10)
		player.request_trick("ollie")
		var down := false
		for _i in 60:
			await get_tree().physics_frame
			if player.is_on_floor() and player.grind == null and player.velocity.y <= 0.0 and player.grind_pop_side == Vector3.ZERO:
				down = true
				break
		expect(down and player.global_position.x > -37.22 + 0.3 and player.global_position.y < -0.3 and player.bail_time <= 0.0 and player.skating, "park: popping out of the ledge lands on the ground outside the pad pos=%s last=%s" % [player.global_position, player.grind_last])
	else:
		expect(false, "park: second ledge ride locks for the pop-out")
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
	# Phase 2: blockout steps up the quarter pipe's north cheek onto its deck
	expect(main.world_sim.get_node_or_null("QuarterDeckSteps") != null, "yard has QuarterDeckSteps")
	var was_skating: bool = player.skating
	player.skating = false
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(-57.05, 0.1, -21.5)
	player.external_move_active = true
	var deck_feet := -10.0
	for _i in 300:
		# walk south (+Z) whatever the camera yaw is
		var axes: Array = player._camera_flat_axes()
		player.external_move = Vector2(Vector3(0, 0, 0.8).dot(axes[1]), Vector3(0, 0, 0.8).dot(axes[0]))
		await get_tree().physics_frame
		deck_feet = maxf(deck_feet, player.global_position.y + 0.325)
		if player.global_position.z > -11.5:
			break
	player.external_move = Vector2.ZERO
	await frames(4)
	expect(deck_feet > 1.5 and player.is_on_floor() and player.global_position.y + 0.325 > 1.5, "deck steps lead onto the quarter-pipe deck (feet %.2f m, lip 1.58 m) pos=%s fwd=%s input=%s" % [deck_feet, player.global_position, player.camera_flat_forward(), player.input_enabled])
	player.skating = was_skating
	player.global_position = home
	player.velocity = Vector3.ZERO
	await frames(4)
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
	await _arcade_door(main)

## Arcade Phase 1 (LOCAL): the front shutter is closed by default and never opens on approach. Interact (E) at the
## shutter rolls it up, fades to black and moves the player into the separate interior scene; the inside exit fades
## back out to the deck and the shutter rolls down again.
func _arcade_door(main) -> void:
	var player = main.player
	player.external_move = Vector2.ZERO
	player.external_move_active = false
	player.skating = false
	var door = main.world_sim.get_node_or_null("ArcadeDoor")
	expect(door != null and main.world_sim.get_node_or_null("ArcadeExterior") != null, "arcade has its exterior and front shutter")
	if door == null:
		return
	expect(door.state == "closed" and is_zero_approx(door.roll), "arcade shutter starts closed")
	# walk straight into the closed shutter: it blocks and does not open
	player.global_position = Vector3(32.0, 1.0, -4.5)
	player.velocity = Vector3.ZERO
	await frames(6)
	player.external_move_active = true
	var min_z := 99.0
	for _i in 120:
		var axes: Array = player._camera_flat_axes()
		player.external_move = Vector2(Vector3(0, 0, -0.8).dot(axes[1]), Vector3(0, 0, -0.8).dot(axes[0]))
		await get_tree().physics_frame
		min_z = minf(min_z, player.global_position.z)
	player.external_move = Vector2.ZERO
	player.external_move_active = false
	expect(min_z > -7.9 and door.state == "closed" and is_zero_approx(door.roll), "walking into the shutter neither opens it nor passes through (min z %.2f)" % min_z)
	player.global_position = Vector3(32.0, 0.95, -6.0)
	player.velocity = Vector3.ZERO
	await frames(4)
	var trig = main._nearest(2.5)
	expect(trig != null and trig.get("kind") == "enter" and trig.prompt() == "Open the Arcade", "shutter interact prompt is in range")
	# arrive on the board: Fony steps off while the shutter rolls, not after the fade
	player.skating = true
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await frames(3)
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
	expect(door.state == "opening" and not player.input_enabled, "E at the shutter starts the roll-up and takes input")
	expect(not player.skating, "the board comes off at the shutter, during the roll-up")
	expect(door.enter(main.flow) == false, "a second interact while opening is ignored")
	var peak := 0.0
	var faded := false
	for _i in 400:
		await get_tree().physics_frame
		peak = maxf(peak, door.roll)
		faded = faded or door.fade.color.a > 0.95
		if door.state == "inside":
			break
	expect(peak > 0.99 and faded, "shutter rolls fully up, then the screen fades to black (peak %.2f)" % peak)
	expect(door.state == "inside" and player.input_enabled and door.fade.color.a < 0.01, "fade back in hands input to the player inside")
	var inside: Node3D = door.interior
	expect(inside != null and inside.visible and inside.scene_file_path == "res://scenes/arcade_interior.tscn", "player is in the separate interior scene")
	expect(main.zone_at(player.global_position) == "ARCADE" and player.global_position.distance_to(inside.to_global(inside.spawn_local)) < 1.0, "interior spawn reads as the ARCADE zone")
	expect(not str(player.sprite_frame).begins_with("kickup"), "no kick-up plays on arrival inside (frame %s)" % player.sprite_frame)
	await frames(20)
	expect(player.is_on_floor(), "player stands on the interior floor")
	await _arcade_interior(main, inside)
	var exit_t = main._nearest(2.5)
	expect(exit_t != null and exit_t.get("kind") == "leave" and exit_t.prompt() == "Leave the Arcade", "interior exit prompt is in range")
	exit_t.interact(main.flow)
	expect(door.state == "leaving" and not player.input_enabled, "exit starts the fade out")
	for _i in 400:
		await get_tree().physics_frame
		if door.state == "closed":
			break
	expect(door.state == "closed" and is_zero_approx(door.roll), "shutter rolls back down behind the player")
	expect(player.input_enabled and player.global_position.z > -7.7 and absf(player.global_position.x - 32.0) < 1.5 and main.zone_at(player.global_position) != "OUTSIDE", "player is back on the deck outside")
	expect(not inside.visible and door.entries == 1 and door.exits == 1, "interior hides again; one entry and one exit")

## Arcade Phase 2: the furnished room, a playable cabinet opening the existing game, and back to the room.
func _arcade_interior(main, inside: Node3D) -> void:
	var player = main.player
	var ids := ["grind-the-terms", "tag-before-training", "cookie-wall", "bars-per-watt", "punk-arcade"]
	var have := 0
	for id in ids:
		if inside.cabinets.has(id) and inside.cabinets[id].is_in_group("interactable"):
			have += 1
	expect(have == ids.size(), "interior has the five playable cabinets got %d" % have)
	expect(int(inside.stats.get("batched_meshes", 99)) <= 12 and int(inside.stats.get("batched_tris", 0)) > 2000, "interior is furnished and batched %s" % str(inside.stats))
	var featured = inside.cabinets["punk-arcade"]
	var attract: MeshInstance3D = inside.get_node_or_null("AttractScreen")
	expect(featured.path == "demo/" and attract != null and attract.material_override.get_shader_parameter("attract") == true, "featured ZERO GAME THING PRO 2K runs the attract loop and links the Punk Arcade page")
	var hq_cab = main.world_sim.get_node("Cabinet")
	expect(main.zone_at(hq_cab.global_position) == "ARCADE" and hq_cab.global_position.distance_to(inside.to_global(inside.HQ_CABINET_LOCAL)) < 0.01, "the HQ placeholder cabinet stands inside the room")
	# walk up to Tag Before Training and press E
	var cab = inside.cabinets["tag-before-training"]
	player.global_position = cab.global_position + Vector3(0, 0.95, 1.1)
	player.velocity = Vector3.ZERO
	await frames(4)
	expect(main._nearest(2.5) == cab and cab.prompt() == "Play Tag Before Training", "cabinet prompt is in range")
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await frames(3)
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
	var ov = inside.overlay
	expect(ov.is_open() and ov.game_id == "tag-before-training" and ov.last_path == "games/tag-before-training/demo/embed.html", "E on the cabinet opens the existing game page %s" % ov.last_path)
	expect(not player.input_enabled and cab.prompt() == "" and main.flow.boundary.phase == "world", "the room holds input while the game is up")
	cab.interact(main.flow)
	expect(ov.opens == 1, "a second press while the game is up is ignored")
	ov.close()
	await frames(2)
	expect(not ov.is_open() and player.input_enabled and ov.closes == 1, "closing the game returns to the room")
	for id in ["grind-the-terms", "cookie-wall", "bars-per-watt"]:
		var c = inside.cabinets[id]
		expect(String(c.path).begins_with("games/" + id + "/demo/") and main.zone_at(c.global_position) == "ARCADE", "%s cabinet links its existing page" % id)
	# back to the shutter for the exit
	player.global_position = inside.to_global(inside.spawn_local)
	player.velocity = Vector3.ZERO
	await frames(6)

## JSON phase lists load as floats; frame indices are ints.
func _has_int(list: Array, value: int) -> bool:
	for item in list:
		if int(item) == value:
			return true
	return false

func _ride_ctx(facing_yaw: float) -> Dictionary:
	return {
		"facing_yaw": facing_yaw,
		"camera_x": 0.0,
		"camera_z": 4.0,
		"origin_x": 0.0,
		"origin_z": 0.0,
		"skating": true,
		"speed": 0.0,
		"accel": 0.0,
		"wish": 0.0,
		"on_floor": true,
		"vy": 0.0,
		"trick": "",
		"trick_time": 0.0,
		"flip_turns": 0.0,
		"bail_time": 0.0,
		"grind": false,
	}

func _fony_sprite() -> void:
	var anim = load("res://scripts/fony_sprite_anim.gd").new()
	anim.ensure_loaded()
	# Camera sits on +Z. Facing yaw is the rig yaw, whose -Z axis is forward.
	expect(anim.direction_name(PI, 0.0, 4.0, 0.0, 0.0) == "front", "sprite front faces the camera")
	expect(anim.direction_name(-PI * 0.75, 0.0, 4.0, 0.0, 0.0) == "front_right", "sprite front-right")
	expect(anim.direction_name(-PI * 0.5, 0.0, 4.0, 0.0, 0.0) == "right", "sprite right faces screen right")
	expect(anim.direction_name(-PI * 0.25, 0.0, 4.0, 0.0, 0.0) == "back_right", "sprite back-right")
	expect(anim.direction_name(0.0, 0.0, 4.0, 0.0, 0.0) == "back", "sprite back faces away")
	expect(anim.direction_name(PI * 0.25, 0.0, 4.0, 0.0, 0.0) == "back_left", "sprite back-left")
	expect(anim.direction_name(PI * 0.5, 0.0, 4.0, 0.0, 0.0) == "left", "sprite left faces screen left")
	expect(anim.direction_name(PI * 0.75, 0.0, 4.0, 0.0, 0.0) == "front_left", "sprite front-left")
	var boundary: String = anim.direction_name(-PI + PI / 8.0, 0.0, 4.0, 0.0, 0.0)
	expect(boundary == "front_right", "sprite sector boundary rounds away from front got %s" % boundary)
	# LOCAL puppet-v1 test build: the puppet bake overrides cruise, push, ollie, kick-up,
	# drop-in, walk, idle and (Phase 1e) grab and bail in all 8 views. Kickflip and grind stay v3.
	for dir_name in anim.DIRS:
		expect(anim.clips["cruise_" + dir_name].source == "puppet" and anim.clips["cruise_" + dir_name].frames.size() == 42 and anim.clips["cruise_" + dir_name].loop, "puppet cruise %s is the 42-frame Phase 1b balance loop" % dir_name)
		expect(anim.clips["push_" + dir_name].frames.size() == 19, "puppet push %s is a 19-frame stroke" % dir_name)
		expect(_same_cell(anim.clips["push_" + dir_name].frames[0], anim.clips["cruise_" + dir_name].frames[0]), "puppet push %s starts on the cruise drawing" % dir_name)
		expect(anim.clips["walk_" + dir_name].frames.size() == 22, "puppet walk %s is 22 frames" % dir_name)
		expect(anim.clips["ollie_" + dir_name].frames.size() == 20, "puppet ollie %s is 20 frames" % dir_name)
	expect(anim.clips.has("kickflip_left") and anim.clips.has("kickflip_right") and anim.clips["kickflip_left"].frames.size() == 6, "v3 kickflip has both sides")
	# Phase 1e: puppet grab (melon, left hand on the heel edge) and bail (fall and recover) in all 8 views.
	for dir_name in anim.DIRS:
		expect(anim.clips.has("grab_" + dir_name) and anim.clips["grab_" + dir_name].source == "puppet" and anim.clips["grab_" + dir_name].frames.size() == 14, "puppet grab %s is 14 frames" % dir_name)
		expect(anim.clips.has("bail_" + dir_name) and anim.clips["bail_" + dir_name].source == "puppet" and anim.clips["bail_" + dir_name].frames.size() == 15, "puppet bail %s is 15 frames" % dir_name)
		expect(_same_cell(anim.clips["bail_" + dir_name].frames[14], anim.clips["cruise_" + dir_name].frames[0]), "puppet bail %s ends on the cruise drawing" % dir_name)
		expect(_same_cell(anim.clips["grab_" + dir_name].frames[3], anim.clips["ollie_" + dir_name].frames[3]), "puppet grab %s crouches like the ollie" % dir_name)
	# Grind round: the puppet 50-50 (in / hold / out) replaces the three v3 grind paintings in all 8 views.
	for dir_name in anim.DIRS:
		var gc: Dictionary = anim.clips.get("grind_" + dir_name, {})
		expect(gc.get("source", "") == "puppet" and gc.frames.size() == 16 and gc.phases.has("in") and gc.phases.has("hold") and gc.phases.has("out"), "puppet 50-50 grind %s is 16 frames with in / hold / out" % dir_name)
		expect(str(gc.frames[0].get("atlas_file", "")) == "fony2d_puppet_v1_grind_atlas.png", "puppet grind %s lives in the grind atlas" % dir_name)
	expect(anim.clips.has("kickup_right") and anim.clips.has("dropin_right"), "v3 kick-up and drop-in have a right side")
	for dir_name in anim.DIRS:
		expect(anim.clips.has("idle_" + dir_name) and anim.clips["idle_" + dir_name].frames.size() == 24, "puppet idle breathes in %s" % dir_name)
	var away := _ride_ctx(0.0)
	away.speed = 9.0
	away.wish = 1.0
	var glide = load("res://scripts/fony_sprite_anim.gd").new()
	var glide_key: String = glide.step(0.05, away)
	expect(glide_key.begins_with("cruise_back#"), "riding away cruises on the new back cycle got %s" % glide_key)
	var cruise_frame: int = glide.frame_index
	glide.step(0.25, away)
	if glide.clips["cruise_back"].frames.size() > 1:
		expect(glide.frame_index != cruise_frame, "the away cruise advances got %s then %s" % [cruise_frame, glide.frame_index])
	else:
		expect(glide.frame_index == 0 and glide.key.begins_with("cruise_back#"), "the one-frame puppet cruise holds steady got %s" % glide.key)
	var stroke = load("res://scripts/fony_sprite_anim.gd").new()
	var pushing := _ride_ctx(0.0)
	pushing.speed = 2.0
	pushing.wish = 1.0
	pushing.accel = 1.0
	var push_key: String = stroke.step(0.05, pushing)
	expect(push_key.begins_with("push_back#"), "a push from a stop, seen from behind, uses push_back got %s" % push_key)
	pushing.speed = 9.0
	pushing.accel = 0.0
	push_key = stroke.step(0.08, pushing)
	expect(push_key.begins_with("push_back#"), "a started push stroke finishes at top speed got %s" % push_key)
	var returned := false
	for _i in 30:
		stroke.step(0.05, pushing)
		if stroke.key.begins_with("cruise_back#"):
			returned = true
			break
	expect(returned and stroke.cruise_gap > 0.0, "the stroke returns to the away cruise and holds got %s gap=%s" % [stroke.key, stroke.cruise_gap])
	stroke.step(0.02, pushing)
	expect(stroke.key.begins_with("cruise_"), "cruise holds between push strokes got %s" % stroke.key)
	var left_push = load("res://scripts/fony_sprite_anim.gd").new()
	var left_ctx := _ride_ctx(PI * 0.5)
	left_ctx.speed = 2.0
	left_ctx.wish = 1.0
	left_ctx.accel = 1.0
	left_push.step(0.05, left_ctx)
	var right_push = load("res://scripts/fony_sprite_anim.gd").new()
	var right_ctx := _ride_ctx(-PI * 0.5)
	right_ctx.speed = 2.0
	right_ctx.wish = 1.0
	right_ctx.accel = 1.0
	right_push.step(0.05, right_ctx)
	expect(left_push.clip == "push_left" and right_push.clip == "push_right", "both sides have their own push clip left=%s right=%s" % [left_push.clip, right_push.clip])
	expect(int(left_push.clips["push_left"].frames[0].rect[0]) != int(right_push.clips["push_right"].frames[0].rect[0]), "left and right push frames are different paintings")
	await _sprite_timing()
	var ollie = load("res://scripts/fony_sprite_anim.gd").new()
	var air := _ride_ctx(0.0)
	air.trick = "ollie"
	air.on_floor = false
	air.vy = 0.0
	air.trick_time = 0.21
	ollie.step(0.016, air)
	expect(ollie.clip == "ollie_back" and ollie.frame_index == 8, "an ollie seen from behind is at the top of the rise halfway through the air got %s#%s" % [ollie.clip, ollie.frame_index])
	air.trick = "land"
	air.on_floor = true
	air.vy = -1.0
	air.trick_time = 0.0
	ollie.step(0.02, air)
	expect(ollie.frame_index == 14, "landing from behind starts on the land frame got %s" % ollie.frame_index)
	ollie.step(0.11, air)
	expect(ollie.frame_index == 17, "the away ollie absorbs into its recover frame got %s" % ollie.frame_index)
	var grabber = load("res://scripts/fony_sprite_anim.gd").new()
	var grabbing := _ride_ctx(0.0)
	grabbing.trick = "crouch"
	grabbing.trick_next = "grab"
	grabbing.on_floor = true
	grabber.step(0.016, grabbing)
	expect(grabber.clip == "grab_back" and grabber.frame_index == 0, "a grab crouch uses the grab phase got %s#%s" % [grabber.clip, grabber.frame_index])
	grabbing.trick = "grab"
	grabbing.trick_next = ""
	grabbing.on_floor = false
	grabbing.vy = 0.5
	grabbing.trick_time = 0.2
	grabber.step(0.016, grabbing)
	expect(grabber.frame_index >= 8 and grabber.frame_index <= 10, "an airborne grab holds the grab frames got %s" % grabber.frame_index)
	grabbing.vy = -4.0
	grabber.step(0.016, grabbing)
	expect(grabber.frame_index >= 11 and grabber.frame_index <= 13, "a falling grab releases got %s" % grabber.frame_index)
	grabbing.grab_held = true
	grabber.step(0.016, grabbing)
	expect(grabber.frame_index == 10, "a grab still held keeps the hand on the board got %s" % grabber.frame_index)
	var flip = load("res://scripts/fony_sprite_anim.gd").new()
	air.trick = "flip"
	air.flip_turns = 0.5
	air.vy = 2.0
	flip.step(0.016, air)
	expect(flip.clip == "kickflip_back" and flip.frame_index == 3, "a kickflip seen from behind tracks the spin got %s#%s" % [flip.clip, flip.frame_index])
	var walker = load("res://scripts/fony_sprite_anim.gd").new()
	var walking := _ride_ctx(0.0)
	walking.skating = false
	walking.speed = 3.0
	walker.step(0.02, walking)
	var walk_frame: int = walker.frame_index
	expect(walker.clip == "walk_back", "walking away uses the walk cycle got %s" % walker.clip)
	walker.step(0.3, walking)
	expect(walker.frame_index != walk_frame, "the walk cycle advances")
	var grinder = load("res://scripts/fony_sprite_anim.gd").new()
	var grinding := _ride_ctx(0.0)
	grinding.grind = true
	grinding.on_floor = false
	grinding.speed = 8.0
	grinder.step(0.05, grinding)
	expect(grinder.clip == "grind_back", "grinding away uses grind_back got %s" % grinder.clip)
	expect(grinder.frame_index == 0, "the grind starts on the touchdown frame got %s" % grinder.frame_index)
	grinding.grind_t = 0.5
	grinder.step(0.05, grinding)
	var hold_frames: Array = grinder._clip("grind_back").phases.hold
	expect(_has_int(hold_frames, grinder.frame_index), "0.5 s into the grind plays the hold loop got %s" % grinder.frame_index)
	grinding.grind = false
	grinding.grind_out = 0.05
	grinding.vy = 3.0
	grinder.step(0.05, grinding)
	expect(grinder.clip == "grind_back" and _has_int(grinder._clip("grind_back").phases.out, grinder.frame_index), "popping out shows the grind out frames got %s#%s" % [grinder.clip, grinder.frame_index])
	grinding.grind_out = -1.0
	grinder.step(0.05, grinding)
	expect(grinder.clip.begins_with("ollie_"), "after the out frames the air uses the ollie frames got %s" % grinder.clip)
	var bailer = load("res://scripts/fony_sprite_anim.gd").new()
	var bailing := _ride_ctx(0.0)
	bailing.skating = false
	bailing.trick = "bail"
	bailing.bail_time = 0.6
	bailing.on_floor = true
	bailer.step(0.016, bailing)
	expect(bailer.clip == "bail_back", "a bail seen from behind uses bail_back got %s" % bailer.clip)
	var front_glide = load("res://scripts/fony_sprite_anim.gd").new()
	var facing := _ride_ctx(PI)
	facing.speed = 9.0
	front_glide.step(0.05, facing)
	expect(front_glide.clip == "cruise_front", "riding toward the camera uses cruise_front got %s" % front_glide.clip)
	var diagonal = load("res://scripts/fony_sprite_anim.gd").new()
	var front_left := _ride_ctx(PI * 0.75)
	front_left.speed = 9.0
	diagonal.step(0.05, front_left)
	var want_diag := "cruise_front_left" if diagonal.clips.has("cruise_front_left") else "cruise_front"
	expect(diagonal.clip == want_diag, "front-left cruise uses %s got %s" % [want_diag, diagonal.clip])
	var side_flip = load("res://scripts/fony_sprite_anim.gd").new()
	var side_air := _ride_ctx(PI * 0.5)
	side_air.trick = "flip"
	side_air.on_floor = false
	side_air.flip_turns = 0.5
	side_flip.step(0.016, side_air)
	expect(side_flip.clip == "kickflip_left" and side_flip.frame_index == 3, "a left kickflip uses the side strip got %s#%s" % [side_flip.clip, side_flip.frame_index])
	var right_grind = load("res://scripts/fony_sprite_anim.gd").new()
	var right_rail := _ride_ctx(-PI * 0.5)
	right_rail.grind = true
	right_rail.on_floor = false
	right_grind.step(0.05, right_rail)
	expect(right_grind.clip == "grind_right", "grinding to the right uses grind_right got %s" % right_grind.clip)
	var front_bail = load("res://scripts/fony_sprite_anim.gd").new()
	var facing_bail := _ride_ctx(PI)
	facing_bail.skating = false
	facing_bail.trick = "bail"
	facing_bail.bail_time = 0.3
	front_bail.step(0.016, facing_bail)
	expect(front_bail.clip == "bail_front" and front_bail.frame_index == 7, "a front bail plays the fall got %s#%s" % [front_bail.clip, front_bail.frame_index])
	var image := Image.new()
	var loaded := image.load("res://assets/library/fony2d/fony2d_v3_atlas.png")
	var atlas_w := image.get_width()
	var atlas_h := image.get_height()
	expect(loaded == OK and atlas_w == 4096 and atlas_h == 1791, "v5 atlas is 4096x1791 got %s %sx%s" % [loaded, atlas_w, atlas_h])
	expect(anim.atlas_size == Vector2i(atlas_w, atlas_h), "catalog atlas size matches the png")
	var outside := 0
	for clip_name in anim.clips:
		var info: Dictionary = anim.clips[clip_name]
		var frames: Array = info.get("frames", [])
		for fr in frames:
			var rect: Array = fr.rect
			var x := float(rect[0])
			var y := float(rect[1])
			var w := float(rect[2])
			var h := float(rect[3])
			# Puppet frames live in their own atlas files; check each against its own sheet.
			var aw := float(atlas_w)
			var ah := float(atlas_h)
			if str(fr.get("atlas", "v3")) == "puppet":
				var sheet := _atlas_image(fr)
				aw = float(sheet.get_width()) if sheet != null else -1.0
				ah = float(sheet.get_height()) if sheet != null else -1.0
			if x < 0.0 or y < 0.0 or x + w > aw or y + h > ah or w <= 0.0 or h <= 0.0:
				outside += 1
	expect(outside == 0, "every frame rect lies inside the atlas outside=%s" % outside)
	var states := ["idle", "walk", "cruise", "push", "kickup", "dropin", "ollie", "kickflip", "grab", "grind", "bail"]
	var unresolved := 0
	var borrowed_left := 0
	for state_name in states:
		for dir_name in anim.DIRS:
			var resolved: String = anim._resolve(str(state_name), str(dir_name))
			if not anim.clips.has(resolved):
				unresolved += 1
			if (str(dir_name) == "right" or str(dir_name) == "front_right" or str(dir_name) == "back_right") and resolved.contains("_left"):
				borrowed_left += 1
	expect(unresolved == 0, "every state resolves in all 8 directions unresolved=%s" % unresolved)
	expect(borrowed_left == 0, "right-facing views never use a left painting borrowed=%s" % borrowed_left)
	var kick = load("res://scripts/fony_sprite_anim.gd").new()
	var stopped := _ride_ctx(0.0)
	stopped.skating = true
	kick.step(0.01, stopped)
	stopped.skating = false
	stopped.speed = 0.0
	stopped.wish = 0.0
	var kick_key: String = kick.step(0.016, stopped)
	expect(kick_key.begins_with("kickup_back#"), "stopping while seen from behind plays kickup_back got %s" % kick_key)
	kick.step(0.9, stopped)
	expect(kick.phase == "" and kick.clip.begins_with("idle_"), "kick-up hands off to idle got %s" % kick.clip)
	stopped.skating = true
	var drop_key: String = kick.step(0.016, stopped)
	expect(drop_key.begins_with("dropin_back#"), "starting while seen from behind plays dropin_back got %s" % drop_key)
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/library/fony2d/frames_v3.json"))
	expect(typeof(catalog) == TYPE_DICTIONARY and catalog.get("animations", {}).size() == 52, "v3 catalog has 52 animations")
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(20, 1, 20), Palette.GROUND)
	var player = _player(host, Vector3(0, 0.4, 0))
	for _i in 40:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	player.velocity = Vector3.ZERO
	await frames(4)
	expect(player.get_node_or_null("Fony") != null and player.get_node_or_null("FonySprite") != null, "mesh rig and painted sprite both exist")
	expect(not player.rig.visible and player.painted_sprite.visible, "the test shows the sprite and keeps the rig")
	expect(player.sprite_frame.begins_with("cruise_") or player.sprite_frame.begins_with("skate_"), "standing on the board uses a ride frame got %s" % player.sprite_frame)
	expect(not player.get_node("FonySprite/Card").flip_h, "the sprite is never mirrored")
	await _anchor_depth(player)
	player.set_painted_sprite(false)
	expect(player.rig.visible and not player.painted_sprite.visible, "the pause toggle brings the mesh rig back")
	player.set_painted_sprite(true)
	player.skating = false
	await frames(1)
	expect(player.sprite_frame.begins_with("kickup_"), "the live body plays a kick-up when skating stops got %s" % player.sprite_frame)
	player.painted_sprite.anim.phase = ""
	player.painted_sprite.anim.trans_time = 0.0
	player.skating = true
	await frames(1)
	expect(player.sprite_frame.begins_with("dropin_"), "the live body plays a drop-in when skating starts got %s" % player.sprite_frame)
	host.queue_free()
	await frames(2)

## Phase 1d (LOCAL puppet build): the 3D-lifted views were baked with the anchor moved toward the camera,
## so the card has to stand that far forward for the drawn board to sit on the body. Orbit the chase camera
## across every view boundary and check where the card draws the body's ground point.
func _anchor_depth(player) -> void:
	var fs = player.painted_sprite
	var anim = fs.anim
	var depth_ok := true
	for dir_name in anim.DIRS:
		for c in ["cruise", "push", "ollie", "walk"]:
			for fr in anim.clips["%s_%s" % [c, dir_name]].frames:
				var gd := float(fr.get("ground_depth_m", -1.0))
				var bp: Array = fr.get("body_px", [])
				# Phase 1c: every riding clip is the side-on stance bake in all 8 views, so the sides carry a ground depth (~0.2 m).
				# Phase 1e: side walk / idle / carry come from the same 3D solve (one carry pose in all 8 views), so they do too.
				if dir_name == "left" or dir_name == "right":
					depth_ok = depth_ok and gd > 0.15 and gd < 0.3 and bp.size() == 2 and float(bp[1]) < -15.0
				else:
					depth_ok = depth_ok and gd > 0.3 and gd < 0.55 and bp.size() == 2 and float(bp[1]) < -30.0
	expect(depth_ok, "puppet frames carry their baked ground depth (sides 0.15-0.3 m, 3D views 0.3-0.55 m)")
	var cam: Camera3D = player.get_node("CameraPivot/SpringArm/Camera")
	player.external_move_active = true
	player.external_move = Vector2.ZERO
	var yaw0: float = player.camera_yaw
	var worst := 0.0
	var worst_jump := 0.0
	var worst_off := 0.0
	var views := {}
	for k in 8:
		for eps in [-0.6, 0.6]:
			var yaw := deg_to_rad(22.5 + 45.0 * k + eps)
			player.camera_yaw = yaw
			await frames(2)
			var facing: float = player.rig.global_rotation.y
			var o: Vector3 = fs.global_position
			var dir: String = anim.direction_name(facing, cam.global_position.x, cam.global_position.z, o.x, o.z)
			views[dir] = true
			for c in ["cruise", "push"]:
				var name := "%s_%s" % [c, dir]
				var hits := []
				for i in [0, 8, 14]:
					anim.clip = name
					anim.frame_index = i
					fs._apply(false, cam)
					var fr: Dictionary = anim.current_frame()
					var bp: Array = fr.get("body_px", [0.0, 0.0])
					var ground_y: float = o.y + fs.foot_local_y
					var hit := _ray_ground(cam, _card_px(fs, fr, cam, Vector2(float(bp[0]), float(bp[1]))), ground_y)
					var err := Vector2(hit.x - o.x, hit.z - o.z)
					worst = maxf(worst, err.length())
					fs.depth_fix = false
					fs.plane_anchor = false
					fs._apply(false, cam)
					var old_hit := _ray_ground(cam, _card_px(fs, fr, cam, Vector2(float(bp[0]), float(bp[1]))), ground_y)
					worst_off = maxf(worst_off, Vector2(old_hit.x - o.x, old_hit.z - o.z).length())
					fs.depth_fix = true
					fs.plane_anchor = true
					hits.append(err)
				views["%s|%d" % [c, k]] = views.get("%s|%d" % [c, k], []) + [hits[0]]
	for k in 8:
		for c in ["cruise", "push"]:
			var pair: Array = views["%s|%d" % [c, k]]
			if pair.size() == 2:
				worst_jump = maxf(worst_jump, (pair[1] - pair[0]).length())
	player.camera_yaw = yaw0
	await frames(2)
	expect(views.size() >= 8 + 16, "the orbit crosses all 8 view boundaries got %s" % views.size())
	expect(worst < 0.03, "the card draws his ground point on the physics body in every view got %.3f m (pre-1d %.3f m)" % [worst, worst_off])
	expect(worst_off > 0.3, "pre-1d placement is still measurable for comparison got %.3f m" % worst_off)
	expect(worst_jump < 0.03, "the drawn ground point does not jump across a view boundary got %.3f m" % worst_jump)
	var side_slip := Vector2(fs.sprite.position.x - fs.depth_offset.x, fs.sprite.position.z - fs.depth_offset.z).length()
	expect(side_slip < 0.0001 and absf(fs.sprite.offset.y) < 0.0001, "the sideways anchor lives in the billboard plane, not on local X got %.4f" % side_slip)

func _card_px(fs, fr: Dictionary, cam: Camera3D, px: Vector2) -> Vector3:
	var s: Sprite3D = fs.sprite
	var rect: Array = fr.get("rect", [0, 0, 1, 1])
	var off: Array = fr.get("anchor_offset", [0.0, 0.0])
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var sc := float(fr.get("atlas_scale", 0.5))
	var vx := (-float(off[0]) + px.x * sc - float(rect[2]) * 0.5 + s.offset.x) * s.pixel_size
	var vy := (float(rect[3]) * 0.5 + float(off[1]) - px.y * sc + s.offset.y) * s.pixel_size
	return s.global_position + right * vx + Vector3.UP * vy

func _ray_ground(cam: Camera3D, p: Vector3, plane_y: float) -> Vector3:
	var c := cam.global_position
	var d := p - c
	return c + d * ((plane_y - c.y) / d.y) if absf(d.y) > 1e-6 else p

func _same_cell(a: Dictionary, b: Dictionary) -> bool:
	if a.get("anchor_offset") != b.get("anchor_offset"):
		return false
	var ra: Array = a.rect
	var rb: Array = b.rect
	if int(ra[2]) != int(rb[2]) or int(ra[3]) != int(rb[3]):
		return false
	var ia := _atlas_image(a)
	var ib := _atlas_image(b)
	if ia == null or ib == null:
		return false
	var ca := ia.get_region(Rect2i(int(ra[0]), int(ra[1]), int(ra[2]), int(ra[3])))
	var cb := ib.get_region(Rect2i(int(rb[0]), int(rb[1]), int(rb[2]), int(rb[3])))
	return ca.get_data() == cb.get_data()

var _atlas_cache := {}

func _atlas_image(fr: Dictionary) -> Image:
	var file := str(fr.get("atlas_file", ""))
	var path := "res://assets/library/fony2d/" + (file if file != "" else "fony2d_v3_atlas.png")
	if not _atlas_cache.has(path):
		var img := Image.new()
		_atlas_cache[path] = img if img.load(path) == OK else null
	return _atlas_cache[path]

## Phase 1a: the sprite follows the game clock. Each check drives the anim the way
## the live body does (one 60 Hz tick at a time) and times what is shown.
func _sprite_timing() -> void:
	var player_script = load("res://scripts/player_controller.gd")
	var pop: float = player_script.OLLIE_POP_VELOCITY
	var g: float = player_script.GRAVITY
	var crouch_s: float = player_script.OLLIE_CROUCH_S
	var airtime := 2.0 * pop / g
	expect(absf(airtime - 0.42) < 0.03 and absf(pop * pop / (2.0 * g) - 0.4) < 0.03, "ollie pop gives about 0.42 s of air and a 0.4 m apex air=%s" % airtime)
	var dt := 1.0 / 60.0
	# Crouch winds down from the ride frame to the crouch frame within the crouch time.
	var crouching = load("res://scripts/fony_sprite_anim.gd").new()
	var c := _ride_ctx(0.0)
	c.trick = "crouch"
	c.trick_next = "ollie"
	var crouch_frames := []
	var tt := 0.0
	while tt < crouch_s:
		c.trick_time = tt
		crouching.step(dt, c)
		if crouch_frames.is_empty() or crouch_frames[-1] != crouching.frame_index:
			crouch_frames.append(crouching.frame_index)
		tt += dt
	expect(crouch_frames == [0, 1, 2, 3], "ollie crouch plays #0-#3 inside %s s got %s" % [crouch_s, crouch_frames])
	# Air: every pop, rise and fall frame shows, none longer than two shares of the air.
	var flying = load("res://scripts/fony_sprite_anim.gd").new()
	var a := _ride_ctx(0.0)
	a.trick = "ollie"
	a.on_floor = false
	var seen := {}
	var order := []
	tt = 0.0
	while tt < airtime:
		a.trick_time = tt
		a.vy = pop - g * tt
		flying.step(dt, a)
		seen[flying.frame_index] = int(seen.get(flying.frame_index, 0)) + 1
		if order.is_empty() or order[-1] != flying.frame_index:
			order.append(flying.frame_index)
		tt += dt
	var longest := 0
	for k in seen:
		longest = maxi(longest, int(seen[k]))
	expect(order == [4, 5, 6, 7, 8, 9, 10, 11, 12, 13], "ollie air walks pop, rise and fall in order got %s" % [order])
	expect(float(longest) * dt <= 2.0 * airtime / 10.0 + dt, "no ollie air frame holds past its share longest=%s s" % (float(longest) * dt))
	# Push: swing frames at the authored 24 fps, foot-down frames at ground speed.
	for speed in [2.0, 5.0]:
		var pusher = load("res://scripts/fony_sprite_anim.gd").new()
		var p := _ride_ctx(0.0)
		p.speed = speed
		p.wish = 1.0
		var swing := 0.0
		var contact := 0.0
		var total := 0.0
		var started := false
		for _i in 200:
			pusher.step(dt, p)
			if pusher.visual_state == "push":
				started = true
				total += dt
				if pusher.frame_index >= 6 and pusher.frame_index < 12:
					contact += dt
				elif pusher.frame_index < 6:
					swing += dt
			elif started:
				break
		var want_contact: float = 6.0 * pusher.PUSH_FOOT_M_PER_FRAME / speed
		expect(absf(swing - 0.25) <= 2.0 * dt, "push wind-up #0-#5 plays at the authored 24 fps at %s m/s got %s s" % [speed, swing])
		expect(absf(contact - want_contact) <= 2.0 * dt, "push foot-down #6-#11 lasts %s s at %s m/s so the sole keeps pace got %s s" % [want_contact, speed, contact])
	var fast = load("res://scripts/fony_sprite_anim.gd").new()
	var f := _ride_ctx(0.0)
	f.speed = 6.5
	f.wish = 1.0
	f.accel = 5.0
	fast.step(dt, f)
	expect(fast.visual_state == "cruise", "no new push stroke above 6 m/s got %s" % fast.key)
	f.speed = 5.5
	fast.step(dt, f)
	expect(fast.visual_state == "push", "a push stroke starts below 6 m/s got %s" % fast.key)
	await get_tree().process_frame

## Phase 2 (LOCAL puppet test): quarter-pipe transition riding on the library pipe (+X climbs, origin = bottom of the curve).
func _transition() -> void:
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(60, 1, 60), Palette.GROUND)
	var pipe: Node3D = load("res://assets/library/quarter_pipe/quarter_pipe.tscn").instantiate()
	host.add_child(pipe)
	await frames(2)
	var info: Dictionary = pipe.profile_info()
	expect(absf(float(info.lip_height) - 2.4 * (1.0 - cos(deg_to_rad(70.0)))) < 0.001 and absf(float(info.lip_arc) - 2.4 * deg_to_rad(70.0)) < 0.001 and float(info.deck_length) == 1.6, "quarter pipe reports its profile %s" % info)
	var cl: PackedVector3Array = pipe.coping_line()
	expect(cl.size() == 2 and absf(cl[0].distance_to(cl[1]) - 7.0) < 0.001 and absf(cl[0].y - float(info.lip_height)) < 0.001, "quarter pipe reports its coping line %s" % cl)
	var mat: ShaderMaterial = pipe.get_node("Shell").material_override
	expect(absf(float(mat.get_shader_parameter("fill_light")) - 1.3) < 0.001, "quarter pipe face is lifted (fill_light 1.3; measured luma 129-140)")
	var g := 18.0
	var lip_h: float = pipe.lip_height()
	# coasting (no stick) entries below the lip: height reached follows v^2 / 2g, then he rolls back down fakie without turning
	for v0 in [4.0, 5.0, 6.0, 7.0]:
		var r: Dictionary = await _ride_pipe(host, v0, 0.0)
		var pred: float = r.entry * r.entry / (2.0 * g)
		expect(r.peak > pred * 0.85 and r.peak < pred * 1.02, "transition: entry %.2f m/s reaches %.3f m (v^2/2g = %.3f)" % [r.entry, r.peak, pred])
		expect(not r.lip and r.exited and r.fakie and r.exit_speed > 0.5 and r.turn < 0.5, "transition: entry %.2f rolls back down fakie, facing unchanged (exit %.2f m/s, fakie %s, turn %.2f deg)" % [r.entry, r.exit_speed, r.fakie, r.turn])
		expect(r.max_lean > 25.0 and r.card_tilted and r.card_upright_after, "transition: card leans with the wall (max %.0f deg) and stands back up on the flat" % r.max_lean)
		expect(not r.pushed, "transition: no push frames on the wall")
	# fast entry: off the coping straight up, back down into the transition (not the deck, not the flat)
	var fast: Dictionary = await _ride_pipe(host, 9.0, 0.0)
	var v_lip_pred := sqrt(maxf(fast.entry * fast.entry - 2.0 * g * lip_h - 2.0 * 0.35 * float(info.lip_arc), 0.0))
	expect(fast.lip and absf(fast.launch - v_lip_pred) < 0.12 * v_lip_pred, "transition: lip launch at %.2f m/s from a %.2f m/s entry (predicted %.2f)" % [fast.launch, fast.entry, v_lip_pred])
	var air_pred: float = fast.launch * fast.launch / (2.0 * g)
	expect(fast.air_above > 0.3 and absf(fast.air_above - air_pred) < 0.08, "transition: %.3f m above the coping (v^2/2g = %.3f), %.2f s in the air" % [fast.air_above, air_pred, fast.air_s])
	expect(fast.landing == "transition" and fast.land_y < lip_h and fast.land_y > 0.3 and not fast.bailed, "transition: lip launch lands back in the transition at %.2f m (landing=%s)" % [fast.land_y, fast.landing])
	expect(fast.exited and fast.fakie and fast.turn < 0.5, "transition: rides out of the lip launch fakie without spinning (turn %.2f deg)" % fast.turn)
	# pumping (stick held on the lower transition) climbs higher than coasting from the same entry
	var coast: Dictionary = await _ride_pipe(host, 6.0, 0.0)
	var pumped: Dictionary = await _ride_pipe(host, 6.0, 1.0)
	expect(pumped.peak > coast.peak + 0.15 and absf(pumped.entry - coast.entry) < 0.6, "transition: pumping climbs higher (%.3f m vs %.3f m coasting, entries %.2f / %.2f)" % [pumped.peak, coast.peak, pumped.entry, coast.entry])
	expect(pumped.pump_frames > 0, "transition: pumping shows the pump frames (%d)" % pumped.pump_frames)
	# landing on the deck is a bail (plan)
	var player = _player(host, Vector3(-3.0, 0.5, 0))
	await frames(16)
	player.skating = true
	player.pipe_air = true
	player.pipe_air_pipe = pipe
	player.global_position = pipe.to_global(Vector3(pipe.lip_local().x + 0.8, lip_h + 0.6, 0.0)) - Vector3.UP * 0.325
	player.velocity = Vector3.ZERO
	var deck_bail := false
	for _i in 60:
		await get_tree().physics_frame
		if player.last_landing == "deck":
			deck_bail = player.trick == "bail" and player.last_bail_reason == "deck_landing"
			break
	expect(deck_bail, "transition: landing on the deck is a bail (landing=%s trick=%s)" % [player.last_landing, player.trick])
	player.queue_free()
	host.queue_free()
	await frames(2)

## One run at the pipe: rolling at v0 m/s on the flat 1.5 m before the curve, stick = 0 (coast) or 1 (pump on the wall).
func _ride_pipe(host: Node, v0: float, stick: float) -> Dictionary:
	var player = _player(host, Vector3(-3.0, 0.2, 0))
	await frames(18)
	player.skating = true
	player.camera_yaw = -PI * 0.5
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	await frames(1)
	player.global_position = Vector3(-1.5, player.global_position.y, 0)
	player.velocity = Vector3(v0, 0, 0)
	player.external_move = Vector2(0, stick)
	var face0: float = player.rig.global_rotation.y
	var r := {"entry": 0.0, "peak": 0.0, "lip": false, "launch": 0.0, "air_above": 0.0, "air_s": 0.0, "landing": "", "land_y": -1.0,
		"exited": false, "fakie": false, "exit_speed": 0.0, "turn": 0.0, "max_lean": 0.0, "card_tilted": false, "card_upright_after": false,
		"pushed": false, "pump_frames": 0, "bailed": false}
	var entered := false
	var air := 0.0
	for _i in 420:
		if not entered and player.ramp_mode == "":
			player.velocity.x = v0
		await get_tree().physics_frame
		if player.ramp_mode == "ride":
			entered = true
			r.max_lean = maxf(r.max_lean, rad_to_deg(player.ramp_lean_up.angle_to(Vector3.UP)))
			if player.painted_sprite.sprite.billboard == BaseMaterial3D.BILLBOARD_DISABLED:
				r.card_tilted = true
			if str(player.sprite_frame).begins_with("push_"):
				r.pushed = true
			if str(player.sprite_frame).begins_with("pump_"):
				r.pump_frames += 1
		if player.pipe_air:
			air += 1.0 / 60.0
			r.air_s = maxf(r.air_s, air)
		if player.trick == "bail":
			r.bailed = true
		r.peak = maxf(r.peak, player.ramp_peak_y)
		r.turn = maxf(r.turn, absf(rad_to_deg(wrapf(player.rig.global_rotation.y - face0, -PI, PI))))
		if r.landing == "" and player.last_landing != "":
			r.landing = player.last_landing
			r.land_y = player.global_position.y + 0.325
		if entered and player.ramp_mode == "" and not player.pipe_air and player.global_position.x < -0.3:
			r.exited = true
			r.fakie = player.is_fakie()
			r.exit_speed = Vector2(player.velocity.x, player.velocity.z).length()
			await frames(3)
			r.card_upright_after = player.painted_sprite.sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y
			break
	r.entry = player.ramp_entry_speed
	for e in player.ramp_events:
		if e.what == "lip_launch":
			r.lip = true
	r.launch = player.lip_launch_speed
	r.air_above = player.air_peak_above_lip
	player.queue_free()
	await frames(2)
	return r

func _host() -> Node3D:
	var host := Node3D.new()
	add_child(host)
	return host

func _player(host: Node, pos: Vector3):
	var player = load("res://scenes/player.tscn").instantiate()
	player.position = pos
	host.add_child(player)
	return player

## Phase 3 (LOCAL puppet test): quarter-pipe drop-in from the deck (qp_setup, qp_dropin, qp_bail). Library pipe at the origin:
## +X climbs, the lip edge is at local (2.255, 1.579), the deck runs 1.6 m behind it; facing the ramp = facing -X.
func _dropin() -> void:
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(60, 1, 60), Palette.GROUND)
	var pipe: Node3D = load("res://assets/library/quarter_pipe/quarter_pipe.tscn").instantiate()
	host.add_child(pipe)
	await frames(2)
	var lip: Vector3 = pipe.lip_local()
	# manifest: three puppet clips in all 8 views, never mirrored (each view is its own bake)
	var probe = _player(host, Vector3(-3.0, 0.2, 0))
	await frames(4)
	var anim = probe.painted_sprite.anim
	var clips_ok := true
	for dir_name in anim.DIRS:
		for spec in [["qp_setup", 23], ["qp_dropin", 17], ["qp_bail", 36]]:
			var nm := "%s_%s" % [spec[0], dir_name]
			clips_ok = clips_ok and anim.clips.has(nm) and anim.clips[nm].source == "puppet" and anim.clips[nm].frames.size() == int(spec[1])
	expect(clips_ok, "drop-in: qp_setup (23), qp_dropin (17), qp_bail (36) puppet clips in all 8 views")
	var ph: Dictionary = anim.clips["qp_dropin_back"].phases
	expect(ph.get("commit", []).size() == 9 and ph.get("roll", []).size() == 8 and _ints(ph.get("roll_deg", [])) == [70, 60, 50, 40, 30, 20, 10, 0] and absf(float(ph.get("roll_start_m", 0)) - probe.QP_ROLL_START_M) < 0.001, "drop-in: qp_dropin phases (9 commit frames, 8 roll-out frames at 70..0 deg, roll start %.4f m)" % float(ph.get("roll_start_m", 0)))
	# the cruise frames are depth-projected (drawn from a camera nearer the body, card moved toward the camera); the
	# last roll-out frame is the same pose drawn with no depth shift, so its drawing is the cruise drawing / body_scale
	var roll_end_ok := true
	var roll_end_worst := 0.0
	for dir_name in anim.DIRS:
		var fa: Dictionary = anim.clips["qp_dropin_" + dir_name].frames[16]
		var fb: Dictionary = anim.clips["cruise_" + dir_name].frames[0]
		var bs := float(fb.get("body_scale", 1.0))
		var dw := absf(float(fa.rect[2]) * bs - float(fb.rect[2]))
		var dh := absf(float(fa.rect[3]) * bs - float(fb.rect[3]))
		roll_end_worst = maxf(roll_end_worst, maxf(dw, dh))
		roll_end_ok = roll_end_ok and dw <= 2.0 and dh <= 2.0
	expect(roll_end_ok, "drop-in: the last roll-out frame is the cruise pose in every view (size off by <= %.1f atlas px after body_scale)" % roll_end_worst)
	var depth_ok := true
	for dir_name in anim.DIRS:
		for c in ["qp_setup", "qp_dropin", "qp_bail"]:
			for fr in anim.clips["%s_%s" % [c, dir_name]].frames:
				depth_ok = depth_ok and absf(float(fr.get("ground_depth_m", 1.0))) < 0.0001
	expect(depth_ok, "drop-in: qp frames are drawn with no depth shift (their rig origin is pinned straight on the pipe)")
	probe.queue_free()
	await frames(2)
	# spot detection: on the deck within 0.5 m of the coping, facing the ramp within 35 deg
	var p = await _deck_player(host, pipe, 0.3, 0.0, 0.0)
	expect(not p.qp_spot().is_empty(), "drop-in: standing 0.3 m behind the coping facing the ramp is a drop-in spot")
	p.rig.face_world(PI * 0.5 + deg_to_rad(50.0))
	await frames(1)
	expect(p.qp_spot().is_empty(), "drop-in: facing 50 deg off the ramp is not a spot")
	p.queue_free()
	await frames(2)
	p = await _deck_player(host, pipe, 0.8, 0.0, 0.0)
	expect(p.qp_spot().is_empty(), "drop-in: 0.8 m behind the coping is not a spot")
	p.skate_toggle_pressed()
	await frames(2)
	expect(p.qp_state == "" and p.skating, "drop-in: Shift away from the spot is the normal board drop (skating=%s qp=%s)" % [p.skating, p.qp_state])
	p.queue_free()
	await frames(2)
	# ten scripted commits from different marks (plan: 10 of 10 rolling forward on the flat at 6.5-7.8 m/s within 0.9 s)
	var marks := [[0.05, 0.0, 0.0], [0.15, 25.0, -1.5], [0.25, -30.0, 1.5], [0.35, 10.0, 2.2], [0.45, -15.0, -2.2],
		[0.1, 34.0, 0.6], [0.2, -34.0, -0.6], [0.3, 5.0, 1.0], [0.4, -5.0, -1.0], [0.5, 0.0, 0.0]]
	var good := 0
	var worst := {"speed_lo": 99.0, "speed_hi": 0.0, "t": 0.0, "jump": 0.0, "tail": 99.0}
	var first: Dictionary = {}
	for m in marks:
		var r: Dictionary = await _dropin_run(host, pipe, float(m[0]), float(m[1]), float(m[2]))
		if first.is_empty():
			first = r
		var ok: bool = r.rolled and not r.fakie and r.exit_speed >= 6.5 and r.exit_speed <= 7.8 and r.exit_t <= 0.9 and r.tail_s >= 0.3 and r.jump < 0.1 and r.turn < 1.0
		if ok:
			good += 1
		else:
			print("  drop-in run failed: ", m, " ", r)
		worst.speed_lo = minf(worst.speed_lo, r.exit_speed)
		worst.speed_hi = maxf(worst.speed_hi, r.exit_speed)
		worst.t = maxf(worst.t, r.exit_t)
		worst.jump = maxf(worst.jump, r.jump)
		worst.tail = minf(worst.tail, r.tail_s)
	expect(good == 10, "drop-in: %d of 10 commits roll forward on the flat at 6.5-7.8 m/s within 0.9 s (exit %.2f-%.2f m/s, slowest %.2f s, tail on the coping >= %.2f s, worst drawn-board jump %.3f m)" % [good, worst.speed_lo, worst.speed_hi, worst.t, worst.tail, worst.jump])
	expect(first.setup_frames > 0 and first.commit_frames > 0 and first.roll_frames > 0 and first.cruise_after, "drop-in: plays qp_setup -> qp_dropin commit -> roll-out -> cruise (%d / %d / %d frames)" % [first.setup_frames, first.commit_frames, first.roll_frames])
	expect(first.max_lean < 0.5 and first.roll_order, "drop-in: roll-out frames follow the wall angle and the card stays upright (max card tilt %.2f deg)" % first.max_lean)
	expect(first.facing_off < 1.0, "drop-in: he is turned square to the coping before the commit (off by %.2f deg)" % first.facing_off)
	# hesitation and leaning back in the first 0.15 s: he falls back onto the deck and the board rolls away
	for spec in [["release", Vector2.ZERO, "qp_hesitate"], ["back", Vector2(0, -1), "qp_lean_back"]]:
		p = await _deck_player(host, pipe, 0.2, 0.0, 0.0)
		await _to_ready(p)
		p.external_move = Vector2(0, 1)
		await frames(5)
		p.external_move = spec[1]
		var saw_bail := false
		for _i in 150:
			await get_tree().physics_frame
			if p.qp_state == "bail":
				p.external_move = Vector2.ZERO
				saw_bail = true
			if str(p.sprite_frame).begins_with("qp_bail_"):
				saw_bail = true
			if saw_bail and p.qp_state == "":
				break
		var feet_y: float = p.global_position.y + 0.325
		expect(saw_bail and p.last_bail_reason == spec[2] and p.qp_state == "" and not p.skating and p.ramp_mode == "" and absf(feet_y - lip.y) < 0.1, "drop-in: %s in the first 0.15 s bails onto the deck (%s, feet %.2f m, walking %s)" % [spec[0], p.last_bail_reason, feet_y, not p.skating])
		p.queue_free()
		await frames(2)
	# after 0.15 s he is committed: letting go of W no longer bails
	p = await _deck_player(host, pipe, 0.2, 0.0, 0.0)
	await _to_ready(p)
	p.external_move = Vector2(0, 1)
	await frames(12)
	p.external_move = Vector2.ZERO
	await frames(60)
	expect(p.qp_runs == 1 and p.last_bail_reason != "qp_hesitate", "drop-in: letting go of W after 0.15 s still rolls in (runs %d)" % p.qp_runs)
	p.queue_free()
	await frames(2)
	# backing out: S in the ready pose, or Shift during the set-up, puts the board back in his hand on the deck
	p = await _deck_player(host, pipe, 0.2, 0.0, 0.0)
	await _to_ready(p)
	p.external_move = Vector2(0, -1)
	await frames(4)
	p.external_move = Vector2.ZERO
	await frames(70)
	expect(p.qp_state == "" and not p.skating and p.is_on_floor() and absf(p.global_position.y + 0.325 - lip.y) < 0.1, "drop-in: S in the ready pose backs out onto the deck (qp=%s)" % p.qp_state)
	p.skate_toggle_pressed()
	await frames(20)
	p.skate_toggle_pressed()
	var back_setup := false
	for _i in 40:
		await get_tree().physics_frame
		back_setup = back_setup or p.qp_reverse
	await frames(10)
	expect(back_setup and p.qp_state == "" and not p.skating, "drop-in: Shift during the set-up backs out (qp=%s)" % p.qp_state)
	p.queue_free()
	await frames(2)
	# rolling up to the coping slowly: Shift kicks the board up, then sets it on the coping
	p = await _deck_player(host, pipe, 0.25, 0.0, 0.0)
	p.skating = true
	await frames(6)
	p.skate_toggle_pressed()
	var saw_kick := false
	for _i in 120:
		await get_tree().physics_frame
		saw_kick = saw_kick or str(p.sprite_frame).begins_with("kickup_")
		if p.qp_state == "ready":
			break
	expect(saw_kick and p.qp_state == "ready", "drop-in: rolling up to the coping, Shift kicks up then sets up (qp=%s)" % p.qp_state)
	p.queue_free()
	await frames(2)
	# Phase 3b: last qp_bail frame is the idle carry pose in every view (idle is depth-projected, qp is not);
	# no frame hides the board (the old clip popped it back after bhide).
	var bail_end_ok := true
	var bail_hide := false
	var bail_end_worst := 0.0
	for dir_name in anim.DIRS:
		var ba: Dictionary = anim.clips["qp_bail_" + dir_name].frames[35]
		var ca: Dictionary = anim.clips["idle_" + dir_name].frames[0]
		var bs := float(ca.get("body_scale", 1.0))
		var dw := absf(float(ba.rect[2]) * bs - float(ca.rect[2]))
		var dh := absf(float(ba.rect[3]) * bs - float(ca.rect[3]))
		# Tolerance was set in 0.5-scale atlas px; scale it with the pack (full-size masters are 1.0).
		var tol := 6.0 * maxf(1.0, float(ca.get("atlas_scale", 0.5)) / 0.5)
		bail_end_worst = maxf(bail_end_worst, maxf(dw, dh))
		bail_end_ok = bail_end_ok and dw <= tol and dh <= tol
		for fr in anim.clips["qp_bail_" + dir_name].frames:
			var bpx: Array = fr.get("board_px", [0, 0])
			if absf(float(bpx[1])) > 2000.0:
				bail_hide = true
	expect(bail_end_ok, "drop-in: qp_bail ends on the idle carry pose in every view (size off by <= %.1f atlas px after body_scale)" % bail_end_worst)
	expect(not bail_hide, "drop-in: qp_bail never hides the board (no pop back into the hand)")
	# live bail: recovery plays through, ends walking with the board, drawn board has no single-frame pop
	p = await _deck_player(host, pipe, 0.2, 0.0, 0.0)
	await _to_ready(p)
	p.external_move = Vector2(0, 1)
	await frames(5)
	p.external_move = Vector2.ZERO
	var cam_b: Camera3D = p.get_node("CameraPivot/SpringArm/Camera")
	var prev_rel := Vector3.ZERO
	var have_board := false
	var board_jump := 0.0
	var jump_at := ""
	var last_sf := ""
	for _i in 160:
		await get_tree().physics_frame
		last_sf = str(p.sprite_frame)
		if p.painted_sprite != null:
			# board vs his feet on screen, so a camera move or a card re-anchor does not count as a pop
			var rel: Vector3 = _board_rel(cam_b, p)
			if have_board:
				var step: float = rel.distance_to(prev_rel)
				if step >= board_jump:
					board_jump = step
					jump_at = "%s qp=%s" % [last_sf, p.qp_state]
			prev_rel = rel
			have_board = true
		if p.qp_state == "" and not last_sf.begins_with("qp_bail_") and have_board:
			for _j in 4:
				await get_tree().physics_frame
				last_sf = str(p.sprite_frame)
				var rel2: Vector3 = _board_rel(cam_b, p)
				var step2: float = rel2.distance_to(prev_rel)
				if step2 >= board_jump:
					board_jump = step2
					jump_at = "%s qp=%s" % [last_sf, p.qp_state]
				prev_rel = rel2
			break
	expect(p.qp_state == "" and not p.skating and (str(p.sprite_frame).begins_with("idle_") or str(p.sprite_frame).begins_with("walk_")), "drop-in: bail recovers to board-ready (carry/walk), qp=%s skating=%s frame=%s" % [p.qp_state, p.skating, p.sprite_frame])
	expect(board_jump < 0.22, "drop-in: bail-to-ready drawn board has no pop (worst step %.3f m at %s)" % [board_jump, jump_at])
	p.queue_free()
	await frames(2)
	# Phase 3b: game camera distance eases through walk-in, set-up, drop-in and roll-out (no single-frame snaps)
	p = await _deck_player(host, pipe, 1.35, 0.0, 0.0)
	p.external_move = Vector2(0, 1)
	var prev_cam := -1.0
	var cam_jump := 0.0
	var cam_min := 99.0
	var cam_max := 0.0
	var started := false
	var rolled := false
	var cam_at := ""
	for _i in 400:
		await get_tree().physics_frame
		var cd: float = p.camera_distance()
		if prev_cam >= 0.0:
			var step := absf(cd - prev_cam)
			if step >= cam_jump:
				cam_jump = step
				cam_at = "%s d=%.2f->%.2f" % [p.qp_state, prev_cam, cd]
		prev_cam = cd
		cam_min = minf(cam_min, cd)
		cam_max = maxf(cam_max, cd)
		var behind: float = pipe.to_local(p.global_position + Vector3.UP * 0.325).x - lip.x
		if not started and behind <= 0.25:
			p.external_move = Vector2.ZERO
			p.velocity = Vector3.ZERO
			p.skate_toggle_pressed()
			started = true
		if started and p.qp_state == "ready" and p.external_move.y < 0.5:
			p.external_move = Vector2(0, 1)
		if p.qp_runs > 0:
			rolled = true
			for _j in 50:
				await get_tree().physics_frame
				cd = p.camera_distance()
				var step2 := absf(cd - prev_cam)
				if step2 >= cam_jump:
					cam_jump = step2
					cam_at = "%s d=%.2f->%.2f" % [p.qp_state, prev_cam, cd]
				prev_cam = cd
				cam_min = minf(cam_min, cd)
				cam_max = maxf(cam_max, cd)
			break
	# 2.8 m/s slew at 60 fps is 0.047 m/frame; leave a little room
	expect(rolled and cam_jump < 0.08, "drop-in: game camera eases through walk-in / set-up / drop-in / roll-out (worst step %.3f m at %s, dist %.2f-%.2f m)" % [cam_jump, cam_at, cam_min, cam_max])
	p.queue_free()
	host.queue_free()
	await frames(2)

func _ints(a: Array) -> Array:
	var out := []
	for v in a:
		out.append(int(round(float(v))))
	return out

func _board_rel(cam: Camera3D, p) -> Vector3:
	var feet: Vector3 = p.global_position + Vector3.DOWN * 0.325
	return _screen_m(cam, p.painted_sprite.drawn_board_world(cam), p.global_position) - _screen_m(cam, feet, p.global_position)

## A world point as seen by the camera: screen position scaled to metres at the reference point's distance (z = 0).
func _screen_m(cam: Camera3D, pt: Vector3, ref: Vector3) -> Vector3:
	var sp: Vector2 = cam.unproject_position(pt)
	var dist: float = maxf(0.1, -(cam.global_transform.affine_inverse() * ref).z)
	var f: float = cam.get_viewport().get_visible_rect().size.y * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
	return Vector3(sp.x, sp.y, 0.0) * dist / f

## A walking player on the pipe deck, d m behind the coping, facing the ramp turned by off_deg, at pipe-local z.
func _deck_player(host: Node, pipe: Node3D, d: float, off_deg: float, z: float):
	var lip: Vector3 = pipe.lip_local()
	var p = _player(host, pipe.to_global(Vector3(lip.x + d, lip.y + 0.05, z)) - Vector3.UP * 0.325)
	await frames(10)
	p.skating = false
	p.external_move_active = true
	p.external_move = Vector2.ZERO
	p.camera_yaw = PI * 0.5 - p.rotation.y
	p.global_position = pipe.to_global(Vector3(lip.x + d, lip.y + 0.02, z)) - Vector3.UP * 0.325
	p.velocity = Vector3.ZERO
	p.rig.face_world(PI * 0.5 + deg_to_rad(off_deg))
	await frames(8)
	return p

func _to_ready(p) -> void:
	p.skate_toggle_pressed()
	for _i in 120:
		await get_tree().physics_frame
		if p.qp_state == "ready":
			break

## One drop-in: set up from the mark, hold W, ride to the flat. Measures the plan's pass criteria.
func _dropin_run(host: Node, pipe: Node3D, d: float, off_deg: float, z: float) -> Dictionary:
	var p = await _deck_player(host, pipe, d, off_deg, z)
	var cam: Camera3D = p.get_node("CameraPivot/SpringArm/Camera")
	var r := {"rolled": false, "fakie": true, "exit_speed": 0.0, "exit_t": 99.0, "tail_s": 0.0, "jump": 0.0, "turn": 0.0,
		"setup_frames": 0, "commit_frames": 0, "roll_frames": 0, "cruise_after": false, "max_lean": 0.0, "roll_order": true, "facing_off": 99.0}
	p.skate_toggle_pressed()
	var anim = p.painted_sprite.anim
	var board_down := int(anim.clips["qp_setup_back"].phases.get("board_down", 7))
	for _i in 120:
		await get_tree().physics_frame
		if str(p.sprite_frame).begins_with("qp_setup_"):
			r.setup_frames += 1
			if anim.frame_index >= board_down:
				r.tail_s += 1.0 / 60.0
		if p.qp_state == "ready":
			break
	# hold the ready pose a moment, then commit
	for _i in 12:
		await get_tree().physics_frame
		r.tail_s += 1.0 / 60.0
	var into: Vector3 = pipe.global_transform.basis * Vector3(-1, 0, 0)
	var face: Vector3 = -p.rig.global_transform.basis.z
	r.facing_off = rad_to_deg(acos(clampf(Vector2(face.x, face.z).normalized().dot(Vector2(into.x, into.z).normalized()), -1.0, 1.0)))
	var yaw0: float = p.rig.global_rotation.y
	# a jump = the drawn board moving on screen against his body (metres at his distance) when the state changes;
	# measured against the physics feet so the camera's own motion (spring arm catching the pipe) doesn't count
	var prev_rel: Vector3 = _board_rel(cam, p)
	var prev_state: String = p.qp_state
	var last_deg := 999.0
	p.external_move = Vector2(0, 1)
	for _i in 120:
		await get_tree().physics_frame
		var rel: Vector3 = _board_rel(cam, p)
		if p.qp_state != prev_state:
			r.jump = maxf(r.jump, (rel - prev_rel).length())
		prev_state = p.qp_state
		prev_rel = rel
		var sf := str(p.sprite_frame)
		if sf.begins_with("qp_dropin_"):
			if p.qp_state == "commit":
				r.commit_frames += 1
			else:
				r.roll_frames += 1
				var deg: float = p.ramp_angle_deg()
				if deg > last_deg + 0.5:
					r.roll_order = false
				last_deg = deg
				r.max_lean = maxf(r.max_lean, absf(rad_to_deg(p.painted_sprite.lean_roll)))
		r.turn = maxf(r.turn, absf(rad_to_deg(wrapf(p.rig.global_rotation.y - yaw0, -PI, PI))))
		if p.qp_runs > 0 and not r.rolled:
			r.rolled = true
			r.exit_speed = p.qp_exit_speed
			r.exit_t = p.qp_exit_s
			r.fakie = p.is_fakie()
			await frames(3)
			r.cruise_after = str(p.sprite_frame).begins_with("cruise_") or str(p.sprite_frame).begins_with("push_")
			break
	p.queue_free()
	await frames(2)
	return r

## Zero X Game Engine boot screen: first scene, Godot MIT license in the fine print,
## Zero on screen, no prompts: it loads the park in the background and moves on by itself.
func _boot() -> void:
	expect(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/boot.tscn", "boot screen is the first scene")
	var boot = load("res://scenes/boot.tscn").instantiate()
	boot.auto_change = false
	var handed := []
	boot.finished.connect(func(path): handed.append(path))
	add_child(boot)
	await get_tree().process_frame
	await get_tree().process_frame
	var flat := " ".join(boot.fine_label.text.replace("\n", " ").split(" ", false))
	var license := " ".join(Engine.get_license_text().replace("\n", " ").split(" ", false))
	expect(license.length() > 900 and flat.contains(license), "boot fine print carries the full Godot license text")
	expect(flat.contains("This game uses Godot Engine, available under the following license:"), "boot fine print has the Godot docs intro line")
	expect(flat.contains("GODOT_COPYRIGHT.txt"), "boot fine print points at the third-party notices file")
	expect(Engine.get_license_text().begins_with("Copyright (c) 2014-present Godot Engine contributors"), "engine license starts with the Godot copyright line")
	expect("ZERO X" in boot.logo.text and "GAME ENGINE" in boot.engine_word.text, "boot shows the Zero X Game Engine name")
	expect("built on Godot Engine" in boot.built_on.text, "boot credits Godot as the base engine")
	expect(boot.zero_stand.texture != null and boot.zero_stand.texture.get_height() > 600, "Zero art is on the boot screen")
	expect(boot.next_scene == "res://scenes/start_screen.tscn" and ResourceLoader.exists(boot.next_scene), "boot hands off to an existing scene (the start screen)")
	expect(boot.requested, "boot starts loading the park in the background")
	var prompts := []
	for node in boot.find_children("*", "Label", true, false):
		if node == boot.fine_label:
			continue  # the license itself says "EXPRESS"
		var t: String = node.text.to_upper()
		if "PRESS" in t or "SKIP" in t or "TAP" in t or "CONTINUE" in t or "CLICK" in t:
			prompts.append(t)
	expect(prompts.is_empty() and boot.find_children("*", "BaseButton", true, false).is_empty(), "boot asks nothing of the player")
	var shell := FileAccess.get_file_as_string("res://web/zero_x_shell.html")
	var tags := RegEx.create_from_string("<[^>]+>")
	var shell_flat := " ".join(tags.sub(shell, " ", true).replace("\n", " ").replace("\t", " ").split(" ", false))
	expect(shell_flat.contains(license), "web loading shell carries the same Godot license text")
	var v := Engine.get_version_info()
	expect(shell.contains("Godot Engine %s.%s.%s" % [v.major, v.minor, v.patch]), "web loading shell names the running Godot version")
	expect(shell.contains("$GODOT_CONFIG") and shell.contains("const GODOT_THREADS_ENABLED = $GODOT_THREADS_ENABLED;"), "web loading shell keeps the export placeholders")
	expect(shell.contains("src=\"zero_x_zero.webp\""), "web loading shell shows the same Zero art")
	var shell_upper := shell_flat.to_upper()
	expect(not ("PRESS START" in shell_upper or "SKIP" in shell_upper or "CONTINUE" in shell_upper), "web loading shell asks nothing of the player")
	expect(FileAccess.get_file_as_string("res://web/GODOT_COPYRIGHT.txt").contains("Comment: Godot Engine"), "official Godot COPYRIGHT.txt ships beside the web build")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	key.pressed = false
	Input.parse_input_event(key)
	await get_tree().process_frame
	expect(handed.is_empty(), "a key press does not skip the boot screen")
	for _i in 600:
		if boot.loaded:
			break
		await get_tree().process_frame
	expect(boot.loaded, "start screen finishes loading in the background")
	expect(handed.is_empty() == (boot.elapsed < boot.MIN_SHOW), "boot holds for the minimum show time")
	boot.elapsed = maxf(boot.elapsed, boot.MIN_SHOW)
	await get_tree().process_frame
	await get_tree().process_frame
	expect(handed == ["res://scenes/start_screen.tscn"], "boot moves on by itself once the start screen is loaded")
	boot.queue_free()
	await get_tree().process_frame

## Phase 4 (LOCAL puppet test): backside kickturn on the library quarter-pipe. Pipe at the origin, +X climbs; he rides in at
## v0 coasting and holds back (S) from partway up; the kickturn fires inside its window (high on the wall, slow, below the
## coping), turns him 180 deg clockwise from above about the back truck and he rolls out forward.
func _kickturn() -> void:
	var cat = JsonFile.read("res://assets/library/fony2d/frames_puppet_v1.json")
	var views := ["back", "back_right", "back_left", "right", "left", "front", "front_right", "front_left"]
	var missing: Array = []
	var edge: Array = []
	var sc := float(cat.atlas.scale_from_master)
	var ax := 400.0 * sc
	var ay := 750.0 * sc
	for d in [40, 50, 60]:
		for v in views:
			var key := "qp_kickturn_bs%d_%s" % [d, v]
			if not cat.animations.has(key) or cat.animations[key].frames.size() != 15:
				missing.append(key)
				continue
			for fr in cat.animations[key].frames:
				var off: Array = fr.anchor_offset
				var rc: Array = fr.atlas_rect
				if not str(fr.atlas_file).begins_with("fony2d_puppet_v1_kickturn_atlas") or float(off[0]) < -ax + 2.0 or float(off[1]) < -ay + 2.0 or float(off[0]) + float(rc[2]) > 800.0 * sc - ax - 2.0 or float(off[1]) + float(rc[3]) > 850.0 * sc - ay - 2.0:
					edge.append("%s" % key)
	expect(missing.is_empty(), "kickturn: 24 clips (3 wall angles x 8 views), 15 frames each (missing %s)" % [missing])
	expect(edge.is_empty(), "kickturn: no frame touches its cell edge (%d bad)" % edge.size())
	expect(cat.animations.has("qp_kickturn_bs50_front") and int(cat.animations.qp_kickturn_bs50_front.phases.turn_deg) == 180 and str(cat.animations.qp_kickturn_bs50_front.phases.direction).begins_with("backside"), "kickturn: phases say backside 180")
	expect(load("res://assets/library/fony2d/fony2d_puppet_v1_kickturn_atlas.png") is Texture2D, "kickturn: atlas imports")
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(60, 1, 60), Palette.GROUND)
	var pipe: Node3D = load("res://assets/library/quarter_pipe/quarter_pipe.tscn").instantiate()
	host.add_child(pipe)
	await frames(2)
	for row in [[5.0, 40], [5.5, 40], [6.5, 50], [7.0, 60]]:
		var r: Dictionary = await _kickturn_run(host, pipe, float(row[0]), true)
		var kt: Dictionary = r.kt
		expect(r.count == 1 and not r.lip and not r.bailed, "kickturn: %.1f m/s entry kickturns once (count %d, lip %s, bail %s)" % [row[0], r.count, r.lip, r.bailed])
		if r.count != 1:
			continue
		expect(int(kt.deg) == int(row[1]), "kickturn: %.1f m/s fires at %.1f deg on the wall, uses the %d deg clip (want %d)" % [row[0], float(kt.wall_deg), int(kt.deg), int(row[1])])
		expect(absf(r.turn - 180.0) < 5.0 and r.cw, "kickturn: %.1f m/s turns %.1f deg, clockwise from above (backside, regular)" % [row[0], r.turn])
		expect(float(kt.time) >= 0.45 and float(kt.time) <= 0.7, "kickturn: %.1f m/s takes %.3f s" % [row[0], float(kt.time)])
		expect(r.max_s < pipe.lip_arc() - 0.2 and r.min_gap > -0.05, "kickturn: %.1f m/s stays on the wall below the coping (max s %.2f of %.2f, min gap %.3f)" % [row[0], r.max_s, pipe.lip_arc(), r.min_gap])
		expect(r.exited and not r.fakie and r.exit_speed > 0.8, "kickturn: %.1f m/s rolls out forward, not fakie (%.2f m/s)" % [row[0], r.exit_speed])
		expect(r.clips.size() == 1 and str(r.clips[0]).begins_with("qp_kickturn_bs%d_" % int(row[1])) and r.frames_seen.size() >= 12 and r.mono, "kickturn: %.1f m/s draws one view, frames in order (%s, %d frames)" % [row[0], r.clips, r.frames_seen.size()])
		expect(r.ref_jump < 0.02, "kickturn: %.1f m/s card anchor never jumps (max %.3f m/tick)" % [row[0], r.ref_jump])
	var low: Dictionary = await _kickturn_run(host, pipe, 4.0, true)
	expect(low.count == 0 and low.exited and low.fakie, "kickturn: too low on the wall (4.0 m/s) no kickturn; rolls back fakie")
	var coast: Dictionary = await _kickturn_run(host, pipe, 6.0, false)
	expect(coast.count == 0 and coast.exited and coast.fakie, "kickturn: without the stick he still rolls back fakie")
	host.queue_free()
	await frames(2)

func _kickturn_run(host: Node, pipe: Node3D, v0: float, hold: bool) -> Dictionary:
	var player = _player(host, Vector3(-3.0, 0.2, 0))
	await frames(18)
	player.skating = true
	player.camera_yaw = -PI * 0.5
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	await frames(1)
	player.global_position = Vector3(-1.5, player.global_position.y, 0)
	player.velocity = Vector3(v0, 0, 0)
	player.external_move = Vector2.ZERO
	var face0: float = player.rig.global_rotation.y
	var r := {"count": 0, "lip": false, "bailed": false, "turn": 0.0, "cw": false, "max_s": 0.0, "min_gap": 1.0, "exited": false,
		"fakie": false, "exit_speed": 0.0, "clips": [], "frames_seen": [], "mono": true, "ref_jump": 0.0, "kt": {}}
	var entered := false
	var last_ref := Vector3.INF
	var last_i := -1
	for _i in 420:
		if not entered and player.ramp_mode == "":
			player.velocity.x = v0
		if hold and player.ramp_mode == "ride" and player.qp_state == "" and player.kt_count == 0 and pipe.profile_point(player.ramp_s).y > 0.5:
			player.external_move = Vector2(0, -1)
		if player.kt_count > 0 or player.ramp_mode == "":
			player.external_move = Vector2.ZERO
		await get_tree().physics_frame
		if player.ramp_mode == "ride":
			entered = true
		if player.trick == "bail":
			r.bailed = true
		if player.qp_state == "kickturn":
			r.max_s = maxf(r.max_s, player.ramp_s)
			var c: Vector3 = pipe.to_local(player.global_position + Vector3.UP * player.CAPSULE_LOW)
			r.min_gap = minf(r.min_gap, pipe.radius - Vector2(c.x, pipe.radius - c.y).length() - player.CAPSULE_R)
			var parts := str(player.sprite_frame).split("#")
			if parts.size() == 2:
				if not r.clips.has(parts[0]):
					r.clips.append(parts[0])
				var fi := int(parts[1])
				if fi < last_i:
					r.mono = false
				if fi != last_i:
					r.frames_seen.append(fi)
				last_i = fi
			var ref: Vector3 = player.global_position + player.sprite_anchor_offset()
			if last_ref != Vector3.INF:
				r.ref_jump = maxf(r.ref_jump, ref.distance_to(last_ref))
			last_ref = ref
		if entered and player.ramp_mode == "" and not player.pipe_air and player.global_position.x < -0.3:
			r.exited = true
			r.fakie = player.is_fakie()
			r.exit_speed = Vector2(player.velocity.x, player.velocity.z).length()
			break
	r.count = player.kt_count
	r.kt = player.kt_last
	var turn := wrapf(player.rig.global_rotation.y - face0, -PI, PI)
	r.turn = absf(rad_to_deg(turn))
	r.cw = r.count == 1 and player.kt_to_yaw < player.kt_from_yaw
	for e in player.ramp_events:
		if e.what == "lip_launch":
			r.lip = true
	player.queue_free()
	await frames(2)
	return r

## Phase 4 (LOCAL): the expanded skate yard. The real yard is built; he rides each new piece and must never sink into it,
## fall through it, or stop dead against it.
func _park() -> void:
	const Pieces = preload("res://assets/library/skate_park/park_pieces.gd")
	var host := _host()
	load("res://scripts/yard.gd").build(host)
	await frames(3)
	for n in ["HalfPipeWest", "HalfPipeEast", "MiniRampSteps", "FunboxKickerEast", "FunboxKickerWest", "ManualPad", "Bank", "SkateQuarter", "Funbox"]:
		expect(host.get_node_or_null(n) != null, "park has " + n)
	var pipes := []
	for q in [host.get_node("SkateQuarter"), host.get_node("HalfPipeWest"), host.get_node("HalfPipeEast")]:
		pipes.append(q)
		expect(q.is_in_group("quarter_pipe") and q.finish == "dark" and q.closed_back and q.get_node_or_null("BackCollision") != null, "park: %s is a library quarter pipe, dark finish, closed back" % q.name)
		var mat: ShaderMaterial = q.get_node("Shell").material_override
		var tint: Color = mat.get_shader_parameter("albedo")
		var face_tex = mat.get_shader_parameter("albedo_tex")
		expect(face_tex is Texture2D and str(face_tex.resource_path).ends_with("dark_face_albedo.png") and tint == Color.WHITE and absf(float(mat.get_shader_parameter("fill_light")) - 1.3) < 0.001, "park: %s dark finish face (finish pass texture, tint %s) keeps the fill light" % [q.name, tint.to_html(false)])
	# no piece overlaps another or the spawn spot
	var boxes := {}
	for n in ["SkateQuarter", "QuarterDeckSteps", "HalfPipeWest", "HalfPipeEast", "MiniRampSteps", "Funbox", "FunboxKickerEast", "FunboxKickerWest", "ManualPad", "Bank", "GrindRail"]:
		boxes[n] = _ground_box(host.get_node(n))
	var overlaps: Array = []
	var names: Array = boxes.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = boxes[names[i]].grow(-0.05)
			var b: Rect2 = boxes[names[j]].grow(-0.05)
			if a.intersects(b) and not ((names[i] == "Funbox" and str(names[j]).begins_with("FunboxKicker")) or (str(names[i]).ends_with("Steps") and names[j] == "SkateQuarter") or (names[i] == "SkateQuarter" and names[j] == "QuarterDeckSteps") or (names[i] == "HalfPipeEast" and names[j] == "MiniRampSteps")):
				overlaps.append("%s/%s" % [names[i], names[j]])
	expect(overlaps.is_empty(), "park: pieces do not overlap (%s)" % [overlaps])
	var spawn := Rect2(-42.6, 1.4, 1.2, 1.2)
	var crowd: Array = []
	for n in names:
		if boxes[n].intersects(spawn):
			crowd.append(n)
	expect(crowd.is_empty(), "park: spawn spot (-42, 2) is clear (%s)" % [crowd])
	var inside := true
	for n in names:
		var r: Rect2 = boxes[n]
		if r.position.x < -78.0 or r.end.x > -32.0 or r.position.y < -50.0 or r.end.y > 18.0:
			inside = false
	expect(inside, "park: every piece stays inside the skate yard")
	# mini ramp: in at 6 m/s, up the east wall, back down fakie, stick toward the west wall, up that one
	var mr: Dictionary = await _mini_run(host, 6.0, false)
	expect(mr.walls.size() == 2 and mr.walls.has("HalfPipeEast") and mr.walls.has("HalfPipeWest") and mr.min_clear > -0.06 and not mr.fell, "park: mini ramp rides both walls (%s), never through the flat (min clearance %.3f)" % [mr.walls, mr.min_clear])
	# kickturn on the mini ramp's east wall
	var kt: Dictionary = await _mini_run(host, 6.5, true)
	expect(kt.kickturns == 1 and not kt.fell and not kt.fakie_after, "park: kickturn on the mini ramp's east wall (%d), rolls away forward" % kt.kickturns)
	# funbox: up the east kicker, across the top, down (or off) the west side
	var fb: Dictionary = await _park_run(host, Vector3(-40.5, 0.3, -2.0), Vector3(-6.0, 0, 0), Vector2(0, 1), 150, false, PI * 0.5)
	expect(fb.max_y > 0.8 and fb.final.x < -53.0 and not fb.fell and fb.min_clear > -0.06 and fb.final_speed > 2.0, "park: funbox kicker up, over the top (peak %.2f m), off the far side at x %.1f, %.1f m/s" % [fb.max_y, fb.final.x, fb.final_speed])
	var fb2: Dictionary = await _park_run(host, Vector3(-55.5, 0.3, -2.0), Vector3(6.0, 0, 0), Vector2(0, 1), 150, false, -PI * 0.5)
	expect(fb2.max_y > 0.8 and fb2.final.x > -43.0 and not fb2.fell and fb2.min_clear > -0.06, "park: funbox the other way (peak %.2f m, x %.1f)" % [fb2.max_y, fb2.final.x])
	# bank: up onto its deck and off the back
	# 120 ticks: off the back and rolling on, stopping short of the yard's west wall (the finish pass added a run-up behind the
	# bank; at 150 ticks the run hit the wall and the capsule's one-tick dip there read as sinking into the ground)
	var bk: Dictionary = await _park_run(host, Vector3(-59.0, 0.3, -1.0), Vector3(-6.0, 0, 0), Vector2(0, 1), 120, false, PI * 0.5)
	var past := {}
	for tr in bk.trace:
		if tr[0].x < -69.5:
			past = {"x": tr[0].x, "y": tr[0].y, "speed": tr[1]}
			break
	expect(bk.max_y > 1.1 and not past.is_empty() and float(past.speed) > 2.0 and not bk.fell and bk.min_clear > -0.06, "park: bank up to its deck (peak %.2f m) and off the back, still rolling (%s, fell %s, min clear %.3f)" % [bk.max_y, past, bk.fell, bk.min_clear])
	var bk2: Dictionary = await _park_run(host, Vector3(-59.0, 0.3, -1.0), Vector3(-4.0, 0, 0), Vector2.ZERO, 150, false, PI * 0.5)
	expect(bk2.max_y > 0.15 and not bk2.fell and bk2.min_clear > -0.06 and bk2.final.y < 1.3, "park: coasting into the bank climbs it without sinking (peak %.2f m)" % bk2.max_y)
	# manual pad: ollie onto it, roll along it, roll off the end
	var mp: Dictionary = await _park_run(host, Vector3(-38.0, 0.3, -4.0), Vector3(0, 0, -6.0), Vector2(0, 1), 150, false, 0.0, 0.25)
	expect(mp.on_pad > 10 and mp.final.z < -16.5 and not mp.fell and mp.min_clear > -0.06 and mp.final_speed > 2.0, "park: ollie onto the manual pad, %d ticks on top, off the end (z %.1f, %.1f m/s)" % [mp.on_pad, mp.final.z, mp.final_speed])
	var mp_hit: Dictionary = await _park_run(host, Vector3(-38.0, 0.3, -4.0), Vector3(0, 0, -5.0), Vector2(0, 1), 90, false, 0.0)
	expect(not mp_hit.fell and mp_hit.min_clear > -0.06 and mp_hit.final.z > -9.0, "park: no ollie, he stops at the pad's face instead of going through it (z %.2f)" % mp_hit.final.z)
	host.queue_free()
	await frames(2)

## Top-down footprint (x, z) of a piece from its collision shapes / mesh AABB.
func _ground_box(n: Node) -> Rect2:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var a: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		box = a if first else box.merge(a)
		first = false
	if n is Node3D and n.has_method("point_at"):
		var p0: Vector3 = n.point_at(0.0)
		var p1: Vector3 = n.point_at(1.0)
		var r := Rect2(Vector2(minf(p0.x, p1.x), minf(p0.z, p1.z)), Vector2(absf(p1.x - p0.x), absf(p1.z - p0.z)))
		return r.grow(0.2)
	return Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))

## One ride across the yard: start at pos with velocity v0, stick held (camera yaw cam), optional ollie after `ollie_at` s.
## Clearance = how far the capsule bottom is above the highest surface under it (negative = sunk into a piece).
func _park_run(host: Node, pos: Vector3, v0: Vector3, stick: Vector2, ticks: int, kickturn := false, cam := -PI * 0.5, ollie_at := -1.0) -> Dictionary:
	const Pieces = preload("res://assets/library/skate_park/park_pieces.gd")
	var player = _player(host, pos)
	await frames(10)
	player.skating = true
	player.camera_yaw = cam
	player.external_move_active = true
	player.external_move = stick
	player.global_position = pos
	player.velocity = v0
	if v0.length() > 0.1 and player.rig != null:
		player.rig.face_world(atan2(-v0.x, -v0.z))
	var r := {"min_clear": 9.0, "max_y": 0.0, "fell": false, "final": Vector3.ZERO, "final_speed": 0.0, "on_pad": 0, "kickturns": 0, "events": [], "trace": []}
	var wedges := [host.get_node("FunboxKickerEast"), host.get_node("FunboxKickerWest"), host.get_node("Bank")]
	var pad: Node3D = host.get_node("ManualPad")
	var fun: Node3D = host.get_node("Funbox")
	var pipes := [host.get_node("SkateQuarter"), host.get_node("HalfPipeWest"), host.get_node("HalfPipeEast")]
	var t := 0.0
	for _i in ticks:
		if ollie_at >= 0.0 and t >= ollie_at and t < ollie_at + 0.02:
			player.external_jump = true
		if kickturn and player.ramp_mode == "ride" and player.qp_state == "" and player.kt_count == 0 and player.ramp.profile_point(player.ramp_s).y > 0.5:
			player.external_move = Vector2(0, -1)
		elif kickturn:
			player.external_move = Vector2.ZERO
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var foot: Vector3 = player.global_position + Vector3.UP * 0.325
		var ground := 0.0
		for w in wedges:
			ground = maxf(ground, Pieces.surface_y(w, foot))
		var lp: Vector3 = pad.to_local(foot)
		var on_pad := absf(lp.x) < 0.8 and absf(lp.z) < 3.5
		if on_pad:
			ground = maxf(ground, 0.3)
			if foot.y > 0.25:
				r.on_pad += 1
		var lf: Vector3 = fun.to_local(foot)
		if absf(lf.x) < 2.1 and absf(lf.z) < 2.1:
			ground = maxf(ground, 0.9)
		for q in pipes:
			var ql: Vector3 = q.to_local(foot)
			if absf(ql.z) < q.half_width() and ql.x > 0.0:
				ground = maxf(ground, q.surface_y(ql.x))
		# on the curve the capsule sits along the normal; only score the flat-ish pieces there
		if player.ramp_mode != "ride" and player.qp_state == "":
			r.min_clear = minf(r.min_clear, foot.y - ground)
		r.max_y = maxf(r.max_y, foot.y)
		r.trace.append([foot, Vector2(player.velocity.x, player.velocity.z).length()])
		if foot.y < -0.3:
			r.fell = true
	r.final = player.global_position
	r.final_speed = Vector2(player.velocity.x, player.velocity.z).length()
	r.kickturns = player.kt_count
	for e in player.ramp_events:
		var e2: Dictionary = e.duplicate()
		r.events.append(e2)
	player.queue_free()
	await frames(2)
	return r

## Mini ramp run: rolling east at v0 from the middle of the flat bottom into HalfPipeEast; once he is back on the flat the
## stick points west (as a player would steer to the other wall). kickturn = hold back high on the east wall.
func _mini_run(host: Node, v0: float, kickturn: bool) -> Dictionary:
	var player = _player(host, Vector3(-47.0, 0.3, -30.0))
	await frames(10)
	player.skating = true
	player.camera_yaw = -PI * 0.5
	player.external_move_active = true
	player.external_move = Vector2.ZERO
	player.global_position = Vector3(-47.0, 0.0, -30.0)
	player.velocity = Vector3(v0, 0, 0)
	player.rig.face_world(atan2(-1.0, 0.0))
	var r := {"walls": [], "min_clear": 9.0, "fell": false, "kickturns": 0, "fakie_after": false}
	var entered := false
	var back_on_flat := false
	for _i in 400:
		if not entered and player.ramp_mode == "":
			player.velocity.x = v0
		if player.ramp_mode == "ride":
			entered = true
			if not r.walls.has(str(player.ramp.name)):
				r.walls.append(str(player.ramp.name))
			if kickturn and player.qp_state == "" and player.kt_count == 0 and player.ramp.profile_point(player.ramp_s).y > 0.5:
				player.external_move = Vector2(0, -1)
			else:
				player.external_move = Vector2.ZERO
		elif entered:
			if not back_on_flat:
				back_on_flat = true
				r.fakie_after = player.is_fakie()
			player.external_move = Vector2(0, -1)     # toward the west wall
		await get_tree().physics_frame
		var foot: Vector3 = player.global_position + Vector3.UP * 0.325
		if player.ramp_mode == "" and foot.x > -49.9 and foot.x < -44.1:
			r.min_clear = minf(r.min_clear, foot.y)
		if foot.y < -0.3:
			r.fell = true
		if r.walls.size() == 2 and (not kickturn or player.kt_count > 0):
			break
	r.kickturns = player.kt_count
	player.queue_free()
	await frames(2)
	return r

# ------------------------------------------------------------------ finish pass (Nov 17 2026)

func _finish_pass() -> void:
	await _finish_catalog()
	await _finish_grind_tricks()
	await _finish_down_rail()
	await _finish_bs_air()
	await _finish_quarter_art()

## The new puppet clips: 5-0 and boardslide (12 frames, in / hold / out) and the backside air (16 frames, rise / hold / release),
## all 8 views, each frame inside its 800x850 master cell, on the grind / air sheets.
func _finish_catalog() -> void:
	var cat = JsonFile.read("res://assets/library/fony2d/frames_puppet_v1.json")
	var views := ["back", "back_right", "back_left", "right", "left", "front", "front_right", "front_left"]
	var sc := float(cat.atlas.scale_from_master)
	var ax := 400.0 * sc
	var ay := 750.0 * sc
	for spec in [["grind_5o", 12, "fony2d_puppet_v1_grind_atlas.png", ["in", "hold", "out"]], ["grind_board", 12, "fony2d_puppet_v1_grind_atlas.png", ["in", "hold", "out"]],
			["air_bs", 16, "fony2d_puppet_v1_air_atlas.png", ["rise", "hold", "release"]]]:
		var bad: Array = []
		for v in views:
			var key := "%s_%s" % [spec[0], v]
			if not cat.animations.has(key) or cat.animations[key].frames.size() != int(spec[1]):
				bad.append(key + " missing")
				continue
			for ph in spec[3]:
				if not cat.animations[key].phases.has(ph):
					bad.append(key + " no " + ph)
			for fr in cat.animations[key].frames:
				var off: Array = fr.anchor_offset
				var rc: Array = fr.atlas_rect
				if str(fr.atlas_file) != str(spec[2]) or float(off[0]) < -ax + 2.0 or float(off[1]) < -ay + 2.0 or float(off[0]) + float(rc[2]) > 800.0 * sc - ax - 2.0 or float(off[1]) + float(rc[3]) > 850.0 * sc - ay - 2.0:
					bad.append(key)
					break
		expect(bad.is_empty(), "finish: %s clip in all 8 views, %d frames, on %s, inside the cell (%s)" % [spec[0], spec[1], spec[2], bad])
	expect(load("res://assets/library/fony2d/fony2d_puppet_v1_air_atlas.png") is Texture2D, "finish: air atlas imports")
	var a = cat.animations.get("air_bs_back", {})
	expect(int(a.get("phases", {}).get("turn_deg", 0)) == 180 and str(a.get("phases", {}).get("direction", "")).begins_with("backside") and str(a.get("phases", {}).get("grab", "")).contains("left"), "finish: backside air phases say backside 180, left hand grab")

## Flat bar: lock a 50-50, switch to a 5-0 (F) and a boardslide (R) and back, each eased (no pop), each with its own clip, its
## own height on the bar and drag; the popup shows the names; rolling off reports the line.
func _finish_grind_tricks() -> void:
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(80, 1, 80), Palette.GROUND)
	var rail = _grind_bar(host, 24.0)
	await frames(2)
	var popup = load("res://scripts/trick_popup.gd").new()
	host.add_child(popup)
	var player = await _grind_ride(host, 7.5)
	popup.player = player
	await frames(2)
	expect(player.grind == rail and player.grind_trick == "5050" and player.callout == "50-50" and player.callout_kind == "grind", "finish: the lock calls out 50-50 (callout %s)" % player.callout)
	await get_tree().process_frame
	await get_tree().process_frame
	expect(popup.shown == "50-50" and popup.label.modulate.a > 0.5, "finish: the popup shows 50-50 (%s)" % popup.shown)
	if player.grind == null:
		expect(false, "finish: grind tricks need the lock")
		host.queue_free()
		await frames(2)
		return
	await frames(10)
	var results := {}
	for step in [["grab", "5o", "5-0"], ["flip", "board", "BOARDSLIDE"], ["flip", "5050", "50-50"]]:
		player.request_trick(step[0])
		var prev: Vector3 = player.global_position
		var jump := 0.0
		var clip := ""
		var v0: float = absf(player.grind_v)
		for i in 14:
			await get_tree().physics_frame
			await get_tree().process_frame
			var d: Vector3 = player.global_position - prev
			jump = maxf(jump, absf(d.y))
			prev = player.global_position
			if i == 12:
				clip = str(player.sprite_frame).split("#")[0]
		var drag: float = (v0 - absf(player.grind_v)) / (14.0 / 60.0)
		var want_y: float = rail.line_point(player.grind_along).y - 0.325 - float(player.GRIND_TRICKS[step[1]].sink)
		results[step[1]] = drag
		expect(player.grind == rail and player.grind_trick == step[1] and player.callout == step[2], "finish: %s on the bar switches to %s (callout %s)" % [step[0], step[1], player.callout])
		expect(jump < 0.03 and absf(player.global_position.y - want_y) < 0.005, "finish: %s eases to its height on the bar (step %.3f m/tick, off %.3f m)" % [step[1], jump, player.global_position.y - want_y])
		var want_clip: String = {"5o": "grind_5o_", "board": "grind_board_", "5050": "grind_"}[step[1]]
		expect(clip.begins_with(want_clip) and (step[1] != "5050" or not (clip.begins_with("grind_5o") or clip.begins_with("grind_board"))), "finish: %s draws its own clip (%s)" % [step[1], clip])
		expect(popup.shown == step[2], "finish: the popup shows %s (%s)" % [step[2], popup.shown])
	expect(results.get("board", 0.0) > results.get("5050", 0.0) + 0.2 and results.get("5o", 0.0) > results.get("5050", 0.0) * 0.4, "finish: drag 50-50 %.2f, 5-0 %.2f, boardslide %.2f m/s^2" % [results.get("5050", 0.0), results.get("5o", 0.0), results.get("board", 0.0)])
	var left := false
	for _i in 200:
		await get_tree().physics_frame
		if player.grind == null:
			left = true
			break
	expect(left and player.grind_last.get("tricks", []) == ["5050", "5o", "board", "5050"] and player.callout.contains("+") and player.callout.contains("5-0"), "finish: rolling off calls the line (%s / %s)" % [player.grind_last.get("tricks", []), player.callout])
	# popup: a name fades out within ~1.2 s
	await frames(80)
	await get_tree().process_frame
	expect(popup.shown == "" and popup.label.modulate.a == 0.0, "finish: the popup fades out (%s)" % popup.shown)
	# the ollie and kickflip call out too
	player.queue_free()
	await frames(2)
	player = _player(host, Vector3(0, -0.3, 10))
	popup.player = player
	await frames(12)
	player.skating = true
	player.external_move_active = true
	player.request_trick("flip")
	await frames(14)
	await get_tree().process_frame
	expect(player.callout == "KICKFLIP" and popup.shown == "KICKFLIP", "finish: a kickflip calls out KICKFLIP (%s / %s)" % [player.callout, popup.shown])
	host.queue_free()
	await frames(2)

## The yard's down rail: a bar down the bank's face from the deck end, reachable from the run-up deck; ollie on, it speeds up and
## rolls off the bottom.
func _finish_down_rail() -> void:
	var host := _host()
	load("res://scripts/yard.gd").build(host)
	await frames(3)
	var rail = host.get_node_or_null("DownRail")
	var bank: Node3D = host.get_node_or_null("Bank")
	var run: Node3D = host.get_node_or_null("DownRailRunUp")
	expect(rail != null and bank != null and run != null and rail.kind == "rail" and float(rail.drop) > 1.0, "finish: the yard has a down rail on the bank and a run-up")
	if rail == null or bank == null or run == null:
		host.queue_free()
		await frames(2)
		return
	var top: Vector3 = rail.line_point(0.0)
	var bottom: Vector3 = rail.line_point(rail.length)
	var clear_min := 9.0
	var clear_max := -9.0
	for i in 21:
		var p: Vector3 = rail.line_point(rail.length * float(i) / 20.0)
		var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.0, p + Vector3.DOWN * 3.0))
		if hit.is_empty():
			continue
		clear_min = minf(clear_min, p.y - hit.position.y)
		clear_max = maxf(clear_max, p.y - hit.position.y)
	expect(top.y > 1.4 and bottom.y < 0.35 and bottom.x > top.x and clear_min > 0.12 and clear_max < 0.5, "finish: the down rail runs east down the bank 0.12-0.5 m over the surface (top %.2f, bottom %.2f, clear %.2f..%.2f)" % [top.y, bottom.y, clear_min, clear_max])
	var deck_y: float = float(run.get_meta("height"))
	var player = _player(host, Vector3(-70.5, deck_y + 0.2, rail.position.z))
	await frames(10)
	player.skating = true
	player.camera_yaw = -PI / 2.0
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	player.global_position = Vector3(-70.5, deck_y - 0.325 + 0.01, rail.position.z + 0.15)
	player.velocity = Vector3(9.0, 0, 0)
	var pop_x := -70.1               # Q at the start of the run-up deck: the crouch then pops ~0.3 m before the deck end
	var popped := false
	var locked := false
	var v_lock := 0.0
	var v_max := 0.0
	for _i in 200:
		await get_tree().physics_frame
		if not popped and player.global_position.x > pop_x:
			player.request_trick("ollie")
			popped = true
		if player.grind == rail and not locked:
			locked = true
			v_lock = absf(player.grind_v)
		if player.grind == rail:
			v_max = maxf(v_max, absf(player.grind_v))
		if OS.get_environment("AU_DR_DEBUG") == "1":
			print("dr x=%.2f y=%.3f vx=%.2f vy=%.2f floor=%s trick=%s grind=%s" % [player.global_position.x, player.global_position.y, player.velocity.x, player.velocity.y, player.is_on_floor(), player.trick, player.grind])
		if locked and player.grind == null:
			break
	expect(locked and v_max > v_lock + 0.5, "finish: ollie off the run-up deck locks onto the down rail and it speeds up (%.2f -> %.2f m/s, last %s)" % [v_lock, v_max, player.grind_last])
	var landed := false
	for _i in 60:
		await get_tree().physics_frame
		if player.is_on_floor():
			landed = true
			break
	await frames(4)
	expect(landed and player.grind_last.get("exit", "") == "end" and player.skating and player.bail_time <= 0.0, "finish: rolls off the bottom of the down rail and rides away (%s)" % player.grind_last)
	host.queue_free()
	await frames(2)

## Phase 5: backside air. Off the coping at speed, grab early: the backside 180 is drawn (air_bs), he lets go on the way down and
## re-enters forward; holding the grab into the landing bails; a late grab is the old melon.
func _finish_bs_air() -> void:
	var host := _host()
	Blocks.solid(host, "Ground", Vector3(0, -0.5, 0), Vector3(60, 1, 60), Palette.GROUND)
	var pipe: Node3D = load("res://assets/library/quarter_pipe/quarter_pipe.tscn").instantiate()
	host.add_child(pipe)
	await frames(2)
	var ok: Dictionary = await _bsair_run(host, pipe, 0.05, false)
	expect(ok.started and ok.callout == "BACKSIDE AIR", "finish: grab off the coping starts a backside air (%s)" % ok.callout)
	expect(ok.clips.size() == 1 and str(ok.clips[0]).begins_with("air_bs_") and ok.mono and ok.frames_seen.size() >= 10, "finish: one view of the air_bs clip, frames in order (%s, %d frames)" % [ok.clips, ok.frames_seen.size()])
	expect(ok.released and ok.landed == "landed" and ok.landing == "transition" and not ok.bailed, "finish: lets go and re-enters the transition (%s, %s)" % [ok.landed, ok.landing])
	expect(ok.exited and not ok.fakie and absf(ok.turn - 180.0) < 5.0, "finish: rolls out forward after the 180 (fakie %s, turn %.1f)" % [ok.fakie, ok.turn])
	var held: Dictionary = await _bsair_run(host, pipe, 0.05, true)
	expect(held.started and held.bailed and held.reason == "bs_air_grab_held", "finish: holding the grab into the re-entry bails (%s)" % held.reason)
	var late: Dictionary = await _bsair_run(host, pipe, 0.6, false)
	expect(not late.started and late.callout == "MELON", "finish: a late grab is the plain melon (%s)" % late.callout)
	host.queue_free()
	await frames(2)

func _bsair_run(host: Node, pipe: Node3D, grab_u: float, hold: bool) -> Dictionary:
	var player = _player(host, Vector3(-3.0, 0.2, 0))
	await frames(18)
	player.skating = true
	player.camera_yaw = -PI * 0.5
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	await frames(1)
	player.global_position = Vector3(-1.5, player.global_position.y, 0)
	player.velocity = Vector3(9.0, 0, 0)
	player.external_move = Vector2.ZERO
	player.grab_hold = hold
	var face0: float = player.rig.global_rotation.y
	var r := {"started": false, "callout": "", "clips": [], "frames_seen": [], "mono": true, "released": false, "landed": "", "landing": "",
		"bailed": false, "reason": "", "exited": false, "fakie": false, "turn": 0.0}
	var entered := false
	var grabbed := false
	var last_i := -1
	for _i in 420:
		if not entered and player.ramp_mode == "":
			player.velocity.x = 9.0
		await get_tree().physics_frame
		await get_tree().process_frame
		if player.ramp_mode == "ride":
			entered = true
		if not grabbed and player.pipe_air and player.air_kind == "lip" and player.air_u() >= grab_u:
			player.request_trick("grab")
			grabbed = true
		if player.trick == "bs_air":
			r.started = true
			var parts := str(player.sprite_frame).split("#")
			if parts.size() == 2:
				if not r.clips.has(parts[0]):
					r.clips.append(parts[0])
				var fi := int(parts[1])
				if fi < last_i:
					r.mono = false
				if fi != last_i:
					r.frames_seen.append(fi)
				last_i = fi
		if grabbed and r.callout == "" and player.callout != "":
			r.callout = player.callout
		if player.bsair_release_u >= 0.0:
			r.released = true
		if player.trick == "bail":
			r.bailed = true
			r.reason = player.last_bail_reason
		if r.landing == "" and player.last_landing != "":
			r.landing = player.last_landing
		if entered and player.ramp_mode == "" and not player.pipe_air and player.global_position.x < -0.3:
			r.exited = true
			r.fakie = player.is_fakie()
			break
	r.landed = str(player.bsair_last.get("result", ""))
	r.turn = absf(rad_to_deg(wrapf(player.rig.global_rotation.y - face0, -PI, PI)))
	player.queue_free()
	await frames(2)
	return r

## Park art: the quarter pipes' dark finish (riding face, coping, edges).
func _finish_quarter_art() -> void:
	var host := _host()
	var pipe: Node3D = load("res://assets/library/quarter_pipe/quarter_pipe.tscn").instantiate()
	pipe.finish = "dark"
	pipe.closed_back = true
	host.add_child(pipe)
	await frames(2)
	var shell: MeshInstance3D = pipe.get_node_or_null("Shell")
	var face_tex = (shell.material_override as ShaderMaterial).get_shader_parameter("albedo_tex") if shell != null else null
	expect(face_tex is Texture2D and str(face_tex.resource_path).ends_with("dark_face_albedo.png"), "finish: dark quarter pipe has the dark sealed face texture (%s)" % (face_tex.resource_path if face_tex is Texture2D else "none"))
	var img: Image = (face_tex as Texture2D).get_image() if face_tex is Texture2D else null
	var luma := 1.0
	if img != null:
		if img.is_compressed():
			img.decompress()
		var sum := 0.0
		for y in range(0, img.get_height(), 16):
			for x in range(0, img.get_width(), 16):
				sum += img.get_pixel(x, y).get_luminance()
		luma = sum / float((img.get_height() / 16) * (img.get_width() / 16))
	expect(luma > 0.12 and luma < 0.32, "finish: dark face texture mean luma %.3f" % luma)
	var coping: MeshInstance3D = pipe.get_node_or_null("Coping")
	var cop_col: Color = (coping.material_override as ShaderMaterial).get_shader_parameter("albedo") if coping != null else Color.WHITE
	expect(coping != null and cop_col.v < 0.6, "finish: dark coping steel %s" % cop_col.to_html(false))
	var trims := 0
	for n in ["EdgeTrimL", "EdgeTrimR", "DeckPlate", "CheekL", "CheekR"]:
		if pipe.get_node_or_null(n) != null:
			trims += 1
	expect(trims == 5, "finish: steel edge trim on both cheeks, a deck plate and dark cheek plates (%d of 5)" % trims)
	var plain: Node3D = load("res://assets/library/quarter_pipe/quarter_pipe.tscn").instantiate()
	host.add_child(plain)
	await frames(2)
	expect(plain.get_node_or_null("EdgeTrimL") == null and str(((plain.get_node("Shell") as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("albedo_tex").resource_path).ends_with("concrete_albedo.png"), "finish: the original finish is unchanged")
	host.queue_free()
	await frames(2)

## M0 (Nov 18 2026): pack budget, near-lossless (q0.97) Fony atlases, district packs, loading cards and exploration stats.
const M0Cards = preload("res://scripts/loading_cards.gd")

func _m0_packs() -> void:
	_m0_fony_lossless()
	_m0_cards()
	_m0_exploration()
	_m0_registry()
	await _m0_free_roam_unchanged()
	await _m0_district_fail_keeps_rolling()
	await _m0_district_skate_across()

func _m0_fony_lossless() -> void:
	# Near-lossless since M0 commit 2: lossy WebP at q0.97 (live was q0.75), 3D detection off so nothing turns into VRAM.
	var ok := 0
	var total := 0
	for name in DirAccess.get_files_at("res://assets/library/fony2d"):
		if not name.ends_with(".png.import"):
			continue
		total += 1
		var cfg := ConfigFile.new()
		cfg.load("res://assets/library/fony2d/" + name)
		if int(cfg.get_value("params", "compress/mode", -1)) == 1 and absf(float(cfg.get_value("params", "compress/lossy_quality", 0.0)) - 0.97) < 0.001 and int(cfg.get_value("params", "detect_3d/compress_to", -1)) == 0:
			ok += 1
	expect(total == 7 and ok == total, "m0: all %d Fony atlases import as WebP q0.97 with 3D detection off (%d)" % [total, ok])
	var path := "res://assets/library/fony2d/fony2d_puppet_v1_air_atlas.png"
	var got: Image = (load(path) as Texture2D).get_image()
	if got.is_compressed():
		got.decompress()
	got.convert(Image.FORMAT_RGBA8)
	var src := Image.load_from_file(ProjectSettings.globalize_path(path))
	src.convert(Image.FORMAT_RGBA8)
	var sq := 0.0
	var seen := 0
	for y in range(0, src.get_height(), 5):
		for x in range(0, src.get_width(), 5):
			var a := src.get_pixel(x, y)
			if a.a8 < 128:
				continue
			var g := got.get_pixel(x, y)
			seen += 1
			sq += (pow(a.r - g.r, 2.0) + pow(a.g - g.g, 2.0) + pow(a.b - g.b, 2.0)) / 3.0
	var psnr := 99.0 if sq == 0.0 else 10.0 * log(1.0 / (sq / maxf(1.0, seen))) / log(10.0)
	# The old q0.75 import measured about 30 dB on the front atlas; q0.97 measures about 33.5 dB.
	expect(seen > 1000 and psnr >= 32.0, "m0: imported Fony atlas stays close to its source PNG (%.2f dB PSNR over %d samples)" % [psnr, seen])

func _m0_cards() -> void:
	var data := M0Cards.read("res://data/loading_cards/test_district.json")
	expect(not data.is_empty() and M0Cards.validate(data).get("ok") == true, "m0 cards: test district card file is valid")
	var picks := []
	for visit in [1, 2, 3, 4, 5]:
		picks.append(str(M0Cards.pick(data, visit).get("id", "")))
	expect(picks == ["test_intro", "test_faction", "test_tip_ledge", "test_tip_bank", "test_tip_ledge"], "m0 cards: visit 1 intro, 2 faction, 3+ rotate tips %s" % str(picks))
	var faction := M0Cards.pick(data, 2)
	expect(str(faction.get("portrait", "")) != "" and ResourceLoader.exists(str(faction["portrait"])) and str(faction.get("tier")) == "faction", "m0 cards: the faction card has a portrait that exists")
	for visit in [1, 2, 3]:
		var art := str(M0Cards.pick(data, visit).get("art", ""))
		expect(art != "" and ResourceLoader.exists(art), "m0 cards: visit %d art exists in the main pack (%s)" % [visit, art])
	expect(str(M0Cards.pick({}, 1, "SOMEWHERE").get("title")) == "SOMEWHERE", "m0 cards: a district with no card file still gets a title card")
	var bad := data.duplicate(true)
	bad["tiers"][0]["pick"] = "shuffle"
	expect(M0Cards.validate(bad).get("ok") == false, "m0 cards: unknown pick mode is rejected")
	var rnd := {"contract": "au.loading_cards", "version": 1, "district": "x", "tiers": [{"id": "t", "from_visit": 1, "pick": "random", "cards": [{"id": "a", "title": "A"}, {"id": "b", "title": "B"}, {"id": "c", "title": "C"}]}]}
	expect(M0Cards.pick(rnd, 7).get("id") == M0Cards.pick(rnd, 7).get("id"), "m0 cards: random pick is stable for a visit")

func _m0_exploration() -> void:
	var save = SaveScript.new()
	expect(save.district_visits("test_district") == 0, "m0 save: no visits before the first")
	expect(save.record_district_visit("test_district", 1000) == 1 and save.record_district_visit("test_district", 2000) == 2, "m0 save: visits count up")
	var st: Dictionary = save.district_stats("test_district")
	expect(int(st.first_visit_unix) == 1000 and int(st.last_visit_unix) == 2000, "m0 save: first visit time kept, last visit time moves")
	expect(save.discover("test_district", "shortcuts", "bank_gap") and not save.discover("test_district", "shortcuts", "bank_gap"), "m0 save: a shortcut is discovered once")
	expect(st.discovered.secrets == [] and st.discovered.shortcuts == ["bank_gap"], "m0 save: discovered holds shortcuts and an empty secrets set")
	var round = SaveScript.new()
	expect(round.apply_json(JSON.stringify(save.to_dict())).get("ok") == true and round.district_visits("test_district") == 2 and round.district_stats("test_district").discovered.shortcuts == ["bank_gap"], "m0 save: exploration survives a JSON roundtrip")
	var old = SaveScript.new()
	expect(old.apply_dict({"contract": "au.world_save", "contract_version": 1, "meetings": {}, "results": []}).get("ok") == true and old.district_visits("test_district") == 0, "m0 save: a pre-M0 save without exploration still loads")
	expect(SaveScript.new().apply_dict({"contract": "au.world_save", "contract_version": 1, "meetings": {}, "results": [], "exploration": {"districts": 3}}).get("ok") == false, "m0 save: a broken exploration block is rejected")
	var path := "user://m0-test-save.json"
	save.save_user(path)
	var only = SaveScript.new()
	expect(only.load_exploration_user(path).get("ok") == true and only.district_visits("test_district") == 2 and only.results.is_empty(), "m0 save: exploration loads alone from disk")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _m0_registry() -> void:
	var reg = JsonFile.read("res://data/districts.json")
	var td: Dictionary = reg.get("districts", {}).get("test_district", {}) if typeof(reg) == TYPE_DICTIONARY else {}
	expect(str(td.get("pack", "")) == "districts/test_district.pck" and str(td.get("scene", "")).begins_with("res://districts/"), "m0 registry: test district pack and scene paths")
	expect(int(td.get("budget_bytes", 0)) > 0 and int(td.get("budget_bytes", 0)) <= 8 * 1024 * 1024 and td.get("free_roam") == false, "m0 registry: test district has a budget and is off in free roam")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	expect(presets.contains("districts/*\"") and presets.contains("name=\"District test_district\""), "m0 export: main preset excludes districts/, a district preset exists")

func _m0_main() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(10)
	return main

func _m0_free_roam_unchanged() -> void:
	var main = await _m0_main()
	var loader = main.get_node_or_null("Districts")
	expect(loader != null and loader.armed.is_empty(), "m0 free roam: no district armed without a flag")
	expect(main.world_sim.find_child("DistrictApron_*", false, false) == null and not loader.view.visible, "m0 free roam: no apron and no loading card")
	expect(main.zone_at(main.player.global_position) == "SKATE YARD" and loader.zone_for(main.player.global_position) == "", "m0 free roam: spawn zone unchanged")
	main.queue_free()
	await frames(2)

func _m0_arm(main, pack_dir: String, force_pack: bool) -> Node:
	var loader = main.get_node("Districts")
	main.flow.save_path = "user://m0-district-save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.flow.save_path))
	loader.pack_dir = pack_dir
	loader.force_pack = force_pack
	loader.arm("test_district")
	return loader

## Push east down Rust Avenue across the district edge (x = 70). Returns the speed log.
func _m0_ride(main, x_from: float, x_to: float) -> Dictionary:
	var pl = main.player
	pl.global_position = Vector3(x_from, 0.5, 90.0)
	pl.velocity = Vector3.ZERO
	pl.camera_yaw = -PI * 0.5 - pl.rotation.y   # camera yaw is relative to the body: face +X (east)
	pl.skating = true
	pl.external_move_active = true
	pl.external_move = Vector2(0, 1)
	var log := {"edge_speed": 0.0, "min_after": 999.0, "min_y": 99.0, "skating": true, "input": true, "paused": false, "ticks": 0, "state_at_edge": ""}
	for i in 900:
		await get_tree().physics_frame
		var v := Vector2(pl.velocity.x, pl.velocity.z).length()
		var x: float = pl.global_position.x
		log.min_y = minf(log.min_y, pl.global_position.y)
		if x < 66.0:
			log.edge_speed = v
		else:
			if log.state_at_edge == "":
				log.state_at_edge = main.get_node("Districts").state("test_district")
			log.min_after = minf(log.min_after, v)
			log.skating = log.skating and pl.skating
			log.input = log.input and pl.input_enabled
			log.paused = log.paused or get_tree().paused
		log.ticks = i
		if OS.get_environment("AU_M0_DEBUG") != "" and i % 60 == 0:
			print("m0 dbg ", i, " ", pl.global_position, " v=", pl.velocity, " sk=", pl.skating, " in=", pl.input_enabled, " fr=", pl.sprite_frame, " fwd=", pl.camera_flat_forward())
		if x >= x_to:
			break
	log["x"] = pl.global_position.x
	pl.external_move = Vector2.ZERO
	pl.external_move_active = false
	return log

func _m0_district_fail_keeps_rolling() -> void:
	var main = await _m0_main()
	var loader = _m0_arm(main, "/nonexistent-m0-dir", true)
	expect(main.world_sim.get_node_or_null("DistrictApron_test_district") != null, "m0 fail: the edge apron is down before any pack")
	var ride := await _m0_ride(main, 35.0, 84.0)
	expect(loader.state("test_district") == "failed" and str(loader.info.test_district.reason) == "no_source", "m0 fail: a missing pack fails cleanly (%s)" % str(loader.info.test_district.reason))
	expect(ride.x >= 84.0 and ride.min_y > -0.5 and ride.skating and ride.input and not ride.paused, "m0 fail: Fony rolls onto the apron with input and skating intact (x %.1f, y min %.2f)" % [ride.x, ride.min_y])
	expect(str(loader.info.test_district.card.get("id")) == "test_intro" and loader.view.status.text.contains("NO SIGNAL"), "m0 fail: the card says the district did not load (%s)" % loader.view.status.text)
	expect(main.flow.save.district_visits("test_district") == 1, "m0 fail: crossing the edge still counts as a visit")
	main.queue_free()
	await frames(2)

func _m0_district_skate_across() -> void:
	var main = await _m0_main()
	var dir := ProjectSettings.globalize_path("res://build/web/districts")
	var have_pack := FileAccess.file_exists(dir.path_join("test_district.pck"))
	var loader = _m0_arm(main, dir if have_pack else "/nonexistent-m0-dir", false)
	var states := []
	loader.state_changed.connect(func(_id, s): states.append(s))
	var ride := await _m0_ride(main, 35.0, 104.0)
	print("m0 ride: source=%s states=%s edge_speed=%.2f min_after=%.2f state_at_edge=%s ticks=%d" % ["pack" if have_pack else "res", str(states), ride.edge_speed, ride.min_after, ride.state_at_edge, ride.ticks])
	expect(loader.state("test_district") == "ready" and main.world_sim.get_node_or_null("District_test_district") != null, "m0 district: the test district is in the world (%s)" % ("from the built pack" if have_pack else "from res://, no built pack yet"))
	expect(main.world_sim.get_node_or_null("DistrictApron_test_district") == null, "m0 district: the apron is gone once the district is in")
	expect(ride.edge_speed > 6.0 and ride.min_after >= ride.edge_speed * 0.85, "m0 district: speed carries across the edge (%.2f m/s before, min %.2f after)" % [ride.edge_speed, ride.min_after])
	expect(ride.skating and ride.input and not ride.paused and ride.min_y > -0.5, "m0 district: loading never pauses, takes input or drops Fony")
	expect(main.flow.save.district_visits("test_district") == 1 and int(main.flow.save.district_stats("test_district").first_visit_unix) > 0, "m0 district: the first visit is recorded with a time")
	expect(str(loader.info.test_district.card.get("id")) == "test_intro", "m0 district: visit 1 showed the intro card")
	expect(main.get_node("Districts").zone_for(main.player.global_position) == "TEST DISTRICT", "m0 district: the zone reads TEST DISTRICT")
	var d: Node3D = main.world_sim.get_node("District_test_district")
	expect(d.get_node_or_null("TestLedge") != null and d.get_node_or_null("TestFlatBar") != null and d.get_node_or_null("TestBank") != null, "m0 district: the district has a ledge, a flat bar and a bank")
	expect(d.get_node("TestLedge").is_in_group("grind_rail") and d.get_node("TestFlatBar").is_in_group("grind_rail"), "m0 district: its ledge and bar are grindable")
	# Leave and come back: visit 2 shows the faction card.
	main.player.global_position = Vector3(0.0, 0.5, 40.0)   # back in the yard, more than prefetch + 20 m from the edge
	await frames(3)
	var back := await _m0_ride(main, 35.0, 80.0)
	expect(main.flow.save.district_visits("test_district") == 2 and str(loader.info.test_district.card.get("id")) == "test_faction", "m0 district: visit 2 shows the faction card (%s)" % str(loader.info.test_district.card.get("id")))
	expect(back.min_after >= back.edge_speed * 0.85, "m0 district: re-entry keeps speed too")
	var saved = SaveScript.new()
	expect(saved.load_exploration_user(main.flow.save_path).get("ok") == true and saved.district_visits("test_district") == 2, "m0 district: visits are persisted")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.flow.save_path))
	main.queue_free()
	await frames(2)
