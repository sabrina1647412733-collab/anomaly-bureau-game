extends SceneTree
## 廊桥 + 老邮局验收截图
const OUT := "res://_预览/洗衣店/场景/"
var scene
var idx := -1
var frames := 0
var cooldown := 0
var shoot_now := false
var shots := [
	# 廊桥：从主楼这头往老邮局看
	{"n": "69_廊桥_向东", "p": Vector3(3.60, 5.10, 10.0), "t": Vector3(13.0, 4.60, 10.0), "fov": 76.0},
	# 廊桥：地板锈穿的洞（俯视）
	{"n": "70_廊桥_锈穿的地板", "p": Vector3(5.20, 5.30, 10.0), "t": Vector3(6.20, 3.50, 10.0), "fov": 62.0},
	# 老邮局：一排没投出去的邮筒
	{"n": "71_老邮局_邮筒", "p": Vector3(15.5, 5.20, 13.6), "t": Vector3(17.5, 4.40, 4.90), "fov": 74.0},
	# 老邮局：一整房间退回的信
	{"n": "72_老邮局_退回的信", "p": Vector3(18.0, 5.30, 12.6), "t": Vector3(15.0, 3.70, 13.8), "fov": 78.0},
	# 那封挂号信（主角）
	{"n": "73_老邮局_那封挂号信", "p": Vector3(17.2, 4.55, 10.2), "t": Vector3(18.0, 3.95, 8.4), "fov": 52.0},
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
