shader_type spatial;
uniform sampler2D floor_tex:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rough_tex:filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 tint:source_color=vec4(.65,.67,.6,1);
uniform float scale_uv=0.6;
uniform bool shop_wear=false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.)).xyz);}
void fragment(){
 vec3 floor_color=texture(floor_tex,world_position.xz*scale_uv).rgb*tint.rgb;
 float underside=step(world_normal.y,-.4);
 float wear=sin(world_position.x*3.1)*sin(world_position.z*2.7)*.015;
 float rough=clamp(texture(rough_tex,world_position.xz*scale_uv).r*.40+.47,.5,.94);
 float damp=1.-smoothstep(.0,.7,length((world_position.xz-vec2(2.35,4.1))*vec2(1.,.6)));
 if (shop_wear && world_normal.y > 0.5) {
  vec2 p = world_position.xz;
  // Gradual worn paths from the entrance to the aisle, and old moisture along the service drain.
  float use_path = p.x - (0.12 + smoothstep(6.0,10.0,p.y)*1.35);
  float traffic = (1.0-smoothstep(.14,1.15,abs(use_path))) * smoothstep(2.5,4.5,p.y);
  float edge = 1.0-smoothstep(.04,.39,3.2-abs(p.x));
  float variation = sin(p.x*6.1+p.y*4.2)*sin(p.y*7.9-p.x*3.2);
  float drain = (1.0-smoothstep(.04,.55,abs(p.y-2.04+variation*.09))) *
      (1.0-smoothstep(2.35,3.05,abs(p.x)));
  floor_color *= 1.0 + .11*traffic - .16*edge - .22*drain;
  rough -= .055*traffic + .17*drain;
 }
 ALBEDO=mix(floor_color,vec3(.32,.34,.30)+wear,underside);
 ROUGHNESS=mix(clamp(rough-damp*.15,.3,.95),.95,underside);
}
