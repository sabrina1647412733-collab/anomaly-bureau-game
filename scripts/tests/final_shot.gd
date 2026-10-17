extends SceneTree
var game
func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()
func _run() -> void:
	for i in range(30): await process_frame
	game._on_start()
	game.round_card.visible = false
	game.round = 3
	for it in game.items: it["got"] = true
	game.handle = true; game.late = false
	game.clock_min = 1457.2
	var t0 := Time.get_ticks_msec()
	while game.state != "cutscene" and Time.get_ticks_msec() - t0 < 3000: await process_frame
	game._skip_cutscene()
	t0 = Time.get_ticks_msec()
	while game.choice == null and game.state != "ending" and Time.get_ticks_msec() - t0 < 5000: await process_frame
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/look/"))
	img.save_png("res://_预览/look/final_choice.png")
	print("[SHOT] final_choice ", img.get_width(), "x", img.get_height())
	quit()