extends SceneTree
## 洗衣店完整流程演练：从进门到 04:00 交班
##   --headless --path . -s res://scripts/tests/case1_night_test.gd
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

func _run() -> void:
	print("")
	print("========== 洗衣店第一夜全程（23:40 → 04:00）==========")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(8):
		await process_frame
	game.start_laundry_case()
	for i in range(8):
		await process_frame
	var lc = game.laundry

	# 目标引导（等一帧让 _update_case_objective 跑过）
	for i in range(6):
		await process_frame
	_check(game.hud_objective.visible, "进门就有目标条")
	_check(game.hud_objective.text.find("看看这家店") >= 0,
		"第一目标是「看看这家店」（实际「%s」）" % game.hud_objective.text)

	# 逐段推进时间轴（直接设 t，模拟时间流逝）
	var marks := [
		[25.0, "beat1", "00:05 滚筒停一下"],
		[32.0, "beat2", "00:12 收银机抽屉"],
		[41.0, "bc2", "00:20 广播「请」字消失"],
		[46.0, "beat3", "00:26 门框刻线"],
		[54.0, "beat4", "00:34 后房门缝有风"],
		[61.0, "beat5", "00:41 镜子那边有响动"],
		[70.0, "beat6", "00:50 9 号烘干机"],
		[80.0, "beat7", "01:00 七台机器"],
		[90.0, "beat8", "01:10 门口地面是湿的"],
		[100.0, "beat9", "01:20 楼上有脚步声"],
		[111.0, "oldlady", "01:30 她进门"],
		[116.0, "beat10", "她走到长椅坐下"],
		[130.0, "beat11", "她对着空气说话"],
		[145.0, "beat12", "她说明天下雨"],
		[170.0, "beat13", "02:30 停电"],
		[171.0, "beat14", "灯亮，长椅上多一条毛巾"],
		[200.0, "beat15", "她把布袋摊开"],
		[205.0, "beat16", "她开始往外拿"],
		[211.0, "count", "03:10 数衣服"],
		[216.0, "count2", "她重数：还差一件"],
		[241.0, "ask", "03:40 是不是洗好了"],
		[256.0, "handover_items", "03:56 柜台三样东西"],
		[258.0, "recorded", "03:58 您已录名"],
		[261.0, "dawn4", "04:00 天光，她消失"],
		[262.0, "aqi_line", "04:01 阿七：你现在能看见我了"],
	]
	for m in marks:
		lc.t = float(m[0]) * 60.0
		lc._timeline()
		for k in range(3):
			await process_frame
		_check(lc.fired.has(m[1]), "%s → 触发 %s" % [m[2], m[1]])
		if m[1] == "ask":
			lc.clues["sweater"] = true
			lc.choose_final("A")

	# 关键节点复查
	_check(lc.lady != null, "她确实进场了")
	# 注意：时间是推进到 04:00 的，剧本在 04:00 会把所有滚筒停下，
	# 所以这里要检查「过程中确实转过」而不是「现在还在转」。
	_check(lc.fired.has("bc2"), "00:20 广播触发过（那一刻机器会自转）")
	_check(lc.selected_ending == "A", "三选一已确认，交班继续")
	_check(game.bag_has("badge"), "交班拿到纸工牌")
	_check(game.bag_has("cash800"), "交班拿到 800 元旧钞")
	_check(game.bag_has("permcard"), "交班拿到权限卡")

	# 目标条应该已经推进到「要给她什么」
	game._update_case_objective()
	_check(game.hud_objective.text.find("交班") >= 0,
		"目标条推进到最后一步（实际「%s」）" % game.hud_objective.text)

	# 选一个结局收尾
	lc.clues["sweater"] = true
	lc.complete_case()
	_check(lc.ended, "选认领 → 第一案结束")
	_check(game.hud_end_title.text == "已认领", "结局卡：已认领")

	print("")
	print("========== 结果 ==========")
	print("通过 %d / 失败 %d" % [oks.size(), fails.size()])
	for f in fails:
		print("  - ", f)
	quit(0 if fails.is_empty() else 1)
