extends RefCounted
## 得利洗衣店 · 接入 0017 框架的「一局」
## ===================================================================
## 这个文件**不实现玩家、HUD、字幕、淡入、交互判定** —— 那些全部复用
## game.gd 里现成的那套（player.gd 654 行 + _make_hud + _update_interaction +
## prompt_ring + _say_seq + _fade_to）。
##
## 本文件只做三件事：
##   1. 把 laundry 那套场景几何挂进 game 的世界里（laundry_art / laundry_kit 建的那批模块）
##   2. 提供这一局的交互点（POINTS）与「点下去发生什么」（act）
##   3. 提供时间轴（第一夜 23:40 → 04:00 的剧本节点）
##
## 用法（在 game.gd 里）：
##   laundry = LaundryCase.new(self)
##   laundry.enter()          # 建场景 + 把玩家放到门厅
##   laundry.step(delta)      # 每帧（_process 里调）
##   laundry.interact(id)     # E 键（_act 里调）

const Art := preload("res://scripts/laundry/laundry_art.gd")
const Lobby := preload("res://scripts/laundry/floor1_lobby.gd")
const Stairs := preload("res://scripts/laundry/stairs.gd")
const Floor2 := preload("res://scripts/laundry/floor2_laundry.gd")
const Back2 := preload("res://scripts/laundry/floor2_backroom.gd")
const Floor3 := preload("res://scripts/laundry/floor3_flats.gd")
const StairsUp := preload("res://scripts/laundry/stairs_upper.gd")
const Floor4 := preload("res://scripts/laundry/floor4_flats.gd")
const Floor5 := preload("res://scripts/laundry/floor5_flats.gd")
const RoofDeck := preload("res://scripts/laundry/roof_deck.gd")
const Basement := preload("res://scripts/laundry/basement.gd")
const BackAlley := preload("res://scripts/laundry/back_alley.gd")
const MailOffice := preload("res://scripts/laundry/mail_office.gd")
const PowerRoom := preload("res://scripts/laundry/power_room.gd")
const Actor := preload("res://scripts/laundry/char_actor.gd")
const Cast := preload("res://scripts/laundry/story_cast.gd")

## 剧本 9-D 时间轴（游戏分钟，从 23:40 起算）
const START_MIN := 23 * 60 + 40
const RATE := 10.0        # 现实1分钟 = 游戏10分钟

var game                 # game.gd 实例
var art                  # LaundryArt
var world: Node3D        # 装洗衣店的根（独立于岚桥站，放在远处不打架）
var root_origin := Vector3.ZERO          # 洗衣店世界原点（保持 0，见 enter() 的注释）

var f2                   # Floor2（门 / 毛衣 / 滚筒）
var b2                   # 后房
var buildings := {}
var cast                 # story_cast
var night = null         # 第一夜（复用 first_night.gd 的交互点/时间轴）
var entered := false
var routes
var campaign
var rebuilt

## 时间轴状态
var t := 0.0             # 从 23:40 起算的游戏秒
var fired := {}
var back_open := false
var has_back_key := false
var spinning := {7: true}
var claimed := false

# ================================================================ 进入
func _init(g) -> void:
	game = g

func enter() -> void:
	if entered:
		return
	entered = true
	world = Node3D.new()
	world.name = "LaundryWorld"
	# ★ 必须放在**原点**。
	# 洗衣店所有模块（floor1_lobby / floor2_laundry / basement …）内部的
	# 坐标都是**绝对楼层坐标**（1F y=0 / 2F y=3.5 / B1 y=-3.0 …），
	# 而且 laundry_kit.model() 里的贴地计算用的是 _aabb() 的**世界**包围盒
	# （inst.position.y += pos.y - b2.position.y）。
	# 一旦 world 不在原点，这套算术全错 —— 实测表现就是
	# 「从出租屋出来以后，B1 的锅炉和 4F 的工具箱飘在 1F 门厅半空」。
	# 所以这里把它放回原点，改用「把岚桥站挪走」的方式来隔离两套场景。
	world.position = Vector3.ZERO
	game.add_child(world)

	art = Art.new(world)
	rebuilt = preload("res://scripts/laundry_rebuild.gd").new(self)
	rebuilt.build()

	# 三个剧情角色
	cast = Cast.new(art)
	cast.spawn_laozhou()
	cast.spawn_aqi()
	cast.spawn_xiulan()
	routes = preload("res://scripts/building_routes.gd").new()
	routes.setup(self)
	campaign = preload("res://scripts/laundry_campaign.gd").new()
	game.add_child(campaign)
	campaign.setup(self)

	# 把玩家放进 1F 门厅
	_place_player_at_entrance()

	print("[LAUNDRY] 场景已挂进 0017 框架 · 三角 ", art.done()["tris"],
		" · 灯 ", art.done()["lights"])

func _place_player_at_entrance() -> void:
	var p = game.player
	# 1F 门厅（6.0 × 26：x −3.2…3.2，z −10…16）。
	# 站在门厅靠北、面朝 +Z（往楼梯间/洗衣店那侧），落地留 5 cm 免得卡进地板。
	p.global_position = world.position + Vector3(-0.55, 0.06, -7.6)
	p.rotation.y = PI                      # 面朝 +Z
	p.velocity = Vector3.ZERO
	if p.has_method("snap_to_floor"):
		p.call("snap_to_floor")
	# 0017 的 player.gd 里朝向变量就是 rotation.y（没有 yaw）

## 洗衣店里的坐标 = 世界坐标（world 就在原点）。
## 保留这个函数是为了接口稳定：万一以后要把整棵树挪走，只改这一个地方。
func W(v: Vector3) -> Vector3:
	return world.position + v

# ================================================================ 交互点
## 直接给 game.gd 的 spots 用（格式和 0017 完全一致：id/pos/r/label）
func spots() -> Array:
	var sd := [
		# 1F 门厅
		{"id":"lb_exit","pos":W(Vector3(-0.55, 1.25, -9.45)),"r":2.1,"label":"推门回到回潮镇"},
		{"id":"lb_board","pos":W(Vector3(-3.00, 1.75, 12.0)),"r":2.4,"label":"看公告栏"},
		{"id":"lb_box503","pos":W(Vector3(-3.00, 1.35, 4.62)),"r":2.2,"label":"看 503 信箱"},
		{"id":"lb_booth","pos":W(Vector3(-0.75, 1.30, 9.00)),"r":2.2,"label":"进传达室"},
		{"id":"lb_elev","pos":W(Vector3(2.85, 1.30, -6.00)),"r":2.4,"label":"看废电梯"},
		{"id":"lb_mail","pos":W(Vector3(-2.95, 1.40, 3.20)),"r":2.2,"label":"拉信箱"},
		{"id":"lb_mark","pos":W(Vector3(2.70, 1.32, 12.60)),"r":2.2,"label":"看墙上的刻线"},
		# 2F 洗衣店
		{"id":"l_price","pos":W(Vector3(-2.20, 5.40, 2.10)),"r":2.4,"label":"看价目表"},
		{"id":"l_cash","pos":W(Vector3(-2.10, 4.70, 8.95)),"r":2.2,"label":"开收银机"},
		{"id":"l_ruler","pos":W(Vector3(0.95, 4.20, 9.95)),"r":2.2,"label":"看门框"},
		{"id":"l_m3","pos":W(Vector3(-2.35, 4.20, 6.60)),"r":2.4,"label":"看 3 号机"},
		{"id":"l_m9","pos":W(Vector3(2.35, 4.20, 4.60)),"r":2.4,"label":"看 9 号烘干机"},
		{"id":"l_bin","pos":W(Vector3(2.90, 3.90, 9.50)),"r":2.2,"label":"翻垃圾桶"},
		{"id":"l_mirror","pos":W(Vector3(3.00, 5.00, 5.50)),"r":2.4,"label":"照镜子"},
		{"id":"l_backdoor","pos":W(Vector3(-1.20, 4.50, 2.05)),"r":2.2,"label":"推后房门"},
		{"id":"l_keyring","pos":W(Vector3(-2.90, 5.05, -0.62)),"r":2.2,"label":"拿钥匙串"},
		{"id":"l_m7","pos":W(Vector3(0.00, 4.25, 2.75)),"r":2.4,"label":"看 7 号机"},
		# 后房
		{"id":"l_registry","pos":W(Vector3(-1.2, 4.3, 0.2)),"r":2.2,"label":"翻老顾客簿"},
		{"id":"l_sign","pos":W(Vector3(-2.2, 4.6, -1.0)),"r":2.2,"label":"看拆下的旧招牌"},
		{"id":"l_photowall","pos":W(Vector3(-0.6, 4.9, -1.2)),"r":2.2,"label":"看照片墙"},
		{"id":"l_clipping","pos":W(Vector3(0.4, 4.8, -1.0)),"r":2.2,"label":"看那张剪报"},
		{"id":"l_boiler","pos":W(Vector3(-2.6, 4.3, -0.8)),"r":2.2,"label":"看锅炉"},
		{"id":"l_raincoat","pos":W(Vector3(1.2, 4.6, -1.2)),"r":2.2,"label":"看那件儿童雨衣"},
	]
	if routes != null:
		sd.append_array(routes.spots())
	if campaign != null:
		sd.append_array(campaign.spots())
	if rebuilt != null:
		for point in sd:
			if rebuilt.POINTS.has(point.id): point.pos = rebuilt.POINTS[point.id]
	return sd

# ================================================================ 交互
func interact(id: String) -> void:
	if campaign != null and campaign.interact(id):
		return
	if id.begins_with("l_locked_"):
		game.audio_system.sfx("knock",-11)
		var lines := {"l_locked_402":"门上挂着五道锁。里面有人压低声音说：新来的？先把洗衣店的夜班值完。", "l_locked_401":"401已经空置。锁舌没有动，这扇门今晚打不开。", "l_locked_503":"门从里面反锁。贴近门板，能听见洗衣机的声音。这一夜，还进不去。"}
		game._say_seq("旁白",String(lines[id]),3.0,false)
		return
	if id in ["l_service_down", "l_service_up"]:
		routes.climb(id == "l_service_down")
		return
	var s: Node3D = game
	match id:
		"lb_exit":
			s._leave_laundry_to_town()
		"lb_board":
			s._say_seq("旁白", "三张纸三个年代。2003 年停水通知、2011 年拆迁补偿公告、2024 年「本楼禁止入内」。")
			s._say_seq("旁白", "最下面那张的落款单位被撕掉了——只剩一道撕口。")
		"lb_box503":
			s._say_seq("旁白", "一百二十个信箱，锈死八十七个。\n只有这一格的锁是新的，铜色还亮着。")
		"lb_booth":
			s._say_seq("旁白", "电视永远在下雪。桌上摊着一本登记簿，最后一页的签名停在 2004-11-07。")
		"lb_elev":
			s._say_seq("旁白", "门半开着，里面是黑的。轿厢卡在三楼。\n贴着门缝，能听见水声。")
		"lb_mail":
			s._say_seq("旁白", "有几格能拉开，里面都是 1998 到 2004 年的水电费单。\n户名一栏，一直写着同一个名字。")
		"lb_mark":
			s._say_seq("旁白", "铅笔画的几道身高线，最高的那道旁边写着：「秀兰 1.32」。\n再往上一片空白。")

		"l_price":
			s._say_seq("旁白", "洗一次，从 3 元改到 8 元，改了四次。最后一行是铅笔写的：\n「7号机 = 专用」")
		"l_cash":
			s._say_seq("旁白", "抽屉是开的。三枚硬币：1998、1998、2019。\n有人在二十年后，还往里投过币。")
		"l_ruler":
			s._say_seq("旁白", "门框内侧一排铅笔刻线，一年一条，都写着年份。\n最后一条刻在 2004 年，1.32 米。之后没有了。")
		"l_m3":
			s._say_seq("旁白", "滚筒在空转，里面什么都没有。\n玻璃内侧有一个手印——小孩的手，五指张开，是往外按的。")
		"l_m9":
			s._say_seq("旁白", "滚筒里卡着一张洗衣单。\n2004-11-07，7 号机，童装一套，未取。")
			s._say_seq("旁白", "你把它收进口袋。")
			_claim("slip")
		"l_bin":
			s._say_seq("旁白", "全是童装。一件一件，都在 1.3 米上下。\n没有一件是收走的。")
		"l_mirror":
			if t >= 220.0 * 60.0:
				s._say_seq("旁白", "镜子里有整个店。\n……它照不出 7 号机。")
				s._say_seq("旁白", "镜子里多了一个人影。她站在你身后，不动。")
				if cast != null and cast.aqi != null:
					cast.aqi_turn_to(game.player.global_position)
			else:
				s._say_seq("旁白", "镜子里有整个店。\n但是它照不出 7 号机。")
		"l_backdoor":
			if not has_back_key:
				s._say_seq("旁白", "锁着。门缝里有风，是往里吹的。")
				return
			if back_open:
				s._say_seq("旁白", "门已经开着了。")
				return
			back_open = true
			s._say_seq("旁白", "钥匙对上了。门轴很涩，推的时候整间屋子都响了一下。")
			if f2 != null and f2.doors.has("back") and f2.doors["back"] != null:
				var tw: Tween = s.create_tween()
				tw.tween_property(f2.doors["back"], "rotation:y", 1.25, 0.8)
		"l_keyring":
			has_back_key = true
			if b2 != null and b2.keyring != null:
				b2.keyring.visible = false
			s._say_seq("旁白", "锅炉顶上挂着一串钥匙。第三把是新的——其余都锈死了。")
		"l_m7":
			if not back_open:
				s._say_seq("旁白", "滚筒在转。里面有一件藏青色的童装毛衣，袖口是白条纹。")
				s._say_seq("旁白", "它不跟着转——筒在转，它悬在正中间。")
			else:
				s._say_seq("旁白", "门锁开了。你伸手进去，把那件毛衣拿了出来。\n它还是干的。")
				if f2 != null and f2.sweater != null:
					f2.sweater.visible = false
				_claim("sweater")
		"l_registry":
			s._say_seq("旁白", "老顾客簿。2004-11-07 那一行：周秀兰　7 号机　童装一套　未取。")
			s._say_seq("旁白", "她和这家店同名。")
			_claim("registry")
		"l_sign":
			s._say_seq("旁白", "拆下来的旧招牌。漆下凸起四个字——「秀兰干洗」。")
			s._say_seq("旁白", "2004 年那一夜之后，它改名叫得利。")
			_claim("sign")
		"l_photowall":
			s._say_seq("旁白", "一家三口的照片。孩子的脸被刀片刮掉了。\n刮得很干净，像是有人不想让这张脸留在世上。")
			_claim("photo")
		"l_clipping":
			s._say_seq("旁白", "剪报：2004 年 11 月 8 日，老街 27 号「秀兰干洗」昨夜起火，一人失联。")
			s._say_seq("旁白", "失联。没有说死。\n二十年来，没有一个人来认领过。")
			_claim("clipping")
		"l_boiler":
			s._say_seq("旁白", "锅炉低鸣。你把手放上去——它在震，和外面滚筒的节奏一模一样。")
		"l_raincoat":
			s._say_seq("旁白", "挂钩上一件儿童雨衣，还在滴水。\n可是这间屋子已经二十年没进过人了。")

		# —— 门 / 座位（走 0017 框架原生的 door / seat）
		"exit_leave":
			s._say_seq("旁白", "（你推开门。今晚先到这里。）")

# ================================================================ 线索
var clues := {}
func _claim(id: String) -> void:
	clues[id] = true

func has_clue(id: String) -> bool:
	return clues.get(id, false)

func got_count() -> int:
	return clues.size()

## 结局判定（剧本 9-D 的三选一 + 隐藏 D）
func pick_ending() -> String:
	return "A"

# ================================================================ 时间轴
func step(delta: float) -> void:
	if ended:
		return
	if game.audio_system.is_busy() or not game.sub_queue.is_empty():
		_spin(delta)
		return
	t += delta * RATE
	_timeline()
	_spin(delta)

func _timeline() -> void:
	if campaign != null:
		campaign.timeline()

# 柜台三件：仅在第三夜正式交班时出现。
func _place_handover_items() -> void:
	if art == null:
		return
	var a = art
	# 柜台在世界 (−2.10−0.28, 3.5, 6.0+2.40) 一带，台面高约 0.57+3.5
	var base := Vector3(-2.38, 4.07, 8.40)
	# 纸工牌：一张卡片 + 一根挂绳
	a.box(base, Vector3(0.16, 0.012, 0.10), a.plain(Color(0.92, 0.90, 0.84), 0.85), false, 0.12)
	a.box(base + Vector3(0, 0.002, 0.0), Vector3(0.10, 0.002, 0.02),
		a.plain(Color(0.30, 0.32, 0.36), 0.8), false, 0.12)
	# 信封（800 元旧钞）
	a.box(base + Vector3(0.22, 0.006, 0.02), Vector3(0.20, 0.028, 0.13),
		a.plain(Color(0.86, 0.84, 0.76), 0.9), false, -0.08)
	# 权限卡
	a.box(base + Vector3(-0.22, 0.004, 0.03), Vector3(0.13, 0.010, 0.09),
		a.plain(Color(0.20, 0.42, 0.50), 0.35, 0.5), false, 0.2)

## 04:00 天光：主灯色温收到 3300 K，环境光抬起（剧本写死的）
func _dawn_light() -> void:
	if game == null or game.env_node == null:
		return
	var e: Environment = game.env_node.environment
	# 环境从夜色抬到晨光
	e.ambient_light_color = Color(0.52, 0.50, 0.46)
	e.ambient_light_energy = 1.12
	e.tonemap_exposure = 1.08
	e.fog_light_color = Color(0.30, 0.28, 0.24)
	e.fog_density = 0.004
	# 加一盏假晨光（从窗的方向）
	if art != null:
		var dawn: DirectionalLight3D = DirectionalLight3D.new()
		dawn.add_to_group("case1_dawn")
		dawn.light_color = Color(1.0, 0.86, 0.62)
		dawn.light_energy = .65
		dawn.rotation = Vector3(deg_to_rad(-28), deg_to_rad(35), 0)
		art.root.add_child(dawn)

## 04:01 长椅上坐着阿七（原来她站在镜子前，这一步把她挪到长椅）
func _show_aqi_on_bench() -> void:
	if cast == null or cast.aqi == null:
		return
	var aqi = cast.aqi
	aqi.global_position = Vector3(1.8, 3.5, 6.75)
	aqi.face_yaw(-PI * 0.5, 0.0)     # 面朝 −X（朝向玩家）
	if aqi.has_anim("SitIdle"):
		aqi.sit(0.44)
	else:
		aqi.play("Idle", 0.0)
	aqi.visible = true

## 04:02 黑屏 → 标题卡
func _show_title_card() -> void:
	if game == null:
		return
	game.show_case_title("得利洗衣店", "第一案 · 完")

# ================================================================ 第一夜的中段事件
## 停电 3.2 秒：剧本 02:30 那一下。只剩 7 号机的绿光。
func _blackout(sec: float) -> void:
	if game == null or game.env_node == null:
		return
	var e: Environment = game.env_node.environment
	var saved_amb: float = e.ambient_light_energy
	var saved_exp: float = e.tonemap_exposure
	var blackout_night: int = campaign.night_number() if campaign != null else 1
	var lamps := {}
	for lamp in world.find_children("*","Light3D",true,false):
		if lamp.global_position.y>3.5 and lamp.global_position.y<6.9 and lamp.global_position.distance_to(Vector3(0,4.2,2.6))>1.0:
			lamps[lamp]=lamp.light_energy;lamp.light_energy=0.
	var tubes=world.find_children("Detail_Tube*","MeshInstance3D",true,false)
	for tube in tubes:tube.visible=false
	e.ambient_light_energy = 0.02
	e.tonemap_exposure = 0.35
	await game.get_tree().create_timer(sec).timeout
	if not is_instance_valid(world): return
	for lamp in lamps:
		if is_instance_valid(lamp):lamp.light_energy=lamps[lamp]
	for tube in tubes:
		if is_instance_valid(tube):tube.visible=true
	if campaign != null and (not is_instance_valid(campaign) or campaign.night_number()!=blackout_night or bool(campaign.progress.rest_pending) or fired.has("dawn4")): return
	if game != null and game.env_node != null:
		e.ambient_light_energy = saved_amb
		e.tonemap_exposure = saved_exp

## 停电之后长椅上多一条叠得整整齐齐的毛巾（剧本 02:30）
func _place_towel() -> void:
	if game == null or game.laundry == null:
		return
	var a = art
	if a == null:
		return
	# 长椅在 (1.9, 3.5, 6.2~7.2)，座面顶 3.99；毛巾叠好放中间座位
	a.box(Vector3(1.90, 4.01, 6.72), Vector3(0.34, 0.035, 0.26),
		a.plain(Color(0.84, 0.86, 0.86), 0.92), false, 0.06)
	a.box(Vector3(1.90, 4.03, 6.72), Vector3(0.30, 0.015, 0.22),
		a.plain(Color(0.90, 0.91, 0.91), 0.95), false, 0.06)

# 唯一认领结局。保留旧接口便于迁移存档，不再提供多结局操作。
var final_open := false
var ended := false
var selected_ending := ""

func _open_final_choice() -> void:
	if campaign != null:
		campaign.lady_talk()

func choose_final(kind: String) -> void:
	if campaign != null and kind == "A":
		campaign.claim()

const ENDINGS := {
	"A": {
		"title": "已认领",
		"body": "她把第六件叠好，放进布袋。\n\n"
			+ "「……齐了。」\n\n"
			+ "她站起来，把布袋抱在怀里，走到门口，转身。\n"
			+ "「谢谢你啊。你叫什么名字？」\n\n"
			+ "你说了。她点了点头，像是真的记住了。",
		"dossier": "案卷 00184 · 得利洗衣店\n处置：已认领\n附：一件童装毛衣（2004-11-07 · 未取）",
	},
}

func _finish_case(kind: String) -> void:
	choose_final(kind)

func complete_case() -> void:
	if selected_ending == "" or ended:
		return
	ended = true
	var kind := selected_ending
	preload("res://scripts/case_save.gd").record_ending(kind)
	var d: Dictionary = ENDINGS.get(kind, ENDINGS["A"])
	if campaign != null:
		d = {"title":"得利洗衣店 · 第一案结束", "body":"她把第六件叠好：……齐了。\n\n「谢谢你啊。你叫什么名字？」\n「许砚。」\n「许砚。我记着。」\n\n阿七坐在长椅上：「你现在能看见我了？」\n\n三夜工资2400元，欠租2160元结清，余下新收入240元。\n归还的第一份来历：向阳福利院旧址。", "dossier":"案卷00184 · 已认领\n周秀兰与未取原衣归属成立\n周小满：事故后去向未明，继续追查\n许砚：已录名 · 临-0131\n第一案 · 完"}
	game._show_case_end(String(d["title"]), String(d["body"]), String(d["dossier"]))
	print("[CASE] 第一案结束：", kind, " · ", String(d["title"]))

var lady = null
func _spawn_lady(animate_entry := true) -> void:
	# 复用 first_night 里那套「走 → 坐下 → 数衣服」的实现
	var Night := preload("res://scripts/laundry/first_night.gd")
	night = Night.new()
	world.add_child(night)
	# 只复用演员驱动；独立试玩场景的 UI/时间轴不在这里运行。
	night.set_process(false)
	night.set_physics_process(false)
	night.world = world
	night.art_ref = art
	# 它需要 f2（门/毛衣）与世界根
	night.f2 = f2
	night._spawn_lady(animate_entry)
	lady = night.lady

func _spin(delta: float) -> void:
	if f2 == null:
		return
	for k in spinning.keys():
		if spinning[k] and f2.drums.has(k):
			var d: Node3D = f2.drums[k]
			d.rotation.z += delta * 2.6

## 恢复物件和演员的现场状态，不重播广播、不重发背包物品。
func restore_visuals(data: Dictionary) -> void:
	if f2.sweater != null:
		f2.sweater.visible = not has_clue("sweater")
	if b2.keyring != null:
		b2.keyring.visible = not has_back_key
	if f2.doors.has("back"):
		f2.doors["back"].rotation.y = 1.25 if back_open else 0.0
	if fired.has("oldlady"):
		_spawn_lady(false)
		night._lady_walk_t = float(data.get("lady_walk", 6.0))
		night._npc_step(0.0)
		if String(data.get("lady_state", "sit")) != "walk":
			night._do_sit()
			night.lady_state = "sit"
		if fired.has("count"):
			night.lady_count()
		if fired.has("ask"):
			night.lady_ask()
		lady.visible = not fired.has("dawn4")
	if fired.has("beat14"):
		_place_towel()
	if fired.has("handover_items"):
		_place_handover_items()
	if fired.has("dawn4"):
		_dawn_light()
	if fired.has("aqi_line"):
		_show_aqi_on_bench()
	if campaign != null:
		campaign.restore(data.get("campaign",{}))

func _once(k: String) -> bool:
	if fired.has(k):
		return false
	fired[k] = true
	return true

func _tell(who: String, text: String) -> void:
	game._say_seq(who, text, 3.0, false, true)
