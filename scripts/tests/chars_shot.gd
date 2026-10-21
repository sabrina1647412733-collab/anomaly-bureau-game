extends SceneTree
## 四角色对照验收：正面 / 侧面 / 特写
const OUT := "res://_预览/洗衣店/角色/"

var scene
var frames := 0
var idx := -1
var cooldown := 0
var shoot_now := false
var views := [
	{"n": "20_四角色_正面", "p": Vector3(0.0, 1.05, 2.80), "t": Vector3(0.0, 0.82, -1.20), "fov": 44.0},
	{"n": "21_四角色_侧面", "p": Vector3(3.20, 1.05, -1.20), "t": Vector3(0.0, 0.82, -1.20), "fov": 44.0},
	{"n": "22_四角色_近", "p": Vector3(-1.20, 0.98, 0.55), "t": Vector3(-1.35, 0.80, -1.20), "fov": 50.0},
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	scene = load("res://scenes/laundry.tscn").instantiate()
	root.add_child(scene)
	RenderingServer.frame_post_draw.connect(_grab)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		var fig = load("res://scripts/laundry/figure.gd").new(scene.art)
		var names := ["OldLady_F2", "Girl_F2", "Zhou_F2", "AQi_F2"]
		var heights := [1.55, 1.15, 1.72, 1.62]
		var xs := [-1.35, -0.45, 0.45, 1.35]
		for i in range(names.size()):
			fig.glb_figure(scene, "res://assets/models/chars/%s.glb" % names[i],
				heights[i], Vector3(xs[i], 0.03, -1.20), 0.0)
		var key := OmniLight3D.new()
		key.position = Vector3(0.0, 2.2, 2.0)
		key.light_color = Color(1.0, 0.93, 0.85)
		key.light_energy = 7.0
		key.omni_range = 12.0
		scene.add_child(key)
		var fill := OmniLight3D.new()
		fill.position = Vector3(0.0, 1.6, -3.4)
		fill.light_color = Color(0.60, 0.72, 1.0)
		fill.light_energy = 3.2
		fill.omni_range = 9.0
		scene.add_child(fill)
		var night = scene.get_node_or_null("FirstNight")
		if night != null:
			night.set_process(false)
		return false
	if frames < 7:
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
