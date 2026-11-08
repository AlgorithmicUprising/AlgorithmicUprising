extends Node

static var installed := false

func _ready() -> void:
	install()

static func install() -> void:
	if installed:
		return
	installed = true
	_keys("move_forward", [KEY_W, KEY_UP])
	_keys("move_back", [KEY_S, KEY_DOWN])
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_keys("jump", [KEY_SPACE])
	_button("jump", JOY_BUTTON_A)
	_keys("interact", [KEY_E])
	_button("interact", JOY_BUTTON_X)
	_keys("skate_toggle", [KEY_SHIFT])
	_button("skate_toggle", JOY_BUTTON_Y)
	# Q and E are not camera keys. E is interact only. Q stays unused.
	# Right stick still looks. Keyboard look is the mouse.
	_axis("camera_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("camera_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("camera_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("camera_down", JOY_AXIS_RIGHT_Y, 1.0)
	_keys("pause", [KEY_ESCAPE])
	_button("pause", JOY_BUTTON_START)
	_keys("session_confirm", [KEY_ENTER, KEY_KP_ENTER])
	_button("session_confirm", JOY_BUTTON_A)
	_keys("session_cancel", [KEY_BACKSPACE])
	_button("session_cancel", JOY_BUTTON_B)

static func _add(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)

static func _keys(action: String, keys: Array) -> void:
	_add(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		InputMap.action_add_event(action, event)

static func _button(action: String, button: JoyButton) -> void:
	_add(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

static func _axis(action: String, axis: JoyAxis, value: float) -> void:
	_add(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)
