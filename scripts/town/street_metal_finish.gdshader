shader_type spatial;
render_mode cull_disabled;

// Light zinc/paint finishes for rain pipes and appliance casings. Intentionally
// separate from the rusty chequer-plate texture used on heavy street steel.
uniform vec4 tint : source_color = vec4(0.72, 0.71, 0.66, 1.0);
uniform vec3 street_origin = vec3(0.0);
uniform float metalness = 0.0;
uniform float base_roughness = 0.72;
uniform float mottle_amount = 0.022;
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

float surface_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec3 axis = abs(normalize(world_normal));
	// Select the dominant local surface for subtle finish variation. No holes,
	// concrete grain, black vertex paint or artificial emissive fill are used.
	vec2 plane = world_pos.xy;
	if (axis.x > axis.y && axis.x > axis.z) {
		plane = world_pos.zy;
	} else if (axis.y > axis.z) {
		plane = world_pos.xz;
	}
	float broad = surface_noise(plane * 4.0);
	float fine = surface_noise(plane * 70.0);
	float footprint = max(length(dFdx(plane)), length(dFdy(plane))) * 70.0;
	fine = mix(0.5, fine, 1.0 - smoothstep(0.35, 1.05, footprint));
	float variation = (broad - 0.5) * mottle_amount + (fine - 0.5) * 0.012;
	float damp = clamp(wetness, 0.0, 1.0) * (0.20 + max(world_normal.y, 0.0) * 0.22);
	ALBEDO = tint.rgb * (1.0 + variation - damp * 0.045);
	METALLIC = metalness;
	ROUGHNESS = clamp(base_roughness + (fine - 0.5) * 0.045 + (broad - 0.5) * 0.025 - damp * 0.12, 0.48, 0.88);
	SPECULAR = 0.38;
}
