extends SceneTree
## 固定机位对比截图（当前观感 vs 改版观感）
## 用法： godot --path . --script res://scripts/tests/look_shots.gd -- before
## 说明：只读地摆相机，不改任何游戏状态；输出到 res://_预览/look/<tag>_NN_名字.png
var game
var tag := "look"

const POSES := [
	["01_站台全景",      Vector3(-6.0, 0.25, 6.0),   0.0,        0.02],
	["02_站台朝南",      Vector3(-6.0, 0.25, -30.0), PI,         0.02],
	["03_调度台",        Vector3(-15.30, 0.25, -14.0), PI * 0.5, -0.10],
	["04_继电器柜",      Vector3(-15.80, 0.25, 28.2), PI * 0.5,  -0.02],
	["05_值班室",        Vector3(-14.50, 0.25, 12.0), 0.0,       -0.02],
	["06_地面与轨道",    Vector3(-2.0, 0.25, 3.0),    0.0,       -0.55],
]

func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0:
		tag = ua[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/look/"))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _settle(n := 12) -> void:
	for i in range(n):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await process_frame
	await RenderingServer.frame_post_draw

func _look(p: Vector3, yaw: float, pitch_v: float) -> void:
	game.player.global_position = p
	game.player.rotation.y = yaw
	game.player.pitch = pitch_v
	game.player.cam.rotation.x = pitch_v

func _run() -> void:
	await _settle(40)
	game._on_start()
	await _settle(25)
	for p in POSES:
		_look(p[1], p[2], p[3])
		await _settle(28)
		var path := "res://_预览/look/%s_%s.png" % [tag, p[0]]
		var img: Image = root.get_texture().get_image()
		img.save_png(path)
		print("[LOOK] ", path, "  ", img.get_width(), "x", img.get_height())
	print("[LOOK] 完成 tag=", tag)
	quit()