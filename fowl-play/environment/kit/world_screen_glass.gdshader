shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 reflection_color : source_color = vec4(0.72, 0.86, 1.0, 1.0);
uniform float reflection_strength : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform float edge_highlight_strength : hint_range(0.0, 1.0, 0.01) = 0.10;
uniform float highlight_opacity : hint_range(0.0, 0.08, 0.001) = 0.018;

void fragment() {
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge = 1.0 - smoothstep(0.0, 0.035, edge_distance);
	float diagonal = UV.x * 0.62 + UV.y * 0.38;
	float band = 1.0 - smoothstep(0.015, 0.10, abs(diagonal - 0.76));
	float highlight = clamp(band * reflection_strength + edge * edge_highlight_strength, 0.0, 0.16);
	ALBEDO = vec3(0.0);
	EMISSION = reflection_color.rgb * highlight;
	ALPHA = highlight * highlight_opacity;
}
