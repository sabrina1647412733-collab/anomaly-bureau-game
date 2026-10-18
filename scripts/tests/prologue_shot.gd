extends SceneTree
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/look/"))
	img.save_png("res://_预览/look/" + name + ".png")
	print("[SHOT] ", name, " ", img.get_width(), "x", img.get_height())

func _wait_sub(part: String, timeout := 6.0) -> void:
	var t := 0.0
	while t < timeout and not game.hud_sub.text.contains(part):
		await create_timer(0.1).timeout
		t += 0.1
	await create_timer(0.2).timeout

func _wait_end(timeout := 12.0) -> void:
	var t := 0.0
	while t < timeout and game.state != "prologue_end":
		await create_timer(0.1).timeout
		t += 0.1
	await create_timer(1.5).timeout

func _pose(pos: Vector3, yaw: float, pitch: float) -> void:
	game.player.position = pos
	game.player.rotation.y = yaw
	game.player.pitch = pitch
	game.player.cam.rotation.x = pitch
	for i in range(2):
		await process_frame
	await create_timer(0.18).timeout

func _run() -> void:
	for i in range(40):
		await process_frame
	game.menu.start_game.emit()
	await _wait_sub("凌晨", 3.0)
	game.player.can_move = false
	game.player.allow_capture = false
	game.player.lock_look = true
	# 开场英雄镜头：从窗边回看整间出租屋
	await _pose(Vector3(0.20, 12.1, 324.70), 0.0, -0.03)
	await _shot("slice_01_start")
	await _pose(Vector3(-0.35, 12.1, 323.05), PI, -0.02)
	await _pose(Vector3(1.55, 12.1, 323.65), PI * 0.30, -0.10)
	await _shot("slice_02_bed")
	await _pose(Vector3(-0.60, 12.1, 322.35), -PI * 0.60, -0.05)
	await _shot("slice_03_desk")
	await _pose(Vector3(-0.10, 12.1, 323.40), PI, 0.0)
	await _shot("slice_04_window")
	game._prologue_act("phone")
	game._prologue_act("box")
	await process_frame
	game._prologue_act("door")
	await create_timer(0.45).timeout
	await _shot("slice_05_letter")
	game._close_letter()
	for i in range(4):
		await process_frame
	game._prologue_act("phone")
	for i in range(4):
		await process_frame
	await _pose(Vector3(-0.10, 12.1, 323.40), PI, 0.0)
	game._prologue_act("window")
	# 00:17 这一刻：钟跳到 00:17，第一句字幕已经读完
	await create_timer(2.5).timeout
	await _shot("slice_06a_clock")
	# 人影淡入完成，第二句字幕读完，目标 HUD 已收起
	await _wait_sub("看了一眼", 6.0)
	await _shot("slice_06_0017")
	await _wait_end()
	await _shot("slice_07_end")
	quit()
