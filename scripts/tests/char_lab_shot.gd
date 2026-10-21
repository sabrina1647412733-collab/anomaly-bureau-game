extends SceneTree
## 角色实验室截图：多角度 + 多动画帧
const OUT := "res://_预览/角色/"
var scene
var frames := 0
var idx := -1
var cooldown := 0
var shoot_now := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	scene = load("res://scenes/char_lab.tscn").instantiate()
	root.add_child(scene)
	RenderingServer.frame_post_draw.connect(_grab)

func _process(_d: float) -> bool:
	frames += 1
	if frames < 20:
		return false
	if idx < 0:
		idx = 0
		_apply(0)
		cooldown = 0
		return false
	cooldown += 1
	# 每 8 帧截一张
	if cooldown % 8 == 0:
		shoot_now = true
	return false

var shots := [
	{"n": "A1_正面", "p": Vector3(0, 1.15, 3.2), "t": Vector3(0, 0.85, 0), "fov": 42.0},
	{"n": "A2_侧面", "p": Vector3(3.2, 1.15, 0.2), "t": Vector3(0, 0.85, 0), "fov": 42.0},
	{"n": "A3_背面", "p": Vector3(0, 1.15, -3.0), "t": Vector3(0, 0.85, 0), "fov": 42.0},
	{"n": "A4_近脸", "p": Vector3(0, 1.50, 1.1), "t": Vector3(0, 1.42, 0), "fov": 32.0},
	{"n": "A5_全身", "p": Vector3(-2.0, 1.3, 3.4), "t": Vector3(0, 0.85, 0), "fov": 48.0},
]

func _grab() -> void:
	if not shoot_now:
		return
	shoot_now = false
	if idx >= shots.size():
		quit()
		return
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT + shots[idx]["n"] + ".png")
	print("[SHOT] ", shots[idx]["n"])
	idx += 1
	if idx >= shots.size():
		quit()
		return
	_apply(idx)
	cooldown = 0

func _apply(i: int) -> void:
	if i >= shots.size():
		return
	var v = shots[i]
	var cam: Camera3D = scene.get_node("Cam")
	cam.current = true
	cam.position = v["p"]
	cam.fov = v["fov"]
	cam.look_at(v["t"], Vector3.UP)
