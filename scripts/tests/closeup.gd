extends SceneTree
## 定点近景截图：给某个道具/构件/角色拍一张定点照，便于逐件检查。
## 用法： godot --path . --script res://scripts/tests/closeup.gd -- <名> <x> <y> <z> <yaw> <pitch> [fov] [flags...]
##   flags（可多个，任意顺序）：npc=让三个 NPC 现身；sit=让玩家坐下
##   yaw/pitch 用弧度，可写 PI*0.5 之类的表达式；fov 省略时沿用玩家相机。
## 说明：只读地摆相机，不改任何游戏状态；输出 res://_预览/look/<名>.png
var game

func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() < 6:
		print("[CLOSEUP] 参数不足：需要 <名> <x> <y> <z> <yaw> <pitch> [fov] [flags...]")
		quit(1)
		return
	print("[DBG0] args=", ua)
	var nm := ua[0]
	var flags := []
	var fov := -1.0
	for i in range(6, ua.size()):
		if _is_num(ua[i]):
			if fov < 0.0:
				fov = num(ua[i])
		else:
			flags.append(ua[i])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/look/"))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run(nm, num(ua[1]), num(ua[2]), num(ua[3]), num(ua[4]), num(ua[5]), fov, flags)

func _is_num(s: String) -> bool:
	var allow := "0123456789.+-*/() 	PIpiTAU"
	for i in range(s.length()):
		if not allow.contains(s[i]):
			return false
	return s.length() > 0

func num(s: String) -> float:
	var e := Expression.new()
	if e.parse(s) == OK:
		var v = e.execute()
		if v is float or v is int:
			return float(v)
	return float(s)

func _settle(n := 12) -> void:
	for i in range(n):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await process_frame
	await RenderingServer.frame_post_draw

func _run(nm: String, x: float, y: float, z: float, yaw: float, pitch: float,
		fov: float, flags: Array) -> void:
	await _settle(40)
	game._on_start()
	await _settle(25)
	if flags.has("npc"):
		for np in game.npcs:
			np["node"].visible = true
	if flags.has("seats"):
		for i in range(game.builder.seats.size()):
			var st: Dictionary = game.builder.seats[i]
			print("[SEAT] #", i, " pos=", st["pos"], " yaw=", st["yaw"])
	var seat_idx := -1
	for f in flags:
		if str(f).begins_with("seat="):
			seat_idx = int(str(f).substr(5))
	if seat_idx >= 0 and seat_idx < game.builder.seats.size():
		var s: Dictionary = game.builder.seats[seat_idx]
		game.player.sit_at(s["pos"], float(s["yaw"]))
		print("[CLOSEUP] 坐在 #", seat_idx, " ", s["pos"])
		if flags.has("sit"):
			game.player.sitting = true
	elif flags.has("sit"):
		game.player.sitting = true
	game.player.pitch = pitch
	game.player.cam.rotation.x = pitch
	game.player.lock_look = true      # 截图期间锁住鼠标转头
	if seat_idx < 0:
		game.player.global_position = Vector3(x, y, z)
		game.player.rotation.y = yaw
	if flags.has("items"):
		for it in game.items:
			it["node"].visible = true
	if flags.has("clues"):
		for it in game.items:
			it["got"] = true
		game.saw_lag = true
		game._refresh_items_ui()
		var vis := ""
		for bc in game.board_cards:
			vis += ("1" if bc["node"].visible else "0")
		print("[BOARD] 卡片可见性（7 张，应全 1）= ", vis)
	for f in flags:
		if str(f).begins_with("clock="):
			game.clock_min = float(str(f).substr(6))
			print("[CLOSEUP] 时钟拨到 ", game.clock_min)
	if flags.has("train"):
		var sz := 0.0
		for f2 in flags:
			if str(f2).begins_with("z="):
				sz = float(str(f2).substr(2))
		game.train.place(game.train.s_at_z(sz))
		game.train.lights_on(true)
		print("[CLOSEUP] 列车前部摆到 z≈", sz)
	if flags.has("talk"):
		var np: Dictionary = game.npcs[0]
		np["node"].visible = true
		game.dialog_npc = np
		game._say(String(np["name"]), "这台机子昨晚响过三次。")
		print("[CLOSEUP] 触发对话 ", np["name"])
	if flags.has("noarm"):
		game.player.view_arm.visible = false
	if flags.has("third"):
		game.player.toggle_cam()
	if flags.has("cctv"):
		for i in range(2):
			game.player.toggle_cam()
	if flags.has("cam3"):
		for i in range(3):
			game.player.toggle_cam()
	var old_fov: float = game.player.cam.fov
	if fov > 0.0:
		game.player.cam.fov = fov
	await _settle(30)
	# 注意：_settle 里切 mouse_mode 会让系统丢来一个大的 mouse_motion，把 pitch 带跑
	# （调试打印抓到过 -0.55 被改成 +0.5，于是画面永远在拍天花板）。拍之前把 pitch 再钉一次。
	game.player.pitch = pitch
	game.player.cam.rotation.x = pitch
	game.player.lock_look = true      # 截图期间锁住鼠标转头
	await process_frame
	await RenderingServer.frame_post_draw
	print("[DBG] player=", game.player.global_position, " cam=", game.player.cam.global_position,
		" camrot=", game.player.cam.rotation, " pitch=", game.player.pitch,
		" mode=", game.player.cam_mode, " current=", game.player.cam.current,
		" fov=", game.player.cam.fov)
	var path := "res://_预览/look/%s.png" % nm
	var img: Image = root.get_texture().get_image()
	img.save_png(path)
	print("[CLOSEUP] ", path, "  ", img.get_width(), "x", img.get_height(),
		"  fov=", game.player.cam.fov, "  flags=", flags)
	game.player.cam.fov = old_fov
	quit()
