shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform float streak_opacity : hint_range(0.0, 1.0) = 0.42;

void fragment() {
	float centerline = abs(UV.x - 0.5);
	float taper = mix(0.10, 0.34, smoothstep(0.0, 0.78, UV.y));
	float body = 1.0 - smoothstep(taper, taper + 0.12, centerline);
	float head_fade = smoothstep(0.0, 0.10, UV.y);
	float tail_fade = 1.0 - smoothstep(0.84, 1.0, UV.y);
	float edge_glint = 1.0 - smoothstep(0.02, 0.18, abs(centerline - taper * 0.68));
	float alpha = body * head_fade * tail_fade * streak_opacity;

	ALBEDO = mix(vec3(0.48, 0.58, 0.72), vec3(0.86, 0.92, 1.0), edge_glint * 0.32);
	ROUGHNESS = 0.14;
	METALLIC = 0.0;
	ALPHA = alpha;
}
