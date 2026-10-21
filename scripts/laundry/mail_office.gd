extends RefCounted
## 廊桥 + 老邮局（剧本 v2 区域 2-d）
## ---------------------------------------------------------------------------
## 尺寸：1.2 宽 × 26 长 × 2.4 高，横跨到隔壁的「老邮局」楼。
## 位置：2F 东侧，z = +10 起。
## 状态：地板锈穿 4 块，要走过去必须蹲着贴边走。
## 终点：老邮局 2F（空房间，只有一排没投出去的邮筒）。
##
## 这里有什么：2004 年 11 月 8 日以后，所有寄往「老街 27 号」的信都被退回到这里。
## 一整个房间。最重要的：一封寄给「周秀兰」的挂号信，没拆过。
## 里面是一张儿童医院的出院小结，日期 2004-11-06，患者姓名处写着「周小满，男，6 岁」。
##
## 坐标：主楼东墙 x = +3.2。廊桥从 x=3.2 往东跨到 x=13.2（26 m 太长，
##       按剧本「横跨到隔壁楼」收成 10 m 更合理，老邮局楼在 x 13.2…22.0）。

const A := preload("res://scripts/laundry/laundry_art.gd")
const KIT := preload("res://scripts/laundry/laundry_kit.gd")

const Y2 := 3.5             # 2F 地面标高（廊桥面同高）
const BR_X0 := 3.2          # 起点（主楼东墙）
const BR_X1 := 13.2         # 终点（老邮局西墙）
const BR_Z := 10.0          # 廊桥的 z 位置（中心）
const BR_W := 1.2           # 宽
const BR_H := 2.4           # 净高

const PO_X0 := 13.2         # 老邮局
const PO_X1 := 21.0
const PO_Z0 := 4.0
const PO_Z1 := 16.0
const PO_H := 3.05          # 净高（2F 楼板 3.5 → 3F 楼板 6.9，可用净高 3.4 减楼板厚 0.3 = 3.1；
                            # 取 3.05 留缝隙，避免与 3F 楼板重合）

var a: LaundryArt
var k: LaundryKit
var lights: Dictionary = {}

func _init(art: LaundryArt) -> void:
	a = art
	k = KIT.new(art)

func build() -> void:
	_materials()
	_bridge()
	_post_office()
	_post_office_fixtures()
	_mail_room()
	_lights()

var m_wall: StandardMaterial3D
var m_floor: StandardMaterial3D
var m_rust: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_paper: StandardMaterial3D
var m_wood: StandardMaterial3D

func _materials() -> void:
	m_wall = k.pbr("brick_wall_04", 0.20, Color(0.40, 0.36, 0.32), 1.0, 0.0, 1.0)
	m_floor = k.pbr("metal_grate_rusty", 0.9, Color(0.46, 0.42, 0.36), 0.9, 0.5, 1.1)
	m_rust = k.pbr("rusty_metal", 0.8, Color(0.56, 0.46, 0.36), 1.0, 0.3)
	m_metal = k.pbr("metal_plate", 1.3, Color(0.40, 0.40, 0.39), 0.6, 0.65)
	m_dark = k.plain(Color(0.032, 0.032, 0.036), 0.95)
	# 老邮局：1998 年的绿色墙漆 + 旧水磨石地面
	m_wood = k.pbr("wood_planks_dirt", 1.1, Color(0.34, 0.27, 0.20), 0.9)
	m_paper = k.plain(Color(0.80, 0.77, 0.66), 0.95)

# ================================================================ 廊桥
func _bridge() -> void:
	var z0 := BR_Z - BR_W * 0.5
	var z1 := BR_Z + BR_W * 0.5
	var cx := (BR_X0 + BR_X1) * 0.5
	var ln := BR_X1 - BR_X0

	# —— 地板：锈穿的钢板网。4 块是破的（剧本写死）
	var holes := [0.18, 0.36, 0.55, 0.78]      # 沿桥长的相对位置
	var seg := 26
	var prev_x := BR_X0
	for i in range(seg):
		var x0 := BR_X0 + ln * float(i) / float(seg)
		var x1 := BR_X0 + ln * float(i + 1) / float(seg)
		var broken := false
		for hp in holes:
			var hx: float = BR_X0 + ln * hp
			if hx >= x0 and hx < x1:
				broken = true
		if broken:
			# 破洞：只留两根边梁，中间是空的（蹲着贴边走才过得去）
			a.box(Vector3((x0 + x1) * 0.5, Y2 - 0.03, z0 + 0.10),
				Vector3(x1 - x0, 0.06, 0.20), m_rust, false)
			a.box(Vector3((x0 + x1) * 0.5, Y2 - 0.03, z1 - 0.10),
				Vector3(x1 - x0, 0.06, 0.20), m_rust, false)
			# 断掉的栏杆一段（往下垂）
			a.box(Vector3((x0 + x1) * 0.5, Y2 + 0.95, z0 + 0.04),
				Vector3(x1 - x0, 0.06, 0.04), m_rust, false, 0.3)
		else:
			a.box(Vector3((x0 + x1) * 0.5, Y2 - 0.03, BR_Z),
				Vector3(x1 - x0, 0.06, BR_W), m_floor, true)
		prev_x = x1

	# —— 两侧护栏（下半是实心板，上半是竖栏杆）—— 老楼的铁廊桥
	for sz: float in [-1.0, 1.0]:
		var zz: float = BR_Z + sz * (BR_W * 0.5 - 0.03)
		# 底部实心护板
		a.box(Vector3(cx, Y2 + 0.30, zz), Vector3(ln, 0.60, 0.05), m_rust, true)
		# 顶部扶手
		k.pipe(Vector3(BR_X0, Y2 + 1.05, zz), Vector3(BR_X1, Y2 + 1.05, zz), 0.030, m_rust, 10)
		# 竖栏杆（每 0.8 m）
		var n := int(ln / 0.8)
		for i in range(n + 1):
			var xx: float = BR_X0 + ln * float(i) / float(n)
			k.pipe(Vector3(xx, Y2 + 0.60, zz), Vector3(xx, Y2 + 1.05, zz), 0.018, m_rust, 6)

	# —— 顶棚（铁皮，一半塌了）
	a.box(Vector3(cx, Y2 + BR_H, BR_Z), Vector3(ln, 0.08, BR_W + 0.10), m_rust, false)
	# 塌掉的那一块：露出夜空
	a.box(Vector3(BR_X0 + ln * 0.62, Y2 + BR_H + 0.02, BR_Z),
		Vector3(ln * 0.16, 0.06, BR_W + 0.10), m_dark, false)
	# 顶部横撑（每 2 m）
	for i in range(int(ln / 2.0) + 1):
		var xx2: float = BR_X0 + 2.0 * float(i)
		if xx2 > BR_X1:
			break
		a.box(Vector3(xx2, Y2 + BR_H - 0.10, BR_Z), Vector3(0.10, 0.14, BR_W + 0.10), m_metal, false)
	# 两侧立柱（每 2 m）
	for i in range(int(ln / 2.0) + 1):
		var xx3: float = BR_X0 + 2.0 * float(i)
		if xx3 > BR_X1:
			break
		for sz2: float in [-1.0, 1.0]:
			k.pipe(Vector3(xx3, Y2, BR_Z + sz2 * (BR_W * 0.5 - 0.03)),
				Vector3(xx3, Y2 + BR_H, BR_Z + sz2 * (BR_W * 0.5 - 0.03)), 0.040, m_metal, 8)

# ================================================================ 老邮局外壳
func _post_office() -> void:
	var cx := (PO_X0 + PO_X1) * 0.5
	var cz := (PO_Z0 + PO_Z1) * 0.5
	var w := PO_X1 - PO_X0
	var d := PO_Z1 - PO_Z0
	# 地面 / 天花
	# 老邮局地面：旧水磨石（不是铁网！之前误用了廊桥的锈铁材质，整间黑的）
	var po_floor := a.tile_mat(0.32, Color(0.70, 0.69, 0.64), Color(0.30, 0.30, 0.27))
	k.slab(PO_X0, PO_Z0, PO_X1, PO_Z1, Y2, po_floor)
	# 天花板必须用**实体**楼板：只画一张朝下的 quad 的话，
	# 从廊桥那个洞口斜看会直接看穿到星空穹顶（老邮局第一次渲染就是这样）。
	# 天花板：不用 slab_solid（它只画上下两面，没有侧面 ——
	# 从廊桥洞口斜看进来会擦过侧边穿到星空）。
	# 用四面矮墙围一圈 + 一张朝下的顶面，做成真正的“盒底”。
	var ceil_y: float = Y2 + PO_H
	var ceil_m := k.plain(Color(0.52, 0.50, 0.46), 0.95)
	var ceil_edge := k.plain(Color(0.34, 0.34, 0.32), 0.95)
	a.quad_xz(PO_X0, PO_Z0, PO_X1, PO_Z1, ceil_y, ceil_m, false)
	# 天花板上方的实体（四面围一圈，把楼板厚度读出来，也挡住看向天空的视线）
	a.box(Vector3((PO_X0 + PO_X1) * 0.5, ceil_y + 0.16, PO_Z0 - 0.05),
		Vector3(PO_X1 - PO_X0 + 0.20, 0.32, 0.10), ceil_edge, false)
	a.box(Vector3((PO_X0 + PO_X1) * 0.5, ceil_y + 0.16, PO_Z1 + 0.05),
		Vector3(PO_X1 - PO_X0 + 0.20, 0.32, 0.10), ceil_edge, false)
	a.box(Vector3(PO_X0 - 0.05, ceil_y + 0.16, (PO_Z0 + PO_Z1) * 0.5),
		Vector3(0.10, 0.32, PO_Z1 - PO_Z0), ceil_edge, false)
	a.box(Vector3(PO_X1 + 0.05, ceil_y + 0.16, (PO_Z0 + PO_Z1) * 0.5),
		Vector3(0.10, 0.32, PO_Z1 - PO_Z0), ceil_edge, false)
	# 顶面（朝上，挡住从上方看进来的视线）
	a.quad_xz(PO_X0, PO_Z0, PO_X1, PO_Z1, ceil_y + 0.32, k.plain(Color(0.22, 0.22, 0.21), 0.95))
	# 四面墙：老邮局是 1998 年的绿漆墙 + 水磨石地面
	var po_wall := k.pbr("painted_plaster_wall", 0.30, Color(0.62, 0.66, 0.58), 0.95, 0.0, 0.5)
	k.wall_x(PO_Z0 - 0.10, PO_X0, PO_X1, Y2, PO_H, po_wall, 0.20)
	k.wall_x(PO_Z1 + 0.10, PO_X0, PO_X1, Y2, PO_H, po_wall, 0.20)
	k.wall_z(PO_X1 + 0.10, PO_Z0, PO_Z1, Y2, PO_H, po_wall, 0.20)
	# 西墙：廊桥那个洞口要留着
	k.wall_z(PO_X0 - 0.10, PO_Z0, BR_Z - BR_W * 0.5, Y2, PO_H, po_wall, 0.20)
	k.wall_z(PO_X0 - 0.10, BR_Z + BR_W * 0.5, PO_Z1, Y2, PO_H, po_wall, 0.20)
	a.box(Vector3(PO_X0 - 0.10, Y2 + BR_H + (PO_H - BR_H) * 0.5, BR_Z),
		Vector3(0.20, PO_H - BR_H, BR_W), po_wall, false)
	# 墙裙（老邮局的绿漆墙裙）
	for zz: float in [PO_Z0 + 0.02, PO_Z1 - 0.02]:
		a.box(Vector3(cx, Y2 + 0.55, zz), Vector3(w, 1.10, 0.04),
			k.pbr("painted_plaster_wall", 0.5, Color(0.30, 0.40, 0.34), 0.9), false)
	# 老邮局招牌（墙上褪色的「邮政」二字）
	a.box(Vector3(cx, Y2 + 2.60, PO_Z1 - 0.06), Vector3(2.20, 0.50, 0.03),
		k.plain(Color(0.60, 0.58, 0.50), 0.9), false)
	a.label("老 邮 局", Vector3(cx, Y2 + 2.60, PO_Z1 - 0.08), 0.20,
		Color(0.28, 0.34, 0.30), 0.0, 30)

# ================================================================ 老邮局的柜台与设施
func _post_office_fixtures() -> void:
	var cx := (PO_X0 + PO_X1) * 0.5
	# —— 邮局柜台：一长条（靠东墙），上面有铁栅栏（1998 年的窗口）
	var bx := PO_X1 - 1.15
	var cz := (PO_Z0 + PO_Z1) * 0.5
	var wood := k.pbr("wood_planks_dirt", 1.2, Color(0.36, 0.28, 0.20), 0.9)
	var steel := k.pbr("metal_plate", 1.3, Color(0.44, 0.44, 0.43), 0.6, 0.7)
	# 柜台台面
	a.box(Vector3(bx, Y2 + 1.05, cz), Vector3(0.90, 0.09, 6.40), wood, true)
	# 柜台前裙板
	a.box(Vector3(bx + 0.36, Y2 + 0.52, cz), Vector3(0.06, 1.00, 6.40), wood)
	# 铁栅栏（柜台后面那道，从台面到天花板）
	for i in range(9):
		var zz: float = cz - 2.6 + float(i) * 0.65
		k.pipe(Vector3(bx - 0.40, Y2 + 1.14, zz), Vector3(bx - 0.40, Y2 + 2.75, zz),
			0.016, steel, 6)
	a.box(Vector3(bx - 0.40, Y2 + 2.78, cz), Vector3(0.05, 0.05, 6.40), steel)
	# 柜台上的营业牌（「已停业」）
	a.box(Vector3(bx + 0.10, Y2 + 1.16, cz + 1.4), Vector3(0.30, 0.20, 0.02),
		k.plain(Color(0.74, 0.70, 0.58), 0.9), false, 0.15)
	a.label("停止营业", Vector3(bx + 0.10, Y2 + 1.16, cz + 1.38), 0.055,
		Color(0.34, 0.26, 0.20), -PI * 0.5, 26)
	# —— 墙上的旧海报（1998 年的「邮政储蓄」）
	a.box(Vector3(PO_X0 + 0.08, Y2 + 2.10, cz - 4.0), Vector3(0.04, 1.10, 0.80),
		k.plain(Color(0.72, 0.68, 0.56), 0.9), false)
	a.label("邮政储蓄", Vector3(PO_X0 + 0.10, Y2 + 2.30, cz - 4.0), 0.11,
		Color(0.30, 0.32, 0.28), -PI * 0.5, 30)
	# —— 排队的隔栏（地面上的一排立杆 + 横带）
	for i in range(5):
		var zz2: float = PO_Z0 + 3.0 + float(i) * 1.6
		k.pipe(Vector3(cx - 1.0, Y2, zz2), Vector3(cx - 1.0, Y2 + 1.00, zz2), 0.028, steel, 8)
		k.pipe(Vector3(cx - 1.0, Y2 + 0.95, zz2), Vector3(cx - 1.0, Y2 + 0.95, zz2 + 1.6),
			0.012, k.plain(Color(0.42, 0.34, 0.26), 0.9), 6)
	# —— 墙角的包裹架（空架子，1998 年的铁架）
	for i in range(3):
		var yy: float = Y2 + 0.45 + float(i) * 0.55
		a.box(Vector3(PO_X0 + 0.55, yy, PO_Z0 + 1.5), Vector3(0.90, 0.04, 2.20), steel)
	for sx in [-0.42, 0.42]:
		for sz in [-1.05, 1.05]:
			k.pipe(Vector3(PO_X0 + 0.55 + sx, Y2, PO_Z0 + 1.5 + sz),
				Vector3(PO_X0 + 0.55 + sx, Y2 + 1.75, PO_Z0 + 1.5 + sz), 0.022, steel, 6)

# ================================================================ 退回的信（主房间）
## 「2004 年 11 月 8 日以后，所有寄往老街 27 号的信都被退回到这里。一整个房间。」
func _mail_room() -> void:
	var cx := (PO_X0 + PO_X1) * 0.5
	var cz := (PO_Z0 + PO_Z1) * 0.5
	# —— 一排没投出去的邮筒（靠北墙，6 个）
	for i in range(6):
		var px: float = PO_X0 + 1.4 + float(i) * 1.25
		var pz: float = PO_Z0 + 0.70
		# 筒身
		a.cyl(Vector3(px, Y2 + 0.55, pz), 0.26, 1.10,
			k.pbr("painted_concrete", 1.4, Color(0.26, 0.42, 0.32), 0.72), 18)
		# 顶盖
		a.cyl(Vector3(px, Y2 + 1.14, pz), 0.28, 0.08,
			k.pbr("painted_concrete", 1.4, Color(0.22, 0.36, 0.28), 0.7), 18)
		# 投信口（深色）
		a.box(Vector3(px, Y2 + 0.95, pz - 0.255), Vector3(0.26, 0.035, 0.02), m_dark, false)
		# 编号
		a.label(str(1 + i), Vector3(px, Y2 + 0.72, pz - 0.262), 0.075,
			Color(0.82, 0.80, 0.70), 0.0, 26)
	# —— 退回的信：地上一大堆、几摞码在墙边、还有散在邮筒上的
	#     用「一叠叠纸」表达，每叠 6~10 封
	var stacks := [
		[Vector3(PO_X0 + 2.6, Y2, PO_Z1 - 1.4), 0.42, 0.30, 18],
		[Vector3(PO_X0 + 3.4, Y2, PO_Z1 - 1.5), 0.38, 0.34, 14],
		[Vector3(PO_X0 + 4.7, Y2, PO_Z1 - 1.2), 0.46, 0.32, 22],
		[Vector3(PO_X0 + 5.6, Y2, PO_Z1 - 1.6), 0.36, 0.26, 12],
		[Vector3(PO_X0 + 1.6, Y2, PO_Z1 - 2.4), 0.40, 0.30, 16],
		[Vector3(PO_X1 - 1.6, Y2, PO_Z1 - 1.3), 0.44, 0.30, 20],
		[Vector3(PO_X1 - 1.4, Y2, PO_Z0 + 1.9), 0.50, 0.36, 24],
	]
	for st: Array in stacks:
		var base: Vector3 = st[0]
		var sw: float = st[1]
		var sd: float = st[2]
		var cnt: int = st[3]
		for i in range(cnt):
			var hh: float = 0.010
			var off_x: float = fmod(float(i) * 0.0037, 0.02) - 0.01
			var off_z: float = fmod(float(i) * 0.0051, 0.02) - 0.01
			a.box(base + Vector3(off_x, 0.006 + hh * float(i), off_z),
				Vector3(sw, hh, sd), m_paper, false, fmod(float(i) * 0.031, 0.12))
	# 散落在地上的单封信（几十封）
	for i in range(46):
		var px2: float = PO_X0 + 0.6 + fmod(float(i) * 1.87, PO_X1 - PO_X0 - 1.2)
		var pz2: float = PO_Z0 + 1.6 + fmod(float(i) * 2.41, PO_Z1 - PO_Z0 - 2.4)
		a.box(Vector3(px2, Y2 + 0.004, pz2), Vector3(0.22, 0.004, 0.11),
			m_paper, false, fmod(float(i) * 0.73, PI))
	# —— 那封挂号信：单独放在一张小桌上，灯只照它一个
	var tx := cx + 1.6
	var tz := cz + 2.2
	a.bev(Vector3(tx, Y2 + 0.74, tz), Vector3(0.80, 0.04, 0.55), m_wood, 0.008, true)
	for lx: float in [-0.32, 0.32]:
		for lz: float in [-0.20, 0.20]:
			a.box(Vector3(tx + lx, Y2 + 0.36, tz + lz), Vector3(0.04, 0.72, 0.04), m_wood)
	# 挂号信本体（比普通信厚、有红色挂号条）
	a.box(Vector3(tx, Y2 + 0.772, tz), Vector3(0.24, 0.010, 0.16), m_paper, false)
	a.box(Vector3(tx, Y2 + 0.779, tz), Vector3(0.06, 0.002, 0.16),
		k.plain(Color(0.62, 0.14, 0.11), 0.9), false)
	# 桌上的台灯（一盏小灯，只照这封信）
	a.cyl(Vector3(tx - 0.30, Y2 + 0.80, tz + 0.18), 0.06, 0.03, m_metal, 12, "y")
	a.cyl(Vector3(tx - 0.30, Y2 + 0.95, tz + 0.18), 0.010, 0.30, m_metal, 6)
	a.cyl(Vector3(tx - 0.30, Y2 + 1.10, tz + 0.14), 0.09, 0.08,
		k.emit(Color(1.0, 0.82, 0.55), 1.6), 12)
	lights["lamp"] = a.omni(Vector3(tx - 0.28, Y2 + 1.02, tz + 0.10),
		Color(1.0, 0.80, 0.52), 1.35, 2.8, true)
	# —— 窗口（西墙、北墙各一扇，透进月光）
	k.window_z(PO_X0 + 0.06, cz - 2.0, Y2 + 0.9, 1.0, 1.2,
		m_metal, k.plain(Color(0.05, 0.053, 0.062), 0.9), 1.0)
	k.window_x(PO_Z1 - 0.06, cx + 2.2, Y2 + 0.9, 1.0, 1.2,
		m_metal, k.plain(Color(0.05, 0.053, 0.062), 0.9), -1.0)

# ================================================================ 灯
func _lights() -> void:
	# 廊桥：只有中间一盏快坏了的灯（剧本没写灯，但完全黑没法走）
	a.omni(Vector3((BR_X0 + BR_X1) * 0.5, Y2 + BR_H - 0.35, BR_Z),
		Color(1.0, 0.72, 0.44), 1.55, 7.0, false)
	# 廊桥两端的窗光
	a.omni(Vector3(BR_X0 + 1.0, Y2 + 1.6, BR_Z), Color(0.62, 0.72, 0.92), 0.75, 3.5, false)
	a.omni(Vector3(BR_X1 - 1.0, Y2 + 1.6, BR_Z), Color(0.62, 0.72, 0.92), 0.75, 3.5, false)
	# 老邮局：无顶灯，只有月光 + 桌上那盏（_mail_room 里已加）
	var cx := (PO_X0 + PO_X1) * 0.5
	var cz := (PO_Z0 + PO_Z1) * 0.5
	a.omni(Vector3(cx - 2.0, Y2 + 2.2, cz - 3.0), Color(0.56, 0.66, 0.88), 1.65, 9.0, false)
	a.omni(Vector3(cx + 3.0, Y2 + 2.0, cz + 3.5), Color(0.52, 0.60, 0.80), 1.20, 7.5, false)
	# 老邮局的日光灯（那年头邮局用的是冷白日光灯，两根灯管，一根坏了）
	a.box(Vector3(cx - 1.0, Y2 + PO_H - 0.10, cz - 1.5), Vector3(1.60, 0.08, 0.16),
		k.plain(Color(0.60, 0.60, 0.56), 0.8), false)
	a.box(Vector3(cx - 1.0, Y2 + PO_H - 0.16, cz - 1.5), Vector3(1.50, 0.04, 0.10),
		k.emit(Color(0.86, 0.92, 1.0), 1.9), false)
	a.omni(Vector3(cx - 1.0, Y2 + PO_H - 0.45, cz - 1.5), Color(0.82, 0.90, 1.0), 2.55, 9.0, true)
	# 第二根亮着的（靠门口那边）
	a.box(Vector3(cx - 1.0, Y2 + PO_H - 0.10, cz + 3.2), Vector3(1.60, 0.08, 0.16),
		k.plain(Color(0.60, 0.60, 0.56), 0.8), false)
	a.box(Vector3(cx - 1.0, Y2 + PO_H - 0.16, cz + 3.2), Vector3(1.50, 0.04, 0.10),
		k.emit(Color(0.86, 0.92, 1.0), 1.9), false)
	a.omni(Vector3(cx - 1.0, Y2 + PO_H - 0.45, cz + 3.2), Color(0.82, 0.90, 1.0), 2.20, 8.5, true)
