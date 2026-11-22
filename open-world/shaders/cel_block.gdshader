shader_type spatial;
render_mode specular_disabled, cull_back;

uniform vec4 albedo : source_color = vec4(0.75, 0.55, 0.42, 1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float texture_mix : hint_range(0.0, 1.0) = 0.0;
uniform float bands : hint_range(2.0, 4.0) = 3.0;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.28;
// Phase 2 (LOCAL): self-lit fill so a face in its own shadow still reads (quarter-pipe face). 0 = off (every other block).
uniform float fill_light : hint_range(0.0, 2.0) = 0.0;
// Ground slabs: sample the tiling concrete in world space so a 160 m slab does not stretch one UV square.
uniform float triplanar : hint_range(0.0, 1.0) = 0.0;
uniform float triplanar_scale : hint_range(0.05, 2.0) = 0.42;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = smoothstep(0.14, 0.36, 1.0 - facing);
	vec3 base = albedo.rgb;
	if (texture_mix > 0.001) {
		vec3 tex = texture(albedo_tex, UV).rgb;
		if (triplanar > 0.5) {
			vec3 w = abs(normalize(world_nrm));
			w = pow(w, vec3(4.0));
			w /= max(w.x + w.y + w.z, 0.0001);
			float s = triplanar_scale;
			vec3 tx = texture(albedo_tex, world_pos.zy * s).rgb;
			vec3 ty = texture(albedo_tex, world_pos.xz * s).rgb;
			vec3 tz = texture(albedo_tex, world_pos.xy * s).rgb;
			tex = tx * w.x + ty * w.y + tz * w.z;
		}
		base *= tex;
	}
	ALBEDO = base * mix(1.0, 1.0 - outline_strength, edge);
	if (fill_light > 0.0) {
		EMISSION = ALBEDO * fill_light;
	}
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}

void light() {
	float ndot = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float stepped = max(floor(ndot * bands) / max(bands - 1.0, 1.0), 0.28);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * stepped;
}
