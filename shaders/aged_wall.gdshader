shader_type spatial;
render_mode diffuse_burley;
uniform float floor_y=0.0;
uniform vec4 lower_color:source_color=vec4(.50,.54,.46,1);
uniform vec4 upper_color:source_color=vec4(.69,.65,.55,1);
uniform sampler2D plaster_tex:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D tile_tex:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world_pos;
varying vec3 wall_normal;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;wall_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 float h=world_pos.y-floor_y;
 vec3 weights=pow(abs(wall_normal),vec3(6.));weights/=max(dot(weights,vec3(1.)),.001);
 vec3 p=texture(plaster_tex,world_pos.zy*.42).rgb*weights.x+texture(plaster_tex,world_pos.xz*.42).rgb*weights.y+texture(plaster_tex,world_pos.xy*.42).rgb*weights.z;
 vec3 t=texture(tile_tex,world_pos.zy*.70).rgb*weights.x+texture(tile_tex,world_pos.xz*.70).rgb*weights.y+texture(tile_tex,world_pos.xy*.70).rgb*weights.z;
 float upper=smoothstep(1.26,1.28,h);
 vec3 lower=mix(vec3(.47,.50,.43),t,.58)*lower_color.rgb*1.65;
 vec3 plaster=mix(vec3(.62),p,.65)*upper_color.rgb*1.45;
 vec3 c=mix(lower,plaster,upper);
 float border=1.-smoothstep(.012,.022,abs(h-1.275));c=mix(c,vec3(.16,.23,.20),border);
 c*=mix(.62,1.,smoothstep(.0,.20,h));
 ALBEDO=c;ROUGHNESS=mix(.66,.94,upper);
}
