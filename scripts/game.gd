extends Node3D
## 岚桥站 0017 —— 序章 + 四轮循环 + 三人 + 两个结局（按剧本-修订版）

const StationBuilder := preload("res://scripts/station.gd")
const Level := preload("res://scripts/level.gd")
const PlayerScript := preload("res://scripts/player.gd")
const CharBody := preload("res://scripts/charbody.gd")
const TrainScript := preload("res://scripts/train.gd")
const HudMap := preload("res://scripts/hudmap.gd")
const MinesGame := preload("res://scripts/minigame_mines.gd")
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
var hud_cam: Label
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
var web_perf_t := 0.0
var map_acc := 0.0
var web_gpu_is_software := false
var got_this_round := {}
var choice_text := ""
var lan_trust := false
var tape_air := false
var bag_return := false
var studio_onair_on := false
var studio_freq_idx := 0
var pc_overlay: Control
var pc_layer: CanvasLayer
var studio_onair_mat: StandardMaterial3D
var prompt: Variant = null
var prompt_ring: MeshInstance3D = null      # 交互目标脚下的「呼吸环」
var prompt_ring_mat: StandardMaterial3D = null
var ring_flash := 0.0                      # 按下 E 之后 1 秒的高亮
var round_card: Control = null                   # 每轮开头那张「第 N 轮」卡片
var round_card_title: Label = null
var round_card_sub: Label = null
var round_summary: Control = null                # 每轮结束的结算卡
var round_summary_title: Label = null
var round_summary_body: Label = null
var round_summary_foot: Label = null
var desk_phone_mat: StandardMaterial3D = null   # 调度台上那台老式电话的指示灯
var desk_phone_t := 0.0
var tun_lamp_mat: StandardMaterial3D = null        # 环线隧道里那盏坏灯
var tun_lamp_light: OmniLight3D = null
var tun_lamp_t := 0.0                              # 用累积时间而不是真实时钟，方便采样验证
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
var sfx_relay: AudioStreamWAV
var sfx_chime: AudioStreamWAV
var sfx_step: AudioStreamWAV
var sfx_horn: AudioStreamWAV
var sfx_brake: AudioStreamWAV
var sfx_train: AudioStreamWAV
var relay_player: AudioStreamPlayer
var chime_player: AudioStreamPlayer
var step_player: AudioStreamPlayer
var horn_player: AudioStreamPlayer
var brake_player: AudioStreamPlayer
var train_player: AudioStreamPlayer
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
var saw_lag := false
var board_cards: Array = []
var board_root: Node3D
var ending_key_cab: Node3D      # 结局 B：钥匙留在失物招领柜
var ending_key_desk: Node3D     # 结局 A：钥匙放回调度台面
const BOARD_X := -17.94
const BOARD_Z0 := -16.80
const BOARD_DZ := 0.60              # 在岔区机位看见了「红灯晚了半秒」
var _dv_s0 := 0.0
var _dv_end_s := 0.0

var ITEM_DEFS := [
	{"id":"red", "short":"00:16:43 · 旧继电器端口","name":"红灯延迟记录","where":"控制台 · 旧继电器端口","desc":"旧继电器端口的打印条。红灯比它该亮的时间晚了半秒。","pos":Vector3(-16.60, 1.156, -13.60),"col":Color(0.83,0.34,0.31),"round":0},
	{"id":"tape", "short":"「三道有人，改四道」","name":"倒放广播","where":"广播台 · 磁带机","desc":"把站内广播倒过来听，里面有一句被埋掉的话：「三道有人，改四道。」","pos":Vector3(-16.30, 1.172, -13.0),"col":Color(0.35,0.62,0.83),"round":1},
	{"id":"key", "short":"十七年前那把","name":"停用钥匙","where":"隧道 · 检修环线","desc":"十七年前那把停用钥匙。系统早换了，锁还认它。","pos":Vector3(10.80, -0.278, -60.50),"col":Color(0.88,0.64,0.29),"round":2},
	{"id":"log", "short":"00:16:43 手动进路","name":"巡检簿","where":"站台 · 长椅上","desc":"巡检簿被撕掉的一页。上面记着 00:16:43 那道手动进路。","pos":Vector3(-14.72, 0.516, 17.00),"col":Color(0.72,0.82,0.95),"round":2},
	{"id":"relay5", "short":"反馈慢了半拍","name":"五号继电器","where":"信号室 · 继电器柜","desc":"五号继电器的反馈慢半拍。隔离它，进路才锁得死。","pos":Vector3(-17.150, 2.071, 26.700),"col":Color(0.25,0.75,0.56),"round":3},
]

func _ready() -> void:
	if OS.has_feature("web"):
		Engine.max_fps = 60
		call_deferred("_apply_web_quality")
		var gpu := _detect_web_gpu()
		print("[WEB] gpu=", gpu)
		var gl := gpu.to_lower()
		web_gpu_is_software = gl.contains("swiftshader") or gl.contains("software") or gl.contains("llvmpipe")
		if web_gpu_is_software:
			print("[WEB] warning: software WebGL; enable hardware acceleration")
	_make_font()
	_make_env()
	_build_world()
	_spawn_player()
	_make_hud()
	_make_items()
	_make_doors()
	_make_clue_board()
	_make_ending_props()
	_make_npcs()
	_make_buttons()
	_make_switch_signal()
	_make_prompt_ring()
	_make_desk_props()
	_make_duty_computer()
	_make_studio_props()
	_make_tunnel_lamp()
	train = TrainScript.new(self)
	train.reset()
	spots = [
		{"id":"power","pos":Vector3(-17.0, 1.35, -30.0),"r":2.8,"label":"扳下配电柜总闸"},
		{"id":"console","pos":Vector3(-16.6, 1.2, -14.0),"r":2.6,"label":"查看调度台"},
		{"id":"handle","pos":Vector3(-16.70, 1.35, 30.80),"r":2.7,"label":"总调度手柄"},
		{"id":"divert","pos":Vector3(7.7, -0.25, -112.4),"r":3.2,"label":"改环线 · 扳动道岔 1"},
		{"id":"board","pos":Vector3(-17.5, 2.15, -14.5),"r":3.2,"label":"看值班记录板"},
		{"id":"pc", "pos":Vector3(-15.8, 1.15, 4.15), "r": 2.2, "label":"打开值班终端"},
		{"id":"studio_mic", "pos":Vector3(-16.0, 1.25, 34.8), "r": 2.2, "label":"对麦克风试音"},
		{"id":"studio_dial", "pos":Vector3(-15.35, 1.1, 34.8), "r": 1.8, "label":"转动频率旋钮"},
		{"id":"studio_onair", "pos":Vector3(-12.0, 1.9, 36.5), "r": 2.0, "label":"切换 ON AIR"},
		{"id":"studio_tape", "pos":Vector3(-19.2, 1.4, 42.5), "r": 2.2, "label":"翻找磁带架"},
	]
	for s in builder.seats:
		spots.append({"id":"seat", "pos": s["pos"] + Vector3(0, 0.55, 0), "r": 2.1, "label": "坐下", "seat": s})
	print("[0017] 可坐的位置 ", builder.seats.size(), " 个")
	_make_audio()
	_make_menu()
	_make_bag()
	_make_pc_overlay()
	train.lights_on(false)     # 预热：列车灯常驻但能量极低，先把着色器变体编译掉
	round = -2
	_start_round()
	_show_menu()
	print("[0017] 就绪 · 三角 ", builder.tri_count, " · 碰撞 ", builder.col_count, " · 灯 ", builder.lights.size())

func _apply_web_quality() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	vp.scaling_3d_scale = 0.65
	vp.msaa_3d = Viewport.MSAA_DISABLED
	print("[WEB] quality=low scale=0.65 glow=off msaa=off")
func _detect_web_gpu() -> String:
	if not OS.has_feature("web"):
		return ""
	var jb = Engine.get_singleton("JavaScriptBridge")
	if jb == null:
		return ""
	var js := "(function(){var c=document.createElement('canvas');var gl=c.getContext('webgl2')||c.getContext('webgl');if(!gl)return 'none';var e=gl.getExtension('WEBGL_debug_renderer_info');return e?gl.getParameter(e.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER);})()"
	return str(jb.eval(js))
func _make_font() -> void:
	# Web 版没有系统字体，必须用内嵌的 CJK 字体，否则中文全是方框
	var f := load("res://assets/fonts/NotoSansSC-Regular.otf")
	if f is Font:
		font = f
		return
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
	if OS.has_feature("web"):
		e.glow_enabled = false
		e.ssao_enabled = false
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
	player.footstep.connect(_on_footstep)

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
	# 每轮开头的标题卡（放在 fade 下面，过场淡入淡出会把它一起盖住）
	round_card = Control.new()
	round_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	round_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_edge := ColorRect.new()
	card_edge.color = Color(0.88, 0.64, 0.29, 0.80)
	card_edge.position = Vector2(598, 336); card_edge.size = Vector2(404, 126)
	card_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_card.add_child(card_edge)
	var card_fill := ColorRect.new()
	card_fill.color = Color(0.04, 0.05, 0.07, 0.94)
	card_fill.position = Vector2(602, 340); card_fill.size = Vector2(396, 118)
	card_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_card.add_child(card_fill)
	round_card_title = _label(round_card, 0, Vector2(600, 352), Vector2(400, 54), 32, Color(0.88, 0.64, 0.29))
	round_card_sub = _label(round_card, 0, Vector2(600, 412), Vector2(400, 36), 15, Color(0.78, 0.82, 0.88))
	round_card.visible = false
	root.add_child(round_card)
	# 每轮结束的结算卡（在下一轮预览时显示；放在 fade 下面，过场黑幕会盖住它）
	round_summary = Control.new()
	round_summary.set_anchors_preset(Control.PRESET_FULL_RECT)
	round_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sum_edge := ColorRect.new()
	sum_edge.color = Color(0.88, 0.64, 0.29, 0.85)
	sum_edge.position = Vector2(300, 470); sum_edge.size = Vector2(1000, 330)
	sum_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_summary.add_child(sum_edge)
	var sum_fill := ColorRect.new()
	sum_fill.color = Color(0.04, 0.05, 0.07, 0.94)
	sum_fill.position = Vector2(304, 474); sum_fill.size = Vector2(992, 322)
	sum_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_summary.add_child(sum_fill)
	round_summary_title = _label(round_summary, 0, Vector2(330, 490), Vector2(940, 40), 24, Color(0.88, 0.64, 0.29))
	round_summary_body = _label(round_summary, 0, Vector2(330, 535), Vector2(940, 215), 17, Color(0.84, 0.88, 0.94))
	round_summary_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	round_summary_foot = _label(round_summary, 0, Vector2(330, 760), Vector2(940, 24), 12, Color(0.55, 0.60, 0.66))
	round_summary.visible = false
	root.add_child(round_summary)
	hud_fade = ColorRect.new()
	hud_fade.color = Color(0, 0, 0, 1)
	hud_fade.position = Vector2.ZERO
	hud_fade.size = Vector2(1600, 900)
	hud_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_fade.modulate.a = 0.0
	root.add_child(hud_fade)
	hud_cam = _label(root, 0, Vector2(18, 838), Vector2(430, 26), 15, Color(0.55, 0.92, 0.66))
	hud_cam.visible = false
	hud_cam.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
		var n := _make_item_model(d)
		n.position = d["pos"]
		var ol := OmniLight3D.new()
		ol.light_color = d["col"]; ol.light_energy = 1.0; ol.omni_range = 3.4; ol.shadow_enabled = false
		n.add_child(ol)
		add_child(n)
		n.visible = false
		items.append({"def": d, "node": n, "mesh": n, "got": false})

## 每件线索都做成实物小模型（原来是一个飘在空中的发光球），原点在底面，方便直接摆在平面上
func _make_item_model(d: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = String(d["id"])
	var col: Color = d["col"]
	var body := StandardMaterial3D.new()
	body.albedo_color = col
	body.roughness = 0.60
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.10, 0.11, 0.13)
	dark.roughness = 0.85
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.86, 0.87, 0.84)
	paper.roughness = 0.90
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.62, 0.64, 0.66)
	metal.roughness = 0.35
	metal.metallic = 0.5
	var lit := StandardMaterial3D.new()
	lit.albedo_color = col
	lit.emission_enabled = true
	lit.emission = col
	lit.emission_energy_multiplier = 1.6
	match String(d["id"]):
		"red":      # 红灯延迟记录：一条打印条 + 红灯 + 卡子
			_item_part(root, Vector3(0.22, 0.005, 0.09), Vector3(0, 0.0025, 0), paper)
			_item_part(root, Vector3(0.19, 0.002, 0.012), Vector3(0, 0.006, 0.018), dark)
			_item_part(root, Vector3(0.024, 0.016, 0.024), Vector3(0.086, 0.013, 0.026), lit)
			_item_part(root, Vector3(0.030, 0.020, 0.020), Vector3(-0.090, 0.012, 0), dark)
		"tape":     # 倒放广播：磁带
			_item_part(root, Vector3(0.130, 0.034, 0.092), Vector3(0, 0.018, 0), dark)
			for rx in [-0.030, 0.030]:
				_item_part(root, Vector3(0.044, 0.010, 0.044), Vector3(rx, 0.031, 0), metal, true)
			_item_part(root, Vector3(0.110, 0.012, 0.030), Vector3(0, 0.030, -0.030), lit)
			_item_part(root, Vector3(0.104, 0.006, 0.070), Vector3(0, 0.036, 0), paper)
		"key":      # 停用钥匙
			_item_part(root, Vector3(0.050, 0.008, 0.032), Vector3(0, 0.006, -0.042), body)
			_item_part(root, Vector3(0.036, 0.006, 0.014), Vector3(0, 0.007, -0.058), body)
			_item_part(root, Vector3(0.012, 0.008, 0.086), Vector3(0, 0.006, 0.020), body)
			for k in range(3):
				_item_part(root, Vector3(0.010, 0.008, 0.014), Vector3(0.011, 0.006, 0.036 + float(k) * 0.018), body)
		"log":      # 巡检簿：封面 + 内页 + 书签 + 撕口
			_item_part(root, Vector3(0.170, 0.030, 0.240), Vector3(0, 0.016, 0), dark)
			_item_part(root, Vector3(0.158, 0.022, 0.228), Vector3(0.006, 0.032, 0), paper)
			_item_part(root, Vector3(0.006, 0.034, 0.240), Vector3(-0.084, 0.017, 0), body)
			_item_part(root, Vector3(0.030, 0.006, 0.070), Vector3(0.030, 0.044, 0.070), lit)
		"relay5":   # 五号继电器：外壳 + 顶板 + 三个脚 + 红灯
			_item_part(root, Vector3(0.098, 0.062, 0.096), Vector3(0, 0.052, 0), body)
			_item_part(root, Vector3(0.106, 0.008, 0.104), Vector3(0, 0.087, 0), dark)
			for px in [-0.028, 0.0, 0.028]:
				_item_part(root, Vector3(0.014, 0.022, 0.014), Vector3(px, 0.011, 0), metal)
			_item_part(root, Vector3(0.020, 0.014, 0.006), Vector3(0.026, 0.062, -0.050), lit)
	return root

func _item_part(parent: Node3D, size: Vector3, off: Vector3, mat: Material, cyl := false) -> void:
	var mi := MeshInstance3D.new()
	if cyl:
		var cm := CylinderMesh.new()
		cm.top_radius = size.x * 0.5
		cm.bottom_radius = size.x * 0.5
		cm.height = size.y
		cm.radial_segments = 10
		mi.mesh = cm
	else:
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
	mi.material_override = mat
	mi.position = off
	parent.add_child(mi)

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
	play_chime(0.75, -12.0)
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
	# 这一版按《僵尸毁灭工程》3D 角色的那套做法重排：零件模块化 + 衣服叠穿。
	# 每件衣服都是独立零件（内层 / 外层 / 领子 / 前襟 / 袖口 / 下摆 / 口袋 / 扣子），
	# 换人只换配色与零件组合，几何完全复用——这就是能「套用」过来的部分。
	var skin := Color(0.90, 0.71, 0.60)
	var cloth := Color(0.14, 0.14, 0.24)
	var cloth2 := Color(0.24, 0.24, 0.24)
	var hair := Color(0.05, 0.05, 0.06)
	var inner := Color(0.70, 0.71, 0.72)
	var cap_on := false
	var long_coat := false
	match nm:
		"林岚":
			cloth = Color(0.14, 0.33, 0.42)       # 青蓝工作服
			cloth2 = Color(0.24, 0.24, 0.24)      # 灰长裤
			hair = Color(0.05, 0.05, 0.14)
			inner = Color(0.80, 0.83, 0.86)       # 外套里一件浅色工装衬衫
			n.rotation.y = -PI * 0.5              # 站在信号室门口，面朝站台（+X）
		"周砚":
			cloth = Color(0.42, 0.24, 0.14)       # 棕色大衣
			cloth2 = Color(0.06, 0.06, 0.06)      # 近黑长裤
			inner = Color(0.50, 0.49, 0.47)       # 大衣里一件灰衬衫
			long_coat = true                      # A 里他穿及膝长大衣
			n.rotation.y = 0.0                    # 站台南头，面朝北（-Z）
		"陈默":
			cloth = Color(0.23, 0.26, 0.23)       # 灰绿夹克
			cloth2 = Color(0.14, 0.14, 0.14)      # 近黑长裤
			hair = Color(0.14, 0.24, 0.24)        # 帽子 / 发（青灰）
			inner = Color(0.28, 0.31, 0.36)       # 夹克里一件深蓝内衬
			cap_on = true
			n.rotation.y = PI                     # 北隧道口，面朝站台（+Z）
	# 上半身与头各挂一个枢轴：呼吸、转头、点头都作用在枢轴上（零件名不变，量测脚本照样认）
	var upper := Node3D.new()
	upper.name = "upper"
	upper.position = Vector3(0, 0.995, 0)
	n.add_child(upper)
	var hp := Node3D.new()
	hp.name = "headPivot"
	hp.position = Vector3(0, 0.645, 0)          # 世界 y = 1.64（再抬 2cm：领口下面那段脖子才看得见）
	upper.add_child(hp)
	# 头 / 发 / 帽（坐标相对头枢轴）
	_part(hp, "head", Vector3(0, 0, 0), Vector3(0.222, 0.225, 0.205), skin, 0.0, false, Vector3.ZERO, false, 0.034)
	_part(hp, "hairTop", Vector3(0, 0.118, 0.014), Vector3(0.222, 0.045, 0.222), hair, 0.0, false, Vector3.ZERO, false, 0.012)
	_part(hp, "hairBack", Vector3(0, 0.012, 0.104), Vector3(0.212, 0.212, 0.044), hair, 0.0, false, Vector3.ZERO, false, 0.010)
	for hx in [-0.104, 0.104]:
		_part(hp, "hairSide" + ("L" if hx < 0 else "R"), Vector3(hx, 0.052, 0.004), Vector3(0.030, 0.132, 0.192), hair, 0.0, false, Vector3.ZERO, false, 0.008)
	if nm == "林岚":
		_part(hp, "ponytail", Vector3(0, -0.070, 0.128), Vector3(0.086, 0.185, 0.068), hair, 0.0, false, Vector3.ZERO, false, 0.009)
	# 五官：脸不再是一块光板（眉 / 眼 / 鼻 / 嘴 / 耳），全部压在 z = -0.10 这条面上
	for ex in [-0.106, 0.106]:
		_part(hp, "ear" + ("L" if ex < 0 else "R"), Vector3(ex, 0.006, 0.008), Vector3(0.018, 0.050, 0.036), skin.darkened(0.12))
	for bx in [-0.053, 0.053]:
		_part(hp, "brow" + ("L" if bx < 0 else "R"), Vector3(bx, 0.062, -0.098), Vector3(0.042, 0.009, 0.012), hair.lightened(0.38))
	for ex2 in [-0.055, 0.055]:
		var esfx := "L" if ex2 < 0 else "R"
		_part(hp, "eyeS" + esfx, Vector3(ex2, 0.024, -0.094), Vector3(0.030, 0.021, 0.010), Color(0.10, 0.10, 0.12))
		_part(hp, "eyeW" + esfx, Vector3(ex2, 0.022, -0.094), Vector3(0.042, 0.044, 0.024), Color(0.96, 0.96, 0.97), 0.0, false, Vector3.ZERO, true)
		_part(hp, "eyeP" + esfx, Vector3(ex2, 0.021, -0.102), Vector3(0.020, 0.022, 0.014), Color(0.13, 0.11, 0.10), 0.0, false, Vector3.ZERO, true)
		_part(hp, "eyeH" + esfx, Vector3(ex2 - 0.004, 0.030, -0.108), Vector3(0.008, 0.008, 0.006), Color(1.0, 1.0, 1.0), 0.0, false, Vector3.ZERO, true)
	_part(hp, "nose", Vector3(0, -0.004, -0.101), Vector3(0.014, 0.016, 0.012), skin.darkened(0.14))
	var mth := _part(hp, "mouth", Vector3(0, -0.056, -0.099), Vector3(0.026, 0.004, 0.008), Color(0.34, 0.20, 0.19))
	for mx in [-0.013, 0.013]:
		_part(hp, "lip" + ("L" if mx < 0 else "R"), Vector3(mx, -0.0525, -0.099), Vector3(0.012, 0.004, 0.008), Color(0.34, 0.20, 0.19), 0.0, false, Vector3(0, 0, signf(mx) * 0.26))
	for cx in [-0.072, 0.072]:
		_part(hp, "blush" + ("L" if cx < 0 else "R"), Vector3(cx, -0.030, -0.097), Vector3(0.022, 0.013, 0.008), Color(0.93, 0.60, 0.55), 0.0, false, Vector3.ZERO, true)
	if cap_on:
		_part(hp, "cap", Vector3(0, 0.152, 0), Vector3(0.243, 0.055, 0.233), cloth2, 0.0, false, Vector3.ZERO, false, 0.013)
		_part(hp, "visor", Vector3(0, 0.130, -0.152), Vector3(0.233, 0.030, 0.108), cloth2, 0.0, false, Vector3.ZERO, false, 0.009)	# 躯干 + 衣服叠穿（坐标相对上半身枢轴）：内层领口 → 外层领子 → 前襟 → 下摆 → 腰带 → 口袋
	_part(upper, "neck", Vector3(0, 0.480, 0), Vector3(0.116, 0.130, 0.116), skin)
	# 躯干：椭圆截面放样（腰细、胸宽、肩部收口），不再用胸/腰两个方块叠
	_part_loft(upper, "torso", _npc_profile(), cloth)
	_part(upper, "innerCollar", Vector3(0, 0.462, -0.008), Vector3(0.180, 0.044, 0.170), inner, 0.0, false, Vector3.ZERO, false, 0.010)
	_part(upper, "collar", Vector3(0, 0.445, -0.002), Vector3(0.280, 0.050, 0.205), cloth, 0.0, false, Vector3.ZERO, false, 0.018)
	_part_loft(upper, "belt", _band_profile(-0.020, 0.040, 0.170, 0.108), cloth2)
	_part(upper, "buckle", Vector3(0, 0.010, -0.112), Vector3(0.046, 0.046, 0.014), Color(0.62, 0.60, 0.52))
	_part(upper, "badge", Vector3(0.10, 0.350, -0.110), Vector3(0.070, 0.090, 0.012), accent, 1.6)
	if long_coat:
		# 大衣领子：两片翻领，用旋转做出 V 字
		for ls in [-1.0, 1.0]:
			_part(upper, "lapel" + ("L" if ls < 0 else "R"), Vector3(ls * 0.086, 0.424, -0.126), Vector3(0.118, 0.158, 0.018), cloth.lightened(0.05), 0.0, false, Vector3(0, 0, ls * 0.40))
	# 四肢：圆管（比方块更像人）
	for sgn in [-1.0, 1.0]:
		var sfx := "L" if sgn < 0 else "R"
		# 腿分大小腿：髋 0.995 → 膝 0.545 → 脚踝 0.09 → 鞋底正好 0.00（原来鞋在 0.26，三个人是悬空的）
		_part(n, "leg" + sfx, Vector3(sgn * 0.105, 0.770, 0), Vector3(0.176, 0.45, 0.180), cloth2, 0.0, true, Vector3.ZERO, false, 0.0, 0.068)
		_part(n, "shin" + sfx, Vector3(sgn * 0.105, 0.3175, 0), Vector3(0.152, 0.455, 0.156), cloth2, 0.0, true, Vector3.ZERO, false, 0.0, 0.052)
		_part(n, "hemLeg" + sfx, Vector3(sgn * 0.105, 0.118, 0), Vector3(0.118, 0.030, 0.128), cloth2.darkened(0.35))
		_part(n, "shoe" + sfx, Vector3(sgn * 0.105, 0.045, -0.035), Vector3(0.155, 0.09, 0.26), Color(0.07, 0.07, 0.08), 0.0, false, Vector3.ZERO, false, 0.014)
		_part(upper, "shoulderCap" + sfx, Vector3(sgn * 0.225, 0.408, 0), Vector3(0.210, 0.190, 0.220), cloth, 0.0, false, Vector3.ZERO, true)
		_part(upper, "armU" + sfx, Vector3(sgn * 0.238, 0.310, 0), Vector3(0.132, 0.33, 0.138), cloth, 0.0, true, Vector3.ZERO, false, 0.0, 0.054)
		_part(upper, "armL" + sfx, Vector3(sgn * 0.250, -0.010, -0.030), Vector3(0.110, 0.31, 0.118), cloth, 0.0, true, Vector3.ZERO, false, 0.0, 0.044)
		# 袖口：袖管压住手掌上沿 2cm，手不再是一块飘在袖子下面的浅色方块
		_part(upper, "cuff" + sfx, Vector3(sgn * 0.250, -0.132, -0.030), Vector3(0.104, 0.058, 0.112), cloth.darkened(0.28), 0.0, true)
		# 手：掌 + 四指 + 拇指
		_part(upper, "palm" + sfx, Vector3(sgn * 0.250, -0.205, -0.046), Vector3(0.078, 0.080, 0.046), skin, 0.0, false, Vector3.ZERO, false, 0.008)
		for fi in range(4):
			_part(upper, "finger" + sfx + str(fi), Vector3(sgn * 0.250 - 0.026 + float(fi) * 0.017, -0.257, -0.046), Vector3(0.015, 0.052, 0.022), skin, 0.0, false, Vector3.ZERO, false, 0.005)
		_part(upper, "thumb" + sfx, Vector3(sgn * 0.250 - sgn * 0.046, -0.223, -0.058), Vector3(0.020, 0.046, 0.024), skin, 0.0, false, Vector3.ZERO, false, 0.006)
	# 及膝长大衣下摆（挂在躯干节点上；上沿顶到躯干底 1.03，下摆底 0.60，大腿在这个深度只摆 ±0.15，包得住）
	if long_coat:
		_part(upper, "coatSkirt", Vector3(0, -0.180, 0), Vector3(0.402, 0.430, 0.288), cloth, 0.0, false, Vector3.ZERO, false, 0.024)
		_part(upper, "coatHem", Vector3(0, -0.369, 0), Vector3(0.416, 0.054, 0.302), Color(0.30, 0.17, 0.10))
		_part(upper, "coatSeam", Vector3(0, -0.180, -0.148), Vector3(0.024, 0.420, 0.014), cloth.darkened(0.45))
		_part(upper, "coatBackSlit", Vector3(0, -0.240, 0.148), Vector3(0.30, 0.300, 0.012), Color(0.05, 0.05, 0.05))
		_part(upper, "coatBtn1", Vector3(0.050, -0.120, -0.150), Vector3(0.030, 0.030, 0.014), Color(0.62, 0.60, 0.52))
		_part(upper, "coatBtn2", Vector3(0.050, -0.215, -0.150), Vector3(0.030, 0.030, 0.014), Color(0.62, 0.60, 0.52))
		for pp in [-0.108, 0.108]:
			_part(upper, "coatPocket" + ("L" if pp < 0 else "R"), Vector3(pp, -0.232, -0.147), Vector3(0.108, 0.092, 0.014), cloth.darkened(0.22))
	# 每人的随身物（区分剪影）
	match nm:
		"林岚":
			# 工具盒挂在左手下方，手正好在提手上（原来悬在胯边、手碰不到）
			_part(upper, "case", Vector3(-0.262, -0.360, -0.02), Vector3(0.25, 0.19, 0.34), Color(0.55, 0.34, 0.16))
			_part(upper, "caseLid", Vector3(-0.262, -0.258, -0.02), Vector3(0.22, 0.032, 0.30), Color(0.30, 0.32, 0.34))
			_part(upper, "caseSeam", Vector3(-0.262, -0.300, -0.02), Vector3(0.256, 0.012, 0.346), Color(0.30, 0.20, 0.10))
			_part(upper, "caseGrip", Vector3(-0.255, -0.222, -0.02), Vector3(0.036, 0.062, 0.036), Color(0.10, 0.10, 0.12))
		"周砚":
			# 监听耳机挂在脖子上：颈带 + 两个耳罩
			_part(upper, "headband", Vector3(0, 0.498, 0.012), Vector3(0.300, 0.048, 0.250), Color(0.10, 0.10, 0.12))
			for ex3 in [-0.128, 0.128]:
				_part(upper, "muff" + ("L" if ex3 < 0 else "R"), Vector3(ex3, 0.470, 0.010), Vector3(0.062, 0.105, 0.100), Color(0.10, 0.10, 0.12))
		"陈默":
			# 公文包挂在右手下方
			_part(upper, "brief", Vector3(0.255, -0.365, -0.02), Vector3(0.22, 0.24, 0.10), Color(0.17, 0.13, 0.10))
			_part(upper, "briefLid", Vector3(0.255, -0.250, -0.02), Vector3(0.19, 0.03, 0.06), Color(0.35, 0.30, 0.20))
			_part(upper, "briefGrip", Vector3(0.255, -0.215, -0.02), Vector3(0.036, 0.060, 0.036), Color(0.30, 0.26, 0.18))
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
	return {"name": nm, "node": n, "accent": accent, "show_round": show_round, "label": lbl,
		"upper": upper, "head": hp, "mouth": mth}

func _part_loft(parent: Node3D, nm: String, profile: Array, col: Color, segments := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = CharBody.loft(profile, segments)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.78
	mi.material_override = m
	parent.add_child(mi)
	return mi

func _band_profile(y0: float, y1: float, rx: float, rz: float) -> Array:
	return [Vector3(y0, rx, rz), Vector3(y1, rx, rz)]

## NPC 躯干放样（相对 upper 关节）：腰 0.171、胸 0.205、肩部收口
func _npc_profile() -> Array:
	return [
		Vector3(-0.020, 0.174, 0.108),
		Vector3(0.030, 0.168, 0.104),
		Vector3(0.100, 0.163, 0.102),
		Vector3(0.180, 0.172, 0.107),
		Vector3(0.280, 0.186, 0.115),
		Vector3(0.360, 0.199, 0.122),
		Vector3(0.420, 0.205, 0.125),
		Vector3(0.460, 0.198, 0.121),
		Vector3(0.480, 0.184, 0.113),
	]

func _part(parent: Node3D, nm: String, p: Vector3, size: Vector3, col: Color,
		emis := 0.0, tube := false, rot := Vector3.ZERO, ball := false, bev := 0.0,
		bot := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	if bev > 0.0:
		mi.mesh = CharBody.bev_box(size, bev)
	elif ball:
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 8
		sm.rings = 4
		mi.mesh = sm
		mi.scale = size
	elif tube:
		var cm := CylinderMesh.new()
		cm.top_radius = size.x * 0.5
		cm.bottom_radius = size.x * 0.5 if bot <= 0.0 else bot
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
	mi.rotation = rot
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
	cut_phase = ""
	stop_train()
	got_this_round.clear()
	if round_summary != null:
		round_summary.visible = false
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
	_show_round_card()
	# 人物出现
	for np in npcs:
		np["node"].visible = (np["show_round"] >= 0 and np["show_round"] <= round)
	# 物品出现
	for it in items:
		it["node"].visible = (int(it["def"]["round"]) <= round and not it["got"])
	# 序章
	if round == -1:
		_say("旁白", "十七年前，父亲在事故责任书上签了字。今晚，你第一次坐进他的调度席。")
		_say("站内广播", "23:50。岚桥站最后一班车即将进站。……你接管夜班调度席。0017 次，进二道。")
		_say("旁白", "按流程做完交接：确认进路，签值班簿，然后等车。林岚——你妹妹——还在信号室。")
	elif round == 0:
		_say("旁白", "23:50。还是那个时间。广播里那句「按调度席指令执行」，是父亲的声音。")
		_say("旁白", "站台上只有一个人没有在等车。她拎着一个工具盒，站在信号室门口——林岚，你妹妹。")
	elif round == 1:
		_say("旁白", "23:50。纸上的字还在，别的东西都回到原位。站台另一头，多了一个拎着录音笔的男人。")
	elif round == 2:
		_say("旁白", "23:50。三个人现在都有了模糊的熟悉感——他们不记得循环，但记得你。")
	else:
		_say("旁白", "23:50。最后一次。0017 次已经在进站信号里。你只有这 27 分钟。")

func _process(delta: float) -> void:
	_anim_npcs(delta)

	t_now += delta
	var reading := dialog.size() > 0 or bag_open or choice != null or (round_card != null and round_card.visible)
	if state == "play" and not reading:
		round_elapsed += delta
		clock_min += delta / SEC_PER_MIN
		_check_scripted()
		if clock_min >= T_ARRIVE:
			_begin_cutscene()
	elif state == "cutscene":
		_cutscene(delta)
	_animate_doors(delta)
	_animate_items(delta)
	_update_desk_props(delta)
	_update_tunnel_lamp(delta)
	_update_interaction()
	_update_prompt_ring(delta)
	_update_hud()
	map_acc += delta
	if map_acc >= 0.1:
		map_acc = 0.0
		_update_map()
	_update_sub(delta)
	if OS.has_feature("web"):
		web_perf_t += delta
		if web_perf_t >= 2.0:
			web_perf_t = 0.0
			print("[WEB] fps=", Engine.get_frames_per_second(), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func _check_scripted() -> void:
	if not train_started and clock_min >= T_TRAIN:
		train_started = true
		play_horn()
		_say("旁白", "隧道里有光。它来了。")
	if clock_min >= 1452.0 and not _once("warn"):
		_say("站内广播", "0017 次，岚桥站呼叫。前方四道占用，立即停车，等待人工引导。站台乘客请后退至黄线内。")
	# ---- 时间压力：离 00:16:43（T_LOCK）越近，三条提醒 + HUD 与调度台台上的钟一起变色/按秒跳 ----
	if clock_min >= T_LOCK - 2.0 and not _once("lock2m"):
		_say("旁白", "调度台上的钟指着 00:14:43。00:16:43 之前，进路必须锁死。")
	if clock_min >= T_LOCK - 0.5 and not _once("lock30s"):
		_say("旁白", "还有半分钟。")
		play_click()
	if clock_min >= T_LOCK and not _once("lockpass"):
		_say("旁白", "00:16:43 过去了。")

var _once_flags := {}
func _once(k: String) -> bool:
	if _once_flags.has(k):
		return true
	_once_flags[k] = true
	return false

# ------------------------------------------------------------------ 过场
const CUT_POS := Vector3(-4.5, 2.30, 14.0)
const CUT_LOOK := Vector3(4.6, 1.35, 1.0)

func _ensure_cutcam() -> void:
	if cutcam != null:
		return
	cutcam = Camera3D.new()
	cutcam.fov = 62.0
	cutcam.near = 0.05
	cutcam.far = 420.0
	add_child(cutcam)
func _begin_cutscene() -> void:
	state = "cutscene"
	cut_phase = "out"
	cut_t = 0.0
	train_started = true
	play_train()
	player.can_move = false
	player.dragging = false
	_say("旁白", "")

func _cutscene(delta: float) -> void:
	cut_t += delta
	match cut_phase:
		"out":
			hud_fade.modulate.a = clampf(cut_t / 0.28, 0.0, 1.0)
			if cut_t >= 0.34:
				_ensure_cutcam()
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
				if not _once("brakepass"): play_brake()
				cut_phase = "end"
				cut_t = 0.0
		"end":
			hud_fade.modulate.a = clampf(cut_t / 0.36, 0.0, 1.0)
			if cut_t >= 0.42:
				cut_phase = ""
				_after_cutscene()
		"preview":
			_ensure_cutcam()
			# 小角度弧线：只轻轻划过 ±26°，不是绕圈
			var k := clampf(cut_t / 5.2, 0.0, 1.0)
			var ang := preview_base + (k - 0.5) * 0.9
			cutcam.position = preview_center + Vector3(cos(ang) * preview_r, preview_h, sin(ang) * preview_r)
			cutcam.look_at(preview_center + Vector3(0, 0.05, 0))
			hud_fade.modulate.a = clampf(1.0 - cut_t / 0.45, 0.0, 1.0)
			if cut_t >= 5.2:
				cut_phase = "out2"
				cut_t = 0.0
		"dv_out":
			hud_fade.modulate.a = 1.0
			if cut_t >= 0.55:
				_ensure_cutcam()
				cutcam.position = Vector3(16.6, 3.40, -78.0)
				cutcam.look_at(Vector3(6.0, 0.8, -104.0))
				cutcam.current = true
				train.set_divert(true)
				train.place(_dv_s0)
				train.lights_on(true)
				cut_phase = "dv_run"
				cut_t = 0.0
		"dv_run":
			_ensure_cutcam()
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
				play_brake()
				stop_train()
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
	stop_train()
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
	_show_round_summary(hook)

func _round_found_line() -> String:
	var found := []
	for k in got_this_round.keys():
		found.append(String(k))
	if not found.is_empty():
		var s := ""
		for f in found:
			if s != "": s += "、"
			s += f
		return s
	if round == -1:
		var done := 0
		for b in buttons:
			if bool(b["done"]): done += 1
		return "无新线索（交接流程 %d/3）" % done
	return "无新线索"

func _round_reset_reason() -> String:
	match round:
		-1: return "列车没有停。它驶进了废弃四道，时间回到 23:50。"
		0: return "0017 没有进站，屏幕只剩「列车位置未知」。"
		1: return "你听到了「三道有人」，但 0017 还是没停。"
		2: return "你拿到了钥匙和巡检簿，但还差五号继电器。"
		_: return ""

func _show_round_summary(text: String) -> void:
	if round_summary == null:
		_show_hook(text)
		return
	var i := clampi(round + 1, 0, ROUND_NAMES.size() - 1)
	round_summary_title.text = String(ROUND_NAMES[i]) + " · 结算"
	round_summary_body.text = text + "\n\n本轮发现：" + _round_found_line() + "\n为什么重来：" + _round_reset_reason()
	round_summary_foot.text = "[E / 空格] 继续"
	hud_end.text = ""
	hud_end.modulate.a = 0.0
	round_summary.visible = true
	play_chime(0.72, -14.0)
	round_summary.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(round_summary, "modulate:a", 1.0, 0.5)
func _show_hook(text: String) -> void:
	hud_end_title.text = ""
	hud_end.text = text
	hud_end.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
	hud_end.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(hud_end, "modulate:a", 1.0, 0.5)
func _resolve_final() -> void:
	state = "ending"
	play_chime(0.75, -12.0)
	if handle and not late:
		_show_final_choice()
	else:
		_show_end("C")

func _show_final_choice() -> void:
	if round_summary != null:
		round_summary.visible = false
	_fade_to(0.0, 0.7)
	hud_end_title.text = "最后的决定"
	hud_end.text = "列车停住了。天亮之前，只剩一件事要你决定。\n\n公开真相：19 个名字会被看见，父亲可以洗清；但这条线会被关掉，林岚和陈默会失去现在的生活。\n封存：车站和活下来的人可以继续；但 19 个人会永远「失踪」，父亲永远背着那份报告。\n\n[E] 公开真相　　[R] 封存"
	hud_end.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	choice = {"key_a": KEY_E, "key_b": KEY_R}
	chooser_a = "A"
	chooser_b = "B"

func _end_hook() -> void:
	if round_summary != null:
		round_summary.visible = false
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
				_ensure_cutcam()
				cutcam.position = Vector3(16.6, 3.40, -78.0)
				cutcam.look_at(Vector3(6.0, 0.8, -104.0))
				cutcam.current = true
				train.set_divert(true)
				train.place(_dv_s0)
				train.lights_on(true)
				cut_phase = "dv_run"
				cut_t = 0.0
		"dv_run":
			_ensure_cutcam()
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
	stop_train()
	if round_summary != null:
		round_summary.visible = false
	_fade_to(0.0, 0.7)
	# 彩蛋：结局文字里那把钥匙的去向，在场景里真的出现
	if ending_key_cab != null:
		ending_key_cab.visible = (kind == "B")
	if ending_key_desk != null:
		ending_key_desk.visible = (kind == "A")
	shown_end = kind
	state = "ending"
	hud_end_title.add_theme_color_override("font_color", Color(0.88, 0.64, 0.29))
	var lan_a := "林岚站了出来，把工牌放在桌上。" if lan_trust else "林岚没有来。她的工位空着。"
	var tape_a := "周砚把录音播了出去，节目开头第一次没有配乐。" if tape_air else "周砚把录音锁进了抽屉。"
	var bag_a := "陈默走进调查室时，把停用钥匙放在了桌上。" if bag_return else "陈默带着钥匙离开了。"
	var lan_b := "林岚在清晨第一班车前重新校准五号继电器。" if not lan_trust else "林岚把工牌收进抽屉，没再看你。"
	var tape_b := "周砚删掉了录音。" if not tape_air else "周砚把那段录音留在了自己的硬盘里，没有播。"
	var bag_b := "陈默把钥匙留在失物招领柜。" if not bag_return else "陈默把钥匙带回了隧道。"
	if kind == "A":
		hud_end_title.text = "结局 A · 零点之后"
		hud_end.text = "00:16:43，手动进路被取消。\n00:17，工程车与三道隔离。0017 在二道停稳，车门没有打开。\n\n「本次列车暂停服务。今晚的延误不是故障，是一份迟到了十七年的记录。」\n\n第二天，林远舟的名字从事故责任人一栏移出。\n" + lan_a + "\n" + tape_a + "\n" + bag_a
	elif kind == "B":
		hud_end_title.text = "结局 B · 最后一班"
		hud_end.text = "00:16:50，0017 被手动送进检修环线。空工程车驶入四道。\n\n「设备故障已排除，0017 次取消运行。请乘客改乘接驳车辆，感谢配合。」\n\n今晚没有人伤亡。公开通报没有出现任何人的名字。\n" + lan_b + "\n" + tape_b + "\n" + bag_b
	elif kind == "C":
		hud_end_title.text = "结局 C · 第二十八个 00:17"
		hud_end.text = "00:17。0017 次没有停。\n\n你又一次回到 23:50。钟还在走，五号继电器还在慢半拍。\n\n这一次，你连那 19 个名字都没能带出来。"
	hud_end.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(hud_end, "modulate:a", 1.0, 0.8)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player != null:
		player.allow_capture = false

# ------------------------------------------------------------------ 对话 / 交互
func _interact() -> void:
	if prompt != null:
		ring_flash = 1.0      # 目标脚下那一圈闪一下，确认这一下按下去了
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
		lan_trust = allow
		choice_text = ""
		if allow:
			_give_clue(0)
			_say("林岚", "工牌划过端口的一瞬间，红灯迟了半秒才亮。")
			_say("旁白", "获得「红灯延迟记录」。")
		else:
			_say("林岚", "你最好记住这半秒。")
			dialog_npc["said"] = false
	elif chooser_a == "air":
		tape_air = allow
		choice_text = ""
		play_click()
		if allow:
			_say("周砚", "……好。我会播。但你别指望所有人都会感谢你。")
		else:
			_say("周砚", "我把带子删掉。今晚之后，没有人会再听见它。")
	elif chooser_a == "return":
		bag_return = allow
		choice_text = ""
		play_click()
		if allow:
			_say("陈默", "……谢谢。至少让我把包还给他。")
		else:
			_say("陈默", "钥匙我带走。它不该留在这里。")

func _give_clue(idx: int) -> void:
	var it: Dictionary = items[idx]
	it["got"] = true
	it["node"].visible = false
	got_this_round[String(it["def"]["name"])] = true
	print("[0017] 获得 ", it["def"]["name"])
	play_chime(1.12, -8.0)

func _pickup(it: Dictionary) -> void:
	it["got"] = true
	it["node"].visible = false
	got_this_round[String(it["def"]["name"])] = true
	play_chime(0.92, -11.0)
	_cost(10)
	_say("旁白", "你把「" + str(it["def"]["name"]) + "」收进值班服口袋。它比看起来重。")

func _talk(np: Dictionary) -> void:
	if round == 0 and np["name"] == "林岚":
		dialog = [
			"你回来了。爸的名字还挂在事故责任栏里。",
			"五号继电器的反馈慢了半秒。和十七年前一样。",
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
			"十七年前，我叫邵国安。三道里那 19 个人，有我弟弟。只有我出来了。",
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
		choice_text = "[E] 允许她接入旧继电器端口　[R] 拒绝"
		hud_prompt.text = choice_text
	elif nm == "周砚":
		_give_clue(1)
		_say("周砚", "三道有人，改四道。")
		_say("旁白", "可官方报告写着——三道无人。获得「倒放广播」。")
		choice = {"key_a": KEY_E, "key_b": KEY_R}
		chooser_a = "air"; chooser_b = "delete"
		choice_text = "[E] 让他把录音播出去　[R] 让他删掉"
		hud_prompt.text = choice_text
	elif nm == "陈默":
		_give_clue(2); _give_clue(3)
		_say("陈默", "三道有人。不是车，是人。十七年前我叫邵国安；那 19 个人里，有我弟弟。只有我出来了。")
		_say("旁白", "获得「停用钥匙」和「巡检簿」。")
		choice = {"key_a": KEY_E, "key_b": KEY_R}
		chooser_a = "return"; chooser_b = "keep"
		choice_text = "[E] 把包还给他　[R] 留下钥匙"
		hud_prompt.text = choice_text

func _press_button(idx: int) -> void:
	var b: Dictionary = buttons[idx]
	if b["done"]:
		return
	b["done"] = true
	b["mat"].emission_energy_multiplier = 2.6
	play_relay(1.0)
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
			play_relay(0.82)
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
				play_relay(0.62)
				_say("旁白", "手柄推不动。继电器没有响。")
				return
			play_relay(1.08)
			_cost(60)
			if clock_min >= T_LOCK:
				late = true
				_say("旁白", "手柄推到底了。可继电器没有响——它比它该有的时间，慢了半秒。")
			else:
				handle = true
				_say("调度台", "进路已锁。0017 次，二道停车。")
		"board":
			_read_board()
		"divert":
			if not (_has_clue(2) or _has_clue(3)):
				_say("旁白", "道岔锁着。锁扣上刻着两个字：停用。得有那把钥匙，或者巡检簿上的记录。")
				return
			divert = true
			_cost(35)
			play_relay(0.90)
			_set_switch_green(true)
			_say("旁白", "钥匙插进锁孔，锁扣弹开。道岔扳过去的时候，钢轨在黑暗里挪了一寸。")
			_say("站内广播", "进路变更。0017 次，改走检修环线。")
		"pc":
			_open_pc()
		"studio_mic":
			play_chime(0.55, -12.0)
			_say("广播台", "……电流声。麦克风还开着。")
			if round == 1:
				_say("周砚", "别对着它说话。它会录下来。")
		"studio_dial":
			studio_freq_idx = (studio_freq_idx + 1) % 3
			play_relay(0.70)
			if studio_freq_idx == 2:
				if round >= 1:
					_say("广播台", "……0017。无信号。\n……三道有人。改四道。")
					if not _has_clue(1):
						_give_clue(1)
						_say("旁白", "收音机里传来一句倒放的话。获得「倒放广播」。")
				else:
					_say("广播台", "……0017。无信号。……三道有人。改四道。")
					_say("旁白", "你听见了一句不该出现在这个时间的话。")
			elif studio_freq_idx == 0:
				_say("广播台", "88.7 岚桥交通台：……末班车……")
			else:
				_say("广播台", "101.7 夜间节目：……谁弄丢了 0017……")
		"studio_onair":
			studio_onair_on = not studio_onair_on
			play_relay(0.90)
			if studio_onair_mat != null:
				studio_onair_mat.emission_energy_multiplier = 2.6 if studio_onair_on else 0.2
			_say("广播台", "ON AIR 灯亮了。整座站台都能听见你。" if studio_onair_on else "ON AIR 灯灭了。")
		"studio_tape":
			if not _has_clue(1):
				_say("广播台", "磁带架最上层有一盘没有标签的带子。背面写着：2009.11.03 / 三道。")
				_say("旁白", "把频率调到 0017，也许能听见它。")
			else:
				_say("广播台", "磁带架上空了一格。标签还在：2009.11.03 / 三道。")

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
	if choice != null and state == "play":
		hud_prompt.text = choice_text
		return
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

## 交互目标脚下的「呼吸环」：以前只有 HUD 上一行 [E] 文字，世界里的东西不说话。
## 现在给当前目标在地面投影一圈琥珀色光环（呼吸），按下 E 的一瞬间整圈高亮 1 秒。
func _make_prompt_ring() -> void:
	prompt_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.200
	tm.outer_radius = 0.245
	tm.rings = 28                # 绕一圈 28 段（少了会变成方框，第一版 rings=4 渲出来是个菱形）
	tm.ring_segments = 4      # 截面 4 边：低多边形，跟站体的棱面感一致
	prompt_ring.mesh = tm
	prompt_ring_mat = StandardMaterial3D.new()
	prompt_ring_mat.albedo_color = Color(0.95, 0.72, 0.34, 0.5)
	prompt_ring_mat.emission_enabled = true
	prompt_ring_mat.emission = Color(0.95, 0.72, 0.34)
	prompt_ring_mat.emission_energy_multiplier = 0.75
	prompt_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	prompt_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	prompt_ring.material_override = prompt_ring_mat
	prompt_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	prompt_ring.visible = false
	add_child(prompt_ring)

func _update_prompt_ring(delta: float) -> void:
	if prompt_ring == null:
		return
	ring_flash = maxf(0.0, ring_flash - delta)
	var p := Vector3.ZERO
	var ok := false
	if prompt != null:
		match String(prompt["kind"]):
			"item":
				p = prompt["it"]["node"].global_position
				ok = true
			"npc":
				p = prompt["npc"]["node"].global_position
				ok = true
			"button":
				p = buttons[int(prompt["idx"])]["node"].global_position
				ok = true
			"door":
				p = prompt["door"]["spot"]
				ok = true
			"spot":
				p = prompt["spot"]["pos"]
				ok = true
	if not ok:
		prompt_ring.visible = false
		return
	# 环要贴在地板上：从目标往上一点往下打一条射线，用命中的那个面当"地面"
	var fy := p.y
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.4, 0), p + Vector3(0, -6.0, 0))
	q.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		fy = float(hit["position"].y)
	prompt_ring.visible = true
	prompt_ring.global_position = Vector3(p.x, fy + 0.025, p.z)
	var t := float(Time.get_ticks_msec()) * 0.001
	var breathe := sin(t * 3.4)
	var br := 1.0 + 0.055 * breathe + ring_flash * 0.30
	prompt_ring.scale = Vector3(br, 1.0, br)
	prompt_ring_mat.albedo_color.a = clampf(0.42 + 0.16 * breathe + ring_flash * 0.5, 0.0, 1.0)
	prompt_ring_mat.emission_energy_multiplier = 0.75 + 0.30 * breathe + ring_flash * 1.5
## 调度台台面上的三件小物件：保温杯 / 值班日志 / 老式电话。
## 台面高度 1.15（和 ITEM_DEFS 里那两件线索摆在同一个面上）。
func _make_desk_props() -> void:
	var root3 := Node3D.new()
	root3.name = "DeskProps"
	add_child(root3)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.56, 0.59, 0.63); steel.roughness = 0.34; steel.metallic = 0.45
	var steelD := StandardMaterial3D.new()
	steelD.albedo_color = Color(0.30, 0.32, 0.35); steelD.roughness = 0.5; steelD.metallic = 0.3
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.84, 0.82, 0.76); paper.roughness = 0.85
	var cover := StandardMaterial3D.new()
	cover.albedo_color = Color(0.20, 0.22, 0.26); cover.roughness = 0.75
	var phoneM := StandardMaterial3D.new()
	phoneM.albedo_color = Color(0.30, 0.11, 0.11); phoneM.roughness = 0.55
	var bakelite := StandardMaterial3D.new()
	bakelite.albedo_color = Color(0.13, 0.13, 0.15); bakelite.roughness = 0.45
	# ① 保温杯（杯身 + 杯盖圈 + 一圈深色腰线）
	_item_part(root3, Vector3(0.084, 0.20, 0.084), Vector3(-16.72, 1.25, -12.60), steel, true)
	_item_part(root3, Vector3(0.090, 0.035, 0.090), Vector3(-16.72, 1.367, -12.60), steelD, true)
	_item_part(root3, Vector3(0.090, 0.020, 0.090), Vector3(-16.72, 1.19, -12.60), steelD, true)
	# ② 值班日志（深色封皮 + 露出来的纸口 + 一支笔）
	_item_part(root3, Vector3(0.24, 0.030, 0.32), Vector3(-16.55, 1.166, -12.30), cover)
	_item_part(root3, Vector3(0.222, 0.018, 0.30), Vector3(-16.55, 1.190, -12.30), paper)
	_item_part(root3, Vector3(0.014, 0.014, 0.20), Vector3(-16.62, 1.206, -12.34), bakelite)
	# ③ 老式电话（机身 + 拨号盘 + 听筒 + 指示灯）—— 彩蛋：指示灯按「三短一长」闪
	_item_part(root3, Vector3(0.17, 0.075, 0.28), Vector3(-16.74, 1.187, -15.30), phoneM)
	_item_part(root3, Vector3(0.13, 0.020, 0.13), Vector3(-16.74, 1.229, -15.24), bakelite, true)
	_item_part(root3, Vector3(0.075, 0.055, 0.075), Vector3(-16.74, 1.252, -15.24), cover, true)
	_item_part(root3, Vector3(0.145, 0.040, 0.062), Vector3(-16.74, 1.245, -15.46), bakelite)
	_item_part(root3, Vector3(0.145, 0.040, 0.062), Vector3(-16.74, 1.245, -15.14), bakelite)
	_item_part(root3, Vector3(0.050, 0.030, 0.035), Vector3(-16.74, 1.245, -15.30), bakelite)
	desk_phone_mat = StandardMaterial3D.new()
	desk_phone_mat.albedo_color = Color(0.85, 0.72, 0.40)
	desk_phone_mat.emission_enabled = true
	desk_phone_mat.emission = Color(0.95, 0.78, 0.40)
	desk_phone_mat.emission_energy_multiplier = 1.4
	_item_part(root3, Vector3(0.026, 0.026, 0.026), Vector3(-16.680, 1.228, -15.200), desk_phone_mat)

## 老式电话的指示灯：三短一长（= 检修暗号里那个「三/四」的节奏），周期 3.2 秒。
func _update_desk_props(delta: float) -> void:
	if desk_phone_mat == null:
		return
	desk_phone_t = fposmod(desk_phone_t + delta, 3.2)
	var on := false
	if desk_phone_t < 0.20:
		on = true
	elif desk_phone_t >= 0.45 and desk_phone_t < 0.65:
		on = true
	elif desk_phone_t >= 0.90 and desk_phone_t < 1.10:
		on = true
	elif desk_phone_t >= 1.35 and desk_phone_t < 2.05:
		on = true
	desk_phone_mat.emission_energy_multiplier = 1.6 if on else 0.05
## 环线隧道东墙上那盏坏灯（level.gd 里三盏壁灯中间那盏是 "dark"）。
## 彩蛋：它不是彻底死掉，而是「大多数时候亮着、偶尔整段掉下去」，亮的时候还在轻微抖。
func _make_tunnel_lamp() -> void:
	var root3 := Node3D.new()
	root3.name = "TunnelLamp"
	add_child(root3)
	tun_lamp_mat = StandardMaterial3D.new()
	tun_lamp_mat.albedo_color = Color(0.55, 0.70, 0.86)
	tun_lamp_mat.emission_enabled = true
	tun_lamp_mat.emission = Color(0.45, 0.70, 0.95)
	tun_lamp_mat.emission_energy_multiplier = 1.0
	_item_part(root3, Vector3(0.030, 0.080, 0.900), Vector3(11.945, 0.870, -61.300), tun_lamp_mat)
	tun_lamp_light = OmniLight3D.new()
	tun_lamp_light.position = Vector3(11.45, 0.62, -61.30)
	tun_lamp_light.light_color = Color(0.62, 0.72, 0.92)
	tun_lamp_light.light_energy = 1.5
	tun_lamp_light.omni_range = 7.5
	tun_lamp_light.shadow_enabled = false
	root3.add_child(tun_lamp_light)

func _update_tunnel_lamp(_delta: float) -> void:
	if tun_lamp_mat == null:
		return
	tun_lamp_t += _delta
	var t := tun_lamp_t
	# 两个不同周期的正弦相乘 → 不规律的"大部分亮、偶尔断"
	var slow := sin(t * 0.90) * sin(t * 0.37 + 2.0)
	var on := slow > -0.25
	var v := (0.85 + 0.15 * sin(t * 11.0)) if on else 0.10
	tun_lamp_mat.emission_energy_multiplier = 1.05 * v
	if tun_lamp_light != null:
		tun_lamp_light.light_energy = 1.55 * v
## 每轮开头的「第 N 轮」卡片：淡入 0.35s → 停 1.9s → 淡出 0.55s
const ROUND_HINTS := ["接管夜班调度席 · 按流程做完交接", "林岚说，红灯亮了，但慢了半秒",
	"周砚的录音里，有一句被剪掉的话", "陈默还带着那只包", "0017 次，二道停车"]
func _show_round_card() -> void:
	if round_card == null:
		return
	var i := clampi(round + 1, 0, ROUND_NAMES.size() - 1)
	round_card_title.text = String(ROUND_NAMES[i])
	round_card_sub.text = String(ROUND_HINTS[i]) if i < ROUND_HINTS.size() else ""
	round_card.visible = true
	play_chime(0.90, -14.0)
	round_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(round_card, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.9)
	tw.tween_property(round_card, "modulate:a", 0.0, 0.55)
	tw.tween_callback(func() -> void: round_card.visible = false)
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
	hud_cam.visible = (player.cam_mode >= 2)
	if player.cam_mode == 2:
		hud_cam.text = "● 第二人称 · 正面看着你     [V] 切换视角"
	elif player.cam_mode == 3:
		hud_cam.text = "● %s  %s   [N] 换机位" % [player.cctv_tag(), player.cctv_name()]
	# 时钟：橙 → 红 随剩余时间推进；最后 30 秒里按秒跳一下（不再是一个静态颜色）
	var tleft := T_LOCK - clock_min
	var tcol := Color(0.88, 0.64, 0.29).lerp(Color(0.95, 0.22, 0.18), clampf(1.0 - tleft / 2.0, 0.0, 1.0))
	var beat := 1.0
	if tleft <= 0.5 and tleft > 0.0:
		beat = 0.55 + 0.45 * (1.0 - fposmod(clock_min * 60.0, 1.0))
	hud_clock.add_theme_color_override("font_color", Color(tcol.r * beat, tcol.g * beat, tcol.b * beat, 1.0))
	if clock_label != null:
		clock_label.text = "%02d:%02d" % [mm / 60, mm % 60]
		clock_label.modulate = Color(tcol.r * beat, tcol.g * beat, tcol.b * beat, 1.0)
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
	if saw_lag:
		obs.append({"text": "监控里那半秒（CAM 07 岔区）", "pos": Vector3(8.0, 0.0, -112.0), "done": true})
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
	if state == "minigame":
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			_close_pc()
		return
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
			match player.cam_mode:
				0: _say("旁白", "视角：第一人称")
				1: _say("旁白", "视角：第三人称")
				2: _say("旁白", "视角：第二人称 · 正面看着你（鼠标上下 = 绕看）")
				3: _say("旁白", "视角：监视器 %s（%s）· [N] 换机位" % [player.cctv_tag(), player.cctv_name()])
		elif event.physical_keycode == KEY_N:
			if player.cam_mode == 3:
				player.next_cctv()
				_say("旁白", "监视器 %s（%s）" % [player.cctv_tag(), player.cctv_name()])
				_cctv_tip()
		elif event.physical_keycode == KEY_M:
			if state == "play":
				_toggle_cctv_review()
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
	_refresh_clue_board()
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

func _make_pc_overlay() -> void:
	pc_layer = CanvasLayer.new()
	pc_layer.layer = 20
	add_child(pc_layer)
	pc_overlay = MinesGame.new()
	pc_layer.add_child(pc_overlay)
	pc_overlay.call("setup", font)
	pc_overlay.visible = false
	pc_overlay.connect("closed", _close_pc)

func _open_pc() -> void:
	if pc_overlay == null:
		return
	pc_overlay.call("new_game")
	pc_overlay.visible = true
	state = "minigame"
	player.can_move = false
	player.allow_capture = false
	player.dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	hud_prompt.text = ""

func _close_pc() -> void:
	if pc_overlay == null:
		return
	pc_overlay.visible = false
	state = "play"
	player.can_move = true
	player.allow_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.visible = true

func _make_duty_computer() -> void:
	var root3 := Node3D.new(); root3.name = "DutyComputer"; add_child(root3)
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.06, 0.07, 0.08); dark.roughness = 0.70
	var metal := StandardMaterial3D.new(); metal.albedo_color = Color(0.38, 0.40, 0.42); metal.metallic = 0.8; metal.roughness = 0.35
	var green := StandardMaterial3D.new(); green.albedo_color = Color(0.04, 0.20, 0.10)
	green.emission_enabled = true; green.emission = Color(0.20, 0.95, 0.55); green.emission_energy_multiplier = 1.8
	_item_part(root3, Vector3(0.52, 0.36, 0.20), Vector3(-15.8, 1.21, 3.24), dark)
	_item_part(root3, Vector3(0.42, 0.28, 0.012), Vector3(-15.8, 1.22, 3.345), green)
	_item_part(root3, Vector3(0.44, 0.022, 0.14), Vector3(-15.8, 1.075, 3.50), dark)
	_item_part(root3, Vector3(0.18, 0.42, 0.20), Vector3(-15.8, 0.80, 3.22), dark)
	_item_part(root3, Vector3(0.03, 0.03, 0.012), Vector3(-15.8, 0.84, 3.325), green)
	var lbl := Label3D.new(); lbl.font = font; lbl.text = "值班终端"; lbl.font_size = 48
	lbl.pixel_size = 0.012; lbl.modulate = Color(0.55, 0.95, 0.70); lbl.position = Vector3(-15.8, 1.46, 3.34)
	root3.add_child(lbl)

func _make_studio_props() -> void:
	var root3 := Node3D.new(); root3.name = "StudioProps"; add_child(root3)
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.06, 0.07, 0.08); dark.roughness = 0.70
	var metal := StandardMaterial3D.new(); metal.albedo_color = Color(0.38, 0.40, 0.42); metal.metallic = 0.8; metal.roughness = 0.35
	studio_onair_mat = StandardMaterial3D.new(); studio_onair_mat.albedo_color = Color(0.32, 0.04, 0.04)
	studio_onair_mat.emission_enabled = true; studio_onair_mat.emission = Color(0.95, 0.12, 0.10); studio_onair_mat.emission_energy_multiplier = 0.2
	_item_part(root3, Vector3(0.028, 0.34, 0.028), Vector3(-16.0, 1.08, 34.0), metal, true)
	_item_part(root3, Vector3(0.060, 0.060, 0.060), Vector3(-16.0, 1.28, 34.0), dark, true)
	_item_part(root3, Vector3(0.090, 0.018, 0.090), Vector3(-15.35, 0.945, 34.6), metal, true)
	_item_part(root3, Vector3(0.028, 0.040, 0.028), Vector3(-15.35, 0.97, 34.6), metal, true)
	_item_part(root3, Vector3(0.040, 0.260, 0.520), Vector3(-11.58, 2.15, 36.5), studio_onair_mat)
	_item_part(root3, Vector3(0.340, 0.100, 0.240), Vector3(-19.2, 1.28, 42.5), dark)
	_item_part(root3, Vector3(0.080, 0.080, 0.080), Vector3(-19.30, 1.36, 42.5), metal, true)
	_item_part(root3, Vector3(0.080, 0.080, 0.080), Vector3(-19.10, 1.36, 42.5), metal, true)
	_item_part(root3, Vector3(0.040, 0.020, 0.040), Vector3(-19.2, 1.35, 42.63), studio_onair_mat)
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
	# 继电器：两下短促的机械声
	var n_relay := int(rate * 0.22)
	var relay := PackedFloat32Array(); relay.resize(n_relay)
	for i in range(n_relay):
		var tr := float(i) / rate
		var vr := rng.randf_range(-1.0, 1.0) * exp(-tr * 45.0) * 0.55
		vr += sin(TAU * 2200.0 * tr) * exp(-tr * 130.0) * 0.28
		if tr > 0.06:
			var ur := tr - 0.06
			vr += rng.randf_range(-1.0, 1.0) * exp(-ur * 55.0) * 0.45
			vr += sin(TAU * 1800.0 * ur) * exp(-ur * 140.0) * 0.22
		relay[i] = clampf(vr, -1.0, 1.0) * 0.8
	sfx_relay = _wav(relay, false)
	relay_player = _make_sfx_player(sfx_relay, -7.0)
	# 门铃 / 线索提示：880 + 660
	var n_chime := int(rate * 0.9)
	var chime := PackedFloat32Array(); chime.resize(n_chime)
	for i in range(n_chime):
		var tc := float(i) / rate
		var vc := sin(TAU * 880.0 * tc) * exp(-tc * 4.5) * 0.32 + sin(TAU * 1320.0 * tc) * exp(-tc * 6.0) * 0.14
		if tc > 0.12:
			var uc := tc - 0.12
			vc += sin(TAU * 660.0 * uc) * exp(-uc * 3.8) * 0.28
		chime[i] = clampf(vc, -1.0, 1.0)
	sfx_chime = _wav(chime, false)
	chime_player = _make_sfx_player(sfx_chime, -9.0)
	# 脚步：短噪声 + 低频落地
	var n_step := int(rate * 0.1)
	var step := PackedFloat32Array(); step.resize(n_step)
	var lp_step := 0.0
	for i in range(n_step):
		var ts := float(i) / rate
		lp_step = lp_step * 0.72 + rng.randf_range(-1.0, 1.0) * 0.28
		var vs := lp_step * exp(-ts * 55.0) * 0.8 + sin(TAU * 95.0 * ts) * exp(-ts * 40.0) * 0.32
		step[i] = clampf(vs, -1.0, 1.0) * 0.8
	sfx_step = _wav(step, false)
	step_player = _make_sfx_player(sfx_step, -13.0)
	# 汽笛：220 + 277 + 440
	var n_horn := int(rate * 1.1)
	var horn := PackedFloat32Array(); horn.resize(n_horn)
	for i in range(n_horn):
		var th := float(i) / rate
		var envh := minf(th / 0.05, 1.0) * exp(-maxf(th - 0.15, 0.0) * 2.2)
		var vh := (sin(TAU * 220.0 * th) + 0.55 * sin(TAU * 277.0 * th) + 0.25 * sin(TAU * 440.0 * th)) * envh * 0.35
		horn[i] = clampf(vh, -1.0, 1.0)
	sfx_horn = _wav(horn, false)
	horn_player = _make_sfx_player(sfx_horn, -8.0)
	# 刹车：高频下滑 + 噪声
	var n_brake := int(rate * 0.9)
	var brake := PackedFloat32Array(); brake.resize(n_brake)
	var phase_brake := 0.0
	for i in range(n_brake):
		var tb := float(i) / rate
		var fb := lerpf(3200.0, 1500.0, clampf(tb / 0.9, 0.0, 1.0))
		phase_brake += TAU * fb / float(rate)
		var vb := sin(phase_brake) * exp(-tb * 1.8) * 0.10 + rng.randf_range(-1.0, 1.0) * exp(-tb * 2.5) * 0.08
		brake[i] = clampf(vb, -1.0, 1.0)
	sfx_brake = _wav(brake, false)
	brake_player = _make_sfx_player(sfx_brake, -10.0)
	# 列车低频轰鸣：4 秒循环
	var n_rumble := rate * 4
	var rumble := PackedFloat32Array(); rumble.resize(n_rumble)
	var lp_rumble := 0.0
	for i in range(n_rumble):
		var tu := float(i) / rate
		lp_rumble = lp_rumble * 0.92 + rng.randf_range(-1.0, 1.0) * 0.08
		var am := 0.72 + 0.28 * sin(TAU * 0.5 * tu)
		var vu := (sin(TAU * 42.0 * tu) * 0.32 + sin(TAU * 57.0 * tu) * 0.18 + lp_rumble * 0.55) * am
		rumble[i] = clampf(vu, -1.0, 1.0) * 0.55
	sfx_train = _wav(rumble, true)
	train_player = _make_sfx_player(sfx_train, -7.0)

func _make_sfx_player(stream: AudioStream, vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = vol
	add_child(p)
	return p

func play_relay(pitch := 1.0) -> void:
	if relay_player != null:
		relay_player.pitch_scale = clampf(pitch, 0.6, 1.4)
		relay_player.play()

func play_chime(pitch := 1.0, vol := -9.0) -> void:
	if chime_player != null:
		chime_player.pitch_scale = clampf(pitch, 0.6, 1.4)
		chime_player.volume_db = vol
		chime_player.play()

func play_step(running := false) -> void:
	if step_player != null:
		step_player.pitch_scale = randf_range(0.92, 1.08)
		step_player.volume_db = -10.0 if running else -14.0
		step_player.play()

func play_horn() -> void:
	if horn_player != null:
		horn_player.play()

func play_brake() -> void:
	if brake_player != null:
		brake_player.play()

func play_train() -> void:
	if train_player != null and not train_player.playing:
		train_player.play()

func stop_train() -> void:
	if train_player != null:
		train_player.stop()

func _on_footstep(running: bool) -> void:
	play_step(running)

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
	var warn := _label(menu, 0, Vector2(240, 770), Vector2(1120, 44), 14, Color(0.98,0.62,0.26))
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.text = "当前浏览器使用软件渲染（SwiftShader），帧率会很低。请在浏览器设置中开启「使用图形加速」后重开页面。"
	warn.visible = web_gpu_is_software
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
	if hud != null: hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.allow_capture = true

func _show_menu() -> void:
	state = "menu"
	if hud != null: hud.visible = false
	menu.hide_all()
	menu.visible = true
	menu.center.visible = true
	menu.set_slots(slots_info(), "load")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player != null:
		player.allow_capture = false
		player.dragging = false

func _on_start() -> void:
	if round_summary != null:
		round_summary.visible = false
	stop_train()
	round = -2
	_once_flags.clear()
	power = false; sr_open = false; handle = false; late = false; divert = false; shown_end = ""
	lan_trust = false; tape_air = false; bag_return = false; studio_onair_on = false; studio_freq_idx = 0; choice_text = ""
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
	if hud != null: hud.visible = true
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
	play_train()
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

## NPC 微动：呼吸起伏 + 头转向玩家（限幅）+ 说话时小幅点头
func _anim_npcs(delta: float) -> void:
	if npcs.size() == 0 or player == null:
		return
	var t := float(Time.get_ticks_msec()) * 0.001
	var k := clampf(delta * 3.2, 0.0, 1.0)
	for i in range(npcs.size()):
		var np: Dictionary = npcs[i]
		var n: Node3D = np["node"]
		if not n.visible:
			continue
		var up: Node3D = np.get("upper")
		var hd: Node3D = np.get("head")
		if up == null or hd == null:
			continue
		up.position.y = 0.995 + sin(t * 1.15 + float(i) * 2.1) * 0.009        # 呼吸
		# 朝玩家转头（超过 9 m 或不在身前就回正）
		var rel: Vector3 = n.global_transform.basis.inverse() * (player.eye() - (n.global_position + Vector3(0, 1.60, 0)))
		var want := 0.0
		if rel.length() < 9.0:
			var ang := atan2(-rel.x, -rel.z)
			if absf(ang) < 1.5:
				want = clampf(ang, -0.72, 0.72)
		hd.rotation.y = lerpf(hd.rotation.y, want, k)
		# 正在跟他说话 → 小幅点头
		var nod := 0.0
		if dialog_npc == np and hud_sub != null and hud_sub.visible:
			nod = sin(t * 6.2) * 0.05
		hd.rotation.x = lerpf(hd.rotation.x, nod, clampf(delta * 6.0, 0.0, 1.0))
		# 说话时嘴动：一秒钟开合七次（张嘴时高度 x2.1、下唇再压 8mm）
		var mth: MeshInstance3D = np.get("mouth")
		if mth != null:
			var opening := 0.0
			if dialog_npc == np and hud_sub != null and hud_sub.visible:
				opening = 1.0 if fposmod(t * 7.0, 1.0) < 0.45 else 0.18
			var kk := clampf(delta * 15.0, 0.0, 1.0)
			mth.scale.y = lerpf(mth.scale.y, 1.0 + opening * 1.10, kk)
			mth.position.y = lerpf(mth.position.y, -0.056 - opening * 0.008, kk)

# ------------------------------------------------------------------ 值班台回看监控（M）
## 站在值班台前按 M：接上站内监控；再按 M 退出。岔区那台机位能看见「红灯晚了半秒」
func _toggle_cctv_review() -> void:
	if player.cam_mode == 3:
		player.exit_cctv()
		_say("旁白", "断开监控，回到你自己的视角。")
		return
	var desk := Vector3(-16.95, 0.0, -13.85)          # 值班台（调度台）中心
	if player.global_position.distance_to(desk) > 3.2:
		_say("旁白", "要回看监控，得站在值班台前。")
		return
	player.enter_cctv()
	_say("旁白", "接上站内监控。[N] 换机位　[M] 断开")
	_cctv_tip()

func _cctv_tip() -> void:
	if player.cam_mode != 3:
		return
	if player.cctv_i == 6 and not saw_lag:            # CAM 07 = 岔区
		saw_lag = true
		_say("旁白", "岔区机位 CAM 07：红灯亮了。\n可是比它该亮的时刻——晚了半秒。")
	elif player.cctv_i == 7 and not _once("cam8chalk"):   # CAM 08 = 检修环线
		_say("旁白", "环线机位 CAM 08：检修走道东墙上，有人用粉笔写了一行——00:16:43。")

## 值班记录板：钉在值班台后墙上，五件记录按时间轴依次钉上去；
## 另有两张附加卡——站台的「值班记录」（一直在）与监控里那半秒（在岔区机位看见后才出现）
func _make_clue_board() -> void:
	board_root = Node3D.new()
	board_root.name = "ClueBoard"
	add_child(board_root)
	var frame_m := StandardMaterial3D.new()
	frame_m.albedo_color = Color(0.13, 0.14, 0.16); frame_m.roughness = 0.8
	var cork_m := StandardMaterial3D.new()
	cork_m.albedo_color = Color(0.19, 0.15, 0.11); cork_m.roughness = 0.95
	var zc := BOARD_Z0 + BOARD_DZ * 3.0
	_item_part(board_root, Vector3(0.06, 0.98, 4.70), Vector3(BOARD_X - 0.03, 2.30, zc), frame_m)
	_item_part(board_root, Vector3(0.03, 0.88, 4.60), Vector3(BOARD_X + 0.01, 2.30, zc), cork_m)
	_item_part(board_root, Vector3(0.02, 0.028, 4.30), Vector3(BOARD_X + 0.03, 2.02, zc), frame_m)
	var t := Label3D.new()
	t.font = font; t.text = "0017 · 值班记录板"; t.font_size = 96
	t.pixel_size = 0.052 / 96.0 * 2.2
	t.modulate = Color(0.92, 0.95, 1.0); t.outline_size = 8
	t.position = Vector3(BOARD_X + 0.05, 2.60, zc)
	t.rotation.y = PI * 0.5
	board_root.add_child(t)
	var card_m := StandardMaterial3D.new()
	card_m.albedo_color = Color(0.80, 0.81, 0.83); card_m.roughness = 0.92
	var empty_m := StandardMaterial3D.new()
	empty_m.albedo_color = Color(0.06, 0.07, 0.08); empty_m.roughness = 0.95
	# 7 个卡位：0..4 = 五件记录；5 = 站台值班记录；6 = 监控里那半秒
	for i in range(7):
		var c := Node3D.new()
		c.position = Vector3(BOARD_X + 0.03, 2.30, BOARD_Z0 - BOARD_DZ * float(i))
		board_root.add_child(c)
		_item_part(c, Vector3(0.014, 0.46, 0.52), Vector3.ZERO, card_m)
		var lab := Label3D.new()
		lab.font = font; lab.font_size = 96
		lab.pixel_size = 0.030 / 96.0 * 2.2
		lab.modulate = Color(0.10, 0.11, 0.14); lab.outline_size = 0
		lab.position = Vector3(0.02, 0.02, 0)
		lab.rotation.y = PI * 0.5
		c.add_child(lab)
		var pin_m := StandardMaterial3D.new()
		pin_m.albedo_color = Color(0.70, 0.20, 0.18)
		pin_m.emission_enabled = true
		pin_m.emission = Color(0.80, 0.26, 0.22)
		pin_m.emission_energy_multiplier = 0.9
		if i < 5:
			pin_m.albedo_color = ITEM_DEFS[i]["col"]
			pin_m.emission = ITEM_DEFS[i]["col"]
		_item_part(c, Vector3(0.024, 0.024, 0.024), Vector3(0.02, 0.20, 0), pin_m)
		var blank := Node3D.new()
		blank.name = "blank"
		c.add_child(blank)
		board_cards.append({"node": c, "label": lab, "blank": blank})

func _refresh_clue_board() -> void:
	if board_cards.size() == 0:
		return
	for i in range(board_cards.size()):
		var bc: Dictionary = board_cards[i]
		var c: Node3D = bc["node"]
		var lab: Label3D = bc["label"]
		var show := false
		if i < 5:
			show = _has_clue(i)
			if show:
				lab.text = "%s\n%s" % [String(ITEM_DEFS[i]["name"]), String(ITEM_DEFS[i]["short"])]
		elif i == 5:
			show = true                                  # 站台上那块「值班记录」一直在
			lab.text = "值班记录\n00:16:43 手动进路\n记录人 林远舟"
		else:
			show = saw_lag                               # 监控里那半秒
			lab.text = "监控 CAM 07\n红灯 晚了半秒"
		c.visible = show

func _read_board() -> void:
	var got_n := _got_count()
	var txt := "值班记录板：已钉 %d / 5 条记录。" % got_n
	for i in range(ITEM_DEFS.size()):
		if _has_clue(i):
			txt += "\n· " + String(ITEM_DEFS[i]["name"])
	if saw_lag:
		txt += "\n· 监控里那半秒（CAM 07 岔区）"
	if got_n >= 5:
		txt += "\n\n五条记录连起来：00:16:43 那道手动进路，本来就不该存在。"
	_say("旁白", txt)

## 彩蛋：两把「停用钥匙」的落点。A 结局放回调度台面（原文「放在桌上」），B 结局留在失物招领柜格子（原文「留在失物招领柜」）
func _make_ending_props() -> void:
	var kd := {"id": "key", "col": Color(0.88, 0.64, 0.29)}
	ending_key_cab = _make_item_model(kd)
	ending_key_cab.position = Vector3(-17.760, 0.392, -32.290)   # 柜子第 2 格，摆在层板上
	add_child(ending_key_cab)
	ending_key_cab.visible = false
	ending_key_desk = _make_item_model(kd)
	ending_key_desk.position = Vector3(-16.98, 1.156, -12.62)   # 调度台台面
	add_child(ending_key_desk)
	ending_key_desk.visible = false
