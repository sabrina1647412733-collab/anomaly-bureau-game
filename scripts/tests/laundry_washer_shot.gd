extends SceneTree
## 洗衣机 Blender 化验收截图。
const OUT := "res://_预览/洗衣店/场景/"
var scene
var idx := -1
var frames := 0
var cooldown := 0
var shoot_now := false
var shots := [
	{"n": "57_2F_洗衣机Blender化_西侧", "p": Vector3(1.30, 5.05, 3.20), "t": Vector3(-2.80, 4.30, 4.10), "fov": 72.0},
	{"n": "58_2F_洗衣机Blender化_近景", "p": Vector3(-0.95, 4.42, 5.60), "t": Vector3(-2.75, 4.32, 5.85), "fov": 56.0},
	{"n": "59_2F_七号机_Blender化", "p": Vector3(0.06, 4.26, 3.35), "t": Vector3(0.0, 4.04, 2.62), "fov": 34.0},
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
			night.spinning[1] = true
			night.spinning[2] = true
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
