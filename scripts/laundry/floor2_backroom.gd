extends RefCounted
## 区域 2-b ｜ 2F · 后房（3.2 × 2.6 × 2.4）
## 照 v1 场景 6 的局部坐标：原点在房间中心地面。
## 世界位置：洗衣店北墙之后，x −3.2…0，z −0.7…+1.9，地面 y = 3.5。
##
## 这里没有怪物，全是证据：老顾客簿 / 旧招牌 / 锅炉 / 水表 / 照片墙 / 儿童雨衣 / 钥匙串 / 剪报。

const A := preload("res://scripts/laundry/laundry_art.gd")

const Y0 := 3.5
const CX := -1.6      # 房间中心 x
const CZ := 0.6       # 房间中心 z
const HX := 1.6
const HZ := 1.3
const HH := 2.40

var a: LaundryArt
var bulb: OmniLight3D
var keyring: Node3D = null
var m_wall: StandardMaterial3D
var m_floor: StandardMaterial3D

func _init(art: LaundryArt) -> void:
	a = art

## 局部 → 世界
func w(x: float, y: float, z: float) -> Vector3:
	return Vector3(CX + x, Y0 + y, CZ + z)

func build() -> void:
	_shell()
	_clerk_book()
	_signboard()
	_boiler()
	_meter()
	_photo_wall()
	_raincoat()
	_keyring()
	_bulb()

func _shell() -> void:
	m_floor = a.tile_mat(0.30, Color(0.72, 0.70, 0.66), Color(0.20, 0.20, 0.18))
	m_wall = a.pbr("grey_plaster_02", 0.33, Color(0.68, 0.67, 0.64), 1.0, 0.0, 0.5)
	# 地面 / 天花
	a.quad_xz(CX - HX, CZ - HZ, CX + HX, CZ + HZ, Y0, m_floor)
	a.quad_xz(CX - HX, CZ - HZ, CX + HX, CZ + HZ, Y0 + HH, a.plain(Color(0.62, 0.60, 0.57), 0.95), false)
	a.col(Vector3(CX, Y0 - 0.15, CZ), Vector3(HX * 2.0, 0.3, HZ * 2.0))
	# 四面墙
	a.box(Vector3(CX - HX - 0.06, Y0 + HH * 0.5, CZ), Vector3(0.12, HH, HZ * 2.0), m_wall, true)
	a.box(Vector3(CX + HX + 0.06, Y0 + HH * 0.5, CZ), Vector3(0.12, HH, HZ * 2.0), m_wall, true)
	a.box(Vector3(CX, Y0 + HH * 0.5, CZ - HZ - 0.06), Vector3(HX * 2.0, HH, 0.12), m_wall, true)
	# 南墙：门洞 x −2.20…−1.30（0.9 m），其余补墙
	a.box(Vector3(-2.70, Y0 + HH * 0.5, CZ + HZ + 0.06), Vector3(1.00, HH, 0.12), m_wall, true)
	a.box(Vector3(-0.65, Y0 + HH * 0.5, CZ + HZ + 0.06), Vector3(1.30, HH, 0.12), m_wall, true)
	a.box(Vector3(-1.75, Y0 + 2.25, CZ + HZ + 0.06), Vector3(1.00, 0.30, 0.12), m_wall, false)
	# 门框
	var frame := a.plain(Color(0.20, 0.17, 0.14), 0.8)
	a.box(w(0.05, 1.05, HZ + 0.02), Vector3(0.96, 2.10, 0.05), frame, false)
	a.box(w(0.05, 1.05, HZ - 0.02), Vector3(0.06, 2.10, 0.06), frame, false)
	# 低矮的天花让房间压抑：加一根横梁
	a.box(Vector3(CX, Y0 + HH - 0.10, CZ), Vector3(HX * 2.0, 0.20, 0.20), m_wall)

# ------------------------------------------------------------------ 1 老顾客簿
func _clerk_book() -> void:
	# 铁架
	var steel := a.pbr("metal_plate", 1.4, Color(0.52, 0.53, 0.54), 0.9, 0.6)
	a.box(w(-0.90, 0.52, -0.40), Vector3(0.40, 0.05, 0.50), steel, true)
	for lx in [-0.17, 0.17]:
		a.box(w(-0.90 + lx, 0.26, -0.40), Vector3(0.04, 0.52, 0.04), steel)
	a.box(w(-0.90, 0.52, -0.16), Vector3(0.40, 0.04, 0.04), steel)
	# 牛皮纸簿 + 硬板夹
	var paper := a.plain(Color(0.62, 0.50, 0.34), 0.94)
	a.box(w(-0.90, 0.57, -0.40), Vector3(0.32, 0.05, 0.24), paper, false, 0.08)
	a.box(w(-0.90, 0.60, -0.40), Vector3(0.31, 0.005, 0.23), a.plain(Color(0.86, 0.83, 0.72), 0.95))
	# 夹具
	a.box(w(-0.90, 0.63, -0.49), Vector3(0.20, 0.03, 0.05), steel, false)
	# 翻开的那一页（2004-11-07 那一行）
	a.label("11/07  周秀兰  7号机  童装一套  未取", w(-0.90, 0.72, -0.40), 0.014,
		Color(0.24, 0.20, 0.16), 0.0, 34)

# ------------------------------------------------------------------ 2 旧招牌
func _signboard() -> void:
	# 2.4 × 0.5 的木牌，靠在西墙，漆下凸字「秀兰干洗」
	var wood := a.pbr("old_linoleum_flooring_01", 1.2, Color(0.46, 0.36, 0.26), 1.0)
	a.box(w(0.60, 0.25, -1.10), Vector3(2.40, 0.50, 0.06), wood, true, 0.0)
	# 斜靠
	var sb := a.box(w(0.55, 0.48, -1.05), Vector3(2.30, 0.46, 0.05),
		a.plain(Color(0.34, 0.44, 0.36), 0.8), false)
	sb.rotation.x = -0.28
	a.label("秀 兰 干 洗", w(0.55, 0.50, -1.005), 0.062, Color(0.60, 0.59, 0.50), 0.0, 46)

# ------------------------------------------------------------------ 3 锅炉
func _boiler() -> void:
	var rust := a.plain(Color(0.30, 0.24, 0.20), 0.95, 0.25)
	var p := w(-1.30, 0.80, -1.20)
	a.cyl(p, 0.25, 1.55, rust, 18)
	# 顶盖 + 底脚
	a.cyl(p + Vector3(0, 0.78, 0), 0.27, 0.06, a.plain(Color(0.28, 0.26, 0.24), 0.8), 18)
	for lx in [-0.16, 0.16]:
		a.box(p + Vector3(lx, -0.75, 0), Vector3(0.06, 0.10, 0.06), a.plain(Color(0.20, 0.19, 0.18), 0.9))
	# 压力表：停在红区
	var dial := a.cyl(p + Vector3(0.0, 0.30, 0.26), 0.085, 0.04, a.plain(Color(0.86, 0.84, 0.78), 0.6), 16, "z")
	dial.rotation.z = 0.0
	a.box(p + Vector3(0.04, 0.30, 0.29), Vector3(0.012, 0.055, 0.006),
		a.plain(Color(0.70, 0.12, 0.10), 0.7), false, 0.5)
	# 进水管 / 出水管
	a.cyl(p + Vector3(0, 0.60, -0.30), 0.035, 0.55, a.pbr("metal_plate", 1.6, Color(0.55, 0.52, 0.48), 0.9, 0.5), 10, "z")
	a.cyl(p + Vector3(0.28, 0.10, 0), 0.030, 0.60, a.plain(Color(0.32, 0.30, 0.28), 0.8), 10, "x")

# ------------------------------------------------------------------ 4 水表
func _meter() -> void:
	var brass := a.plain(Color(0.68, 0.55, 0.30), 0.45, 0.75)
	a.box(w(0.10, 1.50, -1.26), Vector3(0.20, 0.20, 0.10), brass, false)
	a.cyl(w(0.10, 1.50, -1.20), 0.07, 0.02, a.plain(Color(0.90, 0.88, 0.82), 0.5), 16, "z")
	for i in range(4):
		a.box(w(0.10, 1.44 + 0.01 * i, -1.185), Vector3(0.008, 0.022, 0.004),
			a.plain(Color(0.12, 0.12, 0.12), 0.8), false)
	a.cyl(w(0.10, 1.36, -1.26), 0.022, 0.22, a.plain(Color(0.40, 0.38, 0.34), 0.7), 8)

# ------------------------------------------------------------------ 5 照片墙
func _photo_wall() -> void:
	var cork := a.plain(Color(0.34, 0.27, 0.20), 0.98)
	a.box(w(0.90, 1.60, -1.275), Vector3(1.40, 1.00, 0.03), cork, false)
	a.box(w(0.90, 1.60, -1.29), Vector3(1.46, 1.06, 0.012), a.plain(Color(0.28, 0.22, 0.16), 0.9), false)
	# 三张照片
	var photos := [
		[Vector3(0.42, 1.85, -1.255), Vector2(0.26, 0.20), Color(0.72, 0.70, 0.64)],
		[Vector3(1.36, 1.78, -1.255), Vector2(0.22, 0.28), Color(0.68, 0.66, 0.62)],
		[Vector3(0.92, 1.24, -1.255), Vector2(0.30, 0.22), Color(0.74, 0.72, 0.66)],
	]
	for ph in photos:
		a.box(w(ph[0].x, ph[0].y, ph[0].z), Vector3(ph[1].x, ph[1].y, 0.006), a.plain(ph[2], 0.92), false)
	# 全家福：三个人，孩子的脸被刮掉
	var fam := w(0.42, 1.85, -1.248)
	a.box(fam + Vector3(0, 0.03, 0), Vector3(0.24, 0.14, 0.003), a.plain(Color(0.46, 0.44, 0.40), 0.9), false)
	a.box(fam + Vector3(-0.06, 0.02, 0.002), Vector3(0.05, 0.10, 0.002), a.plain(Color(0.30, 0.30, 0.30), 0.95), false)
	a.box(fam + Vector3(0.05, 0.02, 0.002), Vector3(0.05, 0.10, 0.002), a.plain(Color(0.26, 0.26, 0.26), 0.95), false)
	# 被刀片刮掉的脸：一块发白的刮痕
	a.box(fam + Vector3(0.0, -0.05, 0.004), Vector3(0.06, 0.05, 0.002),
		a.plain(Color(0.84, 0.82, 0.76), 1.0), false, 0.3)
	# 图钉
	for ph in photos:
		a.box(w(ph[0].x, ph[0].y + ph[1].y * 0.45, ph[0].z + 0.006), Vector3(0.012, 0.012, 0.008),
			a.plain(Color(0.62, 0.16, 0.14), 0.6), false)
	# 8 剪报（照片墙下沿）
	var news := a.plain(Color(0.80, 0.76, 0.62), 0.95)
	a.box(w(0.90, 0.94, -1.255), Vector3(0.28, 0.20, 0.005), news, false, 0.04)
	a.label("老街27号「秀兰干洗」昨夜起火\n一人失联", w(0.90, 0.94, -1.246), 0.011,
		Color(0.30, 0.27, 0.21), 0.0, 26)

# ------------------------------------------------------------------ 6 儿童雨衣
func _raincoat() -> void:
	var hook := a.plain(Color(0.40, 0.38, 0.34), 0.6, 0.6)
	a.box(w(-0.40, 1.72, -1.24), Vector3(0.06, 0.10, 0.06), hook)
	var yellow := a.plain(Color(0.86, 0.72, 0.16), 0.62)
	# 雨衣：肩 + 前襟 + 下摆
	a.box(w(-0.40, 1.55, -1.20), Vector3(0.34, 0.10, 0.14), yellow)
	a.box(w(-0.40, 1.30, -1.19), Vector3(0.30, 0.42, 0.10), yellow)
	a.box(w(-0.40, 1.08, -1.17), Vector3(0.34, 0.10, 0.14), yellow, false, 0.0)
	# 兜帽
	a.box(w(-0.40, 1.66, -1.21), Vector3(0.16, 0.12, 0.10), yellow)
	# 还在滴水：地面上的一小片湿痕 + 一滴悬着的
	a.quad_xz(CX - 0.60, CZ - 1.05, CX - 0.20, CZ - 0.85, Y0 + 0.004,
		a.plain(Color(0.30, 0.32, 0.30), 0.15))
	a.box(w(-0.40, 0.98, -1.17), Vector3(0.02, 0.02, 0.02),
		a.plain(Color(0.70, 0.78, 0.80), 0.1), false)

# ------------------------------------------------------------------ 7 备用钥匙串
func _keyring() -> void:
	var iron := a.plain(Color(0.34, 0.33, 0.31), 0.7, 0.5)
	keyring = a.push_group(w(-1.30, 1.58, -1.20), 0.0, true)
	a.cyl(Vector3(0, 0.04, 0), 0.035, 0.008, iron, 12, "y")
	for i in range(3):
		a.box(Vector3(0.02 * i, 0.0, 0.01 * i), Vector3(0.012, 0.075, 0.022), iron, false)
	a.pop_group()

# ------------------------------------------------------------------ 灯
func _bulb() -> void:
	a.box(w(0.10, 2.36, 0.10), Vector3(0.10, 0.06, 0.10), a.plain(Color(0.20, 0.19, 0.18), 0.8))
	a.cyl(w(0.10, 2.30, 0.10), 0.008, 0.10, a.plain(Color(0.30, 0.28, 0.26), 0.8), 8)
	a.box(w(0.10, 2.24, 0.10), Vector3(0.055, 0.045, 0.045), a.emit(Color(1.0, 0.82, 0.55), 1.5))
	# 拉绳
	a.cyl(w(0.18, 1.90, 0.10), 0.004, 0.60, a.plain(Color(0.50, 0.48, 0.42), 0.9), 6)
	a.box(w(0.18, 1.58, 0.10), Vector3(0.016, 0.05, 0.016), a.plain(Color(0.42, 0.40, 0.36), 0.9))
	bulb = a.omni(w(0.10, 2.20, 0.10), Color(1.0, 0.80, 0.52), 1.9, 5.0, true)
