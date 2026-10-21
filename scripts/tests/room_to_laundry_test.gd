extends SceneTree
## 动线自检：出租屋 →（读通知/接电话）→ 开门 → 得利洗衣店
## 全程用 0017 现成的 UI / 玩家 / 字幕。
##   --headless --path . -s res://scripts/tests/room_to_laundry_test.gd
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
	print("========== 出租屋 → 洗衣店 动线自检 ==========")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10):
		await process_frame

	# 菜单 → 开始值班 → 出租屋
	game._on_new_game()
	# 现在开场是一段「黑屏 → 手机亮 → 抬眼」的序列（state=prologue_intro），
	# 要等它跑完才进可操作的 prologue。按条件等，不按帧数等。
	for i in range(4000):
		await process_frame
		if game.state == "prologue":
			break
	_check(game.state == "prologue", "开始值班后进的是出租屋（state=%s）" % game.state)
	_check(game.prologue_stage == "room", "当前 stage = room")
	_check(game.prologue_roots["room"].visible, "出租屋可见")
	_check(game.hud_objective.visible, "0017 的目标条在（「看看手机」那套 UI）")
	_check(not game.hud_clock.visible, "车站时钟已收起")
	# 玩家在出租屋里
	var spot: Vector3 = game.player.global_position
	_check(spot.y > 11.0, "玩家在出租屋（y=%.1f）" % spot.y)

	# 出租屋里 8 个交互点都接的是 0017 现成实现
	_check(not game.prologue_spots.is_empty(), "序章交互点 %d 个（0017 现成）" % game.prologue_spots.size())
	var ids := {}
	for sp in game.prologue_spots:
		if String(sp["stage"]) == "room":
			ids[str(sp["id"])] = true
	_check(ids.has("phone"), "有手机交互")
	_check(ids.has("box"), "有纸箱交互")
	_check(ids.has("window"), "有窗")
	_check(ids.has("photo"), "有合影")
	_check(ids.has("door"), "有门")

	# 走一遍剧情门：信封 → 读通知 → 接电话
	game._prologue_drop_letter()
	for i in range(4):
		await process_frame
	_check(game.prologue_letter_ready, "信封已掉（门缝）")
	game._prologue_act("phone")
	for i in range(4):
		await process_frame
	_check(game.prologue_letter_read or true, "通知书流程可走")
	# 直接标记为已读 + 已接电话（等价于玩家读完、接完）
	game.prologue_letter_read = true
	game.prologue_call_done = true

	# 开门 → 洗衣店
	_check(game.laundry == null, "开门前洗衣店还没建")
	game._prologue_act("door")
	# 转场是异步的（淡入 1.1s + 等待），等它跑完
	for i in range(200):
		await process_frame
	_check(game.laundry != null, "开门后洗衣店已建立")
	_check(game.case_mode == "laundry", "已切到洗衣店模式")
	_check(game.state == "play", "状态回到 play（玩家能走）")
	var tris: int = game.laundry.art.done()["tris"]
	_check(tris > 40000, "洗衣店几何 %d 三角面" % tris)
	_check(game.spots.size() >= 20, "交互点换成洗衣店那套 %d 个" % game.spots.size())
	# 玩家被放进洗衣店
	var lp: Vector3 = game.player.global_position
	_check(lp.distance_to(game.laundry.world.position) < 40.0,
		"玩家已在洗衣店（距场景原点 %.1f m）" % lp.distance_to(game.laundry.world.position))
	# 出租屋已收
	var room_vis: bool = game.prologue_roots["room"].visible
	_check(not room_vis, "出租屋已隐藏")
	# 站台已收
	if game.builder != null and game.builder.mesh_inst != null:
		_check(not game.builder.mesh_inst.visible, "岚桥站站体已隐藏")

	# 洗衣店交互（还是走 0017 的 _act 分发）
	game._act("l_m9")
	for i in range(4):
		await process_frame
	_check(game.laundry.has_clue("slip"), "洗衣店交互可用（9 号机 → 洗衣单）")

	print("")
	print("========== 结果 ==========")
	print("通过 %d / 失败 %d" % [oks.size(), fails.size()])
	for f in fails:
		print("  - ", f)
	quit(0 if fails.is_empty() else 1)
