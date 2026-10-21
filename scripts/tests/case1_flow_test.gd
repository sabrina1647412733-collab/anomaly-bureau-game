extends SceneTree
## 第一案全流程自检：出租屋 → 回潮镇 → 洗衣店 → 第一夜 → 三选一 → 结局卡
##   --headless --path . -s res://scripts/tests/case1_flow_test.gd
var game
var fails: Array = []
var oks: Array = []

func _ok(m: String) -> void:
	oks.append(m); print("  [ OK ] ", m)

func _fail(m: String) -> void:
	fails.append(m); print("  [FAIL] ", m)

func _check(c: bool, m: String) -> void:
	if c: _ok(m)
	else: _fail(m)

func _initialize() -> void:
	_run()

## 等一个条件成立（headless 下帧率极高，一律按条件等，不按帧数等）
func _wait_until(cond: Callable, max_frames := 4000) -> bool:
	for i in range(max_frames):
		await process_frame
		if cond.call():
			return true
	return false

func _run() -> void:
	print("")
	print("========== 第一案全流程自检 ==========")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(8):
		await process_frame

	# ── 1 主菜单 → 新游戏 → 出租屋
	game._on_new_game()
	_check(await _wait_until(func(): return game.state == "prologue"), "进出租屋")
	_check(game.prologue_stage == "room", "stage = room")
	_check(not game.laundry, "还没进洗衣店")
	_check(game.prologue_roots["room"].visible, "出租屋可见")

	# ── 2 出租屋：信封 → 两个选项 → 选「去」
	game._prologue_drop_letter()
	game._pick_envelope()
	_check(await _wait_until(func(): return game.choice == "env_choice"), "信封弹出两个选项")
	game._update_interaction()
	_check(game.hud_prompt.text.find("[E]") >= 0 and game.hud_prompt.text.find("[R]") >= 0,
		"选项文字显示在提示条上")
	game._accept_envelope()
	_check(game.bag_has("envelope") and game.state == "prologue", "同意后通知书入包，仍在出租屋")
	game.field_kit.answer_phone()
	game._prologue_act("door")

	# ── 3 出租屋门外的回潮镇：地点、地图和洗衣店入口
	_check(await _wait_until(func(): return game.prologue_stage == "town" and game.state == "prologue"),
		"从房门进入回潮镇街道")
	_check(game.town_bridge.active and game.town_bridge.town_map.visible, "街道与小地图显示")
	_check(game.town_bridge.layout.get("landmarks", []).size() == 10, "原地图十个命名地标保留")
	var shop: Dictionary = game.town_bridge._landmark("01")
	var front: Array = shop.get("front", [])
	game.player.global_position = game.town_bridge.ORIGIN + Vector3(float(front[0]), 0.2, float(front[1]) + 1.3)
	_check(game.town_bridge.interaction_hint().get("id", "") == "01", "洗衣店门口可交互")
	game.town_bridge.interact("01")

	# ── 4 进洗衣店
	_check(await _wait_until(func(): return game.case_mode == "laundry" and game.state == "play"),
		"进入洗衣店（state=play）")
	var lc = game.laundry
	_check(lc != null and lc.entered, "洗衣店场景已建立")
	_check(is_zero_approx(lc.world.global_position.length()),
		"洗衣店在原点（否则家具会飘，实测踩过）")
	_check(game.spots.size() >= 20, "交互点 %d 个" % game.spots.size())

	# ── 5 第一夜时间轴
	lc.t = 0.0
	lc._timeline()
	_check(true, "00:00 时间轴可跑")
	lc.t = 41.0 * 60.0
	lc._timeline()
	_check(lc.fired.has("bc2"), "00:20 第二遍广播（「请」字消失）")
	_check(lc.spinning.get(1, false), "1/2/3 号机自转")

	# 01:10 她进门
	lc.t = 111.0 * 60.0
	lc._timeline()
	_check(lc.lady != null, "01:10 她已进场")
	if lc.lady != null:
		_check(lc.lady.ap != null, "她是带动画的角色")

	# 03:10 数衣服 / 03:40 问话 → 开三选一
	lc.t = 211.0 * 60.0
	lc._timeline()
	lc.t = 241.0 * 60.0
	lc._timeline()
	_check(lc.final_open, "03:40 之后打开三选一")
	_check(game.choice == "case_final", "choice = case_final")
	game._update_interaction()
	_check(game.hud_prompt.text.find("[E]") >= 0 and game.hud_prompt.text.find("[R]") >= 0,
		"三选一选项显示在提示条上（「%s」）" % game.hud_prompt.text)

	# ── 6 结局 A：需要先拿毛衣
	_check(not lc.has_clue("sweater"), "一开始还没有毛衣")
	lc.choose_final("A")
	_check(not lc.ended, "没毛衣时不能选认领（会被拦下）")
	# 拿毛衣（走后房钥匙 → 开库房门 → 取毛衣）
	lc.has_back_key = true
	lc.back_open = true
	lc.interact("l_m7")
	_check(lc.has_clue("sweater"), "拿到 7 号机里的童装毛衣")
	lc.choose_final("A")
	_check(lc.selected_ending == "A" and not lc.ended, "选认领 → 继续交班")
	lc.t = 262.0 * 60.0
	lc._timeline()
	_check(lc.fired.has("aqi_line"), "结局前播放阿七尾声")
	_check(game.state == "case_end", "进入结局状态（state=%s）" % game.state)
	_check(game.hud_end_title.text == "已认领", "结局卡标题：%s" % game.hud_end_title.text)
	_check(game.hud_end.text.find("案卷 00184") >= 0, "结局卡上有案卷号")
	_check(game.hud_end.text.find("谢谢你啊") >= 0, "结局卡上有她的台词")

	# ── 7 结局 B / C 的判定（另起一局，直接验证逻辑）
	lc.ended = false
	lc.selected_ending = ""
	lc.final_open = true
	lc.choose_final("B")
	lc.complete_case()
	_check(lc.ended and game.hud_end_title.text == "已抹平", "结局 B：已抹平")
	_check(game.hud_end.text.find("复发风险") >= 0, "B 卡上有复发风险")

	print("")
	print("========== 结果 ==========")
	print("通过 %d / 失败 %d" % [oks.size(), fails.size()])
	for f in fails:
		print("  - ", f)
	quit(0 if fails.is_empty() else 1)
