shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled, ambient_light_disabled;

uniform float outline_width = 0.01;
uniform vec4 outline_color : source_color = vec4(0.09, 0.055, 0.04, 1.0);

void vertex() {
	VERTEX += normalize(NORMAL) * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
