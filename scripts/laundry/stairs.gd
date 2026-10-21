extends RefCounted
## 1F ↔ 2F ↔ 3F 的楼梯间（竖井的两段）
## 从门厅南墙洞口 (z=16, y=0) 升到 2F 地面 (y=3.5)，20 级，落在洗衣店门口的平台上。

const A := preload("res://scripts/laundry/laundry_art.gd")

const X0 := 0.30
const X1 := 2.80
const ZB := 16.00      # 梯段底
const ZT := 11.00      # 梯段顶
const FT := 3.50       # 2F 地面
const RUN := 0.25
const RISE := 0.175
const N := 20

var a: LaundryArt

func _init(art: LaundryArt) -> void:
	a = art

func build() -> void:
	_steps()
	_landing()
	_enclosure()
	_details()
	_steps2()
	_landing2()
	_enclosure2()

func _steps() -> void:
	var conc := a.pbr("chipped_concrete", 0.9, Color(0.58, 0.57, 0.54), 1.0)
	var tread := a.plain(Color(0.30, 0.30, 0.29), 0.95)
	var cx := 0.91
	for i in range(N):
		var z := ZB - (float(i) + 0.5) * RUN
		var h := float(i + 1) * RISE
		a.box(Vector3(cx, h * 0.5, z), Vector3(1.14, h, RUN), conc, true)
		# 踏步前缘的防滑条
		a.box(Vector3(cx, h - 0.008, z + RUN * 0.42), Vector3(1.14 - 0.10, 0.016, 0.05), tread)

func _landing() -> void:
	var conc := a.pbr("chipped_concrete", 0.9, Color(0.56, 0.55, 0.52), 1.0)
	# 2F 平台：洗衣店门口
	a.box(Vector3(0.10, FT - 0.11, 10.55), Vector3(6.2, 0.22, 0.90), conc, true)
	a.box(Vector3(0.10, FT - 0.11, 11.00), Vector3(6.2, 0.22, 0.10), conc, false)
	# 平台与楼梯之间的收口
	a.box(Vector3((X0 + X1) * 0.5, FT - 0.11, ZT + 0.10), Vector3(X1 - X0, 0.22, 0.20), conc, false)

func _enclosure() -> void:
	var wall := a.pbr("grey_plaster_02", 0.32, Color(0.78, 0.77, 0.73), 1.0, 0.0, 0.55)
	# 楼梯间两侧的墙：从 1F 一直到 2F 上面
	a.box(Vector3(X0 - 0.09, 2.10, 13.50), Vector3(0.18, 4.20, 5.20), wall, true)
	a.box(Vector3(X1 + 0.09, 2.10, 13.50), Vector3(0.18, 4.20, 5.20), wall, true)
	# 2F 平台北侧的墙（洗衣店南墙已有，这里补平台侧边）
	a.box(Vector3(3.10, 2.10, 13.50), Vector3(0.20, 4.20, 5.20), wall, false)

func _details() -> void:
	# 圆管扶手：沿梯段斜率
	var rail := a.plain(Color(0.42, 0.36, 0.28), 0.45, 0.6)
	var z0 := ZB
	var z1 := ZT
	var y0 := 0.95
	var y1 := FT + 0.95
	var mid := Vector3(X1 - 0.06, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	var len := Vector2(z1 - z0, y1 - y0).length()
	var rr := a.cyl(mid, 0.026, len, rail, 10, "x")
	rr.rotation = Vector3(0, 0, 0)
	rr.look_at_from_position(mid, Vector3(mid.x, y1, z1), Vector3.UP)
	rr.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	# 立柱
	for i in range(5):
		var t := float(i) / 4.0
		var zz: float = lerpf(z0, z1, t)
		var yy: float = lerpf(y0, y1, t)
		a.cyl(Vector3(X1 - 0.06, yy - 0.45, zz), 0.020, 0.90, rail, 8)

	# 墙上的铅笔身高线：秀兰 1.32（剧本第 6 条交互）
	var pencil := a.plain(Color(0.60, 0.58, 0.52), 0.9)
	a.box(Vector3(X1 - 0.005, 1.32, 12.60), Vector3(0.006, 0.012, 0.36), pencil)
	a.label("秀兰 1.32", Vector3(X1 - 0.02, 1.22, 12.95), 0.06, Color(0.66, 0.64, 0.58), -PI * 0.5)
	# 更早的几条刻线
	for i in range(4):
		var y: float = 0.86 + 0.12 * i
		a.box(Vector3(X1 - 0.005, y, 12.30 + 0.05 * i), Vector3(0.006, 0.010, 0.20), pencil)

	# 楼梯间唯一的灯：一盏快要坏的声控灯
	a.box(Vector3(1.55, 3.28, 13.60), Vector3(0.26, 0.06, 0.26), a.plain(Color(0.20, 0.20, 0.20), 0.6))
	a.box(Vector3(1.55, 3.24, 13.60), Vector3(0.22, 0.03, 0.22), a.emit(Color(1.0, 0.82, 0.58), 1.2))
	a.omni(Vector3(1.55, 3.10, 13.60), Color(1.0, 0.76, 0.50), 2.2, 7.0, true)


# ------------------------------------------------------------------ 第二段：2F → 3F
const FT2 := 6.90

func _steps2() -> void:
	# 从 2F 平台 (z=11.0, y=3.5) 上到 3F (y=6.9)，落在 z=16.0 那端的 3F 平台。
	# **注意**：这一段原本从 z=11 往 −Z 走到 z=6，等于把梯段铺进 2F 店堂
	# （店堂 z 1.9…10.1）—— 店堂中间会凭空出现两堵墙和一片混凝土楼板。
	# 现在改为**在竖井内**从 z=11.0 往 +Z 走到 z=16.0（与 1F→2F 同一竖直通道）。
	var conc := a.pbr("chipped_concrete", 0.9, Color(0.56, 0.55, 0.52), 1.0)
	var tread := a.plain(Color(0.30, 0.30, 0.29), 0.95)
	var cx := 2.19
	var zb := 11.00
	var zt := 16.00
	var run := (zt - zb) / float(N)
	for i in range(N):
		var z := zb + (float(i) + 0.5) * run
		var h := FT + float(i + 1) * (FT2 - FT) / float(N)
		a.box(Vector3(cx, (FT + h) * 0.5, z), Vector3(1.14, h - FT, run), conc, true)
		a.box(Vector3(cx, h - 0.008, z), Vector3(1.14 - 0.10, 0.016, 0.05), tread)

func _landing2() -> void:
	var conc := a.pbr("chipped_concrete", 0.9, Color(0.56, 0.55, 0.52), 1.0)
	# 3F 平台：放在竖井南端（z≈16.4），宽度**只在竖井内**（x 0.30…2.80）。
	# 原来是一块 6.2 m 宽、横跨全楼、z=5.2 的混凝土板 —— 它正压着 2F 店堂。
	a.box(Vector3((X0 + X1) * 0.5, FT2 - 0.12, 16.40),
		Vector3(X1 - X0, 0.24, 1.60), conc, true)

func _enclosure2() -> void:
	var wall := a.pbr("grey_plaster_02", 0.32, Color(0.78, 0.77, 0.73), 1.0, 0.0, 0.55)
	# 第二段的侧墙：只在竖井里（z 11.0…17.2），**不能伸进 2F 店堂**
	# 南端给 3F 回廊留侧向出口。
	a.box(Vector3(X0 - 0.09, 5.35, 13.25), Vector3(0.18, 3.4, 4.50), wall, true)
	a.box(Vector3(X1 + 0.09, 5.35, 14.10), Vector3(0.18, 3.4, 6.20), wall, true)
	# 楼梯间灯（第二段）
	a.box(Vector3(1.55, 6.60, 13.60), Vector3(0.24, 0.05, 0.24), a.plain(Color(0.20, 0.20, 0.20), 0.6))
	a.omni(Vector3(1.55, 6.40, 13.60), Color(1.0, 0.78, 0.54), 1.8, 6.0, true)
