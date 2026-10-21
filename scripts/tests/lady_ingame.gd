extends SceneTree
## 老太太在洗衣店里的实际效果（游戏视角）
const OUT := "res://_预览/洗衣店/角色/"
var scene
var frames := 0
var idx := -1
var cooldown := 0
var shoot_now := false
var views := [
	{"n": "30_老太太_店内正面", "p": Vector3(0.30, 5.02, 8.20), "t": Vector3(1.45, 4.35, 5.50), "fov": 44.0},
	{"n": "31_老太太_近景", "p": Vector3(1.42, 4.80, 3.95), "t": Vector3(1.45, 4.38, 5.50), "fov": 42.0},
	{"n": "32_洗衣店_含角色", "p": Vector3(-1.10, 5.06, 8.40), "t": Vector3(1.30, 4.30, 5.30), "fov": 56.0},
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	scene = load("res://scenes/laundry.tscn").instantiate()
	root.add_child(scene)
	RenderingServer.frame_post_draw.connect(_grab)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 4:
		var night = scene.get_node_or_null("FirstNight")
		if night != null:
			night._spawn_lady()
			night.npc_t = 6.0
			night._npc_step(0.016)
			night.set_process(false)
		return false
	if frames < 6:
		return false
	if idx < 0:
		idx = 0
		_apply(idx)
		cooldown = 0
		return false
	cooldown += 1
	if cooldown == 14:
		shoot_now = true
	return false

func _grab() -> void:
	if not shoot_now:
		return
	shoot_now = false
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT + views[idx]["n"] + ".png")
	print("[SHOT] ", views[idx]["n"])
	idx += 1
	if idx >= views.size():
		quit()
		return
	_apply(idx)
	cooldown = 0

func _apply(i: int) -> void:
	var v = views[i]
	var cam: Camera3D = scene.get_node("Cam")
	cam.current = true
	cam.position = v["p"]
	cam.fov = v["fov"]
	cam.look_at(v["t"], Vector3.UP)
