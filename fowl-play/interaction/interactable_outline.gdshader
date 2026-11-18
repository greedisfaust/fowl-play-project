shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.015, 0.015, 0.02, 1.0);
uniform float outline_width : hint_range(0.001, 0.05, 0.001) = 0.008;
uniform float glow_strength : hint_range(0.0, 2.0, 0.01) = 0.0;
uniform float halo_softness : hint_range(0.05, 0.8, 0.01) = 0.32;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	float view_facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float halo_edge = 1.0 - smoothstep(0.0, halo_softness, view_facing);
	ALBEDO = outline_color.rgb;
	EMISSION = outline_color.rgb * glow_strength;
	ALPHA = halo_edge;
}
