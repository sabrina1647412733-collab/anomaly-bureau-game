extends SceneTree
## 60 秒垂直切片回归：出租屋内的完整闭环。
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _run() -> void:
	for i in range(30):
		await process_frame
	game.menu.start_game.emit()
	for i in range(8):
		await process_frame
	var start_ok: bool = game.state == "prologue" and game.prologue_stage == "room"
	print("[SLICE] start state=", game.state, " stage=", game.prologue_stage)
	# 小物件叙事层：收音机 / 墙上旧电话 / 床头相框
	var radio_label_before: String = game._prologue_label({"id": "radio"})
	game._prologue_act("radio")
	game._prologue_act("wallphone")
	game._prologue_act("photo")
	await process_frame
	var radio_light = game.get_meta("room_radio_light", null)
	var props_ok: bool = game.prologue_radio_played and game.prologue_radio_on
	props_ok = props_ok and game.prologue_wallphone_checked and game.prologue_photo_checked
	props_ok = props_ok and radio_light != null and radio_light.visible and game.radio_player != null
	game._prologue_act("radio")
	var radio_toggle_ok: bool = not game.prologue_radio_on
	radio_toggle_ok = radio_toggle_ok and radio_light != null and not radio_light.visible
	print("[SLICE] props=", props_ok, " radio_label=", radio_label_before, " toggle=", radio_toggle_ok)
	game._clear_sub()
	game._prologue_act("phone")
	game._prologue_act("box")
	var letter_ok: bool = game.prologue_letter_ready
	print("[SLICE] letter_ready=", letter_ok)
	game._prologue_act("door")
	await process_frame
	var ui_ok: bool = game.state == "prologue_ui" and game.prologue_paper.visible
	print("[SLICE] letter_ui=", ui_ok)
	game._close_letter()
	game._prologue_act("phone")
	for i in range(4):
		await process_frame
	var call_ok: bool = game.prologue_call_done
	print("[SLICE] call=", call_ok)
	var window_label: String = game._prologue_label({"id": "window"})
	print("[SLICE] window_label=", window_label)
	game._prologue_act("window")
	await create_timer(13.5).timeout
	var end_ok: bool = game.state == "prologue_end" and game.prologue_end_card != null and game.prologue_end_card.visible
	var hud_ok: bool = game.hud_objective != null and not game.hud_objective.visible
	print("[SLICE] anomaly_done=", game.prologue_anomaly_done, " end=", end_ok, " hud_hidden=", hud_ok, " state=", game.state)
	# 按 R 重开：人影、灯光、目标 HUD 都要回到开场状态
	game._start_prologue()
	await create_timer(0.5).timeout
	var restart_ok: bool = game.state == "prologue" and game.prologue_stage == "room"
	restart_ok = restart_ok and (game.prologue_figure == null or not game.prologue_figure.visible)
	restart_ok = restart_ok and (game.prologue_cabin_light == null or game.prologue_cabin_light.light_energy > 1.0)
	restart_ok = restart_ok and (radio_light == null or not radio_light.visible)
	restart_ok = restart_ok and game.hud_objective != null and game.hud_objective.visible
	print("[SLICE] restart=", restart_ok, " state=", game.state)
	var ok := start_ok and props_ok and radio_toggle_ok and letter_ok and ui_ok and call_ok and window_label == "去窗边看看" and end_ok and hud_ok and restart_ok
	print("[SLICE] PASS=", ok)
	quit(0 if ok else 1)
