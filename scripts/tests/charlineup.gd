extends SceneTree
## 角色对照图：把 4 个角色摆成一排、平背景 + 均光，渲染一张和参考图同构的图，
## 便于用 _tools/ref_measure.py 量出我模型的头身比 / 剪影，与 2D 概念图逐项对表。
## 用法： godot --path . --script res://scripts/tests/charlineup.gd
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _run() -> void:
	for i in range(40):
		await process_frame
	game._on_start()
	for i in range(25):
		await process_frame
	if game.hud != null:
		game.hud.visible = false
	var bg := Color(0.29, 0.36, 0.43)          # 参考图背景 #4b5c6e
	    # 关掉泛光：过曝的高光会在头顶糊出一圈光晕，把轮廓量歪
	var we := _find_we(game)
	if we != null and we.environment != null:
		we.environment.glow_enabled = false
		we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		we.environment.ambient_light_color = Color(0.75, 0.80, 0.88)
		we.environment.ambient_light_energy = 1.35
	# 背景 / 地面：不受光的纯色，保证整张图背景是同一个颜色
	var flat := StandardMaterial3D.new()
	flat.albedo_color = bg
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var wall := MeshInstance3D.new()
	var wb := BoxMesh.new(); wb.size = Vector3(26, 12, 0.4)
	wall.mesh = wb; wall.material_override = flat
	wall.position = Vector3(2.55, 4.5, -1.2)
	game.add_child(wall)
	var ground := MeshInstance3D.new()
	var gb := BoxMesh.new(); gb.size = Vector3(26, 0.04, 16)
	ground.mesh = gb; ground.material_override = flat
	ground.position = Vector3(2.55, -0.02, 5.0)
	game.add_child(ground)
	# 四个角色摆一排，都面朝 +Z（镜头）
	var xs := [0.0, 1.7, 3.4, 5.1]
	game.player.cam_mode = 1                    # 让玩家身体显形
	game.player.global_position = Vector3(xs[0], 0.03, 0.0)
	game.player.rotation.y = PI
	game.player.body.visible = true
	var placed := 0
	for np in game.npcs:
		np["label"].visible = false
		np["node"].visible = true
		np["node"].position = Vector3(xs[1 + placed], 0.03, 0.0)
		np["node"].rotation.y = PI
		placed += 1
	# 均光
	for lx in [0.0, 1.7, 3.4, 5.1]:
		var l := OmniLight3D.new()
		l.position = Vector3(lx, 2.3, 2.2)
		l.light_color = Color(1.0, 0.97, 0.92)
		l.light_energy = 1.35
		l.omni_range = 9.0
		l.shadow_enabled = false
		game.add_child(l)
	# 自己的相机（不用玩家相机）
	var c := Camera3D.new()
	c.position = Vector3(2.55, 0.95, 10.6)
	c.fov = 21.0
	c.near = 0.05
	c.far = 200.0
	game.add_child(c)
	c.look_at(Vector3(2.55, 0.88, 0.0), Vector3.UP)
	c.make_current()
	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/look/"))
	var img: Image = root.get_texture().get_image()
	img.save_png("res://_预览/look/charlineup.png")
	print("[LINEUP] ", img.get_width(), "x", img.get_height())
	# 后面的玩家特写只留玩家：旁边 NPC 会挡住侧视
	for np in game.npcs:
		np["node"].visible = false
	# 再来一张玩家上半身特写（看脸 / 帽子 / 背心 / 手臂）
	c.position = Vector3(0.0, 1.35, 2.0)
	c.fov = 42.0
	c.look_at(Vector3(0.0, 1.22, 0.0), Vector3.UP)
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var img2: Image = root.get_texture().get_image()
	img2.save_png("res://_预览/look/charlineup_脸.png")
	print("[LINEUP] 玩家特写 ", img2.get_width(), "x", img2.get_height())
	# 3/4 与侧面：正面容易被手臂挡住腰线，这两张看躯干进深和收腰
	c.position = Vector3(1.45, 1.35, 1.45)
	c.fov = 42.0
	c.look_at(Vector3(0.0, 1.20, 0.0), Vector3.UP)
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var img34: Image = root.get_texture().get_image()
	img34.save_png("res://_预览/look/charlineup_34.png")
	print("[LINEUP] 3/4 特写 ", img34.get_width(), "x", img34.get_height())
	# 侧视：从 -X 看，背后补一块纯色板（+X 侧），避免看到站内
	var sideWall := MeshInstance3D.new()
	var swb := BoxMesh.new(); swb.size = Vector3(0.4, 12, 16)
	sideWall.mesh = swb; sideWall.material_override = flat
	sideWall.position = Vector3(1.2, 4.5, 0.0)
	game.add_child(sideWall)
	c.position = Vector3(-2.0, 1.30, 0.0)
	c.fov = 42.0
	c.look_at(Vector3(0.0, 1.20, 0.0), Vector3.UP)
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var imgSide: Image = root.get_texture().get_image()
	imgSide.save_png("res://_预览/look/charlineup_侧.png")
	print("[LINEUP] 侧面特写 ", imgSide.get_width(), "x", imgSide.get_height())
	# 再来一张"只拍脸"的极近景：检查眼睛 / 眉 / 鼻 / 嘴 / 耳这些 2~6cm 的零件
	c.position = Vector3(0.0, 1.552, 0.52)
	c.fov = 30.0
	c.look_at(Vector3(0.0, 1.545, 0.0), Vector3.UP)
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var img3: Image = root.get_texture().get_image()
	img3.save_png("res://_预览/look/charlineup_眼.png")
	print("[LINEUP] 只拍脸 ", img3.get_width(), "x", img3.get_height())
	quit()

func _find_we(n: Node) -> WorldEnvironment:
	if n is WorldEnvironment:
		return n
	for c in n.get_children():
		var r := _find_we(c)
		if r != null:
			return r
	return null
