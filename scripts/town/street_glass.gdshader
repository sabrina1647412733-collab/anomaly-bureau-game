shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color=vec4(.12,.18,.19,1.);
uniform float lit=0.0;
uniform float daylight=0.0;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
float noise2(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(fract(sin(dot(i,vec2(12.7,71.3)))*437.2),fract(sin(dot(i+vec2(1.,0.),vec2(12.7,71.3)))*437.2),f.x),
 mix(fract(sin(dot(i+vec2(0.,1.),vec2(12.7,71.3)))*437.2),fract(sin(dot(i+vec2(1.),vec2(12.7,71.3)))*437.2),f.x),f.y);
}
void fragment(){
 float horizontal=mix(world_pos.x,world_pos.z,step(abs(world_normal.z),abs(world_normal.x)));
 vec2 p=vec2(horizontal,world_pos.y);
 float dirt=noise2(p*7.)*.13+noise2(p*1.4)*.17;
 float fold=.78+sin(horizontal*35.)*.06+sin(horizontal*11.)*.05;
 vec3 surface=tint.rgb*(fold-dirt);
 ALBEDO=surface;ROUGHNESS=.24+dirt*.6;METALLIC=.13;SPECULAR=.65;
 EMISSION=surface*lit*(1.-daylight)*(.21+noise2(p*2.)*.17);
}
