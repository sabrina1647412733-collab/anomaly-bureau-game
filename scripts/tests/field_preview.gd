extends SceneTree
const OUT := "res://_预览/手机背包/"
var game

func _initialize() -> void:
	_run()

func settle(count := 16) -> void:
	for i in range(count): await process_frame
	await RenderingServer.frame_post_draw

func shot(id: String) -> void:
	await create_timer(.35).timeout
	game.sub = ""
	await settle()
	root.get_texture().get_image().save_png(OUT + id + ".png")
	print("[SHOT] ", id)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle(20)
	game._hide_menu()
	game._start_prologue(false)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(0.6,12.08,322.4)
	game.player.rotation.y = -1.1
	game.player.cam.rotation.x = -.05
	game.hud_fade.modulate.a = 0.0
	game._clear_sub()
	game.field_kit.pickup_phone()
	game.phone_ui._goto("home")
	await shot("01_手机桌面")
	game.phone_ui._goto("conversation")
	await shot("02_聊天软件")
	game.phone_ui.incoming = true
	game.phone_ui._goto("incoming")
	await shot("03_来电")
	game.field_kit.answer_phone()
	game.phone_ui._goto("in_call")
	await shot("03b_通话字幕")
	game._close_phone()
	await shot("04_手持手机")
	game.field_kit.stow()
	game._prologue_drop_letter()
	game._pick_envelope()
	await shot("05_第一次信封")
	game.envelope_refused = 1
	game._show_envelope_choice()
	await shot("06_第二次信封")
	game._accept_envelope()
	game.field_kit.generation += 1
	game._clear_sub()
	game.field_kit.open_inventory(true)
	await shot("07_背包")
	game.field_kit.select("envelope")
	game.field_kit.take_selected()
	await shot("08_手持信件")
	game.start_laundry_case()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(1.5,.08,-5.5)
	game.player.rotation.y = -.48
	game.player.cam.rotation.x = -.85
	game._clear_sub()
	game._update_interaction()
	await shot("09_服务梯")
	game.field_kit.generation += 1
	game._discard_laundry()
	game.queue_free()
	await process_frame
	await process_frame
	quit()
