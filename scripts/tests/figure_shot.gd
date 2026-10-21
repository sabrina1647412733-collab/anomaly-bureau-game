extends SceneTree
## 角色三视图验收：把老太太单独摆在空地上，正面 / 侧面 / 背面各一张。
const OUT := "res://_预览/洗衣店/角色/"

var scene
var frames := 0
var idx := -1
var cooldown := 0
var shoot_now := false
var lady: Node3D
var views := [
	{"n": "01_正面", "p": Vector3(0.0, 1.55, 2.30)},
	{"n": "02_侧面", "p": Vector3(2.30, 1.55, 0.10)},
	{"n": "03_背面", "p": Vector3(0.0, 1.55, -2.10)},
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	scene = load("res://scenes/laundry.tscn").instantiate()
	root.add_child(scene)
	RenderingServer.frame_post_draw.connect(_grab)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 4:
		# 清场：只留角色，放在 1F 门厅空地（z=-4 那一带）
		var night = scene.get_node_or_null("FirstNight")
		var art = scene.art
		var fig = load("res://scripts/laundry/figure.gd").new(art)
		lady = fig.glb_figure(scene, "res://assets/models/chars/OldLady_Final.glb", 1.55)
		lady.position = Vector3(0.0, 0.0, -4.0)
		# 灯：一盏正面补光 + 一盏轮廓光
		var key := OmniLight3D.new()
		key.position = Vector3(-1.2, 2.0, -2.4)
		key.light_color = Color(1.0, 0.86, 0.70)
		key.light_energy = 6.0
		key.omni_range = 9.0
		scene.add_child(key)
		var rim := OmniLight3D.new()
		rim.position = Vector3(1.4, 2.2, -6.0)
		rim.light_color = Color(0.55, 0.70, 1.0)
		rim.light_energy = 3.5
		rim.omni_range = 8.0
		scene.add_child(rim)
		if night != null:
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
	cam.fov = 42.0
	cam.look_at(Vector3(0.0, 0.85, -4.0), Vector3.UP)
