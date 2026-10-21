extends SceneTree
const OUT := "res://_预览/洗衣店/场景/"
var scene
var idx := -1
var frames := 0
var cooldown := 0
var shoot_now := false
var shots := [
	{"n": "60_2F_家具Blender化_全景", "p": Vector3(0.0, 5.12, 9.55), "t": Vector3(0.0, 4.55, 2.30), "fov": 66.0},
	{"n": "61_2F_柜台与收银机", "p": Vector3(-0.55, 5.00, 4.20), "t": Vector3(-2.35, 4.45, 2.60), "fov": 62.0},
	{"n": "62_2F_长椅", "p": Vector3(0.35, 5.05, 2.20), "t": Vector3(1.95, 4.35, 3.10), "fov": 60.0},
	{"n": "63_2F_垃圾桶", "p": Vector3(1.80, 5.00, 2.70), "t": Vector3(2.90, 3.95, 3.55), "fov": 55.0},
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
