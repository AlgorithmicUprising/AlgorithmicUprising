extends Control
## Zero X Game Engine boot screen. First scene, shown before the Project Zero start screen.
##
## Zero X is the punk fork / rename of Godot Engine that Project Zero runs on. We did not
## build the engine core; Godot's contributors did. So the Godot MIT license sits right on
## the boot screen as fine print. The license text comes from the running engine binary
## (Engine.get_license_text()), so it always matches the engine version that ships.
## Godot's third-party notices (Engine.get_copyright_info() + get_license_info()) open in
## a full-screen scroll from the THIRD-PARTY NOTICES key.
##
## Any key, click or tap skips after MIN_SHOW. It auto-advances after AUTO_ADVANCE unless
## the player holds the fine print or opens the notices. Hands off to next_scene; when the
## in-game start screen (option C, the puppeteer) lands, point next_scene at it.

signal finished(next_path: String)

const ENGINE_NAME := "ZERO X GAME ENGINE"
const LICENSE_INTRO := "This game uses Godot Engine, available under the following license:"
const MIN_SHOW := 1.0
const AUTO_ADVANCE := 8.0
const WIDE_MIN := 860.0

const INK := Color("0d0d0b")
const PANEL := Color("171713")
const PAPER := Color("efeadb")
const FINE := Color("d9d4c3")
const DIM := Color("aaa592")
const LIME := Color("c6ff3d")
const HOT := Color("ff4f8b")

@export_file("*.tscn") var next_scene := "res://scenes/main.tscn"
## Tests turn this off and listen for `finished` instead of changing scenes.
@export var auto_change := true

var elapsed := 0.0
var held := false
var leaving := false
var ui_scale := 1.0
var wide := true

var ui: Control
var box: BoxContainer
var logo: Label
var engine_word: Label
var built_on: Label
var zero_line: Label
var sticker: Label
var fine_panel: PanelContainer
var fine_scroll: ScrollContainer
var fine_label: Label
var notices_key: PanelContainer
var continue_key: PanelContainer
var bar_back: ColorRect
var bar_fill: ColorRect
var hint: Label
var notices: PanelContainer
var notices_scroll: ScrollContainer
var notices_list: VBoxContainer
var notices_close: PanelContainer
var crt: Control
var margin: MarginContainer
var heavy: FontVariation

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = INK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	ui = Control.new()
	ui.name = "UI"
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	_build()
	crt = Control.new()
	crt.name = "Grain"
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.draw.connect(_draw_crt)
	add_child(crt)
	get_viewport().size_changed.connect(_layout)
	_layout()
	print(LICENSE_INTRO, "\n\n", Engine.get_license_text())

## The visible rect is 1280 wide whatever the window, so a phone shrinks it to ~0.3x.
## Scale the boot UI back up so one UI unit is at least one CSS pixel and the fine print
## stays readable, then lay out in that space.
func _compute_scale() -> float:
	var vis := get_viewport_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or vis.x <= 0.0:
		return 1.0
	var dpr := 1.0
	if OS.has_feature("web"):
		dpr = maxf(DisplayServer.screen_get_scale(), 1.0)
	return maxf(1.0, vis.x / (win.x / dpr))

func _layout() -> void:
	ui_scale = _compute_scale()
	var vis := get_viewport_rect().size
	ui.scale = Vector2(ui_scale, ui_scale)
	ui.position = Vector2.ZERO
	ui.size = vis / ui_scale
	wide = ui.size.x >= WIDE_MIN and ui.size.x > ui.size.y
	box.vertical = not wide
	var phone := ui.size.x < 520.0
	logo.add_theme_font_size_override("font_size", 92 if wide else (52 if phone else 72))
	engine_word.add_theme_font_size_override("font_size", 30 if wide else 21)
	box.add_theme_constant_override("separation", 26 if wide else 14)
	built_on.add_theme_font_size_override("font_size", 17 if wide else 15)
	zero_line.add_theme_font_size_override("font_size", 19 if wide else 16)
	fine_label.add_theme_font_size_override("font_size", 13 if wide else 12)
	fine_panel.size_flags_stretch_ratio = 1.15 if wide else 1.0
	sticker.visible = not phone
	crt.queue_redraw()

func _build() -> void:
	heavy = FontVariation.new()
	heavy.base_font = ThemeDB.fallback_font
	heavy.variation_embolden = 0.9
	margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	ui.add_child(margin)
	var outer := VBoxContainer.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	box = BoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 26)
	outer.add_child(box)

	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	box.add_child(left)
	var kicker := _label("PROJECT ZERO: THE ALGORITHMIC UPRISING", 13, DIM)
	kicker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kicker.name = "Kicker"
	left.add_child(kicker)
	logo = _label("ZERO X", 92, LIME)
	logo.add_theme_font_override("font", heavy)
	logo.name = "Logo"
	logo.add_theme_constant_override("outline_size", 10)
	logo.add_theme_color_override("font_outline_color", Color("2b3d0a"))
	left.add_child(logo)
	engine_word = _label("GAME ENGINE", 30, PAPER)
	engine_word.add_theme_font_override("font", heavy)
	engine_word.name = "EngineWord"
	left.add_child(engine_word)
	var v := Engine.get_version_info()
	built_on = _label("built on Godot Engine %s.%s.%s-%s  ·  MIT license" % [v.major, v.minor, v.patch, v.status], 17, PAPER)
	built_on.name = "BuiltOn"
	left.add_child(built_on)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(gap)
	zero_line = _label("ZERO: \"Always read the fine print. Here's ours, in full. We renamed the engine. Godot's contributors built it.\"", 19, PAPER)
	zero_line.name = "ZeroLine"
	zero_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(zero_line)
	sticker = _label(" MIT · FORK IT · CREDIT IT ", 14, INK)
	sticker.name = "Sticker"
	var tape := StyleBoxFlat.new()
	tape.bg_color = LIME
	tape.content_margin_left = 6
	tape.content_margin_right = 6
	tape.content_margin_top = 2
	tape.content_margin_bottom = 2
	sticker.add_theme_stylebox_override("normal", tape)
	sticker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sticker.rotation = deg_to_rad(-2.5)
	left.add_child(sticker)

	fine_panel = PanelContainer.new()
	fine_panel.name = "FinePrint"
	fine_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fine_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fine_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new()
	paper.bg_color = PANEL
	paper.border_color = Color("3a3a31")
	paper.set_border_width_all(1)
	paper.border_width_left = 3
	paper.border_color = LIME.darkened(0.35)
	paper.set_content_margin_all(14)
	fine_panel.add_theme_stylebox_override("panel", paper)
	box.add_child(fine_panel)
	fine_scroll = ScrollContainer.new()
	fine_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fine_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	fine_panel.add_child(fine_scroll)
	fine_label = _label(fine_print_text(), 13, FINE)
	fine_label.name = "License"
	fine_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fine_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fine_label.add_theme_constant_override("line_spacing", 2)
	fine_scroll.add_child(fine_label)

	var keys := HFlowContainer.new()
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.add_theme_constant_override("h_separation", 10)
	keys.add_theme_constant_override("v_separation", 8)
	outer.add_child(keys)
	continue_key = _key("CONTINUE  >>")
	continue_key.name = "Continue"
	keys.add_child(continue_key)
	notices_key = _key("THIRD-PARTY NOTICES  [N]")
	notices_key.name = "NoticesKey"
	keys.add_child(notices_key)
	hint = _label("BOOTING…", 13, DIM)
	hint.name = "Hint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.custom_minimum_size = Vector2(220, 0)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.add_child(hint)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(bar)
	bar_back = ColorRect.new()
	bar_back.color = Color("2a2a22")
	bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bar_back)
	bar_fill = ColorRect.new()
	bar_fill.color = LIME
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_fill.anchor_bottom = 1.0
	bar_fill.anchor_right = 0.0
	bar.add_child(bar_fill)

## The Godot MIT license exactly as the engine reports it, with the intro line from the
## Godot docs ("Complying with licenses"). Hard line wraps inside a paragraph are joined
## so it reflows on a phone; the two copyright lines stay on their own lines.
static func fine_print_text() -> String:
	var paragraphs := PackedStringArray()
	for para in Engine.get_license_text().strip_edges().split("\n\n"):
		var lines := para.strip_edges().split("\n")
		if lines.size() > 0 and lines[0].begins_with("Copyright"):
			paragraphs.append("\n".join(lines))
		else:
			paragraphs.append(" ".join(lines))
	return "THE FINE PRINT\n\n" + LICENSE_INTRO + "\n\n" + "\n\n".join(paragraphs) \
		+ "\n\nGodot also includes third-party code under its own licenses. Press N, or tap THIRD-PARTY NOTICES, to read every one."

## Join hard-wrapped lines inside a paragraph so license texts read on a phone. Words and
## order stay exactly the same; lines that look like list items or indented code keep their break.
static func reflow(text: String) -> String:
	var out := PackedStringArray()
	var numbered := RegEx.create_from_string("^\\d+[.)] ")
	for line in text.split("\n"):
		var t := line.strip_edges(false, true)
		var starts_block := t == "" or line.begins_with(" ") or line.begins_with("\t") \
			or t.begins_with("-") or t.begins_with("*") or t.begins_with("•") or t.begins_with("(") \
			or t.begins_with("Copyright") or t.begins_with("Files:") or t.begins_with("License:") \
			or numbered.search(t) != null
		if out.size() and not starts_block and out[out.size() - 1] != "":
			out[out.size() - 1] = out[out.size() - 1] + " " + t
		else:
			out.append(t)
	return "\n".join(out)

## Godot's third-party copyright and license notices, straight from the engine binary.
static func notices_sections() -> Array:
	var out: Array = []
	var v := Engine.get_version_info()
	out.append(["Godot Engine %s" % v.string, LICENSE_INTRO + "\n\n" + Engine.get_license_text().strip_edges()])
	for info in Engine.get_copyright_info():
		var lines := PackedStringArray()
		for part in info.get("parts", []):
			var files: PackedStringArray = part.get("files", PackedStringArray())
			if files.size():
				lines.append("Files: " + ", ".join(files))
			for c in part.get("copyright", PackedStringArray()):
				lines.append("Copyright: " + str(c))
			lines.append("License: " + str(part.get("license", "")))
			lines.append("")
		out.append([str(info.get("name", "")), "\n".join(lines).strip_edges()])
	var licenses: Dictionary = Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for name in names:
		out.append(["License: " + str(name), str(licenses[name]).strip_edges()])
	return out

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _key(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1d2410")
	sb.border_color = LIME
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_label(text, 15, LIME))
	return p

func _process(delta: float) -> void:
	if leaving:
		return
	if notices == null or not notices.visible:
		if not held:
			elapsed += delta
	var ready_to_skip := elapsed >= MIN_SHOW or held or (notices != null and notices.visible)
	if held:
		hint.text = "HELD. READ AT YOUR OWN PACE. ANY KEY, CLICK OR TAP TO CONTINUE."
	elif ready_to_skip:
		hint.text = "ANY KEY, CLICK OR TAP TO SKIP. TAP THE FINE PRINT TO HOLD IT."
	var t := 1.0 if held else clampf(elapsed / AUTO_ADVANCE, 0.0, 1.0)
	bar_fill.anchor_right = t
	bar_fill.offset_right = 0.0
	bar_fill.color = DIM if held else LIME
	if Engine.get_frames_drawn() % 6 == 0:
		crt.queue_redraw()
	if not held and elapsed >= AUTO_ADVANCE:
		advance()

func can_skip() -> bool:
	return elapsed >= MIN_SHOW or held

func _hit(c: Control, pos: Vector2) -> bool:
	return c != null and c.is_visible_in_tree() and c.get_global_rect().has_point(pos)

func _input(event: InputEvent) -> void:
	if leaving:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		return
	if notices != null and notices.visible:
		_notices_input(event)
		return
	if event is InputEventScreenDrag:
		if _hit(fine_panel, event.position):
			fine_scroll.scroll_vertical -= int(event.relative.y / ui_scale)
			held = true
			get_viewport().set_input_as_handled()
		return
	var pos = null
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pos = event.position
	elif event is InputEventScreenTouch and not event.pressed:
		pos = event.position
	if pos != null:
		get_viewport().set_input_as_handled()
		if _hit(notices_key, pos):
			open_notices()
		elif _hit(continue_key, pos):
			advance()
		elif _hit(fine_panel, pos):
			if held and can_skip():
				advance()
			else:
				held = true
		elif can_skip():
			advance()
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_N:
			open_notices()
		elif event.keycode in [KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN]:
			held = true
			_scroll_by(fine_scroll, event.keycode)
		elif can_skip():
			advance()
	elif event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		if event.button_index == JOY_BUTTON_Y:
			open_notices()
		elif can_skip():
			advance()

func _scroll_by(scroll: ScrollContainer, keycode: int) -> void:
	var page := int(scroll.size.y * 0.85)
	match keycode:
		KEY_UP: scroll.scroll_vertical -= 40
		KEY_DOWN: scroll.scroll_vertical += 40
		KEY_PAGEUP: scroll.scroll_vertical -= page
		KEY_PAGEDOWN: scroll.scroll_vertical += page

func _notices_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		notices_scroll.scroll_vertical -= int(event.relative.y / ui_scale)
		get_viewport().set_input_as_handled()
		return
	var pos = null
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pos = event.position
	elif event is InputEventScreenTouch and not event.pressed:
		pos = event.position
	if pos != null:
		get_viewport().set_input_as_handled()
		if _hit(notices_close, pos):
			close_notices()
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		if event.keycode in [KEY_ESCAPE, KEY_N, KEY_BACKSPACE]:
			close_notices()
		elif event.keycode in [KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN]:
			_scroll_by(notices_scroll, event.keycode)
		elif event.keycode in [KEY_HOME]:
			notices_scroll.scroll_vertical = 0
	elif event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		if event.button_index in [JOY_BUTTON_B, JOY_BUTTON_Y, JOY_BUTTON_BACK]:
			close_notices()
		elif event.button_index == JOY_BUTTON_DPAD_DOWN:
			notices_scroll.scroll_vertical += 120
		elif event.button_index == JOY_BUTTON_DPAD_UP:
			notices_scroll.scroll_vertical -= 120

func open_notices() -> void:
	if notices == null:
		_build_notices()
	notices.visible = true
	margin.visible = false
	notices_scroll.scroll_vertical = 0

func close_notices() -> void:
	if notices != null:
		notices.visible = false
	margin.visible = true
	held = true

func _build_notices() -> void:
	notices = PanelContainer.new()
	notices.name = "Notices"
	notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notices.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = INK
	sb.set_content_margin_all(22)
	notices.add_theme_stylebox_override("panel", sb)
	ui.add_child(notices)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	notices.add_child(col)
	var head := HFlowContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("h_separation", 14)
	col.add_child(head)
	notices_close = _key("X  BACK  [Esc]")
	head.add_child(notices_close)
	var title := _label("THIRD-PARTY NOTICES. Zero X Game Engine is built on Godot Engine, which includes code from these projects under their own licenses.", 14, PAPER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size = Vector2(240, 0)
	head.add_child(title)
	notices_scroll = ScrollContainer.new()
	notices_scroll.name = "NoticesScroll"
	notices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	notices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notices_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(notices_scroll)
	notices_list = VBoxContainer.new()
	notices_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notices_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notices_list.add_theme_constant_override("separation", 6)
	notices_scroll.add_child(notices_list)
	for section in notices_sections():
		var name_label := _label(section[0], 14, LIME)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notices_list.add_child(name_label)
		var body := _label(reflow(section[1]), 12, FINE)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		notices_list.add_child(body)

func advance() -> void:
	if leaving:
		return
	leaving = true
	hint.text = "LOADING HUMANS…"
	bar_fill.anchor_right = 1.0
	bar_fill.color = HOT
	finished.emit(next_scene)
	if not auto_change:
		return
	# Let "LOADING HUMANS…" paint before the yard builds and blocks the frame.
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(next_scene)

## Scanlines and a little grain. Light enough that the fine print keeps its contrast.
func _draw_crt() -> void:
	var size_px := crt.size
	var step := maxf(3.0, 3.0 * ui_scale)
	var y := 0.0
	var line := Color(0, 0, 0, 0.16)
	while y < size_px.y:
		crt.draw_line(Vector2(0, y), Vector2(size_px.x, y), line, 1.0)
		y += step
	var rng := RandomNumberGenerator.new()
	rng.seed = Engine.get_frames_drawn() / 6
	for _i in 90:
		var p := Vector2(rng.randf() * size_px.x, rng.randf() * size_px.y)
		var a := rng.randf_range(0.03, 0.08)
		crt.draw_rect(Rect2(p, Vector2(2, 2) * ui_scale), Color(1, 1, 1, a))
