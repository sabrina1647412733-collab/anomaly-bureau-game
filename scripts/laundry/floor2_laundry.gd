extends RefCounted
## 区域 2 ｜ 2F · 得利洗衣店（店堂 6.4 × 8.2 × 3.1）
## 完全照 v1 第 5-1 ~ 5-6 节的局部坐标：地面中心 (0,0,0)，南墙 z=+4.10 是入口。
## 本工程把它放在世界 (0, Y0, ZC)：2F 地面 y = 3.5。
##
## 五个灯按 5-5 那张表，唯一的"错的光源"是 7 号机里的绿。

const A := preload("res://scripts/laundry/laundry_art.gd")

const Y0 := 3.5          # 2F 地面标高
const ZC := 6.0          # 洗衣店局部原点在世界 z 的位置
const HX := 3.2          # 半宽
const HZ := 4.10         # 半长（局部 −4.10 … +4.10）
const HH := 3.10         # 净高

var a: LaundryArt
var m_floor: StandardMaterial3D
var m_tile_w: StandardMaterial3D
var m_paint: StandardMaterial3D
var m_ceil: StandardMaterial3D
var m_steel: StandardMaterial3D
var m_enamel: StandardMaterial3D
var m_enamel_old: StandardMaterial3D
var m_glass: StandardMaterial3D
var m_drum: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_blue: StandardMaterial3D
var m_wood: StandardMaterial3D
var m_mirror: StandardMaterial3D
## 真镜面材质（缓存在材质字典里，别每次重建）
func _mirror_mat() -> ShaderMaterial:
	var key := "mirror_screen"
	if a.mats.has(key):
		return a.mats[key]
	var sh: Shader = load("res://shaders/mirror_screen.gdshader")
	var m := ShaderMaterial.new()
	if sh != null:
		m.shader = sh
	a.mats[key] = m
	return m
var drums: Dictionary = {}
var doors: Dictionary = {}
var sweater: Node3D = null

func _init(art: LaundryArt) -> void:
	a = art

## 局部坐标 → 世界坐标
func w(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, Y0 + y, ZC + z)

func build() -> void:
	_materials()
	_shell()
	_machines()
	_furniture()
	_lights()

# ------------------------------------------------------------------ 材质
func _materials() -> void:
	m_floor = a.tile_mat(0.30, Color(0.64, 0.65, 0.59), Color(0.33, 0.35, 0.30), 2)
	m_tile_w = a.pbr("long_white_tiles", 0.50, Color(0.84, 0.84, 0.82), 0.85, 0.0, 0.7)
	m_paint = a.plain(Color(0.66, 0.72, 0.64), 0.88)
	m_ceil = a.plain(Color(0.93, 0.92, 0.89), 0.95)
	m_steel = a.pbr("metal_plate", 1.6, Color(0.80, 0.81, 0.82), 0.9, 0.7)
	m_enamel = a.plain(Color(0.88, 0.88, 0.86), 0.30, 0.10)
	m_enamel_old = a.plain(Color(0.82, 0.77, 0.62), 0.46, 0.10)
	m_glass = a.glass(Color(0.60, 0.66, 0.66, 0.10))
	m_drum = a.plain(Color(0.52, 0.54, 0.56), 0.22, 0.85)
	m_dark = a.plain(Color(0.06, 0.06, 0.07), 0.9)
	m_blue = a.plain(Color(0.13, 0.24, 0.42), 0.62, 0.02)
	m_wood = a.pbr("old_linoleum_flooring_01", 1.2, Color(0.58, 0.48, 0.36), 1.0)
	m_mirror = a.plain(Color(0.90, 0.92, 0.94), 0.015, 1.0)

# ------------------------------------------------------------------ 壳体
func _shell() -> void:
	var fw := HX * 2.0
	var fd := HZ * 2.0
	# 地面 / 天花
	a.quad_xz(-HX, ZC - HZ, HX, ZC + HZ, Y0, m_floor)
	a.quad_xz(-HX, ZC - HZ, HX, ZC + HZ, Y0 + HH, m_ceil, false)
	a.col(w(0, -0.15, 0), Vector3(fw, 0.3, fd))

	# 四面墙：下 2.2 m 白瓷砖，以上浅绿漆
	var walls := [
		[Vector3(-HX - 0.06, 0, 0), Vector3(0.12, HH, fd), 0.0],   # 西
		[Vector3(HX + 0.06, 0, 0), Vector3(0.12, HH, fd), 0.0],    # 东
		[Vector3(-2.43, 0, -HZ - 0.06), Vector3(1.55, HH, 0.12), 0.0],   # 北（西段）
		[Vector3(1.23, 0, -HZ - 0.06), Vector3(3.95, HH, 0.12), 0.0],    # 北（东段）
		[Vector3(-2.25, 0, HZ + 0.06), Vector3(1.90, HH, 0.12), 0.0],
		[Vector3(2.25, 0, HZ + 0.06), Vector3(1.90, HH, 0.12), 0.0],
	]
	for wl in walls:
		var c: Vector3 = w(wl[0].x, wl[1].y, wl[0].z)
		var s: Vector3 = wl[1]
		# 瓷砖到 2.2 m
		a.box(Vector3(c.x, Y0 + 1.10, c.z), Vector3(s.x, 2.20, s.z), m_tile_w, true)
		# 上部浅绿漆
		a.box(Vector3(c.x, Y0 + 2.20 + (HH - 2.20) * 0.5, c.z),
			Vector3(s.x, HH - 2.20, s.z), m_paint, false)

	# 北墙门洞：x −1.65…−0.75（0.9 m），通后房
	a.box(w(-1.20, 2.70, -HZ - 0.06), Vector3(0.90, 0.80, 0.12), m_tile_w, false)
	var df := a.plain(Color(0.22, 0.18, 0.14), 0.85)
	a.box(w(-1.20, 1.05, -HZ + 0.02), Vector3(0.98, 2.10, 0.05), df, false)
	# 门扇：绕左侧铰链成组，才能转开
	var hinge := a.push_group(w(-1.63, 1.05, -HZ + 0.06), 0.0, true)
	a.box(Vector3(0.43, 0.0, 0.0), Vector3(0.86, 2.02, 0.03),
		a.plain(Color(0.34, 0.29, 0.22), 0.8), false)
	a.box(Vector3(0.78, -0.05, 0.035), Vector3(0.05, 0.05, 0.05),
		a.plain(Color(0.60, 0.55, 0.40), 0.4, 0.8), false)
	a.pop_group()
	doors["back"] = hinge

	# 踢脚线：深绿，剥落（用两段不同长度模拟）
	var sk := a.plain(Color(0.10, 0.18, 0.13), 0.9)
	a.box(w(0, 0.05, -HZ + 0.02), Vector3(fw, 0.10, 0.03), sk, false)
	a.box(w(0, 0.05, HZ - 0.02), Vector3(fw, 0.10, 0.03), sk, false)
	a.box(w(-HX + 0.02, 0.05, 0), Vector3(0.03, 0.10, fd), sk, false)
	a.box(w(HX - 0.02, 0.05, 0), Vector3(0.03, 0.10, fd), sk, false)

	# 20 年前的水位线：西墙 y = 0.90 一条暗线
	var line_m := a.plain(Color(0.30, 0.32, 0.28), 0.95)
	a.box(w(-HX + 0.09, 0.90, 0), Vector3(0.006, 0.012, fd - 0.4), line_m, false)
	# 墙根的锈
	var rust_m := a.pbr("rusty_metal", 1.4, Color(0.7, 0.55, 0.42), 1.0)
	a.box(w(0, 0.10, -HZ + 0.09), Vector3(fw - 0.8, 0.16, 0.012),
		a.plain(Color(0.22, 0.17, 0.14), 0.95), false)

	# 南墙的入口：卷帘门洞（2.2 宽 × 2.4 高），两侧留墙
	a.box(w(0, 2.75, HZ + .06), Vector3(2.60, .70, .12), m_paint, false)
	var door_w := 1.30
	a.box(w(0, 2.46, HZ - 0.02), Vector3(door_w * 2.0 + 0.14, 0.10, 0.16), m_steel, false)
	# 卷帘：卷起来的上半截
	a.cyl(w(0, 2.52, HZ - 0.10), 0.11, door_w * 2.0, m_steel, 14, "x")

	# 吊顶两块塌了：要做成**真的凹进去的洞**，不能只贴一块暗色面。
	# 原来的写法只比顶板低 2 cm，灯下一看就是两块黑方块（像贴上去的黑纸）。
	# 现在：洞口四周补齐断面 + 洞底抬到顶板之上 0.22，洞里是暗的 —— 读作“塌了个洞”。
	var hole_dk := a.plain(Color(0.10, 0.10, 0.10), 0.98)
	var hole_edge := a.plain(Color(0.62, 0.61, 0.58), 0.95)
	for hz in [[-1.10, ZC - 1.40, -0.40, ZC - 0.30], [0.60, ZC + 1.10, 1.60, ZC + 2.20]]:
		var hx0: float = hz[0]
		var hz0: float = hz[1]
		var hx1: float = hz[2]
		var hz1: float = hz[3]
		var yc: float = Y0 + HH
		# 洞底（比顶板高 0.22，从下面看不到，只在洞里露一点暗）
		a.quad_xz(hx0, hz0, hx1, hz1, yc + 0.22, hole_dk, false)
		# 四壁（竖直的断面，把楼板厚度读出来）
		a.box(Vector3((hx0 + hx1) * 0.5, yc + 0.11, hz0), Vector3(hx1 - hx0, 0.22, 0.02), hole_edge)
		a.box(Vector3((hx0 + hx1) * 0.5, yc + 0.11, hz1), Vector3(hx1 - hx0, 0.22, 0.02), hole_edge)
		a.box(Vector3(hx0, yc + 0.11, (hz0 + hz1) * 0.5), Vector3(0.02, 0.22, hz1 - hz0), hole_edge)
		a.box(Vector3(hx1, yc + 0.11, (hz0 + hz1) * 0.5), Vector3(0.02, 0.22, hz1 - hz0), hole_edge)

# ------------------------------------------------------------------ 机器
## Blender 版洗衣机（assets/models/props/washer_01/washer_01.glb，3260 面）。
## 正面朝 −Z（模型导出时正面朝 −Y，glTF Y-up 转过来就是 −Z），
## 所以 yaw=0 时机门朝 −Z；要用 yaw 把门转到房里。
const WASHER_GLB := "res://assets/models/props/washer_01/washer_01.glb"
const DRUM_GLB := "res://assets/models/props/washer_01/washer_01_drum.glb"
var _washer_scene = null
var _drum_scene = null

func _machine_glb(p: Vector3, yaw: float, old := false, open_door := false) -> Node3D:
	if _washer_scene == null:
		_washer_scene = load(WASHER_GLB)
		_drum_scene = load(DRUM_GLB)
	if _washer_scene == null:
		push_warning("floor2: 洗衣机 GLB 加载失败，回退到盒子版")
		return _machine_box(p, yaw, old, open_door)

	# —— 机身：挂在可转的组里，方便整体朝向
	a.push_group(p, yaw)
	var body: Node3D = _washer_scene.instantiate()
	body.set_meta("dynamic", true)      # 不参与静态合批
	body.name = "Washer"
	a.root.add_child(body)
	# 旧机（7 号）换一套偏黄的搪瓷色
	if old:
		_tint_glb(body, Color(0.94, 0.89, 0.74))
	# 机门半开（7 号机用不到，留给以后）
	if open_door:
		var dm := a.push_group(Vector3(-0.42, 0.02, -0.40), -1.05, true)
		a.box(Vector3.ZERO, Vector3(0.42, 0.42, 0.03),
			a.plain(Color(0.72, 0.72, 0.70), 0.45))
		a.pop_group()
	a.pop_group()

	# —— 滚筒：单独一个可转组（与 box 版接口一致：drums[n] = 这个 Node3D）
	var g := Node3D.new()
	g.name = "Drum"
	g.set_meta("dynamic", true)
	g.position = p + Vector3(0, 0.02, 0.01)
	g.rotation.y = yaw
	a.root.add_child(g)
	var drum: Node3D = _drum_scene.instantiate() if _drum_scene != null else null
	if drum != null:
		drum.set_meta("dynamic", true)
		g.add_child(drum)
		# 滚筒轴向：模型是 Y 轴（导出后 Godot 里是 Y），要转成 Z 轴（与 box 版一致）
		drum.rotation.x = PI * 0.5
		drum.position = Vector3(0, 0, -0.18)
	return g

func _tint_glb(n: Node, tint: Color) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var base: Material = mi.get_active_material(i)
			if base is BaseMaterial3D:
				var mm: BaseMaterial3D = base.duplicate()
				mm.albedo_color = base.albedo_color * tint
				mi.set_surface_override_material(i, mm)

## 旧版（盒子拼装）：GLB 加载失败时的 fallback，逻辑一行没动。
func _machine(p: Vector3, yaw: float, old := false, open_door := false) -> Node3D:
	return _machine_glb(p, yaw, old, open_door)

func _machine_box(p: Vector3, yaw: float, old := false, open_door := false) -> Node3D:
	a.push_group(p, yaw)
	var body := m_enamel_old if old else m_enamel
	var wdt := 0.66
	var dep := 0.72
	var hgt := 0.92
	var hw := wdt * 0.5
	var hh := hgt * 0.5
	var hd := dep * 0.5
	var hole := 0.215          # 前脸圆洞半径
	var ring_out := 0.245      # 门圈外径

	# —— 左右侧板 / 顶板 / 底板 / 背板（厚 0.045）
	a.bev(Vector3(0, 0, -hd + 0.022), Vector3(wdt, hgt, 0.045), body, 0.010)
	a.bev(Vector3(0, hh - 0.022, 0), Vector3(wdt, 0.045, dep), body, 0.010)
	a.bev(Vector3(0, -hh + 0.022, 0), Vector3(wdt, 0.045, dep), body, 0.010)
	a.bev(Vector3(-hw + 0.022, 0, 0), Vector3(0.045, hgt, dep - 0.045), body, 0.010)
	a.bev(Vector3(hw - 0.022, 0, 0), Vector3(0.045, hgt, dep - 0.045), body, 0.010)

	# —— 前脸：先铺一张整面（洞在中间），再用环形盖住洞边
	#     整面用 4 块矩形拼，中间留出方孔；环形再把方孔收成圆孔
	var fz := hd - 0.014
	var sq := hole * 1.16                     # 方孔半边长
	a.box(Vector3(0, hh - (hh - sq) * 0.5, fz), Vector3(wdt, hh - sq, 0.030), body)   # 上
	a.box(Vector3(0, -hh + (hh - sq) * 0.5, fz), Vector3(wdt, hh - sq, 0.030), body)  # 下
	a.box(Vector3(-hw + (hw - sq) * 0.5, 0.02, fz), Vector3(hw - sq, sq * 2.0, 0.030), body)  # 左
	a.box(Vector3(hw - (hw - sq) * 0.5, 0.02, fz), Vector3(hw - sq, sq * 2.0, 0.030), body)   # 右

	# —— 方孔 → 圆孔：环形补片（外接正方形，内接圆）
	var segs := 24
	for i in range(segs):
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var r0 := hole
		var r1 := _face_ring_outer(a0, a1, sq + 0.01, sq + 0.01)
		var z2 := hd - 0.008
		var q0 := Vector3(cos(a0) * r0, sin(a0) * r0 + 0.02, z2)
		var q1 := Vector3(cos(a1) * r0, sin(a1) * r0 + 0.02, z2)
		var o0 := Vector3(cos(a0) * r1, sin(a0) * r1 + 0.02, z2)
		var o1 := Vector3(cos(a1) * r1, sin(a1) * r1 + 0.02, z2)
		a.quad(q0, o0, o1, q1, body, Vector3(0, 0, 1))

	# —— 门圈：真正的环带（不是实心饼），否则会把筒腔整个堵死
	var ring_mat := a.plain(Color(0.62, 0.63, 0.64), 0.28, 0.85)
	var rs := 28
	for i in range(rs):
		var a0 := TAU * float(i) / float(rs)
		var a1 := TAU * float(i + 1) / float(rs)
		var zf := hd + 0.014
		var zb := hd - 0.014
		var i0 := Vector3(cos(a0) * hole, sin(a0) * hole + 0.02, zf)
		var i1 := Vector3(cos(a1) * hole, sin(a1) * hole + 0.02, zf)
		var o0 := Vector3(cos(a0) * ring_out, sin(a0) * ring_out + 0.02, zf)
		var o1 := Vector3(cos(a1) * ring_out, sin(a1) * ring_out + 0.02, zf)
		# 正面环带
		a.quad(i0, o0, o1, i1, ring_mat, Vector3(0, 0, 1))
		# 内壁
		var j0 := Vector3(cos(a0) * hole, sin(a0) * hole + 0.02, zb)
		var j1 := Vector3(cos(a1) * hole, sin(a1) * hole + 0.02, zb)
		a.quad(j0, i0, i1, j1, ring_mat, Vector3(-cos(a0), -sin(a0), 0))
	# —— 门玻璃：雾面（低模里靠这层灰读"里面有东西"）
	a.cyl(Vector3(0, 0.02, hd + 0.016), hole - 0.004, 0.008,
		a.glass(Color(0.16, 0.18, 0.19, 0.55)), 28, "z")
	# 7 号机的门是开的：门板挂到左侧外面
	if open_door:
		var dm := a.push_group(Vector3(-0.42, 0.02, hd + 0.10), -1.05)
		a.box(Vector3.ZERO, Vector3(0.42, 0.42, 0.03), a.plain(Color(0.72, 0.72, 0.70), 0.45))
		a.pop_group()
	# —— 筒腔背板内侧压暗
	a.box(Vector3(0, 0.02, -hd + 0.05), Vector3(hole * 2.4, hole * 2.4, 0.012),
		a.plain(Color(0.10, 0.10, 0.11), 0.9))

	# 顶部控制面板 / 投币槽 / 编号牌
	a.box(Vector3(0, hh + 0.045, 0.06), Vector3(wdt - 0.08, 0.055, 0.26), m_dark)
	a.box(Vector3(0, hh + 0.078, 0.02), Vector3(wdt - 0.16, 0.010, 0.18),
		a.plain(Color(0.34, 0.35, 0.35), 0.5, 0.5))
	a.box(Vector3(hw * 0.60, 0.30, hd + 0.006), Vector3(0.095, 0.12, 0.010), m_steel)
	a.box(Vector3(hw * 0.60, 0.30, hd + 0.012), Vector3(0.055, 0.018, 0.006), m_dark)
	a.box(Vector3(0, 0.275, hd + 0.006), Vector3(0.125, 0.080, 0.008),
		a.plain(Color(0.90, 0.90, 0.87), 0.7))
	# 底座
	a.box(Vector3(0, -hh + 0.015, 0), Vector3(wdt - 0.05, 0.05, dep - 0.05), m_dark)
	a.pop_group()

	# —— 滚筒：单独一组，可以转（贴着筒底，不挡门口）
	var g := a.push_group(p + Vector3(0, 0.02, 0.01), yaw, true)
	for i in range(24):
		var a0 := TAU * float(i) / 24.0
		var a1 := TAU * float(i + 1) / 24.0
		var p0 := Vector3(cos(a0) * 0.180, sin(a0) * 0.180, -0.10)
		var p1 := Vector3(cos(a1) * 0.180, sin(a1) * 0.180, -0.10)
		var q0 := Vector3(cos(a0) * 0.180, sin(a0) * 0.180, -0.26)
		var q1 := Vector3(cos(a1) * 0.180, sin(a1) * 0.180, -0.26)
		a.quad(p0, q0, q1, p1, m_drum, Vector3(cos(a0), sin(a0), 0))
	for i in range(8):
		var ang := TAU * float(i) / 8.0
		a.box(Vector3(cos(ang) * 0.152, sin(ang) * 0.152, -0.19),
			Vector3(0.030, 0.046, 0.20),
			a.plain(Color(0.62, 0.64, 0.66), 0.28, 0.85))
	a.pop_group()
	return g

## 前脸圆环的外接半径：在矩形内接，保证不超出机身
func _face_ring_outer(a0: float, a1: float, maxx: float, maxy: float) -> float:
	var am := (a0 + a1) * 0.5
	var cx := cos(am)
	var cy := sin(am)
	var r := 999.0
	if absf(cx) > 0.0001:
		r = minf(r, maxx / absf(cx))
	if absf(cy) > 0.0001:
		r = minf(r, maxy / absf(cy))
	return minf(r, 0.32)

func _machines() -> void:
	# 西墙 6 台洗衣机，机门朝 +X（房间里）
	# 间距 0.92：GLB 机身沿墙方向占 0.72，留 0.20 缝（原 1.00 时缝太大、
	# 且相邻门圈在透视里几乎相切）。机器中心贴墙 x=−2.80。
	var washers := [
		[Vector3(-2.80, 0.46, 2.76), 1], [Vector3(-2.80, 0.46, 1.84), 2],
		[Vector3(-2.80, 0.46, 0.92), 3], [Vector3(-2.80, 0.46, 0.00), 4],
		[Vector3(-2.80, 0.46, -0.92), 5], [Vector3(-2.80, 0.46, -1.84), 6],
	]
	for m in washers:
		var lpos: Vector3 = m[0]
		var dn := _machine(w(lpos.x, lpos.y, lpos.z), PI * 0.5, false)
		drums[int(m[1])] = dn
		a.label(str(m[1]), w(lpos.x + 0.37, 0.755, lpos.z), 0.038, Color(0.14, 0.14, 0.14), PI * 0.5, 34)

	# 东墙 5 台烘干机，机门朝 −X
	var dryers := [
		[Vector3(2.80, 0.46, -1.84), 8], [Vector3(2.80, 0.46, -0.92), 9],
		[Vector3(2.80, 0.46, 0.00), 10], [Vector3(2.80, 0.46, 0.92), 11],
		[Vector3(2.80, 0.46, 1.84), 12],
	]
	for m in dryers:
		var lpos: Vector3 = m[0]
		var dn := _machine(w(lpos.x, lpos.y, lpos.z), -PI * 0.5, false)
		drums[int(m[1])] = dn
		a.label(str(m[1]), w(lpos.x - 0.37, 0.755, lpos.z), 0.038, Color(0.14, 0.14, 0.14), -PI * 0.5, 34)

	_machine_seven()

## 7 号机：正对门，旧一整代，绿光，里面一件不转的毛衣。
func _machine_seven() -> void:
	var p := w(0, 0.46, -3.70)
	drums[7] = _machine(p, 0.0, true, false)
	# 手写编号：红马克笔，7 上面圈一道
	a.label("7", w(0, 1.215, -3.322), 0.058, Color(0.72, 0.10, 0.08), 0.0, 42)
	a.cyl(w(0, 1.215, -3.330), 0.048, 0.003, a.plain(Color(0.72, 0.10, 0.08), 0.6), 20, "z")
	# 投币槽被胶带封死
	a.box(w(0.198, 0.80, -3.328), Vector3(0.10, 0.10, 0.008),
		a.plain(Color(0.76, 0.72, 0.58), 0.88))
	# 玻璃内侧的半张身高贴纸
	a.box(w(0.0, 0.20, -3.352), Vector3(0.30, 0.22, 0.004),
		a.plain(Color(0.86, 0.84, 0.70), 0.9))
	# 纸条
	a.box(w(-0.26, 0.60, -3.330), Vector3(0.13, 0.09, 0.004),
		a.plain(Color(0.90, 0.88, 0.80), 0.9), false, 0.06)
	# 悬在正中间的儿童毛衣
	var knit := a.emit(Color(0.20, 0.27, 0.42), 0.35)
	sweater = a.push_group(w(0, 0.48, -3.300), 0.0, true)
	var stripe := a.plain(Color(0.88, 0.88, 0.86), 0.9)
	# 衣身：下摆宽、肩部略收
	a.bev(Vector3(0, -0.02, 0), Vector3(0.20, 0.15, 0.016), knit, 0.006)
	a.bev(Vector3(0, 0.075, 0), Vector3(0.17, 0.05, 0.016), knit, 0.006)
	# 两只袖子：向下外撇
	var sl := a.bev(Vector3(-0.108, 0.005, 0), Vector3(0.050, 0.16, 0.014), knit, 0.005)
	sl.rotation.z = 0.13
	var sr := a.bev(Vector3(0.108, 0.005, 0), Vector3(0.050, 0.16, 0.014), knit, 0.005)
	sr.rotation.z = -0.13
	# 袖口白条纹
	a.box(Vector3(-0.121, -0.072, 0.001), Vector3(0.050, 0.018, 0.015), stripe)
	a.box(Vector3(0.121, -0.072, 0.001), Vector3(0.050, 0.018, 0.015), stripe)
	# 下摆白条纹
	a.box(Vector3(0, -0.088, 0.001), Vector3(0.198, 0.016, 0.015), stripe)
	# V 领
	var collar := a.plain(Color(0.10, 0.14, 0.24), 0.9)
	a.box(Vector3(0, 0.088, 0.004), Vector3(0.075, 0.030, 0.010), collar)
	a.pop_group()
	# 绿光：全店唯一的"错的光源"
	a.omni(w(0, 0.94, -3.46), Color(0.78, 1.0, 0.88), 1.1, 1.5, false)

# ------------------------------------------------------------------ 家具
## 家具 GLB（_setup/blender_furniture.py 产出）：
## 尺寸与原盒子版对齐；底面在原点、正面朝 −Z。
const FURN_DIR := "res://assets/models/props/"
var _furn_cache: Dictionary = {}

func _put_furniture(id: String, pos: Vector3, yaw := 0.0, tint := Color(1, 1, 1, 1)) -> Node3D:
	var path := FURN_DIR + id + "/" + id + ".glb"
	var ps = _furn_cache.get(path)
	if ps == null:
		ps = load(path)
		_furn_cache[path] = ps
	if ps == null:
		push_warning("floor2: 缺家具模型 " + path)
		return null
	var inst: Node3D = ps.instantiate()
	inst.set_meta("dynamic", true)
	inst.position = pos
	inst.rotation.y = yaw
	a.root.add_child(inst)
	if tint != Color(1, 1, 1, 1):
		_tint_node(inst, tint)
	return inst

func _tint_node(n: Node, tint: Color) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var base: Material = mi.get_active_material(i)
			if base is BaseMaterial3D:
				var mm: BaseMaterial3D = base.duplicate()
				mm.albedo_color = base.albedo_color * tint
				mi.set_surface_override_material(i, mm)

func _furniture() -> void:
	# 1 长椅（Blender 版 bench_01，1864 面）：蓝色硬塑料，三个座位，中间那个永远空着
	#   GLB 的 +Z 长边对应旧版的 Z 长边，所以 yaw=0
	#   旧版靠背在 +X 侧（面向 −X 坐）；GLB 靠背在 −X 侧，所以转 180°。
	var bc_world := w(1.90, 0.0, 1.00)
	_put_furniture("bench_01", Vector3(bc_world.x, Y0, bc_world.z), PI, Color(0.92, 0.94, 1.0))
	# 长椅下那块踏脚钢板（旧版有，保留）
	a.box(w(1.90, 0.18, 1.00) + Vector3(0, 0.02, 0), Vector3(0.10, 0.05, 2.30), m_steel)

	# 2 折叠桌 + 永远停在同一页的杂志
	#   Blender 版（folding_table_01，800 面）：两块台面 + 铁折叠腿 + 摊开的杂志
	var tc := w(2.55, 0.0, 3.30)
	_put_furniture("folding_table_01", Vector3(tc.x, Y0, tc.z), PI * 0.5,
		Color(0.90, 0.84, 0.76))

	# 3 柜台（Blender 版 counter_01，1392 面；后房门在它后面）
	#   GLB 长边沿 Z、正面朝 −Z —— 与旧版完全一致（旧版就是 0.60 深 × 2.00 沿 Z），
	#   所以 yaw = 0。给 PI/2 会把它转成横穿店铺的一堵墙（踩过一次）。
	#   GLB 底面在原点 → y 取地板高 Y0；x/z 用 w() 的结果（w 已经是世界坐标）。
	var cc := w(-2.10, 0.52, 2.40)
	_put_furniture("counter_01", Vector3(cc.x - 0.28, Y0, cc.z), 0.0, Color(0.78, 0.70, 0.60))
	# 柜台碰撞（GLB 不自动带碰撞，这里补一块，尺寸与旧版一致）
	a.col(Vector3(cc.x, cc.y - 0.10, cc.z), Vector3(0.60, 0.66, 2.00))
	# 台面一圈杯渍
	a.cyl(cc + Vector3(0.02, 0.056, 0.35), 0.055, 0.002,
		a.plain(Color(0.42, 0.34, 0.26), 0.95), 18, "y")
	# 4 收银机（Blender 版 register_01，1200 面）：
	#   3×5 按键阵列 + 数字窗 + 摇柄 + 拉开的抽屉（里面三枚硬币：1998/1998/2019）
	var rp := w(-2.10, 0.0, 2.62)
	_put_furniture("register_01", Vector3(rp.x - 0.06, Y0 + 0.57, rp.z), PI * 0.5,
		Color(0.88, 0.84, 0.76))

	# 5 价目表（北墙）
	a.box(w(-2.20, 1.90, -4.02), Vector3(0.60, 0.80, 0.03),
		a.plain(Color(0.88, 0.86, 0.78), 0.85))
	a.box(w(-2.20, 1.90, -4.045), Vector3(0.56, 0.76, 0.01), m_steel)
	a.label("洗 衣 价 目", w(-2.20, 2.12, -3.996), 0.047, Color(0.20, 0.25, 0.21), 0.0, 36)
	a.label("洗衣  8 元\n烘干  5 元\n7 号机 · 专用", w(-2.20, 1.83, -3.995), 0.035, Color(0.26, 0.29, 0.24), 0.0, 30)

	# 6 镜子（东墙）：1.2 × 1.8，左边三分之一是雾的
	#   用 shaders/mirror_screen.gdshader 做镜面反射 —— 原来只是一块高金属度的板，
	#   实测在场景里读成"一整块黑"（截图确认），照不出店堂。
	a.box(w(3.12, 1.55, -0.50), Vector3(0.03, 1.80, 1.20), _mirror_mat())
	a.box(w(3.10, 1.55, -0.50 - 0.40), Vector3(0.01, 1.76, 0.38),
		a.plain(Color(0.66, 0.68, 0.66), 0.5, 0.2))
	a.box(w(3.13, 1.55, -0.50), Vector3(0.02, 1.86, 1.26), m_steel)

	# 7 垃圾桶（Blender 版 bin_01，792 面；铁的，里面全是没人来取的衣物）
	var bn_world := w(2.90, 0.0, 3.50)
	_put_furniture("bin_01", Vector3(bn_world.x, Y0, bn_world.z), 0.0)

	# 8 门框身高尺：南墙门框内侧，1.4 高，一年一条
	var zx := w(0.90, 0.70, 4.03)
	a.box(zx, Vector3(0.08, 1.40, 0.02), a.plain(Color(0.86, 0.84, 0.76), 0.9))
	var mark := a.plain(Color(0.32, 0.30, 0.26), 0.9)
	for i in range(12):
		var yy: float = 0.30 + 0.085 * i
		a.box(zx + Vector3(0, yy - 0.70, 0.015), Vector3(0.05, 0.006, 0.006), mark)
	a.label("2004", zx + Vector3(0, 0.42, 0.02), 0.028, Color(0.30, 0.28, 0.24), 0.0, 28)

# ------------------------------------------------------------------ 灯光（5-5）
func _lights() -> void:
	# 可见的旧荧光灯壳，让照明在空间里有来源。
	for z in [-2.20, 2.20]:
		a.box(w(0, 3.02, z), Vector3(1.25, 0.10, 0.24), m_steel, false)
		a.box(w(0, 2.96, z), Vector3(1.12, 0.025, 0.14), a.emit(Color(0.75, 0.83, 0.78), 1.2), false)
	# 主灯 A：5000 K，门口这一半
	a.omni(w(0, 2.95, 2.20), Color(0.86, 0.92, 1.0), 0.85, 9.0, true)
	# 主灯 B：更暗，让北墙永远半黑
	a.omni(w(0, 2.95, -2.20), Color(0.86, 0.92, 1.0), 0.70, 8.5, true)
	# 招牌反射光：钠黄，从门外漏进来，把地面切成一条黄
	a.omni(w(0, 2.80, 4.60), Color(1.0, 0.66, 0.28), 0.95, 5.0, false)
	# 反射探针：这间屋子所有东西都在反光，镜子得真的照出东西
	var rp := ReflectionProbe.new()
	rp.position = Vector3(0, Y0 + 1.55, ZC)
	rp.size = Vector3(6.9, 3.2, 8.6)
	rp.box_projection = true
	rp.update_mode = ReflectionProbe.UPDATE_ALWAYS
	rp.intensity = 1.0
	rp.interior = true
	a.root.add_child(rp)
	# 镜子补光：只是为了让镜子里有东西可看
	a.omni(w(3.0, 1.60, -0.50), Color(0.86, 0.92, 1.0), 0.55, 3.2, false)
