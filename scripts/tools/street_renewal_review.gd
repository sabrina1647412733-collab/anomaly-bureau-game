extends SceneTree
## Repeatable PLAYER-EYE engine captures. These camera samples do not stand in
## for the separate physical-route acceptance in street_renewal_test.gd.
const DEFAULT_OUT := "F:/诡异事务局/验收/20261023_街道重构/实机图/"
var output := DEFAULT_OUT
var game
var weather
var failures: Array[String] = []
var images: Array[Dictionary] = []
var phase_label := ""
var frame_times: Array[float] = []

func _initialize() -> void:
	call_deferred("run")

func find_weather():
	for property in game.town_bridge.get_property_list():
		if String(property.name) in ["weather","street_weather","environment_controller"]:
			return game.town_bridge.get(String(property.name))
	return null

func set_phase(label: String, minute: float, wet: float) -> void:
	phase_label = label
	game.director.room_minutes = minute
	game.clock_min = minute
	if weather != null:
		weather.restore({"version":1,"wetness":wet,"last_clock":minute,"animation_time":0.0})
		weather.refresh(0.0)
		if OS.get_cmdline_user_args().has("--sky-fill"):
			weather.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			weather.environment.ambient_light_sky_contribution = 0.65
	game._update_hud()

func capture(label: String, feet: Vector3, target: Vector3) -> void:
	var pose := PhysicsShapeQueryParameters3D.new()
	pose.shape = game.player.cap
	pose.transform = Transform3D(Basis.IDENTITY,game.town_bridge.ORIGIN+feet+Vector3(0,0.92,0))
	pose.collision_mask = 1
	pose.exclude = [game.player.get_rid()]
	var overlaps: Array = game.get_world_3d().direct_space_state.intersect_shape(pose,1)
	var floor_query := PhysicsRayQueryParameters3D.create(game.town_bridge.ORIGIN+feet+Vector3(0,0.3,0),game.town_bridge.ORIGIN+feet-Vector3(0,0.8,0),1)
	floor_query.exclude = [game.player.get_rid()]
	if not overlaps.is_empty() or game.get_world_3d().direct_space_state.intersect_ray(floor_query).is_empty():
		var reason := "截图机位不具备正常玩家站位 "+phase_label+"_"+label+" feet="+str(feet)
		failures.append(reason)
		push_error(reason)
		return
	game.player.global_position = game.town_bridge.ORIGIN + feet
	game.player.velocity = Vector3.ZERO
	var direction: Vector3 = game.town_bridge.ORIGIN+target-game.player.eye()
	game.player.rotation.y = atan2(-direction.x,-direction.z)
	game.player.pitch = atan2(direction.y,Vector2(direction.x,direction.z).length())
	game.player.cam.position = Vector3(0,1.66,0)
	game.player.cam.rotation = Vector3(game.player.pitch,0,0)
	game.player.cam.fov = 74.0
	game.town_bridge.update_map()
	game._update_hud()
	# Real-time frames allow actual environment/rain shaders and imported textures
	# to settle; no Blender render or photographic replacement is involved.
	for frame in range(48):
		await process_frame
	# Readback must also work for an occluded export review window. Force the
	# engine's own framebuffer draw without relying on a desktop repaint signal.
	RenderingServer.force_draw(false,1.0/60.0)
	var path := output+phase_label+"_"+label+".png"
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		failures.append("截图失败 "+path+" error="+str(result))
	var sample := {"path":path,"feet":[feet.x,feet.y,feet.z],"target":[target.x,target.y,target.z],"fov":74,"eye_height":1.66,"phase":phase_label,"engine":"Godot actual player-camera framebuffer","camera_only":true}
	if weather != null:
		sample["weather"] = weather.capture()
		sample["rain"] = weather.rain_amount
		sample["daylight"] = weather.daylight
	images.append(sample)
	print("STREET_REVIEW_CAPTURE ",JSON.stringify(sample))

func phase_shots() -> void:
	# Identical coordinates, pitch and FOV to the 20261023 baseline.
	await capture("01_出租公寓出来",Vector3(167.88,0.10,99.96),Vector3(145.88,1.76,120.8))
	await capture("02_走近得利洗衣店",Vector3(146.65,0.10,130),Vector3(145.52,3.8,111.31))
	await capture("03_洗衣店门前",Vector3(145.88,0.10,124.8),Vector3(145.88,3.2,115))
	# Additional opposite-facing samples make the same playable area accountable
	# from both sides instead of only one attractive composition.
	await capture("04_公寓反向与电线",Vector3(155.3,0.10,127.3),Vector3(177.7,6.2,102.8))
	await capture("05_洗衣店侧墙",Vector3(129.7,0.10,124.3),Vector3(132.7,3.6,111.5))
	await capture("06_沿街道路近景",Vector3(150.0,0.10,124.1),Vector3(165.0,0.5,126.5))

func frontage_shots() -> void:
	for recess in game.town_bridge.renewal.manifest.get("shop_recesses", []):
		for entry in game.town_bridge.layout.get("buildings", []):
			if entry.get("seed") != recess.seed:
				continue
			var yaw := float(entry.get("rot", 0.0))
			var outward := Vector3(sin(yaw),0,cos(yaw))
			var front := Vector3(float(entry.x),0.10,float(entry.z))+outward*float(entry.d)*0.5
			await capture("开门店面_"+str(recess.seed),front+outward*1.9,front-outward*0.65+Vector3(0,1.25,0))
	for entry in game.town_bridge.layout.get("buildings", []):
		if entry.get("id", "") != "annex_02":
			continue
		var yaw := float(entry.get("rot", 0.0))
		var outward := Vector3(sin(yaw),0,cos(yaw))
		var front := Vector3(float(entry.x),0.10,float(entry.z))+outward*float(entry.d)*0.5
		await capture("低附房_02",front+outward*2.4,front-outward*0.3+Vector3(0,2.1,0))

func run() -> void:
	create_timer(45 if OS.get_cmdline_user_args().has("--quick") else 220).timeout.connect(func():push_error("街道截图超时");quit(2))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output = argument.trim_prefix("--capture-dir=").replace("\\","/").trim_suffix("/")+"/"
	if DisplayServer.get_name() == "headless":
		push_error("请用有渲染窗口的 Godot 运行；headless 不能提供实际画面")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600,900)
	Engine.max_fps = 60
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._hide_menu()
	game._start_prologue(false)
	game.field_kit.letter_accepted = true
	game.field_kit.phone_owned = true
	game.field_kit.held_id = ""
	game.field_kit.rig.set_item("")
	game.town_bridge.enter()
	game._clear_sub()
	game.audio_system.stop_voice()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.safety.set_physics_process(false)
	game.player.lock_look = true
	game.player.cam_mode = 0
	game.player.body.visible = false
	game.player.cam.current = true
	game.player.flash.visible = false
	game.hud_fade.modulate.a = 0
	game.town_bridge.town_map.first_hint = false
	# Bodies added while entering town become queryable after the physics sync.
	for frame in range(3):
		await physics_frame
	weather = find_weather()
	if weather == null:
		failures.append("找不到时间天气控制器，无法生成可信的昼夜与雨后比较")
		push_error(failures.back())
		quit(1)
		return
	set_phase("夜雨",1390.0,0.88)
	var quick:=OS.get_cmdline_user_args().has("--quick")
	if quick:await capture("02_走近得利洗衣店",Vector3(146.65,0.10,130),Vector3(145.52,3.8,111.31))
	else:await phase_shots()
	set_phase("白天干燥",720.0,0.0)
	if OS.get_cmdline_user_args().has("--frontages"):
		await frontage_shots()
	if OS.get_cmdline_user_args().has("--hero-details"):
		await capture("近景_门旁藤椅搪瓷盆",Vector3(154,0.10,124.7),Vector3(151.8,1.0,127.3))
		await capture("近景_反向立面管线",Vector3(155.3,0.10,127.3),Vector3(177.7,6.2,102.8))
		await capture("近景_晾晒与窗洞",Vector3(160,0.10,125.2),Vector3(161.6,2.6,129.5))
	if quick:await capture("06_沿街道路近景",Vector3(150,0.10,124.1),Vector3(165,0.5,126.5))
	else:
		await phase_shots()
		set_phase("雨后清晨",330.0,0.78)
		await phase_shots()
	# A brief fixed-view frame sample is useful for comparing iterations, but is
	# deliberately labelled as local static-view timing, not an all-PC FPS claim.
	for frame in range(90):
		var previous := Time.get_ticks_usec()
		await process_frame
		frame_times.append(float(Time.get_ticks_usec()-previous)/1000.0)
	frame_times.sort()
	var timing := {"method":"local static-player-camera, 1600x900, 60fps cap; not continuous gameplay or cross-PC benchmark","median_frame_ms":frame_times[frame_times.size()/2],"p95_frame_ms":frame_times[int(frame_times.size()*0.95)],"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	var result := {"images":images,"failures":failures,"timing":timing,"note":"Camera-only samples for same-view visual review. Physical movement and route results are in street_test_result.json."}
	var file := FileAccess.open(output+"capture_manifest.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"\t"));file.close()
	print("STREET_REVIEW_RESULT ",JSON.stringify(timing)," images=",images.size()," errors=",failures.size())
	game.field_kit.generation += 1
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)
