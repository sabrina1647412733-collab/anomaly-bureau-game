extends Node
## This script deliberately has no game-resource preload. Mount before parsing main.
class TestExit extends Node:
	var seconds := 12.0
	func _process(_delta: float) -> void:
		if get_tree().current_scene == null or get_tree().current_scene.scene_file_path != "res://scenes/main.tscn": return
		get_tree().create_timer(seconds).timeout.connect(get_tree().quit)
		set_process(false)

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--verify"):
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--distribution-test-exit-seconds="):
				var exit_timer := TestExit.new()
				exit_timer.seconds = clampf(float(argument.get_slice("=", 1)), 5.0, 180.0)
				get_tree().root.add_child.call_deferred(exit_timer)
	var base := OS.get_executable_path().get_base_dir()
	var path := base.path_join("_运行文件/active.json")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary or manifest.get("protocol") != 2:
		push_error("资源清单缺失或无效，请重新运行完整安装包。"); get_tree().quit(1); return
	for group in ["base", "code_ui", "maps", "case1", "case2", "characters_audio"]:
		var rows: Array[String] = []
		for item in manifest.files:
			if item.group == group: rows.append("%s\t%s\t%d" % [item.path, item.sha256, int(item.size)])
		if rows.is_empty(): continue
		rows.sort()
		var pack := base.path_join("_运行文件/packs/%s-%s.zip" % [group, "\n".join(rows).sha256_text()])
		if not ProjectSettings.load_resource_pack(pack, true):
			push_error("资源包无法挂载：" + pack); get_tree().quit(1); return
	ProjectSettings.set_setting("application/config/version", str(manifest.version))
	print("GROUP_BOOT version=", manifest.version, " mounted_before_main=true")
	# No scene or script has been loaded yet. All subsequent loads see the selected set.
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
