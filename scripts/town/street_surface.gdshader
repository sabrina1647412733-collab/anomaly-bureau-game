shader_type spatial;
render_mode cull_disabled;
uniform sampler2D base_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tex_scale = 0.5;
uniform float base_roughness = 0.9;
uniform float metalness = 0.0;
uniform float normal_strength = 0.25;
uniform float wetness = 0.0;
uniform float wet_response = 0.4;
uniform float emission_strength = 0.0;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex(){
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
vec4 tri(sampler2D tex, vec3 p, vec3 w){
 return texture(tex,p.zy)*w.x+texture(tex,p.xz)*w.y+texture(tex,p.xy)*w.z;
}
void fragment(){
 vec3 n=normalize(world_normal);
 vec3 w=pow(abs(n),vec3(5.0));w/=max(dot(w,vec3(1.0)),0.001);
 vec3 p=world_pos*tex_scale;
 vec3 base=tri(base_tex,p,w).rgb*tint.rgb*COLOR.rgb;
 float damp=wetness*wet_response;
 ALBEDO=base*(1.0-damp*0.23);
 ROUGHNESS=clamp(tri(rough_tex,p,w).r*base_roughness-damp*0.37,0.18,1.0);
 METALLIC=metalness;
 vec3 nx=texture(normal_tex,p.zy).xyz*2.0-1.0;
 vec3 ny=texture(normal_tex,p.xz).xyz*2.0-1.0;
 vec3 nz=texture(normal_tex,p.xy).xyz*2.0-1.0;
 vec3 bumped=normalize(vec3(nx.z*sign(n.x),nx.y,nx.x)*w.x+vec3(ny.x,ny.z*sign(n.y),ny.y)*w.y+vec3(nz.x,nz.y,nz.z*sign(n.z))*w.z);
 NORMAL=normalize(mix(NORMAL,(VIEW_MATRIX*vec4(bumped,0.0)).xyz,normal_strength));
 EMISSION=base*emission_strength;
}
