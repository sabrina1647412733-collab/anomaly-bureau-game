class_name LaundryKit
extends RefCounted
## 得利洗衣店 · 上层/地下层细部工具箱（**新增文件，不改 laundry_art.gd**）
##
## 为什么单独一个文件：laundry_art.gd 是 1F/2F/3F 与角色装配共用的基座，
## 多人在读它。为了让「4F / 5F+屋顶 / B1」可以独立开发、独立回滚，
## 这里只做**包装**：所有几何最终仍走 LaundryArt 的 box/bev/cyl/quad，
## 合批、碰撞、材质缓存全部复用同一套规则。
##
## 美术基准 = 序章出租屋（pro_room_art.gd）：
##   PBR 四件套 + 世界三平面 UV · 护墙板 + 门套 + 画框 · 暖光池 + 深色衰减
##   这里把这套“构件”抽成函数，四个新楼层共用，保证和出租房同一张脸。

const MOD := "res://assets/models/props/"
const MOD_FLAT := "res://assets/models/"

# ---------------------------------------------------------------- 层高链
const F1 := 0.0
const F2 := 3.5
const F3 := 6.9
const F4 := 9.8
const F5 := 12.7
const ROOF := 15.6
const B1 := -3.0
const HH := 2.6          # 4F / 5F 净高
const SLAB := 0.30       # 楼板厚
const X0 := -3.2
const X1 := 3.2
const COR_Z0 := 5.4      # 上层走廊北墙（房间门所在）
const COR_Z1 := 11.0     # 上层走廊南墙（楼梯口）

var a: LaundryArt      # LaundryArt 实例（不污染它的接口）
var root: Node3D
var _mcache: Dictionary = {}
## 可动件登记表：门扇 / 滚筒 / 升降件。剧情与动画系统按 key 取。
var doors: Dictionary = {}

func _init(art: LaundryArt) -> void:
	a = art
	root = a.root

# ================================================================ 材质（全部走 art 的缓存）
func pbr(id: String, uv := 1.0, tint := Color.WHITE, rough := 1.0,
		metal := 0.0, ns := 1.0) -> StandardMaterial3D:
	return a.pbr(id, uv, tint, rough, metal, ns)

func plain(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	return a.plain(c, rough, metal)

func emit(c: Color, e := 2.0) -> StandardMaterial3D:
	return a.emit(c, e)

func glass(c := Color(0.62, 0.70, 0.72, 0.22)) -> StandardMaterial3D:
	return a.glass(c)

## 布料：双面 + 低粗糙，窗帘/床单/挂着的衣服都用它
func cloth(id: String, tint: Color, uv := 2.2) -> StandardMaterial3D:
	var key := "cloth|%s|%s|%.2f" % [id, str(tint), uv]
	if a.mats.has(key):
		return a.mats[key]
	var m := a.pbr(id, uv, tint, 0.96, 0.0, 0.6)
	m.uv1_scale = Vector3(uv, uv, uv)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	a.mats[key] = m
	return m

## 湿墙面：颜色深、粗糙度极低，靠高光读出“湿”
func wet(id: String, tint: Color, uv := 0.45) -> StandardMaterial3D:
	var key := "wet|%s|%s|%.2f" % [id, str(tint), uv]
	if a.mats.has(key):
		return a.mats[key]
	var m := a.pbr(id, uv, tint, 0.16, 0.05, 0.85)
	m.uv1_scale = Vector3(uv, uv, uv)
	a.mats[key] = m
	return m

# ================================================================ 建筑构件
## 水平板：地板 / 天花 / 楼板。kind = "floor" | "ceil" | "slab"
func slab(x0: float, z0: float, x1: float, z1: float, y: float, mat: Material,
		kind := "floor", collide := true) -> void:
	a.quad_xz(x0, z0, x1, z1, y, mat, kind != "ceil")
	if collide:
		var t := SLAB if kind == "slab" else 0.30
		a.col(Vector3((x0 + x1) * 0.5, y - t * 0.5, (z0 + z1) * 0.5),
			Vector3(absf(x1 - x0), t, absf(z1 - z0)))

## 沿 X 方向的墙（垂直于 Z）。dz 是墙厚。
func wall_x(z: float, x0: float, x1: float, y0: float, h: float, mat: Material,
		thick := 0.12, collide := true) -> MeshInstance3D:
	return a.box(Vector3((x0 + x1) * 0.5, y0 + h * 0.5, z),
		Vector3(absf(x1 - x0), h, thick), mat, collide)

## 实体楼板：上下两个面 + 0.30 m 的碰撞体。天花板与地板之间必须是实的，
## 否则从上一层俯视会直接看穿到下一层（4F/5F/屋顶之间都会穿帮）。
## 侧面不画：这一层的墙已经把它挡住了，多画只会多 1.2 万面。
func slab_solid(x0: float, z0: float, x1: float, z1: float, y: float,
		mat_top: Material, mat_bot: Material = null) -> void:
	a.quad_xz(x0, z0, x1, z1, y, mat_top)
	a.quad_xz(x0, z0, x1, z1, y - SLAB, mat_bot if mat_bot != null else mat_top, false)
	a.col(Vector3((x0 + x1) * 0.5, y - SLAB * 0.5, (z0 + z1) * 0.5),
		Vector3(absf(x1 - x0), SLAB, absf(z1 - z0)))

## 带洞的楼板：hole = Rect2(x0, z0, w, d)（世界 XZ）。楼板被切成四块。
## 楼梯井、天窗井都用它，避免“整块板压在楼梯口上”的穿帮。
func slab_hole(x0: float, z0: float, x1: float, z1: float,
		hole: Rect2, y: float, mat: Material, kind := "floor", collide := true) -> void:
	var hx0 := maxf(hole.position.x, x0)
	var hz0 := maxf(hole.position.y, z0)
	var hx1 := minf(hole.position.x + hole.size.x, x1)
	var hz1 := minf(hole.position.y + hole.size.y, z1)
	if hx1 <= hx0 or hz1 <= hz0:
		slab(x0, z0, x1, z1, y, mat, kind, collide)
		return
	# 北条 / 南条 / 西条 / 东条
	if hz0 > z0:
		slab(x0, z0, x1, hz0, y, mat, kind, collide)
	if hz1 < z1:
		slab(x0, hz1, x1, z1, y, mat, kind, collide)
	if hx0 > x0:
		slab(x0, hz0, hx0, hz1, y, mat, kind, collide)
	if hx1 < x1:
		slab(hx1, hz0, x1, hz1, y, mat, kind, collide)

## 沿 X 方向的墙，但**按洞口分段**：holes = [[x0, x1], ...]。
## 用于楼梯口 / 门洞 —— 直接摆一整块 box 会把洞口堵死（4F 原来就犯了这个错）。
## 洞顶以上补过梁，保证墙面仍然完整。
func wall_x_with_holes(z: float, x0: float, x1: float, y0: float, h: float,
		mat: Material, holes: Array, thick := 0.12, door_h := 2.10) -> void:
	var cuts: Array = []
	for hh in holes:
		var a: float = maxf(hh[0], x0)
		var b: float = minf(hh[1], x1)
		if b > a:
			cuts.append([a, b])
	cuts.sort_custom(func(u, v): return u[0] < v[0])
	var x := x0
	for c in cuts:
		if c[0] > x + 0.001:
			a.box(Vector3((x + c[0]) * 0.5, y0 + h * 0.5, z),
				Vector3(c[0] - x, h, thick), mat, true)
		# 洞口上方的过梁
		var lintel := h - door_h
		if lintel > 0.01:
			a.box(Vector3((c[0] + c[1]) * 0.5, y0 + door_h + lintel * 0.5, z),
				Vector3(c[1] - c[0], lintel, thick), mat, false)
		x = c[1]
	if x < x1 - 0.001:
		a.box(Vector3((x + x1) * 0.5, y0 + h * 0.5, z),
			Vector3(x1 - x, h, thick), mat, true)

## 沿 Z 方向的墙（垂直于 X）。
func wall_z(x: float, z0: float, z1: float, y0: float, h: float, mat: Material,
		thick := 0.12, collide := true) -> MeshInstance3D:
	return a.box(Vector3(x, y0 + h * 0.5, (z0 + z1) * 0.5),
		Vector3(thick, h, absf(z1 - z0)), mat, collide)

## 踢脚线（出租屋也有一条，缺了显假）
func skirting_x(z: float, x0: float, x1: float, y: float, mat: Material,
		back := Vector3.ZERO, hgt := 0.12) -> void:
	a.box(Vector3((x0 + x1) * 0.5, y + hgt * 0.5, z) + back,
		Vector3(absf(x1 - x0), hgt, 0.025), mat)

func skirting_z(x: float, z0: float, z1: float, y: float, mat: Material,
		back := Vector3.ZERO, hgt := 0.12) -> void:
	a.box(Vector3(x, y + hgt * 0.5, (z0 + z1) * 0.5) + back,
		Vector3(0.025, hgt, absf(z1 - z0)), mat)

## 护墙板：一块木饰面 + 顶部压条 + 底部踢脚。dir 沿哪根轴铺（"x" / "z"）
func wainscot(pos: Vector3, length: float, hgt := 1.02, dir := "x",
		panel_mat: Material = null, rail_mat: Material = null, face := 1.0) -> void:
	var pm := panel_mat if panel_mat != null else pbr("oak_wood_planks", 0.9,
		Color(0.42, 0.33, 0.24), 0.72, 0.0, 0.8)
	var rm := rail_mat if rail_mat != null else pbr("oak_wood_planks", 1.3,
		Color(0.30, 0.23, 0.16), 0.55)
	var size := Vector3(length, hgt, 0.035) if dir == "x" else Vector3(0.035, hgt, length)
	a.box(pos + Vector3(0, hgt * 0.5, 0), size, pm, false)
	# 压条：护墙板顶沿那条 4 cm 的线，是整个房间“装修过”的信号
	var rs := Vector3(length + 0.04, 0.045, 0.075) if dir == "x" else Vector3(0.075, 0.045, length + 0.04)
	a.box(pos + Vector3(0, hgt + 0.02, 0) + Vector3(0, 0, 0.02 * face), rs, rm, false)
	# 踢脚
	var ss := Vector3(length, 0.11, 0.055) if dir == "x" else Vector3(0.055, 0.11, length)
	a.box(pos + Vector3(0, 0.055, 0) + Vector3(0, 0, 0.015 * face), ss, rm, false)

## 门套：在墙上开一个 0.9 × 2.05 的门洞，然后把洞口包起来。
## axis = "x"（墙沿 X 走，门在固定 z）或 "z"。
func door_casing(center: Vector3, w := 0.90, h := 2.05, axis := "x",
		frame_mat: Material = null, thick := 0.12) -> Dictionary:
	var fm := frame_mat if frame_mat != null else pbr("oak_wood_planks", 1.5,
		Color(0.26, 0.19, 0.13), 0.6)
	var fw := 0.075                                    # 门套线宽
	var out := {}
	if axis == "x":
		for sx in [-1.0, 1.0]:
			a.box(center + Vector3(sx * (w * 0.5 + fw * 0.5), h * 0.5, 0),
				Vector3(fw, h + fw, thick + 0.035), fm, false)
		a.box(center + Vector3(0, h + fw * 0.5, 0),
			Vector3(w + fw * 2.0, fw, thick + 0.035), fm, false)
		# 门洞内的侧壁 + 顶（有厚度，不然会看到“纸片墙”）
		a.box(center + Vector3(-w * 0.5 - 0.01, h * 0.5, 0), Vector3(0.02, h, thick), fm)
		a.box(center + Vector3(w * 0.5 + 0.01, h * 0.5, 0), Vector3(0.02, h, thick), fm)
		a.box(center + Vector3(0, h + 0.005, 0), Vector3(w, 0.02, thick), fm)
		out = {"w": w, "h": h, "axis": axis}
	else:
		for sz in [-1.0, 1.0]:
			a.box(center + Vector3(0, h * 0.5, sz * (w * 0.5 + fw * 0.5)),
				Vector3(thick + 0.035, h + fw, fw), fm, false)
		a.box(center + Vector3(0, h + fw * 0.5, 0),
			Vector3(thick + 0.035, fw, w + fw * 2.0), fm, false)
		a.box(center + Vector3(0, h * 0.5, -w * 0.5 - 0.01), Vector3(thick, h, 0.02), fm)
		a.box(center + Vector3(0, h * 0.5, w * 0.5 + 0.01), Vector3(thick, h, 0.02), fm)
		a.box(center + Vector3(0, h + 0.005, 0), Vector3(thick, 0.02, w), fm)
		out = {"w": w, "h": h, "axis": axis}
	return out

## 门扇：给一个可转的组（铰链在 -w/2 一侧），返回 Node3D 供后续开门动画用。
## 注意 group 是 dynamic —— 不参与静态合批。
func door_leaf(hinge: Vector3, w := 0.90, h := 2.02, yaw := 0.0,
		leaf_mat: Material = null, panel_mat: Material = null) -> Node3D:
	var lm := leaf_mat if leaf_mat != null else pbr("oak_wood_planks", 1.6,
		Color(0.30, 0.235, 0.17), 0.62)
	var pm := panel_mat if panel_mat != null else pbr("oak_wood_planks", 1.6,
		Color(0.24, 0.185, 0.135), 0.7)
	var g := a.push_group(hinge, yaw, true)
	a.box(Vector3(w * 0.5,h * .5,0),Vector3(w,h,.042),lm,false)
	# 门板碰撞随铰链转动，开门后不能留下原地的隐形碰撞。
	var door_body := StaticBody3D.new()
	var door_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w,h,.042)
	door_shape.shape = shape
	door_shape.position = Vector3(w*.5,h*.5,0)
	door_body.add_child(door_shape)
	g.add_child(door_body)
	# 双嵌板：老楼的门几乎都是这个样子
	for yy in [h * 0.30, h * 0.70]:
		a.box(Vector3(w * 0.5, yy, 0.024), Vector3(w * 0.70, h * 0.30, 0.014), pm, false)
		a.box(Vector3(w * 0.5, yy, -0.024), Vector3(w * 0.70, h * 0.30, 0.014), pm, false)
	a.pop_group()
	return g

## 画框 / 照片 / 告示：贴墙的一块，带边框。
func picture(center: Vector3, w: float, h: float, art_mat: Material,
		axis := "x", frame_mat: Material = null, frame_w := 0.035) -> void:
	var fm := frame_mat if frame_mat != null else pbr("oak_wood_planks", 2.0,
		Color(0.22, 0.16, 0.11), 0.6)
	if axis == "x":
		a.box(center, Vector3(w, h, 0.02), fm, false)
		a.box(center + Vector3(0, 0, 0.012), Vector3(w - frame_w * 2.0, h - frame_w * 2.0, 0.012),
			art_mat, false)
	else:
		a.box(center, Vector3(0.02, h, w), fm, false)
		a.box(center + Vector3(0.012, 0, 0), Vector3(0.012, h - frame_w * 2.0, w - frame_w * 2.0),
			art_mat, false)

# ================================================================ 管线
## 任意两点之间接一根圆管（水管、燃气管、扶手、栏杆）
func pipe(p0: Vector3, p1: Vector3, r: float, mat: Material, seg := 12) -> MeshInstance3D:
	var d := p1 - p0
	var ln := d.length()
	if ln < 0.0005:
		return null
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = ln
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = mat
	var up := Vector3.UP
	var dir := d / ln
	var basis: Basis
	if absf(dir.dot(up)) > 0.9995:
		basis = Basis(Vector3.RIGHT, PI if dir.dot(up) < 0.0 else 0.0)
	else:
		var axis := up.cross(dir).normalized()
		basis = Basis(axis, acos(clampf(up.dot(dir), -1.0, 1.0)))
	mi.transform = Transform3D(basis, (p0 + p1) * 0.5)
	root.add_child(mi)
	a.stats["meshes"] = int(a.stats["meshes"]) + 1
	return mi

## 圆盘 / 法兰（实心）
func disc(center: Vector3, radius: float, thick: float, mat: Material,
		axis := "y", seg := 16) -> void:
	var cm2 := CylinderMesh.new()
	cm2.top_radius = radius
	cm2.bottom_radius = radius
	cm2.height = thick
	cm2.radial_segments = seg
	var mi := MeshInstance3D.new()
	mi.mesh = cm2
	mi.material_override = mat
	if axis == "x":
		mi.rotation.z = PI * 0.5
	elif axis == "z":
		mi.rotation.x = PI * 0.5
	mi.position = center
	root.add_child(mi)

## 真正的环（管箍、法兰、手轮外圈）：用一圈四边形做成的空心环带。
## 不能用 CylinderMesh —— 那是实心饼，手轮会变成一块橙色圆片。
func ring(center: Vector3, radius: float, thick: float, mat: Material,
		axis := "y", seg := 16, width := 0.0) -> void:
	var r_out := radius
	# 环宽默认取半径的 34% —— 太厚就变成一块饼，太薄又看不见（手轮要读得出是“圈”）
	var r_in := radius - (width if width > 0.0 else radius * 0.34)
	r_in = maxf(r_in, 0.001)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(seg):
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		# 环在局部 XY 平面（正对 +Z），最后按 axis 转
		var i0 := Vector3(cos(a0) * r_in, sin(a0) * r_in, 0)
		var i1 := Vector3(cos(a1) * r_in, sin(a1) * r_in, 0)
		var o0 := Vector3(cos(a0) * r_out, sin(a0) * r_out, 0)
		var o1 := Vector3(cos(a1) * r_out, sin(a1) * r_out, 0)
		# 正面
		_tri(st, o0, o1, i1, Vector3(0, 0, 1))
		_tri(st, o0, i1, i0, Vector3(0, 0, 1))
		# 背面
		_tri(st, o0, i1, o1, Vector3(0, 0, -1))
		_tri(st, o0, i0, i1, Vector3(0, 0, -1))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = center
	if axis == "x":
		mi.rotation.y = PI * 0.5
	elif axis == "y":
		mi.rotation.x = PI * 0.5
	root.add_child(mi)
	a.stats["meshes"] = int(a.stats["meshes"]) + 1

func _tri(st: SurfaceTool, x: Vector3, y: Vector3, z: Vector3, n: Vector3) -> void:
	st.set_normal(n); st.add_vertex(x)
	st.set_normal(n); st.add_vertex(y)
	st.set_normal(n); st.add_vertex(z)

## 阀门手轮：外环 + 中心毂 + 4 根辐条。B1 墙上那 7 个“勿动”靠它才像手轮。
func valve_wheel(center: Vector3, radius := 0.115, mat: Material = null,
		axis := "z", spokes := 4) -> void:
	# 真正的手轮读法是「**空心环 + 辐条 + 中心毂**」。
	# 之前是「实心圆盘 + 一圈亮边」，从侧面看就是一块扁饼（截图里像棕色圆饼贴在墙上）。
	var m := mat if mat != null else plain(Color(0.50, 0.40, 0.30), 0.9, 0.25)
	var bright := plain(Color(0.64, 0.60, 0.48), 0.34, 0.82)
	var dark := plain(Color(0.30, 0.26, 0.20), 0.80, 0.40)
	var rim_w := 0.030                    # 轮缘厚度（径向）
	# ① 外圈：真正的空心环带（宽度 rim_w）
	ring(center, radius, 0.026, m, axis, 20, rim_w)
	# ② 辐条：从中心毂伸到轮缘内沿
	for i in range(spokes):
		var ang := TAU * float(i) / float(spokes) + 0.18
		var r_out := radius - rim_w * 0.6
		var r_in := radius * 0.22
		var d_out := Vector3(cos(ang) * r_out, sin(ang) * r_out, 0.0)
		var d_in := Vector3(cos(ang) * r_in, sin(ang) * r_in, 0.0)
		if axis == "z":
			pipe(center + d_in, center + d_out, 0.011, bright, 6)
		elif axis == "x":
			pipe(center + Vector3(0, d_in.x, d_in.y), center + Vector3(0, d_out.x, d_out.y),
				0.011, bright, 6)
		else:
			pipe(center + Vector3(d_in.x, 0, d_in.y), center + Vector3(d_out.x, 0, d_out.y),
				0.011, bright, 6)
	# ③ 中心毂 + 一段朝墙的阀杆
	disc(center, radius * 0.26, 0.040, bright, axis, 12)
	var back := Vector3.ZERO
	if axis == "z":
		back = Vector3(0, 0, 0.075)
	elif axis == "x":
		back = Vector3(0.075, 0, 0)
	else:
		back = Vector3(0, 0.075, 0)
	disc(center + back, radius * 0.11, 0.075, dark, axis, 8)

## 铁梯：两点之间（一般竖直），两侧边梁 + 横向踏棍
func ladder(p0: Vector3, p1: Vector3, width := 0.42, r := 0.022,
		mat: Material = null) -> void:
	var m := mat if mat != null else plain(Color(0.20, 0.20, 0.21), 0.55, 0.65)
	var d := p1 - p0
	var side := Vector3(width * 0.5, 0, 0)
	var n := maxf(2.0, d.length() / 0.30)
	for sx in [-1.0, 1.0]:
		pipe(p0 + side * sx, p1 + side * sx, r * 0.85, m, 8)
	for i in range(1, int(n)):
		var t := float(i) / n
		pipe(p0 + side * -1.0 + d * t, p0 + side + d * t, r * 0.7, m, 8)

## 栏杆：起点到终点，一根上扶手 + 若干立柱
func railing(p0: Vector3, p1: Vector3, hgt := 1.02, mat: Material = null,
		spacing := 0.9, r := 0.022) -> void:
	var m := mat if mat != null else plain(Color(0.24, 0.20, 0.15), 0.5, 0.55)
	var top0 := p0 + Vector3(0, hgt, 0)
	var top1 := p1 + Vector3(0, hgt, 0)
	pipe(top0, top1, r, m, 10)
	var ln := (p1 - p0).length()
	var n := maxi(1, int(ceil(ln / spacing)))
	for i in range(n + 1):
		var t := float(i) / float(n)
		var foot: Vector3 = p0.lerp(p1, t)
		pipe(foot, foot + Vector3(0, hgt, 0), r * 0.7, m, 8)

# ================================================================ 灯
## 吸顶灯：外壳 + 发光片 + 一盏 omni。返回 omni，方便剧情里关灯。
func ceiling_lamp(pos: Vector3, energy := 2.2, rng := 6.0, col := Color(1.0, 0.80, 0.56),
		shadow := true, fixture := Color(0.20, 0.19, 0.18)) -> OmniLight3D:
	a.box(pos, Vector3(0.30, 0.05, 0.30), plain(fixture, 0.7))
	a.box(pos + Vector3(0, -0.055, 0), Vector3(0.26, 0.035, 0.26), emit(col, 1.5))
	return a.omni(pos + Vector3(0, -0.18, 0), col, energy, rng, shadow)

## 吊灯泡：一根线 + 灯泡 + 光（后房那盏提过，上层沿用同一套语言）
func bulb_lamp(pos: Vector3, drop := 0.55, energy := 1.8, rng := 5.5,
		col := Color(1.0, 0.80, 0.52), shadow := true) -> OmniLight3D:
	a.cyl(pos + Vector3(0, -drop * 0.5, 0), 0.006, drop, plain(Color(0.18, 0.17, 0.16), 0.9), 6)
	a.box(pos + Vector3(0, -drop, 0), Vector3(0.075, 0.10, 0.075), emit(col, 1.6))
	return a.omni(pos + Vector3(0, -drop - 0.06, 0), col, energy, rng, shadow)

## 冷光：窗/天窗/月光。用 spot 打出斜切光柱的感觉。
func moon_spot(from: Vector3, to: Vector3, energy := 2.0, angle := 26.0,
		col := Color(0.62, 0.72, 0.92)) -> SpotLight3D:
	# spot() 内部用 look_at_from_position(..., Vector3.UP)；当天光从正上方往下打时
	# 方向与 UP 共线，Godot 会报 "Target and up vectors are colinear"。
	# 这里先把 from 稍微挪开一点，保证方向不与 UP 平行。
	var dir := (to - from)
	if dir.length_squared() < 1e-6:
		dir = Vector3(0, -1, 0)
	if absf(dir.normalized().dot(Vector3.UP)) > 0.985:
		from = from + Vector3(0.35, 0, 0.35)
	return a.spot(from, to, col, energy, 18.0, angle, true)

# ================================================================ 模型（Poly Haven CC0）
## 实例化 Poly Haven 模型。id 可以是：
##   "props/utility_box_01"  → assets/models/props/<id>/...（4F/5F/屋顶/B1 新资产）
##   "wooden_table_02"       → assets/models/<id>/...（出租屋已入库的旧资产，直接复用）
## 关键：必须 set_meta("dynamic", true)，否则 merge_static() 会把没有
## material_override 的 GLB 网格并进“null 材质组”，材质全丢。figure.gd 同理。
func model(id: String, pos: Vector3, yaw := 0.0, target_h := 0.0,
		tint := Color(1, 1, 1, 1), rot_x := 0.0) -> Node3D:
	var base := MOD if id.begins_with("props/") else MOD_FLAT
	var short := id.substr(6) if id.begins_with("props/") else id
	# Poly Haven 的模型是 <id>_1k.gltf；本项目自建的（洗衣机/家具/锅炉/缝纫机）是 <id>.glb。
	# 两种都要能加载 —— 原来硬编码 _1k.gltf，自建模型一律返回 null（锅炉就是这么消失的）。
	var dir := base + short + "/"
	var candidates := [dir + short + ".glb", dir + short + "_1k.gltf", dir + short + ".gltf"]
	var path := ""
	var ps = null
	for cand in candidates:
		if ResourceLoader.exists(cand):
			path = cand
			ps = _mcache.get(path)
			if ps == null:
				ps = load(path)
				_mcache[path] = ps
			break
	if ps == null:
		push_warning("LaundryKit: 缺模型 " + dir + short + " (.glb / _1k.gltf 都没有)")
		return null
	var inst: Node3D = ps.instantiate()
	inst.set_meta("dynamic", true)
	inst.position = pos
	inst.rotation.y = yaw
	if rot_x != 0.0:
		inst.rotation.x = rot_x
	root.add_child(inst)
	if target_h > 0.0:
		var b := _aabb(inst)
		if b.size.y > 0.001:
			var s := target_h / b.size.y
			inst.scale = Vector3(s, s, s)
	# 贴地：gltf 原点不一定在脚底
	var b2 := _aabb(inst)
	inst.position.y += pos.y - b2.position.y
	if tint != Color(1, 1, 1, 1):
		_tint(inst, tint)
	return inst

func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

func _tint(n: Node, tint: Color) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var base: Material = mi.get_active_material(i)
			if base is BaseMaterial3D:
				var mm: BaseMaterial3D = base.duplicate()
				mm.albedo_color = tint
				mi.set_surface_override_material(i, mm)

## 给模型加一层碰撞盒（先量 AABB，再丢一个 StaticBody 形状进去）
func model_collide(inst: Node3D, pad := 0.0) -> void:
	if inst == null:
		return
	var b := _aabb(inst)
	if b.size == Vector3.ZERO:
		return
	var local := b.position + b.size * 0.5 - inst.global_position
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = b.size + Vector3(pad, pad, pad)
	cs.shape = sh
	body.add_child(cs)
	inst.add_child(body)
	body.position = local

# ================================================================ 软装
## 挂着的布：网格 + 顶部压边 + 几条折，用来做窗帘 / 墙上的旧床单。
func drape(pos: Vector3, width: float, height: float, mat: Material, seed := 0.0,
		axis := "x", folds := 7.0, amp := 0.035) -> MeshInstance3D:
	var nx := 22
	var ny := 26
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for j in range(ny + 1):
		var v := float(j) / float(ny)
		var row: Array = []
		for i in range(nx + 1):
			var u := float(i) / float(nx)
			var w := width * (0.94 + 0.06 * v)
			var off := sin(u * PI * folds + seed) * (0.010 + amp * v)
			off += sin(u * PI * folds * 2.11 + seed * 1.7) * 0.008 * v
			var pt: Vector3
			if axis == "x":
				pt = Vector3((u - 0.5) * w, -v * height, off)
			else:
				pt = Vector3(off, -v * height, (u - 0.5) * w)
			row.append(pt)
		rows.append(row)
	for j in range(ny):
		for i in range(nx):
			var p00: Vector3 = rows[j][i]
			var p01: Vector3 = rows[j][i + 1]
			var p10: Vector3 = rows[j + 1][i]
			var p11: Vector3 = rows[j + 1][i + 1]
			st.add_vertex(p00); st.add_vertex(p01); st.add_vertex(p11)
			st.add_vertex(p00); st.add_vertex(p11); st.add_vertex(p10)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	a.stats["meshes"] = int(a.stats["meshes"]) + 1
	return mi

## 披在家具上的旧布（防尘罩）：中间拱起、四角垂下
func dust_sheet(center: Vector3, sx: float, sz: float, mat: Material, seed := 0.0) -> MeshInstance3D:
	var nx := 18
	var nz := 20
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for j in range(nz + 1):
		var v := float(j) / float(nz)
		var row: Array = []
		for i in range(nx + 1):
			var u := float(i) / float(nx)
			var x := (u - 0.5) * sx
			var z := (v - 0.5) * sz
			# 布搭成拱：越靠边越往下垂
			var edge := minf(minf(u, 1.0 - u) * 2.0, minf(v, 1.0 - v) * 2.0)
			var sag := -0.11 * pow(1.0 - clampf(edge, 0.0, 1.0), 2.0)
			var y := 0.16 * (1.0 - pow(maxf(1.0 - edge, 0.0), 1.6)) + sag
			y += sin(u * 9.0 + seed) * 0.012 + sin(v * 11.0 + seed * 2.0) * 0.010
			row.append(Vector3(x, y, z))
		rows.append(row)
	for j in range(nz):
		for i in range(nx):
			var p00: Vector3 = rows[j][i]
			var p01: Vector3 = rows[j][i + 1]
			var p10: Vector3 = rows[j + 1][i]
			var p11: Vector3 = rows[j + 1][i + 1]
			st.add_vertex(p00); st.add_vertex(p01); st.add_vertex(p11)
			st.add_vertex(p00); st.add_vertex(p11); st.add_vertex(p10)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = center
	root.add_child(mi)
	a.stats["meshes"] = int(a.stats["meshes"]) + 1
	return mi

## 挂着的一件小衣服（晾衣绳上那 7 件童装）：躯干 + 两只袖子 + 下摆
func garment(pos: Vector3, mat: Material, w := 0.34, hgt := 0.40,
		seed := 0.0, yaw := 0.0) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = yaw
	root.add_child(g)
	# 肩到下摆：一张带弧度的布片
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 10
	var ny := 14
	var rows: Array = []
	for j in range(ny + 1):
		var v := float(j) / float(ny)
		var row: Array = []
		for i in range(nx + 1):
			var u := float(i) / float(nx)
			var ww := w * (0.62 + 0.38 * sin(PI * minf(1.0, 0.25 + v * 0.9)))
			var x := (u - 0.5) * ww
			var z := sin(u * 5.0 + seed) * 0.016 * (0.3 + v) + sin(v * 6.0 + seed) * 0.010
			row.append(Vector3(x, -v * hgt, z))
		rows.append(row)
	for j in range(ny):
		for i in range(nx):
			var p00: Vector3 = rows[j][i]
			var p01: Vector3 = rows[j][i + 1]
			var p10: Vector3 = rows[j + 1][i]
			var p11: Vector3 = rows[j + 1][i + 1]
			st.add_vertex(p00); st.add_vertex(p01); st.add_vertex(p11)
			st.add_vertex(p00); st.add_vertex(p11); st.add_vertex(p10)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	g.add_child(mi)
	# 两只袖子
	for sx in [-1.0, 1.0]:
		var s := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.055, 0.22, 0.022)
		s.mesh = bm
		s.material_override = mat
		s.position = Vector3(sx * (w * 0.52), -0.10, 0.0)
		s.rotation.z = sx * 0.30
		g.add_child(s)
	# 衣架
	var hang := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(w * 0.66, 0.012, 0.012)
	hang.mesh = hb
	hang.material_override = plain(Color(0.55, 0.52, 0.45), 0.5, 0.6)
	hang.position = Vector3(0, 0.012, 0)
	g.add_child(hang)
	return g

## 布上的水渍 / 地上的人形水痕：程序化生成一张 alpha 遮罩
func stain_material(col: Color, alpha := 0.55, kind := "human") -> StandardMaterial3D:
	var key := "stain|%s|%.2f|%s" % [str(col), alpha, kind]
	if a.mats.has(key):
		return a.mats[key]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(n):
		for x in range(n):
			var u := (float(x) + 0.5) / n
			var v := (float(y) + 0.5) / n
			var d := 9.0
			if kind == "human":
				d = _human_dist(u, v)
			else:
				var dx := (u - 0.5) * 2.2
				var dy := (v - 0.5) * 2.2
				d = sqrt(dx * dx + dy * dy) - 0.55 + sin(u * 7.0) * 0.05 + sin(v * 9.0) * 0.05
			var edge := 0.035
			var al := clampf(1.0 - (d - 0.0) / edge, 0.0, 1.0)
			# 内外都要淡一点，边缘才不像剪贴画
			al *= 0.55 + 0.45 * clampf(d / 0.45, 0.0, 1.0)
			var mott := 0.72 + 0.28 * absf(sin(u * 33.0 + v * 21.0) * sin(v * 27.0 - u * 11.0))
			img.set_pixel(x, y, Color(col.r, col.g, col.b, al * alpha * mott))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 1)
	m.roughness = 0.10
	m.metallic = 0.05
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	a.mats[key] = m
	return m

## 人形距离场：躯干椭圆 + 头 + 四肢胶囊（0 = 里面）
func _human_dist(u: float, v: float) -> float:
	# 归一化到 [-1,1]，身体竖直
	var px := (u - 0.5) * 2.0
	var py := (v - 0.5) * 2.0
	var d := 9.0
	# 躯干
	d = minf(d, _ellipse(px, py + 0.10, 0.42, 0.52))
	# 头
	d = minf(d, _ellipse(px, py + 0.78, 0.22, 0.24))
	# 脖子
	d = minf(d, _ellipse(px, py + 0.50, 0.10, 0.14))
	# 手臂（斜向外下）
	d = minf(d, _capsule(px, py, -0.36, -0.10, -0.66, 0.24, 0.15))
	d = minf(d, _capsule(px, py, 0.36, -0.10, 0.66, 0.24, 0.15))
	# 腿
	d = minf(d, _capsule(px, py, -0.20, 0.40, -0.26, 0.94, 0.17))
	d = minf(d, _capsule(px, py, 0.20, 0.40, 0.26, 0.94, 0.17))
	return d

func _ellipse(x: float, y: float, rx: float, ry: float) -> float:
	var d := Vector2(x / maxf(rx, 0.001), y / maxf(ry, 0.001)).length()
	return (d - 1.0) * minf(rx, ry)

func _capsule(x: float, y: float, x0: float, y0: float, x1: float, y1: float, r: float) -> float:
	var p := Vector2(x, y)
	var a0 := Vector2(x0, y0)
	var b := Vector2(x1, y1)
	var ab := b - a0
	var t := clampf((p - a0).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return (p - (a0 + ab * t)).length() - r

## 在一处平面上铺一块水渍
func stain(center: Vector3, size: float, col := Color(0.16, 0.19, 0.19, 1.0),
		alpha := 0.6, kind := "human", yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	mi.material_override = stain_material(col, alpha, kind)
	mi.position = center
	mi.rotation.y = yaw
	mi.set_meta("dynamic", true)     # 透明面不参与合批（顺序会乱）
	root.add_child(mi)
	return mi

# ================================================================ 湿 / 水
## 墙面从下往上湿的一条：贴在墙根，用一层半透明的深色 + 高反光
func wet_band_x(z: float, x0: float, x1: float, y: float, hgt := 0.85,
		face := 1.0) -> void:
	var key := "wetband"
	if not a.mats.has(key):
		var n := 64
		var img := Image.create(4, n, false, Image.FORMAT_RGBA8)
		for j in range(n):
			var v := float(j) / float(n - 1)     # 0 = 底
			var al := pow(1.0 - v, 1.7)
			img.set_pixel(0, j, Color(0.05, 0.06, 0.06, al))
			img.set_pixel(1, j, Color(0.05, 0.06, 0.06, al))
			img.set_pixel(2, j, Color(0.05, 0.06, 0.06, al))
			img.set_pixel(3, j, Color(0.05, 0.06, 0.06, al))
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.06
		m.metallic = 0.15
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		a.mats[key] = m
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(absf(x1 - x0), hgt)
	mi.mesh = pm
	mi.material_override = a.mats[key]
	mi.position = Vector3((x0 + x1) * 0.5, y + hgt * 0.5, z + 0.008 * face)
	mi.set_meta("dynamic", true)
	root.add_child(mi)

## 水面：PlaneMesh + shader（顶点微波动 / 边缘泡沫），mark dynamic 以便动画
func water_surface(center: Vector3, sx: float, sz: float,
		gen: int = 48) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(sx, sz)
	pm.subdivide_width = gen
	pm.subdivide_depth = gen
	mi.mesh = pm
	mi.material_override = water_material()
	mi.position = center
	mi.set_meta("dynamic", true)
	root.add_child(mi)
	return mi

## 地面薄水膜（B1 那 10 cm 的水）：几乎不自发光，只靠反射读“湿”，
## 用它跟蓄水池的深水区分开 —— 否则整层楼都会被染成一片绿。
func thin_film_material() -> ShaderMaterial:
	var key := "thin_film_shader"
	if a.mats.has(key):
		return a.mats[key]
	var code := """
shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform vec3 tint : source_color = vec3(0.10, 0.12, 0.11);
uniform float amp = 0.004;
uniform float wave_speed = 0.6;

void vertex(){
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	VERTEX.y += sin(wp.x * 3.1 + t * 1.2) * amp + sin(wp.z * 2.7 - t * 0.9) * amp * 0.8;
}

void fragment(){
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float n1 = sin(wp.x * 11.0 + t * 2.2) * cos(wp.z * 9.0 - t * 1.8);
	float n2 = sin(wp.x * 23.0 - t * 3.0) * cos(wp.z * 19.0 + t * 2.4);
	vec3 nrm = normalize(vec3(n1 * 0.20 + n2 * 0.07, 1.0, n2 * 0.18 + n1 * 0.06));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);
	ALBEDO = tint;
	ROUGHNESS = 0.075;
	METALLIC = 0.62;
}
"""
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	a.mats[key] = m
	return m

## 水面材质（全工程共用一份，重复调用直接命中缓存）
func water_material() -> ShaderMaterial:
	var key := "water_shader"
	if a.mats.has(key):
		return a.mats[key]
	var code := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec3 deep_col : source_color = vec3(0.008, 0.016, 0.018);
uniform vec3 shallow_col : source_color = vec3(0.05, 0.10, 0.095);
uniform vec3 glow_col : source_color = vec3(0.05, 0.16, 0.13);
uniform float amp = 0.010;
uniform float speed = 0.5;
uniform float glow = 0.012;

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex(){
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * speed;
	VERTEX.y += sin(wp.x * 2.3 + t * 1.7) * amp
	          + sin(wp.z * 3.1 - t * 1.3) * amp * 0.8
	          + sin((wp.x + wp.z) * 5.4 + t * 2.4) * amp * 0.35;
}

void fragment(){
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * speed;
	// 用两层滚动噪声假装法线，读得出“水面在动”
	float n1 = sin(wp.x * 9.0 + t * 2.0) * cos(wp.z * 7.5 - t * 1.6);
	float n2 = sin(wp.x * 21.0 - t * 3.1) * cos(wp.z * 17.0 + t * 2.2);
	vec3 nrm = normalize(vec3(n1 * 0.28 + n2 * 0.10, 1.0, n2 * 0.24 + n1 * 0.09));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = mix(deep_col, shallow_col, clamp(0.35 + n1 * 0.25, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.055;
	METALLIC = 0.55;
	EMISSION = glow_col * (glow + fres * 0.35);
}
"""
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	a.mats[key] = m
	return m

# ================================================================ 夜天 / 星空
## 屋顶用的夜空穹顶：程序化星空贴图 + 内翻球。不影响其他楼层（只有屋顶能看到）。
func sky_dome(center: Vector3, radius := 70.0) -> MeshInstance3D:
	var st := SphereMesh.new()
	st.radius = radius
	st.height = radius * 2.0
	st.radial_segments = 48
	st.rings = 28
	st.is_hemisphere = false
	var mi := MeshInstance3D.new()
	mi.mesh = st
	var m := StandardMaterial3D.new()
	m.albedo_texture = _sky_texture()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.disable_receive_shadows = true
	mi.material_override = m
	mi.position = center
	mi.set_meta("dynamic", true)
	root.add_child(mi)
	return mi

func _sky_texture() -> ImageTexture:
	var key := "skytex"
	if a.mats.has(key):
		return a.mats[key]
	var w := 1024
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	# 竖向渐变：天顶深蓝黑 → 地平线略亮（城市光害）
	for y in range(h):
		var v := float(y) / float(h - 1)          # 0 = 上（天顶）
		var c: Color
		if v < 0.52:
			var t := v / 0.52
			c = Color(0.012, 0.016, 0.032).lerp(Color(0.030, 0.038, 0.062), t)
		else:
			var t2 := (v - 0.52) / 0.48
			c = Color(0.030, 0.038, 0.062).lerp(Color(0.070, 0.066, 0.070), t2)
		for x in range(w):
			img.set_pixel(x, y, c)
	# 星星：按纬度加权（天顶密、地平线稀）
	for i in range(1400):
		# 关键：fmod 会返回负数，所以一律用 absf 归一化到 [0,1) ——
		# 否则 sx 可能为负，`sx % w` 在 GDScript 里仍保留负号，
		# set_pixel 会报 "Index p_x = -154 is out of bounds"。
		var hh := absf(fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0))
		var hh2 := absf(fmod(sin(float(i) * 78.233) * 12345.6789, 1.0))
		var hh3 := absf(fmod(sin(float(i) * 39.425) * 9876.5432, 1.0))
		var sy := clampi(int(hh * h * 0.86), 0, h - 1)
		var sx := clampi(int(hh2 * w), 0, w - 1)
		var bright := 0.25 + 0.75 * hh3 * hh3
		var col := Color(0.82 * bright, 0.86 * bright, 1.0 * bright)
		img.set_pixel(sx % w, sy, col)
		if hh3 > 0.82:
			# 亮星带一点十字光
			for dx in [-1, 1]:
				if sx + dx >= 0 and sx + dx < w:
					img.set_pixel(sx + dx, sy, Color(0.30, 0.34, 0.44))
			if sy + 1 < h:
				img.set_pixel(sx, sy + 1, Color(0.26, 0.30, 0.40))
	# 月亮：一块亮盘 + 光晕
	var mx := int(w * 0.22)
	var my := int(h * 0.20)
	var mr := 15.0
	# 注意 x 的上下界也要夹住（原来只夹了 y，x 会越界到负数 → set_pixel 报
	# "Index p_x = -154 is out of bounds"）。
	for y in range(maxi(0, my - 60), mini(h, my + 60)):
		for x in range(maxi(0, mx - 90), mini(w, mx + 90)):
			if x < 0 or x >= w or y < 0 or y >= h:
				continue
			var d := Vector2(float(x - mx), float(y - my)).length()
			if d < mr:
				img.set_pixel(x, y, Color(0.96, 0.95, 0.88))
			elif d < mr + 26.0:
				var t := 1.0 - (d - mr) / 26.0
				var add := Color(0.20, 0.22, 0.26) * pow(t, 2.2)
				var base := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(base.r + add.r, base.g + add.g, base.b + add.b))
	# 云：几条低空暗带（用低频噪声）
	for y in range(int(h * 0.55), int(h * 0.80)):
		for x in range(w):
			var u := float(x) / w
			var vv := float(y) / h
			var n := sin(u * 18.0 + 1.3) * sin(vv * 26.0) + sin(u * 7.0 - 2.0) * 0.6
			if n > 0.82:
				var base2 := img.get_pixel(x, y)
				var k := 0.5
				img.set_pixel(x, y, Color(base2.r * k + 0.010, base2.g * k + 0.011, base2.b * k + 0.014))
	var tex := ImageTexture.create_from_image(img)
	a.mats[key] = tex
	return tex

# ================================================================ 小道具（复用率最高的几件）
## 墙面水表：一个小圆盘 + 表体 + 两根细管
func water_meter(pos: Vector3, yaw := 0.0, plate := Color(0.78, 0.76, 0.70)) -> void:
	var g := a.push_group(pos, yaw)
	a.box(Vector3(0, 0, 0.05), Vector3(0.17, 0.17, 0.09), plain(Color(0.30, 0.28, 0.25), 0.5, 0.5))
	a.cyl(Vector3(0, 0, 0.10), 0.072, 0.012, plain(plate, 0.35), 16, "z")
	a.box(Vector3(0.02, 0.01, 0.107), Vector3(0.010, 0.048, 0.006), plain(Color(0.14, 0.13, 0.12), 0.7), false, 0.5)
	var pip := plain(Color(0.42, 0.38, 0.32), 0.45, 0.7)
	a.cyl(Vector3(0, -0.135, 0.05), 0.016, 0.16, pip, 8)
	a.cyl(Vector3(0, 0.135, 0.05), 0.016, 0.16, pip, 8)
	a.pop_group()

## 老式暖气片：一排立片 + 上下两根横管
func radiator(pos: Vector3, width := 1.0, hgt := 0.62, yaw := 0.0,
		mat: Material = null) -> void:
	var m := mat if mat != null else pbr("painted_concrete", 1.4, Color(0.74, 0.72, 0.66), 0.7)
	var g := a.push_group(pos, yaw)
	var n := int(width / 0.075)
	for i in range(n):
		var x := -width * 0.5 + (float(i) + 0.5) * (width / float(n))
		a.box(Vector3(x, 0, 0), Vector3(0.045, hgt, 0.10), m, false)
	a.box(Vector3(0, hgt * 0.45, 0), Vector3(width, 0.045, 0.11), m, false)
	a.box(Vector3(0, -hgt * 0.45, 0), Vector3(width, 0.045, 0.11), m, false)
	a.pop_group()

## 窗（墙垂直于 Z，窗朝 ±Z）
func window_x(z: float, x_center: float, y0: float, w := 1.0, h := 1.25,
		frame_mat: Material = null, night_mat: Material = null, face := 1.0) -> void:
	var fm := frame_mat if frame_mat != null else pbr("oak_wood_planks", 1.6,
		Color(0.34, 0.27, 0.19), 0.62)
	var nm := night_mat if night_mat != null else plain(Color(0.020, 0.026, 0.038), 0.95)
	# 窗洞外的夜色板（比墙深一层，读作“外面是夜”）
	a.box(Vector3(x_center, y0 + h * 0.5, z), Vector3(w + 0.10, h + 0.10, 0.03), nm, false)
	# 玻璃
	a.box(Vector3(x_center, y0 + h * 0.5, z + 0.03), Vector3(w, h, 0.012),
		glass(Color(0.30, 0.36, 0.44, 0.16)), false)
	# 窗框 + 中挺
	a.box(Vector3(x_center, y0 + h * 0.5, z + 0.045), Vector3(w + 0.10, 0.055, 0.055), fm, false)
	a.box(Vector3(x_center, y0 + h + 0.03, z + 0.045), Vector3(w + 0.16, 0.07, 0.09), fm, false)
	a.box(Vector3(x_center, y0 - 0.03, z + 0.045), Vector3(w + 0.16, 0.07, 0.09), fm, false)
	a.box(Vector3(x_center - w * 0.5 - 0.04, y0 + h * 0.5, z + 0.045), Vector3(0.07, h, 0.09), fm, false)
	a.box(Vector3(x_center + w * 0.5 + 0.04, y0 + h * 0.5, z + 0.045), Vector3(0.07, h, 0.09), fm, false)
	a.box(Vector3(x_center, y0 + h * 0.5, z + 0.045), Vector3(0.05, h, 0.07), fm, false)
	# 窗台
	a.box(Vector3(x_center, y0 - 0.06, z + 0.08 * face), Vector3(w + 0.24, 0.05, 0.20), fm, false)

## 窗（墙垂直于 X，窗朝 ±X）
func window_z(x: float, z_center: float, y0: float, w := 1.0, h := 1.25,
		frame_mat: Material = null, night_mat: Material = null, face := 1.0) -> void:
	var fm := frame_mat if frame_mat != null else pbr("oak_wood_planks", 1.6,
		Color(0.34, 0.27, 0.19), 0.62)
	var nm := night_mat if night_mat != null else plain(Color(0.020, 0.026, 0.038), 0.95)
	a.box(Vector3(x, y0 + h * 0.5, z_center), Vector3(0.03, h + 0.10, w + 0.10), nm, false)
	a.box(Vector3(x + 0.03 * face, y0 + h * 0.5, z_center), Vector3(0.012, h, w),
		glass(Color(0.30, 0.36, 0.44, 0.16)), false)
	a.box(Vector3(x + 0.045 * face, y0 + h * 0.5, z_center), Vector3(0.055, 0.055, w + 0.10), fm, false)
	a.box(Vector3(x + 0.045 * face, y0 + h + 0.03, z_center), Vector3(0.09, 0.07, w + 0.16), fm, false)
	a.box(Vector3(x + 0.045 * face, y0 - 0.03, z_center), Vector3(0.09, 0.07, w + 0.16), fm, false)
	a.box(Vector3(x + 0.045 * face, y0 + h * 0.5, z_center - w * 0.5 - 0.04), Vector3(0.09, h, 0.07), fm, false)
	a.box(Vector3(x + 0.045 * face, y0 + h * 0.5, z_center + w * 0.5 + 0.04), Vector3(0.09, h, 0.07), fm, false)
	a.box(Vector3(x + 0.045 * face, y0 + h * 0.5, z_center), Vector3(0.07, h, 0.05), fm, false)
	a.box(Vector3(x + 0.08 * face, y0 - 0.06, z_center), Vector3(0.20, 0.05, w + 0.24), fm, false)

## 贴在墙上的纸（公告、疏散图、电路图）：一张纸 + 一点翘角
func paper_sign(center: Vector3, w: float, h: float, col: Color, yaw := 0.0,
		axis := "x") -> void:
	var m := plain(col, 0.95)
	if axis == "x":
		a.box(center, Vector3(w, h, 0.006), m, false)
		a.box(center + Vector3(w * 0.42, -h * 0.42, 0.004), Vector3(w * 0.16, h * 0.16, 0.004),
			plain(col.darkened(0.25), 0.95), false, 0.5)
	else:
		a.box(center, Vector3(0.006, h, w), m, false)
		a.box(center + Vector3(0.004, -h * 0.42, w * 0.42), Vector3(0.004, h * 0.16, w * 0.16),
			plain(col.darkened(0.25), 0.95), false, 0.5)

## 门牌：小金属片 + 数字
func door_plate(pos: Vector3, text: String, yaw := 0.0, hgt := 0.10) -> void:
	var g := a.push_group(pos, yaw)
	a.box(Vector3.ZERO, Vector3(0.17, hgt, 0.012), plain(Color(0.62, 0.58, 0.48), 0.4, 0.7))
	a.pop_group()
	var l := a.label(text, pos + Vector3(0, 0, 0.012), hgt * 0.62,
		Color(0.10, 0.09, 0.08), yaw, 34)

## 挂锁（老周门上那种）
func padlock(pos: Vector3, yaw := 0.0, size := 1.0) -> void:
	var brass := plain(Color(0.62, 0.52, 0.30), 0.35, 0.85)
	var dark := plain(Color(0.16, 0.15, 0.14), 0.5, 0.6)
	var g := a.push_group(pos, yaw)
	a.box(Vector3.ZERO, Vector3(0.052 * size, 0.062 * size, 0.022 * size), brass)
	a.cyl(Vector3(0, 0.040 * size, 0), 0.017 * size, 0.050 * size,
		dark, 10, "z")
	a.pop_group()

# ================================================================ 合批
## 与 laundry_main 的调用保持一致：一层建完再合一次。
func merge() -> Dictionary:
	return a.merge_static()
