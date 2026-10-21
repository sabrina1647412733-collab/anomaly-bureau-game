extends SceneTree
var game
var OUT := "res://_预览/接手优化/"

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--ui-720"):
		OUT = "res://_预览/接手优化_720p/"
	_run()

func settle(frames := 14) -> void:
	for i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	await settle()
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("[SHOT] ", name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle(30)
	await shot("01_主菜单")
	game._hide_menu()
	game._start_prologue(false)
	game._clear_sub()
	game.start_laundry_case()
	game.set_process(false)
	game._clear_sub()
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(0, 3.58, 9.4)
	game.player.rotation.y = 0
	game.player.pitch = -0.10
	game.player.cam.rotation.x = -0.10
	game.hud_fade.modulate.a = 0.0
	game._update_hud()
	await shot("02_洗衣店")
	game.laundry._open_final_choice()
	game._update_interaction()
	game._show_sub("她", "是不是洗好了？", 3.0, false)
	game.hud_sub.text = "是不是洗好了？"
	game.hud_sub_title.text = "她"
	await shot("03_处置选择")
	game.choice = null
	game.laundry.selected_ending = "C"
	game.laundry.complete_case()
	await shot("04_结局归档")
	game.state = "play"
	game.hud_end.text = ""
	game.hud_end_title.text = ""
	game.note("物", "灰色卫衣", "没有牌子，没有尺码标。\n\n衣领上有一点洗不掉的旧痕迹。")
	game.note("物", "童装毛衣", "藏青色，袖口是白条纹。\n\n2004-11-07，七号机，童装一套，未取。")
	game._toggle_notebook()
	await shot("05_记事本")
	game.nb.close()
	game._open_pause()
	await shot("06_暂停")
	game.menu.show_slots("save")
	await shot("07_存档")
	game.menu._show_settings(true)
	await shot("08_设置")
	game.queue_free()
	await process_frame
	quit()
