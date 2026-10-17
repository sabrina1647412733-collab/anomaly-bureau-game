extends CharacterBody3D
## 第一/第三人称控制器：走 / 跑 / 跳 / 蹲 / 坐 + 低模角色

const CharBody := preload("res://scripts/charbody.gd")
const SPEED_WALK := 3.2
const SPEED_RUN := 6.0
const SPEED_CROUCH := 1.5
const ACCEL := 12.0
const AIR_ACCEL := 3.0
const JUMP_SPEED := 5.6
const GRAV := 22.0
const KEY_TURN := 1.9
const EYE := 1.66
const EYE_CROUCH := 1.02
const EYE_SIT := 1.30
const COYOTE := 0.12
const PITCH_MAX := 1.45
const TP_DIST := 3.3
## 第二人称「监视器」机位：站内固定摄像机，镜头对着玩家
const CCTV := [
	{"pos": Vector3(-8.6, 4.35, -44.0), "name": "站台北段"},
	{"pos": Vector3(-8.6, 4.35, -20.0), "name": "站台中段"},
	{"pos": Vector3(-8.6, 4.35, 4.0), "name": "站台南段"},
	{"pos": Vector3(-8.6, 4.35, 28.0), "name": "信号室前"},
	{"pos": Vector3(-8.6, 4.35, 48.0), "name": "出口闸机"},
	{"pos": Vector3(-14.9, 3.05, 20.0), "name": "站台西侧"},
	{"pos": Vector3(11.0, 3.60, -95.0), "name": "岔区"},
	{"pos": Vector3(8.35, 0.62, -57.40), "name": "检修环线"},    # 原来挂在 (15.6,3.20,-60)：隧道顶板外 + 东墙外，切过去只看到一片黑（看图才发现）
]
const CCTV_FOV := 46.0
## 第二人称（对脸视角）：镜头在角色正前方看着他的眼睛
const FACE_DIST := 3.10
const FACE_LOOK_UP := -0.02
const TP_UP := 0.55

var mouse_sens := 0.0022
var cam: Camera3D
var flash: SpotLight3D
var cap: CapsuleShape3D
var cap_node: CollisionShape3D
var pitch := 0.0
var lock_look := false        # 截图脚本用：锁住鼠标转头，避免窗口鼠标事件把镜头带跑（游戏里恒为 false）
var can_move := true
var allow_capture := true
var cam_mode := 0          # 0 第一人称 / 1 第三人称 / 2 第二人称（正面看眼睛）/ 3 监视器
var cctv_i := 0
var _fov_before_cctv := 74.0
var _cam_before_review := 0
var crouching := false
var crouch_k := 0.0
var sitting := false
var air_time := 0.0
var coyote := 0.0
var jump_locked := false
var dip := 0.0
var head_bob := 0.0
var bob_amp := 0.0
var step_phase := 0.0
var walk_phase := 0.0
var body: Node3D
var view_arm: Node3D
var parts := {}
signal footstep(running)
signal landed(hard)

func _ready() -> void:
	cap_node = CollisionShape3D.new()
	cap = CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.72
	cap_node.shape = cap
	cap_node.position = Vector3(0, 0.86, 0)
	add_child(cap_node)

	cam = Camera3D.new()
	cam.position = Vector3(0, EYE, 0)
	cam.fov = 74.0
	cam.near = 0.05
	cam.far = 420.0
	add_child(cam)
	flash = SpotLight3D.new()
	flash.light_color = Color(0.85, 0.90, 1.0)
	flash.light_energy = 3.2
	flash.spot_range = 26.0
	flash.spot_angle = 33.0
	flash.spot_angle_attenuation = 1.1
	flash.spot_attenuation = 1.4
	flash.shadow_enabled = true
	flash.position = Vector3(0.20, -0.05, 0.0)
	cam.add_child(flash)

	_build_body()
	_build_viewarm()
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.35
	slide_on_ceiling = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ---------------------------------------------------------------- 角色模型
func _mesh_box(size: Vector3, col: Color, off: Vector3, emis := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emis
	mi.material_override = m
	mi.position = off
	return mi

func _mesh_cyl(size: Vector3, col: Color, off: Vector3, bot := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = size.x * 0.5
	cm.bottom_radius = size.x * 0.5 if bot <= 0.0 else bot
	cm.height = size.y
	cm.radial_segments = 10
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.80
	mi.material_override = m
	mi.position = off
	return mi

func _mesh_bevbox(size: Vector3, col: Color, off: Vector3, bev := 0.03, emis := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CharBody.bev_box(size, bev)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.80
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emis
	mi.material_override = m
	mi.position = off
	return mi
func _mesh_sphere(size: Vector3, col: Color, off: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5               # 单位球，靠 mi.scale 拉成椭球
	sm.height = 1.0
	sm.radial_segments = 8        # 8 段保持低多边形的棱面感，同时把直角磨掉
	sm.rings = 4
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.80
	mi.material_override = m
	mi.position = off
	mi.scale = size
	return mi
func _joint(nm: String, parent: Node3D, joint: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = joint
	parent.add_child(n)
	parts[nm] = n
	return n

func _build_body() -> void:
	# 配色取自选定的 A 方向概念图：藏青制服 + 琥珀反光背心 + 深灰长裤
	# 结构照《僵尸毁灭工程》3D 角色的做法重排：零件模块化 + 衣服叠穿。
	# 内层衬衫 / 外层制服 / 背心 / 背心肩带 / 袖口 / 口袋 / 腰带各是独立零件，
	# 以后想换装只改颜色和零件组合，不用再动一次几何。
	var coat := Color(0.14, 0.14, 0.24)
	var dark := Color(0.24, 0.24, 0.24)
	var vest := Color(0.80, 0.52, 0.14)
	var shirt := Color(0.62, 0.66, 0.70)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)

	var hip := _joint("hip", body, Vector3(0, 0.86, 0))
	var skin := Color(0.90, 0.71, 0.60)
	hip.add_child(_mesh_bevbox(Vector3(0.360, 0.200, 0.240), dark, Vector3(0, 0.0125, 0), 0.032))
	var torso := _joint("torso", body, Vector3(0, 0.94, 0))
	torso.add_child(_mesh_bevbox(Vector3(0.430, 0.430, 0.270), coat, Vector3(0, 0.215, 0), 0.042))
	# 内层：衬衫领口 + 前襟在背心下面露一条（叠穿的读法）
	torso.add_child(_mesh_box(Vector3(0.200, 0.046, 0.202), shirt, Vector3(0, 0.436, 0.004)))
	torso.add_child(_mesh_box(Vector3(0.062, 0.078, 0.022), shirt, Vector3(0, 0.428, -0.128)))
	torso.add_child(_mesh_box(Vector3(0.112, 0.140, 0.112), skin, Vector3(0, 0.465, 0)))   # 脖子：从领口里一直伸进下巴
	torso.add_child(_mesh_box(Vector3(0.300, 0.052, 0.246), coat, Vector3(0, 0.412, 0)))
	# 肩：以前是一块 0.14x0.08x0.16 的方盒子顶在肩角上，外面鼓出一块直角（很反人类）。
	# 现在换成 8 段低多边形椭球（三角肌），肩线从躯干顶自然滚下来接住上臂圆管。
	for sc in [-1.0, 1.0]:
		torso.add_child(_mesh_sphere(Vector3(0.186, 0.176, 0.210), coat, Vector3(sc * 0.235, 0.425, 0)))
	# 背心拆成胸 + 腰两段：胸 0.44 宽、腰收到 0.382 —— 直筒背心是「整个人像块板」的主因，原来是一根 0.44x0.44 到底。
	torso.add_child(_mesh_bevbox(Vector3(0.436, 0.250, 0.285), vest, Vector3(0, 0.305, 0), 0.034, 0.55))
	torso.add_child(_mesh_bevbox(Vector3(0.396, 0.185, 0.285), vest, Vector3(0, 0.095, 0), 0.030, 0.55))   # 反光背心（A 里是从胸到胯的长背心）
	torso.add_child(_mesh_box(Vector3(0.446, 0.045, 0.295), Color(0.89, 0.80, 0.33), Vector3(0, 0.36, 0), 0.9))
	torso.add_child(_mesh_box(Vector3(0.404, 0.045, 0.295), Color(0.89, 0.80, 0.33), Vector3(0, 0.13, 0), 0.9))
	# 背心的两条肩带盖过肩膀（原来只有胸口一块平板，肩上是空的）
	for sx in [-0.155, 0.155]:
		torso.add_child(_mesh_box(Vector3(0.098, 0.064, 0.298), vest, Vector3(sx, 0.450, 0.0), 0.55))
	# 背心口袋 + 深色袋口线
	for px in [-0.135, 0.135]:
		torso.add_child(_mesh_box(Vector3(0.125, 0.105, 0.020), vest.darkened(0.18), Vector3(px, 0.240, -0.152)))
		torso.add_child(_mesh_box(Vector3(0.128, 0.016, 0.024), vest.darkened(0.42), Vector3(px, 0.288, -0.154)))
	torso.add_child(_mesh_box(Vector3(0.404, 0.045, 0.280), dark, Vector3(0, 0.01, 0)))          # 腰带
	torso.add_child(_mesh_box(Vector3(0.052, 0.048, 0.020), Color(0.62, 0.60, 0.52), Vector3(0, 0.010, -0.142)))  # 腰带扣
	torso.add_child(_mesh_box(Vector3(0.10, 0.14, 0.02), vest, Vector3(0.11, 0.34, -0.15), 0.9))  # 工牌
	torso.add_child(_mesh_box(Vector3(0.38, 0.02, 0.02), dark, Vector3(0, 0.44, -0.13)))        # 挂绳
	torso.add_child(_mesh_box(Vector3(0.12, 0.14, 0.07), Color(0.30, 0.26, 0.20), Vector3(-0.15, 0.06, 0.15)))  # 工具腰包
	var head := _joint("head", body, Vector3(0, 1.46, 0))     # 抬高 2cm：给脖子留出可见的一段
	# 参考图那套「玩具人偶」头：偏宽、圆角大，五官是圆眼睛 + 小笑弧 + 腮红
	head.add_child(_mesh_bevbox(Vector3(0.215, 0.195, 0.210), skin, Vector3(0, 0.100, 0), 0.032))
	head.add_child(_mesh_bevbox(Vector3(0.218, 0.040, 0.214), Color(0.10, 0.09, 0.10), Vector3(0, 0.203, 0.012), 0.014))
	head.add_child(_mesh_bevbox(Vector3(0.204, 0.175, 0.040), Color(0.10, 0.09, 0.10), Vector3(0, 0.100, 0.104), 0.012))
	for hx in [-0.106, 0.106]:
		head.add_child(_mesh_bevbox(Vector3(0.028, 0.115, 0.190), Color(0.10, 0.09, 0.10), Vector3(hx, 0.140, 0.004), 0.010))
	for ex in [-0.108, 0.108]:
		head.add_child(_mesh_box(Vector3(0.018, 0.046, 0.032), skin.darkened(0.10), Vector3(ex, 0.095, 0.006)))
	# 眉：短、略向外挑
	for bx in [-0.052, 0.052]:
		var brow := _mesh_box(Vector3(0.040, 0.007, 0.012), Color(0.28, 0.21, 0.17), Vector3(bx, 0.150, -0.100))
		brow.rotation.z = -signf(bx) * 0.05
		head.add_child(brow)
	# 眼：圆眼球（白）+ 虹膜 + 高光，三层球，越靠前越小 —— 参考图里最抓人的就是这对圆眼
	for eye_x in [-0.050, 0.050]:
		head.add_child(_mesh_sphere(Vector3(0.042, 0.044, 0.024), Color(0.96, 0.96, 0.97), Vector3(eye_x, 0.110, -0.096)))
		head.add_child(_mesh_sphere(Vector3(0.020, 0.022, 0.014), Color(0.13, 0.11, 0.10), Vector3(eye_x, 0.109, -0.104)))
		head.add_child(_mesh_sphere(Vector3(0.008, 0.008, 0.006), Color(1.0, 1.0, 1.0), Vector3(eye_x - 0.004, 0.116, -0.110)))
	head.add_child(_mesh_box(Vector3(0.014, 0.016, 0.012), skin.darkened(0.14), Vector3(0, 0.084, -0.103)))
	# 嘴：三段小盒子拼一个上翘的笑弧（中间低、两头高）
	head.add_child(_mesh_box(Vector3(0.026, 0.004, 0.008), Color(0.34, 0.20, 0.19), Vector3(0, 0.052, -0.101)))
	for mx in [-0.013, 0.013]:
		var lip := _mesh_box(Vector3(0.012, 0.004, 0.008), Color(0.34, 0.20, 0.19), Vector3(mx, 0.0555, -0.101))
		lip.rotation.z = signf(mx) * 0.26
		head.add_child(lip)
	# 腮红：两片压扁的球
	for cx in [-0.072, 0.072]:
		head.add_child(_mesh_sphere(Vector3(0.022, 0.013, 0.008), Color(0.93, 0.60, 0.55), Vector3(cx, 0.078, -0.099)))
	head.add_child(_mesh_bevbox(Vector3(0.232, 0.081, 0.232), dark, Vector3(0, 0.235, 0), 0.016))          # 帽子
	head.add_child(_mesh_bevbox(Vector3(0.250, 0.028, 0.098), dark, Vector3(0, 0.208, -0.124), 0.012))      # 帽檐
	head.add_child(_mesh_box(Vector3(0.058, 0.028, 0.02), vest, Vector3(0, 0.185, -0.108), 0.6))  # 帽徽
	for sgn in [-1.0, 1.0]:
		var sfx := "L" if sgn < 0 else "R"
		var sh := _joint("shoulder" + sfx, body, Vector3(sgn * 0.25, 1.40, 0))
		sh.add_child(_mesh_cyl(Vector3(0.140, 0.44, 0.140), coat, Vector3(0, -0.22, 0), 0.058))          # 上臂（圆管）
		var el := _joint("elbow" + sfx, sh, Vector3(0, -0.42, 0))
		el.add_child(_mesh_cyl(Vector3(0.136, 0.022, 0.136), coat.darkened(0.18), Vector3(0, 0, 0)))   # 肘关节环（玩具人偶那种球窝）
		el.add_child(_mesh_cyl(Vector3(0.120, 0.34, 0.120), coat, Vector3(0, -0.17, 0), 0.044))          # 小臂
		el.add_child(_mesh_cyl(Vector3(0.108, 0.024, 0.108), shirt, Vector3(0, -0.268, 0)))        # 露出来的衬衫袖口
		el.add_child(_mesh_cyl(Vector3(0.116, 0.060, 0.116), coat.darkened(0.30), Vector3(0, -0.302, 0)))  # 制服袖口
		# 手：掌 + 四指 + 拇指（原来是一块 8.6x10.6x9.4cm 的皮肤色方块，像戴了拳击手套）
		el.add_child(_mesh_bevbox(Vector3(0.078, 0.080, 0.046), skin, Vector3(0, -0.390, -0.008), 0.008))
		for fi in range(4):
			var fx := -0.026 + float(fi) * 0.017
			el.add_child(_mesh_bevbox(Vector3(0.015, 0.052, 0.022), skin, Vector3(fx, -0.442, -0.008), 0.005))
		el.add_child(_mesh_bevbox(Vector3(0.020, 0.046, 0.024), skin, Vector3(-sgn * 0.046, -0.408, -0.020), 0.006))
		var hp := _joint("hip" + sfx, body, Vector3(sgn * 0.11, 0.84, 0))
		hp.add_child(_mesh_cyl(Vector3(0.192, 0.40, 0.192), dark, Vector3(0, -0.20, 0), 0.074))          # 大腿
		var kn := _joint("knee" + sfx, hp, Vector3(0, -0.40, 0))
		kn.add_child(_mesh_cyl(Vector3(0.174, 0.022, 0.174), dark.darkened(0.18), Vector3(0, 0, 0)))   # 膝关节环
		kn.add_child(_mesh_cyl(Vector3(0.164, 0.36, 0.164), dark, Vector3(0, -0.18, 0), 0.055))          # 小腿
		kn.add_child(_mesh_box(Vector3(0.124, 0.030, 0.134), dark.darkened(0.35), Vector3(0, -0.330, 0)))  # 裤脚
		var ft := _joint("foot" + sfx, kn, Vector3(0, -0.36, 0))
		ft.add_child(_mesh_bevbox(Vector3(0.166, 0.092, 0.300), Color(0.08, 0.09, 0.11), Vector3(0, -0.034, -0.055), 0.018))
	body.visible = false

func _build_viewarm() -> void:
	view_arm = Node3D.new()
	view_arm.name = "ViewArm"
	view_arm.position = Vector3(0.30, -0.335, -0.70)
	cam.add_child(view_arm)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.14, 0.24)
	mat.emission_enabled = true
	mat.emission = Color(0.14, 0.14, 0.24)
	mat.emission_energy_multiplier = 0.18
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.17, 0.18, 0.21)
	gmat.roughness = 0.85
	gmat.emission_enabled = true
	gmat.emission = Color(0.17, 0.18, 0.21)
	gmat.emission_energy_multiplier = 0.10
	var fore := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.050
	fm.bottom_radius = 0.062
	fm.height = 0.28
	fm.radial_segments = 10
	fore.mesh = fm
	fore.position = Vector3(0.010, -0.020, -0.115)
	fore.rotation.x = PI * 0.5
	fore.material_override = mat
	view_arm.add_child(fore)
	var hand := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.104, 0.096, 0.140)
	hand.mesh = hm
	hand.position = Vector3(0.012, -0.048, -0.40)
	hand.material_override = gmat
	view_arm.add_child(hand)
	var thumb := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.045, 0.050, 0.072)
	thumb.mesh = tm
	thumb.position = Vector3(-0.048, -0.030, -0.395)
	thumb.material_override = gmat
	view_arm.add_child(thumb)
	for fx in [-0.026, 0.0, 0.026]:
		var fg := MeshInstance3D.new()
		var ff := BoxMesh.new()
		ff.size = Vector3(0.024, 0.034, 0.070)
		fg.mesh = ff
		fg.position = Vector3(0.012 + fx, -0.048, -0.515)
		fg.material_override = gmat
		view_arm.add_child(fg)
	var cuff := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.072
	cc.bottom_radius = 0.072
	cc.height = 0.055
	cc.radial_segments = 10
	cuff.mesh = cc
	cuff.position = Vector3(0.010, -0.024, -0.262)
	cuff.rotation.x = PI * 0.5
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.80, 0.52, 0.14)
	cm.emission_enabled = true
	cm.emission = Color(0.80, 0.52, 0.14)
	cm.emission_energy_multiplier = 0.30
	cuff.material_override = cm
	view_arm.add_child(cuff)

func toggle_cam() -> void:
	var prev := cam_mode
	cam_mode = (cam_mode + 1) % 4
	if cam_mode == 3:
		_fov_before_cctv = cam.fov
		_pick_cctv()
		cam.fov = CCTV_FOV
	elif prev == 3:
		cam.fov = _fov_before_cctv
	body.visible = (cam_mode != 0)
	if view_arm != null:
		view_arm.visible = (cam_mode == 0 and not sitting)

## 挑离玩家最近的那台监视器
func _pick_cctv() -> void:
	var best := 0
	var bd := 1e9
	for i in range(CCTV.size()):
		var d: float = (CCTV[i]["pos"] as Vector3).distance_to(global_position)
		if d < bd:
			bd = d
			best = i
	cctv_i = best

## 由值班台进入监视器视角（M 键）；退出时回到进入前的视角
func enter_cctv() -> void:
	if cam_mode == 3:
		return
	_cam_before_review = cam_mode
	_fov_before_cctv = cam.fov
	cam_mode = 3
	_pick_cctv()
	cam.fov = CCTV_FOV
	body.visible = true
	if view_arm != null:
		view_arm.visible = false

func exit_cctv() -> void:
	if cam_mode != 3:
		return
	cam_mode = _cam_before_review
	cam.fov = _fov_before_cctv
	body.visible = (cam_mode != 0)
	if view_arm != null:
		view_arm.visible = (cam_mode == 0 and not sitting)

func next_cctv() -> void:
	if cam_mode != 3:
		return
	cctv_i = (cctv_i + 1) % CCTV.size()

func cctv_name() -> String:
	return String(CCTV[clampi(cctv_i, 0, CCTV.size() - 1)]["name"])

func cctv_tag() -> String:
	return "CAM %02d" % (clampi(cctv_i, 0, CCTV.size() - 1) + 1)

func sit_at(pos: Vector3, yaw: float) -> void:
	sitting = true
	can_move = false
	cap_node.disabled = true
	if view_arm != null:
		view_arm.visible = false          # 坐着时关掉碰撞，免得被椅子顶起来
	global_position = pos
	rotation.y = yaw
	velocity = Vector3.ZERO

func stand_up() -> void:
	sitting = false
	can_move = true
	cap_node.disabled = false
	global_position += Vector3(0, 0.12, 0)
	if view_arm != null:
		view_arm.visible = (cam_mode == 0)

func eye_height() -> float:
	var h := lerpf(EYE, EYE_CROUCH, crouch_k)
	if sitting:
		h = EYE_SIT
	return h

func eye() -> Vector3:
	if cam_mode != 0:
		return global_position + Vector3(0, eye_height() - 0.08, 0)   # 第三/第二人称仍用角色眼睛做交互判定
	return cam.global_position

func forward() -> Vector3:
	if cam_mode >= 2:
		return -global_transform.basis.z      # 第二/监视器视角：以角色自身朝向做交互判定
	return -cam.global_transform.basis.z

func look(delta_rot: Vector2) -> void:
	if lock_look:
		return
	rotate_y(-delta_rot.x * mouse_sens)
	pitch = clamp(pitch - delta_rot.y * mouse_sens, -PITCH_MAX, PITCH_MAX)
	if cam_mode == 0:
		cam.rotation.x = pitch
		if view_arm != null:
			view_arm.visible = not sitting
			view_arm.position = Vector3(0.26 + sin(head_bob) * 0.014 * bob_amp, -0.26 + cos(head_bob * 2.0) * 0.012 * bob_amp - dip * 0.6, -0.42)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or dragging:
			look(event.relative)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed and allow_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F:
			flash.visible = not flash.visible
		elif event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

var dragging := false

func _physics_process(delta: float) -> void:
	# 键盘转头
	var turn := 0.0
	var tilt := 0.0
	if can_move:
		if Input.is_physical_key_pressed(KEY_LEFT): turn += 1.0
		if Input.is_physical_key_pressed(KEY_RIGHT): turn -= 1.0
		if Input.is_physical_key_pressed(KEY_UP): tilt -= 1.0
		if Input.is_physical_key_pressed(KEY_DOWN): tilt += 1.0
		if Input.is_physical_key_pressed(KEY_Q): turn += 1.0
		if Input.is_physical_key_pressed(KEY_R): turn -= 1.0
	if turn != 0.0:
		rotate_y(turn * KEY_TURN * delta)
	if tilt != 0.0:
		pitch = clamp(pitch + tilt * KEY_TURN * 0.7 * delta, -PITCH_MAX, PITCH_MAX)
		if cam_mode == 0:
			cam.rotation.x = pitch
		if view_arm != null:
			view_arm.visible = not sitting
			view_arm.position = Vector3(0.26 + sin(head_bob) * 0.014 * bob_amp, -0.26 + cos(head_bob * 2.0) * 0.012 * bob_amp - dip * 0.6, -0.42)

	# 蹲下（按住 Ctrl 或 C）
	var want_crouch := false
	if can_move and not sitting:
		want_crouch = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C)
	crouching = want_crouch
	crouch_k = lerpf(crouch_k, 1.0 if crouching else 0.0, clampf(delta * 9.0, 0.0, 1.0))
	cap.height = lerpf(1.72, 1.10, crouch_k)
	cap_node.position.y = cap.height * 0.5

	if sitting and (Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_D)):
		stand_up()                       # 坐着时按方向键自动起身
	var target := Vector2.ZERO
	if can_move and not sitting:
		if Input.is_physical_key_pressed(KEY_W): target.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S): target.y += 1.0
		if Input.is_physical_key_pressed(KEY_A): target.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D): target.x += 1.0
	var running := Input.is_physical_key_pressed(KEY_SHIFT) and not crouching
	var speed := SPEED_RUN if running else (SPEED_CROUCH if crouching else SPEED_WALK)
	var wish := global_transform.basis * Vector3(target.x, 0.0, target.y)
	wish.y = 0.0
	if wish.length() > 0.001:
		wish = wish.normalized() * speed
	var acc := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, wish.x, acc * delta * 4.0)
	velocity.z = move_toward(velocity.z, wish.z, acc * delta * 4.0)

	if is_on_floor():
		air_time = 0.0
		coyote = COYOTE
	else:
		air_time += delta
		coyote = max(0.0, coyote - delta)
		velocity.y -= GRAV * delta

	if can_move and not sitting and Input.is_physical_key_pressed(KEY_SPACE):
		if coyote > 0.0 and not jump_locked:
			velocity.y = JUMP_SPEED
			coyote = 0.0
			jump_locked = true
	else:
		jump_locked = false

	var was_falling := velocity.y
	if sitting:
		velocity = Vector3.ZERO
	move_and_slide()
	if is_on_floor() and was_falling < -0.5:
		landed.emit(was_falling < -7.0)

	var planar := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and planar > 0.4:
		step_phase += delta * (planar * 1.9)
		if step_phase > PI:
			step_phase -= PI
			footstep.emit(running)
		bob_amp = lerp(bob_amp, 1.0, delta * 6.0)
	else:
		bob_amp = lerp(bob_amp, 0.0, delta * 6.0)
	head_bob += delta * planar * 2.0
	dip = lerp(dip, 0.0, delta * 7.0)
	_update_camera(delta, planar, running)
	_update_body(delta, planar)

func _update_camera(delta: float, planar: float, running: bool) -> void:
	var eh := eye_height()
	if cam_mode == 2:
		# 第二人称：站到角色正前方、眼睛高度，回头看他的眼睛；鼠标上下 = 绕着他上下看
		var eye_p := global_position + Vector3(0, eye_height() - 0.10, 0)
		var fwd := -global_transform.basis.z
		var right := global_transform.basis.x.normalized()
		var dir := fwd.rotated(right, -clampf(pitch, -1.15, 0.75))
		var want := eye_p + dir * FACE_DIST
		var sp := get_world_3d().direct_space_state
		var qf := PhysicsRayQueryParameters3D.create(eye_p, want)
		qf.exclude = [get_rid()]
		var hf: Dictionary = sp.intersect_ray(qf)
		if not hf.is_empty():
			want = hf["position"] + (eye_p - hf["position"]).normalized() * 0.24
		cam.global_position = want
		cam.look_at(eye_p + Vector3(0, FACE_LOOK_UP, 0), Vector3.UP)
	elif cam_mode == 3:
		var c: Dictionary = CCTV[clampi(cctv_i, 0, CCTV.size() - 1)]
		cam.global_position = c["pos"]
		cam.look_at(global_position + Vector3(0, (1.30 if sitting else 1.05), 0), Vector3.UP)
	elif cam_mode == 0:
		cam.position = Vector3(0, eh + sin(head_bob * 2.0) * 0.028 * bob_amp - dip, 0)
		cam.rotation = Vector3(pitch, 0.0, 0.0)
		# 跑动/蹲下时轻微侧倾
		cam.rotation.z = lerp(cam.rotation.z, sin(step_phase) * 0.012 * bob_amp * (1.6 if running else 1.0), delta * 8.0)
	else:
		var back := Vector3(0, TP_UP, TP_DIST)
		back = back.rotated(Vector3.RIGHT, pitch)
		var want_local := Vector3(0, eh - 0.10, 0) + back
		var from := global_transform * Vector3(0, eh - 0.10, 0)
		var to := global_transform * want_local
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			to = hit["position"] + (from - hit["position"]).normalized() * 0.28
		cam.global_position = to
		if cam.global_position.distance_to(from) > 0.06: cam.look_at(from + Vector3(0, 0.05, 0), Vector3.UP)

func _update_body(delta: float, planar: float) -> void:
	if body == null:
		return
	if sitting:
		# 坐姿：髋抬到「大腿底面正好落在座面上」（长椅座面顶 0.49、椅子 0.465），
		# 大腿略下倾 11.8°、小腿竖直，脚掌正好踩到地面（以前髋陷进座面、脚还悬空）。
		# 第一人称坐姿必须藏掉自己的头：相机会正好落在头部方块内部，不藏就是穿模。
		body.visible = true
		parts["head"].visible = (cam_mode != 0)
		parts["hip"].position = Vector3(0, 0.575, 0)
		parts["torso"].position = Vector3(0, 0.655, 0)
		parts["head"].position = Vector3(0, 1.155, 0)
		for sgn in ["L", "R"]:
			parts["shoulder" + sgn].position = Vector3((-0.25 if sgn == "L" else 0.25), 1.115, 0)
			parts["shoulder" + sgn].rotation = Vector3(0.35, 0, 0)
			parts["hip" + sgn].position = Vector3((-0.11 if sgn == "L" else 0.11), 0.575, 0)
			parts["hip" + sgn].rotation = Vector3(1.279, 0, 0)
			parts["knee" + sgn].rotation = Vector3(-1.279, 0, 0)
			parts["elbow" + sgn].rotation = Vector3(0.45, 0, 0)
		return
	body.visible = (cam_mode != 0)
	parts["head"].visible = (cam_mode != 0)
	var k := crouch_k
	parts["hip"].position = Vector3(0, 0.86 - 0.36 * k, 0)
	parts["torso"].position = Vector3(0, 0.94 - 0.36 * k, 0)
	parts["head"].position = Vector3(0, 1.44 - 0.36 * k, 0)
	var sw := sin(walk_phase) * clampf(planar / SPEED_WALK, 0.0, 1.4) * 0.62
	walk_phase += delta * (planar * 2.7 + 0.6)
	# 走路时整个人上下起伏 1.2cm（两步一个周期），配合肩胯摆动 —— 原来只有手臂在摆，躯干是平移过去的
	body.position.y = sin(walk_phase * 2.0) * 0.012 * clampf(planar / SPEED_WALK, 0.0, 1.2)
	for sgn in ["L", "R"]:
		var dir := 1.0 if sgn == "L" else -1.0
		parts["shoulder" + sgn].position = Vector3(dir * 0.27, 1.40 - 0.36 * k, 0)
		parts["shoulder" + sgn].rotation = Vector3(-sw * dir * 0.75 - 0.12 * k, 0, 0)
		parts["elbow" + sgn].rotation = Vector3(-0.25 - 0.35 * absf(sw) - 0.5 * k, 0, 0)
		parts["hip" + sgn].position = Vector3(dir * 0.11, 0.84 - 0.34 * k, 0)
		parts["hip" + sgn].rotation = Vector3(sw * dir - 0.85 * k, 0, 0)
		parts["knee" + sgn].rotation = Vector3(maxf(0.0, -sw * dir) + 1.45 * k, 0, 0)