extends RefCounted
## 屋顶 R ｜ 第三夜（180 m²）
## ---------------------------------------------------------------------------
## 剧本 v2 区域 6：
##   水箱  2.5 × 2.5 × 3.0，铁皮，里面是满的，水面离口沿 20 cm
##   晾衣绳 8 条，横跨屋顶，上面挂着 7 件衣服：全部是童装，全部是同款
##   天窗  1.2 × 1.2，正对 502 的水渍
##   楼顶地面 沥青防水层，有三处是新的修补过的
##
## 屋顶 y = 15.6（也就是 5F 地面 12.7 + 净高 2.6 + 楼板 0.3）。
## 光照规则：无人工光，只有夜空 + 水箱的铝反光。

const A := preload("res://scripts/laundry/laundry_art.gd")
const KIT := preload("res://scripts/laundry/laundry_kit.gd")

const Y := 15.6
const X0 := -6.0
const X1 := 6.0
const Z0 := -3.0
const Z1 := 12.0
const PARAPET := 0.85

var a: LaundryArt
var k: LaundryKit
var lights: Dictionary = {}
var clothes: Array = []
var water_tank: Node3D = null
var tank_water: MeshInstance3D = null

func _init(art: LaundryArt) -> void:
	a = art
	k = KIT.new(art)

func build() -> void:
	_materials()
	_deck()
	_parapet()
	_water_tank()
	_clothes_lines()
	_skylight_from_above()
	_roof_props()
	_night()

var m_roof: StandardMaterial3D
var m_patch: StandardMaterial3D
var m_wall: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_rust: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_alum: StandardMaterial3D

func _materials() -> void:
	# 沥青防水层：深灰黑、粗糙、有一点反光（夜里下过雨没干透）
	# 沥青 albedo 原来 0.30，夜里几乎不反光 → 站在屋顶像掉进洞。
	# 提到 0.44，并把 roughness 降一点让月光有反光（湿沥青本来就有油光）。
	m_roof = k.pbr("asphalt_04", 0.34, Color(0.54, 0.54, 0.55), 0.66, 0.03, 1.0)
	m_patch = k.pbr("asphalt_04", 0.30, Color(0.20, 0.20, 0.21), 0.62, 0.02, 1.2)
	m_wall = k.pbr("brick_wall_04", 0.32, Color(0.46, 0.42, 0.38), 1.0, 0.0, 0.8)
	m_metal = k.pbr("metal_plate", 1.3, Color(0.52, 0.53, 0.54), 0.7, 0.7)
	m_rust = k.pbr("rusty_metal", 0.85, Color(0.62, 0.52, 0.42), 1.0, 0.2)
	m_dark = k.plain(Color(0.045, 0.045, 0.05), 0.95)
	m_alum = k.pbr("metal_plate", 1.1, Color(0.78, 0.79, 0.80), 0.38, 0.85, 0.7)

# ================================================================ 屋面
func _deck() -> void:
	# 屋面本体：一张朝上的沥青面 + 下面 0.30 m 的楼板实体。
	# 关键：5F 的天花只做到 12.7+2.6 = 15.3，与屋面 15.6 之间这 0.3 m
	# 必须有东西，否则从屋顶俯视会直接看进 5F 房间（会穿帮）。
	# 屋面给实际楼梯留洞，不能用完整楼板压住最后一跑。
	var xs := [X0,.30,2.80,X1]
	var zs := [Z0,10.10,Z1]
	for ix in range(xs.size()-1):
		for iz in range(zs.size()-1):
			if ix == 1 and iz == 1: continue
			k.slab_solid(xs[ix],zs[iz],xs[ix+1],zs[iz+1],Y,m_roof,k.plain(Color(.24,.24,.23),.95))
	# 楼板侧面：把 5F 顶上那 0.3 m 的楼板厚度在女儿墙内侧读出来
	var edge := k.pbr("rough_concrete", 0.6, Color(0.44, 0.43, 0.40), 1.0)
	a.box(Vector3(0, Y - 0.16, Z0 + 0.20), Vector3(X1 - X0, 0.32, 0.10), edge, false)
	a.box(Vector3(0, Y - 0.16, Z1 - 0.20), Vector3(X1 - X0, 0.32, 0.10), edge, false)
	# 女儿墙（四周一圈，比人高一点点）：外面是 15.6 + 0.85 = 16.45 的天际线
	k.wall_x(Z0, X0, X1, Y, PARAPET, m_wall, 0.30)
	k.wall_x(Z1,X0,.30,Y,PARAPET,m_wall,.30)
	k.wall_x(Z1,2.80,X1,Y,PARAPET,m_wall,.30)
	k.wall_z(X0, Z0, Z1, Y, PARAPET, m_wall, 0.30)
	k.wall_z(X1, Z0, Z1, Y, PARAPET, m_wall, 0.30)
	# 压顶：一圈浅色的水泥盖板（女儿墙顶上那条亮线，夜里最好看）
	var cap := k.pbr("chipped_concrete", 0.7, Color(0.56, 0.55, 0.52), 1.0)
	a.box(Vector3(0, Y + PARAPET + 0.04, Z0), Vector3(X1 - X0 + 0.36, 0.08, 0.42), cap, false)
	a.box(Vector3((X0+.30)*.5,Y+PARAPET+.04,Z1),Vector3(.30-X0,.08,.42),cap)
	a.box(Vector3((X1+2.80)*.5,Y+PARAPET+.04,Z1),Vector3(X1-2.80,.08,.42),cap)
	a.box(Vector3(X0, Y + PARAPET + 0.04, (Z0 + Z1) * 0.5), Vector3(0.42, 0.08, Z1 - Z0), cap, false)
	a.box(Vector3(X1, Y + PARAPET + 0.04, (Z0 + Z1) * 0.5), Vector3(0.42, 0.08, Z1 - Z0), cap, false)

	# 三处新的修补过的沥青：颜色更深、边缘有接缝（剧本写死的三处）
	var patches := [
		[Vector3(-3.20, 0.0, 8.40), Vector2(2.40, 1.70), 0.06],
		[Vector3(2.60, 0.0, 4.10), Vector2(1.80, 2.20), -0.10],
		[Vector3(-0.90, 0.0, 11.20), Vector2(1.60, 1.40), 0.04],
	]
	for p in patches:
		var c: Vector3 = p[0]
		var sz: Vector2 = p[1]
		a.quad_xz(c.x - sz.x * 0.5, c.z - sz.y * 0.5, c.x + sz.x * 0.5, c.z + sz.y * 0.5,
			Y + 0.006, m_patch)
		# 接缝：一圈比周围亮的边
		var seam := k.plain(Color(0.40, 0.39, 0.38), 0.9)
		a.box(Vector3(c.x, Y + 0.008, c.z - sz.y * 0.5), Vector3(sz.x, 0.004, 0.035), seam)
		a.box(Vector3(c.x, Y + 0.008, c.z + sz.y * 0.5), Vector3(sz.x, 0.004, 0.035), seam)
		a.box(Vector3(c.x - sz.x * 0.5, Y + 0.008, c.z), Vector3(0.035, 0.004, sz.y), seam)
		a.box(Vector3(c.x + sz.x * 0.5, Y + 0.008, c.z), Vector3(0.035, 0.004, sz.y), seam)

	# 落水口 + 排水管（顺着女儿墙内侧下来）
	k.ring(Vector3(4.60, Y + 0.03, 10.20), 0.16, 0.05, m_metal, "y", 16)
	a.cyl(Vector3(4.60, Y + 0.02, 10.20), 0.14, 0.04, m_dark, 16)
	k.pipe(Vector3(4.60, Y - 0.02, 10.20), Vector3(4.60, Y - 0.90, 10.20), 0.07, m_rust, 12)

	# 一根排气立管 + 两个蘑菇头（屋顶的“杂”）
	k.pipe(Vector3(-4.40, Y, 2.20), Vector3(-4.40, Y + 1.55, 2.20), 0.075, m_rust, 12)
	a.cyl(Vector3(-4.40, Y + 1.60, 2.20), 0.15, 0.10, m_metal, 14)
	a.cyl(Vector3(-4.40, Y + 1.68, 2.20), 0.19, 0.05, m_metal, 14)
	k.pipe(Vector3(-3.10, Y, 10.40), Vector3(-3.10, Y + 1.20, 10.40), 0.06, m_rust, 10)
	a.cyl(Vector3(-3.10, Y + 1.24, 10.40), 0.13, 0.08, m_metal, 12)

# ================================================================ 女儿墙
func _parapet() -> void:
	# 与真实最后一跑对齐的楼梯帽。北面开门，保留头部净空。
	for xx in [.20,2.90]: k.wall_z(xx,9.75,14.30,Y,2.30,m_wall,.16)
	k.wall_x(14.30,.20,2.90,Y,2.30,m_wall,.16)
	k.wall_x(9.75,.20,1.48,Y,2.30,m_wall,.16)
	k.wall_x(9.75,2.64,2.90,Y,2.30,m_wall,.16)
	a.box(Vector3(2.06,Y+2.2,9.75),Vector3(1.16,.20,.16),m_wall,true)
	a.box(Vector3(1.55,Y+2.36,12.0),Vector3(2.90,.12,4.80),m_roof,true)
	a.label("屋顶出口",Vector3(2.06,Y+2.04,9.64),.06,Color(.8,.8,.7),0)
	k.door_casing(Vector3(2.06,Y,9.75),1.16,2.10,"x",m_metal,.09)

func _water_tank() -> void:
	var c := Vector3(-3.60, Y, 6.20)
	var w := 2.5
	var d := 2.5
	var h := 3.0
	water_tank = a.push_group(c, 0.0)
	# 支腿：四根角钢 + 斜撑（架高 0.55，让人从下面能看见）
	var leg := k.pbr("metal_plate", 1.4, Color(0.34, 0.34, 0.35), 0.55, 0.7)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			a.box(Vector3(sx * (w * 0.5 - 0.14), 0.28, sz * (d * 0.5 - 0.14)),
				Vector3(0.10, 0.56, 0.10), leg)
	# 承台
	a.box(Vector3(0, 0.58, 0), Vector3(w + 0.10, 0.10, d + 0.10), leg)
	# 箱体：四面板 + 顶沿
	var body := k.pbr("rusty_metal", 0.55, Color(0.50, 0.48, 0.45), 1.0, 0.35)
	a.box(Vector3(0, 0.63 + h * 0.5, 0), Vector3(w, h, d), body, true)
	# 竖向的加强肋（铁皮水箱的“鼓包”读法）
	for i in range(4):
		var t: float = (float(i) + 0.5) / 4.0
		for sz2 in [-1.0, 1.0]:
			a.box(Vector3(-w * 0.5 + w * t, 0.63 + h * 0.5, sz2 * (d * 0.5 + 0.015)),
				Vector3(0.035, h - 0.10, 0.03), m_rust)
		for sx2 in [-1.0, 1.0]:
			a.box(Vector3(sx2 * (w * 0.5 + 0.015), 0.63 + h * 0.5, -d * 0.5 + d * t),
				Vector3(0.03, h - 0.10, 0.035), m_rust)
	# 三道横向箍
	for i in range(3):
		var yy: float = 0.63 + 0.30 + float(i) * 0.90
		a.box(Vector3(0, yy, 0), Vector3(w + 0.06, 0.045, d + 0.06), m_rust)
	# 顶盖：一圈口沿 + 中间一个检修口（开着）
	a.box(Vector3(0, 0.63 + h, 0), Vector3(w + 0.14, 0.08, d + 0.14), m_metal)
	a.box(Vector3(0, 0.63 + h + 0.05, 0), Vector3(0.80, 0.03, 0.80), m_dark)
	# —— 水面：口沿以下 0.20 m。这是“里面是满的”。
	var wy: float = 0.63 + h - 0.20
	tank_water = k.water_surface(Vector3(0, wy, 0), 0.76, 0.76, 18)
	tank_water.set_meta("dynamic", true)
	# 水面反射的那点铝光——屋顶那盏“错的光”
	lights["tank"] = a.omni(c + Vector3(0, 0.63 + h + 0.45, 0),
		Color(0.42, 0.56, 0.62), 1.35, 5.5, false)
	a.pop_group()

	# 出水立管：从水箱下来，一直下到楼里（读作"整栋楼的水")
	k.pipe(c + Vector3(0, 0.30, -1.30), c + Vector3(0, -3.20, -1.30), 0.075, m_rust, 12)
	k.pipe(c + Vector3(0, 0.30, 1.30), c + Vector3(0, -3.20, 1.30), 0.075, m_rust, 12)
	# 上水箱的小铁梯（从屋面到口沿）
	k.ladder(c + Vector3(-1.42, 0.0, -0.55), c + Vector3(-1.42, 0.63 + h + 0.15, -0.55), 0.40)

# ================================================================ 晾衣绳 + 7 件童装
## 8 条，横跨屋顶。上面挂着 7 件衣服：全部是童装，全部是同款。
## 第 8 条是空的 —— 这一点必须让玩家自己数出来。
func _clothes_lines() -> void:
	var pole := k.pbr("rusty_metal", 1.2, Color(0.40, 0.34, 0.28), 0.8, 0.3)
	var line := k.plain(Color(0.30, 0.29, 0.26), 0.85)
	# 四根立杆：每边两根
	var posts := [
		Vector3(-5.30, 0, -1.60), Vector3(5.30, 0, -1.60),
		Vector3(-5.30, 0, 9.60), Vector3(5.30, 0, 9.60),
	]
	for p in posts:
		k.pipe(Vector3(p.x, Y, p.z), Vector3(p.x, Y + 2.55, p.z), 0.045, pole, 10)
		# 底座
		a.cyl(Vector3(p.x, Y + 0.05, p.z), 0.12, 0.10, pole, 10)
		# 斜拉索（往女儿墙）
		k.pipe(Vector3(p.x, Y + 2.45, p.z),
			Vector3(p.x + (0.0 if absf(p.x) < 1.0 else signf(p.x) * 0.55), Y + 0.80,
				p.z + (0.55 if p.z < 0.0 else -0.55)), 0.012,
			k.plain(Color(0.26, 0.25, 0.23), 0.8), 6)

	# 8 条绳：沿 Z 方向，x 从 −4.2 到 3.6，等距
	var z_a: float = -1.60
	var z_b: float = 9.60
	for i in range(8):
		var x: float = -4.20 + float(i) * (7.80 / 7.0)
		# 绳：两根立杆之间的低垂曲线（用几段直管拼出的下垂）
		var seg := 6
		var prev := Vector3(x, Y + 2.42, z_a)
		for s in range(1, seg + 1):
			var t := float(s) / float(seg)
			var zz: float = lerpf(z_a, z_b, t)
			var sag := sin(PI * t) * 0.16
			var cur := Vector3(x, Y + 2.42 - sag, zz)
			k.pipe(prev, cur, 0.008, line, 5)
			prev = cur
		# 前 7 条各挂 1 件；第 8 条空着
		if i < 7:
			var tpos: float = 0.35 + 0.06 * float(i % 3)
			var zz2: float = lerpf(z_a, z_b, tpos)
			var sag2 := sin(PI * tpos) * 0.16
			# 全部同款：同一块藏青布 + 白条纹，只是挂的姿势微差
			var knit := k.cloth("poly_wool_herringbone", Color(0.20, 0.26, 0.40), 3.0)
			var g := k.garment(Vector3(x, Y + 2.42 - sag2 - 0.03, zz2), knit,
				0.36, 0.42, float(i) * 1.7, PI * 0.5)
			# 白条纹（袖口 + 下摆）
			a.box(Vector3(x, Y + 2.42 - sag2 - 0.40, zz2), Vector3(0.35, 0.022, 0.015),
				k.plain(Color(0.86, 0.86, 0.84), 0.9))
			# 晾衣夹
			for cx in [-0.12, 0.12]:
				a.box(Vector3(x + cx, Y + 2.42 - sag2 - 0.01, zz2),
					Vector3(0.030, 0.055, 0.020),
					k.plain(Color(0.62, 0.58, 0.44), 0.6))
			clothes.append(g)

# ================================================================ 天窗（从上面看）
## 天窗在 502 的正上方：屋顶上这一块是凸起的玻璃罩，从下面 502 看是天花板上的洞。
func _skylight_from_above() -> void:
	var sx0: float = -2.30
	var sz0: float = 2.90
	var sx1: float = -1.10
	var sz1: float = 4.10
	var cx := (sx0 + sx1) * 0.5
	var cz := (sz0 + sz1) * 0.5
	var w := sx1 - sx0
	var d := sz1 - sz0
	# 天窗井的凸台（比屋面高 0.16）
	var frame := k.pbr("metal_plate", 1.5, Color(0.36, 0.36, 0.35), 0.6, 0.6)
	a.box(Vector3(cx, Y + 0.20, sz0 + 0.03), Vector3(w + 0.12, 0.40, 0.06), frame, false)
	a.box(Vector3(cx, Y + 0.20, sz1 - 0.03), Vector3(w + 0.12, 0.40, 0.06), frame, false)
	a.box(Vector3(sx0 + 0.03, Y + 0.20, cz), Vector3(0.06, 0.40, d + 0.12), frame, false)
	a.box(Vector3(sx1 - 0.03, Y + 0.20, cz), Vector3(0.06, 0.40, d + 0.12), frame, false)
	# 玻璃顶（微微反光，夜里透出下面 502 的月光）
	var gm := k.glass(Color(0.30, 0.38, 0.48, 0.26))
	a.box(Vector3(cx, Y + 0.38, cz), Vector3(w, 0.02, d), gm)
	# 天窗四周一圈“水渍”——502 那块人形水痕就是从这儿渗下去的
	k.stain(Vector3(cx, Y + 0.005, sz0 - 0.55), 1.35,
		Color(0.16, 0.18, 0.18, 1.0), 0.38, "blob")
	# 天窗旁边：一把扔下的螺丝刀 + 撬开的木螺丝（链 C 的终点）
	a.box(Vector3(sx0 - 0.30, Y + 0.012, sz1 + 0.28), Vector3(0.03, 0.02, 0.16),
		k.plain(Color(0.44, 0.42, 0.38), 0.4, 0.8), false, 0.7)
	a.box(Vector3(sx0 - 0.30, Y + 0.012, sz1 + 0.28), Vector3(0.035, 0.045, 0.035),
		k.plain(Color(0.30, 0.26, 0.20), 0.5, 0.5), false, 0.7)
	for i in range(3):
		a.cyl(Vector3(sx1 + 0.28 + 0.06 * float(i), Y + 0.012, sz1 + 0.10 + 0.05 * float(i)),
			0.008, 0.020, k.plain(Color(0.52, 0.50, 0.44), 0.4, 0.8), 6, "y")

# ================================================================ 屋顶杂项
func _roof_props() -> void:
	# 一把断了一条腿的木椅（有人上来过）
	k.model("painted_wooden_chair_01", Vector3(4.20, Y, 8.30), 2.1, 0.92,
		Color(0.62, 0.56, 0.46))
	# 一只倒扣的铁桶
	a.cyl(Vector3(3.30, Y + 0.17, 9.10), 0.17, 0.34,
		k.pbr("rusty_metal", 1.4, Color(0.46, 0.40, 0.34), 0.9, 0.25), 14)
	# 一排砖压着的旧油毡（怕风把补的地方掀了）
	for i in range(4):
		a.box(Vector3(-1.90 + 0.24 * float(i), Y + 0.13, 8.60 + 0.10 * float(i % 2)),
			Vector3(0.22, 0.10, 0.11),
			k.pbr("brick_4", 1.8, Color(0.52, 0.44, 0.38), 1.0), false, 0.2 * float(i))
	# 一只塑料袋（风把它吹到女儿墙上卡住了）
	a.box(Vector3(-5.70, Y + 0.30, 3.40), Vector3(0.22, 0.28, 0.06),
		k.plain(Color(0.78, 0.80, 0.78), 0.55), false, 0.4)
	# 烟囱状的通风管群（3 根，靠北墙）
	for i in range(3):
		var px: float = 1.20 + 0.55 * float(i)
		k.pipe(Vector3(px, Y, Z0 + 0.55), Vector3(px, Y + 1.10, Z0 + 0.55), 0.055, m_rust, 10)
		a.cyl(Vector3(px, Y + 1.14, Z0 + 0.55), 0.12, 0.07, m_metal, 12)

# ================================================================ 夜
## 屋顶无人工光：只有夜空 + 水箱的铝反光。
## 用一个内翻的星空穹顶 + 一盏很弱的冷色天光（DirectionalLight 只作用于这一层也做不到，
## 所以用一个大 range 的 omni 模拟"天在发光"）。
func _night() -> void:
	k.sky_dome(Vector3(0, Y + 2.0, 4.0), 90.0)
	# 月光：一盏从上往下的 spot，色温 6500 K。屋顶必须能看清，否则等于没做。
	k.moon_spot(Vector3(-6.0, Y + 16.0, 16.0), Vector3(-1.0, Y, 5.0), 5.2, 52.0,
		Color(0.58, 0.68, 0.94))
	# 第二盏月光专门照晾衣绳（那一排 7 件衣服是这一层的“戏眼”）
	k.moon_spot(Vector3(4.0, Y + 13.0, 6.0), Vector3(-1.0, Y + 2.1, 3.6), 3.8, 40.0,
		Color(0.62, 0.72, 0.96))
	# 城市光害：地平线方向一盏极弱的暖光，把女儿墙的压顶打亮
	a.omni(Vector3(-9.0, Y + 2.4, 22.0), Color(0.66, 0.54, 0.38), 1.35, 30.0, false)
	# —— 屋顶是 180 m² 的大平面，只靠两盏 spot 会有一半是黑的。
	#    补一盏「夜空漫射」：大范围、很弱、贴顶，专门托住女儿墙内侧与地面暗部。
	#    色温偏冷（6500 K），强度克制，不破坏“无人工光”的设定。
	# 四盏分散的「夜空漫射」，覆盖 180 m² 的四个象限（单靠中央一盏会有暗环）
	a.omni(Vector3(-3.2, Y + 6.0, 0.5), Color(0.58, 0.68, 0.92), 4.20, 16.0, false)
	a.omni(Vector3(3.2, Y + 6.0, 0.5), Color(0.58, 0.68, 0.92), 4.20, 16.0, false)
	a.omni(Vector3(-3.2, Y + 6.0, 9.5), Color(0.58, 0.68, 0.92), 4.20, 16.0, false)
	a.omni(Vector3(3.2, Y + 6.0, 9.5), Color(0.58, 0.68, 0.92), 4.20, 16.0, false)
	# 女儿墙内侧一圈的反弹光（月光打在墙上的二次反射）
	a.omni(Vector3(0.0, Y + 1.6, 1.0), Color(0.46, 0.56, 0.76), 2.80, 12.0, false)
	a.omni(Vector3(0.0, Y + 1.6, 9.0), Color(0.46, 0.56, 0.76), 2.80, 12.0, false)
	# 水箱的铝反光：从上方贴着脸打，把铁皮的竖肋读出来
	a.omni(Vector3(-3.60, Y + 3.30, 8.40), Color(0.62, 0.74, 0.84), 2.20, 7.0, false)
	# 水箱开口那一圈溢出来的冷光（水面在反光）
	a.omni(Vector3(-3.60, Y + 4.10, 6.20), Color(0.50, 0.66, 0.74), 0.85, 6.0, false)
	# 楼梯帽门口的一盏感应灯（老楼都有，屋顶这一盏还亮着）
	a.box(Vector3(1.55, Y + 2.05, Z1 - 0.30), Vector3(0.24, 0.06, 0.24),
		k.plain(Color(0.20, 0.19, 0.18), 0.7))
	a.box(Vector3(1.55, Y + 2.00, Z1 - 0.30), Vector3(0.20, 0.03, 0.20),
		k.emit(Color(1.0, 0.82, 0.60), 1.2))
	a.omni(Vector3(1.55, Y + 1.85, Z1 - 0.55), Color(1.0, 0.76, 0.50), 1.60, 5.5, true)
