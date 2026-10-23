shader_type spatial;
render_mode cull_disabled;

// Shared mipmapped outdoor PBR. No screen/depth reads or renderer-specific APIs.
uniform sampler2D base_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 street_origin = vec3(0.0);
uniform float tex_scale = 0.5; // Repetitions per metre, independent of exported mesh UVs.
uniform float base_roughness = 1.0;
uniform float minimum_roughness = 0.62;
uniform float metalness = 0.0;
uniform float normal_strength = 0.5;
uniform float vertex_tint_strength = 0.35;
uniform float albedo_saturation = 1.0;
uniform float ao_strength = 0.3;
uniform float macro_variation = 0.08;
uniform float wall_age = 0.0;
uniform float wetness = 0.0;
uniform float wet_response = 0.4;
uniform float emission_strength = 0.0;
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

vec4 tri(sampler2D tex, vec2 uv_x, vec2 uv_y, vec2 uv_z, vec3 weights) {
	return texture(tex, uv_x) * weights.x + texture(tex, uv_y) * weights.y
		+ texture(tex, uv_z) * weights.z;
}

void fragment() {
	vec3 n = normalize(world_normal) * (FRONT_FACING ? 1.0 : -1.0);
	vec3 weights = pow(abs(n), vec3(5.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	// Right-handed T/B/N frames: negative faces reverse U or V, so wood grain
	// and normal-map grooves agree on every building orientation.
	vec3 side = step(vec3(0.0), n) * 2.0 - 1.0;
	vec3 p = world_pos * tex_scale;
	vec2 uv_x = vec2(-p.z * side.x, p.y);
	vec2 uv_y = vec2(p.x, -p.z * side.y);
	vec2 uv_z = vec2(p.x * side.z, p.y);
	vec3 source = tri(base_tex, uv_x, uv_y, uv_z, weights).rgb;
	source = mix(vec3(dot(source, vec3(0.2126, 0.7152, 0.0722))), source, albedo_saturation);
	vec3 base = source * tint.rgb;
	// Preserve palette variation without multiplying the already coloured PBR
	// by the flat prototype's dark/green vertex paint.
	base *= mix(vec3(1.0), clamp(COLOR.rgb, vec3(0.0), vec3(1.15)), vertex_tint_strength);
	float macro = broad_noise(world_pos.xz * 0.18 + vec2(8.7, 2.1));
	base *= 1.0 + (macro - 0.5) * macro_variation;
	float upright = 1.0 - smoothstep(0.35, 0.82, abs(n.y));
	float foot_height = 0.34 + broad_noise(world_pos.xz * 0.7) * 0.42;
	float foot = (1.0 - smoothstep(0.05, foot_height, world_pos.y)) * upright * wall_age;
	float streak = smoothstep(0.62, 0.85, broad_noise(vec2(
		(world_pos.x + world_pos.z) * 2.2, world_pos.y * 0.12))) * upright * wall_age;
	base *= 1.0 - foot * 0.16 - streak * 0.055;
	// Broad static patches respond to weather. Even saturated asphalt keeps a
	// rough surface between the separate real puddles; it is never a city mirror.
	float patch = smoothstep(0.24, 0.76, broad_noise(world_pos.xz * 0.43 + vec2(2.7, 9.2)));
	float upward = smoothstep(0.15, 0.85, n.y);
	float damp = clamp(wetness * wet_response, 0.0, 1.0)
		* mix(0.32 + foot * 0.24, 0.25 + patch * 0.75, upward);
	ALBEDO = base * (1.0 - damp * 0.20);
	float dry_roughness = clamp(tri(rough_tex, uv_x, uv_y, uv_z, weights).r
		* base_roughness, minimum_roughness, 1.0);
	ROUGHNESS = max(mix(minimum_roughness, 0.34, damp), dry_roughness - damp * 0.28);
	METALLIC = metalness;
	SPECULAR = 0.38;
	AO = mix(1.0, tri(ao_tex, uv_x, uv_y, uv_z, weights).r, ao_strength);
	AO_LIGHT_AFFECT = 0.15;
	// Imported normal textures may use RG compression. Blend perturbations
	// around the geometric normal, keeping pipes curved even under a flat map.
	vec2 bump_x = (texture(normal_tex, uv_x).rg * 2.0 - 1.0) * normal_strength;
	vec2 bump_y = (texture(normal_tex, uv_y).rg * 2.0 - 1.0) * normal_strength;
	vec2 bump_z = (texture(normal_tex, uv_z).rg * 2.0 - 1.0) * normal_strength;
	vec3 perturb = vec3(0.0, bump_x.y, -bump_x.x * side.x) * weights.x
		+ vec3(bump_y.x, 0.0, -bump_y.y * side.y) * weights.y
		+ vec3(bump_z.x * side.z, bump_z.y, 0.0) * weights.z;
	perturb -= n * dot(perturb, n);
	vec3 bumped = normalize(n + perturb * (1.0 - damp * 0.38));
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
	EMISSION = base * emission_strength;
}
