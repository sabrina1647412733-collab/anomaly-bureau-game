extends SceneTree
## Legacy archive data compatibility. The active case uses its own unique-ending
## ledger; obsolete metro menu rows and three ending chips are not gameplay tests.
const Archive := preload("res://scripts/archive.gd")
const Store := preload("res://scripts/storage_paths.gd")
var passed := 0
var failed := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error(label)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--verify"):
		push_error("Run archive compatibility with -- --verify only");quit(1);return
	check(Archive.PATH.begins_with(Store.root_dir()),"旧档案跟随隔离F盘目录")
	check(Archive.save_data(Archive.empty_data()),"可创建隔离档案")
	var data=Archive.load_data()
	check(data.schema_version==Archive.SCHEMA_VERSION,"保留旧schema版本")
	check(Archive.status_of(data.cases["0017"])=="未开始","空历史记录可读取")
	Archive.note_play("0017");data=Archive.load_data()
	check(data.cases["0017"].plays==1,"旧游玩计数可保存")
	check(Archive.status_of(data.cases["0017"])=="进行中","旧状态可读取")
	Archive.note_progress("0017",3,1457.2)
	Archive.note_ending("0017","A",3,1457.2);data=Archive.load_data()
	check(data.cases["0017"].completed,"旧结案标记保留")
	check(data.cases["0017"].endings==["A"],"旧结局列表保留")
	check(data.cases["0017"].best_round==3,"旧最佳轮次保留")
	check(absf(data.cases["0017"].best_clock-1457.2)<.01,"旧时刻保留")
	check(Archive.export_to_file(),"导出默认写入便携目录")
	check(FileAccess.file_exists(Archive.EXPORT_PATH),"导出文件确实位于F盘")
	var text=Archive.export_text()
	check(text.contains("schema_version") and text.contains("endings"),"导出含兼容字段")
	check(Archive.import_text(text).ok,"导入兼容文件")
	check(Archive.endings_seen(Archive.load_data().cases["0017"])==1,"重复导入保持幂等")
	check(not Archive.import_text("{bad json").ok,"拒绝损坏导入")
	check(Archive.load_data().cases["0017"].endings==["A"],"坏导入不破坏已有记录")
	for path in [Archive.PATH,Archive.EXPORT_PATH]:DirAccess.remove_absolute(path)
	print("RESULT: %d passed / %d failed"%[passed,failed]);quit(0 if failed==0 else 1)
