extends SceneTree
## 本轮视觉验收：出租屋广角 / 床 / 厨房 / 书架 / 灯开关 / 交互环 / 车站照明开关。
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _pose(pos: Vector3, yaw: float, pitch: float) -> void:
	game.player.position = pos
	game.player.rotation.y = yaw
	game.player.pitch = pitch
	game.player.cam.rotation.x = pitch
	game.player.velocity = Vector3.ZERO
	for i in range(12):
		await process_frame
	await create_timer(0.15).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/look/"))
	img.save_png("res://_预览/look/" + name + ".png")
	print("[SHOT] ", name, " ", img.get_width(), "x", img.get_height())

func _run() -> void:
	for i in range(36):
		await process_frame
	game.menu.start_game.emit()
	for i in range(20):
		await process_frame
	game.player.can_move = false
	game.player.allow_capture = false
	game.player.view_arm.visible = false
	game._clear_sub()
	game.hud.visible = false
	game._set_prologue_room_lights(true)

	# 广角：从窗前回看左后床与右后厨房
	await _pose(Vector3(-0.10, 12.1, 324.55), 0.0, -0.08)
	await _shot("prologue_room_wide")
	# 床左后角
	await _pose(Vector3(0.20, 12.1, 323.25), 0.93, -0.12)
	await _shot("prologue_bed_left_back")
	# 右后厨房 / 洗手台
	await _pose(Vector3(-0.50, 12.1, 323.30), -0.98, -0.10)
	await _shot("prologue_kitchen_sink")
	# 左前书架
	await _pose(Vector3(0.50, 12.1, 322.80), 1.88, -0.08)
	await _shot("prologue_bookshelf")
	# 门边开关：开
	await _pose(Vector3(0.30, 12.1, 321.00), -0.33, -0.28)
	await _shot("prologue_switch_on")
	# 门边开关：关
	game._set_prologue_room_lights(false)
	await create_timer(0.25).timeout
	await _shot("prologue_switch_off")
	# 关灯后房间广角：仍有窗外冷光
	await _pose(Vector3(-0.10, 12.1, 324.55), 0.0, -0.08)
	await _shot("prologue_room_lights_off")
	# 交互环近景：书桌手机。桌面不应出现大光斑。
	game._set_prologue_room_lights(true)
	game.hud.visible = true
	await _pose(Vector3(2.50, 12.1, 322.45), PI, -0.55)
	game._clear_sub()
	game._update_prologue_interaction()
	await create_timer(0.35).timeout
	print("[RING] prompt=", game.prompt, " hud=", game.hud_prompt.text, " player=", game.player.global_position, " ring=", game.prompt_ring.global_position, " vis=", game.prompt_ring.visible)
	await _shot("prologue_prompt_ring_phone")
	game.hud.visible = false

	# 车站照明：开 / 关
	game._on_start()
	for i in range(30):
		await process_frame
	game.player.can_move = false
	game.player.allow_capture = false
	game.player.view_arm.visible = false
	game.player.cam.attributes = null
	game.hud.visible = false
	await _pose(Vector3(-7.0, 0.25, 8.0), 0.0, 0.0)
	await _shot("station_lights_on")
	game._act("station_light_switch")
	await create_timer(0.30).timeout
	await _shot("station_lights_off")
	game._act("station_light_switch")
	await create_timer(0.20).timeout
	quit()


