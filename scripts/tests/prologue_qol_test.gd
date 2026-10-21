extends SceneTree
## 本轮 7 项小任务的自检
##   --headless --path . -s res://scripts/tests/prologue_qol_test.gd
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
	print("========== 出租屋体验优化自检 ==========")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10):
		await process_frame
	game._on_new_game()
	for i in range(20):
		await process_frame

	# ── 5. 开场：黑屏 → 手机亮 → 抬眼
	# 注意：headless 下帧率极高，一帧只有几 ms，所以一律按「状态」等，不按帧数等。
	_check(game.state == "prologue_intro", "开场从 intro 序列开始（state=%s）" % game.state)
	# 黑屏是在 _play_room_intro() 里设的；到检查这一刻可能已经开始淡出了，
	# 所以只看「开场确实走了淡入」——即 state 是 intro 且 fade 曾经是 1.0。
	_check(game._intro_was_dark, "开场先做了黑屏（fade 从 1.0 开始）")
	for i in range(4000):
		await process_frame
		if game.state == "prologue":
			break
	_check(game.state == "prologue", "开场结束后进入可操作状态（state=%s）" % game.state)
	_check(game.hud_objective.visible, "目标条已显示")
	_check(game.hud_objective.text.find("手机") >= 0 or game.hud_objective.text.find("电话") >= 0,
		"目标条提示看手机/接电话（实际「%s」）" % game.hud_objective.text)

	# ── 1. 字幕点击推进（不排队等）
	game._clear_sub()
	game._say_seq("旁白", "第一句。", 1.0)
	game._say_seq("旁白", "第二句。", 1.0)
	_check(game.sub == "第二句。", "后一句直接顶掉前一句（不排队）：当前「%s」" % game.sub)
	game._sub_skip()                       # 打字中 → 一下打完
	_check(int(game.sub_time * game.sub_cps) >= game.sub.length(), "点一下先把当前句打完")
	game._sub_skip()                       # 打完了 → 进下一句 / 清屏
	_check(game.sub == "", "再点一下清屏（队列已空）")

	# ── 2. 捡信封 + 两个选项
	_check(game.prologue_letter_ready == false, "开局信封还没出现")
	game._prologue_drop_letter()
	_check(game.prologue_letter_ready, "信封已掉到门内地面")
	# 信封有独立交互点（这就是原来"捡不起来"的原因）
	var has_env := false
	for sp in game.prologue_spots:
		if String(sp["id"]).begins_with("envelope"):
			has_env = true
	_check(has_env, "信封有独立交互点（原来没有，所以捡不起来）")
	game._pick_envelope()
	# _pick_envelope 里有 3×0.35s 的 await 才弹选项，按条件等
	for i in range(600):
		await process_frame
		if game.choice == "env_choice":
			break
	_check(game.envelope_taken, "信封已捡起")
	_check(game.field_kit.held_id == "envelope" and not game.bag_has("envelope"), "未决定的信封先拿在手里")
	_check(game.choice == "env_choice", "出现两个选项（choice=%s）" % game.choice)
	# 选「不去」→ 灯灭 2 秒 → 桌上多一张新的 → 这次没有选项
	game._refuse_envelope()
	_check(game.envelope_refused == 1, "选择「不去」计数 +1")
	# 整条链：1.4s 字幕 + 灭灯 2s + 亮灯 + 1s → 约 4.4 秒；按条件等，最多 900 帧
	await create_timer(3.6).timeout
	_check(game.envelope_taken == false, "信封重新变成可捡（它又回来了）")
	_check(game.choice == null, "第二封留在桌上等待玩家拾取")
	game._pick_envelope()
	_check(game.choice == "env_choice_forced", "第二次没有「不去」选项（choice=%s）" % game.choice)
	# 选「去」
	game.choice = null
	game._accept_envelope()
	for i in range(4):
		await process_frame
	_check(game.state == "prologue" and game.bag_has("envelope"),
		"同意后收入背包，等待接电话和主动出门")

	# ── 7. 诡异时钟
	game._spawn_weird_clock()
	for i in range(10):
		await process_frame
	_check(game.clock_appeared and game.wclock != null, "诡异时钟已出现")
	_check(game.wclock.visible, "时钟可见")
	var t0: float = game.wclock.total_min
	game.wclock.turn_step(1.0)
	_check(game.wclock.total_min > t0, "拧一下能拨快时间（%.0f → %.0f）" % [t0, game.wclock.total_min])
	# 拨到里程碑
	var fired_before: int = game.wclock.fired.size()
	game.wclock.turn(120.0)
	_check(game.wclock.fired.size() > fired_before,
		"拨到时间点会触发里程碑（%d → %d）" % [fired_before, game.wclock.fired.size()])
	_check(at_least(game.wclock.fired, ["bc1", "bc2"]), "00:01 / 00:20 广播已触发")

	# ── 3. 记事本四页
	_check(game.nb != null, "记事本已建立")
	game.note("物", "灰色卫衣", "没有牌子、没有尺码标。")
	game.note("人", "房东", "只在聊天里出现过。")
	game.note("话", "广播", "夜间请勿使用七号机。")
	game.note("疑", "门缝", "信封是从门缝进来的，可你没听见人上楼。")
	_check(game.nb.count("物") >= 1, "「物」页有内容")
	_check(game.nb.count("人") >= 1, "「人」页有内容")
	_check(game.nb.count("话") >= 1, "「话」页有内容")
	_check(game.nb.count("疑") >= 1, "「疑」页有内容")
	game.nb.add("物", "灰色卫衣", "重复的不会加第二遍")
	_check(game.nb.count("物") == 1, "同名条目不会重复记")
	game.nb.open()
	_check(game.nb.visible, "记事本能打开")
	game.nb._go(3)
	_check(game.nb.page == 3, "能翻到第 4 页（疑）")
	game.nb.close()
	_check(not game.nb.visible, "记事本能关闭")

	# ── 6. ESC 暂停菜单
	game.state = "prologue"
	game._open_pause()
	_check(game.state == "paused", "ESC 能打开暂停菜单（state=%s）" % game.state)
	_check(game.menu.visible and game.menu.pause_open, "暂停面板可见")
	_check(game.menu.pause_panel.visible, "暂停面板本身可见")
	game._on_resume()
	_check(game.state == "prologue", "从暂停返回出租屋（而不是被强行设成 play）")

	# ── 4. 手机界面
	game._open_phone()
	_check(game.phone_open and game.phone_ui.visible, "手机界面能打开")
	_check(game.phone_ui.page in ["lock", "incoming"], "打开时是锁屏或来电页")
	game.phone_ui._goto("chat")
	_check(game.phone_ui.page == "chat", "能进聊天（房东催债）")
	game.phone_ui._goto("wallet")
	_check(game.phone_ui.page == "wallet", "能进钱包")
	game.phone_ui._goto("album")
	_check(game.phone_ui.page == "album", "能进相册")
	game.phone_ui._goto("calls")
	_check(game.phone_ui.page == "calls", "能进通话记录")
	game._close_phone()
	_check(not game.phone_open, "手机能关掉")

	print("")
	print("========== 结果 ==========")
	print("通过 %d / 失败 %d" % [oks.size(), fails.size()])
	for f in fails:
		print("  - ", f)
	quit(0 if fails.is_empty() else 1)

func at_least(d: Dictionary, keys: Array) -> bool:
	for k in keys:
		if not d.has(k):
			return false
	return true
