extends Node

const Palette = preload("res://scripts/palette.gd")
const Yard = preload("res://scripts/yard.gd")
const JsonFile = preload("res://scripts/json_file.gd")
const FlowScript = preload("res://scripts/hq_flow.gd")
const DistrictLoader = preload("res://scripts/district_loader.gd")
const PracticeRun = preload("res://scripts/story/practice_run.gd")
const SaveScript = preload("res://contracts/save_record.gd")
const FREE_AUTOSAVE_S := 90.0

var flow: Node
var world_sim: Node3D
var player: CharacterBody3D
var zone_label: Label
var mode_label: Label
var prompt_label: Label
var dialogue_panel: PanelContainer
var dialogue_text: Label
var pause_panel: PanelContainer
var look_catch: Control
var visual_demo := false
var look_label: Label
var hint_label: Label
var invert_check: CheckButton
## M0 district packs (scripts/district_loader.gd). Idle unless a district is armed; free roam is unchanged.
var districts: Node
## M1 story mode (scripts/story/practice_run.gd): P.1 Practice Run. Idle until P (provisional key), story=p1 on the
## command line or ?story=p1 in the web build. Free roam is unchanged while it is idle.
var story: Node
## Front end (Nov 19 2026): the start screen's choice (GameSession autoload). "" = no front end (dev shortcuts, tests).
var gs: Node
var session_intent := ""
var session_buttons: HBoxContainer
var session_status: Label
var free_autosave_clock := 0.0
var load_result := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_environment()
	world_sim = Node3D.new()
	world_sim.name = "WorldSim"
	world_sim.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world_sim)
	Yard.build(world_sim)
	player = load("res://scenes/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3(-42.0, 0.5, 2.0)
	player.rotation.y = 1.05
	world_sim.add_child(player)
	var session = load("res://scenes/session_overlay.tscn").instantiate()
	add_child(session)
	flow = FlowScript.new()
	flow.name = "Flow"
	add_child(flow)
	flow.bind(world_sim, player, get_node("/root/AudioOwner"), session, self)
	_hud()
	var popup = load("res://scripts/trick_popup.gd").new()
	popup.name = "TrickPopup"
	popup.player = player
	add_child(popup)
	districts = DistrictLoader.new()
	districts.name = "Districts"
	districts.bind(self)
	add_child(districts)
	_apply_story()
	# save v2: keep mission progress in memory so a free-roam save never wipes it
	flow.save.load_story_user(flow.save_path)
	story = PracticeRun.new()
	story.name = "Story"
	story.bind(self)
	add_child(story)
	_front_end()

func _process(_delta: float) -> void:
	if player == null:
		return
	if gs != null and gs.has_character() and not flow.paused and flow.boundary.phase == "world":
		gs.play_time += _delta
		if story == null or not story.active:
			free_autosave_clock += _delta
			if free_autosave_clock >= FREE_AUTOSAVE_S:
				free_autosave_clock = 0.0
				flow.persist()
	var district_zone: String = districts.zone_for(player.global_position) if districts != null else ""
	zone_label.text = district_zone if district_zone != "" else zone_at(player.global_position)
	var mode := "SKATE" if player.skating else "WALK"
	if player.sprite_frame.begins_with("kickup"):
		mode = "KICK UP"
	elif player.sprite_frame.begins_with("dropin"):
		mode = "DROP IN"
	mode_label.text = mode
	var target = null
	if player.input_enabled and flow.boundary.phase == "world" and not flow.dialogue_open and not flow.paused:
		target = _nearest(2.5)
	prompt_label.text = target.prompt() if target != null and target.has_method("prompt") and not story_hides_prompts() else ""
	if player.look_captured and not _can_look():
		_release_look()
	_sync_look_catch()
	_maybe_demo()
	_publish_web_state()

func _unhandled_input(event: InputEvent) -> void:
	if flow == null:
		return
	if flow.boundary.phase == "in_session":
		return
	if flow.paused:
		if session_buttons != null and session_buttons.visible and (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")) and get_viewport().gui_get_focus_owner() == null:
			session_buttons.get_child(0).grab_focus()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("pause") or event.is_action_pressed("session_confirm"):
			flow.set_paused(false)
			get_viewport().set_input_as_handled()
		return
	if flow.dialogue_open and (event.is_action_pressed("interact") or event.is_action_pressed("session_confirm") or event.is_action_pressed("pause")):
		if event.is_action_pressed("pause"):
			flow.close_dialogue()
		else:
			flow.advance_dialogue()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		_release_look()
		flow.set_paused(true)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and player.look_captured and _can_look():
		player.push_mouse_look(event.relative)
		get_viewport().set_input_as_handled()
		return
	if not player.input_enabled:
		return
	if event.is_action_pressed("story_toggle") and story != null:
		story.toggle()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("mission_retry") and story != null and story.active:
		story.retry()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_BRACKETLEFT:
			player.adjust_look_sensitivity(-0.0004)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_BRACKETRIGHT:
			player.adjust_look_sensitivity(0.0004)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("skate_toggle"):
		# Phase 3 (LOCAL puppet test): on a quarter-pipe deck facing the coping, Shift sets up / backs out of a drop-in
		if player.has_method("skate_toggle_pressed"):
			player.skate_toggle_pressed()
		else:
			player.skating = not player.skating
			player.update_board()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		var target = _nearest(2.5)
		if target != null:
			target.interact(flow)
			get_viewport().set_input_as_handled()

func zone_at(point: Vector3) -> String:
	return Yard.zone_at(point)

func show_dialogue(speaker: String, line: String) -> void:
	dialogue_panel.visible = true
	dialogue_text.text = speaker + ": " + line

func show_dialogue_line(line: String) -> void:
	var speaker := dialogue_text.text.split(": ", false, 1)[0]
	dialogue_text.text = speaker + ": " + line

func hide_dialogue() -> void:
	dialogue_panel.visible = false

func show_pause(show_panel: bool) -> void:
	pause_panel.visible = show_panel
	if show_panel and invert_check != null:
		invert_check.set_pressed_no_signal(player.look_invert_y)
	if session_buttons != null:
		session_buttons.visible = show_panel and gs != null and gs.has_character()
	if session_status != null and show_panel:
		session_status.text = ("Playing as %s. Autosaves at checkpoints. Up/Down picks a button." % gs.player_name()) if gs != null and gs.has_character() else ""

func _nearest(radius: float) -> Node:
	var best: Node = null
	var best_distance := radius
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node.has_method("interact"):
			continue
		var distance := player.global_position.distance_to(node.global_position)
		if distance < best_distance:
			best = node
			best_distance = distance
	return best

func _environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var proc := ProceduralSkyMaterial.new()
	proc.sky_top_color = Color("6d4f92")
	proc.sky_horizon_color = Color("f2b07a")
	proc.ground_horizon_color = Color("e09a6a")
	proc.ground_bottom_color = Color("6a5348")
	proc.sun_angle_max = 12.0
	sky.sky_material = proc
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7e92ae")
	env.ambient_light_energy = 0.36
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -70, 0)
	sun.light_color = Color("ffc090")
	sun.light_energy = 1.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.2
	add_child(sun)

func _apply_story() -> void:
	var story = JsonFile.read("res://data/story_working.json")
	if typeof(story) != TYPE_DICTIONARY:
		return
	var lines = story.get("npc_lines", {})
	if typeof(lines) != TYPE_DICTIONARY:
		return
	var npc = world_sim.get_node_or_null("NPCZero")
	var spoken = lines.get("zero", [])
	if npc != null and typeof(spoken) == TYPE_ARRAY:
		npc.lines = PackedStringArray(spoken)

func _hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var margin := MarginContainer.new()
	layer.add_child(margin)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 16
	margin.offset_top = 12
	margin.offset_right = -16
	margin.offset_bottom = -12
	var column := VBoxContainer.new()
	margin.add_child(column)
	zone_label = Label.new()
	mode_label = Label.new()
	hint_label = Label.new()
	var hint := hint_label
	hint.text = "Click to look. Mouse turns the view; W moves that way. [ ] look speed\nWASD move   Space jump   Shift skate/walk   E talk or cabinet   Enter confirm   Esc pause\nQ ollie   R kickflip   F grab   On a rail: F 5-0, R boardslide   Quarter pipe: hold S up high to kickturn, F off the coping for a backside air\nGamepad: left stick move, right stick look, A jump, Y skate, X interact, Start pause"
	prompt_label = Label.new()
	for label in [zone_label, mode_label, hint, prompt_label]:
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("fff8ef"))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 4)
		column.add_child(label)
	hint.add_theme_font_size_override("font_size", 14)
	dialogue_panel = _center_panel()
	dialogue_text = dialogue_panel.get_child(0).get_child(0)
	layer.add_child(dialogue_panel)
	pause_panel = _center_panel()
	var pause_label: Label = pause_panel.get_child(0).get_child(0)
	pause_label.text = "Paused. Click outside this panel to resume and look. Esc or Enter resumes."
	invert_check = CheckButton.new()
	invert_check.name = "InvertMouseY"
	invert_check.text = "Invert mouse Y"
	invert_check.focus_mode = Control.FOCUS_NONE
	invert_check.process_mode = Node.PROCESS_MODE_ALWAYS
	invert_check.set_pressed_no_signal(player.look_invert_y)
	invert_check.toggled.connect(_on_invert_y)
	pause_panel.get_child(0).add_child(invert_check)
	var sprite_check := CheckButton.new()
	sprite_check.name = "PaintedSprite"
	sprite_check.text = "Painted sprite"
	sprite_check.focus_mode = Control.FOCUS_NONE
	sprite_check.process_mode = Node.PROCESS_MODE_ALWAYS
	sprite_check.set_pressed_no_signal(player.use_painted_sprite)
	sprite_check.toggled.connect(_on_painted_sprite)
	pause_panel.get_child(0).add_child(sprite_check)
	# front end: Save / Load / Quit to title, only when playing a character from the start screen
	session_buttons = HBoxContainer.new()
	session_buttons.name = "SessionButtons"
	session_buttons.add_theme_constant_override("separation", 12)
	session_buttons.visible = false
	for spec in [["SaveGame", "Save", save_manual], ["LoadGame", "Load", load_from_pause], ["QuitToTitle", "Quit to title", quit_to_title]]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.process_mode = Node.PROCESS_MODE_ALWAYS
		b.pressed.connect(spec[2])
		session_buttons.add_child(b)
	pause_panel.get_child(0).add_child(session_buttons)
	session_status = Label.new()
	session_status.name = "SessionStatus"
	session_status.add_theme_font_size_override("font_size", 14)
	session_status.add_theme_color_override("font_color", Color("c6ff3d"))
	pause_panel.get_child(0).add_child(session_status)
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(pause_panel)
	look_catch = Control.new()
	look_catch.set_anchors_preset(Control.PRESET_FULL_RECT)
	look_catch.mouse_filter = Control.MOUSE_FILTER_STOP
	look_catch.gui_input.connect(_on_look_catch)
	layer.add_child(look_catch)
	look_label = Label.new()
	look_label.set_anchors_preset(Control.PRESET_CENTER)
	look_label.offset_left = -220
	look_label.offset_right = 220
	look_label.offset_top = -40
	look_label.offset_bottom = 40
	look_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	look_label.add_theme_font_size_override("font_size", 22)
	look_label.add_theme_color_override("font_color", Color("fff6ea"))
	look_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	look_label.add_theme_constant_override("outline_size", 6)
	look_catch.add_child(look_label)
	layer.move_child(pause_panel, -1)
	layer.move_child(dialogue_panel, -1)

func _center_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -230
	panel.offset_bottom = -36
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.07, 0.92)
	style.border_color = Color("e0a15a")
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("fff6ea"))
	box.add_child(label)
	return panel

func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT and what != NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		return
	if flow == null or player == null:
		return
	if player.look_captured:
		_release_look()
	if flow.boundary.phase == "world" and not flow.paused and not flow.dialogue_open:
		flow.set_paused(true)

func _can_look() -> bool:
	return player != null and flow != null and flow.boundary.phase == "world" and not flow.paused and not flow.dialogue_open and player.input_enabled

func _capture_look() -> void:
	if not _can_look():
		return
	player.look_captured = true
	player.clear_mouse_look()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _release_look() -> void:
	if player != null:
		player.look_captured = false
		player.clear_mouse_look()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _sync_look_catch() -> void:
	if look_catch == null:
		return
	if visual_demo:
		look_catch.visible = false
		look_catch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var show := false
	if flow.boundary.phase == "in_session" or flow.dialogue_open:
		show = false
	elif story_hides_prompts() and not flow.paused:
		# Act I: no "Click to look" (or any input prompt) over a cutscene or a fade
		show = false
	elif flow.paused:
		show = true
		look_label.text = "Paused\nClick to resume and look"
	elif not player.look_captured:
		show = true
		look_label.text = "Click to look"
	look_catch.visible = show
	look_catch.mouse_filter = Control.MOUSE_FILTER_STOP if show else Control.MOUSE_FILTER_IGNORE
	if hint_label != null:
		hint_label.text = "Click to look. Mouse turns the view; W moves that way. Look speed %.3f  [ ]\nWASD move   Space jump   Shift skate/walk   Q ollie   R kickflip   F grab   E talk\nOn a rail: F 5-0, R boardslide.  Quarter pipe: hold S high up to kickturn, F off the coping for a backside air\nEnter confirm   Esc pause. Invert mouse Y is in the pause menu.   P story: Practice Run" % player.look_sensitivity

## True while the story plays a cutscene (or a chase fade): HUD input prompts stay hidden.
func story_hides_prompts() -> bool:
	return story != null and story.has_method("hides_prompts") and story.hides_prompts()

func _on_look_catch(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if flow.paused:
		flow.set_paused(false)
	if _can_look():
		_capture_look()
	look_catch.accept_event()

var demo_armed := false

func _maybe_demo() -> void:
	if demo_armed or player == null or flow == null or flow.boundary.phase != "world":
		return
	var kind := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("demo="):
			kind = arg.trim_prefix("demo=")
	if kind == "" and OS.has_feature("web"):
		var search := str(JavaScriptBridge.eval("window.location.search", true))
		if "demo=ollie" in search:
			kind = "ollie"
		elif "demo=flip" in search:
			kind = "flip"
		elif "demo=grab" in search:
			kind = "grab"
		elif "demo=ramp" in search:
			kind = "ramp"
		else:
			for k in player.DEMO_LINES.keys():
				if ("demo=" + str(k)) in search:
					kind = str(k)
		if "demo=cabinet-" in search:
			_demo_cabinet(search.split("demo=cabinet-")[1].split("&")[0])
	demo_armed = true
	if story != null and not story.active and (OS.get_cmdline_user_args().has("story=p1") or (OS.has_feature("web") and "story=p1" in str(JavaScriptBridge.eval("window.location.search", true)))):
		story.start()
	if kind == "":
		return
	visual_demo = true
	player.start_visual_demo(kind)

## Finish pass browser check (?demo=cabinet-<game id>): open that arcade cabinet the way pressing E at it does
## (arcade_cabinet.gd interact -> arcade_overlay.gd), so the check sees the real overlay and iframe.
func _demo_cabinet(id: String) -> void:
	var door = world_sim.get_node_or_null("ArcadeDoor")
	if door == null:
		return
	var interior = door.ensure_interior()
	if interior == null or not ("cabinets" in interior) or not interior.cabinets.has(id):
		return
	interior.cabinets[id].interact(flow)

func _on_invert_y(enabled: bool) -> void:
	if player == null:
		return
	player.choose_invert_y(enabled)

func _on_painted_sprite(enabled: bool) -> void:
	if player == null:
		return
	player.set_painted_sprite(enabled)

func _publish_web_state() -> void:
	if not OS.has_feature("web") or flow == null:
		return
	var ahead: Vector3 = player.camera_flat_forward()
	var spin := 0.0
	var pose := ""
	if player.rig != null:
		spin = player.rig.board.rotation.z if player.rig.board != null else 0.0
		pose = str(player.rig.pose_name)
	var js := "window.AU_HQ={x:%s,y:%s,z:%s,yaw:%s,fx:%s,fz:%s,skating:%s,session:'%s',input:%s,look:%s,paused:%s,invert:%s,trick:'%s',pose:'%s',spin:%s,zone:'%s',frame:'%s',sprite:%s,grind:'%s',callout:'%s',calls:%d,bsair:'%s',kickturns:%d};" % [
		snapped(player.global_position.x, 0.01),
		snapped(player.global_position.y, 0.01),
		snapped(player.global_position.z, 0.01),
		snapped(player.camera_yaw, 0.001),
		snapped(ahead.x, 0.0001),
		snapped(ahead.z, 0.0001),
		"true" if player.skating else "false",
		flow.boundary.phase,
		"true" if player.input_enabled else "false",
		"true" if player.look_captured else "false",
		"true" if flow.paused else "false",
		"true" if player.look_invert_y else "false",
		player.trick,
		pose,
		snapped(spin, 0.01),
		zone_label.text if zone_label != null else zone_at(player.global_position),
		player.sprite_frame,
		"true" if player.use_painted_sprite else "false",
		(str(player.grind_trick) + "@" + str(player.grind.name)) if player.grind != null else "",
		str(player.callout).replace("'", ""),
		int(player.callout_id),
		str(player.bsair_last.get("result", "")),
		int(player.kt_count),
	]
	JavaScriptBridge.eval(js, true)

# ------------------------------------------------------------------ front end (Nov 19 2026): new game, load, save

## Acts on the start screen's choice once the park is built. Without one (dev shortcuts, tests) nothing changes.
func _front_end() -> void:
	gs = get_node_or_null("/root/GameSession")
	if gs == null:
		return
	session_intent = gs.take_intent()
	if session_intent == "new":
		new_game()
	elif session_intent == "load":
		load_result = load_game(gs.character, gs.load_kind)

## New Game: a fresh save for the chosen character, written to its autosave, then P.1 from the top. The intro video
## has already played (or been skipped) on the start screen.
func new_game() -> void:
	flow.save = SaveScript.new()
	flow.save_path = gs.auto_path()
	flow.save.set_flag("p1_intro_seen")
	flow.persist()
	story.start()

## Load Game: restore a character's autosave or manual save. Story missions resume at their last checkpoint;
## free roam puts the player back where they were. The loaded save becomes the autosave from here on.
func load_game(character: String, kind: String) -> Dictionary:
	var r: Dictionary = gs.slots.read(gs.account_key(), character, kind)
	if not bool(r.get("ok", false)) and kind == "manual":
		r = gs.slots.read(gs.account_key(), character, "auto")
	if not bool(r.get("ok", false)):
		push_warning("load: no save for %s (%s)" % [character, r])
		return {"ok": false, "reason": r.get("reason", "missing")}
	var rec = r.record
	flow.save = rec
	flow.save_path = gs.auto_path()
	# the loaded save becomes the autosave first, so story.start() (which re-reads the story block from disk) sees it
	rec.save_user(flow.save_path)
	gs.play_time = float(rec.meta.get("play_time_s", 0.0))
	gs.created_unix = int(rec.meta.get("created_unix", 0))
	_apply_settings(rec.settings)
	var p: Dictionary = rec.player
	var current := str(rec.story.get("current", ""))
	var resumed := ""
	if current == "p1_practice_run" or (p.get("mode", "") == "story" and current == ""):
		story.start(true)
		resumed = "story"
		var m: Dictionary = rec.mission("p1_practice_run")
		if str(m.get("state", "")) == "done" and (p.get("pos", []) as Array).size() == 3:
			place_player(_vec(p.pos), float(p.get("yaw", 0.0)), bool(p.get("skating", true)))
	elif (p.get("pos", []) as Array).size() == 3:
		place_player(_vec(p.pos), float(p.get("yaw", 0.0)), bool(p.get("skating", true)))
		resumed = "free"
	flow.persist()
	return {"ok": true, "resumed": resumed, "path": r.path, "kind": kind}

static func _vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func place_player(pos: Vector3, yaw: float, skating := true) -> void:
	player.spawn_position = pos
	player.spawn_yaw = yaw
	player.respawn()
	player.camera_yaw = 0.0
	if player.rig != null and player.rig.has_method("face_world"):
		player.rig.face_world(yaw)
	player.skating = skating
	player.update_board()

func _apply_settings(st: Dictionary) -> void:
	if st.has("invert_y") and bool(st.invert_y) != player.look_invert_y:
		player.choose_invert_y(bool(st.invert_y))
	if st.has("look_sensitivity"):
		player.look_sensitivity = float(st.look_sensitivity)
	if st.has("painted_sprite"):
		player.set_painted_sprite(bool(st.painted_sprite))

## Called by flow.persist() before every write. Legacy sessions (no character) are left exactly as before.
func fill_save(save) -> void:
	if gs == null or not gs.has_character():
		return
	gs.stamp(save, "auto")
	var district := ""
	if districts != null:
		for id in districts.armed:
			if districts.info.has(id) and bool(districts.info[id].get("entered", false)):
				district = id
	save.player = {
		"mode": "story" if story != null and story.active else "free",
		"district": district,
		"zone": zone_label.text if zone_label != null else zone_at(player.global_position),
		"pos": [snappedf(player.global_position.x, 0.01), snappedf(player.global_position.y, 0.01), snappedf(player.global_position.z, 0.01)],
		"yaw": snappedf(player.rotation.y + player.camera_yaw, 0.001),
		"skating": player.skating,
	}
	save.settings = {"invert_y": player.look_invert_y, "look_sensitivity": player.look_sensitivity, "painted_sprite": player.use_painted_sprite}

var save_count := 0

func after_save(save) -> void:
	if gs != null and gs.has_character():
		gs.note_autosave(save)
		save_count += 1
		_publish_save(str(save.meta.get("kind", "auto")))

## Web review hook: window.AU_SAVE says which character last saved, where and how often (browser checks wait on it).
func _publish_save(kind: String) -> void:
	if not OS.has_feature("web"):
		return
	var mission := str(flow.save.story.get("current", ""))
	var m: Dictionary = flow.save.story.get("missions", {}).get(mission, {})
	var st := {"character": gs.player_name(), "account": gs.account_key(), "kind": kind, "count": save_count,
		"mission": mission, "state": str(m.get("state", "")), "checkpoint": str(m.get("checkpoint", "")),
		"loaded": load_result.duplicate() if load_result is Dictionary else {}}
	JavaScriptBridge.eval("window.AU_SAVE=%s;" % JSON.stringify(st), true)

## Pause menu: Save. Writes the manual slot (and the autosave).
func save_manual() -> Dictionary:
	if gs == null or not gs.has_character():
		return {"ok": false, "reason": "no_character"}
	flow.persist()
	fill_save(flow.save)
	var r: Dictionary = gs.save_manual(flow.save)
	if session_status != null:
		session_status.text = ("Saved as %s." % gs.player_name()) if bool(r.get("ok", false)) else "Save failed."
	return r

## Pause menu: Quit to title (autosaves first).
func quit_to_title() -> void:
	if gs != null and gs.has_character():
		flow.persist()
	_leave_to_title("")

## Pause menu: Load. Autosaves, then opens Load Game on the start screen.
func load_from_pause() -> void:
	if gs != null and gs.has_character():
		flow.persist()
	_leave_to_title("load")

var left_to_title := ""
func _leave_to_title(open: String) -> void:
	left_to_title = "title" + (":" + open if open != "" else "")
	if gs != null:
		gs.open_on_title = open if open != "" else "menu"
		gs.clear()
	get_tree().paused = false
	flow.paused = false
	_release_look()
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file.call_deferred("res://scenes/start_screen.tscn")
