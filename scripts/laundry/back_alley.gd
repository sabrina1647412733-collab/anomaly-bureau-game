extends RefCounted
## 后巷 + 消防梯（剧本 v2 区域 1-b，80 m²，夜间可走）
## ---------------------------------------------------------------------------
## 尺寸：4.0 × 20.0，两侧墙高 12 m。
## 内容：垃圾桶、消防梯（通往 4F 和 5F）、洗衣店的后门（**堵死**）、隔壁楼的窗户。
## 关键：消防梯的锁是坏的。这是第三条通往五楼的路，第二夜就能爬，
##       但爬到一半会看见洗衣店的窗户里有灯 —— 而那时洗衣店已经关门了。
##
## 位置：主楼北侧（1F 门厅北墙 z = −10 之外）。巷子沿 X 走，宽 4 m（z −14…−10），
##       长 20 m（x −10…+10）。主楼北墙上的后门在 z = −10。
##
## 消防梯：从后巷地面（y=0）沿主楼北墙爬上去，平台落在 4F（9.8）和 5F（12.7）。

const A := preload("res://scripts/laundry/laundry_art.gd")
const KIT := preload("res://scripts/laundry/laundry_kit.gd")

# 巷子
const AZ0 := -14.0          # 巷子北墙
const AZ1 := -10.0          # 主楼北墙（巷子南界）
const AX0 := -10.0
const AX1 := 10.0
const AH := 26.0            # 两侧墙高：抬到 26 m，仰视看不到顶（不然会看到穹顶边缘）

# 消防梯（贴主楼北墙，x 2.2…3.2 那一竖条）
const FZ := -10.0           # 墙面
const FX0 := 5.40           # 梯子的 x 范围（避开后门）
const FX1 := 6.60

var a: LaundryArt
var k: LaundryKit
var lights: Dictionary = {}

func _init(art: LaundryArt) -> void:
	a = art
	k = KIT.new(art)

func build() -> void:
	_materials()
	_ground()
	_walls()
	_back_doors()
	_windows()
	_fire_escape()
	_props()
	_lights()

var m_ground: StandardMaterial3D
var m_wall: StandardMaterial3D
var m_wall_far: StandardMaterial3D
var m_brick: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_rust: StandardMaterial3D
var m_dark: StandardMaterial3D

func _materials() -> void:
	# 后巷：湿沥青地面 + 脏砖墙。这是全案第一个「外面」，要和室内的瓷砖/抹灰完全不同。
	m_ground = k.pbr("asphalt_04", 0.42, Color(0.34, 0.34, 0.35), 0.78, 0.02, 1.0)
	m_wall = k.pbr("brick_wall_04", 0.16, Color(0.42, 0.38, 0.34), 1.0, 0.0, 1.1)
	m_wall_far = k.pbr("rough_concrete", 0.20, Color(0.34, 0.34, 0.33), 1.0, 0.0, 0.9)
	m_brick = k.pbr("brick_4", 1.4, Color(0.50, 0.42, 0.36), 1.0)
	m_metal = k.pbr("metal_plate", 1.3, Color(0.36, 0.36, 0.35), 0.6, 0.6)
	m_rust = k.pbr("rusty_metal", 0.9, Color(0.58, 0.50, 0.42), 1.0, 0.25)
	m_dark = k.plain(Color(0.035, 0.035, 0.04), 0.95)

# ================================================================ 地面
func _ground() -> void:
	var cx := (AX0 + AX1) * 0.5
	var cz := (AZ0 + AZ1) * 0.5
	k.slab(AX0, AZ0, AX1, AZ1, 0.0, m_ground)
	# 巷子中间那条排水槽（老巷子都有）
	var gr := k.pbr("metal_grate_rusty", 1.2, Color(0.40, 0.38, 0.34), 0.9, 0.35)
	a.quad_xz(AX0, cz - 0.18, AX1, cz + 0.18, 0.006, gr)
	# 湿痕：巷子里永远有一摊摊水
	for p in [Vector3(-4.6, 0.004, -12.4), Vector3(1.8, 0.004, -11.6), Vector3(6.4, 0.004, -13.0)]:
		k.stain(p, 1.6, Color(0.16, 0.18, 0.18, 1.0), 0.42, "blob")

# ================================================================ 两侧墙
func _walls() -> void:
	var cz := (AZ0 + AZ1) * 0.5
	# 巷子北墙（对面楼）
	k.wall_x(AZ0 - 0.15, AX0, AX1, 0.0, AH, m_wall, 0.30)
	# 巷子两端：西端封死（死巷），东端通出去
	k.wall_z(AX0 - 0.15, AZ0, AZ1, 0.0, AH, m_wall_far, 0.30)
	# 主楼北墙：1F 门厅已有，但只到 3.2 m 高 —— 后巷要看到整楼外墙，补到 12 m。
	# 注意：不能盖住 1F 已有的墙（否则 z-fighting），从 3.2 往上接。
	# 主楼北外墙：整条 26 m 高（原来只到 12 m，抬头就能看穿到天空穹顶）
	k.wall_x(AZ1 + 0.10, AX0, AX1, 0.0, AH, m_wall_far, 0.24)
	# 楼层分隔线（从巷子里能数出几层）
	for yy in [3.5, 6.9, 9.8, 12.7]:
		a.box(Vector3(0, yy, AZ1 + 0.02), Vector3(6.4, 0.12, 0.06), m_wall_far, false)
	# 墙脚一圈脏：巷子地面往上 1.2 m 的湿痕
	k.wet_band_x(AZ1 - 0.10, AX0, AX1, 0.0, 1.2, -1.0)
	k.wet_band_x(AZ0 + 0.16, AX0, AX1, 0.0, 0.9, 1.0)

# ================================================================ 后门（堵死）
func _back_doors() -> void:
	# 洗衣店的后门：剧本写「堵死」。位置在 2F 后房正下方（世界 z=-10, x≈-1.6）+ 1F 后门
	# 1F：后门（剧本 1F 北端出口，这里是「走出去」的那扇）
	var dz := AZ1 - 0.02
	a.box(Vector3(-0.55, 1.02, dz), Vector3(0.90, 2.05, 0.06),
		k.pbr("old_linoleum_flooring_01", 1.6, Color(0.20, 0.16, 0.12), 0.8), true)
	a.box(Vector3(-0.55, 2.06, dz - 0.01), Vector3(1.00, 0.08, 0.12), m_metal)
	# 门上的铁栅（后巷的门多半有）
	for i in range(4):
		a.box(Vector3(-0.55, 0.40 + 0.42 * float(i), dz - 0.035), Vector3(0.88, 0.030, 0.03), m_rust)
	# —— 洗衣店的后门：被砖砌死了（剧本写死「堵死」）
	var bx := 1.35
	a.box(Vector3(bx, 1.00, dz), Vector3(1.05, 2.00, 0.10), m_brick, true)
	# 砌死那块砖的缝（横竖各几道）
	for i in range(6):
		a.box(Vector3(bx, 0.18 + 0.30 * float(i), dz - 0.055),
			Vector3(1.02, 0.014, 0.014), k.plain(Color(0.30, 0.28, 0.25), 0.95), false)
	# 砌死的地方贴着一张纸（档案：这扇门从 2004 年起就没了）
	a.box(Vector3(bx, 1.55, dz - 0.062), Vector3(0.22, 0.28, 0.006),
		k.plain(Color(0.78, 0.75, 0.66), 0.95), false, 0.05)
	a.label("封", Vector3(bx, 1.55, dz - 0.068), 0.13,
		Color(0.55, 0.12, 0.10), 0.0, 30)

# ================================================================ 窗户
func _windows() -> void:
	# 巷子两边的窗户，一层一层往上
	var wz := AZ1 - 0.06
	for yy in [4.6, 7.9, 10.8]:
		for xx in [-2.2, 0.2, 2.4]:
			# 有的亮着（别的住户），有的黑
			var lit := (int(xx * 10) + int(yy)) % 3 == 0
			k.window_x(wz, xx, yy, 0.85, 1.10, m_metal,
				k.plain(Color(0.055, 0.058, 0.066), 0.9) if not lit
				else k.emit(Color(1.0, 0.76, 0.46), 0.9), 1.0)
			if lit:
				a.omni(Vector3(xx, yy + 0.55, wz - 0.35), Color(1.0, 0.72, 0.42), 0.75, 2.6, false)
	# 对面楼的窗户（北墙）
	for yy in [3.2, 6.2, 9.2]:
		for xx in [-7.0, -4.2, -1.4, 1.4, 4.2, 7.0]:
			k.window_x(AZ0 + 0.06, xx, yy, 0.80, 1.05, m_metal,
				k.plain(Color(0.05, 0.053, 0.06), 0.9), -1.0)
	# 洗衣店那一扇：爬到一半能看见里面有灯（剧本 1-b 的关键）
	k.window_x(AZ1 - 0.05, -1.15, 4.30, 1.10, 1.30, m_metal,
		k.emit(Color(0.90, 0.95, 1.0), 2.2), -1.0)
	a.omni(Vector3(-1.15, 5.00, AZ1 - 0.45), Color(0.86, 0.93, 1.0), 1.55, 4.2, false)

# ================================================================ 消防梯
## 剧本：「从后巷通到 5F 外墙，再到屋顶」「消防梯的锁是坏的」。
## 做法：贴主楼北墙的一条竖直铁梯 + 每层一个休息平台 + 最下面一段可放下的梯子（锁坏）。
func _fire_escape() -> void:
	var fz := AZ1 - 0.55          # 梯子离墙 0.55（留出人站的地方）
	var cx := (FX0 + FX1) * 0.5
	var top := 15.8               # 一直上到屋顶（15.6 + 一点）
	# —— 竖梯：两侧边梁 + 踏棍，从 y=2.6 到顶（2.6 以下是可放下的短梯）
	k.ladder(Vector3(cx, 2.60, fz), Vector3(cx, top, fz), 1.10, 0.035, m_rust)
	# —— 每层的休息平台（4F 9.8 / 5F 12.7 / 屋顶 15.6）
	for py in [9.8, 12.7, 15.6]:
		a.box(Vector3(cx, py + 0.04, fz + 0.30), Vector3(1.30, 0.08, 0.90), m_metal, true)
		# 平台护栏
		k.railing(Vector3(cx - 0.65, py + 0.08, fz + 0.72),
			Vector3(cx + 0.65, py + 0.08, fz + 0.72), 0.95, m_rust, 1.2, 0.022)
		k.railing(Vector3(cx - 0.65, py + 0.08, fz - 0.10),
			Vector3(cx - 0.65, py + 0.08, fz + 0.72), 0.95, m_rust, 1.2, 0.022)
		k.railing(Vector3(cx + 0.65, py + 0.08, fz - 0.10),
			Vector3(cx + 0.65, py + 0.08, fz + 0.72), 0.95, m_rust, 1.2, 0.022)
		# 平台与墙之间的支撑（斜杆）
		for sx in [-0.55, 0.55]:
			k.pipe(Vector3(cx + sx, py, fz + 0.72), Vector3(cx + sx, py - 0.70, fz + 0.05),
				0.022, m_rust, 8)
	# —— 最下面那段「可放下的梯子」：剧本说锁是坏的，所以它现在是放下来的
	#     用一根斜梯表示（从 y=2.6 斜下来到地面）
	var pend := a.push_group(Vector3(cx, 2.60, fz), 0.0, true)
	a.pop_group()
	k.ladder(Vector3(cx, 0.10, fz + 1.15), Vector3(cx, 2.62, fz), 0.90, 0.030, m_rust)
	# 断掉的锁（挂在梯子底部）
	a.box(Vector3(cx + 0.30, 0.34, fz + 1.02), Vector3(0.06, 0.08, 0.03),
		k.plain(Color(0.42, 0.38, 0.30), 0.6, 0.7), false, 0.3)
	# —— 墙上的固定支架（每 2 m 一个）
	var yy := 3.2
	while yy < top - 0.5:
		a.box(Vector3(cx, yy, fz + 0.18), Vector3(1.40, 0.08, 0.36), m_metal, false)
		yy += 2.0
	# —— 顶上的翻越护栏（到屋顶那段）
	a.box(Vector3(cx, 15.95, fz + 0.30), Vector3(1.30, 0.06, 0.90), m_metal, false)
	k.railing(Vector3(cx - 0.65, 16.00, fz + 0.72), Vector3(cx + 0.65, 16.00, fz + 0.72),
		1.00, m_rust, 1.2, 0.022)

# ================================================================ 道具
func _props() -> void:
	# 垃圾桶：3 个，靠对面墙
	for p in [Vector3(-6.8, 0.0, -13.2), Vector3(-6.2, 0.0, -13.3), Vector3(-0.9, 0.0, -13.4)]:
		k.model("props/bin_01", p, 0.3 + p.x * 0.1, 0.0)
	# 旧自行车（靠在墙边）
	var bx := 8.2
	a.box(Vector3(bx, 0.52, -10.9), Vector3(0.06, 0.06, 1.10),
		k.plain(Color(0.22, 0.22, 0.24), 0.6, 0.5), false, 0.12)
	for zz in [-11.40, -10.40]:
		k.ring(Vector3(bx, 0.34, zz), 0.33, 0.05, k.plain(Color(0.18, 0.18, 0.19), 0.7), "x", 18)
	# 空调外机：挂在对面墙上，两排
	# 空调外机：不要排得太整齐（原来 3×3 像贴纸），用固定散列错开
	var ac_i := 0
	for yy in [3.0, 6.4, 9.4]:
		for zz2 in [-8.0, -2.0, 5.0]:
			ac_i += 1
			var ox: float = fmod(float(ac_i) * 0.73, 0.6) - 0.3
			var oy: float = fmod(float(ac_i) * 1.31, 0.5) - 0.25
			a.box(Vector3(zz2 + ox, yy + oy, AZ0 + 0.35), Vector3(0.80, 0.58, 0.55),
				k.plain(Color(0.58, 0.58, 0.54), 0.75, 0.12), false)
			a.box(Vector3(zz2 + ox, yy + oy, AZ0 + 0.63), Vector3(0.66, 0.44, 0.02),
				k.plain(Color(0.26, 0.26, 0.25), 0.8), false)
			# 支架
			a.box(Vector3(zz2 + ox, yy + oy - 0.34, AZ0 + 0.30), Vector3(0.72, 0.05, 0.42),
				k.plain(Color(0.30, 0.28, 0.24), 0.7, 0.4), false)
	# 晾在巷子里的绳子（横跨，上面挂着几件旧衣服）
	var line_m := k.plain(Color(0.30, 0.29, 0.26), 0.85)
	k.pipe(Vector3(-3.0, 2.35, AZ0 + 0.10), Vector3(-3.0, 2.30, AZ1 - 0.10), 0.008, line_m, 5)
	for i in range(3):
		var px := -3.0 + (float(i) - 1.0) * 0.45
		k.garment(Vector3(px, 2.30, -12.0), k.cloth("rough_linen", Color(0.48, 0.44, 0.38), 2.0),
			0.40, 0.52, float(i) * 2.1, PI * 0.5)
	# 地面上的杂物：砖块、塑料袋、烟头
	for i in range(6):
		a.box(Vector3(-8.0 + 2.6 * float(i), 0.05, -12.2 + 0.9 * float(i % 3)),
			Vector3(0.22, 0.10, 0.11), m_brick, false, 0.4 * float(i))
	# 主楼北墙上的管道（雨落管 + 燃气管）
	k.pipe(Vector3(-3.05, 0.0, AZ1 - 0.14), Vector3(-3.05, AH, AZ1 - 0.14), 0.09, m_rust, 12)
	k.pipe(Vector3(3.05, 0.0, AZ1 - 0.14), Vector3(3.05, AH, AZ1 - 0.14), 0.09, m_rust, 12)
	# 巷子尽头的路灯（唯一的人工光）
	k.pipe(Vector3(-9.4, 0.0, -10.6), Vector3(-9.4, 4.4, -10.6), 0.06, m_metal, 10)
	a.box(Vector3(-9.4, 4.45, -10.6), Vector3(0.34, 0.10, 0.34), m_dark, false)
	a.box(Vector3(-8.9, 4.40, -10.6), Vector3(0.50, 0.06, 0.16), m_metal, false)
	a.box(Vector3(-8.68, 4.34, -10.6), Vector3(0.18, 0.04, 0.14),
		k.emit(Color(1.0, 0.80, 0.52), 2.4), false)

# ================================================================ 灯
func _lights() -> void:
	# 后巷：只靠巷尾一盏路灯 + 楼上窗户漏出来的光
	lights["lamp"] = a.omni(Vector3(-8.6, 4.15, -10.7), Color(1.0, 0.78, 0.48), 3.40, 9.0, true)
	# 月光从巷子上方斜切下来（巷宽 4 m，两侧 12 m 高，所以只有一条窄光带）
	k.moon_spot(Vector3(-2.0, 14.0, -12.0), Vector3(-2.0, 0.0, -12.0), 1.60, 26.0,
		Color(0.58, 0.68, 0.92))
	# 消防梯那一带的冷光（月光照在铁梯上）
	a.omni(Vector3((FX0 + FX1) * 0.5, 8.0, AZ1 - 1.2), Color(0.56, 0.66, 0.86), 1.10, 6.0, false)
	# 巷子中段的暗部非常弱的环境光（不然走到中间全黑）
	a.omni(Vector3(2.0, 3.0, -12.0), Color(0.42, 0.46, 0.54), 0.95, 9.0, false)
