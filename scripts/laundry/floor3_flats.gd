extends RefCounted
## 区域 3 ｜ 3F · 303 店主卧室 / 304 孩子房 / 302 后房（从楼上下来）
## 剧本 v2 区域 3：全案情感核心。玩家在这里明白"她不只是个鬼，她是个妈"。
##
## 层高链：1F 0 → 2F 3.5 → 3F 6.9 → 4F 9.8 → 5F 12.7 → 屋顶 15.6
## 3F 布局：
##   走廊 x −3.2…0，z 2.0…10.1（楼梯上来先到这里）
##   303 卧室  x −3.2…−0.2，z 2.2…6.4   （4.0 × 4.2）
##   304 孩子房 x 0.2…3.2，z 2.2…5.6    （3.0 × 3.4）
##   302 后房（同一间，从楼梯口下来）

const A := preload("res://scripts/laundry/laundry_art.gd")

const Y0 := 6.9          # 3F 地面
const HH := 2.6          # 净高

var a: LaundryArt
var m_wall: StandardMaterial3D
var m_wall_304: StandardMaterial3D
var m_floor: StandardMaterial3D
var m_ceil: StandardMaterial3D
var m_wood: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_white: StandardMaterial3D
var m_fabric: StandardMaterial3D
var lights: Dictionary = {}

func _init(art: LaundryArt) -> void:
	a = art

func w(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, Y0 + y, z)

## 家具 GLB（_setup/blender_bedroom.py 产出）。floor3 只持有 LaundryArt，
## 所以这里直接实例化，做法与 floor2 的 _put_furniture 一致。
## 底面在原点、正面朝 −Z。yaw 用来把正面转向房间内。
func _furn(id: String, pos: Vector3, yaw := 0.0, scale_f := 1.0) -> Node3D:
	var path := "res://assets/models/props/" + id + "/" + id + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("floor3: 缺家具模型 " + path)
		return null
	var ps = load(path)
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate()
	inst.set_meta("dynamic", true)
	inst.position = pos
	inst.rotation.y = yaw
	if scale_f != 1.0:
		inst.scale = Vector3(scale_f, scale_f, scale_f)
	a.root.add_child(inst)
	return inst

func build() -> void:
	_materials()
	_corridor()
	_bedroom_303()
	_kids_304()
	_corridor_to_302()
	_backroom_302()

func _materials() -> void:
	# 3F 是住宅层：暖色、有烟味。墙用旧壁纸/抹灰，地面旧木地板。
	m_wall = a.pbr("painted_plaster_wall", 0.34, Color(0.78, 0.70, 0.58), 1.0, 0.0, 0.45)
	m_wall_304 = a.pbr("painted_plaster_wall", 0.36, Color(0.82, 0.80, 0.74), 0.95, 0.0, 0.40)
	m_floor = a.pbr("old_wooden_floor_01", 0.42, Color(0.52, 0.42, 0.33), 1.0, 0.0, 0.7)
	m_ceil = a.plain(Color(0.72, 0.70, 0.66), 0.95)
	m_wood = a.pbr("old_linoleum_flooring_01", 0.9, Color(0.46, 0.34, 0.24), 1.0)
	m_dark = a.plain(Color(0.09, 0.08, 0.075), 0.9)
	m_white = a.plain(Color(0.88, 0.87, 0.84), 0.85)
	m_fabric = a.plain(Color(0.56, 0.52, 0.46), 0.95)

# ------------------------------------------------------------------ 走廊 + 楼梯口
func _corridor() -> void:
	# 走廊：x −3.2…3.2，z 5.6…10.1（3F 楼梯上来是南端）
	var x0 := -3.2
	var x1 := 3.2
	var z0 := 6.4
	var z1 := 10.1
	a.quad_xz(x0, z0, x1, z1, Y0, m_floor)
	a.quad_xz(x0, z0, x1, z1, Y0 + HH, m_ceil, false)
	a.col(Vector3((x0 + x1) * 0.5, Y0 - 0.15, (z0 + z1) * 0.5),
		Vector3(x1 - x0, 0.3, z1 - z0))
	# 304门前的东侧凹廊；西侧属于303，不再把走廊墙画进卧室。
	a.quad_xz(-.08,5.6,3.2,6.4,Y0,m_floor)
	a.quad_xz(-.08,5.6,3.2,6.4,Y0+HH,m_ceil,false)
	a.col(Vector3(1.56,Y0-.15,6.0),Vector3(3.28,.30,.80))
	# 东西墙
	a.box(Vector3(x0 - 0.06, Y0 + HH * 0.5, (z0 + z1) * 0.5), Vector3(0.12, HH, z1 - z0), m_wall, true)
	a.box(Vector3(x1 + 0.06, Y0 + HH * 0.5, (z0 + z1) * 0.5), Vector3(0.12, HH, z1 - z0), m_wall, true)
	# 南端墙：中间必须真的挖开 2.5 m 的楼梯口（x 0.30…2.80），否则上不到 4F。
	# 原来是一整块 box，只“留”了名义上的洞口 —— 玩家会被墙挡住。
	a.box(Vector3(-2.0, Y0 + HH * 0.5, z1 + 0.06), Vector3(2.40, HH, 0.12), m_wall, true)
	a.box(Vector3(3.00, Y0 + HH * 0.5, z1 + 0.06), Vector3(0.40, HH, 0.12), m_wall, true)
	a.box(Vector3(1.55, Y0 + HH - (HH - 2.10) * 0.5, z1 + 0.06),
		Vector3(2.50, HH - 2.10, 0.12), m_wall, false)
	# 北墙：分隔走廊与 303/304，中间留门
	# 北侧沿各房间自身墙体收口，避免第二道整墙堵住303/304。
	# 走廊灯：3F 是暖的、有烟味
	var lm := a.plain(Color(0.20, 0.19, 0.18), 0.7)
	a.box(Vector3(0.6, Y0 + HH - 0.04, 7.6), Vector3(0.28, 0.05, 0.28), lm)
	a.box(Vector3(0.6, Y0 + HH - 0.08, 7.6), Vector3(0.24, 0.03, 0.24),
		a.emit(Color(1.0, 0.80, 0.56), 1.3))
	lights["corridor"] = a.omni(Vector3(0.6, Y0 + HH - 0.20, 7.6), Color(1.0, 0.76, 0.50), 1.9, 6.5, true)
	# 走廊尽头的旧柜子
	a.box(Vector3(-2.90, Y0 + 0.42, 9.40), Vector3(0.45, 0.84, 0.90), m_wood, true)
	a.box(Vector3(-2.89, Y0 + 0.86, 9.40), Vector3(0.48, 0.04, 0.94), a.plain(Color(0.30, 0.22, 0.15), 0.85))

# ------------------------------------------------------------------ 303 店主卧室
## 4.0 × 4.2 × 2.6。床只铺了一半；五斗柜最下层上锁；梳妆台镜子裂成三块，中间那块被撬走；衣柜里只有男装。
func _bedroom_303() -> void:
	var x0 := -3.2
	var x1 := -0.2
	var z0 := 2.2
	var z1 := 6.4
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	_room(x0, x1, z0, z1, HH, m_wall, "d303")

	# 1 双人床（Blender 版 bed_01，2724 面）：床头板 + 床架 + 床垫 +
	#   被子只盖一半、另一半叠在床尾 + 两个枕头（剧本 3-a 写死）
	var bx: float = cx + 0.10
	var bz := z0 + 1.10
	# 模型正面朝 −Z（床头在 −Z 侧），要床头靠北墙（z0 那侧）→ yaw = PI
	_furn("bed_01", Vector3(bx, Y0, bz), PI)
	# 碰撞
	a.col(Vector3(bx, Y0 + 0.25, bz), Vector3(1.50, 0.50, 2.00))

	# 2 五斗柜（Blender 版 dresser_01，1248 面）：四层抽屉 + 铜把手 + 最下层上锁
	#   模型正面朝 −Z，要靠东墙、抽屉朝西（房间内）→ yaw = -PI/2 会让正面朝 −X
	var dx := x1 - 0.28
	var dz := z0 + 0.95
	_furn("dresser_01", Vector3(dx + 0.02, Y0, dz), -PI * 0.5)
	a.col(Vector3(dx, Y0 + 0.45, dz), Vector3(0.52, 0.90, 1.20))

	# 3 梳妆台（Blender 版 vanity_01，924 面）：两个抽屉 + 镜框 +
	#   三块镜面（中间那块被撬走，只剩钉子）
	var mx := x0 + 0.24
	var mz := z0 + 1.55
	_furn("vanity_01", Vector3(mx, Y0, mz), PI * 0.5)
	a.col(Vector3(mx, Y0 + 0.38, mz), Vector3(0.46, 0.76, 0.90))

	# 4 衣柜（Blender 版 wardrobe_01，692 面）：两扇门 + 嵌板 + 门缝里露出的男装
	#   模型正面朝 −Z，要靠南墙、门朝北（房间内）→ yaw = 0 时正面朝 −Z 正好
	# 衣柜移到西墙并旋转，原位置正对303门洞，把入口完全挡住。
	var wx: float = x0 + .35
	var wz := 5.05
	_furn("wardrobe_01",Vector3(wx,Y0,wz),-PI*.5)
	a.col(Vector3(wx,Y0+1.10,wz),Vector3(.60,2.20,1.80))

	# 5 挂历：停在 2004 年 11 月，7 号圈了两圈
	a.box(Vector3(cx + 0.55, Y0 + 1.68, z0 + 0.02), Vector3(0.40, 0.55, 0.02),
		a.plain(Color(0.86, 0.83, 0.74), 0.9))
	a.box(Vector3(cx + 0.55, Y0 + 1.68, z0 + 0.035), Vector3(0.34, 0.46, 0.01),
		a.plain(Color(0.92, 0.90, 0.82), 0.9))
	a.label("2004 11", w(cx + 0.55, 1.90, z0 + 0.05), 0.030, Color(0.30, 0.26, 0.20), 0.0, 28)
	a.cyl(w(cx + 0.60, 1.62, z0 + 0.05), 0.022, 0.003,
		a.plain(Color(0.68, 0.12, 0.10), 0.7), 14, "z")

	# 6 窗帘：有一道从下往上的烟熏痕
	a.box(Vector3(cx + 1.30, Y0 + 1.45, z1 - 0.06), Vector3(1.40, 1.80, 0.04), m_fabric)
	var smoke := a.plain(Color(0.16, 0.14, 0.12), 0.95)
	a.box(Vector3(cx + 1.30, Y0 + 1.05, z1 - 0.085), Vector3(1.10, 0.90, 0.01), smoke)
	a.box(Vector3(cx + 1.30, Y0 + 1.60, z1 - 0.085), Vector3(0.70, 0.36, 0.01),
		a.plain(Color(0.24, 0.21, 0.18), 0.95))

	# 灯：3F 用 3000 K 暖光，但窗那一侧是冷的
	lights["d303"] = a.omni(Vector3(cx, Y0 + 2.35, cz), Color(1.0, 0.80, 0.56), 1.7, 5.5, true)
	a.omni(Vector3(cx + 1.20, Y0 + 1.50, z1 - 0.30), Color(0.62, 0.70, 0.86), 0.45, 2.6, false)

# ------------------------------------------------------------------ 304 孩子房
## 3.0 × 3.4 × 2.5。全案的恐怖顶点：不脏、不乱、不流血——被收拾得干干净净。
func _kids_304() -> void:
	var x0 := 0.2
	var x1 := 3.2
	var z0 := 2.2
	var z1 := 5.6
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	_room(x0, x1, z0, z1, 2.5, m_wall_304, "d304")

	# 小床（Blender 版 kidsbed_01，1372 面）：床架 + 平整的被子 + 枕头（两个压痕）
	#   模型正面朝 −Z（床头在 −Z 侧），床头靠北墙 → yaw = PI
	_furn("kidsbed_01", Vector3(cx - 0.55, Y0, z0 + 0.90), PI)
	a.col(Vector3(cx - 0.55, Y0 + 0.22, z0 + 0.90), Vector3(1.00, 0.36, 1.60))

	# 书桌 + 椅子（Blender 版 kidsdesk_01，876 面）：抽屉 + 作业本 + 铅笔 + 塞在桌下的椅子
	#   模型正面朝 −Z，靠南墙、椅面朝北 → yaw = 0
	_furn("kidsdesk_01", Vector3(cx + 0.55, Y0, z1 - 0.35), 0.0)
	a.col(Vector3(cx + 0.55, Y0 + 0.32, z1 - 0.35), Vector3(0.90, 0.64, 0.50))

	# 墙贴：《海底两万里》，贴到一半停了
	a.box(Vector3(cx + 1.05, Y0 + 1.45, z0 + 0.02), Vector3(0.52, 0.36, 0.02),
		a.plain(Color(0.28, 0.44, 0.56), 0.9))
	a.box(Vector3(cx + 1.05, Y0 + 1.45, z0 + 0.03), Vector3(0.44, 0.28, 0.01),
		a.plain(Color(0.42, 0.62, 0.68), 0.9))
	# 贴到一半：翘起来的一角
	a.box(Vector3(cx + 1.26, Y0 + 1.30, z0 + 0.04), Vector3(0.10, 0.10, 0.01),
		a.plain(Color(0.72, 0.72, 0.66), 0.95), false, 0.4)

	# 衣柜：6 岁男孩的衣服，按季节排好，一件不少
	a.box(Vector3(cx + 1.10, Y0 + 1.05, z1 - 0.30), Vector3(0.90, 1.90, 0.52), m_wood, true)
	a.box(Vector3(cx + 1.10, Y0 + 1.05, z1 - 0.57), Vector3(0.86, 1.82, 0.02), a.plain(Color(0.26, 0.22, 0.18), 0.9))
	for i in range(5):
		a.box(Vector3(cx + 0.76 + float(i) * 0.17, Y0 + 1.30, z1 - 0.52), Vector3(0.13, 0.62, 0.04),
			a.plain(Color(0.36 + 0.06 * float(i), 0.40 + 0.04 * float(i), 0.48), 0.95))

	# 窗台：一排小石头，每颗上面写着日期（366 颗的暗示，这里只摆一排）
	var sill := a.plain(Color(0.66, 0.62, 0.54), 0.9)
	a.box(Vector3(x1 - 0.10, Y0 + 1.15, cz), Vector3(0.20, 0.06, 1.60), sill)
	for i in range(9):
		a.box(Vector3(x1 - 0.10, Y0 + 1.20, cz - 0.62 + float(i) * 0.155),
			Vector3(0.055, 0.035, 0.045), a.plain(Color(0.52, 0.50, 0.46), 0.95))

	# 灯：孩子房是"病房那种惨白的日光"——全楼唯一一处
	a.box(Vector3(cx, Y0 + 2.42, cz), Vector3(0.90, 0.05, 0.12), m_white)
	a.box(Vector3(cx, Y0 + 2.39, cz), Vector3(0.86, 0.02, 0.09), a.emit(Color(0.92, 0.96, 1.0), 1.6))
	lights["d304"] = a.omni(Vector3(cx, Y0 + 2.28, cz), Color(0.88, 0.94, 1.0), 2.1, 5.0, true)

## 302 的连接过道：从 3F 走廊北端（z=2.2）往北到 302 门口。
## 302 在 z=−0.7…1.9，与走廊之间隔着 303 —— 没有这条过道就永远走不到 302。
## 位置取 303 的西侧墙边（x −3.2…−2.0），宽 1.2 m，正好与 302 门洞对齐。
func _corridor_to_302() -> void:
	# 302 在 z −0.7…1.9。过道必须放在 302 的**南侧**（z 1.9…2.3）再往西折，
	# 不能与 302 房间本身重叠（原来 x −3.2…−2.0 / z −0.7…2.3 与 302 完全叠在一起，
	# 两张地面互相覆盖、过道东墙把房间劈成两半 —— 相机进去只能看到墙）。
	#
	# 形状：L 形。第一段（南北向）从 3F 走廊北端 z=2.2 下来到 z=1.95，宽 1.2（x −2.6…−1.4）；
	# 第二段（东西向）沿 302 南墙外沿 z 1.95…2.25 往西到 x=−2.6 再进 302 门洞。
	var y0: float = Y0
	var h: float = 2.40
	# —— 第一段：南北短廊（连接 3F 走廊）
	var ax0 := -2.60
	var ax1 := -1.40
	var az0 := 1.95
	# 接管廊止于303北墙外，不能伸进卧室把床头劈开。
	var az1 := 2.10
	a.quad_xz(ax0, az0, ax1, az1, y0, m_floor)
	a.quad_xz(ax0, az0, ax1, az1, y0 + h, m_ceil, false)
	a.col(Vector3((ax0 + ax1) * 0.5, y0 - 0.15, (az0 + az1) * 0.5),
		Vector3(ax1 - ax0, 0.3, az1 - az0))
	# 短廊西墙 / 东墙
	a.box(Vector3(ax0 - 0.06, y0 + h * 0.5, (az0 + az1) * 0.5),
		Vector3(0.12, h, az1 - az0), m_wall, true)
	a.box(Vector3(ax1 + 0.06, y0 + h * 0.5, (az0 + az1) * 0.5),
		Vector3(0.12, h, az1 - az0), m_wall, true)
	# —— 第二段：302 门前那一小块（门口平台），与 302 的门洞对齐
	a.quad_xz(-2.70, 1.90, -1.20, 1.95, y0 + 0.002, m_floor)
	a.col(Vector3(-1.95, y0 - 0.15, 1.925), Vector3(1.50, 0.3, 0.05))
	# —— 过道灯
	a.box(Vector3(-2.00, y0 + h - 0.04, 2.20), Vector3(0.16, 0.04, 0.16),
		a.plain(Color(0.20, 0.19, 0.18), 0.8))
	a.box(Vector3(-2.00, y0 + h - 0.07, 2.20), Vector3(0.13, 0.02, 0.13),
		a.emit(Color(1.0, 0.80, 0.55), 1.2))
	a.omni(Vector3(-2.00, y0 + h - 0.22, 2.20), Color(1.0, 0.78, 0.52), 1.15, 4.0, true)

# ------------------------------------------------------------------ 302 后房
## 剧本 3-c：与 2-b 同一间，从楼上下来就是它。
## **关键**：后房的地板上有一道水痕，从锅炉一直延伸到楼梯口 —— **是往上走的**。
## 这一间就是 2F 后房的正上方，两间的锅炉位置上下对齐。
func _backroom_302() -> void:
	# 世界坐标与 2F 后房一致：x −3.2…0，z −0.7…+1.9（尺寸 3.2 × 2.6）
	var x0 := -3.2
	var x1 := 0.0
	var z0 := -0.7
	var z1 := 1.9
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var HH2 := 2.40
	# 壳
	a.quad_xz(x0, z0, x1, z1, Y0, m_floor)
	a.quad_xz(x0, z0, x1, z1, Y0 + HH2, m_ceil, false)
	a.col(Vector3(cx, Y0 - 0.15, cz), Vector3(x1 - x0, 0.3, z1 - z0))
	a.box(Vector3(x0 - 0.06, Y0 + HH2 * 0.5, cz), Vector3(0.12, HH2, z1 - z0), m_wall, true)
	a.box(Vector3(x1 + 0.06, Y0 + HH2 * 0.5, cz), Vector3(0.12, HH2, z1 - z0), m_wall, true)
	a.box(Vector3(cx, Y0 + HH2 * 0.5, z0 - 0.06), Vector3(x1 - x0, HH2, 0.12), m_wall, true)
	# 南墙：留 0.9 m 门洞（通向 303 那侧的过道）
	a.box(Vector3(-2.70, Y0 + HH2 * 0.5, z1 + 0.06), Vector3(1.00, HH2, 0.12), m_wall, true)
	a.box(Vector3(-0.65, Y0 + HH2 * 0.5, z1 + 0.06), Vector3(1.30, HH2, 0.12), m_wall, true)
	a.box(Vector3(-1.75, Y0 + 2.10, z1 + 0.06), Vector3(1.00, 0.30, 0.12), m_wall, false)
	# 门套 + 门牌
	var fm := a.pbr("old_linoleum_flooring_01", 1.8, Color(0.28, 0.22, 0.16), 0.7)
	a.box(Vector3(-2.20, Y0 + 1.02, z1 + 0.02), Vector3(0.08, 2.04, 0.10), fm, false)
	a.box(Vector3(-1.30, Y0 + 1.02, z1 + 0.02), Vector3(0.08, 2.04, 0.10), fm, false)
	a.box(Vector3(-1.75, Y0 + 2.08, z1 + 0.02), Vector3(1.00, 0.08, 0.10), fm, false)
	a.label("302", Vector3(-1.20, Y0 + 1.62, z1 + 0.10), 0.085,
		Color(0.22, 0.20, 0.17), 0.0, 34)

	# —— 2F 后房那台锅炉的正上方：同样位置再立一台（楼上楼下共用一根烟道）。
	#     floor3_flats.gd 只持有 LaundryArt，没有 LaundryKit.model()，
	#     所以这里直接实例化 GLB（做法与 floor2 的 _put_furniture 一致）。
	var bp := Vector3(-2.90, Y0, -0.60)
	var bps = load("res://assets/models/props/boiler_01/boiler_01.glb")
	if bps != null:
		var bi: Node3D = bps.instantiate()
		bi.set_meta("dynamic", true)
		bi.position = bp
		bi.scale = Vector3(0.42, 0.42, 0.42)   # 后房这台是小的（净高只有 2.4）
		a.root.add_child(bi)
	else:
		# 兜底：加载失败时退回圆柱
		var rust := a.plain(Color(0.30, 0.24, 0.20), 0.95, 0.25)
		a.cyl(bp + Vector3(0, 0.80, 0), 0.25, 1.55, rust, 18)
		a.cyl(bp + Vector3(0, 1.58, 0), 0.27, 0.06, a.plain(Color(0.28, 0.26, 0.24), 0.8), 18)
	# 烟道：从这台锅炉一直穿到 2F 那台的上方（视觉上连成一根）
	a.cyl(bp + Vector3(0, 1.02, 0), 0.075, 1.35, a.plain(Color(0.30, 0.24, 0.20), 0.95, 0.25), 10)

	# —— 地板上的水痕：从锅炉底座一直延伸到楼梯口（南门口），**往上走的**
	#     做法：一道断续的湿痕 + 沿途越来越窄的湿脚印状斑 + 末端一小摊。
	var water_m := a.plain(Color(0.16, 0.18, 0.18), 0.08)
	# 主水痕：从锅炉 (x−2.90, z−0.60) 到门口 (x−1.75, z+1.90)
	var steps := 16
	for i in range(steps):
		var t := float(i) / float(steps - 1)
		var px: float = lerpf(-2.90, -1.75, t)
		var pz: float = lerpf(-0.60, 1.92, t)
		# 越往上越窄（水在“往上游走”）
		var wdt: float = lerpf(0.42, 0.12, t)
		var dep: float = lerpf(0.30, 0.10, t)
		a.quad_xz(px - wdt * 0.5, pz - dep * 0.5, px + wdt * 0.5, pz + dep * 0.5,
			Y0 + 0.004 + 0.0002 * float(i), water_m)
	# 水痕上每隔一段一条更深的“水线”（读得出是流动的轨迹，不是一摊）
	var line_m := a.plain(Color(0.10, 0.12, 0.12), 0.05)
	for i in range(7):
		var t2 := (float(i) + 0.5) / 7.0
		var lx: float = lerpf(-2.90, -1.75, t2)
		var lz: float = lerpf(-0.60, 1.92, t2)
		a.quad_xz(lx - 0.02, lz - 0.09, lx + 0.02, lz + 0.09, Y0 + 0.006, line_m)
	# 末端：门口那一小摊（水到门口就“停”了，因为门外是楼梯 —— 它要上楼）
	a.quad_xz(-2.05, 1.55, -1.45, 2.05, Y0 + 0.005, water_m)
	a.quad_xz(-1.95, 1.62, -1.55, 1.98, Y0 + 0.007, line_m)
	# 门槛上的一道水（暗示它继续往楼梯走）
	a.quad_xz(-1.90, 2.10, -1.60, 2.24, Y0 + 0.006, water_m)

	# —— 墙角的旧纸箱（从 2F 后房搬上来的东西；这里用纯几何，
	#     floor3_flats.gd 只持有 LaundryArt，没有 LaundryKit 的 model()）
	var cbm := a.pbr("brick_4", 1.6, Color(0.66, 0.56, 0.43), 1.0, 0.0, 0.8)
	a.bev(Vector3(-0.45, Y0 + 0.24, 1.20), Vector3(0.52, 0.48, 0.44), cbm, 0.010, true)
	a.box(Vector3(-0.45, Y0 + 0.49, 1.20), Vector3(0.54, 0.03, 0.46),
		a.plain(Color(0.58, 0.49, 0.37), 0.9), false, 0.10)
	a.bev(Vector3(-0.52, Y0 + 0.62, 1.24), Vector3(0.40, 0.26, 0.34), cbm, 0.008, false)
	a.box(Vector3(-0.52, Y0 + 0.76, 1.24), Vector3(0.42, 0.02, 0.36),
		a.plain(Color(0.60, 0.51, 0.39), 0.9), false, -0.14)
	# —— 墙上的旧照片（与 2F 照片墙遥相呼应，但只剩空框）
	a.box(Vector3(x1 - 0.05, Y0 + 1.62, -0.30), Vector3(0.03, 0.42, 0.34),
		a.plain(Color(0.26, 0.20, 0.14), 0.8), false)
	a.box(Vector3(x1 - 0.07, Y0 + 1.62, -0.30), Vector3(0.02, 0.34, 0.26),
		a.plain(Color(0.60, 0.57, 0.50), 0.95), false)
	# —— 一盏灯泡（和后房一样，吊着的）
	a.box(Vector3(cx + 0.30, Y0 + HH2 - 0.04, 0.40), Vector3(0.10, 0.05, 0.10),
		a.plain(Color(0.20, 0.19, 0.18), 0.8))
	a.cyl(Vector3(cx + 0.30, Y0 + HH2 - 0.14, 0.40), 0.008, 0.10,
		a.plain(Color(0.30, 0.28, 0.26), 0.8), 8)
	a.box(Vector3(cx + 0.30, Y0 + HH2 - 0.20, 0.40), Vector3(0.055, 0.045, 0.045),
		a.emit(Color(1.0, 0.82, 0.55), 1.5))
	a.omni(Vector3(cx + 0.30, Y0 + HH2 - 0.32, 0.40), Color(1.0, 0.80, 0.52), 1.7, 5.2, true)

# ------------------------------------------------------------------ 房间壳
func _room(x0: float, x1: float, z0: float, z1: float, h: float, mat: Material, key: String) -> void:
	a.quad_xz(x0, z0, x1, z1, Y0, m_floor)
	a.quad_xz(x0, z0, x1, z1, Y0 + h, m_ceil, false)
	a.col(Vector3((x0 + x1) * 0.5, Y0 - 0.15, (z0 + z1) * 0.5),
		Vector3(x1 - x0, 0.3, z1 - z0))
	var t := 0.12
	# 四面墙（南墙朝走廊，留门）
	a.box(Vector3(x0 - t * 0.5, Y0 + h * 0.5, (z0 + z1) * 0.5), Vector3(t, h, z1 - z0), mat, true)
	a.box(Vector3(x1 + t * 0.5, Y0 + h * 0.5, (z0 + z1) * 0.5), Vector3(t, h, z1 - z0), mat, true)
	a.box(Vector3((x0 + x1) * 0.5, Y0 + h * 0.5, z0 - t * 0.5), Vector3(x1 - x0, h, t), mat, true)
	# 南墙：门洞 0.9 m 居中
	var cx := (x0 + x1) * 0.5
	a.box(Vector3(x0 + (cx - 0.45 - x0) * 0.5, Y0 + h * 0.5, z1 + t * 0.5),
		Vector3(cx - 0.45 - x0, h, t), mat, true)
	a.box(Vector3(cx + 0.45 + (x1 - cx - 0.45) * 0.5, Y0 + h * 0.5, z1 + t * 0.5),
		Vector3(x1 - cx - 0.45, h, t), mat, true)
	a.box(Vector3(cx, Y0 + 2.25, z1 + t * 0.5), Vector3(0.90, h - 2.10, t), mat, false)
	# 门套
	var df := a.plain(Color(0.24, 0.19, 0.14), 0.85)
	a.box(Vector3(cx - 0.50, Y0 + 1.05, z1 + 0.02), Vector3(0.08, 2.10, 0.10), df, false)
	a.box(Vector3(cx + 0.50, Y0 + 1.05, z1 + 0.02), Vector3(0.08, 2.10, 0.10), df, false)
	a.box(Vector3(cx, Y0 + 2.12, z1 + 0.02), Vector3(1.10, 0.08, 0.10), df, false)
