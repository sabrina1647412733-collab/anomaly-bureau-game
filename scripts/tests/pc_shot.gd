extends SceneTree
var game
func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()
func _run() -> void:
	for i in range(40): await process_frame
	game._on_start()
	for i in range(20): await process_frame
	game._act("pc")
	await process_frame
	game.pc_overlay.call("_reveal", 4, 4)
	game.pc_overlay.call("_reveal", 5, 4)
	game.pc_overlay.call("_reveal", 3, 4)
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/look/"))
	img.save_png("res://_预览/look/pc_扫雷.png")
	print("[SHOT] pc_扫雷 ", img.get_width(), "x", img.get_height())
	game.pc_overlay.call("_show_file")
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	var img2: Image = root.get_texture().get_image()
	img2.save_png("res://_预览/look/pc_事故名单.png")
	print("[SHOT] pc_事故名单 ", img2.get_width(), "x", img2.get_height())
	quit()