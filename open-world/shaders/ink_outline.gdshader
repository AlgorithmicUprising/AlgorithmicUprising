shader_type spatial;
// Arcade Phase 1 (LOCAL): inverted-hull ink line, used as next_pass on props and frames (not on big walls).
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;
uniform vec4 ink : source_color = vec4(0.07, 0.05, 0.06, 1.0);
uniform float width = 0.03;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = ink.rgb;
}
