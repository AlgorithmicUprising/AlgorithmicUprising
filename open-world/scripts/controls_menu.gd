extends CanvasLayer

const Spray = preload("res://scripts/spray.gd")

## Remap screen for the keyboard/mouse side and the Xbox side. Saved to user://pz-input-v1.json.

const ROWS := [
	["move_forward", "Move forward"],
	["move_back", "Move back"],
	["move_left", "Move left"],
	["move_right", "Move right"],
	["jump", "Jump / ollie pop"],
	["trick", "Trick"],
	["grind", "Grind"],
	["spray", "Spray / attack"],
	["boost", "Boost"],
	["push", "Push"],
	["brake", "Brake"],
	["skate_toggle", "Skate / walk"],
	["interact", "Talk / use"],
	["pause", "Pause"],
	["session_confirm", "Confirm"],
	["session_cancel", "Back"],
	["open_log", "Map / log"],
	["zero_vision", "Zero Vision"],
	["story_toggle", "Story mode"],
	["mission_retry", "Retry objective"],
]

var host = null
var status: Label
var list: VBoxContainer

func open(main) -> void:
	host = main
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -300
	panel.offset_bottom = 300
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "CONTROLS    %s" % ("Xbox" if InputBindings.using_pad() else "keyboard")
	box.add_child(title)
	var note := Label.new()
	note.text = "One trick button. Grind, spray and boost are their own actions. E cannot leave interact. Binds save on this device."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 380)
	box.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_fill()
	var tune := HBoxContainer.new()
	box.add_child(tune)
	_tune_button(tune, "Look -", func(): host.player.adjust_look_sensitivity(-0.0004); _status("Mouse look %.4f" % host.player.look_sensitivity))
	_tune_button(tune, "Look +", func(): host.player.adjust_look_sensitivity(0.0004); _status("Mouse look %.4f" % host.player.look_sensitivity))
	_tune_button(tune, "Stick -", func(): _stick(-0.1))
	_tune_button(tune, "Stick +", func(): _stick(0.1))
	var invert_y := CheckButton.new()
	invert_y.text = "Invert Y"
	invert_y.focus_mode = Control.FOCUS_ALL
	invert_y.set_pressed_no_signal(host.player.look_invert_y)
	invert_y.toggled.connect(func(v): host.player.choose_invert_y(v))
	tune.add_child(invert_y)
	var invert_x := CheckButton.new()
	invert_x.text = "Invert X"
	invert_x.focus_mode = Control.FOCUS_ALL
	invert_x.set_pressed_no_signal(host.player.look_invert_x)
	invert_x.toggled.connect(func(v): host.player.choose_invert_x(v))
	tune.add_child(invert_x)
	var stick_y := CheckButton.new()
	stick_y.text = "Invert stick Y"
	stick_y.focus_mode = Control.FOCUS_ALL
	stick_y.set_pressed_no_signal(host.player.stick_invert_y)
	stick_y.toggled.connect(func(v): host.player.choose_stick_invert_y(v))
	tune.add_child(stick_y)
	status = Label.new()
	status.text = "Stick look %.1f    spray %s" % [InputBindings.stick_look, Spray.color_name()]
	box.add_child(status)
	var close := Button.new()
	close.text = "Done"
	close.focus_mode = Control.FOCUS_ALL
	close.pressed.connect(queue_free)
	box.add_child(close)
	close.grab_focus.call_deferred()

func _fill() -> void:
	for child in list.get_children():
		child.queue_free()
	for spec in ROWS:
		var action: String = spec[0]
		var row := HBoxContainer.new()
		list.add_child(row)
		var name := Label.new()
		name.text = spec[1]
		name.custom_minimum_size = Vector2(170, 0)
		row.add_child(name)
		var keys := Label.new()
		keys.text = InputBindings.binding_label(action, "key")
		keys.custom_minimum_size = Vector2(140, 0)
		row.add_child(keys)
		var pad := Label.new()
		pad.text = InputBindings.binding_label(action, "pad")
		pad.custom_minimum_size = Vector2(140, 0)
		row.add_child(pad)
		_bind_button(row, "Key", action, "key")
		_bind_button(row, "Pad", action, "pad")

func _bind_button(row: HBoxContainer, text: String, action: String, kind: String) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(func():
		InputBindings.capture = {"action": action, "kind": kind}
		_status("Press a %s for %s" % [kind, action])
	)
	row.add_child(button)

func _tune_button(row: HBoxContainer, text: String, fn: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(fn)
	row.add_child(button)

func _stick(step: float) -> void:
	InputBindings.stick_look = clampf(InputBindings.stick_look + step, 0.4, 2.2)
	InputBindings.save_user()
	_status("Stick look %.1f" % InputBindings.stick_look)

func _status(text: String) -> void:
	if status != null:
		status.text = text

func _input(event: InputEvent) -> void:
	InputBindings.note(event)
	if InputBindings.capture.is_empty():
		if event.is_action_pressed("session_cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			queue_free()
		return
	var action := str(InputBindings.capture.get("action", ""))
	var kind := str(InputBindings.capture.get("kind", ""))
	var err := ""
	var taken := false
	if kind == "key" and event is InputEventKey and event.pressed and not event.echo:
		err = InputBindings.rebind_key(action, event.physical_keycode)
		taken = true
	elif kind == "key" and event is InputEventMouseButton and event.pressed:
		err = InputBindings.rebind_mouse(action, event.button_index)
		taken = true
	elif kind == "pad" and event is InputEventJoypadButton and event.pressed:
		err = InputBindings.rebind_button(action, event.button_index)
		taken = true
	elif kind == "pad" and event is InputEventJoypadMotion and absf(event.axis_value) > 0.65:
		err = InputBindings.rebind_axis(action, event.axis, event.axis_value)
		taken = true
	if not taken:
		return
	InputBindings.capture = {}
	get_viewport().set_input_as_handled()
	_status(err if err != "" else "Saved")
	_fill()
