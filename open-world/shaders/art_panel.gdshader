shader_type spatial;
// Arcade Phase 1 (LOCAL): posters, murals, marquee, neon and solar cells from one atlas (arcade_art.png).
// Flat quads a few mm off the wall (Compatibility has no decals until Godot 4.8).
render_mode specular_disabled, cull_back;
uniform sampler2D art : source_color, filter_linear_mipmap, repeat_disable;
uniform float glow = 0.0;          // emission multiplier (marquee, neon)
uniform float paper_shade = 0.88;  // paper is a touch darker than the light it sits in
uniform float floor_light = 0.55;  // minimum light so shaded walls still read
uniform float sheen = 0.0;         // solar glass: brighten at grazing angles
uniform float wall_grime = 0.0;    // painted murals pick up the wall's ground grime
// Batched: per-panel settings ride in the vertex colour. r = glow / 3, g = paper shade, b = grime, a = 1 - sheen.
uniform bool use_vertex_color = false;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 c = texture(art, UV).rgb;
	float gl = glow;
	float shade = paper_shade;
	float grime = wall_grime;
	float sh = sheen;
	if (use_vertex_color) {
		gl = COLOR.r * 3.0;
		shade = COLOR.g;
		grime = COLOR.b;
		sh = 1.0 - COLOR.a;
	}
	float g = clamp(1.0 - wpos.y / 2.0, 0.0, 1.0) * grime;
	vec3 base = c * shade * (1.0 - g * 0.4);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	base += vec3(0.55, 0.62, 0.75) * sh * pow(1.0 - facing, 3.0);
	ALBEDO = base;
	EMISSION = c * gl;
	ROUGHNESS = 1.0;
}
void light() {
	float ndot = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * max(ndot, floor_light);
}
