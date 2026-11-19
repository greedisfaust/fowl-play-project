shader_type canvas_item;

// Applied to ScreenText only. The transparent SubViewport keeps the panel out of this pass.
uniform float hdr_boost : hint_range(1.0, 8.0, 0.1) = 2.2;
uniform bool led_matrix_enabled = true;
uniform float led_dot_size : hint_range(1.0, 16.0, 0.5) = 3.0;
uniform float led_gap : hint_range(0.0, 0.8, 0.01) = 0.28;
uniform float led_softness : hint_range(0.01, 0.25, 0.01) = 0.08;

void fragment() {
	vec4 glyph = COLOR;

	// Mask glyph coverage, not the viewport background. Transparent pixels remain transparent.
	if (led_matrix_enabled && glyph.a > 0.001) {
		float cell_size = max(led_dot_size, 1.0);
		vec2 cell_uv = fract(FRAGCOORD.xy / cell_size);
		float distance_to_center = distance(cell_uv, vec2(0.5));
		float radius = 0.5 * (1.0 - clamp(led_gap, 0.0, 0.8));
		float dot_coverage = 1.0 - smoothstep(
			max(radius - led_softness, 0.0),
			radius + led_softness,
			distance_to_center
		);
		glyph.a *= dot_coverage;
	}

	// HDR values are carried by the transparent viewport into the overlay's emission texture.
	glyph.rgb *= hdr_boost;
	COLOR = glyph;
}
