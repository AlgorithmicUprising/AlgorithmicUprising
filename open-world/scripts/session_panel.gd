extends CanvasLayer

var flow: Node
var panel: PanelContainer
var status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.05, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -170
	panel.offset_bottom = 170
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a1c18")
	style.border_color = Color("e0a15a")
	style.set_border_width_all(3)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "CABINET PLACEHOLDER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paint(title, 28)
	box.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "This is not the Punk Arcade canvas and not a song session. No music is loaded. Finish or leave to return to the skate park."
	_paint(body, 18)
	box.add_child(body)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paint(status, 16)
	box.add_child(status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	row.add_child(_button("Finish", _finish))
	row.add_child(_button("Leave", _leave))
	panel.visible = false
	dim.visible = false
	panel.set_meta("dim", dim)

func show_open() -> void:
	_set_visible(true)
	if flow != null:
		status.text = "Session " + str(flow.boundary.session_id) + "  Enter finishes, Backspace or Esc leaves."

func hide_panel() -> void:
	_set_visible(false)

func _set_visible(show_panel: bool) -> void:
	panel.visible = show_panel
	var dim = panel.get_meta("dim")
	if dim is CanvasItem:
		dim.visible = show_panel

func _input(event: InputEvent) -> void:
	if panel == null or not panel.visible or flow == null:
		return
	if event.is_action_pressed("session_confirm"):
		flow.finish_session(_mode(event))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("session_cancel") or event.is_action_pressed("pause"):
		flow.abort_session(_mode(event))
		get_viewport().set_input_as_handled()

func _finish() -> void:
	if flow != null:
		flow.finish_session("unknown")

func _leave() -> void:
	if flow != null:
		flow.abort_session("unknown")

func _mode(event: InputEvent) -> String:
	if event is InputEventKey:
		return "keyboard"
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "gamepad"
	return "unknown"

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 44)
	button.pressed.connect(callback)
	return button

func _paint(label: Label, size: int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("fff6ea"))
