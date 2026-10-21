extends RefCounted
## 区域 1 ｜ 1F · 门厅与信箱墙
## 剧本标注 6.0 × 20.0 × 3.2，但物件坐标落在 z = −10 … +16（26 m）。
## 这里按物件坐标建模（更具体的那一组），门厅实际长 26 m —— 已在交付说明里记一笔。
##
## 北 = −Z（后门 / 后巷）；南 = +Z（楼梯间）。西墙 x = −3.2（信箱墙），东墙 x = +3.2。

const A := preload("res://scripts/laundry/laundry_art.gd")

const X0 := -3.2
const X1 := 3.2
const Z0 := -10.0
const Z1 := 16.0
const H := 3.2

var a: LaundryArt
var m_floor: StandardMaterial3D
var m_path: StandardMaterial3D
var m_wall: StandardMaterial3D
var m_ceil: StandardMaterial3D
var m_rust: StandardMaterial3D
var m_steel: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_paper: StandardMaterial3D
var m_wood: StandardMaterial3D
var m_tv: StandardMaterial3D

func _init(art) -> void:
	a = art

func build() -> void:
	_materials()
	_shell()
	_skirting()
	_mailbox_wall()
	_booth()
	_elevator()
	_notice_board()
	_lamps()
	_back_door()
	_stairs()

# ------------------------------------------------------------------ 材质
func _materials() -> void:
	# uv_scale = 每米重复几次：Poly Haven 的贴图约 2.5–3 m 一铺，所以 ~0.35。
	m_floor = a.pbr("terrazzo_tiles", 0.42, Color(0.94, 0.92, 0.88), 1.0)
	m_path = a.pbr("terrazzo_tiles", 0.55, Color(1.0, 0.99, 0.97), 0.62)
	m_wall = a.pbr("grey_plaster_02", 0.30, Color(0.80, 0.79, 0.76), 1.0, 0.0, 0.55)
	m_ceil = a.pbr("grey_plaster_02", 0.36, Color(0.66, 0.66, 0.64), 1.0)
	m_rust = a.pbr("rusty_metal", 0.85, Color(0.86, 0.80, 0.74), 1.0, 0.15)
	m_steel = a.pbr("metal_plate", 1.1, Color(0.78, 0.79, 0.80), 0.9, 0.65)
	m_dark = a.plain(Color(0.045, 0.045, 0.05), 0.92)
	m_paper = a.plain(Color(0.88, 0.85, 0.74), 0.95)
	m_wood = a.pbr("old_linoleum_flooring_01", 1.0, Color(0.62, 0.55, 0.48), 1.0)
	m_tv = a.emit(Color(0.72, 0.80, 0.86), 1.6)

# ------------------------------------------------------------------ 壳体
func _shell() -> void:
	var w := X1 - X0
	var d := Z1 - Z0
	var cz := (Z0 + Z1) * 0.5
	# 地面 + 被踩亮的一条
	# 注意：东北角有一块 1F→B1 的铁盖洞口（x 2.20…3.10, z −8.60…−6.20，
	# 见 stairs_upper.gd 的 _basement_stair），地板必须挖开，否则洞口被埋在地板底下。
	var bhx0 := 2.20
	var bhx1 := 3.10
	var bhz0 := -8.60
	var bhz1 := -6.20
	# 地板切成四块，绕开洞口
	a.quad_xz(X0, Z0, X1, bhz0, 0.0, m_floor)                 # 洞口以北
	a.quad_xz(X0, bhz1, X1, Z1, 0.0, m_floor)                 # 洞口以南
	a.quad_xz(X0, bhz0, bhx0, bhz1, 0.0, m_floor)             # 洞口以西
	a.quad_xz(bhx1, bhz0, X1, bhz1, 0.0, m_floor)             # 洞口以东
	a.quad_xz(-0.95, Z0, 0.75, Z1, 0.006, m_path)
	# 碰撞同样要挖开（否则玩家会被一层空气地板托在洞口上）
	a.col(Vector3(0, -0.15, (Z0 + bhz0) * 0.5), Vector3(w, 0.3, bhz0 - Z0))
	a.col(Vector3(0, -0.15, (bhz1 + Z1) * 0.5), Vector3(w, 0.3, Z1 - bhz1))
	a.col(Vector3((X0 + bhx0) * 0.5, -0.15, (bhz0 + bhz1) * 0.5),
		Vector3(bhx0 - X0, 0.3, bhz1 - bhz0))
	a.col(Vector3((bhx1 + X1) * 0.5, -0.15, (bhz0 + bhz1) * 0.5),
		Vector3(X1 - bhx1, 0.3, bhz1 - bhz0))
	# 洞口收边：楼板断面 + 一圈角钢（否则能看到地板是“纸片”）
	var lip := a.plain(Color(0.20, 0.19, 0.18), 0.7, 0.4)
	a.box(Vector3((bhx0 + bhx1) * 0.5, -0.15, bhz0), Vector3(bhx1 - bhx0 + 0.10, 0.30, 0.06), lip, false)
	a.box(Vector3((bhx0 + bhx1) * 0.5, -0.15, bhz1), Vector3(bhx1 - bhx0 + 0.10, 0.30, 0.06), lip, false)
	a.box(Vector3(bhx0, -0.15, (bhz0 + bhz1) * 0.5), Vector3(0.06, 0.30, bhz1 - bhz0), lip, false)
	a.box(Vector3(bhx1, -0.15, (bhz0 + bhz1) * 0.5), Vector3(0.06, 0.30, bhz1 - bhz0), lip, false)
	# 洞口四角的地脚螺栓 + 掀开的铁盖（铁盖本体在 stairs_upper 里）
	for pz2 in [bhz0, bhz1]:
		for px2 in [bhx0, bhx1]:
			a.cyl(Vector3(px2, 0.02, pz2), 0.022, 0.05, lip, 8)
	# 天花
	# 楼梯井上方不能再盖一整片天花，否则上楼时视野会穿楼板。
	a.quad_xz(X0, Z0, X1, 11.0, H, m_ceil, false)
	a.quad_xz(X0, 11.0, .30, Z1, H, m_ceil, false)
	a.quad_xz(2.80, 11.0, X1, Z1, H, m_ceil, false)
	# 四壁
	a.box(Vector3(X0 - 0.1, H * 0.5, cz), Vector3(0.2, H, d), m_wall, true)
	a.box(Vector3(X1 + 0.1, H * 0.5, cz), Vector3(0.2, H, d), m_wall, true)
	a.box(Vector3(0, H * 0.5, Z0 - 0.1), Vector3(w, H, 0.2), m_wall, true)
	# 南墙：中间留 2.5 m 宽的楼梯洞口（x 0.3 … 2.8）
	a.box(Vector3(-1.45, H * 0.5, Z1 + 0.1), Vector3(3.50, H, 0.2), m_wall, true)
	a.box(Vector3(3.00, H * 0.5, Z1 + 0.1), Vector3(0.40, H, 0.2), m_wall, true)
	a.box(Vector3(1.55, 2.80, Z1 + 0.1), Vector3(2.50, 0.80, 0.20), m_wall, false)

func _skirting() -> void:
	# 踢脚线：深色 12 cm，旧楼都有，缺了会显假
	var c := Color(0.10, 0.10, 0.10)
	var m := a.plain(c, 0.85)
	var d := Z1 - Z0
	var cz := (Z0 + Z1) * 0.5
	a.box(Vector3(X0 + 0.01, 0.06, cz), Vector3(0.02, 0.12, d), m, false)
	a.box(Vector3(X1 - 0.01, 0.06, cz), Vector3(0.02, 0.12, d), m, false)
	a.box(Vector3(0, 0.06, Z0 + 0.01), Vector3(X1 - X0, 0.12, 0.02), m, false)
	a.box(Vector3(0, 0.06, Z1 - 0.01), Vector3(X1 - X0, 0.12, 0.02), m, false)

# ------------------------------------------------------------------ 信箱墙
## 3.2 × 1.8 × 0.35，西墙 x=−3.0 附近，z = +4.0 为中心；120 格，锈 87 格，27 格塞着信。
func _mailbox_wall() -> void:
	# Blender 版 120 格信箱墙（mailbox_wall_01，9920 面）：
	# 10 列 × 12 行，锈 87 格、27 格插着没取的信、503 统一块新铁皮 + 铜色新锁。
	# 模型：宽 3.2（沿 X）· 高 1.8 · 深 0.18，正面朝 −Z（Godot）。
	#
	# 摆放：贴西墙 X0（−3.2），门朝 +X（房间内）→ 绕 Y 转 +90°。
	# 剧情坐标 (z = +4.0 为中心, y = 0.6 起)。
	var zc := 4.0
	var y0 := 0.6
	var mws = load("res://assets/models/props/mailbox_wall_01/mailbox_wall_01.glb")
	if mws != null:
		var mb: Node3D = mws.instantiate()
		mb.set_meta("dynamic", true)
		mb.position = Vector3(X0 + 0.02, y0, zc)
		# 模型正面朝 -Z。绕 Y 转 +90° 时 -Z 轴指向 -X（朝墙），转 -90° 时指向 +X。
		# 但试下来 -90° 看到的是背板 —— 说明 glTF 导入后正面实际在 +Z 侧。
		# 所以用 +90°（+Z → +X），并把 503 数字反向贴，避免镜像字。
		mb.rotation.y = PI * 0.5
		a.root.add_child(mb)
		# 碰撞：整面墙一块箱子（玩家不该穿过去）
		a.col(Vector3(X0 + 0.09, y0 + 0.9, zc), Vector3(0.18, 1.8, 3.2))
	else:
		# 兜底：加载失败时给一块铁皮面板，至少不空
		a.box(Vector3(X0 + 0.17, y0 + 0.9, zc), Vector3(0.35, 1.8, 3.2), m_rust, true)

	# 503 的门牌（模型里已有新锁和铜牌，这里只补一个能在远处看清的数字）
	a.label("503", Vector3(X0 + 0.20, y0 + 1.26, 4.62), 0.045,
		Color(0.92, 0.90, 0.84), PI * 0.5)

# ------------------------------------------------------------------ 传达室
## 2.4 × 2.2 × 2.6，(−1.9, 0, +9.0)。玻璃窗有裂纹，里面一台老电视在放雪花。
func _booth() -> void:
	var cx := -1.9
	var cz := 9.0
	var w := 2.4
	var d := 2.2
	var h := 2.6
	var x0 := cx - w * 0.5
	var x1 := cx + w * 0.5
	var z0 := cz - d * 0.5
	var z1 := cz + d * 0.5

	# 底座 + 四角立柱 + 顶板
	a.box(Vector3(cx, 0.06, cz), Vector3(w, 0.12, d), a.plain(Color(0.16, 0.15, 0.14), 0.8), true)
	for px2 in [x0 + 0.05, x1 - 0.05]:
		for pz2 in [z0 + 0.05, z1 - 0.05]:
			a.box(Vector3(px2, h * 0.5, pz2), Vector3(0.10, h, 0.10), m_steel)
	a.box(Vector3(cx, h - 0.04, cz), Vector3(w + 0.10, 0.08, d + 0.10), m_steel)
	# —— 下半截实墙（腰墙 1.05 m）+ 窗台板。
	#    原来的传达室只有 4 根柱子 + 玻璃，从外面看就是个悬空的空框；
	#    真实的传达室是「腰墙 + 上玻璃」，补上之后才有体积。
	var booth_wall := a.pbr("painted_plaster_wall", 0.5, Color(0.62, 0.60, 0.54), 0.9, 0.0, 0.5)
	var hw_wall := 0.11
	a.box(Vector3(cx, hw_wall * 0.5 + 0.12, z0 + 0.05), Vector3(w - 0.02, hw_wall, 0.10), booth_wall, true)
	a.box(Vector3(cx, hw_wall * 0.5 + 0.12, z1 - 0.05), Vector3(w - 0.02, hw_wall, 0.10), booth_wall, true)
	a.box(Vector3(x0 + 0.05, hw_wall * 0.5 + 0.12, cz), Vector3(0.10, hw_wall, d - 0.02), booth_wall, true)
	# 窗台板（腰墙上沿那道木线）
	var sill := a.pbr("old_linoleum_flooring_01", 1.2, Color(0.40, 0.31, 0.22), 0.8)
	a.box(Vector3(cx, 0.70, z0 + 0.03), Vector3(w - 0.02, 0.06, 0.16), sill, false)
	a.box(Vector3(cx, 0.70, z1 - 0.03), Vector3(w - 0.02, 0.06, 0.16), sill, false)
	a.box(Vector3(x0 + 0.03, 0.70, cz), Vector3(0.16, 0.06, d - 0.02), sill, false)
	# 窗台到顶之间的横档（把玻璃分成两段，读作老式售票窗）
	for zz2 in [z0 + 0.05, z1 - 0.05]:
		a.box(Vector3(cx, 1.75, zz2), Vector3(w - 0.12, 0.05, 0.06), m_steel, false)
	a.box(Vector3(x0 + 0.05, 1.75, cz), Vector3(0.06, 0.05, d - 0.12), m_steel, false)
	# 玻璃三面（东面留门）
	var g := a.glass(Color(0.52, 0.60, 0.60, 0.30))
	a.box(Vector3(x0 + 0.05, 1.62, cz), Vector3(0.03, 1.72, d - 0.16), g)
	a.box(Vector3(cx, 1.62, z0 + 0.05), Vector3(w - 0.16, 1.72, 0.03), g)
	a.box(Vector3(cx, 1.62, z1 - 0.05), Vector3(w - 0.16, 1.72, 0.03), g)
	# 玻璃上的裂纹
	var crack := a.plain(Color(0.78, 0.80, 0.80), 0.3)
	a.box(Vector3(x0 + 0.07, 1.62, cz - 0.35), Vector3(0.004, 0.30, 0.012), crack, false, 0.42)
	a.box(Vector3(x0 + 0.07, 1.48, cz + 0.10), Vector3(0.004, 0.22, 0.010), crack, false, -0.62)
	# 室内：工作台 + 登记簿 + 老电视（全部 Blender 版）
	#   booth_desk_01（776 面）：木台面 + 铁腿 + 摊开的登记簿 + 台灯 + 搪瓷杯
	#   crt_tv_01（1600 面）：鼓面 CRT + 旋钮 + 天线，屏幕上永远在下雪
	# 工作台：桌面纹理要细（原来 wood_planks_dirt 的 UV 尺度太大，木纹像泡沫板）
	var desk_pos := Vector3(cx - 0.25, 0.0, cz - 0.35)
	var desk_scene = load("res://assets/models/props/booth_desk_01/booth_desk_01.glb")
	if desk_scene != null:
		var booth_node: Node3D = desk_scene.instantiate()
		booth_node.set_meta("dynamic", true)
		booth_node.position = desk_pos
		booth_node.rotation.y = 0.12
		a.root.add_child(booth_node)
		# 桌面木纹：GLB 自带的是打包木纹，这里换成工程里的旧地板贴图（更细、更像老桌子）
		var desk_wood := a.pbr("old_wooden_floor_01", 2.2, Color(0.42, 0.33, 0.24), 0.85, 0.0, 0.7)
		for c in booth_node.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = c
			if mi.mesh == null:
				continue
			for si in range(mi.mesh.get_surface_count()):
				var bm2: Material = mi.get_active_material(si)
				if bm2 is BaseMaterial3D:
					var bb: BaseMaterial3D = bm2
					# 只替换木色的那几个面（其它保留：金属、纸、陶瓷）
					if bb.albedo_color.r > 0.30 and bb.albedo_color.r < 0.50 						and bb.albedo_color.g < 0.35 and bb.metallic < 0.3:
						mi.set_surface_override_material(si, desk_wood)
	# 电视：放在右侧的小柜子顶上（柜子顶面 0.72）
	var tv_scene = load("res://assets/models/props/crt_tv_01/crt_tv_01.glb")
	var cab_x: float = cx + 0.55
	var cab_z: float = cz - 0.30
	if tv_scene != null:
		var t2: Node3D = tv_scene.instantiate()
		t2.set_meta("dynamic", true)
		t2.position = Vector3(cab_x, 0.72, cab_z)
		t2.rotation.y = -0.30
		a.root.add_child(t2)
	# 电视柜（小方柜，顶面 0.72）
	a.box(Vector3(cab_x, 0.36, cab_z), Vector3(0.56, 0.72, 0.50), m_wood, true)
	a.box(Vector3(cab_x, 0.735, cab_z), Vector3(0.60, 0.03, 0.54),
		a.plain(Color(0.28, 0.22, 0.16), 0.8), false)
	# 柜门
	a.box(Vector3(cab_x - 0.282, 0.36, cab_z), Vector3(0.012, 0.62, 0.42),
		a.plain(Color(0.32, 0.25, 0.18), 0.85), false)
	a.cyl(Vector3(cab_x - 0.292, 0.36, cab_z + 0.14), 0.012, 0.03,
		m_steel, 8, "x")

	# 电视的蓝光（每层一盏"错的光"）：从屏幕前方打出，照在北墙上
	a.omni(Vector3(cab_x, 0.95, cab_z - 0.36), Color(0.42, 0.62, 1.0), 0.95, 3.2, false)

# ------------------------------------------------------------------ 废电梯
## 东墙 z = −6.0，2.0 × 2.0。门半开，里面堆杂物，深处一道小孩手印。
func _elevator() -> void:
	var zc := -6.0
	var z0 := zc - 1.0
	var z1 := zc + 1.0
	var h := 2.2
	var shaft := 1.7
	# 洞口：把东墙挖出这一段（东墙是整块，这里补一个"洞框"）
	var frame := a.plain(Color(0.24, 0.24, 0.25), 0.55, 0.7)
	a.box(Vector3(X1 - 0.02, h + 0.06, zc), Vector3(0.10, 0.12, 2.16), frame)
	for pz in [z0 - 0.06, z1 + 0.06]:
		a.box(Vector3(X1 - 0.02, h * 0.5, pz), Vector3(0.10, h, 0.12), frame)
	# 轿厢井道（往 +X 里挖）
	a.box(Vector3(X1 - shaft * 0.5, h * 0.5, zc), Vector3(shaft, h, 2.02),
		a.plain(Color(0.06, 0.06, 0.07), 0.95), false)
	a.col(Vector3(X1 - shaft * 0.6, h * 0.5, zc), Vector3(shaft * 0.5, h, 2.02))
	# 两扇门半开
	var door := a.pbr("metal_plate", 1.4, Color(0.55, 0.56, 0.56), 1.0, 0.55)
	a.box(Vector3(X1 - 0.03, h * 0.5, z0 + 0.55), Vector3(0.05, h, 1.10), door)
	a.box(Vector3(X1 - 0.03, h * 0.5, z1 - 0.55), Vector3(0.05, h, 1.10), door)
	# 杂物
	a.box(Vector3(X1 - 0.75, 0.35, zc - 0.35), Vector3(0.55, 0.70, 0.60),
		a.pbr("brick_4", 1.0, Color(0.55, 0.50, 0.45), 1.0), true)
	a.box(Vector3(X1 - 1.15, 0.22, zc + 0.45), Vector3(0.40, 0.44, 0.50), m_wood, true, 0.3)
	# 深处墙上的小孩手印：一块比墙亮一点的小面
	var hand := a.plain(Color(0.30, 0.29, 0.27), 0.9)
	a.box(Vector3(X1 - 0.30, 1.02, zc + 0.10), Vector3(0.012, 0.10, 0.07), hand, false)
	# 贴着缝听见水声的位置：一滴暗光
	a.omni(Vector3(X1 - 0.5, 0.9, zc), Color(0.30, 0.42, 0.55), 0.35, 2.2, false)

# ------------------------------------------------------------------ 公告栏
## 西墙 z = +12.0，1.8 × 1.2。三张纸三个年代。
func _notice_board() -> void:
	var zc := 12.0
	var y := 1.75
	var w := 1.80
	var h := 1.20
	var x := X0 + 0.035
	# 木框 + 软木面
	a.box(Vector3(x, y, zc), Vector3(0.05, h, w), a.plain(Color(0.20, 0.14, 0.09), 0.85))
	a.box(Vector3(x + 0.028, y, zc), Vector3(0.008, h - 0.10, w - 0.10),
		a.plain(Color(0.38, 0.29, 0.20), 0.95))
	# 三张纸：2003 停水 / 2011 拆迁 / 2024 禁止入内（落款被撕）
	var papers := [
		[Vector3(x + 0.040, y + 0.22, zc - 0.52), Vector3(0.004, 0.30, 0.42), Color(0.86, 0.84, 0.72)],
		[Vector3(x + 0.040, y + 0.16, zc + 0.30), Vector3(0.004, 0.26, 0.50), Color(0.88, 0.86, 0.80)],
		[Vector3(x + 0.042, y - 0.28, zc - 0.02), Vector3(0.004, 0.34, 0.56), Color(0.90, 0.88, 0.84)],
	]
	for p in papers:
		a.box(p[0], p[1], a.plain(p[2], 0.95), false)
	# 2024 那张的右下角被撕掉
	a.box(Vector3(x + 0.046, y - 0.42, zc + 0.28), Vector3(0.003, 0.10, 0.16),
		a.plain(Color(0.42, 0.33, 0.24), 0.95), false, 0.3)

# ------------------------------------------------------------------ 门厅灯
## 天花 z = −2 / +3 / +8 / +14，只有第 2 盏亮。
func _lamps() -> void:
	var zs := [-2.0, 3.0, 8.0, 14.0]
	var housing := a.plain(Color(0.18, 0.18, 0.18), 0.6, 0.4)
	var glass_off := a.plain(Color(0.28, 0.28, 0.27), 0.8)
	var glass_on := a.emit(Color(1.0, 0.86, 0.66), 1.4)
	for i in range(zs.size()):
		var z: float = zs[i]
		a.box(Vector3(0, H - 0.05, z), Vector3(0.34, 0.06, 0.34), housing)
		a.box(Vector3(0, H - 0.10, z), Vector3(0.30, 0.04, 0.30), glass_on if i == 1 else glass_off)
	if true:
		# 第 2 盏：2700 K，1F 的主光
		a.omni(Vector3(0, H - 0.22, 3.0), Color(1.0, 0.78, 0.52), 7.6, 15.0, true)
		# 门厅长 26 m，中间一盏托不住两端。补两盏很弱的「邻店漏光」，
		# 让玩家从北门走到楼梯口这一段始终有轮廓（不然进游戏第一眼就是黑的）。
		a.omni(Vector3(0, H - 0.30, -6.5), Color(0.72, 0.70, 0.62), 2.60, 9.0, false)
		a.omni(Vector3(0, H - 0.30, 11.0), Color(0.86, 0.74, 0.54), 3.00, 9.5, false)

# ------------------------------------------------------------------ 后门
func _back_door() -> void:
	var z := Z0 + 0.12
	var x := -0.55
	var w := 0.9
	var h := 2.05
	a.box(Vector3(x, h * 0.5, z), Vector3(w, h, 0.05), a.plain(Color(0.12, 0.16, 0.13), 0.72, 0.35), true)
	a.box(Vector3(x, h + 0.04, z), Vector3(w + 0.10, 0.06, 0.10), m_steel)
	a.box(Vector3(x, 1.45, z + 0.03), Vector3(0.34, 0.36, 0.02), a.plain(Color(0.22, 0.30, 0.28), 0.15, 0.1))
	a.box(Vector3(x + 0.36, 1.02, z + 0.04), Vector3(0.04, 0.04, 0.10),
		a.plain(Color(0.62, 0.58, 0.46), 0.35, 0.8))

# ------------------------------------------------------------------ 楼梯间入口
## 东侧 z = +16.0。这一轮只做门洞 + 前六级踏步，2F 起来后再接竖井。
func _stairs() -> void:
	# 真正的楼梯在 stairs.gd 里建；这里只做洞口门套
	var z := Z1 - 0.04
	var x := 1.55
	a.box(Vector3(x, 2.46, z), Vector3(2.66, 0.12, 0.16), m_steel)
	a.box(Vector3(x - 1.32, 1.20, z), Vector3(0.10, 2.40, 0.14), m_steel)
	a.box(Vector3(x + 1.32, 1.20, z), Vector3(0.10, 2.40, 0.14), m_steel)
