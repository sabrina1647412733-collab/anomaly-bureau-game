extends RefCounted
## Local field UI tokens. Deliberately not assigned to the window or update panels.
const PAPER := Color("e7dfcc")
const MUTED := Color("b0ac9f")
const BRASS := Color("c5a878")
const INK := Color("1b1d1c")
static func box(fill:=INK, edge:=Color.TRANSPARENT, radius:=3) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=fill;s.border_color=edge
	s.set_border_width_all(1 if edge.a>0 else 0);s.set_corner_radius_all(radius)
	return s
static func readable(label:Label,fs:int,color:=PAPER) -> void:
	label.add_theme_font_size_override("font_size",fs)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,.9))
	label.add_theme_constant_override("shadow_offset_y",2)
	label.add_theme_constant_override("outline_size",2)
	label.add_theme_color_override("font_outline_color",Color(0,0,0,.65))
	label.add_theme_constant_override("line_spacing",8)
static func gradient(parent:Control,top:=false) -> TextureRect:
	var image:=GradientTexture2D.new();image.width=4;image.height=256
	image.fill_from=Vector2.ZERO;image.fill_to=Vector2(0,1)
	var ramp:=Gradient.new()
	ramp.colors=PackedColorArray([Color(0,0,0,.84) if top else Color(0,0,0,0),Color(0,0,0,0) if top else Color(0,0,0,.88)])
	image.gradient=ramp
	var texture:=TextureRect.new();texture.texture=image;texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);parent.add_child(texture);parent.move_child(texture,0)
	return texture
static func button(b:Button,primary:=false) -> void:
	b.add_theme_font_size_override("font_size",22)
	b.add_theme_color_override("font_color",INK if primary else PAPER)
	b.add_theme_color_override("font_hover_color",INK if primary else PAPER)
	b.add_theme_color_override("font_focus_color",INK if primary else PAPER)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var fill:=BRASS if primary else Color("242821")
		if state in ["hover","focus"]:fill=fill.lightened(.12)
		if state=="pressed":fill=fill.darkened(.12)
		if state=="disabled":fill=Color("20231e")
		var s:=box(fill,BRASS if state=="focus" else Color.TRANSPARENT)
		s.content_margin_left=16;s.content_margin_right=16;s.content_margin_top=9;s.content_margin_bottom=9
		b.add_theme_stylebox_override(state,s)
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.focus_mode=Control.FOCUS_ALL
static func pages(value:String,font:Font,width:float,fs:int,max_lines:=2) -> Array[String]:
	# Pixel-measured, lossless segmentation; no truncation, ellipses or plot edits.
	var result:Array[String]=[];var page:="";var line:="";var count:=1
	for letter in value:
		var next_line:bool=letter=="\n" or font.get_string_size(line+letter,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>width
		if next_line:
			if count>=max_lines:
				result.append(page);page="";count=1
			else:count+=1
			line=""
		if letter!="\n":line+=letter
		page+=letter
	if not page.is_empty():result.append(page)
	if result.is_empty():result.append("")
	return result
