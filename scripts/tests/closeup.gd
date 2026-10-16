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
	if seat_idx < 0:
		game.player.global_position = Vector3(x, y, z)
		game.player.rotation.y = yaw
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
	var path := "res://_预览/look/%s.png" % nm
	var img: Image = root.get_texture().get_image()
	img.save_png(path)
	print("[CLOSEUP] ", path, "  ", img.get_width(), "x", img.get_height(),
		"  fov=", game.player.cam.fov, "  flags=", flags)
	game.player.cam.fov = old_fov
	quit()
