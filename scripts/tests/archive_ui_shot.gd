extends SceneTree
## 案卷目录截图：空档案 / 已结案 + 槽位 两种状态。测试后还原真实档案。

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

func _settle(n := 12) -> void:
	for i in range(n):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await process_frame
	await RenderingServer.frame_post_draw

func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT + nm + ".png")
	print("[SHOT] ", nm, " ", img.get_width(), "x", img.get_height())

func _run() -> void:
	await _settle(45)
	game.menu.set_slots(game.slots_info(), "load")
	game.menu.show_slots("load")
	await _settle(20)
	await _shot("archive_empty")

	# 种一份「已结案 1/6 · 结局 1/3」：0017 结局 A + 一个进行中的槽位
	Archive.note_play("0017")
	Archive.note_ending("0017", "A", 3, 1456.7166)
	game.round = 2
	game.clock_min = 1452.0
	game.game_save(0)
	game.menu.set_slots(game.slots_info(), "load")
	game.menu.show_slots("load")
	game.menu.set_archive_note("档案与槽位分开保存：删槽位不会清除档案。")
	await _settle(20)
	await _shot("archive_progress")

	# 存档模式（暂停 → 存档）也要能看到同一份目录
	game.menu.show_slots("save")
	await _settle(15)
	await _shot("archive_save_mode")

	if game != null:
		game.archive_tracking = false
		game.set_process(false)
	_restore()
	quit()
