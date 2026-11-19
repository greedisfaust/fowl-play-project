shader_type canvas_item;

uniform float hdr_boost : hint_range(1.0, 8.0, 0.1) = 2.2;
uniform bool led_matrix_enabled = true;
uniform float led_dot_size : hint_range(1.0, 16.0, 0.5) = 3.0;
uniform float led_gap : hint_range(0.0, 0.8, 0.01) = 0.28;
uniform float led_softness : hint_range(0.01, 0.25, 0.01) = 0.08;

void fragment() {
	vec4 text_pixel = COLOR;

	if (led_matrix_enabled && text_pixel.a > 0.001) {
		vec2 cell_uv = fract(FRAGCOORD.xy / max(led_dot_size, 1.0));
		float distance_to_center = distance(cell_uv, vec2(0.5));
		float radius = 0.5 * (1.0 - clamp(led_gap, 0.0, 0.8));
		float dot_mask = 1.0 - smoothstep(
			max(radius - led_softness, 0.0),
			radius + led_softness,
			distance_to_center
		);
		text_pixel.a *= dot_mask;
	}

	text_pixel.rgb *= hdr_boost;
	COLOR = text_pixel;
}
