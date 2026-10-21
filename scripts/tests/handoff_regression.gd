extends SceneTree
## 验证真实 _process 门控、时间边界、可达尾声、JSON 现场恢复与重开。
var game
var passed := 0
var failed := 0
var slot_backup: PackedByteArray
var slot_existed := false
var slot_path: String

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("[PASS] ", label)
	else:
		failed += 1
		print("[FAIL] ", label)

func _initialize() -> void:
	_run()

func tick_game(seconds: float) -> void:
	game._clear_sub() # 相当于读完当前字幕，仍经由总控推进时钟。
	game._process(seconds)

func _run() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(8):
		await process_frame
	game.set_process(false)
	game._hide_menu()
	game._start_prologue(false)
	game.prologue_letter_ready = true
	game.prologue_letter_read = true
	game.prologue_call_done = true
	game.envelope_taken = true
	game.bag_add("hoodie", "灰色卫衣", "没有牌子。", "物")
	game.note("疑", "测试水声", "门缝里传来的声音。")
	slot_path = game.SLOT_PATHS[2]
	slot_existed = FileAccess.file_exists(slot_path)
	if slot_existed:
		slot_backup = FileAccess.get_file_as_bytes(slot_path)
	check(game.game_save(2), "出租屋可以保存")
	game.prologue_call_done = false
	game.case_bag.clear()
	check(game.game_load(2), "出租屋存档可以读取")
	check(game.state == "prologue" and game.prologue_call_done, "恢复出租屋阶段与电话进度")
	check(game.bag_has("hoodie"), "恢复出租屋背包")
	game.start_laundry_case()
	game.laundry.t = 20.0 * 60.0
	tick_game(0.0)
	check(not game.laundry.fired.has("bc1"), "00:00 尚未播放 00:01 广播")
	tick_game(60.0 / game.laundry.RATE)
	check(game.laundry.fired.has("bc1"), "00:01 精确触发第一次广播")
	game.laundry.t = 39.0 * 60.0
	tick_game(0.0)
	check(not game.laundry.fired.has("bc2"), "00:19 尚未播放第二次广播")
	tick_game(60.0 / game.laundry.RATE)
	check(game.laundry.fired.has("bc2"), "00:20 第二次广播")
	check(game.state == "play" and game.cut_phase == "", "越过 00:17 不触发车站过场")
	game.laundry.has_back_key = true
	game.laundry.back_open = true
	game.laundry.clues["sweater"] = true
	game.laundry.t = 214.0 * 60.0
	tick_game(0.0)
	game.player.global_position = Vector3(0.4, 3.58, 8.4)
	var saved_pos: Vector3 = game.player.global_position
	game._show_sub("广播", "这一句尚未读完。", 3.0, true)
	game.sub_queue = [{"who": "阿七", "text": "下一句。", "pause": true, "hold": 2.0}]
	game._open_pause()
	check(not game.player.can_move, "暂停时停止玩家移动")
	check(game.game_save(2), "洗衣店现场可以保存")
	game.laundry.clues.clear()
	check(game.game_load(2), "洗衣店 JSON 存档可以重建现场")
	check(game.laundry.has_clue("sweater") and game.laundry.back_open, "恢复线索、钥匙与后门")
	check(not game.laundry.f2.sweater.visible, "已拿取的毛衣不会重生")
	check(game.player.global_position.is_equal_approx(saved_pos), "恢复玩家位置")
	check(game.laundry.fired.has("count"), "恢复时间轴已触发节点")
	check(game.laundry.spinning.has(7), "恢复 JSON 中的整数滚筒编号")
	check(game.nb.has("疑", "测试水声"), "恢复记事本")
	check(game.sub == "这一句尚未读完。" and game.sub_queue.size() == 1, "恢复未读字幕及后续台词")
	game.laundry.t = 240.0 * 60.0 - 1.0
	tick_game(1.0 / game.laundry.RATE)
	check(game.state == "case_choice" and game.laundry.final_open, "03:40 打开处置选择")
	var stopped: float = game.laundry.t
	tick_game(10.0)
	check(is_equal_approx(game.laundry.t, stopped), "选项等待期间不偷跑时间")
	game._open_pause()
	game._on_resume()
	check(game.state == "case_choice" and not game.player.can_move, "从暂停返回选择时保持正确输入状态")
	check(game.game_save(2), "选项状态可保存")
	check(game.game_load(2) and game.choice == "case_final", "读档恢复选项且不跳过决定")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_C
	event.pressed = true
	game._unhandled_input(event)
	check(game.laundry.selected_ending == "C", "C 键实际可选顶替")
	check(game.state == "play" and not game.laundry.ended, "选定处置后返回现场，继续交班")
	for minute in range(241, 263):
		tick_game(60.0 / game.laundry.RATE)
	check(game.laundry.fired.has("handover_items"), "正常总控可到达交班")
	check(game.bag_has("badge") and game.bag_has("cash800") and game.bag_has("permcard"), "交班物品进入背包")
	check(game.laundry.fired.has("dawn4"), "正常总控可到达 04:00 天亮")
	check(game.laundry.fired.has("aqi_line"), "正常总控可到达阿七最后的台词")
	check(game.state == "case_end" and game.laundry.ended, "04:02 进入结局卡")
	check(game.hud_end.text.contains("00184"), "结局显示本案编号")
	game._on_new_game()
	check(game.laundry == null and game.case_mode == "", "新游戏清理旧洗衣店实例")
	check(game.case_bag.is_empty() and not game.envelope_taken, "重开清空背包与信封状态")
	# 测试只借用一个槽位，退出前原样恢复用户数据。
	if slot_existed:
		var f := FileAccess.open(slot_path, FileAccess.WRITE)
		f.store_buffer(slot_backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path))
	print("结果：通过 %d / 失败 %d" % [passed, failed])
	game._discard_laundry()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
