shader_type spatial;
// Both sides of the pool shell. The riding faces point into the bowl; the backs
// are what you see from the deck, so culling them hides the transition.
render_mode specular_disabled, cull_disabled;

uniform vec4 albedo : source_color = vec4(0.75, 0.55, 0.42, 1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float texture_mix : hint_range(0.0, 1.0) = 0.0;
uniform float bands : hint_range(2.0, 4.0) = 3.0;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.28;
uniform float fill_light : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float edge = smoothstep(0.14, 0.36, 1.0 - facing);
	vec3 base = albedo.rgb;
	if (texture_mix > 0.001) {
		base *= texture(albedo_tex, UV).rgb;
	}
	ALBEDO = base * mix(1.0, 1.0 - outline_strength, edge);
	if (fill_light > 0.0) {
		EMISSION = ALBEDO * fill_light;
	}
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}

void light() {
	float ndot = clamp(abs(dot(NORMAL, LIGHT)), 0.0, 1.0);
	float stepped = max(floor(ndot * bands) / max(bands - 1.0, 1.0), 0.28);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * stepped;
}
