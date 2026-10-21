extends Control
## 固定像素大小的空心菱形，避免世界空间大字挡住物件。
var caption: Label
func setup(font: Font) -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption=Label.new();caption.add_theme_font_override("font",font)
	caption.add_theme_font_size_override("font_size",15)
	caption.add_theme_color_override("font_color",Color("e4c58a"))
	caption.add_theme_color_override("font_shadow_color",Color(0,0,0,.95))
	caption.add_theme_constant_override("shadow_offset_x",1);caption.add_theme_constant_override("shadow_offset_y",2)
	caption.position=Vector2(14,-12);caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(caption)
func _draw() -> void:
	var points=PackedVector2Array([Vector2(0,-9),Vector2(7,0),Vector2(0,9),Vector2(-7,0),Vector2(0,-9)])
	draw_polyline(points,Color(0,0,0,.85),4,true)
	draw_polyline(points,Color("e4c58a"),1.5,true)
	draw_line(Vector2(0,12),Vector2(0,21),Color("e4c58a"),1.2,true)
