extends RefCounted
## Arcade Phase 1 (LOCAL): one shader family + one trim sheet + one art atlas for the whole Arcade.
## Interior (Phase 2) reuses these with darker palette pairs.

const TRIM_CONCRETE := 0
const TRIM_SHUTTER := 1
const TRIM_BOXPROFILE := 2
const TRIM_RUST := 3

# Proposed Arcade palette pairs (PLAN.md section 5). Site colours: acid, coolant, alert.
const WALL_DARK := Color("1d4a46")
const WALL := Color("37807a")
const WALL_IN_DARK := Color("102a28")
const WALL_IN := Color("1f4c48")
const BAND_DARK := Color("7a3022")
const BAND := Color("c45a40")
const STEEL := Color("3a3540")
const CAUTION := Color("f0c14a")
const GLASS_WARM := Color("ffcf8a")
const NEON_ACID := Color("dbff00")
const NEON_COOLANT := Color("2ec4b6")
const ALERT := Color("ff3355")
const INK := Color("121310")

static var _toon: Shader
static var _ink: Shader
static var _art: Shader
static var _trim: Texture2D
static var _atlas: Texture2D

const NO_OMNI_LAYER := 1 << 10   # batched Arcade meshes: sun + ambient only, so omni lights add no extra passes
const OMNI_MASK := 0xFFFFF & ~(1 << 10)

## Vertex-coloured flat props (one draw call for every steel/pipe/coping/etc. part).
static func props(line := 0.0, tile := -1, tile_m := 2.0, detail := 1.0) -> ShaderMaterial:
	var m := toon(Color.WHITE, Color.WHITE, tile, tile_m, line, 0.0, detail)
	m.set_shader_parameter("use_vertex_color", true)
	return m

## Vertex colour for an emissive prop in props(): energy rides in alpha.
static func glow_vc(c: Color, energy: float) -> Color:
	return Color(c.r, c.g, c.b, 1.0 - clampf(energy, 0.01, 3.99) / 4.0)

## Vertex-coloured art panels: per-panel glow / shade / grime / sheen.
static func art_vc() -> ShaderMaterial:
	var m := art(0.0, 0.9, 0.58)
	m.set_shader_parameter("use_vertex_color", true)
	return m

static func art_color(glow_amount := 0.0, shade := 0.9, grime := 0.0, sheen := 0.0) -> Color:
	return Color(glow_amount / 3.0, shade, grime, 1.0 - sheen)

static var _glow: Shader

## Unshaded vertex-coloured glow batch (windows, lamps, bulbs).
static func glow_batch() -> ShaderMaterial:
	if _glow == null:
		_glow = load("res://shaders/arcade_glow.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _glow
	return m

static func trim_texture() -> Texture2D:
	if _trim == null:
		_trim = load("res://assets/arcade/arcade_trim.png")
	return _trim

static func art_texture() -> Texture2D:
	if _atlas == null:
		_atlas = load("res://assets/arcade/arcade_art.png")
	return _atlas

static func toon(dark: Color, light: Color, tile := -1, tile_m := 2.0, line := 0.0, grime := 0.0, detail := 1.0) -> ShaderMaterial:
	if _toon == null:
		_toon = load("res://shaders/toon_world.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _toon
	m.set_shader_parameter("color_dark", dark)
	m.set_shader_parameter("color_light", light)
	m.set_shader_parameter("trim", trim_texture())
	m.set_shader_parameter("trim_tile", tile)
	m.set_shader_parameter("tile_m", tile_m)
	m.set_shader_parameter("grime", grime)
	m.set_shader_parameter("detail_mix", detail)
	if line > 0.0:
		m.next_pass = outline(line)
	return m

static func outline(width: float) -> ShaderMaterial:
	if _ink == null:
		_ink = load("res://shaders/ink_outline.gdshader")
	var o := ShaderMaterial.new()
	o.shader = _ink
	o.set_shader_parameter("width", width)
	return o

static func ribbed(dark: Color, light: Color, pitch := 0.22, tile := TRIM_CONCRETE, grime := 0.3) -> ShaderMaterial:
	var m := toon(dark, light, tile, 5.0, 0.0, grime, 0.6)
	m.set_shader_parameter("rib_pitch", pitch)
	return m

static func flat(c: Color, line := 0.0) -> ShaderMaterial:
	return toon(c.darkened(0.25), c, -1, 2.0, line)

static func glow(c: Color, energy := 1.6) -> ShaderMaterial:
	# Dark albedo + strong emission: reads as light coming from inside instead of a sunlit white panel.
	var m := toon(c * 0.3, c * 0.3, -1, 2.0, 0.0, 0.0, 0.0)
	m.set_shader_parameter("emission_color", c)
	m.set_shader_parameter("emission_energy", energy)
	m.set_shader_parameter("rim", 0.0)
	return m

static func kit(dark: Color, light: Color, colormap: Texture2D, line := 0.0) -> ShaderMaterial:
	var m := toon(dark, light, -1, 1.0, line)
	m.set_shader_parameter("mode", 1)
	m.set_shader_parameter("kit_tex", colormap)
	return m

static func shutter() -> ShaderMaterial:
	var m := toon(Color("2e343c"), Color("8a959e"), TRIM_RUST, 3.0, 0.0, 0.3, 0.6)
	m.set_shader_parameter("mode", 2)
	m.set_shader_parameter("rib_pitch", 0.16)
	return m

static func art(glow_amount := 0.0, shade := 0.88, floor_light := 0.55, grime := 0.0, sheen := 0.0) -> ShaderMaterial:
	if _art == null:
		_art = load("res://shaders/art_panel.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _art
	m.set_shader_parameter("art", art_texture())
	m.set_shader_parameter("glow", glow_amount)
	m.set_shader_parameter("paper_shade", shade)
	m.set_shader_parameter("floor_light", floor_light)
	m.set_shader_parameter("wall_grime", grime)
	m.set_shader_parameter("sheen", sheen)
	return m
