extends SceneTree
# Acceptance-only script, never included in delivered resource packs.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var base := OS.get_executable_path().get_base_dir()
	for arg in args:
		if arg.begins_with("--runtime-root="): base = arg.trim_prefix("--runtime-root=")
	print("CONTENT_PROBE root=", base)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("_运行文件/active.json")))
	for group in ["base", "code_ui", "maps", "case1", "case2", "characters_audio"]:
		var rows: Array[String] = []
		for f in manifest.files:
			if f.group == group: rows.append("%s\t%s\t%d" % [f.path, f.sha256, int(f.size)])
		if rows.is_empty(): continue
		rows.sort()
		if not ProjectSettings.load_resource_pack(base.path_join("_运行文件/packs/%s-%s.zip" % [group, "\n".join(rows).sha256_text()]), true): quit(2); return
	ProjectSettings.set_setting("application/config/version", str(manifest.version))
	print("CONTENT_PROBE packs mounted")
	var menu = load("res://scripts/menu.gd").new(); root.add_child(menu); menu.setup(SystemFont.new())
	var updater = load("res://scripts/update_service.gd").new(); root.add_child(updater)
	var view = load("res://scripts/update_panel.gd").new(); menu.add_child(view); view.setup(menu, updater)
	var model_scene: PackedScene = load("res://assets/models/case1_props/shoe.glb")
	var model := model_scene.instantiate()
	var label := str(view.primary.text)
	var candidate := {"tag_name":"v0.8.2","assets":[{"name":"AnomalyBureau-manifest-v3.json","size":100,"digest":"sha256:"+"a".repeat(64),"browser_download_url":"https://github.com/sabrina1647412733-collab/anomaly-bureau-game/releases/download/v0.8.2/AnomalyBureau-manifest-v3.json"}]}
	var supported: bool = not updater._select_group_manifest(candidate).is_empty()
	var ok: bool = label == "安装更新" and absf(model.scale.x - 1.02) < 0.0001 and str(manifest.version) == "0.8.2" and supported
	var result := {"ok":ok,"version":manifest.version,"ui_label":label,"model_x":model.scale.x,"transport":manifest.transport,"cross_release_manifest_supported":supported}
	for arg in args:
		if arg.begins_with("--result="):
			var file := FileAccess.open(arg.trim_prefix("--result="),FileAccess.WRITE)
			file.store_string(JSON.stringify(result));file.close()
	model.free()
	menu.queue_free(); updater.queue_free()
	print("CONTENT_PROOF ", JSON.stringify(result))
	quit(0 if ok else 1)
