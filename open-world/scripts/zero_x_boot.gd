extends Control
## Zero X Game Engine boot screen. First scene, shown before the Project Zero start screen.
##
## Zero X is the punk fork / rename of Godot Engine that Project Zero runs on. We did not
## build the engine core; Godot's contributors did. So the Godot MIT license sits right on
## the boot screen as fine print. The license text comes from the running engine binary
## (Engine.get_license_text()), so it always matches the engine version that ships.
##
## No consent, no prompts: the screen just stays up while next_scene loads in the
## background (ResourceLoader.load_threaded_request) and moves on by itself once it is
## loaded and at least MIN_SHOW seconds have passed. Nothing the player does gates it.
## Front end (Nov 19 2026): next_scene is the puppeteer start screen (scenes/start_screen.tscn).

signal finished(next_path: String)

const LICENSE_INTRO := "This game uses Godot Engine, available under the following license:"
const MIN_SHOW := 2.5
const WIDE_MIN := 860.0
const ZERO_ART := "res://web/zero_x_zero.webp"

const INK := Color("0d0d0b")
const PANEL := Color("171713")
const PAPER := Color("efeadb")
const FINE := Color("d9d4c3")
const DIM := Color("aaa592")
const LIME := Color("c6ff3d")
const HOT := Color("ff4f8b")

@export_file("*.tscn") var next_scene := "res://scenes/start_screen.tscn"
## Tests turn this off and listen for `finished` instead of changing scenes.
@export var auto_change := true

var elapsed := 0.0
var load_progress := 0.0
var loaded := false
var leaving := false
var ui_scale := 1.0
var wide := true
var requested := false

var ui: Control
var margin: MarginContainer
var heavy: FontVariation
var box: BoxContainer
var head: HBoxContainer
var logo: Label
var engine_word: Label
var built_on: Label
var zero_line: Label
var sticker: Label
var zero_side: TextureRect
var zero_stand: TextureRect
var fine_panel: PanelContainer
var fine_scroll: ScrollContainer
var fine_label: Label
var bar_fill: ColorRect
var status: Label
var crt: Control

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
	requested = ResourceLoader.load_threaded_request(next_scene, "PackedScene") == OK

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
	built_on.add_theme_font_size_override("font_size", 17 if wide else 14)
	zero_line.add_theme_font_size_override("font_size", 19 if wide else 15)
	fine_label.add_theme_font_size_override("font_size", 13 if wide else 12)
	box.add_theme_constant_override("separation", 26 if wide else 12)
	fine_panel.size_flags_stretch_ratio = 1.15 if wide else 1.0
	# Desktop: Zero stands under the title. Phone: a smaller Zero beside the title.
	zero_stand.visible = wide
	zero_side.visible = not wide
	zero_side.custom_minimum_size = Vector2(86 if phone else 110, 0)
	sticker.visible = not phone
	crt.queue_redraw()

func _build() -> void:
	heavy = FontVariation.new()
	heavy.base_font = ThemeDB.fallback_font
	heavy.variation_embolden = 0.9
	var zero_tex: Texture2D = _zero_texture()
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
	outer.add_child(box)

	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	box.add_child(left)
	head = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 10)
	left.add_child(head)
	var titles := VBoxContainer.new()
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 6)
	head.add_child(titles)
	var kicker := _label("PROJECT ZERO: THE ALGORITHMIC UPRISING", 13, DIM)
	kicker.name = "Kicker"
	kicker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(kicker)
	logo = _label("ZERO X", 92, LIME)
	logo.name = "Logo"
	logo.add_theme_font_override("font", heavy)
	logo.add_theme_constant_override("outline_size", 10)
	logo.add_theme_color_override("font_outline_color", Color("2b3d0a"))
	titles.add_child(logo)
	engine_word = _label("GAME ENGINE", 30, PAPER)
	engine_word.name = "EngineWord"
	engine_word.add_theme_font_override("font", heavy)
	titles.add_child(engine_word)
	var v := Engine.get_version_info()
	built_on = _label("built on Godot Engine %s.%s.%s-%s  ·  MIT license" % [v.major, v.minor, v.patch, v.status], 17, PAPER)
	built_on.name = "BuiltOn"
	built_on.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(built_on)
	zero_side = _zero(zero_tex)
	zero_side.name = "ZeroSide"
	zero_side.size_flags_vertical = Control.SIZE_FILL
	head.add_child(zero_side)
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
	zero_stand = _zero(zero_tex)
	zero_stand.name = "ZeroStand"
	zero_stand.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zero_stand.custom_minimum_size = Vector2(0, 120)
	zero_stand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	left.add_child(zero_stand)

	fine_panel = PanelContainer.new()
	fine_panel.name = "FinePrint"
	fine_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fine_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fine_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new()
	paper.bg_color = PANEL
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

	status = _label("LOADING HUMANS…", 15, LIME)
	status.name = "Status"
	status.add_theme_font_override("font", heavy)
	outer.add_child(status)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(bar)
	var bar_back := ColorRect.new()
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

## The exported game and an editor with a filled import cache take load().
## If that cache is missing, load() cannot see the WebP yet, so decode the source
## file. Image.load does not work in an export.
func _zero_texture() -> Texture2D:
	var sidecar := FileAccess.get_file_as_string(ZERO_ART + ".import")
	if sidecar.is_empty() or _imported_ctex_exists(sidecar):
		return load(ZERO_ART) as Texture2D
	var image := Image.new()
	if image.load(ZERO_ART) == OK and image.get_height() > 0:
		return ImageTexture.create_from_image(image)
	return load(ZERO_ART) as Texture2D

func _imported_ctex_exists(sidecar: String) -> bool:
	var key := "path=\""
	var at := sidecar.find(key)
	if at < 0:
		return false
	var start := at + key.length()
	var end := sidecar.find("\"", start)
	if end < 0:
		return false
	return FileAccess.file_exists(sidecar.substr(start, end - start))

func _zero(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return t

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
		+ "\n\nGodot also includes third-party code under its own licenses, listed in GODOT_COPYRIGHT.txt (Godot's official COPYRIGHT.txt), which ships with this game. More at godotengine.org/license."

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _process(delta: float) -> void:
	if leaving:
		return
	elapsed += delta
	if requested and not loaded:
		var progress := []
		var state := ResourceLoader.load_threaded_get_status(next_scene, progress)
		if progress.size():
			load_progress = float(progress[0])
		if state == ResourceLoader.THREAD_LOAD_LOADED:
			loaded = true
			load_progress = 1.0
		elif state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			requested = false
	if not requested:
		loaded = true
		load_progress = 1.0
	# The bar never runs ahead of the minimum show time, so it doesn't flash full.
	var shown := minf(load_progress, elapsed / MIN_SHOW)
	bar_fill.anchor_right = clampf(shown, 0.0, 1.0)
	bar_fill.offset_right = 0.0
	status.text = "LOADING HUMANS…  %d%%" % int(round(clampf(shown, 0.0, 1.0) * 100.0))
	if Engine.get_frames_drawn() % 6 == 0:
		crt.queue_redraw()
	if loaded and elapsed >= MIN_SHOW:
		advance()

## Fine print can be dragged on a phone (touch is not emulated as mouse in this project).
## Scrolling only; it never pauses or gates the hand-off.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and fine_panel.get_global_rect().has_point(event.position):
		fine_scroll.scroll_vertical -= int(event.relative.y / ui_scale)

func advance() -> void:
	if leaving:
		return
	leaving = true
	status.text = "LOADING HUMANS…  100%"
	bar_fill.anchor_right = 1.0
	bar_fill.color = HOT
	finished.emit(next_scene)
	if not auto_change:
		return
	var packed: PackedScene = null
	if requested:
		packed = ResourceLoader.load_threaded_get(next_scene) as PackedScene
	# Let the full bar paint before the yard builds and blocks the frame.
	await get_tree().process_frame
	await get_tree().process_frame
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
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
