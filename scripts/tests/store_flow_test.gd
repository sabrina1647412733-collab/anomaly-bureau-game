extends SceneTree
## 开门选地点 + 便利店交互 + 车站入口解锁的流程测试。
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
	for i in range(40):
		await process_frame
	game.menu.start_game.emit()
	await create_timer(0.4).timeout
	# 直接把出租屋段推到接完电话，专测开门选地点后的流程
	game.prologue_letter_ready = true
	game.prologue_letter_read = true
	game.prologue_call_done = true
	game._prologue_set_objective("去便利店")
	game._open_travel_menu()
	await process_frame
	var menu_ok: bool = game.state == "prologue_travel" and game.prologue_travel_card.visible
	game._travel_to("store")
	await create_timer(1.3).timeout
	var store_ok: bool = game.state == "prologue" and game.prologue_stage == "store"
	store_ok = store_ok and game.player.position.z > 501.5 and game.player.position.z < 503.0
	var labels_ok: bool = game._prologue_label({"id":"counter", "stage":"store"}) == "便利店柜台"
	labels_ok = labels_ok and game._prologue_label({"id":"fridge", "stage":"store"}) == "冷柜"
	labels_ok = labels_ok and game._prologue_label({"id":"travel", "stage":"store"}).contains("开门")
	game._prologue_act("fridge")
	game._prologue_act("shelf")
	game._prologue_act("magazine")
	await process_frame
	var props_ok: bool = game.prologue_seen.has("store_fridge") and game.prologue_seen.has("store_shelf") and game.prologue_seen.has("store_magazine")
	# 未结账前车站必须锁着
	game._travel_to("station")
	await create_timer(0.15).timeout
	var locked_ok: bool = game.prologue_stage == "store" and not game.prologue_store_done
	game._prologue_act("counter")
	await process_frame
	var unlock_ok: bool = game.prologue_store_done and game.prologue_objective == "去岚桥站"
	game._open_travel_menu()
	await process_frame
	var station_btn_ok: bool = not game.prologue_travel_station_btn.disabled
	game._travel_to("station")
	await create_timer(1.3).timeout
	var station_ok: bool = game.state == "prologue" and game.prologue_stage == "station"
	station_ok = station_ok and game.player.position.z > 326.0 and game.player.position.z < 327.0
	station_ok = station_ok and _stage_spot("station", "reader") and _stage_spot("station", "travel")
	var station_label_ok: bool = game._prologue_label({"id":"reader", "stage":"station"}) == "刷工牌"
	station_label_ok = station_label_ok and game._prologue_label({"id":"travel", "stage":"station"}) == "回临江里"
	# 地点菜单可从车站打开并返回
	game._open_travel_menu()
	await process_frame
	var station_menu_ok: bool = game.state == "prologue_travel" and game.prologue_travel_card.visible
	game._close_travel_menu()
	await process_frame
	station_menu_ok = station_menu_ok and game.state == "prologue"
	var ok := menu_ok and store_ok and labels_ok and props_ok and locked_ok and unlock_ok and station_btn_ok and station_ok and station_label_ok and station_menu_ok
	print("[STORE_FLOW] menu=", menu_ok, " store=", store_ok, " labels=", labels_ok, " props=", props_ok)
	print("[STORE_FLOW] locked=", locked_ok, " unlock=", unlock_ok, " station_btn=", station_btn_ok)
	print("[STORE_FLOW] station=", station_ok, " station_labels=", station_label_ok, " station_menu=", station_menu_ok)
	print("[STORE_FLOW] PASS=", ok)
	quit(0 if ok else 1)
