shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float water_opacity : hint_range(0.0, 1.0) = 0.72;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float droplet_layer(vec2 uv, vec2 grid, float time_scale, float size_scale) {
	vec2 animated_uv = uv * grid + vec2(0.0, TIME * time_scale);
	vec2 cell_id = floor(animated_uv);
	vec2 cell_uv = fract(animated_uv);
	float seed = hash21(cell_id);
	float active = step(0.24, seed);
	vec2 center = vec2(
		mix(0.16, 0.84, hash21(cell_id + 7.13)),
		mix(0.12, 0.88, hash21(cell_id + 19.71))
	);
	float width = mix(0.10, 0.22, hash21(cell_id + 31.17)) * size_scale;
	float height = mix(0.15, 0.34, hash21(cell_id + 43.91)) * size_scale;
	vec2 delta = (cell_uv - center) / vec2(width, height);
	float body = 1.0 - smoothstep(0.72, 1.0, length(delta));
	float tail_x = abs(cell_uv.x - center.x);
	float tail_y = cell_uv.y - center.y;
	float tail_width = width * mix(0.24, 0.42, seed);
	float tail = (1.0 - smoothstep(tail_width * 0.55, tail_width, tail_x));
	tail *= smoothstep(0.02, 0.10, tail_y) * (1.0 - smoothstep(0.10, mix(0.32, 0.58, seed), tail_y));
	return active * max(body, tail * 0.46);
}

void fragment() {
	float fine_drops = droplet_layer(UV, vec2(48.0, 28.0), 0.11, 0.78);
	float large_drops = droplet_layer(UV + vec2(0.13, 0.07), vec2(19.0, 12.0), 0.055, 1.42);
	float water_shape = max(fine_drops * 0.62, large_drops);

	vec2 gradient = vec2(dFdx(water_shape), dFdy(water_shape));
	vec2 distortion = gradient * 0.0045;
	vec3 refracted = textureLod(screen_texture, SCREEN_UV + distortion, 0.0).rgb;

	float highlight = pow(clamp(length(gradient) * 5.0, 0.0, 1.0), 1.6);
	float alpha = clamp(water_shape * 0.78 + highlight * 0.12, 0.0, 0.86) * water_opacity;

	ALBEDO = refracted * vec3(0.91, 0.96, 1.0) + vec3(0.10, 0.13, 0.18) * highlight;
	ALPHA = alpha;
}
