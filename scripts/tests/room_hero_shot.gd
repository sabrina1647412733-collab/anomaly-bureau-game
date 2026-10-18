extends SceneTree
var game
func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()
func shot(name: String, pos: Vector3, yaw: float, pitch: float) -> void:
	game.player.position = pos
	game.player.rotation.y = yaw
	game.player.cam.rotation.x = pitch
	game.player.velocity = Vector3.ZERO
	for i in range(18): await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png("res://_预览/look/" + name + ".png")
	print("[SHOT] ", name)
func _run() -> void:
	for i in range(40): await process_frame
	game.menu.start_game.emit()
	for i in range(60): await process_frame
	game.player.can_move = false
	game.player.view_arm.visible = false
	game.hud.visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/look/"))
	await shot("room_hero_1_start", Vector3(-0.35, 12.1, 323.05), PI, -0.02)
	await shot("room_hero_2_wide", Vector3(-0.2, 12.1, 321.25), PI, -0.05)
	await shot("room_hero_3_bed", Vector3(1.55, 12.1, 323.65), PI * 0.30, -0.10)
	await shot("room_hero_4_desk", Vector3(-1.35, 12.1, 322.55), -PI * 0.34, -0.06)
	await shot("room_hero_5_window", Vector3(-0.1, 12.1, 323.4), PI, 0.0)
	await shot("room_hero_6_north", Vector3(-0.2, 12.1, 324.15), 0.0, -0.04)
	quit()
