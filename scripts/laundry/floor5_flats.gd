extends RefCounted
## 5F ｜ 空屋、门缝、消防梯（第二夜末 — 第三夜，280 m²）
## ---------------------------------------------------------------------------
## 剧本 v2 区域 5。这一层的恐怖是“过于干净”：
##   502 空屋：真的空。连灰都很少。地板中央一块 2×2 的水渍，形状像一个人躺着。
##             天窗就在正上方（链 C 的终点）。
##   503 门缝有光：第一夜从楼下走过看到门缝里有光，第二夜上楼发现是黑的。
##             门从里面反锁；里面一台洗衣机的声音；打开后 7 台玩具洗衣机 + 一张湿床。
##   走廊：无灯。只有天窗月光 6500 K。
##
## 5F 楼面 y = 12.7，净高 2.6。屋顶 y = 15.6，所以这一层天花之上还有 0.3 m 楼板。

const A := preload("res://scripts/laundry/laundry_art.gd")
const KIT := preload("res://scripts/laundry/laundry_kit.gd")

const Y := 12.7
const HH := 2.6
const X0 := -3.2
const X1 := 3.2
const CZ0 := 5.4
const CZ1 := 10.1

var a: LaundryArt
var k: LaundryKit
var lights: Dictionary = {}
var doors: Dictionary = {}
var toy_washers: Array = []
## 天窗：1.2 × 1.2，正对 502 地板中央那道人形水渍（502 中心 x=−1.7, z=3.5）
var skylight_rect := {"x0": -2.30, "z0": 2.90, "x1": -1.10, "z1": 4.10}

func _init(art: LaundryArt) -> void:
	a = art
	k = KIT.new(art)

func build() -> void:
	_materials()
	_corridor()
	_room_502()
	_room_503()
	_stair()

var m_floor: StandardMaterial3D
var m_wall: StandardMaterial3D
var m_ceil: StandardMaterial3D
var m_wood: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_paper: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_rail: StandardMaterial3D

func _materials() -> void:
	# 5F 已经空了很久：地板是灰的，墙是旧的、没上漆的抹灰，天花板有渗水的黄斑。
	m_floor = k.pbr("old_wooden_floor_01", 0.48, Color(0.40, 0.36, 0.31), 0.85, 0.0, 0.9)
	m_wall = k.pbr("grey_plaster_02", 0.32, Color(0.66, 0.65, 0.62), 1.0, 0.0, 0.6)
	m_ceil = k.pbr("grey_plaster_02", 0.38, Color(0.58, 0.57, 0.54), 1.0)
	m_wood = k.pbr("old_linoleum_flooring_01", 1.1, Color(0.42, 0.34, 0.26), 0.85)
	m_dark = k.plain(Color(0.055, 0.055, 0.060), 0.95)
	m_paper = k.plain(Color(0.84, 0.81, 0.72), 0.95)
	m_metal = k.pbr("metal_plate", 1.5, Color(0.58, 0.58, 0.56), 0.7, 0.6)
	m_rail = k.pbr("old_linoleum_flooring_01", 1.4, Color(0.26, 0.20, 0.15), 0.7)

# ================================================================ 走廊（无灯）
func _corridor() -> void:
	var zc := (CZ0 + CZ1) * 0.5
	k.slab(X0, CZ0, X1, CZ1, Y, m_floor)
	k.slab_solid(X0, CZ0, X1, CZ1, Y + HH + 0.30, m_ceil, m_ceil)
	k.wall_z(X0 - 0.06, CZ0, CZ1, Y, HH, m_wall)
	k.wall_z(X1 + 0.06, CZ0, CZ1, Y, HH, m_wall)
	# 北墙：502 / 503 两扇门，门洞真的挖开
	var cuts := [[-2.15, -1.25], [1.25, 2.15]]
	var xx := X0
	for c in cuts:
		if c[0] > xx + 0.001:
			k.wall_x(CZ0 - 0.06, xx, c[0], Y, HH, m_wall)
		a.box(Vector3((c[0] + c[1]) * 0.5, Y + HH - (HH - 2.05) * 0.5, CZ0 - 0.06),
			Vector3(c[1] - c[0], HH - 2.05, 0.12), m_wall, false)
		xx = c[1]
	if xx < X1 - 0.001:
		k.wall_x(CZ0 - 0.06, xx, X1, Y, HH, m_wall)
	# 南墙带楼梯洞口，由下面「楼梯口」那段分段建，这里不能画整块。
	k.skirting_x(CZ0 + 0.015, X0, X1, Y, m_dark, Vector3(0, 0, 0.02))
	k.skirting_x(CZ1 - 0.015, X0, X1, Y, m_dark, Vector3(0, 0, -0.02))
	k.skirting_z(X0 + 0.015, CZ0, CZ1, Y, m_dark, Vector3(0.02, 0, 0))
	k.skirting_z(X1 - 0.015, CZ0, CZ1, Y, m_dark, Vector3(-0.02, 0, 0))

	# 502 / 503 的门套
	for cx in [-1.70, 1.70]:
		k.door_casing(Vector3(cx, Y, CZ0 - 0.02), 0.90, 2.05, "x",
			k.pbr("old_linoleum_flooring_01", 2.0, Color(0.30, 0.24, 0.18), 0.7), 0.12)
	# 门牌（锈得几乎看不清）
	k.door_plate(Vector3(-1.08, Y + 1.60, CZ0 + 0.10), "502", 0.0, 0.082)
	k.door_plate(Vector3(2.32, Y + 1.60, CZ0 + 0.10), "503", 0.0, 0.082)

	# —— 5F 走廊自己是没有灯的（剧本写死）。但不能全黑，否则不能走。
	#     光来自三处，都不是这一层的：4F 楼梯口漏上来的暖光、天窗的冷月光、
	#     北墙尽头那扇破窗的街灯。用这三盏把“轮廓”做出来。
	#     另外：5F 走廊的墙也是“湿的”（楼上的水一路渗下来），这条湿痕是本层的说明
	a.omni(Vector3(1.55, Y + 1.70, CZ1 - 0.35), Color(1.0, 0.78, 0.52), 2.30, 5.4, false)
	a.omni(Vector3(-1.10, Y + 1.80, 7.40), Color(0.62, 0.72, 0.92), 1.25, 5.6, false)
	a.omni(Vector3(0.60, Y + 1.60, 8.60), Color(0.52, 0.60, 0.76), 0.85, 5.2, false)
	a.omni(Vector3(2.90, Y + 1.55, 9.70), Color(0.86, 0.72, 0.52), 1.15, 4.4, false)
	# 走廊尽头那扇破窗（街灯从这里进来）
	k.window_z(X1, 9.90, Y + 1.05, 0.85, 1.05, m_wood,
		k.plain(Color(0.055, 0.062, 0.080), 0.95), -1.0)
	# 走廊中间一盏坏掉的吸顶灯：只有外壳，没有光（这是“5F 无灯”的证据）
	a.box(Vector3(0.40, Y + HH - 0.03, 7.90), Vector3(0.30, 0.05, 0.30),
		k.plain(Color(0.22, 0.21, 0.20), 0.8))
	a.box(Vector3(0.40, Y + HH - 0.075, 7.90), Vector3(0.26, 0.03, 0.26),
		k.plain(Color(0.30, 0.29, 0.27), 0.9))

	# —— 503 的门缝有光：一条 4 mm 的暖光，从门缝底下透出来
	#     这是 5F 唯一的人工光，也是“下面看到的那道光”。
	var seam_y := Y + 0.012
	a.box(Vector3(1.70, seam_y, CZ0 - 0.004), Vector3(0.86, 0.010, 0.008),
		k.emit(Color(1.0, 0.74, 0.42), 2.6), false)
	lights["seam"] = a.omni(Vector3(1.70, Y + 0.10, CZ0 - 0.10),
		Color(1.0, 0.70, 0.40), 0.55, 2.4, false)
	# 门前的鞋：4 双（童鞋、男鞋），其中一双是湿的
	var shoe := k.plain(Color(0.10, 0.095, 0.09), 0.7)
	var shoe_wet := k.wet("leather", Color(0.14, 0.13, 0.13), 2.0) if false else \
		k.plain(Color(0.075, 0.072, 0.075), 0.18)
	for i in range(4):
		var px: float = 1.28 + 0.22 * float(i % 2)
		var pz: float = CZ0 - 0.26 - 0.30 * float(i / 2)
		a.box(Vector3(px, Y + 0.035, pz), Vector3(0.10, 0.07, 0.24),
			shoe_wet if i == 3 else shoe, false, 0.1 * float(i))
	# 童鞋：明显小一号
	a.box(Vector3(1.92, Y + 0.026, CZ0 - 0.30), Vector3(0.075, 0.052, 0.16), shoe, false, 0.2)

	# 走廊地上的灰：一条被踩出来的路。不能是纯色平面（会像纸），
	# 用“每块地板砖稍微亮一点”的方式做，中间那道实测出来。
	var pathm := k.pbr("old_wooden_floor_01", 0.55, Color(0.54, 0.51, 0.45), 0.98, 0.0, 0.9)
	a.quad_xz(-1.15, CZ0 + 0.30, 0.95, CZ1 - 0.30, Y + 0.004, pathm)

	# 走廊墙根湿痕（楼上的水一路渗下来）
	k.wet_band_x(CZ0 + 0.16, X0, X1, Y, 0.70)
	k.wet_band_x(CZ1 - 0.16, X0, X1, Y, 0.55, -1.0)
	# 天花板上两块渗水的黄渍
	for c in [Vector2(-1.20, 7.60), Vector2(1.60, 9.10)]:
		k.stain(Vector3(c.x, Y + HH - 0.012, c.y), 1.30,
			Color(0.30, 0.26, 0.18, 1.0), 0.62, "blob", 0.4)

	# 502 门口：一封没投出去的信（灰里的一张白）
	a.box(Vector3(-1.55, Y + 0.006, CZ0 - 0.42), Vector3(0.22, 0.004, 0.12),
		k.plain(Color(0.86, 0.84, 0.76), 0.95), false, 0.4)

	# 天窗的光：从天花板斜切下来（在走廊上能看到一道光柱的边缘）
	k.moon_spot(Vector3(-1.70, Y + HH + 1.8, 3.50), Vector3(-1.70, Y, 3.50), 1.6, 28.0)

	# 楼梯口（南墙）：往 4F 下去。洞口 x 0.30…2.80，两侧留墙 + 上方过梁。
	a.box(Vector3(-1.45, Y + HH * 0.5, CZ1 + 0.02), Vector3(3.50, HH, 0.12), m_wall, true)
	a.box(Vector3(3.00, Y + HH * 0.5, CZ1 + 0.02), Vector3(0.40, HH, 0.12), m_wall, true)
	a.box(Vector3(1.55, Y + HH - (HH - 2.10) * 0.5, CZ1 + 0.02),
		Vector3(2.50, HH - 2.10, 0.12), m_wall, false)
	a.box(Vector3(1.35, Y + 2.34, CZ1 + 0.02), Vector3(2.50, 0.26, 0.12), m_wall, false)

# ================================================================ 502 空屋
## 3.0 × 3.9。空的。真的空的。连灰都很少。
## 唯一的东西：地板中央一块被水泡过的痕迹（2×2），形状像一个人躺着。天窗就在正上方。
func _room_502() -> void:
	var x0 := -3.2
	var x1 := -0.2
	var z0 := 1.6
	var z1 := CZ0
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	# 房间地面抬高 1.5 mm：走廊那块的 slab 也在 Y，门口处两块 quad 共面会 z-fighting
	# （渲染成一条锯齿）。抬 1.5 mm 完全看不出来，但深度冲突消失。
	k.slab(x0, z0, x1, z1, Y + 0.0015, m_floor)
	# 天花板：中间开天窗洞（用四块拼出来）
	var sx0: float = skylight_rect["x0"]
	var sz0: float = skylight_rect["z0"]
	var sx1: float = skylight_rect["x1"]
	var sz1: float = skylight_rect["z1"]
	var yc := Y + HH
	a.quad_xz(x0, z0, x1, sz0, yc, m_ceil, false)
	a.quad_xz(x0, sz1, x1, z1, yc, m_ceil, false)
	a.quad_xz(x0, sz0, sx0, sz1, yc, m_ceil, false)
	a.quad_xz(sx1, sz0, x1, sz1, yc, m_ceil, false)
	_skylight(sx0, sz0, sx1, sz1, yc)
	k.wall_z(x0 - 0.06, z0, z1, Y, HH, m_wall)
	# 502和503共用维修通道：双侧隔墙都留出真实门洞。
	k.wall_z(x1 + .06,z0,3.80,Y,HH,m_wall)
	k.wall_z(x1 + .06,4.90,z1,Y,HH,m_wall)
	a.box(Vector3(x1+.06,Y+2.35,4.35),Vector3(.12,.50,1.10),m_wall,false)
	k.wall_x(z0 - 0.06, x0, x1, Y, HH, m_wall)
	a.box(Vector3(-2.75, Y + HH * 0.5, z1 + 0.06), Vector3(0.90, HH, 0.12), m_wall, true)
	a.box(Vector3(-0.65, Y + HH * 0.5, z1 + 0.06), Vector3(0.90, HH, 0.12), m_wall, true)
	a.box(Vector3(-1.70, Y + 2.30, z1 + 0.06), Vector3(0.90, 0.30, 0.12), m_wall, false)
	# 墙根踢脚：必须盖住「墙 box 下沿」与「地板 quad」的共面接缝，
	# 否则墙脚会渲染成一条锯齿（z-fighting，不是阴影问题）。
	k.skirting_x(z0 + 0.015, x0, x1, Y, m_dark, Vector3(0, 0, 0.02), 0.15)
	k.skirting_x(z1 - 0.015, x0, x1, Y, m_dark, Vector3(0, 0, -0.02), 0.15)
	k.skirting_z(x0 + 0.015, z0, z1, Y, m_dark, Vector3(0.02, 0, 0), 0.15)
	k.skirting_z(x1 - 0.015, z0, z1, Y, m_dark, Vector3(-0.02, 0, 0), 0.15)
	# 这一层没有护墙板（没人装修过）

	# —— 地板中央的人形水渍：全案最安静的一处。2 × 2 m，形状像一个人躺着。
	#     三层叠（原来两层、且都是深色，在深木地板上完全看不出来）：
	#       ① 大范围的“泡过水”痕迹：**浅色**水碱边（水干后木头泛白）
	#       ② 人形本体：比地板略深的中性灰，边界锐利
	#       ③ 人形边缘一圈极浅的线（水线，读得出轮廓）
	k.stain(Vector3(cx, Y + 0.003, cz), 2.70,
		Color(0.62, 0.60, 0.54, 1.0), 0.30, "blob", 0.0)
	k.stain(Vector3(cx, Y + 0.005, cz), 2.20,
		Color(0.30, 0.30, 0.28, 1.0), 0.72, "human", 0.0)
	var st := k.stain(Vector3(cx, Y + 0.007, cz), 2.05,
		Color(0.14, 0.15, 0.15, 1.0), 0.80, "human", 0.0)
	st.rotation.y = PI * 0.5      # 头朝北（对着门）

	# —— 这个房间“连灰都很少”：地面干净得反常，只在墙角有一层
	a.quad_xz(x0 + 0.08, z0 + 0.08, x0 + 0.75, z0 + 0.55, Y + 0.003,
		k.plain(Color(0.40, 0.38, 0.35), 0.98))
	a.quad_xz(x1 - 0.75, z1 - 0.55, x1 - 0.08, z1 - 0.08, Y + 0.003,
		k.plain(Color(0.40, 0.38, 0.35), 0.98))

	# —— 空屋唯一留下的东西：窗台上一个玻璃杯（干了），和墙上一枚钉子
	a.cyl(Vector3(x1 - 0.22, Y + 1.02, cz + 0.40), 0.035, 0.10,
		k.glass(Color(0.70, 0.74, 0.76, 0.22)), 12)
	a.box(Vector3(x1 - 0.22, Y + 1.00, cz + 0.40), Vector3(0.12, 0.02, 0.12), m_wood)
	a.cyl(Vector3(x0 + 0.10, Y + 1.58, cz - 0.60), 0.006, 0.06, m_metal, 6, "x")

	# —— 窗（西墙）：外面是夜，玻璃上有一层灰
	k.window_z(x0, cz - 0.30, Y + 0.95, 1.00, 1.20, m_wood,
		k.plain(Color(0.052, 0.056, 0.066), 0.9), 1.0)
	# 窗下的暖气片：早就凉了
	# Blender 版散热器（radiator_01，7812 面）：12 节翼片 + 集管 + 端盖 + 托架 + 放气阀
	k.model("props/radiator_01", Vector3(x0 + 0.09, Y + 0.10, cz - 0.30), -PI * 0.5)

	# 灯：无灯 —— 只有天窗月光 6500 K。
	# 月光要真的把地面照亮，否则那道“人形”根本读不出来（这是这一层的戏眼）。
	# 主照明用 omni（阴影柔和），spot 只做“光柱感”且不投硬影 ——
	# 原来 spot 强度 6.5 + 投影，把窗框在地面打成锯齿状的黑十字，很脏。
	# 主照明：**不投影**。这间只有 2.6 m 高、灯光掠射角极斜，
	# 开阴影会在墙脚拖出锯齿状的黑边（shadow map 分辨率不够）。
	# 用两盏不投影的 omni 叠加做出柔和的天窗光，反而更干净。
	a.omni(Vector3(cx, Y + 1.75, cz), Color(0.70, 0.80, 1.0), 1.55, 6.4, false)
	a.omni(Vector3(cx, Y + 2.30, cz - 0.55), Color(0.62, 0.72, 0.96), 0.85, 5.0, false)
	lights["skylight"] = a.omni(Vector3(cx, Y + 0.95, cz + 0.30), Color(0.66, 0.76, 0.98),
		0.70, 4.2, false)
	# 这一盏**不投影**：天窗框在地面会投出锯齿状的黑十字，脏得厉害。
	# 光柱感靠强度和小角度做，阴影交给上面那盏 omni（它的边缘是软的）。
	# 光源不能正对下方（方向会与 UP 共线，Godot 会报警并产生怪旋转）。
	# 稍微侧移 0.6 m，模拟"月光斜着从天窗切进来"，反而更像光柱。
	var moon := a.spot(Vector3((sx0 + sx1) * 0.5 + 0.60, yc + 2.4, (sz0 + sz1) * 0.5 + 0.45),
		Vector3(cx, Y, cz), Color(0.72, 0.82, 1.0), 1.30, 18.0, 34.0, false)
	# 天窗井内壁把光兜下来（井壁是白的）
	a.omni(Vector3((sx0 + sx1) * 0.5, yc - 0.35, (sz0 + sz1) * 0.5),
		Color(0.70, 0.82, 1.0), 1.60, 3.4, false)
	# 门口方向一盏极弱的廊光（有它，门的轮廓才立得住）
	a.omni(Vector3(-1.70, Y + 1.90, CZ0 + 0.60), Color(0.62, 0.66, 0.74), 0.55, 3.6, false)

# ---------------------------------------------------------------- 天窗
## 1.2 × 1.2，正对 502 的水渍。钢框 + 玻璃 + 一层雨渍。天窗外面是屋顶。
func _skylight(x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	var w := x1 - x0
	var d := z1 - z0
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var fm := k.pbr("metal_plate", 1.6, Color(0.34, 0.34, 0.33), 0.6, 0.55)
	# 框
	a.box(Vector3(cx, y + 0.02, z0 - 0.02), Vector3(w + 0.10, 0.07, 0.055), fm)
	a.box(Vector3(cx, y + 0.02, z1 + 0.02), Vector3(w + 0.10, 0.07, 0.055), fm)
	a.box(Vector3(x0 - 0.02, y + 0.02, cz), Vector3(0.055, 0.07, d + 0.10), fm)
	a.box(Vector3(x1 + 0.02, y + 0.02, cz), Vector3(0.055, 0.07, d + 0.10), fm)
	# 中挺
	a.box(Vector3(cx, y + 0.02, cz), Vector3(w, 0.05, 0.04), fm)
	a.box(Vector3(cx, y + 0.02, cz), Vector3(0.04, 0.05, d), fm)
	# 玻璃：夜天色 + 一点反光
	var gm := k.glass(Color(0.16, 0.22, 0.32, 0.30))
	a.box(Vector3(cx, y + 0.012, cz), Vector3(w, 0.012, d), gm)
	# 玻璃上的雨渍（三角形的小脏斑）
	for i in range(5):
		var px: float = lerpf(x0 + 0.15, x1 - 0.15, fmod(float(i) * 0.37, 1.0))
		var pz: float = lerpf(z0 + 0.15, z1 - 0.15, fmod(float(i) * 0.61, 1.0))
		a.box(Vector3(px, y - 0.002, pz), Vector3(0.06 + 0.02 * float(i % 3), 0.002, 0.05),
			k.plain(Color(0.24, 0.26, 0.24), 0.35), false, 0.5 * float(i))
	# 天窗井：四壁把楼板厚度读出来（0.3 m 高，往上）
	var well := k.pbr("rough_concrete", 0.5, Color(0.52, 0.50, 0.47), 1.0)
	a.box(Vector3(cx, y + 0.16, z0 - 0.05), Vector3(w + 0.12, 0.30, 0.10), well, false)
	a.box(Vector3(cx, y + 0.16, z1 + 0.05), Vector3(w + 0.12, 0.30, 0.10), well, false)
	a.box(Vector3(x0 - 0.05, y + 0.16, cz), Vector3(0.10, 0.30, d + 0.12), well, false)
	a.box(Vector3(x1 + 0.05, y + 0.16, cz), Vector3(0.10, 0.30, d + 0.12), well, false)

# ================================================================ 503 门缝有光
## 3.0 × 3.9。门从里面反锁。第一夜：门缝有光。第二夜：黑的。
## 打开后：地板上摆着 7 台小洗衣机模型——是玩具。最里面一张单人床，床上有一个人形的凹陷，是湿的。
func _room_503() -> void:
	var x0 := 0.2
	var x1 := X1
	var z0 := 1.6
	var z1 := CZ0
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	k.slab(x0, z0, x1, z1, Y + 0.0015, m_floor)
	k.slab_solid(x0, z0, x1, z1, Y + HH + 0.30, m_ceil, m_ceil)
	k.wall_z(x0-.06,z0,3.80,Y,HH,m_wall)
	k.wall_z(x0-.06,4.90,z1,Y,HH,m_wall)
	a.box(Vector3(x0-.06,Y+2.35,4.35),Vector3(.12,.50,1.10),m_wall,false)
	k.slab(-.22,3.80,.22,4.90,Y+.0015,m_floor)
	k.wall_z(x1 + 0.06, z0, z1, Y, HH, m_wall)
	k.wall_x(z0 - 0.06, x0, x1, Y, HH, m_wall)
	a.box(Vector3(0.75, Y + HH * 0.5, z1 + 0.06), Vector3(1.10, HH, 0.12), m_wall, true)
	a.box(Vector3(2.65, Y + HH * 0.5, z1 + 0.06), Vector3(1.10, HH, 0.12), m_wall, true)
	a.box(Vector3(1.70, Y + 2.30, z1 + 0.06), Vector3(0.90, 0.30, 0.12), m_wall, false)
	k.skirting_x(z1 - 0.015, x0, x1, Y, m_dark, Vector3(0, 0, -0.02))
	k.skirting_z(x0 + 0.015, z0, z1, Y, m_dark, Vector3(0.02, 0, 0))

	# —— 门：从里面反锁。门上有 3 条插销 + 一条门链（里面的人不敢开）
	doors["503"] = k.door_leaf(Vector3(1.25, Y, CZ0 - 0.03), 0.90, 2.02, 0.0,
		k.pbr("old_linoleum_flooring_01", 1.8, Color(0.26, 0.20, 0.15), 0.72))
	var bolt := k.plain(Color(0.40, 0.38, 0.33), 0.42, 0.85)
	for i in range(3):
		a.box(Vector3(1.98, Y + 0.85 + 0.34 * float(i), CZ0 - 0.10),
			Vector3(0.16, 0.035, 0.02), bolt)
	for i in range(3):
		a.box(Vector3(1.62, Y + 0.85 + 0.34 * float(i), CZ0 - 0.10),
			Vector3(0.06, 0.06, 0.03), bolt)
	# 门链 + 挂锁（从里面挂上）
	k.pipe(Vector3(1.42, Y + 1.52, CZ0 - 0.10), Vector3(1.72, Y + 1.44, CZ0 - 0.10),
		0.008, bolt, 6)

	# —— 7 台玩具洗衣机：地板上摆成一个圈（对着门，全部朝门）
	#     这是全案最狠的一处“童趣的恐怖”——6 岁孩子摆的。
	#     做法照 2F 的真机器缩到 1/5：机身壳 + 真正的一圈圆门 + 深色玻璃 + 控制面板，
	#     这样一眼就认得出“这是洗衣机”。
	var toy := k.plain(Color(0.82, 0.82, 0.80), 0.38, 0.10)
	var toy_side := k.plain(Color(0.70, 0.71, 0.70), 0.42, 0.10)
	var toy_glass := k.plain(Color(0.12, 0.14, 0.16), 0.22, 0.30)
	var toy_ring := k.plain(Color(0.90, 0.91, 0.90), 0.28, 0.35)
	var toy_panel := k.plain(Color(0.16, 0.17, 0.18), 0.55, 0.20)
	for i in range(7):
		var ang := TAU * float(i) / 7.0 - PI * 0.5
		var rr := 0.58 if i % 2 == 0 else 0.74
		var tp := Vector3(cx + cos(ang) * rr, Y, cz + sin(ang) * rr * 0.9)
		a.push_group(tp, -ang + PI, true)
		# 尺寸全是**全尺寸**（a.box / a.bev 的 size 都是 BoxMesh.size 语义）
		var W := 0.26
		var H := 0.30
		var D := 0.24
		var hw := W * 0.5
		var hd := D * 0.5
		# 机身：bev 的 pos 是中心点，所以 y = H/2
		a.bev(Vector3(0, H * 0.5 + 0.002, 0), Vector3(W, H, D), toy, 0.010)
		# 正面圆门（朝 +Z）：外圈亮环 + 深色玻璃 + 中心暗点
		var door_y := H * 0.44
		var face_z := hd
		a.cyl(Vector3(0, door_y, face_z), 0.078, 0.010, toy_ring, 20, "z")
		a.cyl(Vector3(0, door_y, face_z + 0.007), 0.060, 0.008, toy_glass, 20, "z")
		a.cyl(Vector3(0, door_y, face_z + 0.012), 0.024, 0.005,
			k.plain(Color(0.42, 0.44, 0.46), 0.20, 0.6), 14, "z")
		# 顶部控制面板（平放在机顶后沿）+ 两颗旋钮
		var panel_y := H + 0.004
		var panel_z := -hd * 0.42
		a.box(Vector3(0, panel_y, panel_z),
			Vector3(W * 0.80, 0.012, 0.085), toy_panel)
		for kx in [-0.050, 0.016]:
			a.cyl(Vector3(kx, panel_y + 0.012, panel_z), 0.014, 0.012,
				k.plain(Color(0.86, 0.84, 0.78), 0.35, 0.3), 12, "y")
		# 四角支脚：抬 1.2 cm
		for sx2 in [-hw * 0.72, hw * 0.72]:
			for sz2 in [-hd * 0.70, hd * 0.70]:
				a.cyl(Vector3(sx2, 0.006, sz2), 0.010, 0.012, toy_panel, 6, "y")
		a.pop_group()
		toy_washers.append(tp)
	# 圈中间：一台小的 8 号（编号用红笔画在地上）
	# 地上用红蜡笔画的圈 + 一个“8”。原来是实心红圆盘，看着像一滩血 —— 改成空心圈。
	var crayon := k.plain(Color(0.58, 0.14, 0.11), 0.85)
	for seg in range(16):
		var a0: float = TAU * float(seg) / 16.0
		var mm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.030, 0.002, 0.075)
		mm.mesh = bm
		mm.material_override = crayon
		mm.position = Vector3(cx + cos(a0) * 0.19, Y + 0.004, cz + sin(a0) * 0.19)
		mm.rotation.y = -a0 + PI * 0.5
		a.root.add_child(mm)
	a.label("8", Vector3(cx, Y + 0.012, cz + 0.20), 0.085,
		Color(0.58, 0.13, 0.10), 0.3, 36)
	# 床脚底下：拖鞋一正一反（孩子睡前摆的）

	# —— 最里面的单人床：床上有一个人形的凹陷，是湿的。
	#     原来床架是深棕色大盒子（old_linoleum），暗光下整个读作一只木箱。
	#     改成：细铁床架 + 浅色床垫 + 白床单（层次分明，一眼是床）。
	var bed := Vector3(cx + 0.30, Y, z0 + 0.85)
	var bed_iron := a.pbr("metal_plate", 1.5, Color(0.42, 0.42, 0.43), 0.55, 0.6)
	# 四条腿（全尺寸 0.05×0.34×0.05，中心在 y=0.17）
	for bx in [-0.42, 0.42]:
		for bz in [-0.84, 0.84]:
			a.box(bed + Vector3(bx, 0.17, bz), Vector3(0.05, 0.34, 0.05), bed_iron, true)
	# 床架边框
	for bz2 in [-0.84, 0.84]:
		a.box(bed + Vector3(0, 0.345, bz2), Vector3(0.90, 0.05, 0.05), bed_iron)
	for bx2 in [-0.42, 0.42]:
		a.box(bed + Vector3(bx2, 0.345, 0), Vector3(0.05, 0.05, 1.72), bed_iron)
	# 床板
	a.box(bed + Vector3(0, 0.372, 0), Vector3(0.86, 0.014, 1.70),
		k.pbr("wood_planks_dirt", 1.2, Color(0.40, 0.33, 0.26), 0.9))
	# 床垫（浅亚麻）
	var mattress_dry := k.cloth("rough_linen", Color(0.70, 0.68, 0.62), 2.0)
	a.box(bed + Vector3(0, 0.42, 0), Vector3(0.84, 0.08, 1.68), mattress_dry)
	# 白床单：铺开 + 一侧垂下
	a.box(bed + Vector3(0, 0.465, 0), Vector3(0.86, 0.012, 1.70),
		k.cloth("rough_linen", Color(0.80, 0.79, 0.74), 2.4))
	a.box(bed + Vector3(0.435, 0.43, 0), Vector3(0.014, 0.13, 1.70),
		k.cloth("rough_linen", Color(0.78, 0.77, 0.72), 2.4))
	# 湿的那一块（人形区域）：暗一档、低粗糙度，但不是镜面
	a.box(bed + Vector3(0, 0.473, 0.02), Vector3(0.56, 0.006, 1.20),
		k.pbr("rough_linen", 2.2, Color(0.40, 0.41, 0.40), 0.34, 0.02, 0.5))
	# 人形凹陷：比床垫再深一点的一块，也湿
	var dent := k.stain(bed + Vector3(0, 0.479, 0.05), 1.55,
		Color(0.10, 0.115, 0.115, 1.0), 0.85, "human", 0.0)
	dent.rotation.y = 0.0
	# 湿痕继续渗到地板上
	k.stain(bed + Vector3(0.10, 0.005, 0.60), 0.90, Color(0.18, 0.20, 0.19, 1.0), 0.42, "blob")

	# —— 玩具洗衣机们围着的“洗衣机声”：一台真的小机器在转
	#     剧本里“里面传出来的声音：洗衣机的声音”。这里放一台老式双缸机。
	var real := Vector3(x1 - 0.55, Y, z0 + 0.55)
	a.bev(real + Vector3(0, 0.34, 0), Vector3(0.62, 0.68, 0.60),
		k.plain(Color(0.76, 0.74, 0.68), 0.42, 0.05), 0.012, true)
	a.box(real + Vector3(0, 0.72, 0), Vector3(0.64, 0.06, 0.62),
		k.plain(Color(0.60, 0.58, 0.54), 0.4, 0.2))
	a.cyl(real + Vector3(0, 0.14, 0.31), 0.14, 0.02,
		k.plain(Color(0.30, 0.32, 0.34), 0.5), 18, "z")
	a.cyl(real + Vector3(0.36, 0.14, 0.31), 0.13, 0.02,
		k.plain(Color(0.30, 0.32, 0.34), 0.5), 18, "z")
	a.omni(real + Vector3(0, 0.55, 0.40), Color(0.70, 0.80, 0.90), 0.30, 1.8, false)

	# —— 唯一的窗：门缝的光就是从这间漏出去的
	k.window_z(x1, cz + 0.55, Y + 0.95, 0.95, 1.15, m_wood,
		k.plain(Color(0.020, 0.026, 0.038), 0.95), -1.0)
	# 窗帘（洗过、还没干）
	k.drape(Vector3(x1 - 0.16, Y + 2.16, cz + 0.55), 1.30, 1.16,
		k.cloth("rough_linen", Color(0.12, 0.14, 0.16), 2.0), 1.7, "z", 6.0, 0.03)

	# 灯：门缝那盏黄灯（第二夜会灭）——房间本身没有灯，就是这一盏
	k.bulb_lamp(Vector3(cx, Y + HH - 0.02, cz - 0.30), 0.50, 1.15, 4.6,
		Color(1.0, 0.74, 0.42), true)

# ================================================================ 楼梯口
func _stair() -> void:
	# 往 4F 下去：楼梯在 stairs_upper 建，这里只留洞口的过梁（走廊已做）
	pass
