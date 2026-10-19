extends SceneTree
## 验收截图：真·新档玩到结局 A → 打开案卷目录，应显示「已结案 1/6 · 结局 1/3」。
## 会备份并还原本机档案与槽位。

const Archive := preload("res://scripts/archive.gd")
const OUT := "res://_预览/截图/"
const PATHS := ["user://archive.json", "user://archive_export.json", "user://save_1.json", "user://save_2.json", "user://save_3.json"]

var game
var backup := {}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
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
	var t := f.get_as_text() if f != null else ""
	if f != null:
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
	for i in range(40):
		await process_frame
	# 真·新档（开始值班）
	game._on_new_game()
	for i in range(5):
		await process_frame
	game._on_start()
	for i in range(5):
		await process_frame
	# 快进到最后一轮，满足结局 A 条件
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
	print("[SHOT] 结局=", game.shown_end, " 标题=", game.hud_end_title.text)

	# 回主菜单 → 载入存档 → 案卷目录
	game._show_menu()
	for i in range(20):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await process_frame
	game.menu.set_slots(game.slots_info(), "load")
	game.menu.show_slots("load")
	for i in range(20):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT + "archive_after_ending_a.png")
	print("[SHOT] archive_after_ending_a ", game.menu.archive_summary.text)
	if game != null:
		game.archive_tracking = false
		game.set_process(false)
	_restore()
	quit()
