extends Node3D
## 岚桥站 0017 —— 序章 + 四轮循环 + 三人 + 两个结局（按剧本-修订版）

const StationBuilder := preload("res://scripts/station.gd")
const Level := preload("res://scripts/level.gd")
const PlayerScript := preload("res://scripts/player.gd")
const TrainScript := preload("res://scripts/train.gd")
const HudMap := preload("res://scripts/hudmap.gd")
const MenuScript := preload("res://scripts/menu.gd")
const BagScript := preload("res://scripts/bag.gd")
const HotbarScript := preload("res://scripts/hotbar.gd")

const T_START := 1430.0
const T_TRAIN := 1456.0
const T_ARRIVE := 1457.0
const T_LOCK := 1456.7166
const SEC_PER_MIN := 6.0

const ROUND_NAMES := ["序章", "第 1 轮 · 那半秒", "第 2 轮 · 被剪掉的带子", "第 3 轮 · 还包的人", "第 4 轮 · 零点十七分"]

# 文字化线索（不再用 C0x）
const CLUES := ["红灯延迟记录", "倒放广播", "停用钥匙", "巡检簿", "五号继电器"]

var font: Font
var level
var builder
var player
var train
var env_node: WorldEnvironment
var hud: CanvasLayer
var hud_clock: Label
var hud_prompt: Label
var hud_sub: Label
var hud_sub_title: Label
var hud_end: Label
var hud_end_title: Label
var hud_fade: ColorRect
var hud_map
var clock_label: Label3D

var clock_min := T_START
var state := "play"            # play / cutscene / ending
var round := -1                # -1 序章, 0 林岚, 1 周砚, 2 陈默, 3 收束
var round_elapsed := 0.0       # 本轮现实流逝秒
var power := false
var sr_open := false
var handle := false
var late := false
var divert := false
var shown_end := ""
var end_t := 0.0
var items := []
var npcs := []
var buttons := []
var spots := []
var t_now := 0.0
var prompt: Variant = null
var sub := ""
var sub_cps := 26.0
var sub_time := 0.0
var dialog := []              # 当前对话队列
var dialog_idx := 0
var dialog_npc: Variant = null
var choice: Variant = null            # {text, key_a, label_a, key_b, label_b}
var chooser_a = null
var chooser_b = null
const SLOT_PATHS := ["user://save_1.json", "user://save_2.json", "user://save_3.json"]
var menu_layer: CanvasLayer
var menu
var ambient: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var sfx_click: AudioStreamWAV
var cutcam: Camera3D
var cut_t := 0.0
var train_started := false
var cut_phase := ""
var preview_center := Vector3.ZERO
var preview_r := 2.4
var preview_h := 0.42
var preview_base := 0.0
var bag_open := false
var bag
var hotbar
var bag_sel := 0
var doors := []
var safe_pos := Vector3(-15.05, 0.2, -12.90)
var safe_t := 0.0
var sig_red: MeshInstance3D = null
var sig_green: MeshInstance3D = null
var sig_light: OmniLight3D = null
var dv_said := false
var _dv_s0 := 0.0
var _dv_end_s := 0.0

var ITEM_DEFS := [
	{"id":"red","name":"红灯延迟记录","where":"控制台 · 旧继电器端口","desc":"旧继电器端口的打印条。红灯比它该亮的时间晚了半秒。","pos":Vector3(-16.60, 1.30, -13.60),"col":Color(0.83,0.34,0.31),"round":0},
	{"id":"tape","name":"倒放广播","where":"广播台 · 磁带机","desc":"把站内广播倒过来听，里面有一句被埋掉的话：「三道有人，改四道。」","pos":Vector3(-16.30, 1.30, -13.0),"col":Color(0.35,0.62,0.83),"round":1},
	{"id":"key","name":"停用钥匙","where":"隧道 · 检修环线","desc":"十七年前那把停用钥匙。系统早换了，锁还认它。","pos":Vector3(10.80, -0.10, -60.50),"col":Color(0.88,0.64,0.29),"round":2},
	{"id":"log","name":"巡检簿","where":"站台 · 长椅上","desc":"巡检簿被撕掉的一页。上面记着 00:16:43 那道手动进路。","pos":Vector3(-14.30, 1.02, 17.00),"col":Color(0.72,0.82,0.95),"round":2},
	{"id":"relay5","name":"五号继电器","where":"信号室 · 继电器柜","desc":"五号继电器的反馈慢半拍。隔离它，进路才锁得死。","pos":Vector3(-16.20, 1.50, 27.20),"col":Color(0.25,0.75,0.56),"round":3},
]

func _ready() -> void:
	_make_font()
	_make_env()
	_build_world()
	_spawn_player()
	_make_hud()
	_make_items()
	_make_doors()
	_make_npcs()
	_make_buttons()
	_make_switch_signal()
	train = TrainScript.new(self)
	train.reset()
	spots = [
		{"id":"power","pos":Vector3(-17.0, 1.35, -30.0),"r":2.8,"label":"扳下配电柜总闸"},
		{"id":"console","pos":Vector3(-16.6, 1.2, -14.0),"r":2.6,"label":"查看调度台"},
		{"id":"handle","pos":Vector3(-16.70, 1.35, 30.80),"r":2.7,"label":"总调度手柄"},
		{"id":"divert","pos":Vector3(7.7, -0.25, -112.4),"r":3.2,"label":"改环线 · 扳动道岔 1"},
	]
	for s in builder.seats:
		spots.append({"id":"seat", "pos": s["pos"] + Vector3(0, 0.55, 0), "r": 2.1, "label": "坐下", "seat": s})
	print("[0017] 可坐的位置 ", builder.seats.size(), " 个")
	_make_audio()
	_make_menu()
	_make_bag()
	train.lights_on(false)     # 预热：列车灯常驻但能量极低，先把着色器变体编译掉
	round = -2
	_start_round()
	_show_menu()
	print("[0017] 就绪 · 三角 ", builder.tri_count, " · 碰撞 ", builder.col_count, " · 灯 ", builder.lights.size())

func _make_font() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "sans-serif"])
	sf.allow_system_fallback = true
	font = sf

func _make_env() -> void:
	# —— 观感可调参数：改这两个数就能整体调亮暗 / 调泛光强度 ——
	const LOOK_EXPOSURE := 0.58      # 曝光：0.8 更暗更夜，1.2 更亮
	const LOOK_GLOW := 0.45          # 泛光强度：只让灯本身发光，不做梦幻感
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.027, 0.043, 0.063)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.52, 0.62, 0.78)
	e.ambient_light_energy = 0.18
	e.fog_enabled = false
	# —— 电影感调色（2026-10-16 观感升级）：ACES 色调映射让高光有滚降、泛光让灯带真的发光、SSAO 补角落接触阴影 ——
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = LOOK_EXPOSURE
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = LOOK_GLOW
	e.glow_strength = 1.0
	e.glow_bloom = 0.04
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.glow_hdr_threshold = 1.10
	e.glow_hdr_scale = 2.0
	e.set("glow_levels/1", 0.0)
	e.set("glow_levels/2", 0.25)
	e.set("glow_levels/3", 0.45)
	e.set("glow_levels/4", 0.60)
	var has_rd := RenderingServer.get_rendering_device() != null      # Compatibility(GLES3) 渲染器没有 SSAO
	e.ssao_enabled = has_rd
	if has_rd:
		e.ssao_radius = 0.8
		e.ssao_intensity = 1.1
		e.ssao_power = 1.4
		e.ssao_light_affect = 0.12
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.04
	e.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	env_node = we
	var dl := DirectionalLight3D.new()
	dl.light_color = Color(0.55, 0.65, 0.9)
	dl.light_energy = 0.06
	dl.rotation_degrees = Vector3(-52, 18, 0)
	add_child(dl)

func _build_world() -> void:
	builder = StationBuilder.new(self)
	builder.font = font
	level = Level.new()
	level.b = builder
	level.font = font
	level.build()
	builder.commit()
	clock_label = builder.label3d("23:50", Vector3(-4.40, 3.63, -2.0), 0.30, Color(0.88, 0.64, 0.29), PI * 0.5)
	clock_label.outline_size = 10

func _spawn_player() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	player.position = Vector3(-15.05, 0.15, -12.90)
	player.rotation.y = PI * 0.5
	add_child(player)
	player.landed.connect(_on_land)

func _on_land(hard: bool) -> void:
	if hard:
		player.dip = 0.18

func _make_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var dot := ColorRect.new(); dot.color = Color(0.88,0.64,0.29,0.85); dot.position = Vector2(799, 449); dot.size = Vector2(3,3)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot)
	hud_clock = _label(root, 0, Vector2(690, 14), Vector2(220, 56), 42, Color(0.88,0.64,0.29))
	hud_sub_title = _label(root, 0, Vector2(340, 686), Vector2(920, 22), 13, Color(0.35,0.62,0.83))
	hud_sub = _label(root, 0, Vector2(240, 708), Vector2(1120, 72), 19, Color(0.92,0.95,0.98))
	hud_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_prompt = _label(root, 0, Vector2(480, 492), Vector2(640, 30), 17, Color(0.88,0.64,0.29))
	hud_end = _label(root, 0, Vector2(340, 420), Vector2(920, 260), 20, Color(0.86,0.90,0.95))
	hud_end.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_end_title = _label(root, 0, Vector2(340, 320), Vector2(920, 80), 46, Color(0.88,0.64,0.29))
	hud_end.text = ""
	hud_end_title.text = ""
	hud_fade = ColorRect.new()
	hud_fade.color = Color(0, 0, 0, 1)
	hud_fade.position = Vector2.ZERO
	hud_fade.size = Vector2(1600, 900)
	hud_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_fade.modulate.a = 0.0
	root.add_child(hud_fade)
	hud_map = HudMap.new()
	hud_map.font = font
	hud_map.player_node = player
	hud_map.position = Vector2(1224, 16)
	hud_map.size = Vector2(360, 436)
	root.add_child(hud_map)

func _label(parent: Control, preset: int, pos: Vector2, size: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = fs
	l.theme = th
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.size = size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _make_items() -> void:
	for d in ITEM_DEFS:
		var n := Node3D.new()
		n.position = d["pos"]
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.18; sm.height = 0.36; sm.radial_segments = 4; sm.rings = 2
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = d["col"]
		m.emission_enabled = true
		m.emission = d["col"]
		m.emission_energy_multiplier = 2.2
		mi.material_override = m
		n.add_child(mi)
		var ol := OmniLight3D.new()
		ol.light_color = d["col"]; ol.light_energy = 1.2; ol.omni_range = 4.5; ol.shadow_enabled = false
		n.add_child(ol)
		add_child(n)
		n.visible = false
		items.append({"def": d, "node": n, "mesh": mi, "got": false})

func _make_doors() -> void:
	doors.clear()
	_add_door("信号室门", Vector3(-14.19, 0.02, 27.02), Vector3(-14.07, 2.26, 29.58), Vector3(0, 0, 2.72), Vector3(-14.1, 1.55, 28.30), false)
	_add_door("检修笼门", Vector3(-16.24, 0.02, -36.88), Vector3(-16.12, 2.16, -35.12), Vector3(0, 2.14, 0), Vector3(-16.14, 1.55, -36.00), true)
	_add_door("值班室门", Vector3(-10.99, 0.02, 7.60), Vector3(-10.87, 2.64, 9.60), Vector3(0, 0, 2.04), Vector3(-10.9, 1.55, 8.60), false)
	_add_door("广播台门", Vector3(-11.49, 0.02, 37.60), Vector3(-11.37, 2.64, 39.60), Vector3(0, 0, 2.04), Vector3(-11.4, 1.55, 38.60), false)
	var d3 := StationBuilder.new(self)
	d3.box("hazard", Vector3(-17.04, 0.12, -30.05), Vector3(-16.94, 0.70, -29.95), false)
	d3.commit(); d3.mesh_inst.name = "PowerLever"
	var d4 := StationBuilder.new(self)
	d4.box("metalD", Vector3(-16.74, 1.08, 30.70), Vector3(-16.66, 1.72, 30.90), false)
	d4.box("red", Vector3(-16.78, 1.66, 30.66), Vector3(-16.62, 1.80, 30.94), false)
	d4.commit(); d4.mesh_inst.name = "DispatchHandle"
	set_meta("lever", d3.mesh_inst); set_meta("handle", d4.mesh_inst)

func _add_door(nm: String, mn: Vector3, mx: Vector3, slide: Vector3, spot: Vector3, needs_power: bool) -> void:
	var n := Node3D.new()
	n.name = nm
	n.set_meta("closed", Vector3.ZERO)
	add_child(n)
	var d := StationBuilder.new(n)
	d.box("metalD", mn, mx, false)
	# 警示条比门板大 5mm，避免共面导致的深度冲突闪烁
	d.box("hazard", Vector3(mn.x - 0.005, mn.y, mn.z - 0.005), Vector3(mx.x + 0.005, mn.y + 0.22, mx.z + 0.005), false)
	d.commit()
	d.add_collider(mn - Vector3(0.05, 0.02, 0.05), mx + Vector3(0.05, 0.02, 0.05))
	doors.append({"name": nm, "node": n, "slide": slide, "open": false, "needs_power": needs_power, "spot": spot, "r": 2.7})

func _toggle_door(d: Dictionary) -> void:
	if bool(d["needs_power"]) and not power:
		_say("旁白", "门锁着。先去配电柜合闸。")
		return
	d["open"] = not bool(d["open"])
	play_click()
	_cost(4)
	_say("旁白", ("关上了 " if not bool(d["open"]) else "推开了 ") + str(d["name"]) + "。")
func _make_npcs() -> void:
	npcs = [
		_npc("林岚", Vector3(-13.9, 0, 28.2), Color(0.35,0.62,0.83), 0),
		_npc("周砚", Vector3(-6.0, 0, 42.0), Color(0.88,0.64,0.29), 1),
		_npc("陈默", Vector3(-0.8, 0, -53.0), Color(0.25,0.75,0.56), 2),
	]

func _npc(nm: String, pos: Vector3, accent: Color, show_round: int) -> Dictionary:
	var n := Node3D.new()
	n.position = pos
	# 配色直接取自选定的 A 方向概念图（_预览/角色概念/A_低多边形极简.png）：
	# 皮肤 #e4b49c / 藏青制服 #24243c / 深灰长裤 #3c3c3c / 青蓝工作服 #24546c /
	# 棕色大衣 #6c3c24 / 灰绿夹克 #305030 / 琥珀背心 #cc8424 + 亮黄条 #e4cc54
	var skin := Color(0.90, 0.71, 0.60)
	var cloth := Color(0.14, 0.14, 0.24)
	var cloth2 := Color(0.24, 0.24, 0.24)
	var hair := Color(0.05, 0.05, 0.06)
	var cap_on := false
	var long_coat := false
	match nm:
		"林岚":
			cloth = Color(0.14, 0.33, 0.42)       # 青蓝工作服
			cloth2 = Color(0.24, 0.24, 0.24)      # 灰长裤
			hair = Color(0.05, 0.05, 0.14)
			n.rotation.y = -PI * 0.5              # 站在信号室门口，面朝站台（+X）
		"周砚":
			cloth = Color(0.42, 0.24, 0.14)       # 棕色大衣
			cloth2 = Color(0.06, 0.06, 0.06)      # 近黑长裤
			long_coat = true                      # A 里他穿及膝长大衣
			n.rotation.y = 0.0                    # 站台南头，面朝北（-Z）
		"陈默":
			cloth = Color(0.23, 0.26, 0.23)       # 灰绿夹克
			cloth2 = Color(0.14, 0.14, 0.14)      # 近黑长裤
			hair = Color(0.14, 0.24, 0.24)        # 帽子 / 发（青灰）
			cap_on = true
			n.rotation.y = PI                     # 北隧道口，面朝站台（+Z）
	# 头 / 发 / 帽 / 眼
	_part(n, "head", Vector3(0, 1.60, 0), Vector3(0.21, 0.23, 0.20), skin)
	_part(n, "hair", Vector3(0, 1.705, -0.01), Vector3(0.235, 0.075, 0.225), hair)
	if cap_on:
		_part(n, "cap", Vector3(0, 1.740, 0), Vector3(0.245, 0.055, 0.235), cloth2)
		_part(n, "visor", Vector3(0, 1.718, -0.155), Vector3(0.235, 0.030, 0.110), cloth2)
	else:
		_part(n, "hairback", Vector3(0, 1.575, 0.098), Vector3(0.215, 0.215, 0.045), hair)
	for ex in [-0.055, 0.055]:
		_part(n, "eye", Vector3(ex, 1.617, -0.104), Vector3(0.045, 0.026, 0.020), Color(0.06, 0.06, 0.07))
	# 躯干 / 领口 / 工牌
	_part(n, "torso", Vector3(0, 1.26, 0), Vector3(0.40, 0.46, 0.24), cloth)
	_part(n, "collar", Vector3(0, 1.470, 0), Vector3(0.30, 0.065, 0.215), cloth2)
	_part(n, "badge", Vector3(0.10, 1.345, -0.132), Vector3(0.055, 0.075, 0.016), accent, 1.6)
	_part(n, "belt", Vector3(0, 1.010, 0), Vector3(0.35, 0.065, 0.25), cloth2)
	# 四肢：圆管（比方块更像人）
	for sgn in [-1.0, 1.0]:
		var sfx := "L" if sgn < 0 else "R"
		# 腿分大小腿：髋 0.995 → 膝 0.545 → 脚踝 0.09 → 鞋底正好 0.00（原来鞋在 0.26，三个人是悬空的）
		_part(n, "leg" + sfx, Vector3(sgn * 0.105, 0.770, 0), Vector3(0.155, 0.45, 0.165), cloth2, 0.0, true)
		_part(n, "shin" + sfx, Vector3(sgn * 0.105, 0.3175, 0), Vector3(0.140, 0.455, 0.150), cloth2, 0.0, true)
		_part(n, "shoe" + sfx, Vector3(sgn * 0.105, 0.045, -0.035), Vector3(0.155, 0.09, 0.26), Color(0.07, 0.07, 0.08))
		_part(n, "armU" + sfx, Vector3(sgn * 0.245, 1.305, 0), Vector3(0.115, 0.33, 0.125), cloth, 0.0, true)
		_part(n, "armL" + sfx, Vector3(sgn * 0.255, 0.985, -0.030), Vector3(0.100, 0.31, 0.110), cloth, 0.0, true)
		_part(n, "hand" + sfx, Vector3(sgn * 0.255, 0.790, -0.050), Vector3(0.095, 0.120, 0.100), skin)
	# 及膝长大衣下摆（挂在躯干节点上；下摆底 0.60，大腿在这个深度只摆 ±0.15，包得住）
	if long_coat:
		_part(n, "coatSkirt", Vector3(0, 0.735, 0), Vector3(0.46, 0.27, 0.30), cloth)
		_part(n, "coatHem", Vector3(0, 0.612, 0), Vector3(0.475, 0.055, 0.315), Color(0.30, 0.17, 0.10))
		_part(n, "coatBackSlit", Vector3(0, 0.72, 0.152), Vector3(0.30, 0.22, 0.012), Color(0.05, 0.05, 0.05))
	# 每人的随身物（区分剪影）
	match nm:
		"林岚":
			_part(n, "case", Vector3(-0.345, 0.740, -0.02), Vector3(0.20, 0.16, 0.34), Color(0.55, 0.34, 0.16))
			_part(n, "caseLid", Vector3(-0.345, 0.830, -0.02), Vector3(0.17, 0.03, 0.30), Color(0.30, 0.32, 0.34))
		"周砚":
			_part(n, "muff", Vector3(-0.310, 1.020, -0.02), Vector3(0.19, 0.16, 0.24), Color(0.10, 0.10, 0.12))
			_part(n, "headband", Vector3(0, 1.455, 0.010), Vector3(0.345, 0.045, 0.255), Color(0.10, 0.10, 0.12))
		"陈默":
			_part(n, "brief", Vector3(-0.335, 0.700, -0.02), Vector3(0.22, 0.24, 0.10), Color(0.17, 0.13, 0.10))
			_part(n, "briefLid", Vector3(-0.335, 0.830, -0.02), Vector3(0.19, 0.03, 0.06), Color(0.35, 0.30, 0.20))
	var key := OmniLight3D.new()
	key.position = Vector3(0.5, 1.5, 0.6)
	key.light_color = Color(0.75, 0.82, 0.95)
	key.light_energy = 2.2
	key.omni_range = 4.5
	key.shadow_enabled = false
	n.add_child(key)
	var lbl := Label3D.new()
	lbl.font = font
	lbl.text = nm
	lbl.font_size = 96
	lbl.pixel_size = 0.30 / 96.0 * 2.2
	lbl.modulate = accent
	lbl.outline_size = 8
	lbl.position = Vector3(0, 2.12, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.add_child(lbl)
	add_child(n)
	n.visible = false
	return {"name": nm, "node": n, "accent": accent, "show_round": show_round, "label": lbl}

func _part(parent: Node3D, nm: String, p: Vector3, size: Vector3, col: Color,
		emis := 0.0, tube := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	if tube:
		var cm := CylinderMesh.new()
		cm.top_radius = size.x * 0.5
		cm.bottom_radius = size.x * 0.5
		cm.height = size.y
		cm.radial_segments = 8
		mi.mesh = cm
	else:
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.78
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emis
	mi.material_override = m
	mi.position = p
	parent.add_child(mi)
	return mi

func _make_buttons() -> void:
	# 序章控制台：三个能按的钮
	var defs := [
		["确认进路 · 0017 进二道", Vector3(-16.42, 0.93, -13.1)],
		["签值班簿", Vector3(-16.42, 0.93, -14.0)],
		["交接班确认", Vector3(-16.42, 0.93, -14.9)],
	]
	for d in defs:
		var n := Node3D.new()
		n.position = d[1]
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new(); box.size = Vector3(0.08, 0.16, 0.30)
		mi.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.10, 0.16, 0.22)
		m.emission_enabled = true; m.emission = Color(0.35, 0.62, 0.83); m.emission_energy_multiplier = 0.6
		mi.material_override = m
		n.add_child(mi)
		add_child(n)
		buttons.append({"label": d[0], "node": n, "mesh": mi, "mat": m, "done": false})

func _start_round() -> void:
	round += 1
	round_elapsed = 0.0
	clock_min = T_START
	train_started = false
	_set_switch_green(divert)
	train.reset()
	state = "play"
	player.position = Vector3(-15.05, 0.15, -12.90)
	player.rotation.y = PI * 0.5
	player.velocity = Vector3.ZERO
	_restore_player_cam()      # 释放过场机位、交还控制权
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_fade_to(0.0, 1.2)
	# 人物出现
	for np in npcs:
		np["node"].visible = (np["show_round"] >= 0 and np["show_round"] <= round)
	# 物品出现
	for it in items:
		it["node"].visible = (int(it["def"]["round"]) <= round and not it["got"])
	# 序章
	if round == -1:
		_say("站内广播", "23:50。岚桥站最后一班车即将进站。……你接管夜班调度席。0017 次，进二道。")
		_say("旁白", "按流程做完交接：确认进路，签值班簿，然后等车。")
	elif round == 0:
		_say("旁白", "23:50。还是那个时间。你确定没有听错——广播里那句「按调度席指令执行」，说的是你。")
		_say("旁白", "站台上只有一个人没有在等车。她拎着一个工具盒，站在信号室门口。")
	elif round == 1:
		_say("旁白", "23:50。纸上的字还在，别的东西都回到原位。站台另一头，多了一个拎着录音笔的男人。")
	elif round == 2:
		_say("旁白", "23:50。三个人现在都有了模糊的熟悉感——他们不记得循环，但记得你。")
	else:
		_say("旁白", "23:50。最后一次。0017 次已经在进站信号里。你只有这 27 分钟。")

func _process(delta: float) -> void:
	t_now += delta
	if state == "play":
		round_elapsed += delta
		clock_min += delta / SEC_PER_MIN
		_check_scripted()
		if clock_min >= T_ARRIVE:
			_begin_cutscene()
	elif state == "cutscene":
		_cutscene(delta)
	_animate_doors(delta)
	_animate_items(delta)
	_update_interaction()
	_update_hud()
	_update_map()
	_update_sub(delta)

func _check_scripted() -> void:
	if not train_started and clock_min >= T_TRAIN:
		train_started = true
		_say("旁白", "隧道里有光。它来了。")
	if clock_min >= 1452.0 and not _once("warn"):
		_say("站内广播", "0017 次，岚桥站呼叫。前方四道占用，立即停车，等待人工引导。站台乘客请后退至黄线内。")

var _once_flags := {}
func _once(k: String) -> bool:
	if _once_flags.has(k):
		return true
	_once_flags[k] = true
	return false

# ------------------------------------------------------------------ 过场
const CUT_POS := Vector3(-4.5, 2.30, 14.0)
const CUT_LOOK := Vector3(4.6, 1.35, 1.0)

func _begin_cutscene() -> void:
	state = "cutscene"
	cut_phase = "out"
	cut_t = 0.0
	train_started = true
	player.can_move = false
	player.dragging = false
	_say("旁白", "")

func _cutscene(delta: float) -> void:
	cut_t += delta
	match cut_phase:
		"out":
			hud_fade.modulate.a = clampf(cut_t / 0.28, 0.0, 1.0)
			if cut_t >= 0.34:
				if cutcam == null:
					cutcam = Camera3D.new()
					cutcam.fov = 62.0
					cutcam.near = 0.05
					cutcam.far = 420.0
					add_child(cutcam)
				cutcam.position = CUT_POS
				cutcam.look_at(CUT_LOOK)
				cutcam.current = true
				train.reset()
				train.lights_on(true)
				cut_phase = "pass"
				cut_t = 0.0
		"pass":
			var p := clampf(cut_t / 2.9, 0.0, 1.0)
			train.place(train.s_at_z(-200.0) + 310.0 * pow(p, 1.15))
			hud_fade.modulate.a = clampf(1.0 - cut_t / 0.32, 0.0, 1.0)
			if cut_t >= 3.15:
				cut_phase = "end"
				cut_t = 0.0
		"end":
			hud_fade.modulate.a = clampf(cut_t / 0.36, 0.0, 1.0)
			if cut_t >= 0.42:
				cut_phase = ""
				_after_cutscene()
		"preview":
			# 小角度弧线：只轻轻划过 ±26°，不是绕圈
			var k := clampf(cut_t / 3.6, 0.0, 1.0)
			var ang := preview_base + (k - 0.5) * 0.9
			cutcam.position = preview_center + Vector3(cos(ang) * preview_r, preview_h, sin(ang) * preview_r)
			cutcam.look_at(preview_center + Vector3(0, 0.05, 0))
			hud_fade.modulate.a = clampf(1.0 - cut_t / 0.45, 0.0, 1.0)
			if cut_t >= 3.6:
				cut_phase = "out2"
				cut_t = 0.0
		"dv_out":
			hud_fade.modulate.a = 1.0
			if cut_t >= 0.55:
				if cutcam == null:
					cutcam = Camera3D.new()
					cutcam.fov = 62.0
					cutcam.near = 0.05
					cutcam.far = 420.0
					add_child(cutcam)
				cutcam.position = Vector3(16.6, 3.40, -78.0)
				cutcam.look_at(Vector3(6.0, 0.8, -104.0))
				cutcam.current = true
				train.set_divert(true)
				train.place(_dv_s0)
				train.lights_on(true)
				cut_phase = "dv_run"
				cut_t = 0.0
		"dv_run":
			var t01 := clampf(cut_t / 9.0, 0.0, 1.0)
			var ee := t01 * t01 * (3.0 - 2.0 * t01)
			hud_fade.modulate.a = clampf(1.0 - cut_t / 0.5, 0.0, 1.0)
			train.place(_dv_s0 + ee * (_dv_end_s - _dv_s0))
			cutcam.position = Vector3(16.6, 3.40, -78.0).lerp(Vector3(16.2, 3.40, -84.0), ee)
			cutcam.look_at(Vector3(6.0, 0.8, -104.0).lerp(Vector3(13.0, 0.6, -66.0), ee))
			if not dv_said and cut_t > 4.4:
				dv_said = true
				_say("站内广播", "0017 次，岚桥站呼叫。进路已变更，改走检修环线。")
			if cut_t >= 9.2:
				cut_phase = "dv_end"
				cut_t = 0.0
		"dv_end":
			hud_fade.modulate.a = clampf(cut_t / 0.7, 0.0, 1.0)
			if cut_t >= 0.85:
				cut_phase = ""
				train.lights_on(false)
				_show_end("B")
		"out2":
			hud_fade.modulate.a = clampf(cut_t / 0.35, 0.0, 1.0)
			if cut_t >= 0.42:
				cut_phase = ""
				_end_hook()

func _preview_setup() -> void:
	preview_h = 0.42
	match round:
		-1:                                   # 林岚（信号室门口）：从站台一侧看过去
			preview_center = Vector3(-13.9, 1.15, 28.2)
			preview_r = 5.0
			preview_base = 0.20
			_show_npc("林岚")
		0:                                    # 周砚（站台南头）
			preview_center = Vector3(-6.0, 1.15, 42.0)
			preview_r = 5.0
			preview_base = 0.15
			_show_npc("周砚")
		1:                                    # 陈默（北隧道口）：从站台这侧往轨道方向看
			preview_center = Vector3(-0.8, 1.15, -53.0)
			preview_r = 5.0
			preview_base = PI - 0.20
			_show_npc("陈默")
		_:
			preview_center = Vector3(-14.9, 1.35, 28.3)
			preview_r = 4.0
			preview_base = 0.25

func _show_npc(nm: String) -> void:
	for np in npcs:
		if String(np["name"]) == nm:
			np["node"].visible = true

func _restore_player_cam() -> void:
	if cutcam != null:
		cutcam.current = false
		cutcam.queue_free()
		cutcam = null
	player.can_move = true
	player.velocity = Vector3.ZERO
	player.allow_capture = true
	player.cam.current = true
	train.lights_on(false)
	train.reset()

func _after_cutscene() -> void:
	var hook := ""
	if round == -1:
		hook = "列车没有停。它驶进了废弃四道。\n……已按调度席指令执行。\n\n0017 次　位置未知"
	elif round == 0:
		hook = "00:17。0017 次没有进站。\n屏幕只留下一行灰字：列车位置未知。\n\n「又是半秒。和十七年前一模一样。」——林岚"
	elif round == 1:
		hook = "把带子倒过来，里面是一句被埋掉的话：\n「三道有人，改四道。」\n\n可官方报告写着——三道无人。"
	elif round == 2:
		hook = "「三道有人。不是车，是人。」\n他救了人，可十九个人还是没出来——中间少了什么？"
	if round >= 3:
		_restore_player_cam()
		if divert:
			_begin_divert_end()
		else:
			_resolve_final()
		return
	_preview_setup()
	cut_phase = "preview"
	cut_t = 0.0
	_show_hook(hook)

func _show_hook(text: String) -> void:
	hud_end_title.text = ""
	hud_end.text = text
	hud_end.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
	hud_end.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(hud_end, "modulate:a", 1.0, 0.5)
func _resolve_final() -> void:
	state = "ending"
	if handle and not late:
		_show_final_choice()
	else:
		_show_end("B")

func _show_final_choice() -> void:
	_fade_to(0.0, 0.7)
	hud_end_title.text = "最后的决定"
	hud_end.text = "列车停住了。天亮之前，只剩一件事要你决定。\n\n记录是公开，还是封存？\n\n[E] 公开真相　　[R] 封存"
	hud_end.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	choice = {"key_a": KEY_E, "key_b": KEY_R}
	chooser_a = "A"
	chooser_b = "B"

func _end_hook() -> void:
	hud_end.text = ""
	hud_end.modulate.a = 1.0
	_once_flags.clear()
	_start_round()

func _skip_cutscene() -> void:
	match cut_phase:
		"dv_out", "dv_run":
			cut_phase = "dv_end"
			cut_t = 0.0
		"out", "pass":
			cut_phase = "end"
			cut_t = 0.5
		"end":
			cut_t = 0.5
		"preview":
			cut_phase = "out2"
			cut_t = 0.5
		"dv_out":
			hud_fade.modulate.a = clampf(cut_t / 0.45, 0.0, 1.0)
			if cut_t >= 0.55:
				if cutcam == null:
					cutcam = Camera3D.new()
					cutcam.fov = 62.0
					cutcam.near = 0.05
					cutcam.far = 420.0
					add_child(cutcam)
				cutcam.position = Vector3(16.6, 3.40, -78.0)
				cutcam.look_at(Vector3(6.0, 0.8, -104.0))
				cutcam.current = true
				train.set_divert(true)
				train.place(_dv_s0)
				train.lights_on(true)
				cut_phase = "dv_run"
				cut_t = 0.0
		"dv_run":
			var t01 := clampf(cut_t / 9.0, 0.0, 1.0)
			var ee := t01 * t01 * (3.0 - 2.0 * t01)
			hud_fade.modulate.a = clampf(1.0 - cut_t / 0.5, 0.0, 1.0)
			train.place(_dv_s0 + ee * (_dv_end_s - _dv_s0))
			cutcam.position = Vector3(16.6, 3.40, -78.0).lerp(Vector3(16.2, 3.40, -84.0), ee)
			cutcam.look_at(Vector3(6.0, 0.8, -104.0).lerp(Vector3(13.0, 0.6, -66.0), ee))
			if not dv_said and cut_t > 4.4:
				dv_said = true
				_say("站内广播", "0017 次，岚桥站呼叫。进路已变更，改走检修环线。")
			if cut_t >= 9.2:
				cut_phase = "dv_end"
				cut_t = 0.0
		"dv_end":
			hud_fade.modulate.a = clampf(cut_t / 0.7, 0.0, 1.0)
			if cut_t >= 0.85:
				cut_phase = ""
				train.lights_on(false)
				_show_end("B")
		"out2":
			cut_t = 0.5
		_:
			pass

func _show_end(kind: String) -> void:
	_fade_to(0.0, 0.7)
	shown_end = kind
	state = "ending"
	hud_end_title.add_theme_color_override("font_color", Color(0.88, 0.64, 0.29))
	if kind == "A":
		hud_end_title.text = "结局 A · 零点之后"
		hud_end.text = "00:16:43，手动进路被取消。\n00:17，工程车与三道隔离。0017 在二道停稳，车门没有打开。\n\n「本次列车暂停服务。今晚的延误不是故障，是一份迟到了十七年的记录。」\n\n第二天，林远舟的名字从事故责任人一栏移出。\n周砚重录了那期节目，开头第一次没有配乐。\n陈默走进调查室时，把停用钥匙放在了桌上。"
	else:
		hud_end_title.text = "结局 B · 最后一班"
		hud_end.text = "00:16:50，0017 被手动送进检修环线。空工程车驶入四道。\n\n「设备故障已排除，0017 次取消运行。请乘客改乘接驳车辆，感谢配合。」\n\n没有人伤亡。公开通报没有出现任何人的名字。\n陈默把钥匙留在失物招领柜，周砚删掉了录音。\n林岚在清晨第一班车前重新校准五号继电器，像什么都没发生过。"
	hud_end.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(hud_end, "modulate:a", 1.0, 0.8)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player != null:
		player.allow_capture = false

# ------------------------------------------------------------------ 对话 / 交互
func _interact() -> void:
	if state == "ending":
		if choice != null:
			if Input.is_physical_key_pressed(KEY_E):
				_show_end(chooser_a); choice = null
			elif Input.is_physical_key_pressed(KEY_R):
				_show_end(chooser_b); choice = null
		return
	if choice != null:
		if Input.is_physical_key_pressed(KEY_E):
			choice = null; _resolve_choice(true)
		elif Input.is_physical_key_pressed(KEY_R):
			choice = null; _resolve_choice(false)
		return
	if dialog.size() > 0:
		dialog_idx += 1
		_advance_dialog()
		return
	if prompt == null:
		return
	if prompt["kind"] == "stand":
		player.stand_up()
		_say("旁白", "你站了起来。")
		return
	if prompt["kind"] == "item":
		_pickup(prompt["it"])
	elif prompt["kind"] == "npc":
		_talk(prompt["npc"])
	elif prompt["kind"] == "button":
		_press_button(prompt["idx"])
	elif prompt["kind"] == "door":
		_toggle_door(prompt["door"])
	else:
		_act(prompt["id"])

func _resolve_choice(allow: bool) -> void:
	if chooser_a == "A":
		if allow:
			_give_clue(0)
			_say("林岚", "工牌划过端口的一瞬间，红灯迟了半秒才亮。")
			_say("旁白", "获得「红灯延迟记录」。")
		else:
			_say("林岚", "你最好记住这半秒。")
			dialog_npc["said"] = false

func _give_clue(idx: int) -> void:
	var it: Dictionary = items[idx]
	it["got"] = true
	it["node"].visible = false
	print("[0017] 获得 ", it["def"]["name"])

func _pickup(it: Dictionary) -> void:
	it["got"] = true
	it["node"].visible = false
	_cost(10)
	_say("旁白", "你把「" + str(it["def"]["name"]) + "」收进值班服口袋。它比看起来重。")

func _talk(np: Dictionary) -> void:
	if round == 0 and np["name"] == "林岚":
		dialog = [
			"我是信号检修，不是乘客。",
			"五号继电器的反馈慢了半秒。",
			"让我进控制室——那个端口十七年前就封了，我的工牌能打开它。",
		]
		dialog_npc = np
		dialog_idx = -1
		_advance_dialog()
	elif round == 1 and np["name"] == "周砚":
		dialog = [
			"别关站内广播。我在做一期节目，叫《谁弄丢了 0017》。",
			"刚才那声不是电流，是有人在喊车次。让我听完整的。",
		]
		dialog_npc = np; dialog_idx = -1; _advance_dialog()
	elif round == 2 and np["name"] == "陈默":
		dialog = [
			"这只包在失物柜里放了十七年。今天有人用我的名字把它取出来，我得送回去。",
			"一把旧钥匙而已。站里换了系统，这样的东西早就没用了。",
		]
		dialog_npc = np; dialog_idx = -1; _advance_dialog()
	else:
		_say(np["name"], "……")

func _advance_dialog() -> void:
	if dialog_idx >= dialog.size():
		dialog = []
		dialog_idx = 0
		_after_talk()
		return
	_say(str(dialog_npc["name"]), str(dialog[dialog_idx]))

func _after_talk() -> void:
	var nm: String = dialog_npc["name"]
	_cost(30)
	if nm == "林岚":
		choice = {"key_a": KEY_E, "key_b": KEY_R}
		chooser_a = "A"; chooser_b = "no"
		hud_prompt.text = "[E] 允许她接入旧继电器端口　[R] 拒绝"
	elif nm == "周砚":
		_give_clue(1)
		_say("周砚", "三道有人，改四道。")
		_say("旁白", "可官方报告写着——三道无人。获得「倒放广播」。")
	elif nm == "陈默":
		_give_clue(2); _give_clue(3)
		_say("陈默", "三道有人。不是车，是人。那时候我叫邵国安，他还在隧道里。")
		_say("旁白", "获得「停用钥匙」和「巡检簿」。")

func _press_button(idx: int) -> void:
	var b: Dictionary = buttons[idx]
	if b["done"]:
		return
	b["done"] = true
	b["mat"].emission_energy_multiplier = 2.6
	play_click()
	_cost(25)
	if idx == 0:
		_say("调度台", "0017 次，进二道。进路已设。")
	elif idx == 1:
		_say("调度台", "值班簿已签。今夜值班：你。")
	else:
		_say("调度台", "交接完成。祝你好运。")
	var tw := create_tween()
	tw.tween_property(b["mat"], "emission_energy_multiplier", 0.6, 0.6)

func _act(id: String) -> void:
	match id:
		"power":
			power = true
			_cost(45)
			_say("旁白", "闸刀合上的一瞬间，整条站台的灯都暗了一下，再亮起来。")
		"console":
			_cost(15)
			_say("调度台", "进路表上一次被人改过，改的时间被涂掉了——只留下一行小字：按调度席指令执行。")
		"seat":
			player.sit_at(prompt["spot"]["seat"]["pos"], float(prompt["spot"]["seat"]["yaw"]))
			_say("旁白", "你坐了下来。按 E 或方向键起身。")
		"handle":
			if _got_count() < 5:
				_say("旁白", "手柄推不动。继电器没有响。")
				return
			_cost(60)
			if clock_min >= T_LOCK:
				late = true
				_say("旁白", "手柄推到底了。可继电器没有响——它比它该有的时间，慢了半秒。")
			else:
				handle = true
				_say("调度台", "进路已锁。0017 次，二道停车。")
		"divert":
			if not (_has_clue(2) or _has_clue(3)):
				_say("旁白", "道岔锁着。锁扣上刻着两个字：停用。得有那把钥匙，或者巡检簿上的记录。")
				return
			divert = true
			_cost(35)
			play_click()
			_set_switch_green(true)
			_say("旁白", "钥匙插进锁孔，锁扣弹开。道岔扳过去的时候，钢轨在黑暗里挪了一寸。")
			_say("站内广播", "进路变更。0017 次，改走检修环线。")

func _cost(sec: float) -> void:
	clock_min += sec / 60.0
	hud_clock.text = hud_clock.text  # 立刻刷新
	var tw := create_tween()
	tw.tween_property(hud_clock, "scale", Vector2(1.25, 1.25), 0.12)
	tw.tween_property(hud_clock, "scale", Vector2(1, 1), 0.12)

func _got_count() -> int:
	var n := 0
	for it in items:
		if it["got"]:
			n += 1
	return n

# ------------------------------------------------------------------ 交互检测
func _update_interaction() -> void:
	prompt = null
	hud_prompt.text = ""
	if player.sitting:
		prompt = {"kind": "stand", "text": "站起来"}
		hud_prompt.text = "[E]  站起来"
		return
	if state != "play" or bag_open:
		return
	var eye: Vector3 = player.eye()
	var fwd: Vector3 = player.forward()
	var best := -1.0
	for it in items:
		if it["got"] or not it["node"].visible:
			continue
		var p: Vector3 = it["node"].global_position
		var v := p - eye
		var d := v.length()
		if d > 2.8: continue
		var dot := v.normalized().dot(fwd)
		if dot < 0.72: continue
		var s := dot - d * 0.05
		if s > best:
			best = s
			prompt = {"kind": "item", "it": it, "text": "拾取 · " + str(it["def"]["name"])}
	for np in npcs:
		if not np["node"].visible: continue
		var p2: Vector3 = np["node"].global_position + Vector3(0, 1.4, 0)
		var v2 := p2 - eye
		var d2 := v2.length()
		if d2 > 2.4: continue
		var dot2 := v2.normalized().dot(fwd)
		if dot2 < 0.70: continue
		var s2 := dot2 - d2 * 0.05
		if s2 > best:
			best = s2
			prompt = {"kind": "npc", "npc": np, "text": "与 " + str(np["name"]) + " 说话"}
	if round == -1:
		for i in range(buttons.size()):
			var b: Dictionary = buttons[i]
			if b["done"]: continue
			var p3: Vector3 = b["node"].global_position
			var v3 := p3 - eye
			var d3 := v3.length()
			if d3 > 2.6: continue
			var dot3 := v3.normalized().dot(fwd)
			if dot3 < 0.80: continue
			var s3 := dot3 - d3 * 0.05
			if s3 > best:
				best = s3
				prompt = {"kind": "button", "idx": i, "text": str(b["label"])}
	for d in doors:
		var v5: Vector3 = d["spot"] - eye
		var d5 := v5.length()
		if d5 > float(d["r"]):
			continue
		var h5 := Vector3(v5.x, 0.0, v5.z)
		if h5.length() < 0.02:
			continue
		var dot5 := h5.normalized().dot(Vector3(fwd.x, 0.0, fwd.z).normalized())
		if dot5 < 0.65:
			continue
		var s5 := dot5 - d5 * 0.05
		if s5 > best:
			best = s5
			prompt = {"kind": "door", "door": d, "text": ("关门" if bool(d["open"]) else "开门") + " · " + String(d["name"])}
	for sp in spots:
		var sk: String = sp["id"]
		if sk == "power" and power: continue
		if sk == "divert" and (round < 3 or divert): continue
		if sk == "handle" and (round < 3): continue
		var v4: Vector3 = sp["pos"] - eye
		var d4 := v4.length()
		if d4 > sp["r"]: continue
		var dot4 := v4.normalized().dot(fwd)
		if dot4 < 0.62: continue
		var s4 := dot4 - d4 * 0.05
		if s4 > best:
			best = s4
			var txt: String = sp["label"]
			if sk == "handle":
				txt = "拉下总调度手柄" if _got_count() >= 5 else "总调度手柄 · 缺少证据"
			if sk == "seat":
				txt = "坐下"
			if sk == "divert":
				txt = "改环线 · 扳动道岔 1"
				if not (_has_clue(2) or _has_clue(3)):
					txt = "改环线 · 需要停用钥匙或巡检簿"
			prompt = {"kind": "spot", "id": sk, "text": txt, "spot": sp}
	if prompt != null:
		hud_prompt.text = "[E]  " + str(prompt["text"])

# ------------------------------------------------------------------ 动画
func _animate_doors(delta: float) -> void:
	var lv: MeshInstance3D = get_meta("lever")
	var hd: MeshInstance3D = get_meta("handle")
	for d in doors:
		if String(d["name"]) == "信号室门" and (sr_open or round >= 3):
			d["open"] = true
		if String(d["name"]) == "检修笼门" and power:
			d["open"] = true
		var n: Node3D = d["node"]
		var tgt: Vector3 = n.get_meta("closed") + (d["slide"] if bool(d["open"]) else Vector3.ZERO)
		n.position = n.position.lerp(tgt, clampf(delta * 2.4, 0.0, 1.0))
	lv.rotation.x = lerp(lv.rotation.x, (-0.9 if power else 0.35), clampf(delta * 5.0, 0.0, 1.0))
	hd.rotation.x = lerp(hd.rotation.x, (-1.1 if handle else 0.0), clampf(delta * 5.0, 0.0, 1.0))

func _void_guard(delta: float) -> void:
	safe_t += delta
	if player.is_on_floor() and safe_t > 0.5:
		safe_t = 0.0
		safe_pos = player.global_position + Vector3(0, 0.3, 0)
	if player.global_position.y < -12.0:
		player.global_position = safe_pos
		player.velocity = Vector3.ZERO
		_say("旁白", "……你踩空了半秒。")

func _toggle_bag(on: bool) -> void:
	bag_open = on
	bag.visible = on
	player.can_move = not on
	if on:
		bag.refresh(items, bag_sel)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.allow_capture = false
		player.dragging = false
	elif state == "play":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player.allow_capture = true
func _animate_items(delta: float) -> void:
	var i := 0
	for it in items:
		var n: Node3D = it["node"]
		if n.visible:
			n.rotate_y(delta * 1.1)
			var base: Vector3 = it["def"]["pos"]
			n.position.y = base.y + sin(t_now * 1.5 + float(i) * 1.4) * 0.09
		i += 1

func _update_hud() -> void:
	var m := int(floor(clock_min))
	var mm := ((m % 1440) + 1440) % 1440
	var ss := int((clock_min - floor(clock_min)) * 60.0)
	hud_clock.text = "%02d:%02d:%02d" % [mm / 60, mm % 60, ss]
	hud_clock.add_theme_color_override("font_color",
		Color(0.95, 0.30, 0.26) if clock_min >= 1454.5 else Color(0.88, 0.64, 0.29))
	if clock_label != null:
		clock_label.text = "%02d:%02d" % [mm / 60, mm % 60]
	_refresh_items_ui()

func _update_map() -> void:
	if hud_map == null:
		return
	var obs := []
	if round == -1:
		for i in range(buttons.size()):
			var b: Dictionary = buttons[i]
			if not b["done"]:
				obs.append({"text": str(b["label"]), "pos": b["node"].global_position})
	if round == 0 and dialog_npc != null and dialog_npc["name"] == "林岚":
		if not _has_clue(0):
			obs.append({"text": "去信号室门口找林岚", "pos": Vector3(-13.9, 1.4, 28.2)})
	if round == 1 and not _has_clue(1):
		obs.append({"text": "去站台南头找周砚", "pos": Vector3(-6.0, 1.4, 42.0)})
	if round == 2 and not _has_clue(2):
		obs.append({"text": "去北隧道口找陈默", "pos": Vector3(0.6, 1.4, -52.0)})
	if round >= 3:
		if divert:
			obs.append({"text": "道岔已扳向检修环线", "pos": Vector3(7.7, 1.0, -112.4), "done": true})
		elif _has_clue(2) or _has_clue(3):
			obs.append({"text": "去岔区 · 改环线（结局 B）", "pos": Vector3(7.7, 1.0, -112.4)})
		if not handle and _got_count() >= 5:
			obs.append({"text": "回信号室 · 拉下总调度手柄", "pos": Vector3(-16.7, 1.15, 30.8)})
		elif _got_count() < 5:
			obs.append({"text": "集齐五件记录", "pos": Vector3(-16.2, 1.5, 27.2)})
	hud_map.objectives = obs
	hud_map.round_title = ROUND_NAMES[round + 1]
	var cl := {}
	for i in range(CLUES.size()):
		if _has_clue(i):
			cl[CLUES[i]] = true
	hud_map.clues = cl
	hud_map.people = []
	for np in npcs:
		if np["node"].visible:
			hud_map.people.append({"name": np["name"], "pos": np["node"].global_position, "col": np["accent"]})
	if round == -1:
		hud_map.round_hint = "照着流程做：确认进路、签值班簿、交接确认。然后，等车。"
	elif round == 0:
		hud_map.round_hint = "林岚站在信号室门口，拎着一个工具盒。她说五号继电器的反馈慢了半秒。"
	elif round == 1:
		hud_map.round_hint = "周砚在做一期节目，叫《谁弄丢了 0017》。他要把广播倒放给你听。"
	elif round == 2:
		hud_map.round_hint = "陈默要把一只放了十七年的包送回去。里面有一把旧钥匙。"
	else:
		hud_map.round_hint = "00:16:43 那道手动进路必须取消。也可以去岔区改环线——把 0017 送进检修环线，让今晚没有名字。"

func _has_clue(i: int) -> bool:
	return items[i]["got"]

# ------------------------------------------------------------------ 字幕
func _say(who: String, text: String) -> void:
	hud_sub_title.text = who
	sub = text
	sub_time = 0.0
	hud_sub.text = ""
	print("[", who, "] ", text)

func _update_sub(delta: float) -> void:
	if sub == "":
		return
	sub_time += delta
	var shown := int(sub_time * sub_cps)
	shown = mini(shown, sub.length())
	hud_sub.text = sub.substr(0, shown)
	if shown >= sub.length() and sub_time > sub.length() / sub_cps + 3.5:
		sub = ""
		hud_sub.text = ""
		hud_sub_title.text = ""

func _fade_to(a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(hud_fade, "modulate:a", a, dur)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if state == "cutscene" and (event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_E or event.physical_keycode == KEY_ESCAPE):
			_skip_cutscene()
		elif event.physical_keycode == KEY_E:
			_interact()
		elif event.physical_keycode == KEY_R:
			if choice != null:
				_interact()
		elif event.physical_keycode == KEY_V:
			player.toggle_cam()
			_say("旁白", "视角：第三人称" if player.cam_mode == 1 else "视角：第一人称")
		elif event.physical_keycode == KEY_B:
			_toggle_bag(not bag_open)
		elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
			_set_sel(event.physical_keycode - KEY_1)
			_refresh_items_ui()
		elif event.physical_keycode == KEY_T:
			if state == "play":
				_cost(0)
				clock_min = T_ARRIVE
				_say("旁白", "你决定提前结束这班。")
		elif event.physical_keycode == KEY_ESCAPE:
			if bag_open:
				_toggle_bag(false)
			elif state == "play":
				state = "paused"
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				player.allow_capture = false
				player.dragging = false
				menu.visible = true
				menu.show_pause()
			elif state == "paused":
				_on_resume()
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ------------------------------------------------------------------ 音频
func _set_sel(v: int) -> void:
	bag_sel = v
	if bag != null:
		bag.sel = v

func _refresh_items_ui() -> void:
	if hotbar != null:
		hotbar.items = items
		hotbar.sel = bag_sel
	if bag != null and bag.visible:
		bag.refresh(items, bag_sel)

func _make_bag() -> void:
	bag = BagScript.new()
	hud.add_child(bag)
	bag.setup(font)
	bag.visible = false
	bag.sel_changed.connect(_set_sel)
	hotbar = HotbarScript.new()
	hud.add_child(hotbar)
	hotbar.setup(font)
	hotbar.sel_changed.connect(_set_sel)
	print("[0017] 背包就绪")
func _make_buses() -> void:
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")

func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var n := samples.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w

func _make_audio() -> void:
	_make_buses()
	# 站内底噪：低频嗡鸣 + 风机噪声（4 秒循环）
	var rate := 22050
	var secs := 4
	var n := rate * secs
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20170
	var lp := 0.0
	for i in range(n):
		var t := float(i) / float(rate)
		var v := sin(TAU * 47.0 * t) * 0.32 + sin(TAU * 71.0 * t) * 0.20 + sin(TAU * 71.7 * t) * 0.16
		lp = lp * 0.86 + rng.randf_range(-1.0, 1.0) * 0.14
		v += lp * 0.55
		s[i] = v * 0.16
	ambient = AudioStreamPlayer.new()
	ambient.stream = _wav(s, true)
	ambient.bus = "Music"
	ambient.volume_db = -4.0
	add_child(ambient)
	ambient.play()
	# 交互点击声
	var clicks := PackedFloat32Array()
	clicks.resize(2205)
	for i in range(2205):
		var t2 := float(i) / 22050.0
		clicks[i] = rng.randf_range(-1.0, 1.0) * exp(-t2 * 120.0) * 0.9
	sfx_click = _wav(clicks, false)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = sfx_click
	sfx_player.bus = "SFX"
	sfx_player.volume_db = -8.0
	add_child(sfx_player)

func play_click() -> void:
	if sfx_player != null:
		sfx_player.play()

# ------------------------------------------------------------------ 菜单 / 存读档
func _make_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	menu = MenuScript.new()
	menu_layer.add_child(menu)
	menu.setup(font)
	menu.start_game.connect(_on_start)
	menu.load_slot.connect(_on_load_slot)
	menu.save_slot.connect(_on_save_slot)
	menu._pause_wants_save.connect(func():
		menu.set_slots(slots_info(), "save")
		menu.show_slots("save")
	)
	menu.resume_game.connect(_on_resume)
	menu.to_menu.connect(_on_to_menu)
	menu.quit_game.connect(func(): get_tree().quit())
	_apply_settings()

func _apply_settings() -> void:
	var c: Dictionary = menu.get_cfg()
	menu.apply_audio()
	if player != null:
		player.mouse_sens = 0.0022 * clampf(c["sens"], 0.2, 3.0)
	sub_cps = 26.0 * clampf(c["speed"], 0.3, 3.0)
	var end := lerpf(26.0, 60.0, clampf(c["fog"], 0.0, 1.5))
	for bd in StationBuilder.ALL:
		for k in bd._mats.keys():
			var m = bd._mats[k]
			if m is ShaderMaterial:
				m.set_shader_parameter("fog_end", end)
	if env_node != null:
		env_node.environment.adjustment_brightness = clampf(c["bright"], 0.4, 2.0)

func _hide_menu() -> void:
	menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.allow_capture = true

func _show_menu() -> void:
	state = "menu"
	menu.hide_all()
	menu.visible = true
	menu.center.visible = true
	menu.set_slots(slots_info(), "load")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player != null:
		player.allow_capture = false
		player.dragging = false

func _on_start() -> void:
	round = -2
	_once_flags.clear()
	power = false; sr_open = false; handle = false; late = false; divert = false; shown_end = ""
	train.set_divert(false)
	_set_switch_green(false)
	for it in items: it["got"] = false
	for b in buttons: b["done"] = false
	_start_round()
	state = "play"
	_hide_menu()

func _on_load_slot(i: int) -> void:
	if game_load(i):
		state = "play"
		menu.hide_all()
		_hide_menu()
		_say("旁白", "接着上一班继续。")

func _on_save_slot(i: int) -> void:
	if game_save(i):
		_say("调度台", "已存入槽位 %d。" % (i + 1))
		menu.set_slots(slots_info(), "load")
		menu.hide_all()
		state = "play"
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player.allow_capture = true

func slots_info() -> Array:
	var out := []
	for i in range(3):
		var d := {"exists": FileAccess.file_exists(SLOT_PATHS[i]), "round": "", "clock": "", "time": ""}
		if d["exists"]:
			var f := FileAccess.open(SLOT_PATHS[i], FileAccess.READ)
			if f != null:
				var j = JSON.parse_string(f.get_as_text())
				f.close()
				if typeof(j) == TYPE_DICTIONARY:
					var r := clampi(int(j.get("round", -1)) + 1, 0, 4)
					d["round"] = str(ROUND_NAMES[r])
					var cm := float(j.get("clock", T_START))
					var mm := ((int(cm) % 1440) + 1440) % 1440
					d["clock"] = "%02d:%02d" % [mm / 60, mm % 60]
					d["time"] = str(j.get("time", ""))
		out.append(d)
	return out

func _on_resume() -> void:
	state = "play"
	menu.hide_all()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.allow_capture = true
	player.dragging = false

func _on_to_menu() -> void:
	state = "menu"
	_show_menu()

func _refresh_visibility() -> void:
	for np in npcs:
		np["node"].visible = (round >= 0 and int(np["show_round"]) <= round)
	for it in items:
		it["node"].visible = (int(it["def"]["round"]) <= round and not it["got"])

func game_has_save() -> bool:
	for p in SLOT_PATHS:
		if FileAccess.file_exists(p):
			return true
	return false

func game_save(i: int) -> bool:
	var f := FileAccess.open(SLOT_PATHS[i], FileAccess.WRITE)
	if f == null:
		return false
	var got := []
	for it in items:
		got.append(it["got"])
	var btns := []
	for b in buttons:
		btns.append(b["done"])
	var d := {"round": round, "clock": clock_min, "power": power, "sr": sr_open,
			  "handle": handle, "late": late, "divert": divert, "got": got, "btn": btns,
			  "time": Time.get_datetime_string_from_system(false, false)}
	f.store_string(JSON.stringify(d))
	f.close()
	return true

func game_load(i: int) -> bool:
	if not FileAccess.file_exists(SLOT_PATHS[i]):
		return false
	var f := FileAccess.open(SLOT_PATHS[i], FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		return false
	round = int(d.get("round", -1))
	clock_min = float(d.get("clock", T_START))
	power = bool(d.get("power", false))
	sr_open = bool(d.get("sr", false))
	handle = bool(d.get("handle", false))
	late = bool(d.get("late", false))
	divert = bool(d.get("divert", false))
	train.set_divert(divert)
	_set_switch_green(divert)
	var got: Array = d.get("got", [])
	for k in range(mini(got.size(), items.size())):
		items[k]["got"] = bool(got[k])
	var btns: Array = d.get("btn", [])
	for k2 in range(mini(btns.size(), buttons.size())):
		buttons[k2]["done"] = bool(btns[k2])
	_refresh_visibility()
	return true
func clampf(v: float, a: float, b: float) -> float:
	return clamp(v, a, b)

# ------------------------------------------------------------------ 岔区 · 道岔信号 / 改环线结局
func _make_switch_signal() -> void:
	# 道岔信号：红灯 = 主线停车，绿灯 = 放行检修环线
	var p := Vector3(0.85, 0.0, -108.0)
	var sb := StationBuilder.new(self)
	sb.box("metalD", p + Vector3(-0.10, -1.15, -0.10), p + Vector3(0.10, 1.20, 0.10), true)
	sb.box("dark", p + Vector3(-0.17, 1.20, -0.17), p + Vector3(0.17, 2.30, 0.17), true)
	sb.box("metalD", p + Vector3(-0.30, 2.30, -0.24), p + Vector3(0.30, 2.42, 0.24), false)
	sb.box("dark", p + Vector3(-0.32, -1.17, -0.32), p + Vector3(0.32, -1.09, 0.32), true)
	sb.commit()
	sb.mesh_inst.name = "SwitchSignal"
	for spec in [["red", 1.80, Color(0.85, 0.16, 0.12)], ["green", 1.40, Color(0.28, 0.85, 0.42)]]:
		var col: Color = spec[2]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.30, 0.30, 0.06)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(col.r * 0.22, col.g * 0.22, col.b * 0.22)
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.12
		mi.material_override = m
		mi.position = p + Vector3(0.0, float(spec[1]), 0.17)
		add_child(mi)
		if spec[0] == "red":
			sig_red = mi
		else:
			sig_green = mi
	var ol := OmniLight3D.new()
	ol.position = p + Vector3(0.0, 1.55, 1.0)
	ol.light_color = Color(0.85, 0.20, 0.16)
	ol.light_energy = 1.5
	ol.omni_range = 9.0
	ol.shadow_enabled = false
	add_child(ol)
	sig_light = ol

func _set_switch_green(on: bool) -> void:
	if sig_red == null or sig_green == null:
		return
	var mr: StandardMaterial3D = sig_red.material_override
	var mg: StandardMaterial3D = sig_green.material_override
	mr.emission_energy_multiplier = 0.12 if on else 2.4
	mg.emission_energy_multiplier = 2.4 if on else 0.12
	if sig_light != null:
		sig_light.light_color = Color(0.28, 0.85, 0.42) if on else Color(0.85, 0.20, 0.16)
		sig_light.light_energy = 2.1 if on else 1.4

func _begin_divert_end() -> void:
	# 结局 B：列车真的拐进侧线
	state = "cutscene"
	cut_phase = "dv_out"
	cut_t = 0.0
	dv_said = false
	_dv_s0 = train.s_at_z(-160.0)
	_dv_end_s = train.s_at_z(-62.0) + train.last_front_offset()
	player.can_move = false
	player.dragging = false
	player.allow_capture = false
	hud_sub.text = ""
	hud_sub_title.text = ""
	train.set_divert(true)
	_set_switch_green(true)
	_say("旁白", "你扳动了道岔。绿灯亮起来的时候，黑暗里有一道光在动。")
