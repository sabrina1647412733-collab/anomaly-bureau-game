extends Control
## 回潮镇地图：同一份 town-layout.json 驱动地标与道路。

var layout: Dictionary = {}
var player_local := Vector2.ZERO
var big_open := false
var first_hint := true
var map_font: Font
var player_yaw := 0.0
var target_id := "01"
var intuition_id := "01"
var intuition_text := "洗衣店附近有异常"

func set_intuition(id: String, text: String) -> void:
	if intuition_id==id and intuition_text==text:return
	intuition_id=id;intuition_text=text;queue_redraw()

func target_name() -> String:
	for place in layout.get("landmarks",[]):
		if String(place.get("id",""))==target_id:return String(place.get("name","目标地点"))
	return "目标地点"

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
	_draw_context(center,scale,true)
	_draw_roads(center, scale, true)
	_draw_markers(center, scale, true)
	draw_circle(center, 5.5, Color(0.97, 0.92, 0.69))
	draw_arc(center, 9.0, 0.0, TAU, 24, Color(0.97, 0.92, 0.69), 1.5)
	_arrow(center)
	_label("许砚 · 当前位置", frame.position + Vector2(8, 19), 16, Color(0.95, 0.90, 0.72))
	_label("M  全镇地图", frame.position + Vector2(8, frame.size.y - 8), 13, Color(0.70, 0.83, 0.78))
	_label("目标："+target_name(),Vector2(size.x-260,326),15,Color("e2bd7f"))
	if first_hint and not intuition_text.is_empty():
		_label("直觉："+intuition_text, Vector2(size.x - 300, 349), 14, Color(0.78, 0.88, 0.73))

func _draw_big() -> void:
	var outer := Rect2(Vector2(56, 42), size - Vector2(112, 84))
	draw_rect(outer, Color(0.025, 0.048, 0.053, 0.97), true)
	draw_rect(outer, Color(0.63, 0.49, 0.27), false, 2.0)
	var scale := minf((outer.size.x - 120.0) / 300.0, (outer.size.y - 120.0) / 240.0)
	var center := outer.get_center()
	_draw_context(center,scale,false)
	_draw_roads(center, scale, false)
	_draw_markers(center, scale, false)
	var here := _point(player_local, center, scale, false)
	draw_circle(here, 7.0, Color(0.98, 0.88, 0.58))
	draw_arc(here, 12.0, 0.0, TAU, 24, Color(0.98, 0.88, 0.58), 1.5)
	_arrow(here)
	_label("回潮镇  ·  全镇地图", outer.position + Vector2(22, 31), 23, Color(0.93, 0.87, 0.69))
	_label("▲ 你的位置与朝向     ◆ 当前目标：%s     ○ 直觉区域" % target_name(), outer.position + Vector2(22, 56), 16, Color(0.74, 0.87, 0.79))
	_label("浅灰为建筑轮廓 · 蓝色为河道 · 亮色为桥与道路；封闭民居不表示可以进入。",outer.position+Vector2(22,outer.size.y-18),14,Color("8fa7a0"))
	_label("M 关闭地图", outer.end - Vector2(145, 15), 15, Color(0.74, 0.87, 0.79))

func _point(world: Vector2, center: Vector2, scale: float, small: bool) -> Vector2:
	var origin := player_local if small else Vector2(150, 120)
	return center + (world - origin) * scale

func _frame(small:bool)->Rect2:
	return Rect2(Vector2(size.x-260,78),Vector2(224,224)) if small else Rect2(Vector2(80,120),size-Vector2(160,225))

func _line(a:Vector2,b:Vector2,tint:Color,width:float,small:bool)->void:
	var clipped:=_clip_segment(a,b,_frame(small))
	if clipped.size()==2:draw_line(clipped[0],clipped[1],tint,width,true)

func _footprint(entry:Dictionary,center:Vector2,scale:float,small:bool,tint:Color)->void:
	var yaw:=float(entry.get("rot",0.));var c:=cos(yaw);var s:=sin(yaw)
	var at:=Vector2(float(entry.get("x",0.)),float(entry.get("z",0.)))
	var half:=Vector2(float(entry.get("w",5.)),float(entry.get("d",5.)))*.5
	var polygon:=PackedVector2Array()
	for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var p:Vector2=corner*half
		polygon.append(_point(at+Vector2(c*p.x+s*p.y,-s*p.x+c*p.y),center,scale,small))
	var frame:=_frame(small)
	var mask:=PackedVector2Array([frame.position,Vector2(frame.end.x,frame.position.y),frame.end,Vector2(frame.position.x,frame.end.y)])
	for clipped in Geometry2D.intersect_polygons(polygon,mask):
		var clean:=PackedVector2Array()
		for point in clipped:
			if clean.is_empty() or clean[clean.size()-1].distance_squared_to(point)>.0004:clean.append(point)
		if clean.size()>2 and clean[0].distance_squared_to(clean[clean.size()-1])<.0004:clean.resize(clean.size()-1)
		if clean.size()<3:continue
		var area:=0.
		for i in range(clean.size()):area+=clean[i].cross(clean[(i+1)%clean.size()])
		# Clipping a facade at the map border may leave an edge or a sub-pixel
		# sliver. Do not send that degenerate polygon to the renderer.
		if absf(area)>.5 and Geometry2D.triangulate_polygon(clean).size()>=3:draw_colored_polygon(clean,tint)

func _draw_context(center:Vector2,scale:float,small:bool)->void:
	var river:Dictionary=layout.get("river",{})
	var raw:Array=river.get("points",[])
	for i in range(raw.size()-1):
		_line(_point(Vector2(raw[i][0],raw[i][1]),center,scale,small),_point(Vector2(raw[i+1][0],raw[i+1][1]),center,scale,small),Color("20434e"),float(river.get("width",11.))*scale,small)
	for building in layout.get("buildings",[]):_footprint(building,center,scale,small,Color("344846"))
	for place in layout.get("landmarks",[]):
		if String(place.get("id","")) not in ["04","08","10"]:_footprint(place,center,scale,small,Color("4a5b52"))
	for bridge in layout.get("bridges",[]):
		var a:Array=bridge.get("from",[]);var b:Array=bridge.get("to",[])
		if a.size()==2 and b.size()==2:_line(_point(Vector2(a[0],a[1]),center,scale,small),_point(Vector2(b[0],b[1]),center,scale,small),Color("c3ae7b"),maxf(2.,float(bridge.get("width",3.))*scale*.6),small)

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
		var target := String(place.get("id", "")) == target_id
		if small and not _frame(true).grow(-14).has_point(p):
			if target:
				var offset:=p-center
				var edge:=center+offset*(92./maxf(absf(offset.x),absf(offset.y)))
				var direction:=offset.normalized();var side:=direction.orthogonal()
				draw_colored_polygon(PackedVector2Array([edge+direction*7,edge-direction*5+side*5,edge-direction*5-side*5]),Color("edba73"))
			continue
		draw_circle(p, 4.5 if target else 2.5, Color(0.95, 0.67, 0.31) if target else Color(0.59, 0.77, 0.73))
		if target:
			draw_arc(p, 12.0 if small else 16.0, 0.0, TAU, 28, Color(0.67, 0.83, 0.50, 0.9), 2.0)
		if String(place.get("id",""))==intuition_id and not target:
			draw_arc(p,12.0 if small else 16.0,0.0,TAU,28,Color(.67,.83,.50,.65),1.0)
		if not small:
			_label(String(place.get("name", "")), p + Vector2(7, -7), 13, Color(0.89, 0.91, 0.83))

func _label(value: String, where: Vector2, font_size: int, color: Color) -> void:
	if map_font != null:
		draw_string(map_font, where, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
