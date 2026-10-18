extends SceneTree
## 铁路/轨道专项截图：隐藏 HUD，只拍道床、钢轨、隧道和岔区。
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
	print("[RAIL] ", nm, " ", img.get_width(), "x", img.get_height())

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
	await _pose(Vector3(-1.35, 1.15, -8.0), -PI * 0.5, -0.28)
	await _shot("rail_01_side")
	await _pose(Vector3(4.0, 0.85, -18.0), PI, -0.06)
	await _shot("rail_02_along")
	await _pose(Vector3(4.0, 0.85, -62.0), 0.0, 0.0)
	await _shot("rail_03_tunnel")
	await _pose(Vector3(10.5, 0.85, -80.0), PI, -0.05)
	await _shot("rail_04_branch")
	quit()
