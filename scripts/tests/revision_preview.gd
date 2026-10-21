extends SceneTree
var game
const OUT := "res://_预览/20261021改进/"
var output_dir := OUT
func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--preview-small"): output_dir="res://_预览/20261021改进_720p/"
	run()
func shot(name: String) -> void:
	game._clear_sub()
	game.director.step(0)
	game.director.toast.visible = false
	game._update_hud()
	await create_timer(.4).timeout
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir+name+".png")
	print("[SHOT] ",name)
func view(foot: Vector3,target: Vector3) -> void:
	game.player.set_physics_process(false)
	game.player.global_position=foot
	game.player.rotation=Vector3.ZERO
	game.player.cam.position=Vector3(0,1.66,0)
	game.player.cam.look_at(target)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	await process_frame
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._hide_menu()
	game._start_prologue(false)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.hud_fade.modulate.a=0
	game._ring_phone()
	game.field_kit.pickup_phone()
	await shot("01_房东催租来电")
	game.field_kit.answer_phone()
	await create_timer(1.1).timeout
	game.phone_ui.active_chat="派遣科"
	game.phone_ui._goto("conversation")
	await shot("02_招聘消息与工作目标")
	game._close_phone()
	game.field_kit.stow()
	game._pick_envelope()
	game._refuse_envelope()
	await create_timer(3.6).timeout
	view(Vector3(1.43,12.08,323.6),game.prologue_envelope.global_position)
	await shot("03_第二封信_实际桌面模型")
	game._pick_envelope()
	await shot("04_第二次只有同意")
	game._accept_envelope()
	await create_timer(.9).timeout
	game.field_kit.pickup_clock()
	await shot("05_随身时钟与事件")
	game.director.close_clock(true)
	game.field_kit.open_inventory(true)
	game.field_kit.select("weird_clock")
	await shot("06_六乘四方格背包")
	game.field_kit.open_inventory(false)
	game.field_kit.equip("phone")
	view(Vector3(3.0,12.08,322.0),Vector3(4.0,13.5,322.0))
	await shot("07_近墙持物_独立深度")
	game.field_kit.stow()
	game.start_laundry_case()
	game.player.set_physics_process(false)
	game.set_process(false)
	var views := [
		["08_三楼走廊",Vector3(0,6.98,9.2),Vector3(0,8.0,5.7)],
		["09_三楼卧室",Vector3(-1.7,6.98,6.0),Vector3(-1.5,7.8,3.0)],
		["10_四楼走廊",Vector3(1.0,9.88,9.0),Vector3(0,11.1,5.4)],
		["11_四楼杂物间",Vector3(0,9.88,4.8),Vector3(0,10.8,3.0)],
		["12_五楼走廊",Vector3(0,12.78,9.0),Vector3(0,14.0,5.4)],
		["13_五楼空屋",Vector3(-1.7,12.78,4.9),Vector3(-1.7,13.2,3.3)],
		["14_折返楼梯",Vector3(.91,8.43,13.6),Vector3(2.4,9.6,11.0)],
		["15_屋顶出口",Vector3(2.1,15.68,9.0),Vector3(-2,17.0,6.0)],
		["16_三楼回廊封闭",Vector3(-.3,6.98,16.4),Vector3(-.3,8.5,11.0)]
	]
	for entry in views:
		view(entry[1],entry[2])
		await shot(entry[0])
	game.field_kit.generation+=1
	game._discard_laundry()
	game.queue_free()
	await process_frame
	await process_frame
	quit()
