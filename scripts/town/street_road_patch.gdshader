shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// Horizontal shallow repair surfaces. The source mesh supplies a solid inner
// ring (COLOR.a=1) and a feathered outer ring (COLOR.a=0), with no alpha prepass.
uniform sampler2D base_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 street_origin = vec3(0.0);
uniform vec4 road_tint : source_color = vec4(0.86, 0.87, 0.88, 1.0);
uniform float repair_darkening = 0.88;
uniform float tex_scale = 1.08;
uniform float normal_strength = 1.05;
uniform float wetness = 0.0;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - street_origin;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float broad_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = world_pos.xz * tex_scale * vec2(1.0, -1.0);
	vec3 source = texture(base_tex, uv).rgb;
	source = mix(vec3(dot(source, vec3(0.2126, 0.7152, 0.0722))), source, 0.42);
	float macro = broad_noise(world_pos.xz * 0.18 + vec2(8.7, 2.1));
	float patch = smoothstep(0.24, 0.76, broad_noise(world_pos.xz * 0.43 + vec2(2.7, 9.2)));
	float damp = clamp(wetness * 0.9, 0.0, 1.0) * (0.25 + patch * 0.75);
	ALBEDO = source * road_tint.rgb * repair_darkening
		* (1.0 + (macro - 0.5) * 0.17) * (1.0 - damp * 0.20);
	ROUGHNESS = max(0.56, clamp(texture(rough_tex, uv).r, 0.85, 1.0) - damp * 0.24);
	METALLIC = 0.0;
	SPECULAR = 0.38;
	vec2 bump = (texture(normal_tex, uv).rg * 2.0 - 1.0) * normal_strength;
	vec3 n = normalize(world_normal);
	vec3 perturb = vec3(bump.x, 0.0, -bump.y);
	perturb -= n * dot(perturb, n);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(n + perturb * (1.0 - damp * 0.38)), 0.0)).xyz);
	ALPHA = clamp(COLOR.a, 0.0, 1.0);
}
