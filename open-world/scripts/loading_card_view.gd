extends CanvasLayer
## District loading card (M0). A lower-left card that never takes input and never pauses the tree, so Fony keeps
## skating while a district streams in. Shows the card's art, title, body and optional portrait, plus a thin progress
## bar and a status line. Placeholder-safe: missing art just hides that slot.

var panel: PanelContainer
var art: TextureRect
var portrait: TextureRect
var portrait_name: Label
var title: Label
var body: Label
var bar: ProgressBar
var status: Label
var card: Dictionary = {}

func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.name = "CardRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	panel.name = "Card"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_bottom = -16
	panel.offset_top = -16
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(360, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.05, 0.07, 0.88)
	box.border_color = Color("e2ff5c")
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", box)
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	art = TextureRect.new()
	art.name = "Art"
	art.custom_minimum_size = Vector2(340, 150)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(art)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var who := VBoxContainer.new()
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(who)
	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_child(portrait)
	portrait_name = Label.new()
	portrait_name.name = "PortraitName"
	portrait_name.add_theme_font_size_override("font_size", 11)
	portrait_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_child(portrait_name)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	title = Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("e2ff5c"))
	text.add_child(title)
	body = Label.new()
	body.name = "Body"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(250, 0)
	body.add_theme_font_size_override("font_size", 14)
	text.add_child(body)
	bar = ProgressBar.new()
	bar.name = "Progress"
	bar.custom_minimum_size = Vector2(0, 6)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	status = Label.new()
	status.name = "Status"
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color("d7f3f8"))
	col.add_child(status)
	visible = false

func show_card(data: Dictionary) -> void:
	card = data
	title.text = str(data.get("title", ""))
	body.text = str(data.get("body", ""))
	body.visible = body.text != ""
	art.texture = _tex(str(data.get("art", "")))
	art.visible = art.texture != null
	portrait.texture = _tex(str(data.get("portrait", "")))
	portrait.visible = portrait.texture != null
	portrait_name.text = str(data.get("portrait_name", ""))
	portrait_name.visible = portrait.visible and portrait_name.text != ""
	if str(data.get("accent", "")) != "":
		title.add_theme_color_override("font_color", Color(str(data["accent"])))
	set_progress(-1.0, "")
	visible = true

## fraction < 0 = unknown size (bar shows a slow sweep).
func set_progress(fraction: float, text: String) -> void:
	if fraction < 0.0:
		bar.value = fmod(Time.get_ticks_msec() / 1200.0, 1.0)
	else:
		bar.value = clampf(fraction, 0.0, 1.0)
	status.text = text

func hide_card() -> void:
	visible = false

func _tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res = load(path)
	return res if res is Texture2D else null
