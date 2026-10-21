extends SceneTree
## 剧情角色验收截图：老周(4F 402) / 阿七(2F 镜子前) / 秀兰(3F 304) / 周秀兰(2F 长椅)
## 不加 --headless（否则拿不到帧）。
##   --path . --script res://scripts/tests/cast_shot.gd

const OUT := "res://_预览/洗衣店/角色/"

var scene
var idx := -1
var frames := 0
var cooldown := 0
var shoot_now := false
var shots := [
	{"n": "C1_老周_402工作台", "p": Vector3(-2.10, 11.15, 4.90), "t": Vector3(-1.72, 10.95, 2.92), "fov": 46.0},
	{"n": "C2_老周_隔门", "p": Vector3(-2.10, 10.90, 6.60), "t": Vector3(-2.05, 10.80, 5.35), "fov": 60.0},
	{"n": "C3_阿七_镜子前", "p": Vector3(1.30, 5.10, 5.50), "t": Vector3(2.55, 4.60, 5.50), "fov": 48.0},
	{"n": "C4_阿七_近景", "p": Vector3(1.85, 4.75, 5.50), "t": Vector3(2.55, 4.55, 5.50), "fov": 38.0},
	{"n": "C5_秀兰_304床边", "p": Vector3(1.90, 8.30, 5.10), "t": Vector3(1.86, 7.75, 2.98), "fov": 52.0},
	{"n": "C6_周秀兰_长椅", "p": Vector3(-0.55, 4.62, 6.35), "t": Vector3(1.90, 4.22, 6.25), "fov": 50.0},
	{"n": "C7_周秀兰_近", "p": Vector3(0.15, 4.50, 6.30), "t": Vector3(1.90, 4.24, 6.25), "fov": 40.0},
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	scene = load("res://scenes/laundry.tscn").instantiate()
	root.add_child(scene)
	RenderingServer.frame_post_draw.connect(_grab)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 4:
		# 让周秀兰进场并坐下（第一夜的 01:10 那一下）
		var night = scene.get_node_or_null("FirstNight")
		if night != null:
			night._spawn_lady()
			night.npc_t = 6.0
			for i in range(40):
				night._npc_step(0.2)
			night._do_sit()
			# 截图模式里 Tween 不一定推进，直接把动作手动走到位：
			# SitDown 播完 → SitIdle（骨盆 0.528 才是坐姿），并按 seat_offset 落位
			var lady = night.lady
			if lady != null:
				lady.ap.play("SitIdle")
				lady.ap.advance(1.0)
				lady.current = "SitIdle"
				lady._apply_seat_offset_instant()
		# 阿七转头看玩家（镜子里那一下）
		if scene.cast != null:
			scene.cast.aqi_turn_to(Vector3(1.30, 3.5, 5.50))
	if frames < 30:
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
	cam.fov = s["fov"]
	cam.look_at_from_position(s["p"], s["t"], Vector3.UP)
