extends SceneTree

const OUT := "res://_预览/回潮镇接入/"

func _initialize() -> void:
	_run()

func _shot(file: String) -> void:
	await create_timer(0.4).timeout
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(OUT + file + ".png")
	print("[TOWN SHOT] ", file, " error=", error, " size=", image.get_size())

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(6):
		await process_frame
	game._hide_menu()
	game._start_prologue(false)
	game.town_bridge.enter()
	game._clear_sub()
	game.hud_fade.modulate.a = 0.0
	game.player.set_physics_process(false)
	game.set_process(false)
	game.player._update_body(0.016, 0.0)
	game.player._update_camera(0.016, 0.0, false)
	game.town_bridge.update_map()
	await _shot("01_出租公寓外_第三人称与小地图")
	game.town_bridge.toggle_map()
	await _shot("02_全镇地图与地点")
	game.town_bridge.toggle_map()
	var place: Dictionary = game.town_bridge._landmark("01")
	var front: Array = place.get("front", [])
	game.player.global_position = game.town_bridge.ORIGIN + Vector3(float(front[0]), 0.1, float(front[1]) + 3.0)
	game.player.look_at(game.town_bridge.ORIGIN + Vector3(float(front[0]), 1.2, float(front[1])), Vector3.UP)
	game.player.cam_mode = 0
	game.player._update_body(0.016, 0.0)
	game.player._update_camera(0.016, 0.0, false)
	game.town_bridge.update_map()
	game._update_hud()
	await _shot("03_洗衣店门前_第一人称")
	game.field_kit.rig.set_item("phone")
	await _shot("04_第一人称_持手机与角色手臂")
	game.field_kit.rig.set_item("")
	game.player.cam_mode = 2
	game.player._update_body(0.016, 0.0)
	game.player._update_camera(0.016, 0.0, false)
	await _shot("05_第二人称_正面角色")
	game.queue_free()
	for i in range(3):
		await process_frame
	quit()
