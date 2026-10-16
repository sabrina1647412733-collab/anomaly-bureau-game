extends SceneTree
## 单点近景截图：给某个道具/构件拍一张定点照，便于逐件检查。
## 用法： godot --path . --script res://scripts/tests/closeup.gd -- <名> <x> <y> <z> <yaw> <pitch> [fov]
##   yaw/pitch 用弧度（可写 PI*0.5 之类的表达式求值），fov 默认沿用玩家相机。
## 说明：只读地摆相机，不改任何游戏状态；输出 res://_预览/look/<名>.png
var game

func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() < 6:
		print("[CLOSEUP] 参数不足：需要 <名> <x> <y> <z> <yaw> <pitch> [fov]")
		quit(1)
		return
	var nm := ua[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/look/"))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run(nm, _num(ua[1]), _num(ua[2]), _num(ua[3]), _num(ua[4]), _num(ua[5]),
	     _num(ua[6]) if ua.size() > 6 else -1.0)

func _num(s: String) -> float:
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

func _run(nm: String, x: float, y: float, z: float, yaw: float, pitch: float, fov: float) -> void:
	await _settle(40)
	game._on_start()
	await _settle(25)
	game.player.global_position = Vector3(x, y, z)
	game.player.rotation.y = yaw
	game.player.pitch = pitch
	game.player.cam.rotation.x = pitch
	var old_fov: float = game.player.cam.fov
	if fov > 0.0:
		game.player.cam.fov = fov
	await _settle(30)
	var path := "res://_预览/look/%s.png" % nm
	var img: Image = root.get_texture().get_image()
	img.save_png(path)
	print("[CLOSEUP] ", path, "  ", img.get_width(), "x", img.get_height(), "  fov=", game.player.cam.fov)
	game.player.cam.fov = old_fov
	quit()
