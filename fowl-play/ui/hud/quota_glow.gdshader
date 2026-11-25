shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.34, 1.0);
uniform float glow_radius : hint_range(2.0, 12.0, 0.5) = 5.0;
uniform float glow_strength : hint_range(0.0, 4.0, 0.01) = 0.0;
uniform float quota_active : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float reward_flash : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float flash_position : hint_range(-1.0, 2.0, 0.01) = -0.2;

void fragment() {
	vec4 glyph = texture(TEXTURE, UV);
	vec3 original_text_color = COLOR.rgb;

	// Preserve the Label's original theme color until the quota is actually reached.
	vec3 champagne_gold = vec3(1.0, 0.79, 0.43);
	vec3 pale_gold = vec3(1.0, 0.91, 0.68);
	float gold_gradient = smoothstep(0.0, 1.0, UV.x);
	vec3 gold_tint = mix(champagne_gold, pale_gold, gold_gradient * 0.55);
	vec3 text_color = mix(original_text_color, gold_tint, quota_active);

	// A soft multi-radius halo avoids the hard, pixel-crisp edge of a simple outline.
	vec2 texel = TEXTURE_PIXEL_SIZE * glow_radius;
	float blur_alpha = 0.0;
	blur_alpha += texture(TEXTURE, UV + vec2(texel.x, 0.0)).a;
	blur_alpha += texture(TEXTURE, UV - vec2(texel.x, 0.0)).a;
	blur_alpha += texture(TEXTURE, UV + vec2(0.0, texel.y)).a;
	blur_alpha += texture(TEXTURE, UV - vec2(0.0, texel.y)).a;
	blur_alpha += texture(TEXTURE, UV + texel * vec2(0.707, 0.707)).a;
	blur_alpha += texture(TEXTURE, UV + texel * vec2(-0.707, 0.707)).a;
	blur_alpha += texture(TEXTURE, UV + texel * vec2(0.707, -0.707)).a;
	blur_alpha += texture(TEXTURE, UV + texel * vec2(-0.707, -0.707)).a;
	blur_alpha *= 0.125;
	float halo = max(0.0, blur_alpha - glyph.a * 0.72);
	float halo_alpha = halo * glow_strength * quota_active * 0.42;

	// One performative sweep, followed by a restrained idle glint using shader time.
	float flash = 1.0 - smoothstep(0.0, 0.13, abs(UV.x - flash_position));
	float idle_position = fract(TIME * 0.12);
	float idle_glint = 1.0 - smoothstep(0.0, 0.085, abs(UV.x - idle_position));
	float glint = max(flash * reward_flash, idle_glint * quota_active * 0.13);
	text_color = mix(text_color, vec3(1.0, 0.97, 0.84), glint * 0.8);

	float output_alpha = max(glyph.a, halo_alpha) * COLOR.a;
	vec3 output_color = mix(glow_color.rgb, text_color, glyph.a);
	COLOR = vec4(output_color, output_alpha);
}
