extends SceneTree
## 跳过过场回归：轮次卡会暂停时钟，所以先关卡片再驱动到点
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _run() -> void:
	for i in range(30):
		await process_frame
	game._on_start()
	game.round_card.visible = false
	game.sub = ""
	game.sub_queue.clear()
	game.sub_pause = false
	game.clock_min = 1457.1
	var t0 := Time.get_ticks_msec()
	while game.state != "cutscene" and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	print("[S] 到点 state=", game.state, " phase=", game.cut_phase)
	game._skip_cutscene()
	t0 = Time.get_ticks_msec()
	while game.cut_phase != "preview" and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	print("[S] 第一下跳过 → phase=", game.cut_phase)
	game._skip_cutscene()
	t0 = Time.get_ticks_msec()
	while game.round < 0 and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	var ok: bool = game.round >= 0 and game.state == "play"
	print("[S] 最终 round=", game.round, " state=", game.state, " PASS=", ok)
	quit(0 if ok else 1)