extends SceneTree
## 复现 + 回归：捡完信封之后必须**看得见选项**、并且**按 E / R 真的能选**。
##   --headless --path . -s res://scripts/tests/envelope_choice_test.gd
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
	print("========== 信封选项自检（捡完信封不能卡死） ==========")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10):
		await process_frame
	game._on_new_game()
	# 等开场跑完
	for i in range(4000):
		await process_frame
		if game.state == "prologue":
			break
	_check(game.state == "prologue", "进入出租屋可操作状态")

	# 掉信封 → 捡起来
	game._prologue_drop_letter()
	game._pick_envelope()
	for i in range(600):
		await process_frame
		if game.choice == "env_choice":
			break

	# ── 核心：选项必须显示出来
	_check(game.choice == "env_choice", "弹出了两个选项（choice=%s）" % game.choice)
	_check(game.state == "prologue_choice", "state 是 prologue_choice")
	# 让 _update_interaction 跑一次（这是真实玩家视野里的提示条）
	game._update_interaction()
	_check(game.hud_prompt.text != "", "选项提示条**不是空的**（实际「%s」）" % game.hud_prompt.text)
	_check(game.hud_prompt.text.find("[E]") >= 0, "提示条里有 [E] 去洗衣店")
	_check(game.hud_prompt.text.find("[R]") >= 0, "提示条里有 [R] 留在屋里")
	# 玩家确实被定住了（设计如此：必须做选择）
	_check(not game.player.can_move, "做选择时玩家定住（这是设计，不是 bug）")

	# ── 按 R = 不去 → 应该能脱开这个状态
	game._refuse_envelope()
	_check(game.choice == null, "按 R 之后选项关闭")
	_check(game.state == "prologue", "按 R 之后回到 prologue（能动了）")
	_check(game.player.can_move, "按 R 之后玩家能动")
	game._update_interaction()
	# 选项关掉之后提示条应该回到「正常交互提示」（比如 [E] 窗外），
	# 而不是继续显示选项文字 —— 所以断言改成「不再含 留在屋里」
	_check(game.hud_prompt.text.find("留在屋里") < 0,
		"选项提示已清掉，回到正常交互提示（实际「%s」）" % game.hud_prompt.text)

	# 等它走完「灯灭 → 再来一封」的链，确认第二次只有一个选项
	await create_timer(3.6).timeout
	_check(game.choice == null and game.prologue_envelope.visible, "第二封出现在桌面，需要重新拾取")
	game._pick_envelope()
	for i in range(1200):
		await process_frame
		if game.choice == "env_choice_forced":
			break
	_check(game.envelope_taken, "桌面上的信封已重新捡起")
	_check(game.choice == "env_choice_forced", "第二次没有「不去」（choice=%s）" % game.choice)
	game._update_interaction()
	_check(game.hud_prompt.text.find("[E]") >= 0, "第二次提示条有 [E] 去洗衣店")
	_check(game.hud_prompt.text.find("[R]") < 0, "第二次提示条**没有** [R]")

	# ── 按 E = 去 → 进洗衣店
	game._accept_envelope()
	_check(game.bag_has("envelope"), "同意后通知书收入背包")
	game.field_kit.answer_phone()
	game._prologue_act("door")
	# 正式路线经过回潮镇，不能再把出出租屋等同于直接进洗衣店。
	game._step_exit_to_town(game.LEAVE_FADE*2.0+.1)
	_check(game.prologue_stage == "town", "房门先进入回潮镇")
	game.town_bridge.interact("01")
	game._step_exit_to_laundry(game.LEAVE_FADE*2.0+.1)
	# 转场现在是两段（黑下去 LEAVE_FADE + 亮起来 LEAVE_FADE，共 2.2 s）。
	# headless 下一帧只有几 ms，所以要给足帧数（实测约 850 帧）。
	for i in range(2000):
		await process_frame
		# 注意：state 在转场「第一段结束」就变成 play 了，但交还控制要等第二段结束，
		# 所以这里必须等 can_move 才算真的到位。
		if game.case_mode == "laundry" and game.state == "play" and game.player.can_move:
			break
	_check(game.case_mode == "laundry", "按 E 之后进入洗衣店（case=%s）" % game.case_mode)
	_check(game.state == "play", "进洗衣店后 state=play（能动）")
	_check(game.player.can_move, "进洗衣店后玩家能动")

	print("")
	print("========== 结果 ==========")
	print("通过 %d / 失败 %d" % [oks.size(), fails.size()])
	for f in fails:
		print("  - ", f)
	quit(0 if fails.is_empty() else 1)
