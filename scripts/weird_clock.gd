extends Node3D
## 诡异时钟（第一案 · 出租屋）
## ---------------------------------------------------------------------------
## 剧本设定：主角签下这份工作后，诡异事务局送了他一只钟。
## 它自己会走。**拧它，就能把时间拨快** —— 但只有到点的时候，事情才会发生。
##
## 用法：
##   clock = WeirdClock.new(); add_child(clock); clock.setup(font, world_pos)
##   clock.turn(15.0)      # 拧 15 分钟
##   clock.step(delta)     # 每帧（只有游戏时间在走的时候才调）
##   signal tick(min)      # 每分钟
##   signal milestone(id)  # 到了剧本节点（00:01 广播 / 01:10 她进门 / 03:10 数衣服…）

signal tick(total_min: float)
signal milestone(id: String)

## 剧本节点（相对 23:40 的分钟数）
const MILESTONES := [
	{"id": "bc1", "at": 21.0, "label": "00:01 第一次广播"},
	{"id": "bc2", "at": 40.0, "label": "00:20 「请」字消失"},
	{"id": "oldlady", "at": 110.0, "label": "01:30 她进门"},
	{"id": "count", "at": 210.0, "label": "03:10 数衣服"},
	{"id": "mirror", "at": 220.0, "label": "03:20 镜子"},
	{"id": "ask", "at": 240.0, "label": "03:40 「是不是洗好了？」"},
	{"id": "dawn", "at": 260.0, "label": "04:00 天亮"},
]

const START_MIN := 23 * 60 + 40      # 23:40
const SPEED := 1.0                    # 正常走速（1 游戏分钟 / 现实秒）
const TURN_STEP := 10.0               # 每拧一下拨 10 分钟

var font: Font
var total_min := 0.0                  # 从 23:40 起算的分钟
var running := true
var fired := {}
var turning := false

# 节点
var root: Node3D
var face: MeshInstance3D
var hand_hour: Node3D
var hand_min: Node3D
var glint: OmniLight3D
var label_3d: Label3D

func setup(f: Font, pos: Vector3) -> void:
	font = f
	root = Node3D.new()
	root.position = pos
	root.name = "WeirdClock"
	add_child(root)
	_build()
	_update_hands()

## 外观：黄铜座钟，50 cm 高。刻意和这间屋里所有东西的质感都不一样 ——
## 它太新了，新得不像这间屋子该有的东西。
func _build() -> void:
	var brass := _pbr(Color(0.62, 0.48, 0.22), 0.28, 0.85)
	var dark := _plain(Color(0.06, 0.06, 0.07), 0.9)
	var cream := _plain(Color(0.90, 0.87, 0.76), 0.55)
	var glass := _glass()
	# 底座 + 三层收分
	_box(root, Vector3(0, 0.02, 0), Vector3(0.30, 0.04, 0.20), dark)
	_box(root, Vector3(0, 0.09, 0), Vector3(0.24, 0.12, 0.16), brass)
	_box(root, Vector3(0, 0.17, 0), Vector3(0.28, 0.03, 0.19), brass)
	# 钟体
	_box(root, Vector3(0, 0.34, 0), Vector3(0.26, 0.30, 0.18), brass)
	# 表盘（朝 +Z，也就是朝向玩家时能看见）
	_box(root, Vector3(0, 0.34, 0.093), Vector3(0.22, 0.22, 0.012), cream)
	# 刻度：12 个
	for i in range(12):
		var ang := TAU * float(i) / 12.0
		var r := 0.088
		var p := Vector3(sin(ang) * r, 0.34 + cos(ang) * r, 0.100)
		_box(root, p, Vector3(0.008, 0.020, 0.004), dark, 0.0,
			Vector2.ZERO, ang)
	# 表盘中心
	_cyl(root, Vector3(0, 0.34, 0.102), 0.008, 0.006, dark, 10, "z")
	# 时针 / 分针（可转，挂在 pivot 上）
	hand_hour = Node3D.new()
	hand_hour.position = Vector3(0, 0.34, 0.104)
	root.add_child(hand_hour)
	_box(hand_hour, Vector3(0, 0.026, 0), Vector3(0.010, 0.052, 0.004), dark)
	hand_min = Node3D.new()
	hand_min.position = Vector3(0, 0.34, 0.108)
	root.add_child(hand_min)
	_box(hand_min, Vector3(0, 0.036, 0), Vector3(0.007, 0.072, 0.004), dark)
	# 玻璃罩（半透，能看见里面的针）
	_box(root, Vector3(0, 0.34, 0.112), Vector3(0.24, 0.24, 0.008), glass)
	# 顶盖 + 小提环（座钟造型）
	_box(root, Vector3(0, 0.505, 0), Vector3(0.20, 0.03, 0.14), brass)
	_cyl(root, Vector3(0, 0.545, 0), 0.035, 0.010, brass, 12, "x")
	# 侧面转钮（拧它）
	_cyl(root, Vector3(0.145, 0.34, 0), 0.022, 0.030, brass, 12, "x")
	# 自发光：它自己在发一点冷光（"错的光"之一）
	glint = OmniLight3D.new()
	glint.position = Vector3(0, 0.36, 0.22)
	glint.light_color = Color(0.45, 0.62, 0.78)
	glint.light_energy = 0.42
	glint.omni_range = 1.6
	root.add_child(glint)
	# 刻度文字（23:40 这种）
	label_3d = Label3D.new()
	label_3d.text = _hhmm(int(START_MIN))
	label_3d.font = font
	label_3d.font_size = 40
	label_3d.pixel_size = 0.0016
	label_3d.position = Vector3(0, 0.60, 0.0)
	label_3d.modulate = Color(1.0, 0.86, 0.55)
	label_3d.shaded = false
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label_3d)

# ---------------------------------------------------------------- 走时 / 拧
func step(delta: float) -> void:
	if not running:
		return
	total_min += delta * SPEED
	_after_advance()

## 拧一下（拨快 10 分钟）
func turn_step(dir := 1.0) -> void:
	turn(TURN_STEP * dir)

func turn(minutes: float) -> void:
	total_min = maxf(0.0, total_min + minutes)
	print("[CLOCK] 拨到 ", _hhmm(int(START_MIN + total_min)))
	_after_advance()

func _after_advance() -> void:
	_update_hands()
	var m := int(START_MIN + total_min)
	# 逐分钟触发 tick
	tick.emit(total_min)
	# 里程碑
	for ms in MILESTONES:
		var id := String(ms["id"])
		if not fired.has(id) and total_min >= float(ms["at"]):
			fired[id] = true
			print("[CLOCK] 里程碑 ", id, " @ ", _hhmm(m))
			milestone.emit(id)

func _update_hands() -> void:
	if hand_min == null or hand_hour == null:
		return
	var m := START_MIN + total_min
	# 分针：一分钟 6°
	hand_min.rotation.z = -fmod(m, 60.0) * TAU / 60.0
	# 时针：12 小时一圈
	hand_hour.rotation.z = -fmod(m, 720.0) * TAU / 720.0
	if label_3d != null:
		label_3d.text = _hhmm(int(m))

func _hhmm(m: int) -> String:
	var mm := int(fmod(float(m), 24.0 * 60.0))
	return "%02d:%02d" % [mm / 60, mm % 60]

func time_text() -> String:
	return _hhmm(int(START_MIN + total_min))

# ---------------------------------------------------------------- 几何工厂（跟着 Node3D 自己建，不用 LaundryArt）
func _pbr(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func _plain(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.60, 0.70, 0.76, 0.18)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material,
		_rot := 0.0, _yawp := Vector2.ZERO, rad := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	if rad != 0.0:
		mi.rotation.z = rad
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material,
		seg := 12, axis := "y") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.position = pos
	if axis == "x": mi.rotation.z = PI * 0.5
	elif axis == "z": mi.rotation.x = PI * 0.5
	mi.material_override = mat
	parent.add_child(mi)
	return mi
