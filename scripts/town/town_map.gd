extends Control
## 回潮镇地图：同一份 town-layout.json 驱动地标与道路。

var layout: Dictionary = {}
var player_local := Vector2.ZERO
var big_open := false
var first_hint := true
var map_font: Font
var player_yaw := 0.0
var target_id := "01"

func set_navigation(yaw: float, target: String) -> void:
	if absf(yaw-player_yaw)>.01 or target_id!=target:
		player_yaw = yaw
		target_id = target
		queue_redraw()

func _arrow(at: Vector2) -> void:
	var direction := Vector2(-sin(player_yaw),-cos(player_yaw))
	var side := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([at+direction*15,at-direction*7+side*6,at-direction*7-side*6]),Color("fff0b0"))

func setup(data: Dictionary, font: Font) -> void:
	layout = data
	map_font = font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func set_player_position(world_local: Vector3) -> void:
	var next_position := Vector2(world_local.x, world_local.z)
	if player_local.distance_squared_to(next_position) > 0.0025:
		player_local = next_position
		queue_redraw()

func toggle_big() -> void:
	big_open = not big_open
	first_hint = false
	queue_redraw()

func _draw() -> void:
	if layout.is_empty():
		return
	if big_open:
		_draw_big()
	else:
		_draw_small()

func _draw_small() -> void:
	var frame := Rect2(Vector2(size.x - 260.0, 78.0), Vector2(224, 224))
	draw_rect(frame.grow(5.0), Color(0.65, 0.51, 0.27, 0.85), false, 2.0)
	draw_rect(frame, Color(0.027, 0.060, 0.066, 0.91), true)
	var center := frame.get_center()
	var scale := 3.0
	_draw_roads(center, scale, true)
	_draw_markers(center, scale, true)
	draw_circle(center, 5.5, Color(0.97, 0.92, 0.69))
	draw_arc(center, 9.0, 0.0, TAU, 24, Color(0.97, 0.92, 0.69), 1.5)
	_arrow(center)
	_label("许砚 · 当前位置", frame.position + Vector2(8, 19), 16, Color(0.95, 0.90, 0.72))
	_label("M  全镇地图", frame.position + Vector2(8, frame.size.y - 8), 13, Color(0.70, 0.83, 0.78))
	if first_hint:
		_label("直觉：洗衣店附近有异常", Vector2(size.x - 320, 328), 16, Color(0.78, 0.88, 0.73))

func _draw_big() -> void:
	var outer := Rect2(Vector2(56, 42), size - Vector2(112, 84))
	draw_rect(outer, Color(0.025, 0.048, 0.053, 0.97), true)
	draw_rect(outer, Color(0.63, 0.49, 0.27), false, 2.0)
	var scale := minf((outer.size.x - 120.0) / 300.0, (outer.size.y - 120.0) / 240.0)
	var center := outer.get_center()
	_draw_roads(center, scale, false)
	_draw_markers(center, scale, false)
	var here := _point(player_local, center, scale, false)
	draw_circle(here, 7.0, Color(0.98, 0.88, 0.58))
	draw_arc(here, 12.0, 0.0, TAU, 24, Color(0.98, 0.88, 0.58), 1.5)
	_arrow(here)
	_label("回潮镇  ·  全镇地图", outer.position + Vector2(22, 31), 23, Color(0.93, 0.87, 0.69))
	_label("▲ 你的位置与朝向     ◆ 当前目标：%s     ○ 直觉区域" % ("出租公寓" if target_id=="02" else "得利洗衣店"), outer.position + Vector2(22, 56), 16, Color(0.74, 0.87, 0.79))
	_label("M 关闭地图", outer.end - Vector2(145, 15), 15, Color(0.74, 0.87, 0.79))

func _point(world: Vector2, center: Vector2, scale: float, small: bool) -> Vector2:
	var origin := player_local if small else Vector2(150, 120)
	return center + (world - origin) * scale

func _draw_roads(center: Vector2, scale: float, small: bool) -> void:
	for road in layout.get("roads", []):
		var points: PackedVector2Array = []
		for raw in road.get("points", []):
			points.append(_point(Vector2(float(raw[0]), float(raw[1])), center, scale, small))
		if points.size() >= 2:
			var tint := Color(0.32, 0.44, 0.42, 0.9)
			var width := maxf(1.2, float(road.get("width", 2.0)) * scale * 0.28)
			if small:
				var frame := Rect2(Vector2(size.x - 260.0, 78.0), Vector2(224, 224))
				for i in range(points.size() - 1):
					var segment := _clip_segment(points[i], points[i + 1], frame)
					if segment.size() == 2:
						draw_line(segment[0], segment[1], tint, width, true)
			else:
				draw_polyline(points, tint, width, true)

func _clip_segment(a: Vector2, b: Vector2, frame: Rect2) -> Array[Vector2]:
	var delta := b - a
	var p := [-delta.x, delta.x, -delta.y, delta.y]
	var q := [a.x - frame.position.x, frame.end.x - a.x, a.y - frame.position.y, frame.end.y - a.y]
	var first := 0.0
	var last := 1.0
	for i in range(4):
		var pi: float = p[i]
		var qi: float = q[i]
		if absf(pi) < 0.000001:
			if qi < 0.0:
				return []
		elif pi < 0.0:
			first = maxf(first, qi / pi)
		else:
			last = minf(last, qi / pi)
		if first > last:
			return []
	return [a + delta * first, a + delta * last]

func _draw_markers(center: Vector2, scale: float, small: bool) -> void:
	for place in layout.get("landmarks", []):
		var raw_front: Array = place.get("front", [place.get("x", 0.0), place.get("z", 0.0)])
		var p := _point(Vector2(float(raw_front[0]), float(raw_front[1])), center, scale, small)
		if small and (p.x < size.x - 260.0 or p.x > size.x - 36.0 or p.y < 78.0 or p.y > 302.0):
			continue
		var target := String(place.get("id", "")) == target_id
		draw_circle(p, 4.5 if target else 2.5, Color(0.95, 0.67, 0.31) if target else Color(0.59, 0.77, 0.73))
		if target:
			draw_arc(p, 12.0 if small else 16.0, 0.0, TAU, 28, Color(0.67, 0.83, 0.50, 0.9), 2.0)
		if String(place.get("id",""))=="01" and not target:
			draw_arc(p,12.0 if small else 16.0,0.0,TAU,28,Color(.67,.83,.50,.65),1.0)
		if not small:
			_label(String(place.get("name", "")), p + Vector2(7, -7), 13, Color(0.89, 0.91, 0.83))

func _label(value: String, where: Vector2, font_size: int, color: Color) -> void:
	if map_font != null:
		draw_string(map_font, where, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
