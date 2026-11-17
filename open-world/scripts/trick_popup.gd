extends CanvasLayer
## Finish pass (Nov 17 2026): trick name popup. Watches the player's callout (player_controller.gd say()) and throws the name on
## screen in the punk-arcade style: heavy slanted letters, thick black outline, offset shadow, a punch-in, a short hold and a fade.
## Tricks are lime, grinds magenta, bails orange. No font file is shipped: the engine's default font, emboldened and slanted.

const SHOW_S := 1.15                # whole life of one name on screen
const PUNCH_S := 0.12               # scale 1.45 -> 1.0 at the start
const FADE_S := 0.35                # fade at the end
const COLORS := {"trick": Color("c8ff3a"), "grind": Color("ff3fa8"), "bail": Color("ff6a2a")}

var player: Node = null
var label: Label
var shown_id := 0
var age := 99.0
var shown := ""                     # tests / probes: the name currently on screen ("" when faded out)
var history: Array = []

func _ready() -> void:
	layer = 11
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 1.1
	font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.28, 1.0), Vector2.ZERO)
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = 54
	settings.font_color = COLORS.trick
	settings.outline_size = 14
	settings.outline_color = Color(0.04, 0.02, 0.03, 1.0)
	settings.shadow_size = 2
	settings.shadow_color = Color(0.05, 0.03, 0.08, 0.9)
	settings.shadow_offset = Vector2(6, 6)
	label = Label.new()
	label.name = "TrickName"
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -420
	label.offset_right = 420
	label.offset_top = 190
	label.offset_bottom = 270
	label.pivot_offset = Vector2(420, 40)
	label.rotation = deg_to_rad(-4.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	add_child(label)

func _process(delta: float) -> void:
	if player != null and is_instance_valid(player) and "callout_id" in player and int(player.callout_id) != shown_id:
		shown_id = int(player.callout_id)
		show_name(str(player.callout), str(player.callout_kind))
	age += delta
	if age >= SHOW_S:
		label.modulate.a = 0.0
		shown = ""
		return
	var punch := clampf(age / PUNCH_S, 0.0, 1.0)
	var s := lerpf(1.45, 1.0, 1.0 - (1.0 - punch) * (1.0 - punch))
	label.scale = Vector2(s, s)
	label.modulate.a = clampf((SHOW_S - age) / FADE_S, 0.0, 1.0)

func show_name(text: String, kind := "trick") -> void:
	label.text = text
	label.label_settings.font_color = COLORS.get(kind, COLORS.trick)
	age = 0.0
	shown = text
	label.modulate.a = 1.0
	label.scale = Vector2(1.45, 1.45)
	history.append(text)
	if history.size() > 32:
		history.pop_front()
