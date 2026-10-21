extends SceneTree
## 配电房验收截图
const OUT := "res://_预览/洗衣店/场景/"
var scene
var idx := -1
var frames := 0
var cooldown := 0
var shoot_now := false
var shots := [
	# 配电房全景：从门口看进去
	{"n": "74_配电房_全景", "p": Vector3(4.20, 4.72, 7.86), "t": Vector3(4.20, 4.40, 6.30), "fov": 88.0},
	# 总闸 + 少一根的保险丝
	{"n": "75_配电房_总闸与保险丝", "p": Vector3(4.20, 4.80, 7.80), "t": Vector3(3.98, 4.55, 6.36), "fov": 66.0},
	# 1998 年电路图（那根通向 B1 蓄水池的线 + 勿动）
	{"n": "76_配电房_电路图", "p": Vector3(4.05, 4.95, 7.70), "t": Vector3(5.12, 5.02, 7.05), "fov": 64.0},
	# 门外的挂锁
	{"n": "77_配电房_门与挂锁", "p": Vector3(2.55, 4.85, 7.05), "t": Vector3(3.18, 4.55, 7.08), "fov": 58.0},
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
