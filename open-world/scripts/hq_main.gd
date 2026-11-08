extends Node

const Blocks = preload("res://scripts/world_blocks.gd")
const Palette = preload("res://scripts/palette.gd")
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_environment()
	world_sim = Node3D.new()
	world_sim.name = "WorldSim"
	world_sim.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world_sim)
	_district()
	player = load("res://scenes/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3(0.2, 0.3, 7.5)
	player.rotation.y = -0.28
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
		flow.set_paused(true)
		get_viewport().set_input_as_handled()
		return
	if not player.input_enabled:
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
	if point.z < -9.0:
		return "ARCADE"
	if point.x > 14.0:
		return "SHOPPING EDGE"
	return "SKATE PARK"

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
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.AMBIENT
	env.ambient_light_energy = 0.55
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -40, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48.0
	add_child(sun)

func _district() -> void:
	Blocks.solid(world_sim, "Ground", Vector3(0, -0.5, -3), Vector3(54, 1, 50), Palette.GROUND)
	Blocks.solid(world_sim, "FenceNorth", Vector3(0, 1.1, -23.5), Vector3(50, 2.2, 0.4), Palette.FENCE)
	Blocks.solid(world_sim, "FenceSouth", Vector3(0, 1.1, 17.5), Vector3(50, 2.2, 0.4), Palette.FENCE)
	Blocks.solid(world_sim, "FenceWest", Vector3(-23, 1.1, -3), Vector3(0.4, 2.2, 42), Palette.FENCE)
	Blocks.solid(world_sim, "FenceEast", Vector3(24.5, 1.1, -3), Vector3(0.4, 2.2, 42), Palette.FENCE)
	Blocks.label(world_sim, "NEIGHBORHOOD NOT BUILT", Vector3(0, 2.5, -23.1), Palette.LABEL_COOL, 42)
	Blocks.visual(world_sim, "ZoneSkatePark", Vector3(0, 0.03, 1.5), Vector3(18, 0.05, 15), Palette.SKATE)
	Blocks.solid(world_sim, "Funbox", Vector3(-6.5, 0.4, 0.5), Vector3(3.2, 0.8, 3.2), Palette.FUNBOX)
	Blocks.add_ramp(world_sim, "Ramp", Vector3(-1.2, 0, -2.2))
	Blocks.add_ramp(world_sim, "RampTwo", Vector3(5.2, 0, -2.2))
	Blocks.solid(world_sim, "PaintWall", Vector3(-1.5, 0.7, 6.2), Vector3(0.4, 1.4, 3.4), Palette.PARK_WALL)
	Blocks.visual(world_sim, "PaintA", Vector3(-1.25, 0.95, 5.7), Vector3(0.08, 0.8, 1.1), Palette.PAINT_A)
	Blocks.visual(world_sim, "PaintB", Vector3(-1.25, 0.85, 6.9), Vector3(0.08, 0.55, 0.9), Palette.PAINT_B)
	Blocks.label(world_sim, "SKATE PARK", Vector3(-6.2, 2.5, 6.4))
	var rail = load("res://scenes/grind_rail.tscn").instantiate()
	rail.name = "GrindRail"
	rail.length = 8.0
	rail.position = Vector3(1.2, 1.05, 4.2)
	world_sim.add_child(rail)
	Blocks.label(world_sim, "RAIL", Vector3(1.2, 1.6, 4.2), Palette.LABEL, 32)
	Blocks.visual(world_sim, "ZoneArcade", Vector3(0, 0.02, -15), Vector3(14, 0.04, 8), Palette.ARCADE_FLOOR)
	Blocks.solid(world_sim, "ArcadeBack", Vector3(0, 2, -19.2), Vector3(16, 4, 0.45), Palette.ARCADE)
	Blocks.solid(world_sim, "ArcadeLeft", Vector3(-8, 2, -15.2), Vector3(0.45, 4, 8.2), Palette.ARCADE)
	Blocks.solid(world_sim, "ArcadeRight", Vector3(8, 2, -15.2), Vector3(0.45, 4, 8.2), Palette.ARCADE)
	Blocks.solid(world_sim, "ArcadeFrontLeft", Vector3(-5.25, 2, -11.1), Vector3(5.5, 4, 0.45), Palette.ARCADE)
	Blocks.solid(world_sim, "ArcadeFrontRight", Vector3(5.25, 2, -11.1), Vector3(5.5, 4, 0.45), Palette.ARCADE)
	Blocks.solid(world_sim, "ArcadeSign", Vector3(0, 3.55, -10.75), Vector3(5.2, 0.9, 0.22), Palette.ARCADE_SIGN)
	Blocks.label(world_sim, "ARCADE", Vector3(0, 4.35, -10.5))
	var cabinet = load("res://scenes/cabinet.tscn").instantiate()
	cabinet.name = "Cabinet"
	cabinet.position = Vector3(0, 0.85, -12.2)
	world_sim.add_child(cabinet)
	Blocks.visual(world_sim, "ZoneShoppingEdge", Vector3(18.2, 0.025, 1), Vector3(7.5, 0.05, 20), Palette.SIDEWALK)
	Blocks.visual(world_sim, "Curb", Vector3(14.2, 0.08, 1), Vector3(0.35, 0.12, 20), Palette.CURB)
	Blocks.solid(world_sim, "ShopA", Vector3(20.4, 1.5, -6), Vector3(4.8, 3.0, 4.6), Palette.SHOP_A)
	Blocks.solid(world_sim, "ShopB", Vector3(20.4, 2.2, 1.2), Vector3(4.8, 4.4, 4.8), Palette.SHOP_B)
	Blocks.solid(world_sim, "ShopC", Vector3(20.4, 1.15, 8.2), Vector3(4.8, 2.3, 4.2), Palette.SHOP_C)
	Blocks.solid(world_sim, "SurveillanceMast", Vector3(20.4, 5.15, 1.2), Vector3(0.5, 0.28, 0.4), Palette.SURVEILLANCE)
	Blocks.label(world_sim, "SHOPPING EDGE", Vector3(16.2, 2.8, 12.2), Palette.LABEL_COOL)
	Blocks.label(world_sim, "SURVEILLANCE", Vector3(20.4, 6.0, 1.2), Palette.LABEL_COOL, 36)
	_npc("NPCZero", "zero", "Zero", Palette.ZERO, Vector3(-4.5, 0, 2.4))
	_npc("NPCFony", "fony", "Fony", Palette.FONY, Vector3(3.4, 0, -10.0))

func _npc(node_name: String, id: String, display_name: String, color: Color, pos: Vector3) -> void:
	var npc = load("res://scenes/npc.tscn").instantiate()
	npc.name = node_name
	npc.npc_id = id
	npc.display_name = display_name
	npc.body_color = color
	npc.position = pos
	world_sim.add_child(npc)

func _apply_story() -> void:
	var story = JsonFile.read("res://data/story_working.json")
	if typeof(story) != TYPE_DICTIONARY:
		return
	var lines = story.get("npc_lines", {})
	if typeof(lines) != TYPE_DICTIONARY:
		return
	for npc_name in ["NPCZero", "NPCFony"]:
		var npc = world_sim.get_node_or_null(npc_name)
		if npc == null:
			continue
		var key := "zero" if npc_name == "NPCZero" else "fony"
		var spoken = lines.get(key, [])
		if typeof(spoken) == TYPE_ARRAY:
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
	var hint := Label.new()
	hint.text = "WASD move    Space jump    Shift skate/walk    E talk or cabinet    Q/E look    Esc pause\nGamepad map: left stick, A jump, Y skate, X interact, right stick look, Start pause"
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
	pause_label.text = "Paused. Esc or Enter resumes."
	layer.add_child(pause_panel)

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

func _publish_web_state() -> void:
	if not OS.has_feature("web") or flow == null:
		return
	var js := "window.AU_HQ={x:%s,y:%s,z:%s,skating:%s,session:'%s',input:%s,zone:'%s'};" % [
		snapped(player.global_position.x, 0.01),
		snapped(player.global_position.y, 0.01),
		snapped(player.global_position.z, 0.01),
		"true" if player.skating else "false",
		flow.boundary.phase,
		"true" if player.input_enabled else "false",
		zone_at(player.global_position),
	]
	JavaScriptBridge.eval(js, true)
