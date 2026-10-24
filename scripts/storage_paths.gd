extends RefCounted
## Desktop data follows the existing project/game folder; web keeps IndexedDB.
static var cached_root := ""
static var inspection_active := false
const LEGACY := ["autosave.json","save_1.json","save_2.json","save_3.json","settings.cfg","laundry_archive.json","archive.json","archive_export.json"]

static func root_dir() -> String:
	if OS.has_feature("web"):return "user://"
	if not cached_root.is_empty():return cached_root
	var override_dir := ""
	var verify := OS.get_cmdline_user_args().has("--verify")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--data-dir="):override_dir=argument.trim_prefix("--data-dir=").replace("\\","/")
	var base := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	var local_name := "_玩家数据"
	if verify:
		var test_name := "启动验证"
		for argument in OS.get_cmdline_args():
			if argument.ends_with(".gd"):test_name=argument.replace("\\","/").get_file().get_basename()
		local_name="_预览/验证数据/"+test_name
	cached_root=override_dir if not override_dir.is_empty() else base.path_join(local_name)
	DirAccess.make_dir_recursive_absolute(cached_root)
	var ignore=FileAccess.open(cached_root.path_join(".gdignore"),FileAccess.WRITE)
	if ignore!=null:ignore.close()
	# Read old data once without deleting or changing anything in AppData.
	if not verify:
		for name in LEGACY:
			var destination=cached_root.path_join(name)
			if not FileAccess.file_exists(destination) and FileAccess.file_exists("user://"+name):
				DirAccess.copy_absolute(ProjectSettings.globalize_path("user://"+name),destination)
	return cached_root

static func file(name: String) -> String:
	return root_dir().path_join(name)
