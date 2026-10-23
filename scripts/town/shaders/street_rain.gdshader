shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float weather_time = 0.0;
uniform float rain_amount : hint_range(0.0, 1.0) = 0.6;
uniform float daylight : hint_range(0.0, 1.0) = 0.0;
varying float drop_visible;

void vertex() {
	// Each instance starts above the highest roof/awning in its own world cell.
	// The shader never uses TIME, which otherwise continues during pause.
	float phase = INSTANCE_CUSTOM.g;
	float floor_height = INSTANCE_CUSTOM.r * 64.0;
	float speed = mix(0.55, 0.75, INSTANCE_CUSTOM.b);
	float descent = fract(phase - weather_time * speed);
	VERTEX.y += floor_height + 0.45 + descent * 17.0;
	VERTEX.x += descent * 0.16;
	drop_visible = smoothstep(INSTANCE_CUSTOM.a - 0.05, INSTANCE_CUSTOM.a + 0.10, rain_amount);
	// Very close ribbons otherwise project into distracting blue bars. This is
	// world rain, so suppress only drops next to the eye rather than tinting HUD.
	float eye_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	drop_visible *= smoothstep(1.1, 3.5, eye_distance);
}

void fragment() {
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	float ends = sin(UV.y * 3.14159265);
	ALBEDO = mix(vec3(0.35, 0.42, 0.46), vec3(0.64, 0.68, 0.70), daylight);
	ALPHA = edge * ends * drop_visible * mix(0.14, 0.12, daylight);
}
