extends SceneTree

var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/map/"))
	img.save_png("res://_预览/map/" + name + ".png")
	print("[SHOT] ", name)

func _pose(pos: Vector3, yaw: float, pitch: float) -> void:
	game.player.position = pos
	game.player.rotation.y = yaw
	game.player.pitch = pitch
	if game.player.cam != null:
		game.player.cam.rotation.x = pitch
	for i in range(3):
		await process_frame
	await create_timer(0.2).timeout

func _run() -> void:
	for i in range(60):
		await process_frame
	game.menu.start_game.emit()
	await create_timer(2.0).timeout
	game.player.can_move = false
	game.player.allow_capture = false
	game.player.lock_look = true
	if game.hud != null:
		game.hud.visible = false
	game.state = "play"

	# ---- 站台：站在中央往四方向看 ----
	await _pose(Vector3(-9.0, 1.7, 0.0), 0.0, 0.0)
	await _shot("c1_platform_north")
	await _pose(Vector3(-9.0, 1.7, 0.0), PI, 0.0)
	await _shot("c2_platform_south")
	await _pose(Vector3(-9.0, 1.7, -28.0), PI, 0.0)
	await _shot("c5_dispatch_area")
	await _pose(Vector3(-6.0, 1.7, 8.0), -PI * 0.5, 0.0)
	await _shot("c3_platform_to_track")
	await _pose(Vector3(-9.0, 1.7, -45.0), 0.0, 0.05)
	await _shot("c4_platform_tunnel_north")

	# ---- 调度席：退到 4 米外看 ----
	await _pose(Vector3(-11.5, 1.55, -14.0), PI * 0.5, -0.12)
	await _shot("d1_dispatch_console")
	await _pose(Vector3(-11.0, 1.6, -10.0), PI * 0.85, -0.05)
	await _shot("d2_dispatch_room")

	# ---- 值班记录板 ----
	await _pose(Vector3(-13.5, 1.7, -14.5), PI * 0.5, 0.0)
	await _shot("e1_board")

	# ---- 信号室：从门口往里 ----
	await _pose(Vector3(-12.6, 1.6, 28.3), PI * 0.5, 0.0)
	await _shot("f1_signal_room")
	await _pose(Vector3(-13.0, 1.6, 24.8), 0.0, 0.0)
	await _shot("f3_relay_corridor")
	await _pose(Vector3(-15.5, 1.6, 31.0), PI * 0.25, 0.0)
	await _shot("f2_relay_cabinet")

	# ---- 值班室 ----
	await _pose(Vector3(-12.3, 1.6, 8.5), PI * 0.5, 0.0)
	await _shot("g1_duty_room")
	await _pose(Vector3(-16.9, 1.6, 5.0), 0.0, 0.0)
	await _shot("g2_duty_desk")

	# ---- 广播台 ----
	await _pose(Vector3(-12.8, 1.6, 39.0), PI * 0.5, 0.0)
	await _shot("h1_studio")
	await _pose(Vector3(-15.0, 1.6, 35.5), 0.0, 0.0)
	await _shot("h2_studio_desk")
	await _pose(Vector3(-16.5, 1.6, 43.0), 0.0, 0.0)
	await _shot("h3_tape_shelf")

	# ---- 失物招领 ----
	await _pose(Vector3(-13.0, 1.6, -32.3), PI * 0.5, 0.0)
	await _shot("i1_lost_found")

	# ---- 长椅 ----
	await _pose(Vector3(-11.0, 1.6, 17.0), PI * 0.5, -0.05)
	await _shot("k1_bench")

	# ---- 总手柄 ----
	await _pose(Vector3(-13.6, 1.6, 30.8), PI * 0.5, -0.05)
	await _shot("l1_handle")

	# ---- 岔区 ----
	await _pose(Vector3(4.0, 0.4, -90.0), 0.0, 0.0)
	await _shot("j1_branch")

	print("[MAP SHOTS DONE]")
	quit()
