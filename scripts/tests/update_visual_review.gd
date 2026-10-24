extends SceneTree
var output := ""
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-out="): output = arg.trim_prefix("--review-out=")
	if output.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await create_timer(1).timeout
	var service = game.get_node("Updates")
	var view = game.menu.get_node("UpdatePanel")
	await shot("01_main_menu")
	view.show_history()
	var deadline := Time.get_ticks_msec() + 25000
	while service.history_busy and Time.get_ticks_msec() < deadline: await process_frame
	await shot("02_github_history")
	view.close()
	service.latest = {"tag_name":"v0.6.1", "published_at":"2026-10-24T10:00:00Z", "name":"回潮镇 · 功能更新", "body":"此图使用测试版本信息，仅用于验证更新界面。\n\n• 修复调查流程与交互问题\n• 改善街道细节和声音表现\n• 保留已有存档与设置\n\n点击立即更新后，游戏会下载、校验并自动重新启动。"}
	service.asset = {"size":104857600}
	service._set_state("available", "发现新版本 v0.6.1")
	view.show_update(); await shot("03_update_prompt")
	service._set_state("downloading", "正在下载更新…")
	service.progress.emit(57671680,104857600)
	await shot("04_download_progress")
	service._set_state("available", "test"); view.close()
	print("VISUAL_REVIEW_COMPLETE ",output); quit()
