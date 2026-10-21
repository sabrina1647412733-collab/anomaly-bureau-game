extends RefCounted
## 上层与地下层的楼梯井（**新文件，不改 stairs.gd**）
## ---------------------------------------------------------------------------
## stairs.gd 已经做了 1F→2F→3F 两段；这里接着往上和往下：
##   3F 6.9 → 4F 9.8 → 5F 12.7 → 屋顶 15.6（折返式，每层两跑）
##   1F 0.0 → B1 −3.0（北端服务梯，从门厅角落的铁盖下去）
##
## 竖井位置：x 0.30…2.80，z 10.10…14.20（在 3F 走廊南墙之外，
## 与 1F/2F 的楼梯间同一组 x 范围，所以从上往下看是一条竖井）。
##
## 每个 2.9 m 层高用 16 级：8 级上 → 中间平台 → 8 级回来 → 上一层。
## 一侧跑在西半跨（x 0.30…1.48），另一侧在东半跨（x 1.62…2.80）。

const A := preload("res://scripts/laundry/laundry_art.gd")
const KIT := preload("res://scripts/laundry/laundry_kit.gd")

const SX0 := 0.30
const SX1 := 2.80
const SZ0 := 10.10
const SZ1 := 14.20
const RISE := 2.9
const N := 16
const R := RISE / float(N)          # 0.18125

const F3 := 6.9
const F4 := 9.8
const F5 := 12.7
const FR := 15.6

var a: LaundryArt
var k: LaundryKit
var lights: Dictionary = {}

func _init(art: LaundryArt) -> void:
	a = art
	k = KIT.new(art)

func build() -> void:
	_materials()
	# 三个上层之间 + 到屋顶
	_shaft_walls()
	_flights(F3, F4)
	_flights(F4, F5)
	_flights(F5, FR)
	_roof_hatch_room()
	# 地下室
	_basement_stair()

var m_conc: StandardMaterial3D
var m_wall: StandardMaterial3D
var m_tread: StandardMaterial3D
var m_rail: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_dark: StandardMaterial3D

func _materials() -> void:
	m_conc = k.pbr("chipped_concrete", 0.85, Color(0.56, 0.55, 0.52), 1.0)
	m_wall = k.pbr("rough_concrete", 0.32, Color(0.52, 0.51, 0.48), 1.0, 0.0, 0.8)
	m_tread = k.plain(Color(0.32, 0.32, 0.31), 0.9)
	m_rail = k.pbr("rusty_metal", 1.2, Color(0.44, 0.36, 0.28), 0.8, 0.3)
	m_metal = k.pbr("metal_plate", 1.3, Color(0.50, 0.50, 0.49), 0.7, 0.65)
	m_dark = k.plain(Color(0.045, 0.045, 0.05), 0.95)

# ================================================================ 竖井墙
## 从 3F 一直到屋顶，四面墙。南端 z=14.2 是井底墙；北端在走廊墙上开口。
func _shaft_walls() -> void:
	var top := FR + 0.5
	# 东西两侧墙：从 3F 一直到屋顶
	k.wall_z(SX0 - 0.10, SZ0, SZ1, F3 - 0.2, top - F3 + 0.2, m_wall, 0.20)
	k.wall_z(SX1 + 0.10, SZ0, SZ1, F3 - 0.2, top - F3 + 0.2, m_wall, 0.20)
	# 南端墙
	# 南侧给 2F→3F 来向留出完整头部净空，再接三楼回廊。
	k.wall_x(SZ1 + 0.10, SX0 - 0.20, SX1 + 0.20, F3 + 2.3, top - F3 - 2.3, m_wall, 0.20)
	# 每层楼板在竖井里的“边”：楼板到这里为止（走廊南墙那条线就是洞口）
	# 顶（屋顶板）由 roof_deck 负责；这里补 4F/5F 井口一圈的收边
	for yy in [F4, F5]:
		a.box(Vector3((SX0 + SX1) * 0.5, yy - 0.15, SZ1 + 0.02),
			Vector3(SX1 - SX0, 0.30, 0.24), m_conc, true)
		a.box(Vector3(SX0 - 0.02, yy - 0.15, (SZ0 + SZ1) * 0.5),
			Vector3(0.22, 0.30, SZ1 - SZ0), m_conc, true)
		a.box(Vector3(SX1 + 0.02, yy - 0.15, (SZ0 + SZ1) * 0.5),
			Vector3(0.22, 0.30, SZ1 - SZ0), m_conc, true)

	# 每层井口一盏声控灯（3F 以上是坏的，只有 4F 那段亮）
	_bulb(Vector3((SX0 + SX1) * 0.5, F3 + 2.50, SZ1 - 0.60), F3, 0.55)   # 3F→4F 坏：暗
	_bulb(Vector3((SX0 + SX1) * 0.5, F4 + 2.50, SZ1 - 0.60), F4, 1.45)  # 4F 段：好
	_bulb(Vector3((SX0 + SX1) * 0.5, F5 + 2.50, SZ1 - 0.60), F5, 0.42)  # 5F 段：坏

func _bulb(pos: Vector3, base_y: float, energy: float) -> void:
	a.box(pos, Vector3(0.22, 0.05, 0.22), m_dark)
	a.box(pos + Vector3(0, -0.04, 0), Vector3(0.18, 0.03, 0.18),
		k.emit(Color(1.0, 0.80, 0.56), 1.2 if energy > 0.8 else 0.25))
	if energy > 0.8:
		lights["stair_%d" % int(base_y)] = a.omni(pos + Vector3(0, -0.20, 0),
			Color(1.0, 0.78, 0.54), energy, 5.5, true)
	else:
		a.omni(pos + Vector3(0, -0.20, 0), Color(1.0, 0.74, 0.50), energy, 3.0, false)

# ================================================================ 两跑折返
## y0 → y0+2.9 的一整层：西跑 8 级上、中间平台、东跑 8 级回到北侧。
func _flights(y0: float, y1: float) -> void:
	var run := 2.60 / 8.0            # 每级踏面 0.325
	var half := (y1 - y0) * 0.5
	# —— 西跑（x 0.30…1.48）：从 z=10.30 往 +Z 上 8 级
	var ax0 := SX0 + 0.04
	var ax1 := SX0 + (SX1 - SX0) * 0.5 - 0.06
	for i in range(8):
		var z: float = 10.30 + (float(i) + 0.5) * run
		var h: float = y0 + (float(i) + 1.0) * (half / 8.0)
		a.box(Vector3((ax0 + ax1) * 0.5, h - .065, z),
			Vector3(ax1 - ax0, .13, run), m_conc, true)
		# 防滑条
		a.box(Vector3((ax0 + ax1) * 0.5, h - 0.008, z + run * 0.40),
			Vector3(ax1 - ax0 - 0.06, 0.014, 0.045), m_tread)
	# —— 中间平台（z 12.90…14.10）
	a.box(Vector3((SX0 + SX1) * 0.5, y0 + half - 0.10, 13.50),
		Vector3(SX1 - SX0, 0.20, 1.20), m_conc, true)
	# —— 东跑（x 1.62…2.80）：从 z=14.10 往 −Z 上 8 级，到 z=11.50
	var bx0 := SX0 + (SX1 - SX0) * 0.5 + 0.06
	var bx1 := SX1 - 0.04
	for i in range(8):
		# 东跑从中间平台北沿起步，平台上必须能横向走到另一侧。
		var z2: float = 13.00 - (float(i) + 0.5) * run
		var h2: float = y0 + half + (float(i) + 1.0) * (half / 8.0)
		a.box(Vector3((bx0 + bx1) * 0.5, h2 - .065, z2),
			Vector3(bx1 - bx0, .13, run), m_conc, true)
		a.box(Vector3((bx0 + bx1) * 0.5, h2 - 0.008, z2 - run * 0.40),
			Vector3(bx1 - bx0 - 0.06, 0.014, 0.045), m_tread)
	# —— 顶部平台：z 10.10…11.50，这一层的地面
	a.box(Vector3((SX0 + SX1) * 0.5, y1 - 0.10, 10.30),
		Vector3(SX1 - SX0, 0.20, 1.00), m_conc, true)
	# —— 中间平台那一侧的高窗（让光从上层漏下来）
	if y0 >= F4:
		var win := k.plain(Color(0.10, 0.14, 0.20), 0.9)
		a.box(Vector3(SX1 + 0.05, y0 + half + 0.45, 13.50), Vector3(0.03, 0.55, 0.80), win, false)
		a.omni(Vector3(SX1 - 0.20, y0 + half + 0.50, 13.50), Color(0.62, 0.72, 0.92), 0.35, 3.2, false)
	# —— 扶手：两跑各一根
	k.railing(Vector3(ax1 - 0.03, y0, 10.30), Vector3(ax1 - 0.03, y0, 12.90), 1.05, m_rail, 0.9, 0.020)
	k.railing(Vector3(bx0 + 0.03, y0 + half, 14.10), Vector3(bx0 + 0.03, y0 + half, 11.50),
		1.05, m_rail, 0.9, 0.020)
	# —— 分跑的中间隔墙（矮墙，读得出“折返”）
	a.box(Vector3((SX0 + SX1) * 0.5, y0 + half * 0.5, 12.95),
		Vector3(0.10, half, 0.12), m_wall)
	# —— 墙上的楼层号（老楼都刷在墙上）
	a.label("4F", Vector3(SX1 - 0.02, F4 + 1.55, 11.00), 0.13, Color(0.72, 0.70, 0.60), -PI * 0.5, 44)
	a.label("5F", Vector3(SX1 - 0.02, F5 + 1.55, 11.00), 0.13, Color(0.72, 0.70, 0.60), -PI * 0.5, 44)

# ================================================================ 屋顶出口
func _roof_hatch_room() -> void:
	# 屋顶楼梯帽（roof_deck 里做了外壳，这里补里面的门与门槛）
	a.box(Vector3((SX0 + SX1) * 0.5, FR + 0.04, SZ0 - 0.06),
		Vector3(0.10, 0.08, 0.30), m_metal, false)

# ================================================================ 1F → B1
## 门厅北端角落的服务梯：一块掀开的铁盖 + 一段直梯下到 B1。
## 位置与 B1 的锅炉房对齐：x 2.20…3.10，z −8.60…−6.20（在门厅东北角）。
const BY := -3.0
const BHX0 := 2.20
const BHX1 := 3.10
const BHZ0 := -8.60
const BHZ1 := -6.20

func _basement_stair() -> void:
	var cx := (BHX0 + BHX1) * 0.5
	var cz := (BHZ0 + BHZ1) * 0.5
	# —— 井壁（从 B1 地面到 1F 楼面）
	#     四面墙必须**让到洞口外侧**，不能往里偏。
	#     原来 BHX1/ BHZ1 那两面各往里偏 6 cm，正好挡住竖井通道
	#     （射线自检在 y=0.30 处撞到它）。这里改成整块墙厚都让到洞口之外。
	var t := 0.12
	# 西侧下部留出 B1 出口，不能把落梯点封成一个盒子。
	k.wall_z(BHX0 - t * 0.5, BHZ0, BHZ1, -1.0, 1.0, m_wall, t)
	k.wall_z(BHX0 - t * 0.5, BHZ0, -7.65, BY, 2.0, m_wall, t)
	k.slab(BHX0, BHZ0, BHX1, BHZ1, BY, m_conc)
	k.wall_z(BHX1 + t * 0.5, BHZ0, BHZ1, BY, 3.0, m_wall, t)
	k.wall_x(BHZ0 - t * 0.5, BHX0, BHX1, BY, 3.0, m_wall, t)
	k.wall_x(BHZ1 + t * 0.5, BHX0, BHX1, BY, 3.0, m_wall, t)
	# —— 直梯：铁梯从 1F 洞口一直到 B1
	k.ladder(Vector3(BHX0 + 0.22, BY, BHZ0 + 0.30),
		Vector3(BHX0 + 0.22, 0.05, BHZ0 + 0.30), 0.42)
	# 梯子顶端的扶手（1F 一侧，防止直接踩空）
	k.railing(Vector3(BHX0, 0.0, BHZ1 - 0.10), Vector3(BHX0, 0.0, BHZ0 + 0.10), 1.0, m_rail, 0.9)
	# —— 掀开的铁盖（斜靠在洞口边上）
	var lid := a.push_group(Vector3(BHX1 + 0.10, 0.02, BHZ0 + 0.20), 0.0, true)
	a.box(Vector3(0, 0.02, 0.60), Vector3(0.86, 0.05, 1.10), m_metal)
	a.box(Vector3(0, 0.045, 0.60), Vector3(0.70, 0.02, 0.94),
		k.pbr("metal_grate_rusty", 1.4, Color(0.58, 0.50, 0.42), 0.9, 0.3))
	a.pop_group()
	# 盖子上的铰链
	for zz in [BHZ0 + 0.30, BHZ1 - 0.30]:
		a.cyl(Vector3(BHX1 + 0.06, 0.06, zz), 0.03, 0.20, m_metal, 8, "x")
	# —— 警示牌（手写的，钉在墙上）
	a.box(Vector3(BHX1 + 0.02, 1.05, BHZ1 + 0.03), Vector3(0.28, 0.20, 0.006),
		k.plain(Color(0.82, 0.78, 0.62), 0.95), false)
	a.label("B1 勿下", Vector3(BHX1 + 0.02, 1.05, BHZ1 + 0.036), 0.045,
		Color(0.56, 0.12, 0.10), -PI * 0.5, 30)
	# —— 洞口的黄黑警示条（1F 地面）
	var warn := k.plain(Color(0.78, 0.64, 0.18), 0.85)
	a.box(Vector3(cx, 0.012, BHZ0 - 0.10), Vector3(BHX1 - BHX0 + 0.30, 0.01, 0.10), warn, false)
	a.box(Vector3(cx, 0.012, BHZ1 + 0.10), Vector3(BHX1 - BHX0 + 0.30, 0.01, 0.10), warn, false)
	# —— B1 井底一盏很暗的灯（只在井口能看见一点）
	a.omni(Vector3(cx, BY + 2.30, cz), Color(0.70, 0.62, 0.46), 0.45, 3.4, false)
