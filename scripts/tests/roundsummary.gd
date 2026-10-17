extends SceneTree
## 轮次结算卡回归：标题、发现、重置原因、结束隐藏、序章交接进度、_after_cutscene 集成
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _run() -> void:
	for i in range(30):
		await process_frame
	game._on_start()
	for i in range(10):
		await process_frame
	game.round = 0
	for i in range(game.items.size()):
		if String(game.items[i]["def"]["id"]) == "red":
			game._give_clue(i)
	game._show_round_summary("测试：0017 没有进站。")
	await process_frame
	var ok1: bool = game.round_summary.visible
	var title: String = game.round_summary_title.text
	var body: String = game.round_summary_body.text
	print("[SUMMARY] round0 visible=", ok1, " title=", title, " body=", body.replace("\n", " | "))
	var pass1 := ok1 and title.contains("第 1 轮") and body.contains("红灯延迟记录") and body.contains("0017 没有进站")
	game._end_hook()
	await process_frame
	var pass2: bool = not game.round_summary.visible
	print("[SUMMARY] after_end hidden=", pass2, " round=", game.round)
	game.round = -1
	for b in game.buttons:
		b["done"] = false
	if game.buttons.size() >= 2:
		game.buttons[0]["done"] = true
		game.buttons[1]["done"] = true
	game._show_round_summary("测试：交接。")
	await process_frame
	var body2: String = game.round_summary_body.text
	print("[SUMMARY] prologue body=", body2.replace("\n", " | "))
	var pass3 := body2.contains("交接流程 2/3")
	game.round = 0
	game._after_cutscene()
	await process_frame
	var body3: String = game.round_summary_body.text
	print("[SUMMARY] after_cutscene visible=", game.round_summary.visible, " body=", body3.replace("\n", " | "))
	var pass4: bool = game.round_summary.visible and body3.contains("本轮发现：") and body3.contains("为什么重来：")
	game._end_hook()
	await process_frame
	print("[SUMMARY] PASS=", pass1 and pass2 and pass3 and pass4)
	quit(0 if (pass1 and pass2 and pass3 and pass4) else 1)