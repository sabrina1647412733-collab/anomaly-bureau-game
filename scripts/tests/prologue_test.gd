extends SceneTree
## 序章回归：出租屋 → 入职通知书 → 接线员 → 开门地点菜单 → 便利店 → 岚桥站。
## 房间内不再有 0017 / 00:17 / 2009 异象或结束卡。
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _stage_spot(stage: String, id: String) -> bool:
	for sp in game.prologue_spots:
		if String(sp.get("stage", "")) == stage and String(sp.get("id", "")) == id:
			return true
	return false

func _run() -> void:
	for i in range(32):
		await process_frame
	game.menu.start_game.emit()
	for i in range(8):
		await process_frame
	var start_ok: bool = game.state == "prologue" and game.prologue_stage == "room"
	for id in ["phone", "box", "window", "door", "radio", "wallphone", "photo", "light_switch"]:
		start_ok = start_ok and _stage_spot("room", id)
	var main_light = game.get_meta("room_main_light", null)
	var window_light = game.get_meta("room_window_light", null)
	var main_on: float = main_light.light_energy if main_light != null else 0.0
	var win_on: float = window_light.light_energy if window_light != null else 0.0
	print("[SLICE] start state=", game.state, " stage=", game.prologue_stage, " switch_spot=", _stage_spot("room", "light_switch"))

	# 灯开关：关灯明显变暗，窗外冷光保留；再开恢复。
	game._prologue_act("light_switch")
	await process_frame
	var off_ok: bool = not game.prologue_room_lights_on
	off_ok = off_ok and main_light != null and main_light.light_energy < main_on * 0.25
	off_ok = off_ok and window_light != null and absf(window_light.light_energy - win_on) < 0.01
	off_ok = off_ok and game._prologue_label({"id": "light_switch"}) == "开灯"
	game._prologue_act("light_switch")
	await process_frame
	var on_ok: bool = game.prologue_room_lights_on and main_light != null and absf(main_light.light_energy - main_on) < 0.01
	print("[SLICE] light_switch off=", off_ok, " on=", on_ok, " main=", main_on)

	# 生活物件：收音机 / 旧电话 / 相框（父亲背景，不再承担 0017 线索）
	var radio_label_before: String = game._prologue_label({"id": "radio"})
	game._prologue_act("radio")
	game._prologue_act("wallphone")
	game._prologue_act("photo")
	game._prologue_act("window")
	await process_frame
	var radio_light = game.get_meta("room_radio_light", null)
	var props_ok: bool = game.prologue_radio_played and game.prologue_radio_on
	props_ok = props_ok and game.prologue_wallphone_checked and game.prologue_photo_checked and game.prologue_seen.has("window")
	props_ok = props_ok and radio_light != null and radio_light.visible and game.radio_player != null
	game._prologue_act("radio")
	var radio_toggle_ok: bool = not game.prologue_radio_on
	radio_toggle_ok = radio_toggle_ok and radio_light != null and not radio_light.visible
	print("[SLICE] props=", props_ok, " radio_label=", radio_label_before, " toggle=", radio_toggle_ok)

	# 查看手机 + 纸箱 → 门缝信封
	game._clear_sub()
	game._prologue_act("phone")
	game._prologue_act("box")
	var letter_ok: bool = game.prologue_letter_ready
	print("[SLICE] letter_ready=", letter_ok)
	game._prologue_act("door")
	await process_frame
	var ui_ok: bool = game.state == "prologue_ui" and game.prologue_paper.visible
	var lt: String = game.prologue_paper_text.text
	var letter_clean: bool = ui_ok and lt.contains("异常事件处置岗（临时）") and lt.contains("岚桥站")
	letter_clean = letter_clean and lt.contains("权限：D") and lt.contains("报酬")
	letter_clean = letter_clean and not lt.contains("0017") and not lt.contains("00:17")
	letter_clean = letter_clean and not lt.contains("2009") and not lt.contains("不要相信")
	print("[SLICE] letter_ui=", ui_ok, " letter_clean=", letter_clean)
	game._close_letter()
	game._prologue_act("phone")
	for i in range(3):
		await process_frame
	var call_ok: bool = game.prologue_call_done and game.prologue_objective == "去便利店"
	print("[SLICE] call=", call_ok, " objective=", game.prologue_objective)

	# 接完电话直接开门选地点，不再有 prologue_end 结束卡
	game._prologue_act("door")
	await process_frame
	var menu_ok: bool = game.state == "prologue_travel" and game.prologue_travel_card.visible
	var no_end_ok: bool = game.prologue_end_card == null or not game.prologue_end_card.visible
	print("[SLICE] travel_menu=", menu_ok, " no_end=", no_end_ok)

	game._travel_to("store")
	await create_timer(1.3).timeout
	var store_ok: bool = game.state == "prologue" and game.prologue_stage == "store"
	store_ok = store_ok and game.player.position.z > 501.5 and game.player.position.z < 503.0
	game._prologue_act("counter")
	await process_frame
	var unlock_ok: bool = game.prologue_store_done and game.prologue_objective == "去岚桥站"
	game._open_travel_menu()
	await process_frame
	game._travel_to("station")
	await create_timer(1.3).timeout
	var station_ok: bool = game.state == "prologue" and game.prologue_stage == "station"
	station_ok = station_ok and _stage_spot("station", "reader") and _stage_spot("station", "travel")
	print("[SLICE] store=", store_ok, " unlock=", unlock_ok, " station=", station_ok)

	# 重开序章：灯状态必须复位
	game._set_prologue_room_lights(false)
	game._start_prologue()
	await create_timer(0.4).timeout
	var restart_ok: bool = game.state == "prologue" and game.prologue_stage == "room"
	restart_ok = restart_ok and game.prologue_room_lights_on
	restart_ok = restart_ok and main_light != null and absf(main_light.light_energy - main_on) < 0.01
	restart_ok = restart_ok and (radio_light == null or not radio_light.visible)
	restart_ok = restart_ok and game.hud_objective != null and game.hud_objective.visible
	print("[SLICE] restart=", restart_ok, " state=", game.state)

	var ok := start_ok and off_ok and on_ok and props_ok and radio_toggle_ok and letter_ok
	ok = ok and ui_ok and letter_clean and call_ok and menu_ok and no_end_ok
	ok = ok and store_ok and unlock_ok and station_ok and restart_ok
	print("[SLICE] PASS=", ok)
	quit(0 if ok else 1)
