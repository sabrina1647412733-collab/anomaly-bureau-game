shader_type sky;

// Time is supplied by the controller, so pause and save/restore freeze clouds too.
uniform vec4 zenith_color : source_color = vec4(0.025, 0.045, 0.078, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.12, 0.15, 0.18, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.055, 0.069, 0.086, 1.0);
uniform vec3 sun_direction = vec3(-0.4, 0.7, -0.2);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.85;
uniform float daylight : hint_range(0.0, 1.0) = 0.0;
uniform float weather_time = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void sky() {
	float elevation = max(EYEDIR.y, 0.0);
	vec3 colour = mix(horizon_color.rgb, zenith_color.rgb, pow(elevation, 0.55));
	vec2 projected = EYEDIR.xz / (max(EYEDIR.y, 0.08) + 0.32);
	vec2 wind = vec2(weather_time * 0.0018, weather_time * 0.0006);
	float clouds = smooth_noise(projected * 2.8 + wind) * 0.58;
	clouds += smooth_noise(projected * 5.6 + wind * 1.3) * 0.29;
	clouds += smooth_noise(projected * 11.2 + wind * 1.7) * 0.13;
	float cover = smoothstep(0.78 - cloud_cover * 0.62, 0.99 - cloud_cover * 0.38, clouds);
	colour = mix(colour, cloud_color.rgb, cover * 0.86);
	float sun = smoothstep(0.99962, 0.99994, dot(EYEDIR, normalize(sun_direction)));
	colour += vec3(1.0, 0.86, 0.62) * sun * daylight * (1.0 - cover) * (1.0 - cloud_cover * 0.75);
	float moon = smoothstep(0.99972, 0.99990, dot(EYEDIR, normalize(vec3(0.28, 0.52, -0.72))));
	colour += vec3(0.39, 0.48, 0.59) * moon * (1.0 - daylight) * (1.0 - cover * 0.98);
	float below = 1.0 - smoothstep(-0.15, 0.0, EYEDIR.y);
	COLOR = mix(colour, horizon_color.rgb * 0.35, below);
}
