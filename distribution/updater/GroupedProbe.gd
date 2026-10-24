extends Node
## Acceptance-only autoload; never included in the delivered bootstrap or packs.
var config: Dictionary = {}
var service: Node
var view: Control
var deadline := 0
var started := false
var live_verified := false
var content_check: Dictionary = {}
var downloaded_bytes := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--group-probe="):
			config = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--group-probe=")))
		if arg.begins_with("--distribution-content-check="):
			content_check = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--distribution-content-check=")))
	deadline = Time.get_ticks_msec() + 90000
	set_process(not config.is_empty() or not content_check.is_empty())

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline: push_error("Group UI probe timeout"); get_tree().quit(1); return
	var game := get_tree().current_scene
	if game == null or not game.has_node("Updates"): return
	if not content_check.is_empty():
		var scene: PackedScene = load("res://assets/models/case1_props/shoe.glb")
		var model := scene.instantiate()
		var label := str(game.menu.get_node("UpdatePanel").primary.text)
		var version := str(ProjectSettings.get_setting("application/config/version"))
		var correct: bool = absf(model.scale.x - float(content_check.model_x)) < 0.0001 and label == str(content_check.ui_label) and version == str(content_check.version)
		var result := FileAccess.open(str(content_check.result), FileAccess.WRITE)
		result.store_string(JSON.stringify({"ok":correct, "version":version, "model_x":model.scale.x, "ui_label":label})); result.close()
		model.free(); set_process(false)
		if not correct: push_error("Updated resources do not match the selected manifest"); get_tree().quit(1)
		return
	if service == null:
		service = game.get_node("Updates")
		view = game.menu.get_node("UpdatePanel")
		service.progress.connect(func(bytes: int, _total: int): downloaded_bytes = bytes)
		service.check_updates()
	elif service.state == "error":
		push_error("Group UI probe: " + service.message); get_tree().quit(1)
	elif service.state == "downloading" and config.get("exit_during_download", false) and downloaded_bytes > int(config.get("exit_after_bytes", 7173)):
		var proof := FileAccess.open(str(config.exit_result), FileAccess.WRITE)
		proof.store_string(JSON.stringify({"normal_tree_quit":true, "downloaded_bytes":downloaded_bytes})); proof.close()
		get_tree().quit()
	elif service.state == "current" and not live_verified:
		live_verified = true
		service.restart_args = PackedStringArray(config.restart_args)
		service.latest = {"tag_name":"v" + str(config.get("version", "0.7.1")), "published_at":"2026-10-24T00:00:00Z", "body":"## 新增内容\n- 安装更新按钮。"}
		service._group_manifest = str(config.manifest)
		service._group_asset = {"digest":"sha256:" + str(config.sha256), "browser_download_url":str(config.url), "size":int(config.size)}
		service.asset = service._group_asset
		service._prepare_group_manifest()
	elif service.state == "available" and not started:
		started = true
		view.show_update()
		var file := FileAccess.open(str(config.result), FileAccess.WRITE)
		file.store_string(JSON.stringify({"plan_bytes":service.download_bytes, "primary_enabled":not view.primary.disabled, "message":service.message, "exported_github_live":live_verified}))
		file.close()
		view.primary.pressed.emit()
