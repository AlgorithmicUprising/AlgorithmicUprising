extends Node

## Keyboard, mouse, and a wireless Xbox pad on the standard layout.
## Godot's joy buttons are what the WebGL export fills from the browser Gamepad API
## (standard mapping). HUD marks are original letterforms drawn by this project.
## They are not Microsoft's Xbox icons.

const MOVE_DEADZONE := 0.25
const LOOK_DEADZONE := 0.18
const TRIGGER_DEADZONE := 0.12
const STICK_CURVE := 1.65
const SAVE_PATH := "user://pz-input-v1.json"

static var installed := false
static var last_device := "keyboard"
static var stick_look := 1.0
static var capture := {}

func _ready() -> void:
	install()

static func install() -> void:
	if installed:
		return
	installed = true
	_keys("move_forward", [KEY_W, KEY_UP], MOVE_DEADZONE)
	_keys("move_back", [KEY_S, KEY_DOWN], MOVE_DEADZONE)
	_keys("move_left", [KEY_A, KEY_LEFT], MOVE_DEADZONE)
	_keys("move_right", [KEY_D, KEY_RIGHT], MOVE_DEADZONE)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0, MOVE_DEADZONE)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0, MOVE_DEADZONE)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0, MOVE_DEADZONE)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0, MOVE_DEADZONE)
	_keys("jump", [KEY_SPACE])
	_button("jump", JOY_BUTTON_A)
	# One trick button. The maneuver is chosen from context and the combo tier.
	_keys("trick", [KEY_Q])
	_button("trick", JOY_BUTTON_B)
	# Grind is its own button. Riding onto a rail still locks; holding this widens the catch.
	_keys("grind", [KEY_F])
	_button("grind", JOY_BUTTON_LEFT_SHOULDER)
	# Spray / attack: left click, and RT on the pad.
	_mouse("spray", MOUSE_BUTTON_LEFT)
	_axis("spray", JOY_AXIS_TRIGGER_RIGHT, 1.0, TRIGGER_DEADZONE)
	_keys("brake", [KEY_CTRL])
	_axis("brake", JOY_AXIS_TRIGGER_LEFT, 1.0, TRIGGER_DEADZONE)
	_keys("push", [KEY_R])
	_keys("boost", [KEY_X])
	_button("boost", JOY_BUTTON_RIGHT_SHOULDER)
	_keys("interact", [KEY_E])
	_button("interact", JOY_BUTTON_X)
	_keys("skate_toggle", [KEY_SHIFT])
	_button("skate_toggle", JOY_BUTTON_Y)
	_axis("camera_left", JOY_AXIS_RIGHT_X, -1.0, LOOK_DEADZONE)
	_axis("camera_right", JOY_AXIS_RIGHT_X, 1.0, LOOK_DEADZONE)
	_axis("camera_up", JOY_AXIS_RIGHT_Y, -1.0, LOOK_DEADZONE)
	_axis("camera_down", JOY_AXIS_RIGHT_Y, 1.0, LOOK_DEADZONE)
	_keys("pause", [KEY_ESCAPE])
	_button("pause", JOY_BUTTON_START)
	_keys("session_confirm", [KEY_ENTER, KEY_KP_ENTER])
	_button("session_confirm", JOY_BUTTON_A)
	_keys("session_cancel", [KEY_BACKSPACE])
	_button("session_cancel", JOY_BUTTON_B)
	_keys("open_log", [KEY_M])
	_button("open_log", JOY_BUTTON_BACK)
	_keys("zero_vision", [KEY_Z])
	_button("zero_vision", JOY_BUTTON_LEFT_STICK)
	_keys("story_toggle", [KEY_P])
	_button("story_toggle", JOY_BUTTON_MISC1)
	_keys("mission_retry", [KEY_T])
	_button("mission_retry", JOY_BUTTON_RIGHT_STICK)
	_ensure_button("ui_up", JOY_BUTTON_DPAD_UP)
	_ensure_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_ensure_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_ensure_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_ensure_button("ui_accept", JOY_BUTTON_A)
	_ensure_button("ui_cancel", JOY_BUTTON_B)
	scrub_conflicts()
	load_user()

## E is interact only. A remap cannot put it on the camera or on anything else.
static func scrub_conflicts() -> void:
	for action in InputMap.get_actions():
		if str(action) == "interact":
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and (event.physical_keycode == KEY_E or event.keycode == KEY_E):
				InputMap.action_erase_event(action, event)

static func curve(v: float) -> float:
	var mag := absf(v)
	if mag < 0.001:
		return 0.0
	return signf(v) * pow(mag, STICK_CURVE)

static func note(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.2:
			return
		last_device = "xbox"
	elif event is InputEventKey or event is InputEventMouseButton:
		last_device = "keyboard"
	elif event is InputEventMouseMotion and event.relative.length() >= 1.0:
		last_device = "keyboard"

static func using_pad() -> bool:
	return last_device == "xbox"

static func glyph(action: String) -> String:
	if using_pad():
		return str(PAD_GLYPH.get(action, "?"))
	return str(KEY_GLYPH.get(action, "?"))

const KEY_GLYPH := {
	"move": "WASD",
	"camera": "MOUSE",
	"jump": "SPACE",
	"trick": "Q",
	"grind": "F",
	"spray": "LMB",
	"brake": "CTRL",
	"push": "R",
	"boost": "X",
	"interact": "E",
	"skate_toggle": "SHIFT",
	"pause": "ESC",
	"session_confirm": "ENTER",
	"session_cancel": "BKSP",
	"open_log": "M",
	"zero_vision": "Z",
	"story_toggle": "P",
	"mission_retry": "T",
	"ui": "ARROWS",
}

const PAD_GLYPH := {
	"move": "LS",
	"camera": "RS",
	"jump": "A",
	"trick": "B",
	"grind": "LB",
	"spray": "RT",
	"brake": "LT",
	"push": "LS",
	"boost": "RB",
	"interact": "X",
	"skate_toggle": "Y",
	"pause": "MENU",
	"session_confirm": "A",
	"session_cancel": "B",
	"open_log": "VIEW",
	"zero_vision": "L3",
	"story_toggle": "SHARE",
	"mission_retry": "R3",
	"ui": "D-PAD",
}

static func prompt_text(text: String) -> String:
	var mark := glyph("interact")
	if text.begins_with("E  "):
		return mark + "  " + text.substr(3)
	if text.begins_with("E "):
		return mark + " " + text.substr(2)
	return text

static func hint_line() -> String:
	return "Look %s   Move %s   %s jump   %s trick   %s grind   %s spray   %s boost\n%s brake   %s push   %s talk   %s pause   %s log   %s vision   %s menus" % [
		glyph("camera"), glyph("move"), glyph("jump"), glyph("trick"), glyph("grind"),
		glyph("spray"), glyph("boost"), glyph("brake"), glyph("push"), glyph("interact"),
		glyph("pause"), glyph("open_log"), glyph("zero_vision"), glyph("ui"),
	]

static func skip_label(filled: int) -> String:
	return "HOLD %s TO SKIP  %s" % [glyph("session_confirm"), "|".repeat(filled)]

static func rumble(strong: float, weak: float, seconds: float) -> bool:
	if last_device != "xbox":
		return false
	if OS.has_feature("web") and not _web_rumble():
		return false
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return false
	Input.start_joy_vibration(int(pads[0]), weak, strong, seconds)
	return true

static func _web_rumble() -> bool:
	var raw = JavaScriptBridge.eval("""
		(function () {
			if (!navigator.getGamepads) return 0;
			var pads = navigator.getGamepads();
			for (var i = 0; i < pads.length; i++) {
				var p = pads[i];
				if (!p) continue;
				if (p.vibrationActuator) return 1;
				if (p.hapticActuators && p.hapticActuators.length) return 1;
			}
			return 0;
		})()
	""", true)
	return int(raw) == 1

static func load_user() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	stick_look = clampf(float(parsed.get("stick_look", 1.0)), 0.4, 2.2)
	var bindings = parsed.get("bindings", {})
	if typeof(bindings) != TYPE_DICTIONARY:
		return
	for action in bindings.keys():
		var name := str(action)
		if not InputMap.has_action(name) or name.begins_with("ui_"):
			continue
		InputMap.action_erase_events(name)
		for spec in bindings[name]:
			if typeof(spec) != TYPE_DICTIONARY:
				continue
			_add_spec(name, spec)
	scrub_conflicts()

static func save_user() -> void:
	var bindings := {}
	for action in InputMap.get_actions():
		var name := str(action)
		if name.begins_with("ui_"):
			continue
		var specs: Array = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				specs.append({"kind": "key", "code": event.physical_keycode})
			elif event is InputEventMouseButton:
				specs.append({"kind": "mouse", "button": event.button_index})
			elif event is InputEventJoypadButton:
				specs.append({"kind": "button", "button": event.button_index})
			elif event is InputEventJoypadMotion:
				specs.append({"kind": "axis", "axis": event.axis, "value": event.axis_value})
		bindings[name] = specs
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"stick_look": stick_look, "bindings": bindings}))

static func binding_label(action: String, kind: String) -> String:
	var parts: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		if kind == "key" and event is InputEventKey:
			parts.append(OS.get_keycode_string(event.physical_keycode))
		elif kind == "key" and event is InputEventMouseButton:
			parts.append("Mouse %d" % int(event.button_index))
		elif kind == "pad" and event is InputEventJoypadButton:
			parts.append(_button_name(event.button_index))
		elif kind == "pad" and event is InputEventJoypadMotion:
			parts.append(_axis_name(event.axis, event.axis_value))
	return ", ".join(parts) if parts.size() else "—"

static func rebind_key(action: String, code: int) -> String:
	if code == KEY_E and action != "interact":
		return "E stays interact"
	if code == KEY_ESCAPE and action != "pause":
		return "Esc stays pause"
	var owner := _key_owner(code)
	if owner != "" and owner != action:
		return "%s is %s" % [OS.get_keycode_string(code), owner]
	_erase_kind(action, "key")
	var event := InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = event.physical_keycode
	InputMap.action_add_event(action, event)
	scrub_conflicts()
	save_user()
	return ""

static func rebind_mouse(action: String, button: int) -> String:
	_erase_kind(action, "mouse")
	var event := InputEventMouseButton.new()
	event.button_index = button as MouseButton
	InputMap.action_add_event(action, event)
	save_user()
	return ""

static func rebind_button(action: String, button: int) -> String:
	_erase_kind(action, "button")
	var event := InputEventJoypadButton.new()
	event.button_index = button as JoyButton
	InputMap.action_add_event(action, event)
	save_user()
	return ""

static func rebind_axis(action: String, axis: int, value: float) -> String:
	_erase_kind(action, "axis")
	var event := InputEventJoypadMotion.new()
	event.axis = axis as JoyAxis
	event.axis_value = 1.0 if value >= 0.0 else -1.0
	InputMap.action_add_event(action, event)
	save_user()
	return ""

static func _key_owner(code: int) -> String:
	for action in InputMap.get_actions():
		if str(action).begins_with("ui_"):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == code:
				return str(action)
	return ""

static func _erase_kind(action: String, kind: String) -> void:
	for event in InputMap.action_get_events(action):
		var drop := false
		if kind == "key" and event is InputEventKey:
			drop = true
		elif kind == "mouse" and event is InputEventMouseButton:
			drop = true
		elif kind == "button" and event is InputEventJoypadButton:
			drop = true
		elif kind == "axis" and event is InputEventJoypadMotion:
			drop = true
		if drop:
			InputMap.action_erase_event(action, event)

static func _add_spec(action: String, spec: Dictionary) -> void:
	var kind := str(spec.get("kind", ""))
	if kind == "key":
		var event := InputEventKey.new()
		event.physical_keycode = int(spec.get("code", 0)) as Key
		event.keycode = event.physical_keycode
		InputMap.action_add_event(action, event)
	elif kind == "mouse":
		var event := InputEventMouseButton.new()
		event.button_index = int(spec.get("button", 1)) as MouseButton
		InputMap.action_add_event(action, event)
	elif kind == "button":
		var event := InputEventJoypadButton.new()
		event.button_index = int(spec.get("button", 0)) as JoyButton
		InputMap.action_add_event(action, event)
	elif kind == "axis":
		var event := InputEventJoypadMotion.new()
		event.axis = int(spec.get("axis", 0)) as JoyAxis
		event.axis_value = float(spec.get("value", 1.0))
		InputMap.action_add_event(action, event)

static func _button_name(button: int) -> String:
	match button:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_BACK: return "View"
		JOY_BUTTON_START: return "Menu"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_DPAD_UP: return "D-up"
		JOY_BUTTON_DPAD_DOWN: return "D-down"
		JOY_BUTTON_DPAD_LEFT: return "D-left"
		JOY_BUTTON_DPAD_RIGHT: return "D-right"
		_: return "btn %d" % button

static func _axis_name(axis: int, value: float) -> String:
	var side := "+" if value >= 0.0 else "-"
	match axis:
		JOY_AXIS_LEFT_X: return "LS X%s" % side
		JOY_AXIS_LEFT_Y: return "LS Y%s" % side
		JOY_AXIS_RIGHT_X: return "RS X%s" % side
		JOY_AXIS_RIGHT_Y: return "RS Y%s" % side
		JOY_AXIS_TRIGGER_LEFT: return "LT"
		JOY_AXIS_TRIGGER_RIGHT: return "RT"
		_: return "axis %d" % axis

static func _add(action: String, deadzone := 0.25) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)

static func _keys(action: String, keys: Array, deadzone := 0.25) -> void:
	_add(action, deadzone)
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

static func _axis(action: String, axis: JoyAxis, value: float, deadzone := 0.25) -> void:
	_add(action, deadzone)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)

static func _mouse(action: String, button: MouseButton) -> void:
	_add(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

static func _ensure_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
