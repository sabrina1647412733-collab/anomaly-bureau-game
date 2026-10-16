extends SceneTree
## 校验带倒角盒子：三角面数 / AABB，并把"倒角盒 vs 纯方块"并排渲一张图
const CharBody := preload("res://scripts/charbody.gd")

func _initialize() -> void:
	var root3 := Node3D.new()
	root.add_child(root3)
	var m1 := CharBody.bev_box(Vector3(0.42, 0.46, 0.26), 0.045)
	print("[BEV] 三角=", m1.get_faces().size() / 3, "  AABB=", m1.get_aabb().size)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.14, 0.24)
	mat.roughness = 0.8
	var a := MeshInstance3D.new()
	a.mesh = m1
	a.material_override = mat
	a.position = Vector3(-0.32, 0.30, 0)
	root3.add_child(a)
	var bmi := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.42, 0.46, 0.26)
	bmi.mesh = bx
	bmi.material_override = mat
	bmi.position = Vector3(0.32, 0.30, 0)
	root3.add_child(bmi)
	var l := DirectionalLight3D.new()
	l.rotation = Vector3(-0.9, 0.7, 0)
	l.light_energy = 1.4
	root3.add_child(l)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.34, 1.30)
	cam.fov = 42.0
	root3.add_child(cam)
	cam.look_at(Vector3(0.0, 0.30, 0.0), Vector3.UP)
	cam.make_current()
	_run()

func _run() -> void:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/look/"))
	var img: Image = root.get_texture().get_image()
	img.save_png("res://_预览/look/bev_对比.png")
	print("[BEV] 出图：左=倒角盒  右=纯方块")
	quit()