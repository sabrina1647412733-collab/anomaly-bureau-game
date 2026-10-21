extends RefCounted
## 4F ｜ 唯一活着的一层
## ---------------------------------------------------------------------------
## 剧本 v2 区域 4（300 m²）：这一层是给玩家“喘气”的。有人、有灯、有声音。
## 也正因为如此，它最可疑。
##
## 布局（世界坐标，走廊沿用 3F 的 x −3.2…3.2 / z 5.4…11.0）：
##   4F 楼面 y = 9.8，净高 2.6
##   走廊   x −3.2…3.2，z 5.4…11.0   —— 全楼唯一灯是好的
##   402    x −3.2…−0.8，z 2.2…5.4  （2.4 × 3.2）老周家，门上有 5 道锁
##   403    x −0.8…0.8，z 2.6…5.4   （1.6 × 2.8）杂物间
##   401    x  0.8…3.2，z 2.2…5.4   （2.4 × 3.2）空置，只做门（不开）
##
## 美术基准 = 序章出租屋：护墙板 + 木地板 + 暖光池 + 真实 PBR + 门套画框。

const A := preload("res://scripts/laundry/laundry_art.gd")
const KIT := preload("res://scripts/laundry/laundry_kit.gd")

const Y := 9.8
const HH := 2.6
const X0 := -3.2
const X1 := 3.2
const CZ0 := 5.4
const CZ1 := 10.1

var a: LaundryArt
var k: LaundryKit
var lights: Dictionary = {}
var doors: Dictionary = {}
var radio: Node3D = null

func _init(art: LaundryArt) -> void:
	a = art
	k = KIT.new(art)

func build() -> void:
	_materials()
	_corridor()
	_room_402()
	_room_403()
	_room_401()
	_stair_opening()

# ================================================================ 材质
var m_floor: StandardMaterial3D
var m_wall: StandardMaterial3D
var m_ceil: StandardMaterial3D
var m_panel: StandardMaterial3D
var m_rail: StandardMaterial3D
var m_wood: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_paper: StandardMaterial3D
var m_fabric: StandardMaterial3D

func _materials() -> void:
	# 4F 是“唯一还住着人”的一层：暖色木地板 + 上过漆的墙 + 旧木护墙板。
	m_floor = k.pbr("oak_wood_planks", 0.55, Color(0.52, 0.38, 0.27), 0.72, 0.0, 0.85)
	m_wall = k.pbr("painted_plaster_wall", 0.32, Color(0.80, 0.74, 0.64), 0.95, 0.0, 0.5)
	m_ceil = k.plain(Color(0.86, 0.84, 0.79), 0.95)
	m_panel = k.pbr("oak_wood_planks", 0.85, Color(0.40, 0.30, 0.21), 0.70, 0.0, 0.8)
	m_rail = k.pbr("oak_wood_planks", 1.3, Color(0.28, 0.21, 0.14), 0.55)
	m_wood = k.pbr("oak_wood_planks", 1.1, Color(0.46, 0.34, 0.24), 0.72)
	m_dark = k.plain(Color(0.10, 0.093, 0.085), 0.88)
	m_metal = k.pbr("metal_plate", 1.4, Color(0.62, 0.62, 0.60), 0.7, 0.6)
	m_paper = k.plain(Color(0.88, 0.85, 0.75), 0.95)
	m_fabric = k.cloth("rough_linen", Color(0.52, 0.47, 0.40), 2.0)

# ================================================================ 走廊
## 4F 的灯是好的，全楼唯一。这句话要在画面上读得出来：
## 三盏吸顶灯全亮、色温 3200 K、地面有一条亮路。
func _corridor() -> void:
	var zc := (CZ0 + CZ1) * 0.5
	k.slab(X0, CZ0, X1, CZ1, Y, m_floor)
	k.slab_solid(X0, CZ0, X1, CZ1, Y + HH + 0.30, m_ceil, m_ceil)
	# 东西墙
	k.wall_z(X0 - 0.06, CZ0, CZ1, Y, HH, m_wall)
	k.wall_z(X1 + 0.06, CZ0, CZ1, Y, HH, m_wall)
	# 南北墙：北墙是三个房门（门洞要真的挖开，否则从走廊看不见屋里）
	_wall_with_doors(CZ0 - 0.06, m_wall, [-2.10, 0.0, 2.10], 0.90)
	# 南墙不在这里画 —— 它带 2.5 m 楼梯洞口，由 _stair_opening() 分段建。
	# （原来这里画了整块，洞口等于白挖，玩家上不去 5F。）
	for cx in [-2.10, 0.0, 2.10]:
		k.door_casing(Vector3(cx, Y, CZ0 - 0.02), 0.90, 2.05, "x",
			k.pbr("oak_wood_planks", 2.0, Color(0.34, 0.25, 0.17), 0.6), 0.12)
		# 门牌
		k.door_plate(Vector3(cx + 0.62, Y + 1.62, CZ0 + 0.10), _plate_num(cx), 0.0, 0.085)

	# 护墙板：出租屋那套。走廊两侧 + 北墙。
	k.wainscot(Vector3(X0 + 0.02, Y, zc), CZ1 - CZ0, 1.02, "z", m_panel, m_rail, 1.0)
	k.wainscot(Vector3(X1 - 0.02, Y, zc), CZ1 - CZ0, 1.02, "z", m_panel, m_rail, -1.0)
	# 护墙板按门洞切段，不能跨过门洞让人穿过板面。
	for span in [[X0,-2.55],[-1.65,-.45],[.45,1.65],[2.55,X1]]:
		k.wainscot(Vector3((span[0]+span[1])*.5,Y,CZ0+.04),span[1]-span[0],1.02,"x",m_panel,m_rail,1.0)
	# 踢脚（沿护墙板底下再压一道深色，读得出墙脚）
	k.skirting_x(CZ0 + 0.015, X0, X1, Y, m_rail, Vector3(0, 0, 0.02))
	k.skirting_x(CZ1 - 0.015, X0, X1, Y, m_rail, Vector3(0, 0, -0.02))

	# 三盏灯全亮 → “这一层有活人”
	for zz in [6.6, 8.5, 10.3]:
		k.ceiling_lamp(Vector3(0.0, Y + HH - 0.03, zz), 2.35, 6.8,
			Color(1.0, 0.82, 0.60), true)
	lights["corridor"] = a.omni(Vector3(0.0, Y + 1.95, 8.3), Color(1.0, 0.84, 0.64), 1.1, 7.5, false)

	# 疏散示意图：标着 B1 有一个「安全出口」，但那里没有出口
	var map_pos := Vector3(X1 - 0.04, Y + 1.72, 7.30)
	k.paper_sign(map_pos, 0.62, 0.46, Color(0.86, 0.85, 0.78), 0.0, "z")
	# 图上的楼栋平面：五条横线（楼层）+ 一条竖线（楼梯井）+ B1 那格红
	var ink := k.plain(Color(0.28, 0.26, 0.22), 0.9)
	for i in range(5):
		var yy: float = -0.18 + 0.09 * float(i)
		a.box(map_pos + Vector3(0.30, yy, 0.008), Vector3(0.021, 0.004, 0.038), ink, false)
	# 楼梯井（一条竖线，穿过五层）
	a.box(map_pos + Vector3(0.42, 0.0, 0.008), Vector3(0.005, 0.36, 0.021), ink, false)
	# 每层三个房间（小方块）
	for i in range(4):
		for j in range(3):
			a.box(map_pos + Vector3(-0.10 + 0.10 * float(j), -0.18 + 0.09 * float(i), 0.008),
				Vector3(0.030, 0.016, 0.021), ink, false)
	# B1 那一层：标着“安全出口”，但那里没有出口 —— 红笔划掉
	a.box(map_pos + Vector3(0.10, -0.22, 0.010), Vector3(0.075, 0.028, 0.008),
		k.plain(Color(0.58, 0.14, 0.11), 0.85), false)
	a.label("疏散示意图", map_pos + Vector3(-0.02, 0.235, -0.42), 0.024,
		Color(0.22, 0.20, 0.17), -PI * 0.5)
	a.label("B1 安全出口", map_pos + Vector3(-0.20, -0.22, 0.012), 0.016,
		Color(0.58, 0.13, 0.10), -PI * 0.5, 20)

	# 走廊尽头：一辆不要的旧椅子 + 一个纸箱（出租屋那种生活痕）
	k.model("props/plastic_monobloc_chair_01", Vector3(-2.75, Y, 10.30), 2.3, 0.86)
	k.model("cardboard_box_01", Vector3(-2.55, Y, 9.70), 0.5, 0.42, Color(0.80, 0.72, 0.60))
	k.model("cardboard_box_01", Vector3(-2.62, Y + 0.40, 9.74), 1.1, 0.34, Color(0.74, 0.66, 0.55))

	# 楼梯口：往 3F 下去（南墙洞口），这里只做过梁与栏杆
	a.box(Vector3(1.55, Y + 2.28, CZ1), Vector3(2.40, 0.32, 0.14), m_wall)
	k.railing(Vector3(0.35, Y, CZ1 - 0.10), Vector3(-0.20, Y, CZ1 - 0.10), 1.02,
		k.plain(Color(0.28, 0.22, 0.16), 0.5, 0.4))

## 按门洞位置把一面墙切成若干段（门洞宽 w，门洞上方补过梁）。
## 这一步必须真的做 —— 只在墙上贴一个门套，从走廊是看不进屋里的。
func _wall_with_doors(z: float, mat: Material, centers: Array, w: float, hgt := HH) -> void:
	var cuts: Array = []
	for cx in centers:
		cuts.append([cx - w * 0.5, cx + w * 0.5])
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var x := X0
	for c in cuts:
		var a0: float = c[0]
		var a1: float = c[1]
		if a0 > x + 0.001:
			k.wall_x(z, x, a0, Y, hgt, mat)
		# 过梁：门洞上方那一段墙
		a.box(Vector3((a0 + a1) * 0.5, Y + hgt - (hgt - 2.05) * 0.5, z),
			Vector3(a1 - a0, hgt - 2.05, 0.12), mat, false)
		x = a1
	if x < X1 - 0.001:
		k.wall_x(z, x, X1, Y, hgt, mat)

func _plate_num(cx: float) -> String:
	if cx < -1.0:
		return "402"
	if cx < 1.0:
		return "403"
	return "401"

# ================================================================ 402 老周家
## 2.4 × 3.2 × 2.6。他是这栋楼里唯一的活人，修水表的。
## 门上有 5 道锁；屋里：一墙的水表、一堆工具、一台收音机（只在播 2004 年的节目）、
## 一张他自己画的全楼管线图。
func _room_402() -> void:
	var x0 := -3.2
	var x1 := -0.8
	var z0 := 2.2
	var z1 := CZ0
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	k.slab(x0, z0, x1, z1, Y + 0.0015, m_floor)
	k.slab_solid(x0, z0, x1, z1, Y + HH + 0.30, m_ceil, m_ceil)
	k.wall_z(x0 - 0.06, z0, z1, Y, HH, m_wall)
	k.wall_z(x1 + 0.06, z0, z1, Y, HH, m_wall)
	k.wall_x(z0 - 0.06, x0, x1, Y, HH, m_wall)
	# 南墙：中间留门洞（门在走廊那侧已经做了门套）
	a.box(Vector3(-2.875,Y+HH*.5,z1+.06),Vector3(.65,HH,.12),m_wall,true)
	a.box(Vector3(-1.225,Y+HH*.5,z1+.06),Vector3(.85,HH,.12),m_wall,true)
	a.box(Vector3(-2.15, Y + 2.30, z1 + 0.06), Vector3(0.90, 0.30, 0.12), m_wall, false)
	k.wainscot(Vector3(x0 + 0.02, Y, cz), z1 - z0, 1.02, "z", m_panel, m_rail, 1.0)
	k.wainscot(Vector3(x1 - 0.02, Y, cz), z1 - z0, 1.02, "z", m_panel, m_rail, -1.0)
	k.wainscot(Vector3(cx, Y, z0 + 0.04), x1 - x0, 1.02, "x", m_panel, m_rail, 1.0)

	# —— 门上的五道锁（408 那个画面：一排铁件，像一把枪的保险）
	k.doors["402"] = k.door_leaf(Vector3(-2.55, Y, CZ0 - 0.03), 0.90, 2.02, 0.0,
		k.pbr("oak_wood_planks", 1.8, Color(0.26, 0.19, 0.13), 0.7))
	var lock_m := k.plain(Color(0.44, 0.42, 0.36), 0.42, 0.85)
	for i in range(5):
		var yy: float = Y + 0.58 + float(i) * 0.29
		var xx: float = -2.05 - (0.02 if i % 2 == 0 else 0.0)
		k.padlock(Vector3(xx, yy, CZ0 - 0.08), 0.0, 1.0 + 0.06 * float(i % 3))
	for yy2 in [Y + 0.52, Y + 1.96]:
		a.box(Vector3(-2.10, yy2, CZ0 - 0.075), Vector3(0.62, 0.055, 0.02), lock_m)
	# 门镜（从里往外看的那种反装）
	a.cyl(Vector3(-2.10, Y + 1.62, CZ0 - 0.09), 0.028, 0.012,
		k.plain(Color(0.72, 0.70, 0.62), 0.15, 0.9), 14, "z")

	# —— 一墙的水表（东墙，9 只 3×3，盘面朝房内）
	#     老周是修水表的：这面墙是他的“工作证”。
	for i in range(9):
		var col := i % 3
		var row := i / 3
		k.water_meter(Vector3(x1 - 0.14, Y + 1.46 - float(row) * 0.34,
			z0 + 0.72 + float(col) * 0.40), PI * 0.5,
			Color(0.80, 0.78, 0.70) if i % 4 != 0 else Color(0.66, 0.64, 0.58))
	var pip := k.pbr("metal_plate", 1.8, Color(0.50, 0.46, 0.38), 0.55, 0.75)
	k.pipe(Vector3(x1 - 0.13, Y + 1.62, z0 + 0.85), Vector3(x1 - 0.13, Y + 0.30, z0 + 0.85), 0.014, pip)
	k.pipe(Vector3(x1 - 0.13, Y + 1.62, z0 + 1.15), Vector3(x1 - 0.13, Y + 0.30, z0 + 1.15), 0.014, pip)
	k.pipe(Vector3(x1 - 0.13, Y + 1.62, z0 + 0.85), Vector3(x1 - 0.13, Y + 1.62, z0 + 1.15), 0.012, pip)

	# —— 工具台（北墙）：木台面 + 抽屉柜 + 台钳 + 一堆工具
	var bench := Vector3(cx - 0.10, Y, z0 + 0.42)
	a.bev(bench + Vector3(0, 0.86, 0), Vector3(1.60, 0.06, 0.62), m_wood, 0.01, true)
	for sx in [-0.68, 0.68]:
		a.box(bench + Vector3(sx, 0.42, 0.22), Vector3(0.06, 0.84, 0.06), m_dark)
	k.model("props/metal_tool_chest", bench + Vector3(-0.45, 0, 0.02), 0.0, 0.62)
	# 台下的抽屉柜 + 一摞零件盒（工作台不能只有两条腿）
	a.bev(bench + Vector3(0.42, 0.34, 0.02), Vector3(0.58, 0.66, 0.50),
		k.pbr("oak_wood_planks", 1.3, Color(0.34, 0.26, 0.18), 0.8), 0.010, true)
	for i in range(3):
		a.box(bench + Vector3(0.42, 0.14 + 0.21 * float(i), 0.28),
			Vector3(0.52, 0.17, 0.02), k.plain(Color(0.28, 0.21, 0.15), 0.85))
		a.cyl(bench + Vector3(0.42, 0.14 + 0.21 * float(i), 0.30),
			0.018, 0.02, k.plain(Color(0.58, 0.54, 0.40), 0.4, 0.8), 8, "z")
	k.model("props/wooden_crate_01", bench + Vector3(0.55, 0.89, 0.0), 0.4, 0.24, Color(0.86, 0.76, 0.62))
	# 台钳
	a.box(bench + Vector3(0.12, 0.95, -0.18), Vector3(0.16, 0.10, 0.12), k.plain(Color(0.26, 0.30, 0.28), 0.45, 0.7))
	a.cyl(bench + Vector3(0.12, 1.02, -0.18), 0.03, 0.10, k.plain(Color(0.30, 0.33, 0.31), 0.4, 0.75), 12)
	# 台面上摊开的工具
	for i in range(4):
		a.box(bench + Vector3(-0.30 + 0.16 * float(i), 0.90, -0.12 + 0.03 * float(i)),
			Vector3(0.035, 0.02, 0.16), k.plain(Color(0.52, 0.50, 0.46), 0.35, 0.8), false,
			0.3 * float(i))

	# —— 收音机：永远开着，只在播 2004 年的节目
	radio = k.model("props/vintage_radio_transceiver", Vector3(cx + 0.62, Y + 0.89, z0 + 0.40), -0.35, 0.30)
	# 指示灯：4F 那盏“错的光”——红
	a.cyl(Vector3(cx + 0.62, Y + 1.02, z0 + 0.56), 0.012, 0.006,
		k.emit(Color(1.0, 0.20, 0.12), 2.2), 10, "z")
	lights["radio"] = a.omni(Vector3(cx + 0.62, Y + 1.06, z0 + 0.60),
		Color(1.0, 0.24, 0.14), 0.55, 2.2, false)
	# 天线
	a.cyl(Vector3(cx + 0.86, Y + 1.20, z0 + 0.40), 0.004, 0.55,
		k.plain(Color(0.55, 0.53, 0.48), 0.4, 0.8), 6)

	# —— 全楼管线图（西墙）：手绘的立管图，B1 那里标着「勿动」。
	#     关键约束：所有线条必须**严格在纸的范围内**。
	#     原来线条长度按 1.14 算，而纸只有 1.02 宽，线头戳到墙上像乱划。
	#     纸面：中心 z = cz+0.30，宽 0.86；y 从 Y+1.07 到 Y+2.09（高 1.02）。
	var map_cz: float = cz + 0.30
	var map_cy: float = Y + 1.58
	var pw := 0.86
	var ph := 1.02
	k.paper_sign(Vector3(x0 + 0.06, map_cy, map_cz), pw, ph, Color(0.90, 0.88, 0.80), 0.0, "z")
	# 图框（内侧留 3 cm 白边）
	var ink := k.plain(Color(0.20, 0.24, 0.30), 0.9)
	var fr := k.plain(Color(0.24, 0.27, 0.32), 0.9)
	a.box(Vector3(x0 + 0.072, map_cy + ph * 0.5 - 0.03, map_cz), Vector3(0.004, 0.006, pw - 0.06), fr)
	a.box(Vector3(x0 + 0.072, map_cy - ph * 0.5 + 0.03, map_cz), Vector3(0.004, 0.006, pw - 0.06), fr)
	a.box(Vector3(x0 + 0.072, map_cy, map_cz - pw * 0.5 + 0.03), Vector3(0.004, ph - 0.06, 0.006), fr)
	a.box(Vector3(x0 + 0.072, map_cy, map_cz + pw * 0.5 - 0.03), Vector3(0.004, ph - 0.06, 0.006), fr)
	# 五条横线 = 五个楼层（严格在框内，长度从 pw-0.14 起递减，做出手画的随意感）
	for i in range(5):
		var yy: float = map_cy - ph * 0.32 + float(i) * 0.13
		var seg_w: float = pw * 0.72 - 0.03 * float(i % 2)
		a.box(Vector3(x0 + 0.074, yy, map_cz), Vector3(0.003, 0.005, seg_w), ink)
	# 立管：四条竖线（从最上层通到 B1）
	for i in range(4):
		var zz: float = map_cz - pw * 0.26 + float(i) * 0.17
		a.box(Vector3(x0 + 0.074, map_cy - 0.02, zz),
			Vector3(0.003, ph * 0.62, 0.005), ink)
	# B1 那一层用红笔划掉 + 手写「勿动」
	var red := k.plain(Color(0.62, 0.14, 0.11), 0.8)
	a.box(Vector3(x0 + 0.076, map_cy - ph * 0.32, map_cz - pw * 0.10),
		Vector3(0.004, ph * 0.20, 0.010), red)
	a.box(Vector3(x0 + 0.076, map_cy - ph * 0.30, map_cz - pw * 0.10),
		Vector3(0.004, 0.008, pw * 0.34), red)
	a.label("勿动", Vector3(x0 + 0.078, map_cy + ph * 0.30, map_cz + pw * 0.20), 0.026,
		Color(0.62, 0.13, 0.10), -PI * 0.5, 22)

	# —— 床：靠西墙，1.0 宽的单人床，被子卷着（修表的人睡觉不脱鞋）
	a.bev(Vector3(x0 + 0.62, Y + 0.24, z0 + 1.30), Vector3(1.06, 0.34, 1.90),
		k.pbr("oak_wood_planks", 1.1, Color(0.34, 0.25, 0.17), 0.8), 0.012, true)
	# 床垫：亚麻布（有织纹），不是一块灰板
	var mattress := k.cloth("rough_linen", Color(0.74, 0.71, 0.64), 2.2)
	var sheet := k.cloth("rough_linen", Color(0.86, 0.85, 0.80), 2.6)
	var quilt := k.cloth("rough_linen", Color(0.56, 0.48, 0.38), 1.6)
	a.box(Vector3(x0 + 0.62, Y + 0.44, z0 + 1.30), Vector3(1.00, 0.10, 1.82), mattress)
	# 铺了一半的白床单（从床头铺到中间，边缘垂下来）
	a.box(Vector3(x0 + 0.62, Y + 0.50, z0 + 0.86), Vector3(1.01, 0.03, 1.10), sheet)
	a.box(Vector3(x0 + 1.13, Y + 0.38, z0 + 0.86), Vector3(0.02, 0.26, 1.10), sheet)
	# 被子：只盖到腰，脚头那一半堆起来（读作“人刚起来”）
	a.box(Vector3(x0 + 0.62, Y + 0.55, z0 + 1.82), Vector3(1.03, 0.14, 0.78), quilt)
	a.box(Vector3(x0 + 0.62, Y + 0.62, z0 + 2.06), Vector3(0.98, 0.12, 0.30),
		k.cloth("rough_linen", Color(0.50, 0.43, 0.34), 1.6))
	# 被子垂到床沿外
	a.box(Vector3(x0 + 1.14, Y + 0.44, z0 + 1.82), Vector3(0.02, 0.30, 0.78), quilt)
	a.box(Vector3(x0 + 0.62, Y + 0.50, z0 + 1.62), Vector3(0.92, 0.10, 0.66),
		k.cloth("rough_linen", Color(0.60, 0.56, 0.47), 2.0))
	# 床头板：老式铁管床头（出租屋那张是同一套语言）
	var iron := k.plain(Color(0.20, 0.19, 0.18), 0.55, 0.55)
	for sx2 in [x0 + 0.20, x0 + 1.04]:
		a.cyl(Vector3(sx2, Y + 0.62, z0 + 0.36), 0.022, 0.76, iron, 8)
	for i in range(3):
		a.cyl(Vector3(x0 + 0.62, Y + 0.52 + 0.22 * float(i), z0 + 0.36),
			0.014, 0.84, iron, 6, "x")
	# 枕头（压痕）
	a.box(Vector3(x0 + 0.62, Y + 0.48, z0 + 0.55), Vector3(0.52, 0.09, 0.30),
		k.cloth("rough_linen", Color(0.78, 0.76, 0.70), 2.4))
	a.box(Vector3(x0 + 0.62, Y + 0.515, z0 + 0.55), Vector3(0.30, 0.012, 0.18),
		k.plain(Color(0.68, 0.66, 0.60), 0.95))

	# —— 一张凳子 + 墙上的旧照片（儿子？）—— 老周每个月上去看一次
	a.box(Vector3(cx + 0.55, Y + 0.24, cz + 1.28), Vector3(0.36, 0.06, 0.36), m_wood)
	for sx in [-0.14, 0.14]:
		for sz2 in [-0.14, 0.14]:
			a.box(Vector3(cx + 0.55 + sx, Y + 0.11, cz + 1.28 + sz2),
				Vector3(0.035, 0.22, 0.035), m_wood)
	k.picture(Vector3(x0 + 0.06, Y + 1.72, cz + 1.30), 0.30, 0.38,
		k.plain(Color(0.62, 0.60, 0.54), 0.9), "z", m_rail, 0.025)

	# —— 暖气片（北墙窗下）+ 窗
	k.window_x(z0, cx, Y + 0.95, 1.05, 1.15, m_rail,
		k.plain(Color(0.055, 0.058, 0.068), 0.9))
	# Blender 版散热器（radiator_01）
	k.model("props/radiator_01", Vector3(cx - 0.10, Y + 0.10, z0 + 0.10), 0.0)

	# —— 灯：3200 K，全楼唯一舒服的地方
	k.ceiling_lamp(Vector3(cx + 0.30, Y + HH - 0.03, cz + 0.30), 2.5, 6.2,
		Color(1.0, 0.84, 0.64), true)
	# 台灯（工具台上，给局部一个光池）
	var lamp := k.model("desk_lamp_arm_01", bench + Vector3(-0.62, 0.89, -0.22), -0.6, 0.52,
		Color(0.90, 0.84, 0.72))
	if lamp != null:
		lights["desk_lamp"] = a.omni(bench + Vector3(-0.52, 1.12, -0.12),
			Color(1.0, 0.78, 0.50), 1.05, 2.6, false)
	a.omni(Vector3(x0 + 0.20, Y + 1.60, cz + 0.30), Color(0.86, 0.90, 1.0), 0.35, 2.4, false)

	# —— 门后挂钩上的雨衣（修水表的，永远穿着雨衣）
	a.box(Vector3(-1.10, Y + 1.72, CZ0 - 0.12), Vector3(0.05, 0.10, 0.05),
		k.plain(Color(0.42, 0.40, 0.35), 0.5, 0.6))
	a.box(Vector3(-1.10, Y + 1.42, CZ0 - 0.14), Vector3(0.40, 0.52, 0.10),
		k.plain(Color(0.20, 0.26, 0.23), 0.65))
	a.box(Vector3(-1.10, Y + 1.66, CZ0 - 0.14), Vector3(0.18, 0.12, 0.10),
		k.plain(Color(0.18, 0.24, 0.21), 0.65))

# ================================================================ 403 杂物间
## 2.0 × 2.4。堆着 2004 年以后的旧家具；一台老式缝纫机，上面搭着一件没缝完的小毛衣
## ——和 7 号机里那件是同一件；墙角一个烧了一半的纸箱，里面是孩子的衣服，被抢救出来的。
func _room_403() -> void:
	var x0 := -0.8
	var x1 := 0.8
	var z0 := 2.6
	var z1 := CZ0
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	k.slab(x0, z0, x1, z1, Y + 0.0015, m_floor)
	k.slab_solid(x0, z0, x1, z1, Y + HH + 0.30, m_ceil, m_ceil)
	k.wall_z(x0 - 0.06, z0, z1, Y, HH, m_wall)
	k.wall_z(x1 + 0.06, z0, z1, Y, HH, m_wall)
	k.wall_x(z0 - 0.06, x0, x1, Y, HH, m_wall)
	a.box(Vector3(-.625,Y+HH*.5,z1+.06),Vector3(.35,HH,.12),m_wall,true)
	a.box(Vector3(.625,Y+HH*.5,z1+.06),Vector3(.35,HH,.12),m_wall,true)
	a.box(Vector3(0.0, Y + 2.30, z1 + 0.06), Vector3(0.90, 0.30, 0.12), m_wall, false)
	k.wainscot(Vector3(x0 + 0.02, Y, cz), z1 - z0, 1.02, "z", m_panel, m_rail, 1.0)

	# —— 缝纫机：Blender 版（sewing_01，3036 面）
	#     铸铁 S 形脚架 + 真踏板 + 飞轮 + 横臂机头 + 针杆/压脚 + 金色花纹 + 摇轮 + 线轴/线。
	#     原来这里是二十来行盒子，剪影读得出但细节全无。
	var sw := Vector3(cx - 0.10, Y, z0 + 0.48)
	var sws = load("res://assets/models/props/sewing_01/sewing_01.glb")
	if sws != null:
		var si: Node3D = sws.instantiate()
		si.set_meta("dynamic", true)
		si.position = sw
		si.rotation.y = PI          # 机器正面（-Z）转向房间内侧
		a.root.add_child(si)
		# 台面上搭着的那件没缝完的小毛衣：藏青 + 白条纹（剧本 4-b 写死）
		var knit := k.emit(Color(0.20, 0.27, 0.42), 0.15)
		a.bev(sw + Vector3(-0.02, 0.80, 0.02), Vector3(0.22, 0.10, 0.16), knit, 0.006)
		a.box(sw + Vector3(-0.02, 0.745, 0.03), Vector3(0.215, 0.014, 0.014),
			k.plain(Color(0.88, 0.88, 0.86), 0.9))
		# 缝到一半的线：从机针拖到台面边缘
		k.pipe(sw + Vector3(-0.16, 0.78, 0.02), sw + Vector3(-0.10, 0.74, 0.20), 0.0025,
			k.plain(Color(0.80, 0.78, 0.70), 0.9), 4)
	else:
		# 兜底：加载失败时的极简版（只保留轮廓）
		a.box(sw + Vector3(0, 0.72, 0), Vector3(0.94, 0.05, 0.48), m_wood, false)
		a.box(sw + Vector3(-0.08, 0.90, 0), Vector3(0.34, 0.16, 0.20),
			k.plain(Color(0.13, 0.13, 0.14), 0.38, 0.45), false)
	# 缝纫机旁的凳（保留）
	k.model("props/metal_stool_01", Vector3(cx + 0.10, Y, z0 + 1.02), 0.3, 0.46)

	# —— 烧了一半的纸箱：箱体 + 焦黑的上沿 + 里面露出来的童装
	var bx := Vector3(x1 - 0.36,Y,z1 - 1.10)
	k.model("cardboard_box_01", bx, 0.35, 0.56, Color(0.66, 0.55, 0.42))
	a.box(bx + Vector3(0, 0.46, -0.02), Vector3(0.60, 0.10, 0.56),
		k.plain(Color(0.055, 0.050, 0.046), 0.95), true)
	a.box(bx + Vector3(0, 0.30, 0.02), Vector3(0.52, 0.04, 0.48),
		k.plain(Color(0.08, 0.07, 0.065), 0.95))
	# 抢救出来的孩子衣服（叠着，颜色比箱子浅）
	for i in range(3):
		a.box(bx + Vector3(-0.10 + 0.11 * float(i), 0.36 + 0.05 * float(i), 0.06),
			Vector3(0.18, 0.035, 0.22),
			k.plain(Color(0.52 + 0.05 * float(i), 0.56, 0.62 - 0.04 * float(i)), 0.95),
			false, 0.12 * float(i))

	# —— 旧家具：两块叠起来的海绵床垫 + 一台老电视（报废）
	a.box(Vector3(cx + 0.42,Y+.14,cz-.02),Vector3(.92,.28,1.10),
		k.cloth("rough_linen", Color(0.50, 0.47, 0.42), 1.6), true)
	a.box(Vector3(cx + 0.46,Y+.42,cz+.02),Vector3(.86,.26,1.02),
		k.cloth("rough_linen", Color(0.56, 0.53, 0.47), 1.6))
	# 一卷旧床垫：横躺靠墙（原来是竖直圆柱，读作一根柱子，还挡镜头）
	var roll := a.cyl(Vector3(x1 - 0.34, Y + 0.20, z0 + 1.15), 0.19, 1.30,
		k.cloth("rough_linen", Color(0.44, 0.41, 0.37), 1.5), 16, "z")
	roll.rotation.z = 0.0
	# 卷的两个端面（布卷的断面是螺旋的，这里用两圈布条意思一下）
	for sz4 in [-0.66, 0.66]:
		a.cyl(Vector3(x1 - 0.34, Y + 0.20, z0 + 1.15 + sz4), 0.195, 0.02,
			k.cloth("rough_linen", Color(0.52, 0.49, 0.44), 1.5), 16, "z")
	# 卷上压着的两块砖（怕它弹开）
	for i in range(2):
		a.box(Vector3(x1 - 0.34, Y + 0.42, z0 + 0.92 + 0.46 * float(i)),
			Vector3(0.22, 0.09, 0.11),
			k.pbr("brick_4", 1.8, Color(0.50, 0.42, 0.36), 1.0), false, 0.2 * float(i))

	# —— 墙上一排钉子 + 挂着的旧包袱（搬家搬了一半的东西）
	for i in range(4):
		a.cyl(Vector3(x0 + 0.08, Y + 1.62, z0 + 0.55 + 0.46 * float(i)),
			0.008, 0.07, k.plain(Color(0.34, 0.32, 0.28), 0.6, 0.6), 6, "x")
	# 旧包袱：要贴在钉子上挂（原来放在 x0+0.22，离墙 22 cm，是悬空的）
	a.box(Vector3(x0 + 0.075, Y + 1.44, z0 + 0.90), Vector3(0.15, 0.30, 0.26),
		k.cloth("rough_linen", Color(0.52, 0.48, 0.40), 2.0))
	# 扎口的绳
	a.box(Vector3(x0 + 0.075, Y + 1.60, z0 + 0.90), Vector3(0.16, 0.018, 0.27),
		k.plain(Color(0.36, 0.30, 0.22), 0.9))
	# —— 墙角那摞椅子（搬家时叠起来的）
	for i in range(3):
		a.box(Vector3(x1 - 0.26, Y + 0.04 + 0.16 * float(i), z1 - 0.62),
			Vector3(0.42, 0.05, 0.42), k.pbr("oak_wood_planks", 1.2, Color(0.36, 0.28, 0.20), 0.8),
			false, 0.12 * float(i))
		for sx3 in [-0.17, 0.17]:
			a.box(Vector3(x1 - 0.26 + sx3, Y + 0.20 + 0.16 * float(i), z1 - 0.62),
				Vector3(0.04, 0.36, 0.04), k.plain(Color(0.20, 0.16, 0.12), 0.8), false, 0.12 * float(i))
	# —— 一台老式缝纫机旁边的凳 + 一盏很暗的灯（杂物间没人来）
	k.model("props/metal_stool_01", Vector3(cx + 0.10, Y, z0 + 1.02), 0.3, 0.46)
	k.bulb_lamp(Vector3(cx, Y + HH - 0.02, cz - 0.10), 0.58, 1.45, 4.6,
		Color(1.0, 0.82, 0.56), true)
	# 灯罩上落满灰：一圈脏斑
	a.cyl(Vector3(cx, Y + HH - 0.48, cz), 0.10, 0.12,
		k.plain(Color(0.52, 0.50, 0.44), 0.95), 12)

# ================================================================ 401 空置
## 只做一扇门（不开）。门缝底下是黑的——这一间的灯，从来没人开过。
func _room_401() -> void:
	var x0 := 0.8
	var x1 := X1
	var z0 := 2.2
	var cz := (z0 + CZ0) * 0.5
	k.doors["401"] = k.door_leaf(Vector3(1.65, Y, CZ0 - 0.03), 0.90, 2.02, 0.0,
		k.pbr("oak_wood_planks", 1.8, Color(0.22, 0.165, 0.12), 0.75))
	# 门缝（黑）
	a.box(Vector3(2.10, Y + 0.02, CZ0 - 0.03), Vector3(0.86, 0.03, 0.02),
		k.plain(Color(0.015, 0.015, 0.017), 0.95))
	# 电表箱：这一层有电，就是从这里来的
	var box_p := Vector3(x1 - 0.10, Y + 1.55, cz)
	a.box(box_p, Vector3(0.10, 0.52, 0.40), k.plain(Color(0.42, 0.42, 0.40), 0.5, 0.5))
	a.box(box_p + Vector3(-0.055, 0, 0), Vector3(0.012, 0.46, 0.34),
		k.plain(Color(0.30, 0.30, 0.29), 0.7))
	for i in range(3):
		a.box(box_p + Vector3(-0.062, 0.14 - 0.14 * float(i), 0.0),
			Vector3(0.014, 0.05, 0.07), k.plain(Color(0.76, 0.72, 0.52), 0.4, 0.8))
	a.label("电表", box_p + Vector3(-0.062, 0.30, 0), 0.026,
		Color(0.14, 0.13, 0.11), -PI * 0.5)

# ================================================================ 楼梯洞口
## 南墙 z = 11.0 处留 2.4 m 宽的洞，通往 stairs_upper 的 3F→4F 梯段。
func _stair_opening() -> void:
	# 南墙：楼梯口 x 0.30…2.80（宽 2.5 m），与 1F/2F/3F 楼梯间对齐。
	# 原来写成「两边各补一块大墙」，实际只剩 x 0.75…2.80 里的一小段能过 ——
	# 这里改成真的只在楼梯口两侧留墙、上方留过梁。
	a.box(Vector3(-1.45, Y + HH * 0.5, CZ1 + 0.02), Vector3(3.50, HH, 0.12), m_wall, true)
	a.box(Vector3(3.00, Y + HH * 0.5, CZ1 + 0.02), Vector3(0.40, HH, 0.12), m_wall, true)
	# 过梁（洞口上方那一小段墙，保持墙面连续）
	a.box(Vector3(1.55, Y + HH - (HH - 2.10) * 0.5, CZ1 + 0.02),
		Vector3(2.50, HH - 2.10, 0.12), m_wall, false)
