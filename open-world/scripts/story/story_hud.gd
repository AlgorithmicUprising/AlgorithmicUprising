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
var score_box: Control               # the skate-combo SCORE box (hidden in the Act I scenes, which score in the box above)
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
# P.1 v2 (Nov 19 2026): Fony's phone. A compact thread docked top right (P.1 v2 "Phone UI spec").
const PHONE_DARK := Color("0f0d10")
const SERA_BLUE := Color("9fd8ff")
const MAX_BUBBLES := 3
const COLLAPSE_S := 8.0
var phone_panel: PanelContainer
var phone_name: Label
var phone_sub: Label
var phone_status: Label
var phone_avatar: Label
var phone_thread: VBoxContainer
var phone_typing: Label
var phone_compose: Label
var phone_chip: PanelContainer
var phone_chip_label: Label
var phone_log: Array = []           # tests / probes: {"from", "text", "out"} in order
var phone_idle := 0.0
var typing_left := 0.0
var draft_text := ""
var draft_parts := PackedStringArray()
var draft_t := 0.0
var alert_panel: Control
var alert_label: Label
var letterbox_top: ColorRect
var letterbox_bottom: ColorRect
var skip_label: Label
var phone_sender := "???"
var fade_rect: ColorRect
var fade_target := 0.0
var fade_speed := 2.0
var objective_panel: Control         # the objective box, top left (hidden over cutscenes and the end card)
var right_column: VBoxContainer      # the Zero Score + score stack; the phone docks under it
const PHONE_GAP := 10.0

func _ready() -> void:
	layer = 12
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# objective, top left under the zone / mode labels
	var obj := _panel(root, Vector2(16, 66), Vector2(430, 0))
	objective_panel = obj
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
	right_column = right
	zero_panel = _boxed(right, true)
	var zcol := VBoxContainer.new()
	zero_panel.add_child(zcol)
	zero_label = _label(zcol, 26, LIME, true)
	best_label = _label(zcol, 14, LIME)
	var score_panel := _boxed(right, true)
	score_box = score_panel
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
	_build_phone(root)
	# cinematic letterbox and hold-to-skip hint (CINEMATIC P.2 / P.3)
	letterbox_top = ColorRect.new()
	letterbox_top.color = Color.BLACK
	letterbox_top.anchor_right = 1.0
	letterbox_top.offset_bottom = 64
	letterbox_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letterbox_top.visible = false
	root.add_child(letterbox_top)
	letterbox_bottom = ColorRect.new()
	letterbox_bottom.color = Color.BLACK
	letterbox_bottom.anchor_top = 1.0
	letterbox_bottom.anchor_right = 1.0
	letterbox_bottom.anchor_bottom = 1.0
	letterbox_bottom.offset_top = -64
	letterbox_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letterbox_bottom.visible = false
	root.add_child(letterbox_bottom)
	skip_label = Label.new()
	skip_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_label.offset_left = -330
	skip_label.offset_top = -48
	skip_label.offset_right = -18
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.add_theme_font_size_override("font_size", 14)
	skip_label.add_theme_color_override("font_color", Color("efeadb"))
	skip_label.visible = false
	root.add_child(skip_label)
	_build_alert(root)
	# full-screen fade (P.2 Run: caught by the net, the culvert)
	fade_rect = ColorRect.new()
	fade_rect.name = "Fade"
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)
	root.move_child(fade_rect, card_panel.get_index())

func _process(delta: float) -> void:
	toast_age += delta
	toast_label.modulate.a = clampf(1.6 - toast_age, 0.0, 1.0)
	_phone_tick(delta)
	dock_phone()
	if fade_rect != null and fade_rect.color.a != fade_target:
		fade_rect.color.a = move_toward(fade_rect.color.a, fade_target, delta * fade_speed)

## Fades the screen to black (1.0) or back (0.0) over secs. snap() for tests.
func fade_to(alpha: float, secs := 0.6) -> void:
	fade_target = clampf(alpha, 0.0, 1.0)
	fade_speed = 1.0 / maxf(0.01, secs)

func fade_alpha() -> float:
	return fade_rect.color.a if fade_rect != null else 0.0

## Keeps the phone (and its chip) docked under the score stack, whatever height that stack has at this resolution
## (it grows with the Zero Score line, the best line and the combo row). Never overlaps it.
func dock_phone() -> void:
	if right_column == null or phone_panel == null:
		return
	# under the letterbox while it is up (it would clip the top of the stack otherwise)
	var bar := letterbox_top.offset_bottom if letterbox_top != null and letterbox_top.visible else 0.0
	right_column.offset_top = 12.0 + bar
	var top := right_column.offset_top + right_column.get_combined_minimum_size().y + PHONE_GAP
	if right_column.visible:
		top = maxf(top, right_column.position.y + right_column.size.y + PHONE_GAP)
	else:
		top = 12.0 + bar
	for c in [phone_panel, phone_chip]:
		c.offset_top = top
		c.offset_bottom = top

## Tests: the phone does not overlap the score stack, the talk box or the prompt.
func layout_ok() -> bool:
	dock_phone()
	var ph := phone_panel.get_global_rect()
	if ph.intersects(right_column.get_global_rect()):
		return false
	if talk_panel.visible and ph.intersects(talk_panel.get_global_rect()):
		return false
	return true

func set_objective(title: String, text: String) -> void:
	title_label.text = title
	objective_label.text = text

func set_line(text: String) -> void:
	line_label.text = text
	line_label.visible = text != ""

func set_zero(zero: int, best: int) -> void:
	zero_label.text = "ZERO SCORE\n" + (fmt(zero) if zero > 0 else "- - -")
	best_label.text = "BEST LINE  " + fmt(best)

## Act I scenes 1.1+: the combo SCORE box only shows while there is a skate combo to show.
func show_combo(on: bool) -> void:
	if score_box != null and score_box.visible != on:
		score_box.visible = on
		call_deferred("dock_phone")

func set_score(score: int, meter: float, mult: int, speed_mult: float) -> void:
	score_label.text = "SCORE  " + fmt(score)
	meter_fill.size = Vector2(222.0 * clampf(meter, 0.0, 1.0), 12)
	meter_fill.color = LIME if meter > 0.66 else (Color("ffd59a") if meter > 0.33 else Color("f0a25a"))
	mult_label.text = "COMBO x%d   SPEED +%d%%" % [mult, int(round((speed_mult - 1.0) * 100.0))]

func say(speaker: String, text: String) -> void:
	talk_panel.visible = true
	speaker_label.text = speaker
	var voice := speaker.begins_with("VOICE") or speaker.begins_with("CRT") or speaker == "MARQUEE"
	var sera := speaker.begins_with("SERA") or speaker.begins_with("WELFARE") or speaker.begins_with("BILLBOARD")
	speaker_label.add_theme_color_override("font_color", LIME if voice else (SERA_BLUE if sera else (Color("b8b8b0") if speaker.begins_with("ENFORCEMENT") else (COPPER if speaker == "FONY" or speaker == protagonist_tag else PAPER))))
	talk_label.text = text
	# narration (stage directions) reads dimmer and in italics-style parentheses
	talk_label.add_theme_color_override("font_color", Color("cfc6bb") if speaker == "" and text.begins_with("(") else PAPER)

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

# ------------------------------------------------------------------ the phone (P.1 v2)

func _build_phone(root: Control) -> void:
	phone_panel = PanelContainer.new()
	phone_panel.name = "Phone"
	phone_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_panel.anchor_left = 1.0
	phone_panel.anchor_right = 1.0
	phone_panel.offset_left = -346
	phone_panel.offset_right = -16
	phone_panel.offset_top = 214
	phone_panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.035, 0.045, 0.88), Color(0.78, 1.0, 0.23, 0.35)))
	root.add_child(phone_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_panel.add_child(col)
	phone_status = _label(col, 11, Color("aaa592"))
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var av := PanelContainer.new()
	av.custom_minimum_size = Vector2(30, 30)
	av.add_theme_stylebox_override("panel", _style(Color("2a282c"), Color("3a383c"), 1))
	head.add_child(av)
	phone_avatar = _label(av, 12, Color("8a8890"))
	phone_avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	head.add_child(names)
	phone_name = _label(names, 16, PAPER)
	phone_sub = _label(names, 11, Color("aaa592"))
	phone_thread = VBoxContainer.new()
	phone_thread.add_theme_constant_override("separation", 5)
	phone_thread.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(phone_thread)
	phone_typing = _label(col, 16, LIME)
	phone_typing.visible = false
	phone_compose = _label(col, 13, Color("2a1a12"))
	phone_compose.visible = false
	var cst := _style(COPPER.lightened(0.25), COPPER, 1)
	cst.set_content_margin_all(6)
	phone_compose.add_theme_stylebox_override("normal", cst)
	phone_chip = PanelContainer.new()
	phone_chip.anchor_left = 1.0
	phone_chip.anchor_right = 1.0
	phone_chip.offset_left = -196
	phone_chip.offset_right = -16
	phone_chip.offset_top = 214
	phone_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_chip.add_theme_stylebox_override("panel", _style(Color(0.04, 0.035, 0.045, 0.8), Color(0.78, 1.0, 0.23, 0.35)))
	root.add_child(phone_chip)
	phone_chip_label = _label(phone_chip, 13, LIME)
	phone_panel.visible = false
	phone_chip.visible = false
	phone_header("???", "via YARD-PUBLIC (no internet)")
	phone_set_status("NO SIM · Wi-Fi: YARD-PUBLIC")

func _build_alert(root: Control) -> void:
	alert_panel = Control.new()
	alert_panel.name = "PhoneAlert"
	alert_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	alert_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_panel.visible = false
	root.add_child(alert_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_panel.add_child(dim)
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -120
	box.offset_bottom = 120
	box.add_theme_stylebox_override("panel", _style(Color("f4f7fb"), Color("e0362c"), 6))
	alert_panel.add_child(box)
	alert_label = _label(box, 26, Color("1a2230"))
	alert_label.remove_theme_color_override("font_outline_color")
	alert_label.add_theme_constant_override("outline_size", 0)
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func phone_header(sender: String, subline: String) -> void:
	phone_sender = sender
	phone_name.text = sender
	phone_name.add_theme_color_override("font_color", LIME if sender != "???" else PAPER)
	phone_sub.text = subline
	phone_sub.visible = subline != ""
	phone_avatar.text = "• •\n__" if sender != "???" else "?"
	phone_avatar.add_theme_color_override("font_color", LIME if sender != "???" else Color("8a8890"))
	phone_chip_label.text = "• " + sender + "  ·  PHONE"

func phone_set_status(text: String) -> void:
	phone_status.text = text

## Shows the thread (reopens it after a collapse).
func phone_open() -> void:
	phone_panel.visible = true
	phone_chip.visible = false
	phone_idle = 0.0

## A message in the thread. outgoing = Fony's (right, copper, lowercase). quiet = already there (no ping, no open).
func say_text(sender: String, text: String, outgoing := false, quiet := false) -> void:
	typing_left = 0.0
	phone_typing.visible = false
	var body := text.to_lower() if outgoing else text
	phone_log.append({"from": sender, "text": body, "out": outgoing})
	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if outgoing else Control.SIZE_SHRINK_BEGIN
	var st := _style(COPPER if outgoing else PHONE_DARK, COPPER.darkened(0.2) if outgoing else LIME, 2)
	st.set_content_margin_all(7)
	bubble.add_theme_stylebox_override("panel", st)
	var l := _label(bubble, 14, Color("1d140e") if outgoing else PAPER)
	if outgoing:
		l.add_theme_constant_override("outline_size", 0)
	l.text = body
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(262.0, 22.0 + 8.2 * float(body.length())), 0)
	phone_thread.add_child(bubble)
	while phone_thread.get_child_count() > MAX_BUBBLES:
		var old := phone_thread.get_child(0)
		phone_thread.remove_child(old)
		old.queue_free()
	if not quiet:
		phone_open()

func phone_typing_for(seconds: float) -> void:
	typing_left = seconds
	phone_typing.visible = true
	phone_open()

## Fony's unsent draft in the compose bar ("" clears it). "a|b|c" types a, deletes it, types b, ... and stays on the
## last one (Beat 10: "ok but" -> "what label" -> "ok but what's th"). It is never sent.
func phone_draft(text: String) -> void:
	draft_parts = PackedStringArray(text.split("|")) if text != "" else PackedStringArray()
	draft_text = draft_parts[0] if not draft_parts.is_empty() else ""
	draft_t = 0.0
	phone_compose.visible = text != ""
	phone_compose.text = draft_text
	if text != "":
		phone_open()

func phone_clear() -> void:
	for c in phone_thread.get_children():
		phone_thread.remove_child(c)
		c.queue_free()
	phone_draft("")
	typing_left = 0.0
	phone_typing.visible = false

## The full-screen emergency alert (covers the thread and wipes the draft). "" hides it.
func phone_alert(text: String) -> void:
	# the default font has no warning sign: draw it as (!)
	var t := text.replace("⚠", "(!)")
	var cut := t.find(" · ")
	if cut >= 0:
		t = t.substr(0, cut) + "\n" + t.substr(cut + 3)
	alert_label.text = t
	alert_panel.visible = text != ""
	if text != "":
		phone_clear()

## Gameplay HUD (objective box, Zero Score / score stack) on or off: off over cutscenes and the end card, so no
## leftover mission state (P.3's FUSES / SWEEP) sits over them. The phone stays (P.4 changes its header).
func story_chrome(on: bool) -> void:
	if objective_panel != null:
		objective_panel.visible = on
	if right_column != null:
		right_column.visible = on

func chrome_on() -> bool:
	return right_column != null and right_column.visible and objective_panel.visible

func letterbox(on: bool) -> void:
	letterbox_top.visible = on
	letterbox_bottom.visible = on

func skip_hint(text: String) -> void:
	skip_label.text = text
	skip_label.visible = text != ""

func _phone_tick(delta: float) -> void:
	if phone_panel == null:
		return
	if typing_left > 0.0:
		typing_left -= delta
		phone_typing.text = ["•", "• •", "• • •"][int(Time.get_ticks_msec() / 300) % 3]
		if typing_left <= 0.0:
			phone_typing.visible = false
	if draft_text != "":
		draft_t += delta
		var k := mini(int(draft_t / 1.8), draft_parts.size() - 1)
		draft_text = draft_parts[k]
		# type it out letter by letter inside each 1.8 s slot (the last one stays)
		var shown := draft_text.substr(0, mini(draft_text.length(), int((draft_t - 1.8 * k) * 14.0)))
		phone_compose.text = shown + ("|" if int(draft_t * 2.0) % 2 == 0 else " ")
	if phone_panel.visible and typing_left <= 0.0 and draft_text == "" and not alert_panel.visible:
		phone_idle += delta
		if phone_idle >= COLLAPSE_S:
			phone_panel.visible = false
			phone_chip.visible = phone_log.size() > 0
