shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform float wetness=0.8;
uniform float rain_amount=0.6;
uniform float weather_time=0.0;
uniform bool river=false;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 if(!river && wetness<0.22){discard;}
 vec2 p=world_pos.xz;
 vec2 q=fract(p*1.7)-0.5;
 float phase=fract(weather_time*.65+sin(dot(floor(p*1.7),vec2(12.4,74.8)))*24.);
 float ring=sin((length(q)-phase*.65)*70.)*exp(-abs(length(q)-phase*.65)*23.)*(1.-phase);
 float ripple=ring*rain_amount*0.025;
 vec3 cold=vec3(.10,.145,.165);
 ALBEDO=cold+vec3(.025,.032,.035)*(sin(p.x*.8+p.y*.4)*.5+.5);
 ROUGHNESS=river?.26:.12;
 METALLIC=.32;
 NORMAL=normalize(NORMAL+vec3(sin(p.x*9.+weather_time*1.6)*.012+ripple,0.,cos(p.y*11.+weather_time*1.3)*.012+ripple));
 SPECULAR=.65;
 ALPHA=river?1.0:COLOR.a*clamp((wetness-.18)*1.4,0.0,.65);
}
