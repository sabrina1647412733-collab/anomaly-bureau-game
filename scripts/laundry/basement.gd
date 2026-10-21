extends RefCounted
## B1 ｜ 锅炉房、蓄水池、竖井底（第三夜）
## ---------------------------------------------------------------------------
## 剧本 v2 区域 7 —— 全案的“真相房间”。也是唯一一个水往上涨的地方。
##
## 入口：1F 门厅西北角地面上有一块铁盖（x −2.6…−1.7，z −8.2…−6.4），
##       铁梯下去 3 米，直接落在锅炉房的地面上。
##
## B1 楼面 y = −3.0，净高 2.7（顶棚就是 1F 地板的底面 y = −0.30）。
##   7-a 锅炉房   x −4.8…0.4，z −8.8…0.2：两台老锅炉，一台还在烧；
##               墙上一排阀门全部写着“勿动”；地面有 10 cm 的水，是温的。
##   7-b 蓄水池   x 1.0…4.4，z 1.0…5.4：铁梯下去，水面离地面 1.2 m，缓慢上升；
##               池壁上一圈水位线，比现在高 1.5 m —— 那是 2004-11-08 的水位。
##   7-c 竖井底   x 2.6…4.8，z −7.2…−5.0：五根水管从头顶的黑暗里伸下来，
##               全部通向 2F 洗衣店；墙上「2004-11-08 01:40 停水通知 · 未送达」；
##               地上一个孩子的凉鞋，一只。
##
## 光照规则：2000 K（锅炉的火）+ 蓄水池水面反射的绿。

const A := preload("res://scripts/laundry/laundry_art.gd")
const KIT := preload("res://scripts/laundry/laundry_kit.gd")

const Y := -3.0
const CEIL := -0.30
const HH := CEIL - Y            # 2.7
const X0 := -5.0
const X1 := 5.0
const Z0 := -9.0
const Z1 := 7.0

# 蓄水池（外沿）
const POOL_X0 := 1.00
const POOL_X1 := 4.40
const POOL_Z0 := 1.00
const POOL_Z1 := 5.40
const POOL_DEPTH := 2.50
## 水面高度：B1 地面 Y=-3.0，剧本「铁梯下去，水面离地面 1.2 m」→ 水面在 Y-1.20 = -4.20。
## （曾经写成 -1.20，那是在 B1 地面**以上** 1.8 m，水会悬在半空 —— 已修正。）
const WATER_Y := Y - 1.20

var a: LaundryArt
var k: LaundryKit
var lights: Dictionary = {}
var water: MeshInstance3D = null
var sandal_model: Node3D
var water_base_y := 0.0
## 蓄水池是否在自动上涨（剧本第三夜：每 30 秒 1 cm）
var water_rising := false
var _rise_acc := 0.0
## 池壁渗水的那些小水流（随水位一起变化）
var _seepage: Array = []
## 水位线标签（比现在高 1.5 m 的那圈 2004 水位）
var _mark_y := 0.0
var boiler_fire: OmniLight3D = null
var valve_wheels: Array = []

func _init(art: LaundryArt) -> void:
	a = art
	k = KIT.new(art)

func build() -> void:
	_materials()
	_shell()
	_boiler_room()
	_pipes()
	_pool()
	_shaft_bottom()
	_lights()

var m_floor: StandardMaterial3D
var m_wall: StandardMaterial3D
var m_ceil: StandardMaterial3D
var m_conc: StandardMaterial3D
var m_rust: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_fire: StandardMaterial3D
var m_paper: StandardMaterial3D
var m_wet_floor: StandardMaterial3D

func _materials() -> void:
	# 地下室：混凝土 + 铁锈 + 煤灰。所有表面都比楼上脏一个数量级。
	m_floor = k.pbr("concrete_floor", 0.40, Color(0.40, 0.40, 0.39), 0.95, 0.0, 1.1)
	m_wet_floor = k.wet("concrete_floor", Color(0.22, 0.23, 0.23), 0.42)
	m_wall = k.pbr("rough_concrete", 0.30, Color(0.44, 0.44, 0.42), 0.92, 0.0, 0.9)
	m_ceil = k.pbr("rough_concrete", 0.34, Color(0.26, 0.26, 0.25), 0.95)
	m_conc = k.pbr("chipped_concrete", 0.75, Color(0.48, 0.48, 0.46), 0.95)
	m_rust = k.pbr("rusty_metal", 0.70, Color(0.50, 0.40, 0.31), 1.0, 0.25)
	m_metal = k.pbr("metal_plate", 1.2, Color(0.40, 0.40, 0.40), 0.75, 0.6)
	m_dark = k.plain(Color(0.030, 0.030, 0.033), 0.96)
	m_fire = k.emit(Color(1.0, 0.46, 0.14), 2.8)
	m_paper = k.plain(Color(0.78, 0.74, 0.60), 0.95)

# ================================================================ 壳体
func _shell() -> void:
	var cz := (Z0 + Z1) * 0.5
	var cx := (X0 + X1) * 0.5
	# 地面：要挖两个洞 ——
	#   ① 蓄水池池口（否则楼板把池子盖住，水面永远看不见）
	#   ② 1F→B1 的竖井（否则 B1 地板把竖井封死，玩家从 1F 下不来）
	# 用 slab_hole 挖第一个，再用四块矩形铺出「既避开池口、又避开竖井」的剩余地面。
	var sx0 := 2.60
	var sx1 := 4.80
	var sz0 := -7.60
	var sz1 := -4.60
	# 池口矩形（不含楼板厚度）
	var px0 := POOL_X0
	var px1 := POOL_X1
	var pz0 := POOL_Z0
	var pz1 := POOL_Z1
	# 先铺「竖井以北」与「竖井以南」两条横带（这两条也要避开池口，池口在南边 so 只在北带里需要避）
	k.slab_hole(X0, Z0, X1, sz0, Rect2(px0, pz0, px1 - px0, pz1 - pz0), Y, m_floor)
	k.slab_hole(X0, sz1, X1, Z1, Rect2(px0, pz0, px1 - px0, pz1 - pz0), Y, m_floor)
	# 竖井东西两侧
	k.slab_hole(X0, sz0, sx0, sz1, Rect2(px0, pz0, px1 - px0, pz1 - pz0), Y, m_floor)
	k.slab_hole(sx1, sz0, X1, sz1, Rect2(px0, pz0, px1 - px0, pz1 - pz0), Y, m_floor)
	# 竖井口一圈钢框（读得出这是个人工开的洞）
	var ring_f := k.pbr("metal_plate", 1.4, Color(0.36, 0.36, 0.35), 0.7, 0.6)
	for bz in [sz0, sz1]:
		a.box(Vector3((sx0 + sx1) * 0.5, Y - 0.16, bz), Vector3(sx1 - sx0 + 0.20, 0.32, 0.10), ring_f, false)
	for bx in [sx0, sx1]:
		a.box(Vector3(bx, Y - 0.16, (sz0 + sz1) * 0.5), Vector3(0.10, 0.32, sz1 - sz0), ring_f, false)
	# 顶棚 = 1F 楼板的底面。竖井要穿过它才能上到 1F，
	# 所以顶棚也必须挖开竖井那一段（否则天花板会把竖井封在 -0.30 高度 —— 
	# 这正是射线自检反复撞在 y=-0.30 的真凶）。
	# 竖井开口：x 2.60…4.80, z −7.60…−4.60
	# 服务梯与废电梯是两个重叠开口，按两者的并集切割顶棚。
	var xs := [X0, 2.20, 2.60, 3.10, 4.80, X1]
	var zs := [Z0, -8.60, -7.60, -6.20, -4.60, Z1]
	var service := Rect2(2.20, -8.60, .90, 2.40)
	var elevator := Rect2(2.60, -7.60, 2.20, 3.00)
	for ix in range(xs.size() - 1):
		for iz in range(zs.size() - 1):
			var midpoint := Vector2((xs[ix] + xs[ix+1]) * .5, (zs[iz] + zs[iz+1]) * .5)
			if not service.has_point(midpoint) and not elevator.has_point(midpoint):
				k.slab(xs[ix], zs[iz], xs[ix+1], zs[iz+1], CEIL, m_ceil, "ceil")
	k.wall_z(X0 - 0.15, Z0, Z1, Y, HH, m_wall, 0.30)
	k.wall_z(X1 + 0.15, Z0, Z1, Y, HH, m_wall, 0.30)
	k.wall_x(Z0 - 0.15, X0, X1, Y, HH, m_wall, 0.30)
	k.wall_x(Z1 + 0.15, X0, X1, Y, HH, m_wall, 0.30)
	# 墙根一圈湿痕（从下往上湿，地下室永远干不了）
	k.wet_band_x(Z0 + 0.16, X0, X1, Y, 1.30)
	k.wet_band_x(Z1 - 0.16, X0, X1, Y, 0.95, -1.0)
	k.wet_band_x(Z0 + 0.16, POOL_X0, POOL_X1, Y, 0.6)
	# 一圈混凝土柱（读得出这是老楼的地下室）
	for zz in [-7.0, -4.0, -1.0, 2.0, 5.0]:
		a.box(Vector3(X0 + 0.20, Y + HH * 0.5, zz), Vector3(0.30, HH, 0.30), m_conc, true)
		a.box(Vector3(X1 - 0.20, Y + HH * 0.5, zz), Vector3(0.30, HH, 0.30), m_conc, true)

	# —— 地面那 10 cm 的水：温的。只铺锅炉房那一半（西半），
	#     蓄水池和竖井底是干的石地 —— 这样镜头里“哪块是水”才读得出来。
	a.quad_xz(X0 + 0.2, Z0 + 0.2, 0.60, -0.60, Y + 0.002, m_wet_floor)
	var film := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5.0, 7.6)
	pm.subdivide_width = 20
	pm.subdivide_depth = 24
	film.mesh = pm
	film.material_override = k.thin_film_material()
	film.position = Vector3(-2.20, Y + 0.045, -4.20)
	film.set_meta("dynamic", true)
	a.root.add_child(film)
	lights["wet_floor"] = a.omni(Vector3(-2.20, Y + 0.20, -4.20), Color(0.60, 0.60, 0.48),
		1.90, 10.0, false)
	# 水膜边缘一圈湿痕（水渗到干地上）
	k.wet_band_x(0.60, X0, 0.60, Y, 0.30)

# ================================================================ 锅炉房（西半）
func _boiler_room() -> void:
	# —— 1 号炉：还在烧（立式，圆筒 + 炉门 + 烟囱）
	_boiler(Vector3(-3.55, Y, -5.60), true)
	# —— 2 号炉：已经停了（锈得更狠）
	_boiler(Vector3(-3.55, Y, -2.60), false)

	# 煤堆：靠西墙
	var coal := k.pbr("brick_4", 1.6, Color(0.13, 0.128, 0.124), 1.0)
	for i in range(11):
		var px: float = -4.55 + fmod(float(i) * 0.37, 0.80)
		var pz: float = -7.70 + fmod(float(i) * 0.61, 1.40)
		var rr: float = 0.10 + 0.06 * fmod(float(i) * 0.41, 1.0)
		a.cyl(Vector3(px, Y + rr * 0.55, pz), rr, rr * 1.2, coal, 8)
	# 铲煤的铁锹（靠在煤堆上）
	k.pipe(Vector3(-3.95, Y + 0.02, -7.10), Vector3(-3.60, Y + 0.95, -6.95), 0.018, m_metal, 8)
	a.box(Vector3(-3.57, Y + 1.00, -6.93), Vector3(0.17, 0.23, 0.02), m_metal, false, 0.3)

	# —— 墙上一排阀门，全部写着“勿动”（北墙 z = −8.85）
	var wheel := k.pbr("rusty_metal", 1.6, Color(0.54, 0.42, 0.32), 1.0, 0.3)
	for i in range(7):
		var px2: float = -4.30 + float(i) * 0.66
		var py2: float = Y + 1.45
		a.cyl(Vector3(px2, py2, Z0 + 0.34), 0.055, 0.20, m_metal, 12, "z")
		k.valve_wheel(Vector3(px2, py2, Z0 + 0.50), 0.115, wheel, "z", 4)
		valve_wheels.append(Vector3(px2, py2, Z0 + 0.50))
		# 纸条「勿动」
		a.box(Vector3(px2, py2 - 0.32, Z0 + 0.22), Vector3(0.13, 0.09, 0.005),
			m_paper, false, 0.10 * float(i % 3))
		a.label("勿动", Vector3(px2, py2 - 0.32, Z0 + 0.228), 0.040,
			Color(0.24, 0.12, 0.10), 0.0, 30)

	# —— 配电盘 / 压力表 / 保险丝（少一根）
	var panel := Vector3(0.05, Y + 1.55, Z0 + 0.22)
	a.box(panel, Vector3(1.15, 0.85, 0.16), k.plain(Color(0.22, 0.24, 0.23), 0.6, 0.35), false)
	for i in range(3):
		var gp: Vector3 = panel + Vector3(-0.36 + 0.36 * float(i), 0.18, 0.09)
		a.cyl(gp, 0.10, 0.02, k.plain(Color(0.78, 0.76, 0.68), 0.5), 16, "z")
		a.box(gp + Vector3(0.02, 0.03, 0.012), Vector3(0.008, 0.055, 0.004),
			k.plain(Color(0.62, 0.12, 0.10), 0.7), false, 0.6)
	a.box(panel + Vector3(-0.36, 0.26, 0.095), Vector3(0.06, 0.012, 0.004),
		k.plain(Color(0.66, 0.10, 0.08), 0.8), false)
	for i in range(6):
		a.box(panel + Vector3(-0.44 + 0.176 * float(i), -0.27, 0.09),
			Vector3(0.075, 0.11, 0.05), k.plain(Color(0.64, 0.60, 0.44), 0.5, 0.2), false)
	# 空着的那一格（剧本：一排保险丝，少一根）
	a.box(panel + Vector3(-0.44 + 0.176 * 3.0, -0.31, 0.088), Vector3(0.07, 0.05, 0.012), m_dark, false)

	# —— 工作台：工具 + 零件 + 一盏马灯（唯一“人待过”的痕迹）
	var bench := Vector3(-1.60, Y, -8.10)
	a.bev(bench + Vector3(0, 0.82, 0), Vector3(2.10, 0.07, 0.64),
		k.pbr("wood_planks_dirt", 1.2, Color(0.32, 0.26, 0.20), 0.9), 0.012, true)
	for sx in [-0.86, 0.86]:
		a.box(bench + Vector3(sx, 0.41, 0), Vector3(0.07, 0.82, 0.54), m_dark)
	k.model("props/metal_tool_chest", bench + Vector3(-0.68, 0, 0.02), 0.2, 0.60)
	k.model("props/wooden_crate_01", bench + Vector3(0.62, 0.855, 0.0), 0.3, 0.26, Color(0.78, 0.68, 0.54))
	for i in range(10):
		a.cyl(bench + Vector3(-0.26 + 0.075 * float(i % 5), 0.868, -0.16 + 0.09 * float(i / 5)),
			0.016, 0.012, k.plain(Color(0.48, 0.46, 0.40), 0.5, 0.7), 8)
	# 马灯
	a.box(bench + Vector3(0.24, 1.00, -0.20), Vector3(0.13, 0.19, 0.13), m_metal)
	a.box(bench + Vector3(0.24, 1.00, -0.20), Vector3(0.09, 0.12, 0.09),
		k.emit(Color(1.0, 0.62, 0.28), 1.4))
	lights["lamp"] = a.omni(bench + Vector3(0.24, 1.12, -0.20), Color(1.0, 0.58, 0.26),
		1.55, 4.2, true)

	# —— 从 1F 下来的铁盖洞口：在地面开一个方口，四边压钢框
	var hx0 := -2.60
	var hx1 := -1.70
	var hz0 := -8.20
	var hz1 := -6.40
	# 洞口：把地面那圈水膜和湿地板让开（用一块深色的井道盒子）
	a.box(Vector3((hx0 + hx1) * 0.5, Y - 0.02, (hz0 + hz1) * 0.5),
		Vector3(hx1 - hx0, 0.04, hz1 - hz0), m_dark, false)

	# 洞口的钢框
	a.box(Vector3((hx0 + hx1) * 0.5, Y + 0.05, hz0 - 0.05), Vector3(hx1 - hx0 + 0.16, 0.10, 0.10), m_metal, false)
	a.box(Vector3((hx0 + hx1) * 0.5, Y + 0.05, hz1 + 0.05), Vector3(hx1 - hx0 + 0.16, 0.10, 0.10), m_metal, false)
	a.box(Vector3(hx0 - 0.05, Y + 0.05, (hz0 + hz1) * 0.5), Vector3(0.10, 0.10, hz1 - hz0), m_metal, false)
	a.box(Vector3(hx1 + 0.05, Y + 0.05, (hz0 + hz1) * 0.5), Vector3(0.10, 0.10, hz1 - hz0), m_metal, false)
	# 洞口正下方的光（井道里有一点从上漏下来的门厅灯）
	a.omni(Vector3((hx0 + hx1) * 0.5, Y + 2.10, (hz0 + hz1) * 0.5),
		Color(0.82, 0.72, 0.54), 0.55, 2.6, false)

# ---------------------------------------------------------------- 单台锅炉
func _boiler(c: Vector3, burning: bool) -> void:
	# Blender 版锅炉（boiler_01，8208 面）：铸铁锥形炉体 + 真挖洞的炉门 +
	# 观火孔 + 出渣口 + 六道箍 + 铆钉圈 + 压力表 + 安全阀 + 烟囱接口。
	# 光影、位置、炉火仍由这里控制 —— 模型只负责形体。
	var inst := k.model("props/boiler_01", c, 0.0, 0.0)
	if inst != null:
		# 不烧的那台压暗、偏灰（铸铁冷下来的样子）
		if not burning:
			k._tint(inst, Color(0.74, 0.72, 0.70))
	# 烟囱：从锅炉顶接口往上穿到顶棚
	k.pipe(c + Vector3(0, 2.05, 0), c + Vector3(0, HH + Y + 0.10, 0), 0.13, m_rust, 12)
	if burning:
		# 炉膛火光：全案最暖的一盏（2000 K），从观火孔的位置往外打
		boiler_fire = a.omni(c + Vector3(0, 0.80, 0.72), Color(1.0, 0.42, 0.12),
			2.45, 5.4, true)
		# 地面上的一摊橙色反光
		a.omni(c + Vector3(0, 0.12, 1.10), Color(1.0, 0.46, 0.16), 0.90, 2.8, false)

# ================================================================ 五根水管
## 五根水管从头顶的黑暗里伸下来，全部通向 2F 洗衣店。剧本写死的画面。
func _pipes() -> void:
	var pip := k.pbr("metal_plate", 1.2, Color(0.34, 0.33, 0.31), 0.75, 0.55)
	var xs := [-1.20, -0.60, 0.00, 0.60, 1.20]
	var zline := 0.60          # 五根管子下来的那条线（在 2F 洗衣店正下方偏北）
	for i in range(5):
		var x: float = xs[i]
		# 立管：从顶棚下来
		k.pipe(Vector3(x, CEIL, zline), Vector3(x, Y + 0.18, zline), 0.075, pip, 12)
		k.ring(Vector3(x, Y + 2.20, zline), 0.10, 0.045, m_rust, "y", 14)
		k.ring(Vector3(x, Y + 0.75, zline), 0.10, 0.045, m_rust, "y", 14)
		# 手阀
		var vy: float = Y + 1.45 + 0.10 * float(i % 3)
		a.cyl(Vector3(x, vy, zline), 0.085, 0.07, m_rust, 12)
		k.pipe(Vector3(x - 0.10, vy, zline), Vector3(x + 0.10, vy, zline), 0.012, m_metal, 6)
		# 落地转 90°：往北（−Z）走，通向楼外
		k.pipe(Vector3(x, Y + 0.18, zline), Vector3(x, Y + 0.18, Z0 + 0.30), 0.075, pip, 12)
	# 支吊架
	for zz in [-2.20, -0.80, 0.60]:
		a.box(Vector3(0.0, CEIL - 0.10, zz), Vector3(2.90, 0.06, 0.08), m_rust, false)
		for x2 in xs:
			a.box(Vector3(x2, CEIL - 0.19, zz), Vector3(0.06, 0.20, 0.06), m_rust, false)
	# 方向牌：手写的「→ 洗衣店」
	a.box(Vector3(1.62, Y + 1.95, zline - 0.02), Vector3(0.46, 0.16, 0.008), m_paper, false)
	a.label("→ 洗衣店", Vector3(1.62, Y + 1.95, zline + 0.002), 0.055,
		Color(0.22, 0.18, 0.14), 0.0, 34)

# ================================================================ 蓄水池
func _pool() -> void:
	var cx := (POOL_X0 + POOL_X1) * 0.5
	var cz := (POOL_Z0 + POOL_Z1) * 0.5
	var w := POOL_X1 - POOL_X0
	var d := POOL_Z1 - POOL_Z0
	var wall_t := 0.26
	var bottom: float = Y - POOL_DEPTH
	# 池底
	a.quad_xz(POOL_X0, POOL_Z0, POOL_X1, POOL_Z1, bottom, m_conc, true)
	a.col(Vector3(cx, bottom - 0.15, cz), Vector3(w, 0.3, d))
	# 四壁
	k.wall_x(POOL_Z0 - wall_t * 0.5, POOL_X0 - wall_t, POOL_X1 + wall_t, bottom, POOL_DEPTH, m_conc, wall_t)
	k.wall_x(POOL_Z1 + wall_t * 0.5, POOL_X0 - wall_t, POOL_X1 + wall_t, bottom, POOL_DEPTH, m_conc, wall_t)
	k.wall_z(POOL_X0 - wall_t * 0.5, POOL_Z0, POOL_Z1, bottom, POOL_DEPTH, m_conc, wall_t)
	k.wall_z(POOL_X1 + wall_t * 0.5, POOL_Z0, POOL_Z1, bottom, POOL_DEPTH, m_conc, wall_t)
	# 池口内沿收口：楼板被挖开后的断面（0.30 m 厚）在这里露出来
	var lip := k.pbr("chipped_concrete", 0.7, Color(0.44, 0.44, 0.42), 1.0)
	a.box(Vector3(cx, Y - 0.15, POOL_Z0), Vector3(w, 0.32, 0.04), lip, false)
	a.box(Vector3(cx, Y - 0.15, POOL_Z1), Vector3(w, 0.32, 0.04), lip, false)
	a.box(Vector3(POOL_X0, Y - 0.15, cz), Vector3(0.04, 0.32, d), lip, false)
	a.box(Vector3(POOL_X1, Y - 0.15, cz), Vector3(0.04, 0.32, d), lip, false)
	# 池口压顶
	var cap := k.pbr("chipped_concrete", 0.6, Color(0.52, 0.52, 0.50), 1.0)
	a.box(Vector3(cx, Y + 0.06, POOL_Z0 - wall_t * 0.5), Vector3(w + wall_t * 2.0 + 0.10, 0.12, wall_t + 0.12), cap)
	a.box(Vector3(cx, Y + 0.06, POOL_Z1 + wall_t * 0.5), Vector3(w + wall_t * 2.0 + 0.10, 0.12, wall_t + 0.12), cap)
	a.box(Vector3(POOL_X0 - wall_t * 0.5, Y + 0.06, cz), Vector3(wall_t + 0.12, 0.12, d), cap)
	a.box(Vector3(POOL_X1 + wall_t * 0.5, Y + 0.06, cz), Vector3(wall_t + 0.12, 0.12, d), cap)

	# 铁梯
	k.ladder(Vector3(POOL_X0 + 0.34, Y + 0.14, cz), Vector3(POOL_X0 + 0.34, bottom + 0.10, cz), 0.46)
	# 铁梯上的锈水痕（一直延伸到水下）
	k.wet_band_x(POOL_Z0 - 0.28, POOL_X0 + 0.10, POOL_X0 + 0.60, Y, 1.45)
	# 池壁上的水位线：比现在高 1.5 m（2004-11-08 的水位）。
	# 注意它比池口还高 0.3 m —— 那晚水是漫出来的，不是“池子满”，是“整层被淹”。
	var mark_y: float = WATER_Y + 1.50
	_mark_y = mark_y
	var mark := k.plain(Color(0.32, 0.26, 0.19), 0.95)
	a.box(Vector3(cx, mark_y, POOL_Z0 - 0.02), Vector3(w, 0.035, 0.014), mark)
	a.box(Vector3(cx, mark_y, POOL_Z1 + 0.02), Vector3(w, 0.035, 0.014), mark)
	a.box(Vector3(POOL_X0 - 0.02, mark_y, cz), Vector3(0.014, 0.035, d), mark)
	a.box(Vector3(POOL_X1 + 0.02, mark_y, cz), Vector3(0.014, 0.035, d), mark)
	# 池口外那一圈墙上的水渍（漫出来的水渗进混凝土留下的）
	k.wet_band_x(POOL_Z0 - 0.30, POOL_X0 - 0.30, POOL_X1 + 0.30, Y, 0.90)

	# —— 池壁上的渗水（三条）：从水面往上渗的一条湿痕。
	#     水位涨，它跟着长 —— 这是玩家唯一能"肉眼看出在涨"的线索。
	var seep_mat := k.wet("rough_concrete", Color(0.10, 0.12, 0.12), 0.55)
	var seep_positions := [
		[POOL_Z0 + 0.02, POOL_X0 + 0.55, POOL_X0 + 1.05],   # 北壁
		[POOL_Z0 + 0.02, POOL_X1 - 1.05, POOL_X1 - 0.55],   # 北壁（另一段）
		[POOL_Z1 - 0.02, POOL_X0 + 0.95, POOL_X0 + 1.45],   # 南壁
	]
	for sp in seep_positions:
		var zz: float = sp[0]
		var x0: float = sp[1]
		var x1: float = sp[2]
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(absf(x1 - x0), 0.55)      # 基础长度 0.55 m，会随水位拉伸
		mi.mesh = pm
		mi.material_override = seep_mat
		mi.set_meta("dynamic", true)
		# 贴在池内壁上，下端在水面附近
		var face_n := 1.0 if zz < (POOL_Z0 + POOL_Z1) * 0.5 else -1.0
		mi.position = Vector3((x0 + x1) * 0.5, WATER_Y + 0.28, zz + 0.006 * face_n)
		a.root.add_child(mi)
		# scale.y 会随水位变化（1.0 = 基础长度）
		_seepage.append([mi, 1.0])
	# 水位线旁边手写的一行
	a.box(Vector3(POOL_X1 + 0.03, mark_y + 0.13, cz), Vector3(0.008, 0.11, 0.66), m_paper, false)
	a.label("2004-11-08", Vector3(POOL_X1 + 0.04, mark_y + 0.13, cz), 0.048,
		Color(0.22, 0.18, 0.14), -PI * 0.5)

	# 水面：缓慢上升的那一层
	water_base_y = WATER_Y
	water = k.water_surface(Vector3(cx, WATER_Y, cz), w - 0.02, d - 0.02, 40)
	# 水面反射的绿：B1 那盏“错的光”
	lights["pool_glow"] = a.omni(Vector3(cx, WATER_Y + 1.35, cz),
		Color(0.16, 0.50, 0.34), 1.20, 4.2, false)
	# 池口上方一盏暖的，把池壁的水位线与铁梯读出来（否则只剩一片绿）
	a.omni(Vector3(cx, CEIL - 0.55, cz), Color(1.0, 0.78, 0.54), 4.20, 9.0, true)
	# 贴着水面的一盏冷光：水本身的反射要有东西可反，池壁才不是一块黑
	a.omni(Vector3(cx, WATER_Y + 0.35, POOL_Z0 + 0.45), Color(0.50, 0.72, 0.88), 1.60, 4.4, false)
	# 池边地面的托底光（水池是这一间的主角，池边不能黑成一片）
	a.omni(Vector3(POOL_X0 - 0.90, Y + 1.30, cz), Color(0.74, 0.68, 0.54), 2.20, 5.8, false)
	# 池壁上那圈 2004 水位线单独补一盏：它是这一间的“读数”
	a.omni(Vector3(POOL_X1 - 0.55, WATER_Y + 1.35, cz), Color(1.0, 0.66, 0.40), 0.95, 2.8, false)

	# 池边的取样瓶 + 手电筒
	a.cyl(Vector3(POOL_X1 + 0.60, Y + 0.09, POOL_Z0 + 0.32), 0.035, 0.17,
		k.glass(Color(0.58, 0.72, 0.64, 0.30)), 10)
	a.box(Vector3(POOL_X1 + 0.92, Y + 0.045, POOL_Z1 - 0.22), Vector3(0.05, 0.05, 0.21),
		k.plain(Color(0.18, 0.18, 0.17), 0.5, 0.4), false, 0.4)

	# 池子上方的管廊：从五根管子分一路进池（读得出“自来水的来处”）
	k.pipe(Vector3(POOL_X0 - 0.20, Y + 0.20, cz), Vector3(POOL_X0 - 0.20, Y + 0.20, 0.60), 0.075,
		k.pbr("metal_plate", 1.2, Color(0.34, 0.33, 0.31), 0.75, 0.55), 12)

# ================================================================ 竖井底（废电梯井）
## 1F 的废电梯在东墙 z=−6.0，井道往下一直到 B1。这里是井底。
func _shaft_bottom() -> void:
	var sx0 := 2.60
	var sx1 := 4.80
	var sz0 := -7.20
	var sz1 := -5.00
	var cx := (sx0 + sx1) * 0.5
	var cz := (sz0 + sz1) * 0.5
	# 井道：从 B1 地面做到 1F 楼板底面（y = -0.30）。
	# 这里**一律不建碰撞**：竖井四面墙只是视觉，玩家掉下去靠的是真正的
	# 竖井四周的墙 —— 而 B1 的外围墙已经在那儿了。
	# 之前反复被挡住，就是因为这面“井壁”的碰撞盒顶面正好横在 y=−0.30 / −0.60，
	# 把下探射线一刀切断。井道不需要自己的碰撞：它的四面本来就是 B1 的墙。
	var shaft_top: float = -0.30
	var shaft_h: float = shaft_top - Y
	a.box(Vector3(sx1 + 0.14, Y + shaft_h * 0.5, cz), Vector3(0.28, shaft_h, sz1 - sz0), m_dark, false)
	a.box(Vector3(cx, Y + shaft_h * 0.5, sz0 - 0.14), Vector3(sx1 - sx0, shaft_h, 0.28), m_dark, false)
	a.box(Vector3(cx, Y + shaft_h * 0.5, sz1 + 0.14), Vector3(sx1 - sx0, shaft_h, 0.28), m_dark, false)
	# 井口一圈亮边的钢框（只视觉，读得出这是个人工开的洞）
	var ring_f2 := k.pbr("metal_plate", 1.4, Color(0.38, 0.38, 0.37), 0.65, 0.65)
	for bz2 in [sz0, sz1]:
		a.box(Vector3(cx, Y + 0.05, bz2), Vector3(sx1 - sx0 + 0.20, 0.06, 0.10), ring_f2, false)
	for bx2 in [sx0, sx1]:
		a.box(Vector3(bx2, Y + 0.05, cz), Vector3(0.10, 0.06, sz1 - sz0), ring_f2, false)
	# 井底：一块积水 + 一只凉鞋
	a.quad_xz(sx0, sz0, sx1, sz1, Y + 0.004, m_wet_floor)
	k.stain(Vector3(cx, Y + 0.008, cz), 1.60, Color(0.14, 0.16, 0.16, 1.0), 0.50, "blob")

	# 孩子的凉鞋：一只，侧躺着。这是全案最后一处物证。
	var sandal := k.plain(Color(0.40, 0.44, 0.50), 0.72)
	var sole := k.plain(Color(0.22, 0.20, 0.18), 0.9)
	var sp := Vector3(cx - 0.30, Y + 0.035, cz + 0.42)
	var g := a.push_group(sp, 0.7, true)
	sandal_model = g
	a.bev(Vector3(0, 0.012, 0), Vector3(0.085, 0.024, 0.185), sole, 0.008)
	a.box(Vector3(0, 0.032, -0.03), Vector3(0.070, 0.020, 0.115), sandal)
	for sz in [-0.020, 0.055]:
		a.box(Vector3(0, 0.045, sz), Vector3(0.078, 0.012, 0.016), sandal)
	a.box(Vector3(0, 0.048, -0.082), Vector3(0.050, 0.022, 0.012), sandal)
	a.pop_group()
	k.stain(sp + Vector3(-0.10, 0.004, 0.12), 0.42, Color(0.16, 0.18, 0.18, 1.0), 0.45, "blob")

	# 井壁上的粉笔箭头 + 「↑ 洗衣店」
	var chalk := k.plain(Color(0.76, 0.76, 0.70), 0.95)
	for i in range(6):
		var yy: float = Y + 0.60 + 0.30 * float(i)
		a.box(Vector3(cx, yy, sz0 + 0.16), Vector3(0.10 + 0.04 * float(i % 3), 0.018, 0.006),
			chalk, false, 0.0)
	a.label("↑ 洗衣店", Vector3(cx, Y + 2.10, sz0 + 0.17), 0.075,
		Color(0.78, 0.77, 0.70), 0.0, 36)

	# —— 停水通知：贴在南边墙上一张纸（未送达）
	var np := Vector3(cx - 0.30, Y + 1.45, sz1 + 0.16)
	a.box(np, Vector3(0.54, 0.38, 0.006), m_paper, false)
	a.label("停水通知", np + Vector3(0, 0.11, 0.006), 0.046,
		Color(0.20, 0.16, 0.12), 0.0, 32)
	a.label("2004-11-08  01:40", np + Vector3(0, -0.04, 0.006), 0.032,
		Color(0.26, 0.22, 0.17), 0.0, 26)
	a.label("· 未送达", np + Vector3(0, -0.14, 0.006), 0.040,
		Color(0.62, 0.14, 0.11), 0.0, 28)

	# 井口的下落光（从 1F 废电梯的门缝漏下来的一点点）
	a.omni(Vector3(cx, Y + 2.20, cz), Color(0.42, 0.52, 0.62), 2.60, 6.4, false)
	# 竖井底是玩家要蹲下找凉鞋的地方 —— 必须有足够的环境光，否则等于没有这个房间。
	# 这一盏是「井壁的反弹」，冷、软、大范围，不抢物证的高光。
	a.omni(Vector3(cx - 0.40, Y + 1.10, cz - 0.60), Color(0.38, 0.48, 0.58), 2.60, 6.6, false)
	# 贴地一盏小的：把那只凉鞋从黑里捞出来（这是全案最后一处物证）
	a.omni(Vector3(cx - 0.35, Y + 0.42, cz + 0.55), Color(0.86, 0.88, 0.82), 0.75, 1.9, false)

# ================================================================ 灯
func _lights() -> void:
	# 2000 K 的锅炉火光（_boiler 里已放）；这里补一盏“房间级”的暗红底光
	a.omni(Vector3(-1.40, CEIL - 0.60, -4.60), Color(1.0, 0.58, 0.30), 4.60, 12.5, true)
	# 顶棚两盏灯（暗，但要把混凝土的质感读出来）
	a.omni(Vector3(-3.20, CEIL - 0.70, -7.60), Color(1.0, 0.72, 0.44), 2.20, 7.5, false)
	# 竖井底那点冷绿
	lights["shaft"] = a.omni(Vector3(3.70, Y + 0.80, -6.10), Color(0.24, 0.42, 0.36),
		0.95, 4.8, false)
	# 悬着的两个灯泡（B1 只有两盏，都很暗）
	for p in [Vector3(-1.20, CEIL, -6.40), Vector3(0.90, CEIL, 4.20)]:
		k.bulb_lamp(p, 0.55, 1.05, 5.5, Color(1.0, 0.70, 0.40), true)

# ================================================================ 动画接口（给第三夜用）
## 蓄水池涨水：每 30 秒 1 cm。dt 是游戏秒。
## 蓄水池涨水：每 30 秒 1 cm（剧本写死）。
## dt 是游戏秒。剧情层可以直接调用；也可以设 water_rising = true 让它自己涨。
func rise_water(dt: float) -> void:
	if water == null:
		return
	# 上限：涨到池口（Y，即地面高度）就停 —— 再涨就漫出来了，
	# 而「漫出来」是 2004 年的事，不是现在。
	var ceil_y: float = Y - 0.02
	if water_base_y >= ceil_y:
		return
	water_base_y = minf(water_base_y + dt * (0.01 / 30.0), ceil_y)
	water.position.y = water_base_y
	_sync_seepage()

## 自动上涨的每帧驱动（由 _process 调）
func _process(dt: float) -> void:
	if not water_rising:
		return
	_rise_acc += dt
	# 每 0.5 s 结算一次，省得每帧都改 transform
	if _rise_acc >= 0.5:
		rise_water(_rise_acc)
		_rise_acc = 0.0

## 池壁上那几条渗水：水位越高，水痕越长（视觉上读得出"在涨"）
func _sync_seepage() -> void:
	if _seepage.is_empty():
		return
	var t: float = clampf((water_base_y - WATER_Y) / maxf(_mark_y - WATER_Y, 0.1), 0.0, 1.0)
	for sp in _seepage:
		var mi: MeshInstance3D = sp[0]
		var base_scale: float = sp[1]
		mi.scale.y = base_scale * (0.35 + 0.65 * t)

## 开始涨水（剧情层：第三夜进入 B1 时调用）
func start_rising() -> void:
	water_rising = true
	_rise_acc = 0.0

## 停止（比如玩家跑到竖井底时）
func stop_rising() -> void:
	water_rising = false

## 锅炉的火：熄灭（第三夜结尾可以调用）
func fire_out() -> void:
	if boiler_fire != null:
		boiler_fire.light_energy = 0.0
