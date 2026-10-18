extends SceneTree
## 便利店室内定点截图：只摆相机，不改玩法状态。
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
	print("[STORE] ", nm, " ", img.get_width(), "x", img.get_height())

func _pose(pos: Vector3, yaw: float, pitch: float) -> void:
	game.player.position = pos
	game.player.rotation.y = yaw
	game.player.pitch = pitch
	game.player.cam.rotation.x = pitch
	for i in range(3):
		await process_frame
	await create_timer(0.20).timeout

func _run() -> void:
	for i in range(40):
		await process_frame
	game.menu.start_game.emit()
	await create_timer(0.45).timeout
	game._show_prologue_stage("store")
	game.player.can_move = false
	game.player.allow_capture = false
	game.player.lock_look = true
	game._clear_sub()
	game.prologue_objective = "看看店里"
	game._prologue_set_objective("看看店里")
	await _pose(Vector3(0, 0.1, 502.32), 0.0, -0.05)
	await _shot("store_01_entrance")
	await _pose(Vector3(0, 0.1, 501.25), 0.0, -0.04)
	await _shot("store_02_backwall")
	await _pose(Vector3(0.35, 0.1, 500.55), -PI * 0.5, -0.08)
	await _shot("store_03_counter")
	await _pose(Vector3(-1.55, 0.1, 500.50), PI * 0.5, -0.04)
	await _shot("store_04_shelf")
	await _pose(Vector3(1.55, 0.1, 502.05), -PI * 0.62, -0.10)
	await _shot("store_05_magazine")
	await _pose(Vector3(-2.00, 0.1, 502.20), -PI * 0.22, -0.05)
	await _shot("store_06_wide")
	quit()
