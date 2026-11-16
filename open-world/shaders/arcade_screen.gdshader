shader_type spatial;
// Arcade Phase 2 (LOCAL): cabinet CRT screens from arcade_screens.png. Unshaded (no light passes).
// Static screens: UV points straight into the atlas; vertex colour r = brightness, g = flicker phase.
// Attract screen (the featured ZERO GAME THING PRO 2K): UV is 0..1 and the shader cycles `cells`,
// with a rolling bar and a short burst of static between cards. A light loop, no video in the pck.
render_mode unshaded, cull_back, shadows_disabled;
uniform sampler2D screens : source_color, filter_linear_mipmap, repeat_disable;
uniform bool attract = false;
uniform vec4 cells[6];
uniform int cell_count = 1;
uniform float hold = 3.2;
uniform float atlas_h = 768.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	vec2 uv = UV;
	float bright = COLOR.r * 1.6;
	float phase = COLOR.g * 6.2831;
	float lines = atlas_h;
	float noise_mix = 0.0;
	vec2 local = UV;
	if (attract) {
		float t = TIME / hold;
		int idx = int(mod(floor(t), float(max(cell_count, 1))));
		float f = fract(t);
		vec4 r = cells[idx];
		// slight barrel bulge
		vec2 c = local - 0.5;
		local = 0.5 + c * (1.0 - 0.06 * dot(c, c));
		uv = r.xy + clamp(local, 0.0, 1.0) * r.zw;
		lines = r.w * atlas_h;
		noise_mix = smoothstep(0.92, 1.0, f) + (1.0 - smoothstep(0.0, 0.06, f));
		bright = 1.15;
	}
	vec3 col = texture(screens, uv).rgb;
	float scan = 0.82 + 0.18 * sin(UV.y * lines * 3.14159);
	if (attract) {
		scan = 0.8 + 0.2 * sin(local.y * 180.0 * 3.14159);
		float bar = smoothstep(0.0, 0.08, abs(fract(local.y - TIME * 0.18) - 0.5));
		col *= 0.9 + 0.1 * bar;
		float n = hash(floor(local * vec2(160.0, 120.0)) + floor(TIME * 24.0));
		col = mix(col, vec3(n * 0.8), clamp(noise_mix, 0.0, 1.0));
		vec2 v = local - 0.5;
		col *= 1.0 - dot(v, v) * 1.1;
	}
	float flick = 0.97 + 0.03 * sin(TIME * 11.0 + phase);
	ALBEDO = col * scan * flick * bright;
}
