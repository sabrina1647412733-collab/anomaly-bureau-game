extends SceneTree
## 1F 门厅验收截图。不加 --headless（否则拿不到帧）。
## 注意：不能在 _process 里 await frame_post_draw —— 协程返回值会被当成“继续”，
## 只能抓一张就退。改成挂 frame_post_draw 信号，_process 只管推进状态。
const OUT := "res://_预览/洗衣店/"

var scene
var idx := -1
var frames := 0
var cooldown := 0
var shoot_now := false
var shots := [
	{"n": "01_门厅_北望", "p": Vector3(-1.70, 1.62, 14.2), "t": Vector3(0.30, 1.30, 0.0), "fov": 70.0},
	{"n": "02_信箱墙", "p": Vector3(-1.35, 1.45, 5.45), "t": Vector3(-3.2, 1.35, 4.15), "fov": 55.0},
	{"n": "03_楼梯", "p": Vector3(1.55, 1.30, 15.4), "t": Vector3(1.55, 3.2, 11.4), "fov": 72.0},
	{"n": "04_洗衣店_进门", "p": Vector3(0.00, 5.15, 10.00), "t": Vector3(-1.50, 4.40, 2.20), "fov": 78.0},
	{"n": "05_洗衣店_西侧机组", "p": Vector3(-1.20, 5.10, 9.40), "t": Vector3(-2.85, 4.35, 5.20), "fov": 74.0},
	{"n": "06_洗衣店_东侧", "p": Vector3(1.20, 5.10, 9.40), "t": Vector3(2.85, 4.35, 5.20), "fov": 74.0},
	{"n": "11_后房_门开", "p": Vector3(-1.20, 4.75, 2.60), "t": Vector3(-1.30, 4.10, 0.20), "fov": 72.0},
	{"n": "12_七号机_毛衣", "p": Vector3(0.06, 4.26, 3.35), "t": Vector3(0.0, 4.04, 2.62), "fov": 32.0},
	{"n": "13_303卧室", "p": Vector3(-0.45, 8.40, 5.10), "t": Vector3(-2.85, 7.75, 3.35), "fov": 80.0},
	{"n": "14_304孩子房", "p": Vector3(0.45, 8.28, 4.95), "t": Vector3(2.35, 7.75, 2.75), "fov": 78.0},
	{"n": "15_3F走廊", "p": Vector3(0.20, 8.42, 9.80), "t": Vector3(-0.40, 8.10, 5.40), "fov": 72.0},
	{"n": "16_老太太_全身", "p": Vector3(1.45, 4.52, 3.05), "t": Vector3(1.45, 4.30, 5.55), "fov": 44.0},
	{"n": "17_老太太_近", "p": Vector3(1.45, 4.50, 4.05), "t": Vector3(1.45, 4.42, 5.55), "fov": 34.0},
	{"n": "08_后房_进门", "p": Vector3(-1.15, 4.95, 1.55), "t": Vector3(-1.60, 4.25, -0.70), "fov": 74.0},
	{"n": "09_后房_照片墙", "p": Vector3(-1.95, 4.85, 0.35), "t": Vector3(-0.70, 4.95, -0.70), "fov": 62.0},
	{"n": "10_后房_锅炉", "p": Vector3(-0.85, 4.80, 0.55), "t": Vector3(-2.90, 4.15, -0.70), "fov": 68.0},
	{"n": "07_洗衣店_七号机", "p": Vector3(0.0, 4.95, 5.20), "t": Vector3(0.0, 4.10, 2.40), "fov": 54.0},
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	scene = load("res://scenes/laundry.tscn").instantiate()
	root.add_child(scene)
	RenderingServer.frame_post_draw.connect(_grab)

var night_ready := false

func _process(_d: float) -> bool:
	frames += 1
	if frames == 3 and not night_ready:
		night_ready = true
		var night = scene.get_node_or_null("FirstNight")
		if night != null:
			night.spinning[1] = true
			night.spinning[2] = true
			night.spinning[3] = true
			night._spawn_lady()
			night.npc_t = 6.0
	if frames < 24:
		return false
	if idx < 0:
		idx = 0
		_apply(idx)
		cooldown = 0
		return false
	cooldown += 1
	if cooldown == 16:
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
