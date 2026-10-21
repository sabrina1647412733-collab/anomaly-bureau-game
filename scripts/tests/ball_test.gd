extends SceneTree
## 最小验证：一个球，看 loft/blob 生成的几何是否正常（法线、面朝向、UV）
var n := 0

func _initialize() -> void:
	var fig = load("res://scripts/laundry/figure.gd").new(null)
	var root := Node3D.new()
	root.name = "BallTest"
	root.position = Vector3(0, 0, 0)
	get_root().add_child(root)

	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.82, 0.36, 0.30)
	m.roughness = 0.35
	m.metallic = 0.0
	# 球 1：blob（放样球）
	fig.blob(root, Vector3(-1.1, 1.0, 0), 0.5, 0.5, 0.5, m, 32, 16)
	# 球 2：Godot 自己的 SphereMesh，做对照
	var mi := MeshInstance3D.new()
	mi.mesh = SphereMesh.new()
	mi.mesh.radius = 0.5
	mi.mesh.height = 1.0
	mi.position = Vector3(1.1, 1.0, 0)
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.35, 0.55, 0.85)
	m2.roughness = 0.35
	mi.material_override = m2
	root.add_child(mi)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.4)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	get_root().add_child(cam)
	cam.current = true

	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-30, 35, 0)
	l.light_energy = 2.2
	get_root().add_child(l)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -120, 0)
	fill.light_energy = 0.7
	fill.light_color = Color(0.7, 0.8, 1.0)
	get_root().add_child(fill)

	var le := Environment.new()
	le.background_mode = Environment.BG_COLOR
	le.background_color = Color(0.09, 0.095, 0.11)
	le.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	le.ambient_light_color = Color(0.35, 0.37, 0.42)
	le.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = le
	get_root().add_child(we)

func _process(_d: float) -> bool:
	n += 1
	if n == 14:
		var img := get_root().get_texture().get_image()
		img.save_png("res://_预览/洗衣店/角色/00_球体测试.png")
		print("[BALL] saved ", img.get_width(), "x", img.get_height())
		quit()
	return false
