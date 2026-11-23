shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.62, 0.24, 0.18);
uniform float glow_radius : hint_range(1.0, 8.0, 0.5) = 2.5;
uniform float glow_strength : hint_range(0.0, 2.0, 0.01) = 0.0;
uniform float shimmer_position : hint_range(-1.0, 2.0, 0.01) = -1.0;

void fragment() {
	vec4 glyph = texture(TEXTURE, UV);
	float gradient = smoothstep(0.0, 1.0, UV.x);
	vec3 deep_gold = vec3(0.68, 0.39, 0.12);
	vec3 champagne = vec3(1.0, 0.84, 0.52);
	vec3 bright_gold = vec3(1.0, 0.94, 0.76);
	vec3 lettering = mix(deep_gold, champagne, gradient);
	lettering = mix(lettering, bright_gold, smoothstep(0.82, 1.0, gradient) * 0.28);

	float shimmer = 1.0 - smoothstep(0.0, 0.105, abs(UV.x - shimmer_position));
	lettering = mix(lettering, vec3(1.0, 0.98, 0.88), shimmer * 0.78);

	vec2 px = TEXTURE_PIXEL_SIZE * glow_radius;
	float surrounding_alpha = 0.0;
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	float halo = max(0.0, surrounding_alpha - glyph.a) * glow_strength;
	float alpha = max(glyph.a, glow_color.a * halo);
	vec3 final_color = mix(glow_color.rgb, lettering, glyph.a);
	COLOR = vec4(final_color, alpha);
}
