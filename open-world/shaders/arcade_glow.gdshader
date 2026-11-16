shader_type spatial;
// Arcade Phase 1 (LOCAL): lit-from-inside parts (glazing, lamps, bulbs). Unshaded, so the sun and omni
// lights add no extra passes. Vertex colour = tint; alpha carries the strength (see arcade_materials.gd glow_vc).
render_mode unshaded, cull_back, shadows_disabled;
uniform float floor_level = 0.35;
void fragment() {
	float e = (1.0 - COLOR.a) * 4.0;
	ALBEDO = COLOR.rgb * min(floor_level + e * 0.6, 1.7);
}
