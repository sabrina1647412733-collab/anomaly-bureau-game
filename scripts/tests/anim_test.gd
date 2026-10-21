extends SceneTree
## 动画验证：让角色在场景里播放 Idle / Walk
const OUT := "res://_预览/洗衣店/角色/"
var scene
var frames := 0
var idx := -1
var cooldown := 0
var shoot_now := false
var ap: AnimationPlayer
var model: Node3D
var anims: Array = []
var views := [
	{"n": "40_动画_Idle", "p": Vector3(1.42, 4.80, 3.95), "t": Vector3(1.45, 4.38, 5.50), "fov": 42.0},
	{"n": "41_动画_Walk", "p": Vector3(0.30, 5.02, 4.20), "t": Vector3(1.45, 4.35, 5.50), "fov": 50.0},
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
		model = fig.glb_figure(scene, "res://assets/models/chars/ZhouXiulan_Anim.glb",
			1.55, Vector3(1.45, 4.30, 5.55), 0.0)
		# 找 AnimationPlayer
		print("[POS] model at ", model.global_position if model else "null")
		print("[POS] model aabb:", _aabb_str(model) if model else "-")
		ap = _find_ap(model)
		if ap:
			for a in ap.get_animation_list():
				anims.append(a)
			print("[ANIM] player found, animations: ", anims)
			if anims.size() > 0:
				ap.play(anims[0])
		else:
			print("[ANIM] no AnimationPlayer")
		# 停掉第一夜
		var night = scene.get_node_or_null("FirstNight")
		if night != null:
			night.set_process(false)
		return false
	if frames < 8:
		return false
	if idx < 0:
		idx = 0
		_apply(idx)
		cooldown = 0
		return false
	cooldown += 1
	# 切换动画
	if ap and idx == 1 and cooldown == 1 and anims.size() > 1:
		ap.play(anims[1])
	if cooldown == 20:
		shoot_now = true
	return false

func _aabb_str(n: Node) -> String:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null: continue
		var b: AABB = m.global_transform * m.get_aabb()
		if first:
			out = b; first = false
		else:
			out = out.merge(b)
	return str(out.position) + " size " + str(out.size)

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r = _find_ap(c)
		if r:
			return r
	return null

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
