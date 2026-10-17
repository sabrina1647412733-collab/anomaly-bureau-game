extends SceneTree
## 剧情增强回归：入职通知书 / 字幕队列 / 值班电脑第三份文件 / 线索板推理 / 结局世界观钩子
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _run() -> void:
	for i in range(30):
		await process_frame
	game._on_new_game()
	for i in range(5):
		await process_frame
	var prologue_ok: bool = game.state == "prologue" and game.prologue_stage == "room"
	var queue_ok: bool = game.sub_queue.size() >= 4 or game.sub.contains("10 月 18 日")
	game._on_start()
	for i in range(5):
		await process_frame
	game._act("pc")
	await process_frame
	var file: Label = game.pc_overlay.get("file_view")
	var accident_ok: bool = file.text.contains("邵国平") and file.text.contains("19")
	game.pc_overlay.call("_show_notice")
	var notice_ok: bool = file.text.contains("诡异事务局") and file.text.contains("不要相信站内广播")
	game.pc_overlay.call("_show_file")
	var restore_ok: bool = file.text.contains("邵国平")
	game._close_pc()
	game.sub = ""
	game.sub_queue.clear()
	for it in game.items:
		it["got"] = true
	game._read_board()
	game._skip_sub_line()
	game._skip_sub_line()
	var board_ok: bool = game.sub.contains("五条记录连起来")
	game._show_end("A")
	var end_ok: bool = game.hud_end.text.contains("诡异事务局")
	var ok := prologue_ok and queue_ok and accident_ok and notice_ok and restore_ok and board_ok and end_ok
	print("[STORY] prologue=", prologue_ok, " queue=", queue_ok, " accident=", accident_ok, " notice=", notice_ok, " restore=", restore_ok, " board=", board_ok, " end=", end_ok, " PASS=", ok)
	quit(0 if ok else 1)
