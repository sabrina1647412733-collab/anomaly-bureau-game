shader_type spatial;
render_mode cull_back, diffuse_lambert;
// 玻璃 / 亚克力面板：在 surface.gdshader 基础上加 ALPHA，只有玻璃类材质用它，
// 这样柜门观察窗、售货机橱窗、广播台观察窗后面的东西才看得见。
// 2026-10-16：掠射角自动变不透明（Fresnel），玻璃边缘因此有厚度感，不像一张平纸。
uniform vec3  albedo : source_color = vec3(0.12, 0.18, 0.22);
uniform vec3  tint = vec3(1.0, 1.0, 1.0);
uniform float reflectance = 1.0;
uniform float roughness = 0.06;
uniform float metallic = 0.06;
uniform float specular = 0.80;
uniform float alpha = 0.34;                 // 正视时的透明度
uniform vec3  emission_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float emission_energy = 0.0;
uniform vec3  fog_color : source_color = vec3(0.016, 0.024, 0.034);
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

    float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
    ALPHA = clamp(alpha + fres * 0.45, 0.0, 1.0);
}
