extends Control
## Project Zero start screen (front end, Nov 19 2026). Order: Zero X boot (P.0, boot.tscn) -> this screen.
## The approved puppeteer art (option C, Nov 15 2026) with its title is the title card: strings sway, Egon's eyes
## pulse, PRESS START blinks. A press brings up the menu where PRESS START was:
##
##   NEW GAME         name your character (default "Fony", a placeholder) -> intro video -> P.1 Practice Run
##   LOAD GAME        this account's characters and their saves (greyed out when there are none)
##   UPRISING ARCADE  the Game Thing Pro console: the site's ZERO GAME THING 2000 and the Punk Arcade cartridges
##   CREDITS          Zero X Game Engine (Godot MIT), AU credits, third-party notices
##
## Keyboard (arrows, Enter, Esc), mouse and gamepad (d-pad / left stick, A, B) all drive Godot's focus navigation.
## Dev shortcuts skip this screen: ?play=free, ?story=p1, ?demo=..., ?district=... (web) or the same after `--`.

const Slots = preload("res://scripts/front/save_slots.gd")
const IntroPlayer = preload("res://scripts/front/intro_player.gd")
const Overlay = preload("res://scripts/arcade_overlay.gd")
const Interior = preload("res://scripts/arcade_interior.gd")
const SaveScript = preload("res://contracts/save_record.gd")

const LAYOUT := "res://data/start_screen.json"
const CREDITS := "res://data/credits.json"
const FONT := "res://assets/fonts/PressStart2P-Regular.ttf"
const ART_DIR := "res://assets/start_screen/"
const PARK := "res://scenes/main.tscn"
## The site's console (ZERO GAME THING 2000). It is where arcade sign-in and score saving live, so the menu opens it
## first; the cartridges below it open the same game pages the in-game arcade cabinets use.
const CONSOLE_URL := "https://algorithmicuprising.com/arcade/"
const BYPASS := ["play=free", "story=", "demo=", "district=", "district_demo="]
const ITEMS := ["new", "load", "arcade", "credits"]
const LABELS := {"new": "NEW GAME", "load": "LOAD GAME", "arcade": "UPRISING ARCADE", "credits": "CREDITS"}

const INK := Color("0d0d0b")
const LIME := Color("c6ff3d")
const PAPER := Color("efeadb")
const DIM := Color("8f8a78")
const HOT := Color("ff4f8b")
const PANEL := Color(0.05, 0.04, 0.08, 0.94)

## Tests turn this off and read `left_to` instead of changing scenes.
@export var auto_change := true

static var _pressed_once := false
static var _bypass_checked := false

## Tests: start from the PRESS START state and skip the dev-shortcut check.
static func reset_statics(pressed := false, bypass_checked := true) -> void:
	_pressed_once = pressed
	_bypass_checked = bypass_checked

var layout := {}
var art: Control
var layers := {}
var title_state := true          # PRESS START showing
var menu_row: HBoxContainer
var menu_buttons := {}
var account_button: Button
var hint_label: Label
var panel_layer: CanvasLayer
var panel: PanelContainer        # the open dialog, or null
var panel_kind := ""             # name / confirm / load / credits / arcade / intro / loading
var name_edit: LineEdit
var intro: Node
var overlay: Node
var font: Font
var t := 0.0
var left_to := ""                # scene path handed off to (tests)
var pending_name := ""
var loading := false
var gs: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	gs = get_node_or_null("/root/GameSession")
	font = load(FONT)
	var d = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT)) if FileAccess.file_exists(LAYOUT) else null
	layout = d if typeof(d) == TYPE_DICTIONARY else {}
	_build_art()
	_build_menu()
	panel_layer = CanvasLayer.new()
	panel_layer.layer = 20
	add_child(panel_layer)
	overlay = Overlay.new()
	overlay.name = "ArcadeOverlay"
	overlay.back_label = "BACK TO PROJECT ZERO"
	overlay.closed.connect(func(_id): _focus_panel())
	add_child(overlay)
	intro = IntroPlayer.new()
	intro.name = "Intro"
	intro.finished.connect(_on_intro_done)
	add_child(intro)
	if gs != null:
		gs.slots.migrate_legacy(gs.account_key())
		if gs.account != null:
			gs.account.changed.connect(func(_s): _refresh())
	get_viewport().size_changed.connect(_fit)
	_fit()
	if _dev_bypass():
		return
	if _pressed_once or (gs != null and gs.open_on_title != ""):
		_show_menu()
	_refresh()
	if gs != null and gs.open_on_title != "":
		var open: String = gs.open_on_title
		gs.open_on_title = ""
		if open == "load" and load_enabled():
			open_load()

func _dev_bypass() -> bool:
	if _bypass_checked:
		return false
	_bypass_checked = true
	var args := " ".join(OS.get_cmdline_user_args())
	if OS.has_feature("web"):
		args += " " + str(JavaScriptBridge.eval("window.location.search", true))
	for b in BYPASS:
		if b in args:
			_go(PARK)
			return true
	return false

# ------------------------------------------------------------------ art (the title card)

func _tex(layer: String) -> Texture2D:
	var l: Dictionary = layout.get("layers", {}).get(layer, {})
	return load(ART_DIR + str(l.get("file", layer + ".png"))) as Texture2D

func _build_art() -> void:
	var bg := ColorRect.new()
	bg.color = Color("07060d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	art = Control.new()
	art.name = "Art"
	art.size = Vector2(1920, 1080)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	for layer in ["plate", "strings_left", "strings_right", "eyes_glow", "title", "prompt"]:
		var r := TextureRect.new()
		r.name = layer
		r.texture = _tex(layer)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pos: Array = layout.get("layers", {}).get(layer, {}).get("pos", [0, 0])
		r.position = Vector2(float(pos[0]), float(pos[1]))
		if r.texture != null:
			r.size = r.texture.get_size()
		var piv: Array = layout.get("pivots", {}).get(layer, [])
		if piv.size() == 2:
			r.pivot_offset = Vector2(float(piv[0]), float(piv[1])) - r.position
		art.add_child(r)
		layers[layer] = r
	var scan := Control.new()
	scan.name = "Scanlines"
	scan.size = art.size
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scan.draw.connect(func():
		var y := 0.0
		while y < 1080.0:
			scan.draw_rect(Rect2(0, y, 1920, 2), Color(0, 0, 0, 0.22))
			y += 4.0
		scan.draw_rect(Rect2(0, fmod(t * 270.0, 1300.0) - 120.0, 1920, 64), Color(1, 1, 1, 0.035)))
	art.add_child(scan)
	layers["scan"] = scan

## Cover the window with the 16:9 art (cropped, never letterboxed), centred.
func _fit() -> void:
	var vs := get_viewport_rect().size
	var s := maxf(vs.x / 1920.0, vs.y / 1080.0)
	art.scale = Vector2(s, s)
	art.position = (vs - Vector2(1920, 1080) * s) * 0.5

func _process(delta: float) -> void:
	t += delta
	var sway := float(layout.get("sway_deg", 0.9))
	var period := float(layout.get("sway_s", 4.0))
	var ph := sin(t * TAU / period)
	if layers.has("strings_left"):
		layers.strings_left.rotation_degrees = sway * ph
		layers.strings_right.rotation_degrees = -sway * ph
	var pulse: Array = layout.get("eyes_pulse", [0.25, 1.0, 2.0])
	if layers.has("eyes_glow"):
		layers.eyes_glow.modulate.a = lerpf(float(pulse[0]), float(pulse[1]), 0.5 + 0.5 * sin(t * TAU / float(pulse[2])))
	if layers.has("prompt"):
		layers.prompt.visible = title_state and fmod(t, 1.0) < 0.5
	if Engine.get_process_frames() % 2 == 0:
		layers.scan.queue_redraw()
	_publish()

# ------------------------------------------------------------------ menu

func _style_button(b: Button, size_px: int) -> void:
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size_px)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", LIME)
	b.add_theme_color_override("font_focus_color", LIME)
	b.add_theme_color_override("font_pressed_color", HOT)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.43, 0.38))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	b.add_theme_constant_override("outline_size", maxi(4, size_px / 4))
	var empty := StyleBoxEmpty.new()
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0.55)
	focus.border_color = LIME
	focus.set_border_width_all(0)
	focus.border_width_bottom = 4
	focus.set_content_margin_all(10)
	empty.set_content_margin_all(10)
	for st in ["normal", "disabled", "pressed"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_stylebox_override("hover", focus)
	b.add_theme_stylebox_override("focus", focus)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())

func _build_menu() -> void:
	menu_row = HBoxContainer.new()
	menu_row.name = "Menu"
	menu_row.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_row.add_theme_constant_override("separation", 36)
	menu_row.position = Vector2(0, 896)
	menu_row.size = Vector2(1920, 72)
	menu_row.visible = false
	art.add_child(menu_row)
	for id in ITEMS:
		var b := Button.new()
		b.name = "Menu_" + id
		b.text = LABELS[id]
		_style_button(b, 30)
		b.pressed.connect(choose.bind(id))
		menu_row.add_child(b)
		menu_buttons[id] = b
	hint_label = Label.new()
	hint_label.add_theme_font_override("font", font)
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", DIM)
	hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_label.add_theme_constant_override("outline_size", 4)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(0, 984)
	hint_label.size = Vector2(1920, 24)
	hint_label.text = "ARROWS / D-PAD MOVE    ENTER / A SELECT    ESC / B BACK"
	hint_label.visible = false
	art.add_child(hint_label)
	account_button = Button.new()
	account_button.name = "Account"
	_style_button(account_button, 14)
	account_button.position = Vector2(30, 1018)
	account_button.pressed.connect(_on_account)
	account_button.visible = false
	art.add_child(account_button)

func _show_menu() -> void:
	title_state = false
	_pressed_once = true
	menu_row.visible = true
	hint_label.visible = true
	account_button.visible = true
	_refresh()
	var first: Button = menu_buttons["new"]
	first.grab_focus()

func _refresh() -> void:
	var has_saves: bool = gs != null and gs.slots.any(gs.account_key())
	if menu_buttons.has("load"):
		menu_buttons["load"].disabled = not has_saves
		menu_buttons["load"].focus_mode = Control.FOCUS_ALL if has_saves else Control.FOCUS_NONE
		menu_buttons["load"].tooltip_text = "" if has_saves else "No saves yet"
	if account_button != null and gs != null:
		var signed: bool = gs.account.state == "signed-in"
		account_button.text = "PLAYER: %s%s" % [gs.account.label(), "" if signed else "  (SAVES ON THIS DEVICE)  SIGN IN \u2197"]
	# neighbours: the row wraps left/right; down from any item goes to the account chip
	var ids: Array = []
	for id in ITEMS:
		if not menu_buttons[id].disabled:
			ids.append(id)
	for i in ids.size():
		var b: Button = menu_buttons[ids[i]]
		b.focus_neighbor_bottom = b.get_path_to(account_button)
		b.focus_neighbor_top = b.get_path()
		b.focus_neighbor_left = b.get_path_to(menu_buttons[ids[(i - 1 + ids.size()) % ids.size()]])
		b.focus_neighbor_right = b.get_path_to(menu_buttons[ids[(i + 1) % ids.size()]])
		b.focus_next = b.focus_neighbor_right
		b.focus_previous = b.focus_neighbor_left
	account_button.focus_neighbor_top = account_button.get_path_to(menu_buttons["new"])

func load_enabled() -> bool:
	return menu_buttons.has("load") and not menu_buttons["load"].disabled

## PRESS START is read in _input, before the GUI, so a click on the art (Controls that stop the mouse) counts too.
func _input(event: InputEvent) -> void:
	if not title_state or loading or panel_kind == "intro":
		return
	if overlay != null and overlay.is_open():
		return
	if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed() and not event.is_echo():
		_show_menu()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if loading or panel_kind == "intro" or title_state:
		return
	if overlay != null and overlay.is_open():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("session_cancel"):
		if panel != null:
			close_panel()
			get_viewport().set_input_as_handled()
		return
	# keep focus somewhere usable (a mouse click on the art drops it)
	if (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")) and get_viewport().gui_get_focus_owner() == null:
		_focus_panel()
		get_viewport().set_input_as_handled()

func choose(id: String) -> void:
	if loading or panel != null:
		return
	match id:
		"new":
			open_new()
		"load":
			if load_enabled():
				open_load()
		"arcade":
			open_arcade()
		"credits":
			open_credits()

func _on_account() -> void:
	if gs != null and gs.account.state != "signed-in":
		gs.account.open_sign_in()

# ------------------------------------------------------------------ dialogs

func _panel(kind: String, title: String, width := 860.0) -> VBoxContainer:
	close_panel()
	panel_kind = kind
	panel = PanelContainer.new()
	panel.name = "Panel_" + kind
	var st := StyleBoxFlat.new()
	st.bg_color = PANEL
	st.border_color = LIME
	st.set_border_width_all(3)
	st.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", st)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(width, 0)
	panel_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var h := _label(title, 22, LIME)
	box.add_child(h)
	menu_row.visible = false
	hint_label.visible = false
	account_button.visible = false
	_center_later()
	return box

func _center_later() -> void:
	await get_tree().process_frame
	_center_panel()
	await get_tree().process_frame
	_center_panel()

func _center_panel() -> void:
	if panel == null:
		return
	var vs := get_viewport_rect().size
	panel.size = Vector2(minf(panel.custom_minimum_size.x, vs.x - 40.0), minf(panel.get_combined_minimum_size().y, vs.y - 40.0))
	panel.position = (vs - panel.size) * 0.5

func _label(text: String, size_px := 14, color := PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(box: Container, text: String, cb: Callable, size_px := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_button(b, size_px)
	b.pressed.connect(cb)
	box.add_child(b)
	return b

func close_panel() -> void:
	if panel != null:
		panel.queue_free()
	panel = null
	var was := panel_kind
	panel_kind = ""
	name_edit = null
	if not title_state and not loading:
		menu_row.visible = true
		hint_label.visible = true
		account_button.visible = true
		_refresh()
		var back_to := {"name": "new", "confirm": "new", "load": "load", "arcade": "arcade", "credits": "credits"}
		var b: Button = menu_buttons.get(back_to.get(was, "new"), menu_buttons["new"])
		if b.disabled:
			b = menu_buttons["new"]
		b.grab_focus()

func _focus_panel() -> void:
	if panel == null:
		if not title_state:
			menu_buttons["new"].grab_focus()
		return
	for n in panel.find_children("*", "Control", true, false):
		if n is LineEdit or (n is Button and not n.disabled):
			n.grab_focus()
			return

## New Game: pick a character name (Fony is the placeholder default).
func open_new() -> void:
	var box := _panel("name", "NEW GAME")
	box.add_child(_label("WHO'S SKATING?", 16))
	name_edit = LineEdit.new()
	name_edit.name = "CharacterName"
	name_edit.text = Slots.DEFAULT_NAME
	name_edit.max_length = Slots.NAME_MAX
	name_edit.add_theme_font_override("font", font)
	name_edit.add_theme_font_size_override("font_size", 24)
	name_edit.add_theme_color_override("font_color", LIME)
	name_edit.select_all_on_focus = true
	name_edit.text_submitted.connect(func(_t): confirm_name())
	box.add_child(name_edit)
	box.add_child(_label("Fony is a placeholder name. Play under any name you like: your saves are kept under it.", 11, DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	_button(row, "START", confirm_name, 18).name = "Start"
	_button(row, "BACK", close_panel, 18).name = "Back"
	name_edit.grab_focus.call_deferred()
	name_edit.select_all.call_deferred()

func confirm_name() -> void:
	var raw := name_edit.text if name_edit != null else Slots.DEFAULT_NAME
	var n := Slots.clean_name(raw)
	if n == "":
		return
	pending_name = n
	if gs != null and gs.slots.exists(gs.account_key(), n):
		_open_confirm(n)
	else:
		start_new(n)

func _open_confirm(n: String) -> void:
	var box := _panel("confirm", "%s ALREADY HAS A SAVE" % n.to_upper())
	var entry := _entry_for(n)
	var line := ""
	if not entry.is_empty():
		var sm = entry.auto if entry.auto != null else entry.manual
		line = "%s   played %s   saved %s" % [_where(sm), _clock(float(sm.play_time_s)), _when(int(sm.saved_unix))]
	box.add_child(_label(line, 12, DIM))
	box.add_child(_label("Starting a new game as %s erases that save (autosave and manual save). Pick another name to keep it." % n, 13))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	var over := _button(row, "START OVER", func(): start_new(n), 16)
	over.name = "StartOver"
	var cancel := _button(row, "CANCEL", open_new, 16)
	cancel.name = "Cancel"
	cancel.grab_focus.call_deferred()

func _entry_for(n: String) -> Dictionary:
	if gs == null:
		return {}
	for e in gs.slots.list(gs.account_key()):
		if Slots.key_of(str(e.character)) == Slots.key_of(n) or str(e.key) == Slots.key_of(n):
			return e
	return {}

## New Game for `n`: erase that character's old saves, play the intro (loading the park behind it), then P.1.
func start_new(n: String) -> void:
	if gs != null:
		gs.slots.erase(gs.account_key(), n)
		gs.begin_new(n)
	close_panel()
	_begin_park_load()
	panel_kind = "intro"
	menu_row.visible = false
	hint_label.visible = false
	account_button.visible = false
	intro.play(gs.intro_seen() if gs != null else false)

func _on_intro_done(reason: String) -> void:
	if gs != null:
		gs.mark_intro(reason == "ended")
	panel_kind = "loading"
	_finish_park_load()

func open_load() -> void:
	var box := _panel("load", "LOAD GAME", 1000.0)
	var who: String = gs.account.label() if gs != null else "GUEST"
	box.add_child(_label("PLAYER: %s%s" % [who, "   saves on this device" if gs == null or gs.account.state != "signed-in" else ""], 11, DIM))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "Saves"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var entries: Array = gs.slots.list(gs.account_key()) if gs != null else []
	var first: Button = null
	for e in entries:
		for kind in ["auto", "manual"]:
			var sm = e[kind]
			if sm == null:
				continue
			var label := "%s   %s\n   %s   %s   %s" % [str(e.character).to_upper(), "AUTOSAVE" if kind == "auto" else "MANUAL SAVE", _where(sm), _clock(float(sm.play_time_s)), _when(int(sm.saved_unix))]
			var b := _button(list, label, load_game.bind(str(e.character), kind), 13)
			b.name = "Save_%s_%s" % [str(e.key), kind]
			if first == null:
				first = b
	if entries.is_empty():
		list.add_child(_label("No saves yet. Start a New Game.", 13, DIM))
	_button(box, "BACK", close_panel, 16).name = "Back"
	if first != null:
		first.grab_focus.call_deferred()
	else:
		_focus_panel.call_deferred()

func load_game(character: String, kind: String) -> void:
	if gs != null:
		gs.begin_load(character, kind)
	close_panel()
	panel_kind = "loading"
	_begin_park_load()
	_finish_park_load()

## Uprising Arcade: the Game Thing Pro console.
func open_arcade() -> void:
	var box := _panel("arcade", "UPRISING ARCADE \u00b7 ZERO GAME THING PRO", 980.0)
	box.add_child(_label("The full console has arcade sign-in, saved scores and leaderboards. The cartridges below play right here. Every game comes back to this screen.", 11, DIM))
	var full := _button(box, "\u25b6 ZERO GAME THING 2000 \u00b7 FULL CONSOLE  (algorithmicuprising.com/arcade)", open_cartridge.bind("zgt-2000", "ZERO GAME THING 2000", CONSOLE_URL), 13)
	full.name = "Cart_console"
	for id in Interior.GAMES:
		var g: Dictionary = Interior.GAMES[id]
		var title := str(g.title) if id != "punk-arcade" else "PUNK ARCADE LAB (all cartridges, one page)"
		var b := _button(box, "\u25b6 " + title.to_upper(), open_cartridge.bind(id, str(g.title), str(g.path)), 13)
		b.name = "Cart_" + id
	_button(box, "BACK", close_panel, 16).name = "Back"
	full.grab_focus.call_deferred()

func open_cartridge(id: String, title: String, path: String) -> void:
	overlay.open_game(id, title, path, null)

func open_credits() -> void:
	var box := _panel("credits", "CREDITS", 1000.0)
	var scroll := ScrollContainer.new()
	scroll.name = "CreditsScroll"
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_ALL
	box.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)
	var body := credits_text()
	for sec in body:
		col.add_child(_label(str(sec[0]), 14, LIME))
		var l := _label(str(sec[1]), 11)
		l.name = "Credit_" + str(sec[0]).replace(" ", "_").replace(":", "")
		col.add_child(l)
	var back := _button(box, "BACK", close_panel, 16)
	back.name = "Back"
	back.grab_focus.call_deferred()

## [[title, body], ...] from data/credits.json, with the running engine's version and full MIT license text.
func credits_text() -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string(CREDITS)) if FileAccess.file_exists(CREDITS) else null
	var out: Array = []
	if typeof(d) != TYPE_DICTIONARY:
		return out
	var v := Engine.get_version_info()
	var ver := "Godot Engine %s.%s.%s-%s" % [v.major, v.minor, v.patch, v.status]
	for sec in d.get("sections", []):
		var lines: Array = []
		for l in sec.get("lines", []):
			lines.append(str(l).replace("{godot_version}", ver))
		if str(sec.get("license", "")) == "godot":
			lines.append("")
			lines.append("This game uses Godot Engine, available under the following license:")
			lines.append("")
			lines.append(Engine.get_license_text())
		out.append([str(sec.get("title", "")), "\n".join(lines)])
	return out

# ------------------------------------------------------------------ hand-off to the park

func _begin_park_load() -> void:
	loading = true
	if auto_change and ResourceLoader.load_threaded_get_status(PARK) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(PARK)

func _finish_park_load() -> void:
	var box := _panel("loading", "LOADING HUMANS\u2026", 520.0)
	box.add_child(_label("Glitchport. Dawn. Heat dome day 9.", 12, DIM))
	_go(PARK)

func _go(path: String) -> void:
	left_to = path
	if not auto_change:
		return
	await get_tree().process_frame
	var packed: PackedScene = null
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
	await get_tree().process_frame
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(path)

# ------------------------------------------------------------------ helpers

static func _clock(s: float) -> String:
	var n := int(s)
	return "%d:%02d:%02d" % [n / 3600, (n / 60) % 60, n % 60]

static func _when(unix: int) -> String:
	if unix <= 0:
		return "--"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + bias)
	var months := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	var h := int(d.hour) % 12
	return "%s %d  %d:%02d %s" % [months[int(d.month) - 1], int(d.day), 12 if h == 0 else h, int(d.minute), "PM" if int(d.hour) >= 12 else "AM"]

static func _where(sm) -> String:
	if sm == null:
		return ""
	var w := str(sm.get("where", ""))
	if w.begins_with("p1_practice_run"):
		var obj := w.trim_prefix("p1_practice_run").trim_prefix(" / ")
		return "P.1 PRACTICE RUN" + ((" \u00b7 " + obj.to_upper().replace("_", " ")) if obj != "" else "")
	return w.to_upper() if w != "" else "FREE SKATE"

func _publish() -> void:
	if not OS.has_feature("web") or Engine.get_process_frames() % 10 != 0:
		return
	var focus := get_viewport().gui_get_focus_owner()
	var st := {"title": title_state, "panel": panel_kind, "focus": str(focus.name) if focus != null else "", "load_enabled": load_enabled(),
		"loading": loading, "intro": intro.state if intro != null else "", "account": gs.account.state if gs != null else "", "arcade": overlay.is_open() if overlay != null else false}
	JavaScriptBridge.eval("window.AU_TITLE=%s;" % JSON.stringify(st), true)
