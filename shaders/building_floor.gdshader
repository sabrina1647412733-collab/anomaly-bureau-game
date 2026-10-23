shader_type spatial;
uniform sampler2D floor_tex:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rough_tex:filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 tint:source_color=vec4(.65,.67,.6,1);
uniform float scale_uv=0.6;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.)).xyz);}
void fragment(){
 vec3 floor_color=texture(floor_tex,world_position.xz*scale_uv).rgb*tint.rgb;
 float underside=step(world_normal.y,-.4);
 float wear=sin(world_position.x*3.1)*sin(world_position.z*2.7)*.015;
 ALBEDO=mix(floor_color,vec3(.32,.34,.30)+wear,underside);
 float rough=clamp(texture(rough_tex,world_position.xz*scale_uv).r*.40+.47,.5,.94);
 float damp=1.-smoothstep(.0,.7,length((world_position.xz-vec2(2.35,4.1))*vec2(1.,.6)));
 ROUGHNESS=mix(rough-damp*.15,.95,underside);
}
