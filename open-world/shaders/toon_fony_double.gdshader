shader_type spatial;
render_mode specular_disabled, cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float texture_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shade_tint : source_color = vec4(0.62, 0.58, 0.72, 1.0);
uniform float rim_strength : hint_range(0.0, 0.6) = 0.12;

void fragment() {
	vec3 base = albedo.rgb;
	if (texture_mix > 0.001) {
		base *= texture(albedo_tex, UV).rgb;
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	EMISSION = base * (0.22 + rim * rim_strength);
}

void light() {
	float ndot = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float band = 0.72;
	if (ndot > 0.45) {
		band = 1.0;
	}
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band;
}
