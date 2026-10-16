shader_type spatial;
render_mode cull_back, diffuse_lambert;
// 参考 render3d.js：平面着色 + 线性雾（8m 起压，46m 全吞）+ 反射率倍率 + 自发光面
// 2026-10-16：打开镜面高光（原来 specular_disabled，所有面都是死平的）；
//             粗糙度/金属度改为每个材质可调，让瓷砖、不锈钢、车体有光泽层次。
uniform vec3  albedo : source_color = vec3(0.05, 0.08, 0.11);
uniform vec3  tint = vec3(1.0, 1.0, 1.0);
uniform float reflectance = 1.0;            // 深色板不至于被光乘成全黑
uniform float roughness = 0.75;             // 0=镜面 1=全哑光
uniform float metallic = 0.0;
uniform float specular = 0.35;               // 高光强度（非金属材质用）
uniform vec3  emission_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float emission_energy = 0.0;
uniform vec3  fog_color : source_color = vec3(0.016, 0.024, 0.034);   // 淡蓝雾：远处是空气不是黑洞
uniform float fog_start = 16.0;
uniform float fog_end = 62.0;

varying vec3 wpos;

void vertex(){
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment(){
    vec3 base = albedo * tint * reflectance;
    ALBEDO = base;
    ROUGHNESS = clamp(roughness, 0.02, 1.0);
    METALLIC = clamp(metallic, 0.0, 1.0);
    SPECULAR = clamp(specular, 0.0, 1.0);
    EMISSION = emission_color * emission_energy * tint;

    float depth = distance(wpos, CAMERA_POSITION_WORLD);
    float f = clamp((depth - fog_start) / (fog_end - fog_start), 0.0, 1.0);
    f = f * f * (3.0 - 2.0 * f) * 0.98;
    ALBEDO = mix(ALBEDO, fog_color, f);
    EMISSION = mix(EMISSION, vec3(0.0), f);
}