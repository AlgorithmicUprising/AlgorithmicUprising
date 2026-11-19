extends CanvasLayer
## M1 (Nov 19 2026): story-mode HUD. Objective line, the Zero Score board (HUD version of the marquee), score and the
## combo meter, line progress, the voice/Fony text box, hesitation prompts and full-screen cards (the flyer).
## Built from one style: dark panels, warm text, Zero's lime for anything that comes from the arcade.

const LIME := Color("c8ff3a")
const COPPER := Color("f0a25a")
const PAPER := Color("fff6ea")
const DIM := Color(0.06, 0.05, 0.06, 0.82)

var title_label: Label
var objective_label: Label
var line_label: Label
var zero_panel: PanelContainer
var zero_label: Label
var best_label: Label
var score_label: Label
var mult_label: Label
var meter_back: ColorRect
var meter_fill: ColorRect
var talk_panel: PanelContainer
var speaker_label: Label
## Front end: the protagonist's on-screen tag (the chosen character name in capitals), coloured like FONY.
var protagonist_tag := "FONY"
var talk_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var card_panel: PanelContainer
var card_label: Label
var toast_label: Label
var toast_age := 99.0

func _ready() -> void:
	layer = 12
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# objective, top left under the zone / mode labels
	var obj := _panel(root, Vector2(16, 66), Vector2(430, 0))
	var col := VBoxContainer.new()
	obj.add_child(col)
	title_label = _label(col, 13, LIME)
	objective_label = _label(col, 20, PAPER)
	line_label = _label(col, 14, Color("d8d0c8"))
	# Zero Score board and score, top right, stacked in one column so they never overlap
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -266
	right.offset_right = -16
	right.offset_top = 12
	right.add_theme_constant_override("separation", 6)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
	zero_panel = _boxed(right, true)
	var zcol := VBoxContainer.new()
	zero_panel.add_child(zcol)
	zero_label = _label(zcol, 26, LIME, true)
	best_label = _label(zcol, 14, LIME)
	var score_panel := _boxed(right, true)
	var scol := VBoxContainer.new()
	score_panel.add_child(scol)
	score_label = _label(scol, 22, PAPER)
	meter_back = ColorRect.new()
	meter_back.custom_minimum_size = Vector2(222, 12)
	meter_back.color = Color(0.2, 0.18, 0.2, 1.0)
	scol.add_child(meter_back)
	meter_fill = ColorRect.new()
	meter_fill.color = LIME
	meter_fill.size = Vector2(0, 12)
	meter_back.add_child(meter_fill)
	mult_label = _label(scol, 15, Color("ffd59a"))
	# talk box, bottom left (non-blocking: he keeps skating)
	talk_panel = _panel(root, Vector2(16, -150), Vector2(600, 0), false, true)
	var tcol := VBoxContainer.new()
	talk_panel.add_child(tcol)
	speaker_label = _label(tcol, 15, LIME)
	talk_label = _label(tcol, 20, PAPER)
	talk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talk_label.custom_minimum_size = Vector2(570, 0)
	talk_panel.visible = false
	# hesitation prompt, bottom centre
	prompt_panel = PanelContainer.new()
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.offset_left = -300
	prompt_panel.offset_right = 300
	prompt_panel.offset_top = -230
	prompt_panel.offset_bottom = -182
	prompt_panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.07, 0.03, 0.9), LIME))
	root.add_child(prompt_panel)
	prompt_label = _label(prompt_panel, 20, LIME)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.visible = false
	# full-screen card (the Sunburn Open flyer)
	card_panel = PanelContainer.new()
	card_panel.set_anchors_preset(Control.PRESET_CENTER)
	card_panel.offset_left = -330
	card_panel.offset_right = 330
	card_panel.offset_top = -150
	card_panel.offset_bottom = 150
	card_panel.add_theme_stylebox_override("panel", _style(Color("f3e6c8"), Color("d9480f"), 5))
	root.add_child(card_panel)
	card_label = _label(card_panel, 22, Color("2a1a12"))
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_panel.visible = false
	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -400
	toast_label.offset_right = 400
	toast_label.offset_top = 262
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 24)
	toast_label.add_theme_color_override("font_color", Color("ffd59a"))
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 6)
	root.add_child(toast_label)

func _process(delta: float) -> void:
	toast_age += delta
	toast_label.modulate.a = clampf(1.6 - toast_age, 0.0, 1.0)

func set_objective(title: String, text: String) -> void:
	title_label.text = title
	objective_label.text = text

func set_line(text: String) -> void:
	line_label.text = text
	line_label.visible = text != ""

func set_zero(zero: int, best: int) -> void:
	zero_label.text = "ZERO SCORE\n" + (fmt(zero) if zero > 0 else "- - -")
	best_label.text = "BEST LINE  " + fmt(best)

func set_score(score: int, meter: float, mult: int, speed_mult: float) -> void:
	score_label.text = "SCORE  " + fmt(score)
	meter_fill.size = Vector2(222.0 * clampf(meter, 0.0, 1.0), 12)
	meter_fill.color = LIME if meter > 0.66 else (Color("ffd59a") if meter > 0.33 else Color("f0a25a"))
	mult_label.text = "COMBO x%d   SPEED +%d%%" % [mult, int(round((speed_mult - 1.0) * 100.0))]

func say(speaker: String, text: String) -> void:
	talk_panel.visible = true
	speaker_label.text = speaker
	var voice := speaker.begins_with("VOICE") or speaker == "MARQUEE"
	speaker_label.add_theme_color_override("font_color", LIME if voice else (COPPER if speaker == "FONY" or speaker == protagonist_tag else PAPER))
	talk_label.text = text

func hush() -> void:
	talk_panel.visible = false

func prompt(text: String) -> void:
	prompt_label.text = text
	prompt_panel.visible = text != ""

func card(text: String) -> void:
	card_label.text = text
	card_panel.visible = text != ""

func toast(text: String) -> void:
	toast_label.text = text
	toast_age = 0.0

static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

func _panel(root: Control, pos: Vector2, size: Vector2, right := false, bottom := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if right:
		p.anchor_left = 1.0
		p.anchor_right = 1.0
		p.offset_left = pos.x - size.x
		p.offset_right = pos.x
	else:
		p.offset_left = pos.x
		p.offset_right = pos.x + size.x
	if bottom:
		p.anchor_top = 1.0
		p.anchor_bottom = 1.0
		p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_top = pos.y
	p.offset_bottom = pos.y
	p.add_theme_stylebox_override("panel", _style(DIM, Color(0.78, 1.0, 0.23, 0.55) if right else Color("e0a15a")))
	root.add_child(p)
	return p

func _boxed(parent: Control, lime: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(DIM, Color(0.78, 1.0, 0.23, 0.55) if lime else Color("e0a15a")))
	parent.add_child(p)
	return p

func _style(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(width)
	st.set_content_margin_all(10)
	return st

func _label(parent: Node, size: int, color: Color, slanted := false) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 4)
	if slanted:
		# "Zero's handwriting" stand-in: the default font, slanted and a little heavy (no font file ships)
		var font := FontVariation.new()
		font.base_font = ThemeDB.fallback_font
		font.variation_embolden = 0.6
		font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.22, 1.0), Vector2.ZERO)
		l.add_theme_font_override("font", font)
	parent.add_child(l)
	return l
