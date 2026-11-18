shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.015, 0.015, 0.02, 1.0);
uniform float outline_width : hint_range(0.001, 0.05, 0.001) = 0.008;
uniform float glow_strength : hint_range(0.0, 2.0, 0.01) = 0.0;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	EMISSION = outline_color.rgb * glow_strength;
	ALPHA = outline_color.a;
}
