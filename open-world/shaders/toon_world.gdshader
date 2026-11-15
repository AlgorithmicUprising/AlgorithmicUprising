shader_type spatial;
// Arcade Phase 1 (LOCAL): one toon surface for the Arcade, outside and (Phase 2) inside.
// An extension of cel_block: same stepped bands, plus a shared greyscale trim sheet gradient-mapped
// between two palette colours, procedural corrugation ribs with distance fade, and a ground-up grime ramp.
// mode 0: world-space trim tile (walls, deck, roof)   mode 1: mesh UV on a Kenney colormap (kit pieces)
// mode 2: mesh UV on a trim tile (roll-up shutter; uv_offset scrolls the slats)
render_mode specular_disabled, cull_back;
uniform vec4 color_dark : source_color = vec4(0.11, 0.29, 0.27, 1.0);
uniform vec4 color_light : source_color = vec4(0.22, 0.5, 0.48, 1.0);
uniform sampler2D trim : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D kit_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform int mode = 0;
uniform int trim_tile = -1;           // 0 concrete, 1 shutter slats, 2 box profile, 3 rust; -1 none
uniform float tile_m = 2.0;           // metres per trim repeat
uniform float detail_mix : hint_range(0.0, 1.0) = 1.0;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float rib_pitch = 0.0;        // >0: corrugation ribs every rib_pitch metres (vertical ribs)
uniform float grime : hint_range(0.0, 1.0) = 0.0;
uniform float bands : hint_range(2.0, 5.0) = 3.0;
uniform float rim : hint_range(0.0, 1.0) = 0.22;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 1.0;
// Batched props: palette colour comes from the vertex colour (one draw call for many flat parts).
// rgb = light colour (dark = rgb * vc_dark); alpha = emission strength / 4 (0 = not lit from inside).
uniform bool use_vertex_color = false;
uniform float vc_dark = 0.72;
varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float trim_sample(vec2 tuv) {
	if (trim_tile < 0) {
		return 1.0;
	}
	// Manual wrap inside one 256 px tile of the 512 px sheet. textureGrad keeps the mip choice
	// from the unwrapped coordinate, so the fract() seam does not flash a 1x1 mip.
	vec2 dx = dFdx(tuv) * 0.5;
	vec2 dy = dFdy(tuv) * 0.5;
	vec2 origin = vec2(float(trim_tile % 2), float(trim_tile / 2)) * 0.5;
	vec2 inset = vec2(3.0 / 512.0);
	vec2 auv = origin + inset + fract(tuv) * (0.5 - inset * 2.0);
	float t = textureGrad(trim, auv, dx, dy).r;
	// fade detail toward its average where it would alias (far, grazing walls)
	float fw = length(fwidth(tuv)) * 256.0;
	return mix(t, 0.62, smoothstep(2.0, 6.0, fw));
}

void fragment() {
	float t = 1.0;
	if (mode == 1) {
		vec3 c = texture(kit_tex, UV).rgb;
		t = dot(c, vec3(0.299, 0.587, 0.114));
	} else if (mode == 2) {
		t = trim_sample(UV * uv_scale / tile_m + uv_offset / tile_m);
		if (rib_pitch > 0.0) {
			// horizontal roll-up slats that travel with uv_offset
			float ph = (UV.y * uv_scale.y + uv_offset.y) / rib_pitch;
			float fw = fwidth(ph);
			float s = fract(ph);
			float aa = clamp(fw * 1.5, 0.01, 0.3);
			float groove = smoothstep(0.0, aa, s) * (1.0 - smoothstep(0.82 - aa, 0.82, s));
			float lip = smoothstep(0.08, 0.3, s) * (1.0 - smoothstep(0.55, 0.8, s));
			float r = mix(0.35, mix(0.75, 1.0, lip), groove);
			r = mix(r, 0.75, smoothstep(0.25, 0.6, fw));
			t = r * mix(0.85, 1.0, t);
		}
	} else {
		vec3 n = abs(wnorm);
		vec2 uv = n.x > n.z ? wpos.zy : wpos.xy;
		if (n.y > 0.7) {
			uv = wpos.xz;
		}
		t = trim_sample(uv / tile_m);
		if (rib_pitch > 0.0 && n.y < 0.7) {
			float ph = uv.x / rib_pitch;
			float fw = fwidth(ph);
			float s = 0.5 + 0.5 * sin(ph * 6.2831853);
			// two antialiased steps (shadow side, face, highlight)
			float aa = clamp(fw * 3.0, 0.02, 0.5);
			float r = 0.5 * smoothstep(0.3 - aa, 0.3 + aa, s) + 0.5 * smoothstep(0.78 - aa, 0.78 + aa, s);
			// distance fade: past ~1.5 px per rib, use the rib average so there is no moire
			r = mix(r, 0.55, smoothstep(0.25, 0.6, fw));
			t = mix(0.6, 1.0, r) * mix(0.86, 1.0, t);
		}
	}
	t = mix(1.0, t, detail_mix);
	vec3 cd = color_dark.rgb;
	vec3 cl = color_light.rgb;
	vec3 em = emission_color.rgb * emission_energy;
	if (use_vertex_color) {
		vec3 vc = COLOR.rgb;
		float e = COLOR.a < 0.999 ? (1.0 - COLOR.a) * 4.0 : 0.0;
		cl = vc;
		cd = vc * vc_dark;
		if (e > 0.0) {
			// emissive part: dark albedo + strong emission reads as light from inside
			cl = vc * 0.3;
			cd = cl;
			em = vc * e;
		}
	}
	vec3 base = mix(cd, cl, t);
	float g = clamp(1.0 - wpos.y / 2.0, 0.0, 1.0) * grime;
	base *= 1.0 - g * 0.4;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	base *= mix(1.0, 1.0 - rim, smoothstep(0.12, 0.36, 1.0 - facing));
	ALBEDO = base;
	EMISSION = em;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}

void light() {
	float ndot = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float stepped = max(floor(ndot * bands + 0.35) / max(bands - 1.0, 1.0), 0.3);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * min(stepped, 1.0);
}
