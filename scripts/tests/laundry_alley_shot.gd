extends SceneTree
## 后巷 / 消防梯验收截图
const OUT := "res://_预览/洗衣店/场景/"
var scene
var idx := -1
var frames := 0
var cooldown := 0
var shoot_now := false
var shots := [
	# 后巷：从东端往西看（能看到死巷、路灯、两侧的窗户）
	{"n": "64_后巷_东望", "p": Vector3(8.0, 1.62, -12.0), "t": Vector3(-9.0, 1.50, -12.2), "fov": 76.0},
	# 后巷：从西端往东看（消防梯在这一头）
	{"n": "65_后巷_西望消防梯", "p": Vector3(-6.5, 1.60, -12.3), "t": Vector3(6.5, 3.20, -11.0), "fov": 74.0},
	# 洗衣店后门：堵死的那块砖
	{"n": "66_后巷_洗衣店后门", "p": Vector3(0.10, 1.55, -12.4), "t": Vector3(1.35, 1.10, -9.95), "fov": 62.0},
	# 消防梯：仰视
	{"n": "67_后巷_消防梯仰视", "p": Vector3(6.0, 1.30, -13.4), "t": Vector3(6.0, 11.0, -10.6), "fov": 78.0},
	# 消防梯：4F 平台视角（爬到一半，能看到洗衣店亮着的窗）
	{"n": "68_后巷_洗衣店亮着的窗", "p": Vector3(6.0, 9.85, -11.0), "t": Vector3(-1.15, 5.00, -9.95), "fov": 70.0},
]
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	scene = load("res://scenes/laundry.tscn").instantiate()
	root.add_child(scene)
	RenderingServer.frame_post_draw.connect(_grab)
func _process(_d: float) -> bool:
	frames += 1
	if frames < 26:
		return false
	if idx < 0:
		idx = 0
		_apply(idx)
		cooldown = 0
		return false
	cooldown += 1
	if cooldown == 20:
		shoot_now = true
	return false
func _grab() -> void:
	if not shoot_now:
		return
	shoot_now = false
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
	var s = shots[i]
	var cam: Camera3D = scene.get_node("Cam")
	cam.current = true
	cam.position = s["p"]
	cam.fov = s["fov"]
	cam.look_at(s["t"], Vector3.UP)
