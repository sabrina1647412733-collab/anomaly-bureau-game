extends SceneTree
## 上层/地下层验收截图。不加 --headless。
## 输出：_预览/洗衣店/场景/
const OUT := "res://_预览/洗衣店/场景/"

var scene
var idx := -1
var frames := 0
var cooldown := 0
var shoot_now := false
var shots := [
	# —— 4F
	{"n": "30_4F走廊_好灯", "p": Vector3(0.0, 11.15, 9.60), "t": Vector3(-0.3, 10.75, 5.40), "fov": 70.0},
	{"n": "31_4F_402老周家", "p": Vector3(-1.35, 11.20, 5.00), "t": Vector3(-3.05, 10.55, 3.10), "fov": 76.0},
	{"n": "32_4F_402管线图", "p": Vector3(-1.75, 11.05, 4.15), "t": Vector3(-3.15, 10.55, 4.35), "fov": 62.0},
	{"n": "33_4F_403缝纫机", "p": Vector3(0.72, 11.18, 4.95), "t": Vector3(-0.15, 10.35, 3.05), "fov": 76.0},
	{"n": "34_4F_疏散图", "p": Vector3(1.10, 11.05, 8.10), "t": Vector3(3.15, 11.45, 7.30), "fov": 58.0},
	# —— 5F
	{"n": "35_5F走廊_无灯", "p": Vector3(0.90, 13.95, 9.80), "t": Vector3(-0.6, 13.20, 5.60), "fov": 76.0},
	{"n": "36_5F_502人形水渍", "p": Vector3(-0.55, 14.10, 5.00), "t": Vector3(-1.75, 12.70, 3.40), "fov": 74.0},
	{"n": "37_5F_502天窗", "p": Vector3(-1.65, 13.10, 5.10), "t": Vector3(-1.72, 15.30, 3.50), "fov": 64.0},
	{"n": "38_5F_503门缝光", "p": Vector3(1.70, 13.42, 7.45), "t": Vector3(1.70, 12.86, 5.50), "fov": 54.0},
	{"n": "39_5F_503玩具机群", "p": Vector3(3.05, 14.10, 5.10), "t": Vector3(1.10, 12.80, 3.60), "fov": 76.0},
	{"n": "40_5F_503湿床", "p": Vector3(2.30, 13.85, 4.70), "t": Vector3(1.75, 12.85, 2.55), "fov": 70.0},
	# —— 屋顶
	{"n": "41_屋顶_水箱", "p": Vector3(1.60, 17.30, 10.20), "t": Vector3(-3.40, 16.40, 6.20), "fov": 68.0},
	{"n": "42_屋顶_晾衣绳7件", "p": Vector3(5.30, 17.10, 9.80), "t": Vector3(-2.60, 17.05, 2.60), "fov": 74.0},
	{"n": "43_屋顶_天窗俯视", "p": Vector3(-1.70, 17.20, 6.20), "t": Vector3(-1.70, 15.32, 3.50), "fov": 54.0},
	{"n": "44_屋顶_全景", "p": Vector3(5.20, 17.60, 11.40), "t": Vector3(-2.00, 16.10, 2.60), "fov": 76.0},
	# —— B1
	{"n": "45_B1_锅炉房", "p": Vector3(2.90, -1.55, -2.20), "t": Vector3(-3.30, -1.90, -5.60), "fov": 76.0},
	{"n": "46_B1_阀门勿动", "p": Vector3(-1.80, -1.10, -6.10), "t": Vector3(-2.60, -1.55, -8.75), "fov": 64.0},
	{"n": "47_B1_蓄水池", "p": Vector3(3.10, -1.42, 6.85), "t": Vector3(2.60, -4.10, 3.10), "fov": 76.0},
	{"n": "48_B1_水位线", "p": Vector3(4.75, -1.55, 1.35), "t": Vector3(2.30, -2.55, 4.60), "fov": 72.0},
	{"n": "49_B1_竖井底凉鞋", "p": Vector3(3.70, -1.35, -4.30), "t": Vector3(3.30, -2.95, -6.00), "fov": 70.0},
	{"n": "50_B1_五根水管", "p": Vector3(0.30, -1.45, 2.60), "t": Vector3(-0.10, -1.05, 0.55), "fov": 72.0},
	# —— 楼梯
	{"n": "51_楼梯_4F到5F", "p": Vector3(1.55, 11.60, 11.30), "t": Vector3(1.55, 12.60, 13.60), "fov": 74.0},
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	scene = load("res://scenes/laundry_upper.tscn").instantiate()
	root.add_child(scene)
	RenderingServer.frame_post_draw.connect(_grab)

func _process(_d: float) -> bool:
	frames += 1
	if frames < 30:
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
