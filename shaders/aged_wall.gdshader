shader_type spatial;
render_mode diffuse_burley;
uniform float floor_y=0.0;
uniform vec4 lower_color:source_color=vec4(.23,.32,.28,1);
uniform vec4 upper_color:source_color=vec4(.62,.63,.55,1);
varying vec3 world_pos;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1)),f.x),f.y),f.z);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float h=world_pos.y-floor_y;
 float broad=noise(world_pos*1.7),fine=noise(world_pos*44.);
 vec3 c=mix(lower_color.rgb,upper_color.rgb,smoothstep(1.19,1.21,h));
 c*=.95+.04*broad+.012*fine;
 c*=mix(.67,1.,smoothstep(0.,.22,h));
 ALBEDO=c;ROUGHNESS=.91;
}
