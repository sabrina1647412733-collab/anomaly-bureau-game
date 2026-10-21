extends SceneTree
## 诊断：模型到底长什么样（四个角度 + 远距离）
const OUT := "res://_预览/洗衣店/角色/"
var scene
var frames := 0
var idx := -1
var cooldown := 0
var shoot_now := false
var model: Node3D
var ap: AnimationPlayer
var views := [
	{"n": "50_诊断_正面远", "p": Vector3(1.45, 4.80, 1.20), "t": Vector3(1.45, 4.30, 5.55), "fov": 55.0},
	{"n": "51_诊断_侧面", "p": Vector3(5.20, 4.80, 5.55), "t": Vector3(1.45, 4.30, 5.55), "fov": 55.0},
	{"n": "52_诊断_背面", "p": Vector3(1.45, 4.80, 9.90), "t": Vector3(1.45, 4.30, 5.55), "fov": 55.0},
	{"n": "53_诊断_全店", "p": Vector3(-2.80, 5.20, 9.60), "t": Vector3(1.45, 4.10, 5.55), "fov": 70.0},
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
			1.55, Vector3(1.45, 4.30, 5.55), PI)
		ap = _find_ap(model)
		if ap:
			print("[DIAG] animations:", ap.get_animation_list())
			var lst = ap.get_animation_list()
			if lst.size() > 0:
				ap.play(lst[0])
		# 打印每个 MeshInstance 的可见性和材质
		if model:
			for mi in model.find_children("*", "MeshInstance3D", true, false):
				var m: MeshInstance3D = mi
				var mats := []
				if m.mesh:
					for i in range(m.mesh.get_surface_count()):
						var mat = m.get_active_material(i)
						if mat is StandardMaterial3D:
							var sm: StandardMaterial3D = mat
							mats.append("%s a=%.2f tr=%d" % [sm.resource_name, sm.albedo_color.a, sm.transparency])
						else:
							mats.append(str(mat))
				print("[DIAG] mesh ", m.name, " vis=", m.visible, " surfs=", m.mesh.get_surface_count() if m.mesh else 0, " mats=", mats)
			print("[DIAG] skel:", model.find_children("*", "Skeleton3D", true, false).size())
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
	if cooldown == 16:
		shoot_now = true
	return false

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
