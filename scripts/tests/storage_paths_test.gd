extends SceneTree
var failed := 0
var passed := 0
const Store := preload("res://scripts/storage_paths.gd")
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	if value:passed+=1;print("PASS ",label)
	else:failed+=1;push_error(label)
func run() -> void:
	check(OS.get_cmdline_user_args().has("--verify"),"存储测试必须隔离玩家数据")
	if failed>0:quit(1);return
	var directory=Store.root_dir()
	check(directory.begins_with(ProjectSettings.globalize_path("res://")),"默认测试目录位于当前F盘工程内")
	check(directory.contains("验证数据") and directory.contains("storage_paths_test"),"各测试使用独立目录")
	check(FileAccess.file_exists(directory.path_join(".gdignore")),"玩家数据不参与资源导入")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false);game.set_process(false)
	game.player.global_position=Vector3(.5,12.1,322.)
	check(game.SLOT_PATHS[0]==Store.file("save_1.json"),"手动槽位使用便携路径")
	check(game.exit_save.PATH==Store.file("autosave.json"),"退出自动档使用便携路径")
	check(preload("res://scripts/case_save.gd").PROGRESS_PATH==Store.file("laundry_archive.json"),"结案记录使用便携路径")
	check(preload("res://scripts/archive.gd").PATH==Store.file("archive.json"),"旧档案也使用便携路径")
	check(game.game_save(0),"实际写入手动槽位")
	check(FileAccess.file_exists(Store.file("save_1.json")),"手动文件确实位于F盘")
	game.player.global_position=Vector3(1.,12.1,322.)
	check(game.game_load(0) and absf(game.player.global_position.x-.5)<.01,"实际读档恢复位置")
	check(game.delete_slot(0) and not FileAccess.file_exists(Store.file("save_1.json")),"删除只作用于当前便携槽位")
	game.menu._save_settings()
	check(FileAccess.file_exists(Store.file("settings.cfg")),"设置文件确实写入F盘")
	DirAccess.remove_absolute(Store.file("settings.cfg"))
	game.queue_free();await process_frame;await process_frame;await create_timer(.12).timeout
	print("RESULT: %d passed / %d failed"%[passed,failed]);quit(0 if failed==0 else 1)
