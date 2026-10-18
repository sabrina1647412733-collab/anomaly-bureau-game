extends SceneTree
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/look/"))
	img.save_png("res://_预览/look/" + nm + ".png")
	print("[TRAVEL] ", nm, " ", img.get_width(), "x", img.get_height())

func _run() -> void:
	for i in range(40):
		await process_frame
	game.menu.start_game.emit()
	await create_timer(0.45).timeout
	game.prologue_letter_ready = true
	game.prologue_letter_read = true
	game.prologue_call_done = true
	game.prologue_anomaly_done = true
	game.state = "prologue_end"
	game.prologue_end_card.visible = true
	game._open_travel_menu()
	await create_timer(0.35).timeout
	await _shot("travel_menu")
	game._travel_to("store")
	await create_timer(1.4).timeout
	game._clear_sub()
	game.player.can_move = false
	game.player.allow_capture = false
	game.player.lock_look = true
	game.player.position = Vector3(0.35, 0.1, 500.55)
	game.player.rotation.y = -PI * 0.5
	game.player.pitch = -0.08
	game.player.cam.rotation.x = -0.08
	for i in range(4):
		await process_frame
	await create_timer(0.25).timeout
	await _shot("store_07_clerk")
	quit()
