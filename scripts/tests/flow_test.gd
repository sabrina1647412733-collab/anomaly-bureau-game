extends SceneTree
## 无头驱动：菜单 → 开始 → 按钮/存读档 → 过场（跳过）→ 预览结算卡 → 下一轮。
## 用时间/状态等待，不再依赖固定帧数。
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _run() -> void:
	for i in range(30):
		await process_frame
	var menu_ok: bool = game.state == "menu" and game.round == -1
	print("[T] 菜单 state=", game.state, " round=", game.round, " 有存档=", game.game_has_save())
	game._on_start()
	for i in range(10):
		await process_frame
	var start_ok: bool = game.state == "play" and game.round == -1
	print("[T] 开始 state=", game.state, " round=", game.round, " 钟=", game.clock_min)
	game._press_button(0)
	var saved: bool = game.game_save(0)
	var has_save: bool = game.game_has_save()
	var loaded: bool = game.game_load(0)
	print("[T] 存档保存=", saved, " 存在=", has_save, " 读档=", loaded)
	game._on_start()
	for i in range(10):
		await process_frame
	game.clock_min = 1457.01
	var t0 := Time.get_ticks_msec()
	while game.state != "cutscene" and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	var cut_ok: bool = game.state == "cutscene"
	print("[T] 到点 state=", game.state, " phase=", game.cut_phase, " cut_ok=", cut_ok)
	game._skip_cutscene()
	t0 = Time.get_ticks_msec()
	while game.cut_phase != "preview" and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	var preview_ok: bool = game.cut_phase == "preview"
	var summary_ok: bool = game.round_summary.visible and game.round_summary_body.text.contains("本轮发现：") and game.round_summary_body.text.contains("为什么重来：")
	print("[T] 预览 phase=", game.cut_phase, " summary=", summary_ok)
	print("[T] 结算 body=", game.round_summary_body.text.replace("\n", " | "))
	game._skip_cutscene()
	t0 = Time.get_ticks_msec()
	while game.round < 0 and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	var next_ok: bool = game.round >= 0 and game.state == "play" and not game.round_summary.visible
	print("[T] 下一轮 round=", game.round, " state=", game.state, " summary_hidden=", not game.round_summary.visible)
	var pass_ok: bool = menu_ok and start_ok and cut_ok and preview_ok and summary_ok and next_ok
	print("[T] PASS=", pass_ok)
	quit(0 if pass_ok else 1)