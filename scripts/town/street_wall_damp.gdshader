shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
// Small geometry patches are authored under sill corners. Their UVs are not
// required; alpha softens the physical patch without inventing full-wall grime.
uniform float wetness = 0.0;
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
	ALPHA = COLOR.a * (0.62 + wetness * 0.24);
}
