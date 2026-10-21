extends Node
## 第一夜：时间轴 + 交互 + 记事本。
## 剧本 9-D 第一夜：23:40 进门 → 00:00 广播去「请」→ 01:10 老太太 → 03:10 数衣服。

const A := preload("res://scripts/laundry/laundry_art.gd")
const Figure := preload("res://scripts/laundry/figure.gd")

const START_MIN := 23 * 60 + 40      # 23:40
const END_MIN := 28 * 60             # 04:00（跨零点用连续分钟数）
const RATE := 16.0                   # 1 真实秒 = 16 游戏秒

var player
var drums: Dictionary = {}
var world: Node3D

var t_night := 0.0                   # 从 23:40 起算的游戏秒
var fired: Dictionary = {}

var ui: CanvasLayer
var lbl_clock: Label
var lbl_prompt: Label
var lbl_sub: Label
var panel: Panel
var nb_body: RichTextLabel
var nb_btns: Array = []
var nb_page := 0
var nb_open := false

var entries := {"人": [], "物": [], "话": [], "疑": []}
var _sub_until := 0.0
var _near: Dictionary = {}
var _focus: Dictionary = {}
var spinning := {7: true}
var npc: Node3D = null
var f2           # Floor2 实例：门 / 毛衣 / 滚筒都在它身上
var art_ref      # LaundryArt：新角色要用它建材质
var br           # 后房实例
var door_back := 0.0
var has_back_key := false
var back_open := false
var npc_t := -1.0

# ---------------------------------------------------------------- 交互点
var POINTS := [
	{"id": "board", "pos": Vector3(-3.00, 1.75, 12.0), "p": "看公告栏", "pg": "物",
		"t": "三张纸三个年代。2003 年停水通知、2011 年拆迁补偿公告、2024 年「本楼禁止入内」。\n"
		+ "最下面那张的落款单位被撕掉了——只剩一道撕口。"},
	{"id": "box503", "pos": Vector3(-3.00, 1.35, 4.62), "p": "看 503 信箱", "pg": "疑",
		"t": "一百二十个信箱，锈死八十七个。\n只有这一格的锁是新的，铜色还亮着。"},
	{"id": "booth", "pos": Vector3(-0.75, 1.30, 9.00), "p": "进传达室", "pg": "物",
		"t": "电视永远在下雪。桌上摊着一本登记簿，最后一页的签名停在 2004-11-07。\n后面的纸被撕掉了。"},
	{"id": "elev", "pos": Vector3(2.85, 1.30, -6.00), "p": "看废电梯", "pg": "疑",
		"t": "门半开着，里面是黑的。轿厢卡在三楼，往下看是一条竖井。\n贴着门缝，能听见水声。"},
	{"id": "mail", "pos": Vector3(-2.95, 1.40, 3.20), "p": "拉信箱", "pg": "物",
		"t": "有几格能拉开，里面都是 1998 到 2004 年的水电费单。\n户名一栏，一直写着同一个名字。"},
	{"id": "mark", "pos": Vector3(2.70, 1.32, 12.60), "p": "看墙上的刻线", "pg": "物",
		"t": "铅笔画的几道身高线，最高的那道旁边写着：「秀兰 1.32」。\n再往上一片空白。"},
	{"id": "exit1", "pos": Vector3(-0.55, 1.25, -9.70), "p": "走出去", "pg": "话",
		"t": "（走出去，今晚就算结束了。回出租屋。）"},
	{"id": "price", "pos": Vector3(-2.20, 5.40, 2.10), "p": "看价目表", "pg": "物",
		"t": "洗一次，从 3 元改到 8 元，改了四次。最后一行是铅笔写的：\n「7号机 = 专用」"},
	{"id": "cash", "pos": Vector3(-2.10, 4.70, 8.95), "p": "开收银机", "pg": "物",
		"t": "抽屉是开的。三枚硬币：1998、1998、2019。\n有人在二十年后，还往里投过币。"},
	{"id": "ruler", "pos": Vector3(0.95, 4.20, 9.95), "p": "看门框", "pg": "物",
		"t": "门框内侧一排铅笔刻线，一年一条，都写着年份。\n最后一条刻在 2004 年，1.32 米。之后没有了。"},
	{"id": "m3", "pos": Vector3(-2.35, 4.20, 6.60), "p": "看 3 号机", "pg": "疑",
		"t": "滚筒在空转，里面什么都没有。\n玻璃内侧有一个手印——小孩的手，五指张开，是往外按的。"},
	{"id": "m9", "pos": Vector3(2.35, 4.20, 4.60), "p": "看 9 号烘干机", "pg": "物",
		"t": "滚筒里卡着一张洗衣单。\n2004-11-07，7 号机，童装一套，未取。"},
	{"id": "bin", "pos": Vector3(2.90, 3.90, 9.50), "p": "翻垃圾桶", "pg": "疑",
		"t": "全是童装。一件一件，都在 1.3 米上下。\n没有一件是收走的。"},
	{"id": "mirror", "pos": Vector3(3.00, 5.00, 5.50), "p": "照镜子", "pg": "疑",
		"t": "镜子里有整个店。\n但是它照不出 7 号机。"},
	{"id": "backdoor", "pos": Vector3(-1.20, 4.50, 2.05), "p": "推后房门", "pg": "疑",
		"t": "锁着。门缝里有风，是往里吹的。"},
	{"id": "keyring", "pos": Vector3(-2.90, 5.05, -0.62), "p": "拿钥匙串", "pg": "物",
		"t": "锅炉顶上挂着一串钥匙。第三把是新的——其余都锈死了。"},
	{"id": "m7", "pos": Vector3(0.00, 4.25, 2.75), "p": "看 7 号机", "pg": "疑",
		"t": "滚筒在转。里面有一件藏青色的童装毛衣，袖口是白条纹。\n它不跟着转——筒在转，它悬在正中间。"},

	# ══════════════════════════════════════════════════════════════════
	# 4F · 唯一活着的一层（402 老周家 / 403 杂物间 / 走廊）
	# 坐标来自 _night/交互点清单_4F5F屋顶B1.md（场景侧按实际几何量过）
	# 这些点在第二夜起才对玩家有意义，但坐标现在就注册好，剧情层直接按 id 取。
	# ══════════════════════════════════════════════════════════════════
	{"id": "locks402", "pos": Vector3(-2.10, 11.30, 5.32), "p": "看 402 门上的锁", "pg": "疑",
		"t": "五把锁，五个牌子，牌子上写的不是人名，是日期。\n最早那把锈死了，最近那把还有油。"},
	{"id": "waterwall", "pos": Vector3(-0.92, 11.40, 4.00), "p": "看那墙水表", "pg": "物",
		"t": "九只水表，走针全都停在同一个刻度。\n有一只是新的，指针归零。"},
	{"id": "radio402", "pos": Vector3(-1.42, 11.10, 2.62), "p": "听收音机", "pg": "疑",
		"t": "它一直在响，但只有一段：\n「……下面播送今晚的天气。预计明天，晴。」\n没有台名，没有日期。"},
	{"id": "pipe_map", "pos": Vector3(-3.12, 11.60, 4.30), "p": "看墙上的管线图", "pg": "物",
		"t": "一整面手绘的全楼管线图。每一根管子都标了口径、走向、阀门编号。\n"
		+ "最底下那根通到「B1 蓄水池」，旁边用红笔写着：勿动。"},
	{"id": "sewing", "pos": Vector3(-0.10, 10.80, 3.08), "p": "看缝纫机", "pg": "疑",
		"t": "一台老式脚踏缝纫机。台面上搭着一件没缝完的小毛衣——藏青色，袖口两道白条。\n"
		+ "它和 7 号机里那件，是同一件。"},
	{"id": "burned_box", "pos": Vector3(0.44, 10.40, 4.64), "p": "翻烧了一半的纸箱", "pg": "疑",
		"t": "纸箱烧掉了一半，切口是齐的，像被什么东西一次性切断。\n里面全是小孩衣服，一件不少，按尺码排好。"},
	{"id": "evac_map", "pos": Vector3(3.12, 11.72, 7.30), "p": "看疏散示意图", "pg": "疑",
		"t": "全楼的疏散图。每层都标了出口。\nB1 那格标着一个「安全出口」——但那里，没有出口。"},

	# ══════════════════════════════════════════════════════════════════
	# 5F · 空屋、门缝、消防梯
	# ══════════════════════════════════════════════════════════════════
	{"id": "floor502", "pos": Vector3(-1.70, 13.10, 3.50), "p": "蹲下看地板", "pg": "疑",
		"t": "地板中央有一块被水泡过的痕迹，两米见方。\n形状像一个人躺着——头、肩、手臂张开的位置，都对得上。"},
	{"id": "skylight502", "pos": Vector3(-1.70, 13.40, 3.50), "p": "抬头看天窗", "pg": "物",
		"t": "一块 1.2 米见方的天窗，正对着地板那块水痕。\n玻璃上有几道雨渍，是很久以前的。"},
	{"id": "seam503", "pos": Vector3(1.70, 13.06, 5.30), "p": "看 503 的门缝", "pg": "疑",
		"t": "门缝底下有一道黄光。\n今晚在楼下的时候，这道光灭过一次。"},
	{"id": "shoes503", "pos": Vector3(1.60, 13.02, 5.10), "p": "看门口的鞋", "pg": "疑",
		"t": "四双鞋，一字排开。三双干的。\n最里面那双童鞋是湿的——但今天没下雨。"},
	{"id": "toys503", "pos": Vector3(1.70, 13.20, 3.50), "p": "看地上的小洗衣机", "pg": "疑",
		"t": "七台玩具洗衣机，围成一个圈，全部朝着门。\n圈中间用红蜡笔画了一个「8」。"},
	{"id": "wetbed503", "pos": Vector3(2.10, 13.30, 2.40), "p": "看那张床", "pg": "疑",
		"t": "一张单人床。床垫上有一个人的凹陷。\n凹陷是湿的。摸上去，还是温的。"},

	# ══════════════════════════════════════════════════════════════════
	# 屋顶 · 水箱 / 晾衣绳 / 天窗
	# ══════════════════════════════════════════════════════════════════
	{"id": "tank", "pos": Vector3(-3.60, 17.20, 8.00), "p": "看水箱", "pg": "疑",
		"t": "铁皮水箱，三米高。从检修口看进去——\n水是满的。水面离口沿大约二十公分。"},
	{"id": "clothes", "pos": Vector3(-0.40, 18.20, 3.60), "p": "数晾衣绳上的衣服", "pg": "疑",
		"t": "八条晾衣绳。上面挂着七件衣服。\n全部是童装。全部是同一款。\n第八条绳，是空的。"},
	{"id": "roof_patch", "pos": Vector3(-3.20, 15.70, 8.40), "p": "看屋顶的补丁", "pg": "物",
		"t": "沥青防水层，有三处是新的补过的。\n补得很平整，像是刚补完不久。"},

	# ══════════════════════════════════════════════════════════════════
	# B1 · 锅炉房 / 蓄水池 / 竖井底
	# ══════════════════════════════════════════════════════════════════
	{"id": "boiler_burning", "pos": Vector3(-3.55, -1.90, -4.80), "p": "看还在烧的那台锅炉", "pg": "疑",
		"t": "两台锅炉。右边那台的观火孔里有光。\n这栋楼二十年没交过供暖费了。"},
	{"id": "valves", "pos": Vector3(-2.60, -1.60, -8.70), "p": "看这排阀门", "pg": "疑",
		"t": "七个阀门手轮，全部拧在同一个角度。\n每个下面贴着一张纸条，手写的两个字：勿动。"},
	{"id": "b1_fuse", "pos": Vector3(0.05, -1.50, -8.75), "p": "看配电盘", "pg": "疑",
		"t": "一排保险丝，少了一根。\n空着的那个位置，用粉笔标了个小小的「5」。"},
	{"id": "pool", "pos": Vector3(2.70, -1.20, 1.35), "p": "看蓄水池", "pg": "疑",
		"t": "四米见方的混凝土池子。一道铁梯子下去。\n水面离地面大约一米二。\n——刚才好像更高一点。"},
	{"id": "waterline", "pos": Vector3(4.30, -1.60, 3.20), "p": "看池壁上的水线", "pg": "疑",
		"t": "池壁上有一圈铁锈色的水线，比现在的水面高出一米五。\n"
		+ "旁边用记号笔写着一个日期：2004-11-08。\n比池口还高——那晚，水是漫出来的。"},
	{"id": "five_pipes", "pos": Vector3(0.00, -1.30, 1.10), "p": "看这五根立管", "pg": "物",
		"t": "五根水管从头顶的黑暗里伸下来，全部通向楼上的洗衣店。\n管子上挂着一块手写的牌子：→ 洗衣店。"},
	{"id": "notice", "pos": Vector3(3.20, -1.55, -4.30), "p": "看墙上的通知", "pg": "疑",
		"t": "一张纸，贴得很牢，二十年没掉。\n「停水通知　2004-11-08　01:40」\n下面一行小字，是后来补上去的：未送达。"},
	{"id": "sandal", "pos": Vector3(3.05, -2.80, -5.60), "p": "捡起那只凉鞋", "pg": "疑",
		"t": "一只童鞋。蓝色，小小的，鞋底还带着干掉的泥。\n只有一只。"},
]

func setup(p, d: Dictionary, w: Node3D, floor2 = null, back = null, art = null) -> void:
	player = p
	drums = d
	world = w
	f2 = floor2
	br = back
	art_ref = art
	_build_ui()
	_note("人", "许砚", "今晚十一点四十，进楼。")
	_say("旁白", "门在身后合上。楼道里没有灯，只有二楼有一点响动。")

# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var font := load("res://assets/fonts/NotoSansSC-Regular.otf")

	lbl_clock = Label.new()
	lbl_clock.add_theme_font_override("font", font)
	lbl_clock.add_theme_font_size_override("font_size", 22)
	lbl_clock.add_theme_color_override("font_color", Color(0.86, 0.88, 0.90))
	lbl_clock.position = Vector2(34, 26)
	ui.add_child(lbl_clock)

	lbl_prompt = Label.new()
	lbl_prompt.add_theme_font_override("font", font)
	lbl_prompt.add_theme_font_size_override("font_size", 17)
	lbl_prompt.add_theme_color_override("font_color", Color(0.95, 0.93, 0.84))
	lbl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl_prompt.position = Vector2(-160, -150)
	lbl_prompt.size = Vector2(320, 30)
	ui.add_child(lbl_prompt)

	lbl_sub = Label.new()
	lbl_sub.add_theme_font_override("font", font)
	lbl_sub.add_theme_font_size_override("font_size", 18)
	lbl_sub.add_theme_color_override("font_color", Color(0.90, 0.91, 0.93))
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_sub.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl_sub.position = Vector2(-420, -110)
	lbl_sub.size = Vector2(840, 80)
	ui.add_child(lbl_sub)

	# 记事本
	panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-380, -240)
	panel.size = Vector2(760, 480)
	panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.058, 0.066, 0.96)
	sb.border_color = Color(0.28, 0.30, 0.34)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	ui.add_child(panel)

	var pages := ["人", "物", "话", "疑"]
	for i in range(pages.size()):
		var bt := Button.new()
		bt.text = pages[i]
		bt.add_theme_font_override("font", font)
		bt.add_theme_font_size_override("font_size", 16)
		bt.position = Vector2(24 + i * 92, 18)
		bt.size = Vector2(80, 34)
		bt.pressed.connect(_tab.bind(i))
		panel.add_child(bt)
		nb_btns.append(bt)

	nb_body = RichTextLabel.new()
	nb_body.add_theme_font_override("normal_font", font)
	nb_body.add_theme_font_size_override("normal_font_size", 16)
	nb_body.bbcode_enabled = true
	nb_body.position = Vector2(26, 70)
	nb_body.size = Vector2(708, 386)
	nb_body.scroll_active = true
	panel.add_child(nb_body)
	_tab(0)

func _tab(i: int) -> void:
	nb_page = i
	var names := ["人", "物", "话", "疑"]
	for k in range(nb_btns.size()):
		nb_btns[k].modulate = Color(1, 1, 1) if k == i else Color(0.55, 0.56, 0.60)
	var arr: Array = entries[names[i]]
	var s := ""
	if arr.is_empty():
		s = "[color=#6c7078]（还是空的）[/color]"
	for e in arr:
		s += "[color=#c8b06a]" + str(e[0]) + "[/color]\n" + str(e[1]) + "\n\n"
	nb_body.text = s

func _note(page: String, key: String, body: String) -> void:
	var arr: Array = entries[page]
	for e in arr:
		if e[0] == key:
			return
	arr.append([key, body])
	if nb_open:
		_tab(nb_page)

func _say(who: String, text: String) -> void:
	lbl_sub.text = ("【" + who + "】" if who != "旁白" else "") + text
	_sub_until = t_night + 9.0
	_note("话", who + "｜" + text.substr(0, 10), "【" + who + "】" + text)

# ---------------------------------------------------------------- 主循环
func _process(dt: float) -> void:
	_anim_doors(dt)
	if t_night < (END_MIN - START_MIN) * 60.0:
		t_night += dt * RATE
	var m: float = START_MIN + t_night / 60.0
	lbl_clock.text = _hhmm(m)
	if t_night > _sub_until:
		lbl_sub.text = ""
	_timeline(m)
	_spin(dt)
	_npc_step(dt)
	_find_focus()

func _anim_doors(dt: float) -> void:
	if f2 == null:
		return
	var target := 1.25 if back_open else 0.0
	door_back = lerpf(door_back, target, clampf(dt * 2.2, 0.0, 1.0))
	if f2.doors.has("back") and f2.doors["back"] != null:
		f2.doors["back"].rotation.y = door_back

func _hhmm(m: float) -> String:
	var mm := int(fmod(m, 24.0 * 60.0))
	return "%02d:%02d" % [mm / 60, mm % 60]

func _spin(dt: float) -> void:
	for k in spinning.keys():
		if drums.has(k):
			var d: Node3D = drums[k]
			d.rotation.z += dt * 2.6

# ---------------------------------------------------------------- 时间轴
func _timeline(m: float) -> void:
	var e := int(m - START_MIN)   # 分钟
	if e >= 1 and _once("bc1"):
		_say("广播", "本店自助洗衣，二十四小时营业。夜间请勿使用七号机。")
	if e >= 20 and _once("bc2"):
		_say("广播", "本店自助洗衣，二十四小时营业。夜间勿使用七号机。")
		_say("旁白", "……它把「请」字去掉了。")
		spinning[1] = true
		spinning[2] = true
		spinning[3] = true
		_say("旁白", "1、2、3 号机自己转了起来。加上 7 号机，一共七台。")
	if e >= 90 and _once("oldlady"):
		_spawn_lady()
		_say("旁白", "门开了。一个老太太走进来，浑身是湿的——可是外面没有下雨。")
	if e >= 210 and _once("count"):
		lady_count()
		_say("她", "一件……两件……三件……")
		_say("旁白", "她在数布袋里的衣服。数到第五件，停了很久。")
	if e >= 220 and _once("ask"):
		lady_ask()
		_say("她", "是不是洗好了？")
	if e >= 250 and _once("dawn"):
		_say("旁白", "天开始亮了。店里的灯一盏一盏回到正常。")
		for k in spinning.keys():
			spinning[k] = false
		if npc != null:
			npc.visible = false
		if lady != null:
			lady.set_process(false)

func _once(k: String) -> bool:
	if fired.has(k):
		return false
	fired[k] = true
	return true

# ---------------------------------------------------------------- 老太太（周秀兰）
## 正式模型 assets/models/chars/ZhouXiulan_Anim.glb（1.56 m，9 个动作）。
## 旧模型 OldLady_Final.glb 不再使用 —— 它没有骨架，不能播动作。
const Actor := preload("res://scripts/laundry/char_actor.gd")

## 长椅实测（bench_01 世界顶点分析，见 _bench_exact）：
##   椅子 x 1.690…2.165，座面顶 y ≈ 3.990 → **座面高 0.490 m**
##   椅背在 +X 侧 → 人面朝 −X；座面 z 5.880…8.120
## 实测数据（_sit_world 直接读骨架世界坐标）：
##   SitIdle 骨盆在 3.5 + 0.04 + 0.528 = 4.068；座面顶 3.990 → 骨盆高 7.8 cm（正常坐姿）
##   脚踝 3.650、ToeBase 3.592 → 鞋底约 3.56，比地面高 6 cm
## 所以**不要动整体偏移**（会把她压进椅面）；6 cm 悬空在坐姿里读不出来
## （长椅前有踏脚钢板 + 大衣下摆盖住膝盖以下）。extra_y 保持 0。
const SEAT_H := 0.490
const SIT_EXTRA_Y := 0.0
const SIT_POS := Vector3(1.80, 3.5, 6.25)
## 模型正面 +Z；要面朝 −X → yaw = −PI/2
const SIT_YAW := -PI * 0.5

var lady = null                 # LaundryActor（char_actor.gd）
var lady_state := ""            # "" / "walk" / "sit" / "count" / "ask"
var _lady_walk_t := 0.0

func _spawn_lady(animate_entry := true) -> void:
	lady = Actor.make(world, "zhou", Vector3(0.0, 3.5, 9.90), PI, 0.0)
	if lady == null:
		return
	npc = lady                    # 老接口：测试与剧情都读 npc
	npc_t = 0.0
	lady_state = "walk"
	# 全身是湿的：一盏冷色小灯贴在她身上（剧本要求"浑身是湿的"）
	var l := OmniLight3D.new()
	l.position = Vector3(0, 1.10, 0.14)
	l.light_color = Color(0.44, 0.54, 0.68)
	l.light_energy = 0.42
	l.omni_range = 2.0
	npc.add_child(l)
	# 门口那一下：开门动作
	if animate_entry and lady.has_anim("OpenDoor"):
		lady.play("OpenDoor", 0.0)
		var tw := create_tween()
		tw.tween_interval(0.9)
		tw.tween_callback(func(): if lady != null: lady.play("Walk", 0.25))

func _npc_step(dt: float) -> void:
	if npc == null or npc_t < 0.0 or lady == null:
		return
	npc_t += dt
	match lady_state:
		"walk":
			# 从门口走到长椅（6 秒），动作 Walk
			_lady_walk_t += dt
			var p0 := Vector3(0.0, 3.5, 9.90)
			var p1 := SIT_POS + Vector3(-.65, 0.0, 0.0)
			var k := clampf(_lady_walk_t / 6.0, 0.0, 1.0)
			var e := k * k * (3.0 - 2.0 * k)
			npc.global_position = p0.lerp(p1, e)
			# 走路途中朝前进方向（模型正面 +Z，所以朝 −Z 走 → yaw = PI）
			if k < 0.85:
				lady.face_yaw(PI, dt)          # 从门口往 −Z 走
			else:
				lady.face_yaw(SIT_YAW, dt)
			if lady.current != "Walk" and lady.has_anim("Walk"):
				lady.play("Walk", 0.25)
			if k >= 1.0:
				lady_state = "sit"
				_do_sit()
		"sit":
			pass
		"count":
			pass
		"ask":
			pass

func _do_sit() -> void:
	if lady.global_position.distance_to(SIT_POS)>1.1:lady.global_position = SIT_POS
	else:create_tween().tween_property(lady,"global_position",SIT_POS,.65).set_trans(Tween.TRANS_SINE)
	lady.face_yaw(SIT_YAW, 0.0)
	# 这动作的坐姿脚会离地 8 cm，往下沉一点让鞋底贴地（骨盆仍在座面上方）
	lady.extra_y = SIT_EXTRA_Y
	# 骨骼混合到校准SitIdle，不使用末帧仍站立的来源SitDown。
	lady.sit(SEAT_H)

## 剧情钩子（first_night._timeline 调用）
func lady_count() -> void:
	lady_state = "count"
	if lady != null:
		lady.sit_idle() # 保持已校准坐姿，不能切换站立的低头动作。

func lady_ask() -> void:
	lady_state = "ask"
	if lady != null:
		lady.sit_idle()

func lady_stand_leave() -> void:
	if lady != null:
		lady.stand()
		lady_state = "leave"

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92
	return m

func _box(p: Node3D, pos: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	p.add_child(mi)

# ---------------------------------------------------------------- 交互
func _find_focus() -> void:
	var best: Dictionary = {}
	var best_d := 99.0
	var eye: Vector3 = player.cam.global_position
	var fwd: Vector3 = player.look_dir()
	for pt in POINTS:
		var v: Vector3 = pt["pos"] - eye
		var d := v.length()
		if d > 2.6:
			continue
		if v.normalized().dot(fwd) < 0.55:
			continue
		if d < best_d:
			best_d = d
			best = pt
	_focus = best
	lbl_prompt.text = ("[E] " + str(best["p"])) if not best.is_empty() else ""

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.keycode
	if k == KEY_TAB:
		_toggle_nb()
		return
	if nb_open:
		if k == KEY_ESCAPE:
			_toggle_nb()
		return
	if k == KEY_E and not _focus.is_empty():
		var pt := _focus
		_use(str(pt["id"]), pt)
	if k == KEY_Q and not _focus.is_empty():
		_note("疑", str(_focus["p"]), "标记了一处可疑的地方。")

func _use(id: String, pt: Dictionary) -> void:
	match id:
		"backdoor":
			if not has_back_key:
				_say("旁白", "锁着。门缝里有风，是往里吹的。")
				_note("疑", "后房门", "锁着，但门缝里有风，是往里吹的。")
				return
			if back_open:
				_say("旁白", "门已经开着了。")
				return
			back_open = true
			_say("旁白", "钥匙对上了。门轴很涩，推的时候整间屋子都响了一下。")
			_note("物", "后房钥匙", "锅炉顶上那串，第三把对得上。")
		"keyring":
			has_back_key = true
			if br != null and br.keyring != null:
				br.keyring.visible = false
			_say("旁白", "锅炉顶上挂着一串钥匙。第三把是新的——其余都锈死了。")
			_note("物", "备用钥匙串", "锅炉顶上。第三把是新的。")
			return
		"m7":
			if not back_open:
				_say("旁白", "滚筒在转。里面有一件藏青色的童装毛衣，袖口是白条纹。
它不跟着转——筒在转，它悬在正中间。")
				_note("疑", "7 号机", "滚筒在转，里面那件衣服不跟着转。")
			else:
				_say("旁白", "门锁开了。你伸手进去，把那件毛衣拿了出来。
它还是干的。")
				_note("物", "藏青色童装毛衣", "7 号机里。干了二十年，还是干的。")
				if f2 != null and f2.sweater != null:
					f2.sweater.visible = false
				_claim()
			return
		"m9":
			pass
	var body: String = str(pt.get("t", ""))
	_say("旁白", body)
	if body != "":
		_note(str(pt.get("pg", "物")), str(pt.get("p", id)), body)

func _claim() -> void:
	if fired.has("claim"):
		return
	fired["claim"] = true
	_say("她", "……齐了。")
	_note("话", "她·齐了", "［她］……齐了。")
	await get_tree().create_timer(3.0).timeout
	_say("旁白", "她把布袋抱在怀里，走到门口，转身。")
	await get_tree().create_timer(3.4).timeout
	_say("她", "谢谢你啊。你叫什么名字？")
	fired["claimed"] = true

func _toggle_nb() -> void:
	nb_open = not nb_open
	panel.visible = nb_open
	player.active = not nb_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if nb_open else Input.MOUSE_MODE_CAPTURED
	_tab(nb_page)
