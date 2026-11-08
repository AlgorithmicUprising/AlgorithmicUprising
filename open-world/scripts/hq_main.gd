extends Node

const Palette = preload("res://scripts/palette.gd")
const Yard = preload("res://scripts/yard.gd")
const JsonFile = preload("res://scripts/json_file.gd")
const FlowScript = preload("res://scripts/hq_flow.gd")

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
var look_label: Label
var hint_label: Label

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
	_apply_story()

func _process(_delta: float) -> void:
	if player == null:
		return
	zone_label.text = zone_at(player.global_position)
	mode_label.text = "SKATE" if player.skating else "WALK"
	var target = null
	if player.input_enabled and flow.boundary.phase == "world" and not flow.dialogue_open and not flow.paused:
		target = _nearest(2.5)
	prompt_label.text = target.prompt() if target != null and target.has_method("prompt") else ""
	if player.look_captured and not _can_look():
		_release_look()
	_sync_look_catch()
	_publish_web_state()

func _unhandled_input(event: InputEvent) -> void:
	if flow == null:
		return
	if flow.boundary.phase == "in_session":
		return
	if flow.paused:
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
	hint.text = "Click to look. Mouse turns the view; W moves that way. [ ] look speed\nWASD move   Space jump   Shift skate/walk   E talk or cabinet   Enter confirm   Esc pause\nGamepad: left stick move, right stick look, A jump, Y skate, X interact, Start pause"
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
	pause_label.text = "Paused. Click to resume and look. Esc or Enter resumes."
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

func _center_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -180
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
	var show := false
	if flow.boundary.phase == "in_session" or flow.dialogue_open:
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
		hint_label.text = "Click to look. Mouse turns the view; W moves that way. Look speed %.3f  [ ]\nWASD move   Space jump   Shift skate/walk   E talk or cabinet   Enter confirm   Esc pause\nGamepad: left stick move, right stick look, A jump, Y skate, X interact, Start pause" % player.look_sensitivity

func _on_look_catch(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if flow.paused:
		flow.set_paused(false)
	if _can_look():
		_capture_look()
	look_catch.accept_event()

func _publish_web_state() -> void:
	if not OS.has_feature("web") or flow == null:
		return
	var js := "window.AU_HQ={x:%s,y:%s,z:%s,yaw:%s,skating:%s,session:'%s',input:%s,look:%s,paused:%s,zone:'%s'};" % [
		snapped(player.global_position.x, 0.01),
		snapped(player.global_position.y, 0.01),
		snapped(player.global_position.z, 0.01),
		snapped(player.camera_yaw, 0.001),
		"true" if player.skating else "false",
		flow.boundary.phase,
		"true" if player.input_enabled else "false",
		"true" if player.look_captured else "false",
		"true" if flow.paused else "false",
		zone_at(player.global_position),
	]
	JavaScriptBridge.eval(js, true)
