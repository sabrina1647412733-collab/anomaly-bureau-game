extends SceneTree
## External acceptance driver for an EXPORTED game, never packed into the game.
const Service := preload("res://scripts/update_service.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var input := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-config="): input = arg.trim_prefix("--probe-config=")
	if input.is_empty(): quit(2); return
	var data = JSON.parse_string(FileAccess.get_file_as_string(input))
	var updater := Service.new(); root.add_child(updater)
	updater.check_updates()
	await updater.changed
	print("PROBE_GITHUB ", updater.state, " ", updater.message)
	if updater.state != "current": quit(3); return
	updater.restart_args = PackedStringArray(["--headless", "--audio-driver", "Dummy", "--log-file", str(data.child_log)])
	updater.latest = {"tag_name":"v" + str(data.version)}
	# Local HTTP transport is injected ONLY by this external test driver.
	# Production selection still requires the exact GitHub HTTPS URL and digest.
	updater.asset = {"browser_download_url":data.url, "digest":"sha256:" + str(data.sha256), "size":int(data.size)}
	updater.changed.connect(func():
		print("PROBE ", updater.state, " ", updater.message)
		if updater.state == "error": quit(1))
	var limit := Timer.new(); root.add_child(limit); limit.one_shot = true; limit.start(180)
	limit.timeout.connect(func(): push_error("probe timed out"); quit(2))
	updater.download_update()
