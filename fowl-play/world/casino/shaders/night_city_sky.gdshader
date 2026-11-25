shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.004, 0.008, 0.022);
uniform vec3 upper_haze_color : source_color = vec3(0.018, 0.028, 0.065);
uniform vec3 horizon_color : source_color = vec3(0.055, 0.070, 0.125);
uniform vec3 amber_city_glow : source_color = vec3(0.34, 0.105, 0.045);
uniform vec3 cyan_city_glow : source_color = vec3(0.025, 0.18, 0.28);
uniform vec3 violet_city_glow : source_color = vec3(0.16, 0.055, 0.25);
uniform float horizon_glow_strength : hint_range(0.0, 2.0) = 0.72;
uniform float cloud_strength : hint_range(0.0, 0.25) = 0.055;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float elevation = direction.y;
	float horizon = 1.0 - smoothstep(-0.12, 0.34, abs(elevation));
	float upper = smoothstep(0.02, 0.92, elevation);
	vec3 sky_color = mix(horizon_color, zenith_color, upper);
	sky_color = mix(sky_color, upper_haze_color, horizon * 0.28);

	float azimuth = atan(direction.x, direction.z);
	float city_band = exp(-pow((elevation + 0.075) * 10.5, 2.0));
	float glow_a = exp(-pow((azimuth - 0.65) * 1.05, 2.0));
	float glow_b = exp(-pow((azimuth + 1.15) * 0.82, 2.0));
	float glow_c = exp(-pow((azimuth - 2.35) * 1.15, 2.0));
	float glow_mix = glow_a * 0.62 + glow_b * 0.46 + glow_c * 0.36;
	sky_color += amber_city_glow * city_band * glow_mix * horizon_glow_strength;
	sky_color += cyan_city_glow * city_band * glow_a * 0.48 * horizon_glow_strength;
	sky_color += violet_city_glow * city_band * glow_c * 0.58 * horizon_glow_strength;

	vec2 cloud_uv = vec2(azimuth * 2.0, elevation * 8.0 + TIME * 0.0015);
	float clouds = value_noise(cloud_uv * 3.2) * 0.65 + value_noise(cloud_uv * 7.0) * 0.35;
	float cloud_mask = smoothstep(0.48, 0.78, clouds) * smoothstep(-0.02, 0.52, elevation);
	sky_color = mix(sky_color, upper_haze_color * 1.45, cloud_mask * cloud_strength);

	COLOR = sky_color;
}
