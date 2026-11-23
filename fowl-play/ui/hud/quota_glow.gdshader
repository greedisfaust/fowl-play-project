shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.68, 0.22, 0.72);
uniform float glow_radius : hint_range(1.0, 8.0, 0.5) = 4.0;
uniform float glow_strength : hint_range(0.0, 2.0, 0.01) = 0.0;

void fragment() {
	vec4 glyph = texture(TEXTURE, UV);
	float halo = 0.0;
	vec2 px = TEXTURE_PIXEL_SIZE * glow_radius;
	halo = max(halo, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	halo = max(halo, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	halo = max(halo, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	halo = max(halo, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	halo = max(halo, texture(TEXTURE, UV + vec2(px.x * 0.7, px.y * 0.7)).a);
	halo = max(halo, texture(TEXTURE, UV + vec2(-px.x * 0.7, px.y * 0.7)).a);
	halo = max(halo, texture(TEXTURE, UV + vec2(px.x * 0.7, -px.y * 0.7)).a);
	halo = max(halo, texture(TEXTURE, UV + vec2(-px.x * 0.7, -px.y * 0.7)).a);
	float soft_halo = max(0.0, halo - glyph.a) * glow_strength;
	vec4 base = COLOR * glyph;
	vec4 glow = vec4(glow_color.rgb, glow_color.a * soft_halo);
	COLOR = vec4(mix(glow.rgb, base.rgb, glyph.a), max(base.a, glow.a));
}
