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
	print("[TRAIN] ", nm, " ", img.get_width(), "x", img.get_height())

func _pose(pos: Vector3, yaw: float, pitch: float) -> void:
	game.player.position = pos
	game.player.rotation.y = yaw
	game.player.pitch = pitch
	game.player.cam.rotation.x = pitch
	for i in range(4):
		await process_frame
	await create_timer(0.22).timeout

func _run() -> void:
	for i in range(40):
		await process_frame
	game._on_start()
	await create_timer(0.7).timeout
	game.player.can_move = false
	game.player.allow_capture = false
	game.player.lock_look = true
	game.player.body.visible = false
	game.player.show_view_arm = false
	if game.player.view_arm != null:
		game.player.view_arm.visible = false
	game.hud.visible = false
	game.hud_clock.visible = false
	game.hud_map.visible = false
	if game.bag != null:
		game.bag.visible = false
	game.train.set_divert(false)
	game.train.place(game.train.s_at_z(-8.0) + game.train.last_front_offset())
	game.train.lights_on(true)
	await _pose(Vector3(-7.0, 1.55, -2.0), -PI * 0.5, 0.02)
	await _shot("train_01_side")
	await _pose(Vector3(-5.0, 1.55, 20.0), 0.0, 0.03)
	await _shot("train_02_platform")
	await _pose(Vector3(4.0, 0.85, 18.0), 0.0, 0.02)
	await _shot("train_03_front")
	quit()
