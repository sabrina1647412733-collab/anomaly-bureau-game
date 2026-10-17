extends SceneTree
## 0017 前序章流程回归：出租屋 → 便利店 → 车站入口 → 第 1 轮
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _run() -> void:
	for i in range(30):
		await process_frame
	game.menu.start_game.emit()
	for i in range(5):
		await process_frame
	var start_ok: bool = game.state == "prologue" and game.prologue_stage == "room"
	print("[PRO] start state=", game.state, " stage=", game.prologue_stage)
	game._prologue_act("phone")
	game._prologue_act("box")
	var letter_ok: bool = game.prologue_letter_ready
	print("[PRO] letter_ready=", letter_ok)
	game._prologue_act("door")
	await process_frame
	var ui_ok: bool = game.state == "prologue_ui" and game.prologue_paper.visible
	print("[PRO] letter_ui=", ui_ok, " state=", game.state)
	game._close_letter()
	game._prologue_act("phone")
	for i in range(3):
		await process_frame
	var call_ok: bool = game.prologue_call_done
	print("[PRO] call=", call_ok)
	game._prologue_act("door")
	await create_timer(1.0).timeout
	var store_ok: bool = game.prologue_stage == "store"
	print("[PRO] store=", store_ok, " stage=", game.prologue_stage)
	game._prologue_act("counter")
	game._prologue_act("store_door")
	await create_timer(1.0).timeout
	var entrance_ok: bool = game.prologue_stage == "entrance"
	print("[PRO] entrance=", entrance_ok, " stage=", game.prologue_stage)
	game._prologue_act("reader")
	await create_timer(7.0).timeout
	var station_ok: bool = game.state == "play" and game.round == -1
	print("[PRO] station=", station_ok, " state=", game.state, " round=", game.round)
	var ok := start_ok and letter_ok and ui_ok and call_ok and store_ok and entrance_ok and station_ok
	print("[PRO] PASS=", ok)
	quit(0 if ok else 1)
