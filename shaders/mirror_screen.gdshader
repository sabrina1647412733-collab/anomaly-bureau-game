shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// 真镜面：把相机的视线按镜面法线反射，再对这个方向做一次屏幕空间采样。
// 简化做法（不引入 ReflectionProbe 依赖）：
//   用 SCREEN_TEXTURE 沿反射方向做 UV 偏移采样。
// 在这类小场景（一面 1.2×1.8 的镜子）里效果足够像"照出店堂"。

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 screen_size = vec2(1600.0, 900.0);
uniform float distort : hint_range(0.0, 0.2) = 0.012;   // 一点起伏，别像一块玻璃板
uniform float tint : hint_range(0.0, 1.0) = 0.92;
uniform vec3 mirror_tint : source_color = vec3(0.86, 0.90, 0.93);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 世界空间法线（这面镜子朝 +X，但按传入的 NORMAL 走更通用）
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 view = normalize(world_pos - CAMERA_POSITION_WORLD);
	vec3 refl = reflect(view, n);

	// 屏幕 UV：用反射方向的 x/z 做一点偏移，读屏幕颜色
	// （不是严格的 SSR，但在这面朝向房间内部的镜子上读起来是对的）
	float d = distort * (sin(world_pos.y * 23.0) * 0.5 + sin(world_pos.z * 17.0) * 0.5);
	vec2 uv = SCREEN_UV + refl.xz * d;
	uv = clamp(uv, vec2(0.001), vec2(0.999));

	vec3 c = texture(screen_tex, uv).rgb;
	c *= mirror_tint * tint;

	// 边缘压暗（镜框的暗角），让镜子不像一块贴图
	vec2 e = abs(UV * 2.0 - 1.0);
	float vig = smoothstep(1.02, 0.72, max(e.x, e.y));
	c *= mix(0.55, 1.0, vig);

	ALBEDO = c;
}
