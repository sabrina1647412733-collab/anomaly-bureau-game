extends Control
var item_id := ""
const INK := Color("cadbcf")
func _draw() -> void:
	match item_id:
		"phone":
			draw_style_box(frame(),Rect2(17,3,28,49))
			draw_line(Vector2(25,9),Vector2(37,9),INK,2)
			draw_circle(Vector2(31,46),2,INK)
		"envelope":
			draw_style_box(frame(),Rect2(4,13,54,34))
			draw_polyline(PackedVector2Array([Vector2(5,14),Vector2(31,33),Vector2(57,14)]),INK,2,true)
		"weird_clock":
			draw_arc(Vector2(31,27),23,0,TAU,40,Color("d0b76f"),3,true)
			draw_polyline(PackedVector2Array([Vector2(31,11),Vector2(31,27),Vector2(43,31)]),INK,3,true)
			draw_line(Vector2(10,54),Vector2(52,54),INK,3)
		_:
			if "key" in item_id:
				draw_arc(Vector2(19,21),10,0,TAU,24,INK,3,true)
				draw_line(Vector2(26,28),Vector2(48,50),INK,4)
				draw_line(Vector2(39,41),Vector2(46,35),INK,3)
			elif item_id in ["hoodie","sweater"]:
				draw_polyline(PackedVector2Array([Vector2(21,8),Vector2(8,16),Vector2(2,32),Vector2(14,37),Vector2(18,28),Vector2(18,53),Vector2(46,53),Vector2(46,28),Vector2(50,37),Vector2(62,32),Vector2(55,16),Vector2(42,8),Vector2(35,17),Vector2(28,17),Vector2(21,8)]),INK,2,true)
			else:
				draw_style_box(frame(),Rect2(9,11,46,37))
				draw_line(Vector2(16,23),Vector2(46,23),INK,2)
				draw_line(Vector2(16,33),Vector2(36,33),INK,2)
func frame() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0,0,0,0)
	style.border_color = INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style
