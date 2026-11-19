shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform vec4 glass_tint : source_color = vec4(0.16, 0.22, 0.29, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.92, 0.72, 0.46, 1.0);
uniform float base_opacity : hint_range(0.0, 0.2, 0.005) = 0.035;
uniform float sheen_strength : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float edge_strength : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float emission_strength : hint_range(0.0, 1.0, 0.01) = 0.08;

void fragment() {
	vec3 normal_view = normalize(NORMAL);
	vec3 view_direction = normalize(VIEW);
	float facing = clamp(dot(normal_view, view_direction), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge_glint = 1.0 - smoothstep(0.0, 0.075, edge_distance);
	float diagonal_coordinate = UV.x * 0.72 + UV.y * 0.28;
	float view_shift = (1.0 - abs(view_direction.x)) * 0.075;
	float sheen_band = 1.0 - smoothstep(0.018, 0.115, abs(diagonal_coordinate - (0.20 + view_shift)));
	float reflection = clamp(fresnel * 0.72 + sheen_band * sheen_strength * 0.34 + edge_glint * edge_strength * 0.24, 0.0, 1.0);

	ALBEDO = mix(glass_tint.rgb, sheen_color.rgb, reflection * 0.52);
	METALLIC = 0.12;
	ROUGHNESS = 0.16;
	SPECULAR = 0.82;
	EMISSION = sheen_color.rgb * reflection * emission_strength;
	ALPHA = clamp(base_opacity + fresnel * sheen_strength * 0.17 + sheen_band * sheen_strength * 0.075 + edge_glint * edge_strength * 0.035, 0.0, 0.28);
}
