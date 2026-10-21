extends RefCounted
## 配电房（剧本 v2 区域 2-c，2.0 × 1.6，锁着）
## ---------------------------------------------------------------------------
## 位置：2F 走廊尽头，(−9.0, 0, +2.0) 相对 2F 原点
##       → 世界坐标约 (x −3.0, z +8.0)，但洗衣店东墙在 x=+3.2，
##       剧本写的 −9.0 是「相对 2F 原点」，2F 原点在世界 (0, 3.5, 6.0)，
##       所以世界位置是 (−9.0, 3.5, 8.0) —— 但那已经出楼了。
##       按「2F 走廊尽头」这个描述，实际放在洗衣店东南角外侧（x 3.2…5.2，z 6.5…8.1），
##       从洗衣店东南角的门进去。
##
## 内容：总闸（第三夜才允许送电）、一排保险丝（**少一根**）、
##       墙上贴着 1998 年的电路图（图上一根线通向「B1 蓄水池」，手写「勿动」）
## 键是 B1 的引子。

const A := preload("res://scripts/laundry/laundry_art.gd")
const KIT := preload("res://scripts/laundry/laundry_kit.gd")

const Y := 3.5              # 2F 地面
const RX0 := 3.2            # 西墙（洗衣店东墙）
const RX1 := 5.2            # 东墙
const RZ0 := 6.2            # 北墙
const RZ1 := 8.0            # 南墙
const RH := 2.30

var a: LaundryArt
var k: LaundryKit
var lights: Dictionary = {}
var breaker: Node3D = null       # 总闸（剧情层可拨动）
var breaker_on := false

func _init(art: LaundryArt) -> void:
	a = art
	k = KIT.new(art)

func build() -> void:
	_materials()
	_shell()
	_panels()
	_diagram()
	_light()

var m_wall: StandardMaterial3D
var m_floor: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_paper: StandardMaterial3D
var m_paint: StandardMaterial3D

func _materials() -> void:
	m_wall = k.pbr("grey_plaster_02", 0.34, Color(0.62, 0.62, 0.60), 1.0, 0.0, 0.6)
	m_floor = k.pbr("chipped_concrete", 0.8, Color(0.48, 0.48, 0.46), 1.0)
	# 柜体用**素色**钢板：metal_plate 是花纹铁（diamond plate），大面积用会很抢眼，
	# 而且和柜门同材质就分不出层次。
	m_metal = k.plain(Color(0.20, 0.21, 0.21), 0.62, 0.55)
	m_dark = k.plain(Color(0.06, 0.06, 0.065), 0.9)
	m_paper = k.plain(Color(0.86, 0.83, 0.72), 0.95)
	m_paint = k.pbr("painted_metal_shutter", 0.9, Color(0.30, 0.36, 0.32), 0.7, 0.3) if false else \
		k.plain(Color(0.26, 0.32, 0.29), 0.7, 0.25)

func _shell() -> void:
	var cx := (RX0 + RX1) * 0.5
	var cz := (RZ0 + RZ1) * 0.5
	k.slab(RX0, RZ0, RX1, RZ1, Y, m_floor)
	# 天花板（实体，别漏）
	var ceil_m := k.plain(Color(0.48, 0.48, 0.46), 0.95)
	a.quad_xz(RX0, RZ0, RX1, RZ1, Y + RH, ceil_m, false)
	a.box(Vector3(cx, Y + RH + 0.16, RZ0 - 0.05), Vector3(RX1 - RX0 + 0.2, 0.32, 0.1), ceil_m, false)
	a.box(Vector3(cx, Y + RH + 0.16, RZ1 + 0.05), Vector3(RX1 - RX0 + 0.2, 0.32, 0.1), ceil_m, false)
	a.box(Vector3(RX0 - 0.05, Y + RH + 0.16, cz), Vector3(0.1, 0.32, RZ1 - RZ0), ceil_m, false)
	a.box(Vector3(RX1 + 0.05, Y + RH + 0.16, cz), Vector3(0.1, 0.32, RZ1 - RZ0), ceil_m, false)
	# 墙：东/北/南三面 + 西面留门洞。
	# 注意：西面就是洗衣店东墙，**不能在这里再建一遍**（会与洗衣店墙重合）。
	k.wall_z(RX1 + 0.06, RZ0, RZ1, Y, RH, m_wall, 0.12)
	k.wall_x(RZ0 - 0.06, RX0, RX1, Y, RH, m_wall, 0.12)
	k.wall_x(RZ1 + 0.06, RX0, RX1, Y, RH, m_wall, 0.12)
	# 门（铁门，锁着）—— 建在洗衣店东墙上那个门洞的位置
	var door_c := Vector3(RX0 + 0.02, Y, cz)
	var dm := k.plain(Color(0.24, 0.28, 0.26), 0.72, 0.25)
	a.box(door_c + Vector3(0, 1.02, 0), Vector3(0.06, 2.04, 0.92), dm, true)
	# 门上的挂锁 + 「配电重地」
	k.padlock(Vector3(door_c.x - 0.05, Y + 1.00, cz + 0.34), PI * 0.5, 1.4)
	a.box(door_c + Vector3(-0.04, 1.62, 0), Vector3(0.008, 0.20, 0.52), m_paper, false)
	a.label("配电重地", door_c + Vector3(-0.05, 1.62, 0), 0.055,
		Color(0.55, 0.12, 0.10), -PI * 0.5, 26)

# ================================================================ 配电柜
func _panels() -> void:
	var cx := (RX0 + RX1) * 0.5
	var cz := (RZ0 + RZ1) * 0.5
	# —— 主配电柜（靠北墙）：一大面铁柜，三扇门
	# 房间只有 2.0 × 1.8 m：柜子不能做太大，否则人站不进去、相机一放就贴脸。
	var pz := RZ0 + 0.18
	var body_depth := 0.24
	a.box(Vector3(cx, Y + 0.92, pz), Vector3(1.30, 1.72, body_depth), m_metal, true)
	# **柜体前脸**：房间在柜子的 +Z 方向（北墙 6.2、南墙 8.0），所以前脸朝 +Z。
	# 所有面板都要放在 face **加上**一个小值的位置（朝房间那侧）。
	# 之前写成 face - 值，面板全跑到背板后面贴墙了（这个坑踩了四次）。
	var face: float = pz + body_depth * 0.5
	# 柜门
	for i in range(3):
		var px: float = cx - 0.42 + 0.42 * float(i)
		a.box(Vector3(px, Y + 0.92, face + 0.012), Vector3(0.38, 1.60, 0.02),
			k.plain(Color(0.36, 0.40, 0.38), 0.58, 0.35), false)
		a.cyl(Vector3(px + 0.14, Y + 0.92, face + 0.030), 0.010, 0.12, m_metal, 8, "y")
	# —— 总闸：柜子左边那扇门上的大闸刀
	#     现在是「断开」状态，剧情第三夜要拨上去
	breaker = a.push_group(Vector3(cx - 0.42, Y + 1.42, face + 0.060), 0.0, true)
	a.box(Vector3.ZERO, Vector3(0.26, 0.34, 0.06), m_dark, false)
	# 闸刀手柄（斜向下 = 断开）
	var handle := a.box(Vector3(0, -0.08, -0.055), Vector3(0.06, 0.20, 0.06),
		k.plain(Color(0.62, 0.16, 0.12), 0.5, 0.4), false)
	handle.rotation.x = 0.55
	a.pop_group()
	a.label("总闸", Vector3(cx - 0.42, Y + 1.70, face + 0.065), 0.048,
		Color(0.86, 0.84, 0.76), 0.0, 26)
	# —— 一排保险丝（柜子中间那扇门）：**少一根**
	for i in range(8):
		if i == 5:
			continue          # ← 剧本写死：少一根
		var px2: float = cx - 0.16 + 0.045 * float(i)
		a.cyl(Vector3(px2, Y + 1.16, face + 0.050), 0.016, 0.10,
			k.plain(Color(0.86, 0.80, 0.58), 0.35, 0.15), 10, "y")
		a.cyl(Vector3(px2, Y + 1.21, face + 0.050), 0.020, 0.02, m_metal, 8, "y")
	# 空位：一个黑洞（少的那根）
	a.box(Vector3(cx - 0.16 + 0.045 * 5.0, Y + 1.16, face + 0.045),
		Vector3(0.030, 0.10, 0.010), m_dark, false)
	a.label("5", Vector3(cx - 0.16 + 0.045 * 5.0, Y + 1.32, face + 0.055), 0.030,
		Color(0.58, 0.14, 0.11), 0.0, 20)
	# —— 电表（三块，柜子右边）
	for i in range(3):
		var my: float = Y + 1.36 - 0.24 * float(i)
		a.cyl(Vector3(cx + 0.42, my, face + 0.050), 0.08, 0.025,
			k.plain(Color(0.80, 0.78, 0.70), 0.45), 16, "z")
		a.box(Vector3(cx + 0.42, my + 0.02, face + 0.070), Vector3(0.006, 0.04, 0.005),
			k.plain(Color(0.20, 0.18, 0.15), 0.8), false, 0.5)
	# —— 墙上的电缆槽（沿墙走的一排线槽）
	var tray := k.pbr("metal_plate", 1.4, Color(0.36, 0.36, 0.34), 0.7, 0.5)
	k.pipe(Vector3(RX0 + 0.12, Y + 2.05, RZ0 + 0.10), Vector3(RX0 + 0.12, Y + 2.05, RZ1 - 0.10),
		0.045, tray, 10)
	k.pipe(Vector3(RX0 + 0.12, Y + 2.05, RZ0 + 0.10), Vector3(RX1 - 0.10, Y + 2.05, RZ0 + 0.10),
		0.045, tray, 10)
	# 从线槽垂到柜子的几根电缆
	for i in range(5):
		var px3: float = cx - 0.50 + 0.25 * float(i)
		k.pipe(Vector3(px3, Y + 2.02, RZ0 + 0.10), Vector3(px3, Y + 1.84, face + 0.03),
			0.016, k.plain(Color(0.10, 0.10, 0.11), 0.9), 6)

# ================================================================ 1998 年电路图
func _diagram() -> void:
	# 东墙上一张 1998 年的电路图。
	# **关键**：图上一根线通向「B1 蓄水池」，旁边手写「勿动」。
	var dx := RX1 - 0.07
	var dy: float = Y + 1.55
	var dz: float = (RZ0 + RZ1) * 0.5 + 0.30
	a.box(Vector3(dx, dy, dz), Vector3(0.008, 0.86, 1.10), m_paper, false)
	# 图框
	var ink := k.plain(Color(0.24, 0.28, 0.34), 0.9)
	a.box(Vector3(dx - 0.005, dy + 0.40, dz), Vector3(0.004, 0.008, 1.02), ink)
	a.box(Vector3(dx - 0.005, dy - 0.40, dz), Vector3(0.004, 0.008, 1.02), ink)
	a.box(Vector3(dx - 0.005, dy, dz + 0.52), Vector3(0.004, 0.80, 0.008), ink)
	a.box(Vector3(dx - 0.005, dy, dz - 0.52), Vector3(0.004, 0.80, 0.008), ink)
	# 电路：几条横线代表楼层
	for i in range(5):
		var yy: float = dy + 0.28 - 0.14 * float(i)
		a.box(Vector3(dx - 0.008, yy, dz), Vector3(0.004, 0.005, 0.86), ink)
	# 通向 B1 的那根线（竖着往下，一直到图纸底部）
	var dz_line: float = dz - 0.34
	a.box(Vector3(dx - 0.010, dy - 0.10, dz_line), Vector3(0.005, 0.60, 0.006), ink)
	# 那根线旁边的手写「勿动」（红笔）
	a.box(Vector3(dx - 0.012, dy - 0.30, dz_line + 0.10), Vector3(0.005, 0.14, 0.006),
		k.plain(Color(0.60, 0.14, 0.11), 0.85))
	a.label("勿动", Vector3(dx - 0.014, dy - 0.34, dz_line + 0.10), 0.050,
		Color(0.60, 0.13, 0.10), 0.0, 22)
	# 手写的「B1 蓄水池」
	a.label("B1 蓄水池", Vector3(dx - 0.014, dy - 0.44, dz_line), 0.042,
		Color(0.24, 0.22, 0.18), 0.0, 20)

# ================================================================ 灯
func _light() -> void:
	var cx := (RX0 + RX1) * 0.5
	var cz := (RZ0 + RZ1) * 0.5
	# 配电房只有一盏是坏的吸顶灯 —— 但太黑看不见。给一盏很弱的应急灯。
	a.box(Vector3(cx, Y + RH - 0.04, cz), Vector3(0.24, 0.05, 0.24),
		k.plain(Color(0.20, 0.20, 0.19), 0.8))
	a.box(Vector3(cx, Y + RH - 0.08, cz), Vector3(0.20, 0.03, 0.20),
		k.emit(Color(1.0, 0.84, 0.60), 1.3))
	lights["main"] = a.omni(Vector3(cx, Y + RH - 0.22, cz), Color(1.0, 0.80, 0.54),
		1.55, 4.2, true)
	# 柜子背光（让配电柜的面板能看清）
	a.omni(Vector3(cx, Y + 1.40, RZ0 + 0.90), Color(0.70, 0.76, 0.80), 0.75, 2.8, false)

# ================================================================ 剧情接口
## 第三夜送电：把总闸拨上（由剧情层调用）
func set_breaker(on: bool) -> void:
	# 只记状态；闸刀手柄的拨动动画留给剧情层（它知道什么时候送电）
	breaker_on = on
