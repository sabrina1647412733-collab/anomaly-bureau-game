extends SceneTree
## 302 后房 / 3F 相关验收截图（追加到 laundry_upper_shot 之后）。
##   Godot_..._console.exe --path . --script res://scripts/tests/laundry_302_shot.gd
const OUT := "res://_预览/洗衣店/场景/"

var scene
var idx := -1
var frames := 0
var cooldown := 0
var shoot_now := false
var shots := [
	# 302 后房：从门口往里看，锅炉在左、水痕从锅炉往门口爬
	{"n": "54_3F_302后房", "p": Vector3(-0.40, 8.30, 1.55), "t": Vector3(-2.90, 7.62, -0.45), "fov": 84.0},
	# 302 水痕特写：俯视，看得到“往上走”的方向
	{"n": "55_3F_302水痕往上走", "p": Vector3(-0.90, 8.68, 1.60), "t": Vector3(-2.60, 6.97, -0.20), "fov": 86.0},
	# 302 锅炉（与 2F 后房上下对齐）
	{"n": "56_3F_302锅炉", "p": Vector3(-1.30, 8.26, 0.25), "t": Vector3(-2.95, 7.55, -0.60), "fov": 74.0},
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
	if cooldown == 18:
		shoot_now = true
	return false

func _grab() -> void:
	if not shoot_now:
		return
	shoot_now = false
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT + shots[idx]["n"] + ".png")
	print("[SHOT] ", shots[idx]["n"], " ", img.get_width(), "x", img.get_height())
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
