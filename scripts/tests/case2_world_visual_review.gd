extends SceneTree
## Actual Godot runtime module views, labelled separately from full player-route QA.
var world
var camera: Camera3D
var out := "F:/诡异事务局/验收/20261024_24小时开发/case2_world/"
var samples: Array[Dictionary] = []
var whitebox := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(160).timeout.connect(func(): push_error("case2 visual review timeout"); quit(2))
	whitebox = OS.get_cmdline_user_args().has("--whitebox")
	out += "whitebox_views/" if whitebox else "finish_views/"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	world = load("res://scripts/case2/case2_world.gd").new()
	world.preview_whitebox = whitebox
	root.add_child(world)
	world.setup(null)
	world.set_anomaly_open(true)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101c1a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a3b0a6")
	env.ambient_light_energy = .23
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_intensity = 1.0
	environment.environment = env
	root.add_child(environment)
	camera = Camera3D.new()
	camera.near = .04
	camera.far = 85
	camera.fov = 72
	root.add_child(camera)
	camera.make_current()
	for shot in [
		["01_1F值守与管线",Vector3(-3.2,1.66,-1),Vector3(-5.5,1.2,-3.6)],
		["02_总表近景",Vector3(-4.45,1.6,-3.4),Vector3(-5.7,1.4,-3.5)],
		["03_公共楼梯",Vector3(2.85,1.66,4.5),Vector3(3.8,2.1,.15)],
		["04_8F厨房",Vector3(-2.5,22.66,-1.2),Vector3(-5.3,22.0,-3.5)],
		["05_16F居住痕迹",Vector3(-2.55,46.66,-1.2),Vector3(-5.1,45.7,-4.6)],
		["06_储物间近景",Vector3(-4.12,46.4,-3.6),Vector3(-3.0,45.9,-4.5)],
		["07_17F走廊",Vector3(.7,49.66,3.3),Vector3(-.6,49.1,-5.4)],
		["08_17F休息角",Vector3(-2.8,49.66,-1.7),Vector3(-4.9,48.8,-4.7)]
	]:
		camera.global_position = world.to_global(shot[1])
		camera.look_at(world.to_global(shot[2]))
		for i in range(14):
			await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		if frame.is_empty():
			push_error("No rendered image; headless/dummy view cannot replace actual engine screenshot")
			quit(3)
			return
		frame.save_png(out + String(shot[0]) + ".png")
		await sample(String(shot[0]), shot[1], shot[2])
	var file := FileAccess.open(out + "runtime_views.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind":"Godot runtime scene module, fixed player-height camera, not complete game playthrough", "whitebox":whitebox, "gpu":RenderingServer.get_video_adapter_name(), "renderer":RenderingServer.get_current_rendering_method(), "resolution":"1600x900", "views":samples}, "\t"))
	print("CASE2_VIEWS_OK ", samples.size(), " ", out)
	quit(0)

func sample(label: String, eye: Vector3, target: Vector3) -> void:
	var frame_ms: Array[float] = []
	for i in range(45):
		var tick := Time.get_ticks_usec()
		await process_frame
		if i >= 10:
			frame_ms.append((Time.get_ticks_usec() - tick) / 1000.0)
	frame_ms.sort()
	samples.append({"name":label,"eye":str(eye),"target":str(target),"frame_ms_median":frame_ms[17],"frame_ms_p95":frame_ms[33],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"video_memory_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0})
