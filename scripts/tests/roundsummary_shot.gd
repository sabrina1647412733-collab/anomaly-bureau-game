extends SceneTree
## 结算卡截图：用于版式验收
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _run() -> void:
	for i in range(40):
		await process_frame
	game._on_start()
	for i in range(30):
		await process_frame
	game.round = 0
	for it in game.items:
		if String(it["def"]["id"]) == "red":
			it["got"] = true
	game._show_round_summary("00:17。0017 次没有进站。\n屏幕只留下一行灰字：列车位置未知。\n\n「又是半秒。和十七年前一模一样。」——林岚")
	game.hud_fade.modulate.a = 0.0
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/look/"))
	img.save_png("res://_预览/look/rs_结算.png")
	print("[SHOT] rs_结算.png ", img.get_width(), "x", img.get_height())
	quit()