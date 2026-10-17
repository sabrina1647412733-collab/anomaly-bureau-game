extends SceneTree
## 结局 A 回归：轮次卡后到点 → 跳列车过场 → 等最终选择 → E 公开
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
	game.round = 3
	for it in game.items:
		it["got"] = true
	game.handle = true
	game.late = false
	game.clock_min = 1457.2
	var t0 := Time.get_ticks_msec()
	while game.state != "cutscene" and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	print("[A] cutscene state=", game.state, " phase=", game.cut_phase)
	game._skip_cutscene()
	t0 = Time.get_ticks_msec()
	while game.choice == null and game.state != "ending" and Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	print("[A] final choice=", game.choice != null, " state=", game.state)
	var e1 := InputEventKey.new(); e1.physical_keycode = KEY_E; e1.pressed = true
	Input.parse_input_event(e1)
	await process_frame
	var e2 := InputEventKey.new(); e2.physical_keycode = KEY_E; e2.pressed = false
	Input.parse_input_event(e2)
	await process_frame
	var ok: bool = game.shown_end == "A" and game.hud_end_title.text.contains("结局 A")
	print("[A] shown_end=", game.shown_end, " title=", game.hud_end_title.text, " PASS=", ok)
	quit(0 if ok else 1)