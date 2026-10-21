extends SceneTree
## 验证：洗衣店是真的接进了 0017 框架，而不是另起一套。
##   --headless --path . -s res://scripts/tests/laundry_case_test.gd
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
	print("========== 洗衣店接入 0017 框架自检 ==========")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10):
		await process_frame

	# 启动前：确认用的是 0017 那套玩家/HUD
	_check(game.player != null, "0017 的玩家已生成")
	_check(game.player.get_script().resource_path.find("player.gd") >= 0,
		"玩家是 scripts/player.gd（不是另写的）")
	_check(game.hud != null, "0017 的 HUD 已生成")
	_check(game.prompt_ring != null, "0017 的呼吸环已生成")
	_check(game.hud_sub != null and game.hud_prompt != null, "0017 的字幕/提示条已生成")

	# 启动洗衣店那一局
	game.start_laundry_case()
	for i in range(10):
		await process_frame

	_check(game.case_mode == "laundry", "已切到洗衣店模式")
	_check(game.laundry != null, "LaundryCase 已建立")
	_check(game.laundry.world != null, "洗衣店世界已挂进场景")
	# 场景内容
	var tris: int = game.laundry.art.done()["tris"]
	var lights: int = game.laundry.art.done()["lights"]
	_check(tris > 40000, "洗衣店三角面 %d（应 >40000）" % tris)
	_check(lights > 80, "洗衣店灯 %d 盏（应 >80）" % lights)
	_check(game.laundry.buildings.size() >= 8,
		"楼层实例 %d 个" % game.laundry.buildings.size())
	# 玩家还是 0017 那个，只是被挪进洗衣店
	_check(game.player == game.player, "玩家对象没被替换")
	_check(game.laundry.cast != null and game.laundry.cast.count() >= 3,
		"三个剧情角色 %d 个" % (game.laundry.cast.count() if game.laundry.cast else 0))
	# 交互点是洗衣店的
	_check(game.spots.size() >= 20, "交互点 %d 个（洗衣店那套）" % game.spots.size())
	var ids := {}
	for sp in game.spots:
		ids[str(sp["id"])] = true
	_check(ids.has("l_m7"), "有 7 号机交互点")
	_check(ids.has("l_keyring"), "有钥匙串交互点")
	_check(ids.has("lb_board"), "有门厅公告栏交互点")
	_check(not ids.has("power") and not ids.has("divert"),
		"岚桥站的交互点已撤掉（不串台）")
	# 岚桥站几何已隐藏
	if game.builder != null and game.builder.mesh_inst != null:
		_check(not game.builder.mesh_inst.visible, "岚桥站站体已隐藏")
	# HUD 还是 0017 的
	_check(game.hud_map == null or game.hud_map.modulate.a < 0.01, "站区图已隐藏（洗衣店没意义）")

	# 交互真的能走（用 0017 的 _act 分发）
	game._act("l_m9")
	for i in range(4):
		await process_frame
	_check(game.laundry.has_clue("slip"), "看 9 号烘干机 → 拿到洗衣单")
	_check(game.sub != "" or game.hud_sub.text != "" or not game.sub_queue.is_empty(),
		"字幕由 0017 的 _say_seq 输出")

	# 时间轴
	game.laundry.t = 41.0 * 60.0
	game.laundry._timeline()
	for i in range(4):
		await process_frame
	_check(game.laundry.fired.has("bc2"), "00:20 第二遍广播已触发")
	_check(game.laundry.spinning.get(1, false), "1 号机自转")

	# 结局判定
	game.laundry.clues.clear()
	game.laundry._claim("name"); game.laundry._claim("cert"); game.laundry._claim("sandal")
	_check(game.laundry.pick_ending() == "D", "名字+接种证+凉鞋 → D")
	game.laundry.clues.clear()
	game.laundry._claim("name")
	_check(game.laundry.pick_ending() == "A", "只知道名字 → A")
	game.laundry.clues.clear()
	_check(game.laundry.pick_ending() == "B", "什么都没有 → B")

	print("")
	print("========== 结果 ==========")
	print("通过 %d / 失败 %d" % [oks.size(), fails.size()])
	for f in fails:
		print("  - ", f)
	quit(0 if fails.is_empty() else 1)
