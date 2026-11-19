shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform float base_opacity : hint_range(0.0, 0.15, 0.005) = 0.035;
uniform float sheen_strength : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float near_distance : hint_range(0.25, 10.0, 0.25) = 1.5;
uniform float far_distance : hint_range(1.0, 20.0, 0.25) = 5.0;
uniform vec3 glass_tint : source_color = vec3(0.42, 0.58, 0.72);

void fragment() {
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	float distance_to_camera = length(VERTEX);
	float near_fade = 1.0 - smoothstep(near_distance, max(far_distance, near_distance + 0.1), distance_to_camera);
	float sheen = fresnel * near_fade * sheen_strength;

	ALBEDO = glass_tint;
	METALLIC = 0.05;
	ROUGHNESS = 0.14;
	SPECULAR = 0.8;
	CLEARCOAT = 1.0;
	ALPHA = clamp(base_opacity + sheen * 0.18, 0.0, 0.22);
}
