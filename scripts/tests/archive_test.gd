extends SceneTree
## 存档档案验收：
## 1) 新档 → 进行中；玩到结局 A → 已结案 1/6 · 结局 1/3
## 2) 删槽位后档案仍在
## 3) 导出 / 导入（合并、幂等）
## 测试会先备份并最终还原本机档案与三个槽位，避免影响真实进度。

const Archive := preload("res://scripts/archive.gd")
const SLOTS := ["user://save_1.json", "user://save_2.json", "user://save_3.json"]
const PATHS := ["user://archive.json", "user://archive_export.json", "user://save_1.json", "user://save_2.json", "user://save_3.json"]

var game
var fails := 0
var backup := {}

func _initialize() -> void:
	for p in PATHS:
		backup[p] = _read(p)
		_remove(p)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t

func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _restore() -> void:
	for p in PATHS:
		_remove(p)
		var t: String = backup.get(p, "")
		if t != "":
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f != null:
				f.store_string(t)
				f.close()

func _check(name: String, ok: bool, extra := "") -> void:
	if ok:
		print("  [PASS] ", name, ("　" + extra) if extra != "" else "")
	else:
		fails += 1
		print("  [FAIL] ", name, ("　" + extra) if extra != "" else "")

func _press(key: int) -> void:
	var e1 := InputEventKey.new()
	e1.physical_keycode = key
	e1.pressed = true
	Input.parse_input_event(e1)
	await process_frame
	var e2 := InputEventKey.new()
	e2.physical_keycode = key
	e2.pressed = false
	Input.parse_input_event(e2)
	await process_frame

func _run() -> void:
	for i in range(30):
		await process_frame

	print("== 1. 空档案 ==")
	var d := Archive.load_data()
	_check("0017 未开始", Archive.status_of(d["cases"]["0017"]) == "未开始", Archive.status_of(d["cases"]["0017"]))
	_check("落盘 schema_version=1", int(d.get("schema_version", 0)) == Archive.SCHEMA_VERSION)
	game.menu.set_slots(game.slots_info(), "load")
	game.menu.show_slots("load")
	await process_frame
	_check("汇总 已结案 0/6 · 结局 0/3", game.menu.archive_summary.text == "已结案 0/6 · 结局 0/3", game.menu.archive_summary.text)
	var locked_ok := true
	for i in range(1, Archive.CASES.size()):
		if game.menu.case_rows[i]["status"].text != "尚未开启":
			locked_ok = false
			print("    ", Archive.CASES[i]["no"], " → ", game.menu.case_rows[i]["status"].text)
	_check("0018–0022 与终章均「尚未开启」", locked_ok)
	_check("0017 行显示 已见 0/3 结局", game.menu.case_rows[0]["ends"].text == "已见 0/3 结局", game.menu.case_rows[0]["ends"].text)

	print("== 2. 新档玩到结局 A ==")
	game.menu.slots_panel.visible = false
	game._on_new_game()
	for i in range(5):
		await process_frame
	d = Archive.load_data()
	_check("新局 plays=1", int(d["cases"]["0017"]["plays"]) == 1, str(d["cases"]["0017"]["plays"]))
	_check("新局状态 进行中", Archive.status_of(d["cases"]["0017"]) == "进行中", Archive.status_of(d["cases"]["0017"]))

	game._on_start()
	for i in range(5):
		await process_frame
	game.round_card.visible = false
	game.round = 3
	for it in game.items:
		it["got"] = true
	game.handle = true
	game.late = false
	game.sub = ""
	game.sub_queue.clear()
	game.sub_pause = false
	game.clock_min = 1457.2
	var t0 := Time.get_ticks_msec()
	while game.state != "cutscene" and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	game._skip_cutscene()
	t0 = Time.get_ticks_msec()
	while game.choice == null and game.state != "ending" and Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	await _press(KEY_E)
	_check("到达结局 A", game.shown_end == "A", game.hud_end_title.text)

	d = Archive.load_data()
	var e: Dictionary = d["cases"]["0017"]
	_check("completed=true", bool(e["completed"]))
	_check("endings=[A]", e["endings"] == ["A"], str(e["endings"]))
	_check("best_round=3", int(e["best_round"]) == 3, str(e["best_round"]))
	_check("best_clock 记录到结局时刻", absf(float(e["best_clock"]) - 1457.2) < 1.0, Archive.clock_text(float(e["best_clock"])))

	game._show_menu()
	await process_frame
	game.menu.set_slots(game.slots_info(), "load")
	game.menu.show_slots("load")
	await process_frame
	_check("档案汇总 已结案 1/6 · 结局 1/3", game.menu.archive_summary.text == "已结案 1/6 · 结局 1/3", game.menu.archive_summary.text)
	_check("0017 行 已结案", game.menu.case_rows[0]["status"].text == "已结案", game.menu.case_rows[0]["status"].text)
	_check("0017 行 已见 1/3 结局", game.menu.case_rows[0]["ends"].text == "已见 1/3 结局", game.menu.case_rows[0]["ends"].text)
	_check("0017 行最佳记录", game.menu.case_rows[0]["sub"].text.contains("最佳：第 4 轮"), game.menu.case_rows[0]["sub"].text)

	print("== 3. 槽位与档案相互独立 ==")
	_check("存档到槽位 1", game.game_save(0))
	_check("槽位 1 文件存在", FileAccess.file_exists(SLOTS[0]))
	game.menu.set_slots(game.slots_info(), "load")
	game.menu._on_delete_pressed(0)
	game.menu._on_delete_pressed(0)   # 第二次点击 = 确认删除，信号由 game 处理
	await process_frame
	_check("槽位 1 已删除", not FileAccess.file_exists(SLOTS[0]))
	d = Archive.load_data()
	_check("删槽位后档案仍是 已结案", bool(d["cases"]["0017"]["completed"]))
	_check("删槽位后结局仍是 A", d["cases"]["0017"]["endings"] == ["A"], str(d["cases"]["0017"]["endings"]))
	_check("删槽位后汇总不变", game.menu.archive_summary.text == "已结案 1/6 · 结局 1/3", game.menu.archive_summary.text)
	_check("槽位按钮回到 空", game.menu.slot_btns[0].text.contains("空"), game.menu.slot_btns[0].text.replace("\n", " / "))

	print("== 4. 导出 / 导入 ==")
	_check("导出到 user://", Archive.export_to_file())
	var text := Archive.export_text()
	_check("导出文本含 schema_version", text.contains("\"schema_version\""))
	_check("导出文本含 endings", text.contains("\"endings\""))
	var res := Archive.import_text(text)
	_check("重复导入 ok（幂等）", bool(res["ok"]))
	_check("重复导入不增加结局", Archive.endings_seen(Archive.load_data()["cases"]["0017"]) == 1)

	var obj = JSON.parse_string(text)
	obj["cases"]["0017"]["endings"] = ["A", "B"]
	var res2 := Archive.import_text(JSON.stringify(obj))
	_check("导入合并 ok", bool(res2["ok"]))
	_check("导入后结局并集 A,B", Archive.load_data()["cases"]["0017"]["endings"] == ["A", "B"], str(Archive.load_data()["cases"]["0017"]["endings"]))
	_check("导入坏文件被拒绝", not bool(Archive.import_text("{not json").get("ok", true)))

	print("== 汇总 ==", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	if game != null:
		game.archive_tracking = false
		game.set_process(false)
	_restore()
	quit(0 if fails == 0 else 1)
