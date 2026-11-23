shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque;

uniform float streak_opacity : hint_range(0.0, 1.0) = 0.82;

void fragment() {
	float x = abs(UV.x - 0.5);
	float core = 1.0 - smoothstep(0.08, 0.46, x);
	float top_fade = smoothstep(0.0, 0.08, UV.y);
	float bottom_fade = 1.0 - smoothstep(0.86, 1.0, UV.y);
	float alpha = core * top_fade * bottom_fade * streak_opacity;
	ALBEDO = mix(vec3(0.43, 0.54, 0.54), vec3(0.82, 0.89, 0.86), core * 0.5);
	ROUGHNESS = 0.28;
	ALPHA = alpha;
}
