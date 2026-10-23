extends SceneTree
## Street acceptance: original landmark contract, actual collision probes, weather
## lifecycle, and optional real player input. No player archive is written.
const OUT := "F:/诡异事务局/验收/20261023_街道重构/"
const SOURCE := "res://assets/town/town-layout.json"
var game
var passed := 0
var failed := 0
var errors: Array[String] = []
var walked_metres := 0.0
var minimum_y := INF
var walk_frames := 0
var supported_samples := 0
var original: Dictionary = {}
var environment_controller
var movement_frame_ms: Array[float] = []
var previous_frame_usec := 0

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--render-timing") and DisplayServer.get_name() != "headless":
		root.size = Vector2i(1600,900)
		Engine.max_fps = 0
		previous_frame_usec = Time.get_ticks_usec()
		process_frame.connect(record_movement_frame)
	call_deferred("run")

func record_movement_frame() -> void:
	var now := Time.get_ticks_usec()
	if is_instance_valid(game) and is_instance_valid(game.town_bridge) and game.town_bridge.active and walk_frames > 0 and Input.is_physical_key_pressed(KEY_W):
		movement_frame_ms.append(float(now-previous_frame_usec)/1000.0)
	previous_frame_usec = now

func movement_timing() -> Dictionary:
	if movement_frame_ms.size() < 40:
		return {}
	var samples: Array[float] = movement_frame_ms.slice(30)
	samples.sort()
	return {"method":"local actual W-input physical street return route; 1600x900; uncapped; first 30 moving frames excluded; not cross-PC benchmark", "frames":samples.size(), "median_ms":samples[samples.size()/2], "p95_ms":samples[int(samples.size()*0.95)], "p99_ms":samples[int(samples.size()*0.99)]}

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		errors.append(label)
		push_error("FAIL " + label)

func held_key(code: Key, on: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = on
	Input.parse_input_event(event)

func read_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func collider_clear(local: Vector3, radius := 0.40) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = 1.72
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [game.player.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, game.town_bridge.ORIGIN + local + Vector3(0, 0.92, 0))
	return game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func support_at(local: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		game.town_bridge.ORIGIN + local + Vector3(0, 0.30, 0),
		game.town_bridge.ORIGIN + local - Vector3(0, 1.00, 0), 1)
	query.exclude = [game.player.get_rid()]
	return game.get_world_3d().direct_space_state.intersect_ray(query)

func line_clear(local_a: Vector3, local_b: Vector3) -> bool:
	# Door anchors in the supplied JSON are rounded to centimetres. A ray ending
	# exactly there can touch the door's own wall, although nothing blocks reaching
	# or aiming at it. Keep only a 12 cm endpoint tolerance, less than gameplay's
	# interaction-sphere tolerance, and still reject intervening walls/props.
	var endpoint := local_b-(local_b-local_a).normalized()*0.12
	var query := PhysicsRayQueryParameters3D.create(game.town_bridge.ORIGIN + local_a, game.town_bridge.ORIGIN + endpoint, 1)
	query.exclude = [game.player.get_rid()]
	return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func nearest_entry_spot(entry: Dictionary) -> Vector3:
	var front: Array = entry.front
	var at := Vector3(float(front[0]), 0.08, float(front[1]))
	var away := Vector2(at.x-float(entry.x), at.z-float(entry.z)).normalized()
	if away.length() < 0.01:
		away = Vector2(0, 1)
	# Start with the real outward direction; only search other standpoints when it
	# is occupied. Each accepted candidate must have a clear capsule AND sightline.
	for radius in [1.15, 1.65, 2.15, 2.65]:
		for offset in [0.0, -0.3, 0.3, -0.6, 0.6, -1.0, 1.0]:
			var side := away.rotated(offset)
			var candidate := at + Vector3(side.x*radius, 0, side.y*radius)
			if collider_clear(candidate) and not support_at(candidate).is_empty() and line_clear(candidate+Vector3(0,1.66,0),at+Vector3(0,1.05,0)):
				return candidate
	return Vector3(INF, INF, INF)

func check_landmarks() -> void:
	var live: Array = game.town_bridge.layout.get("landmarks", [])
	check(live.size() == 10, "保留十处既定地标")
	for original_entry in original.get("landmarks", []):
		var entry: Dictionary = game.town_bridge._landmark(String(original_entry.id))
		var label := String(original_entry.id) + " " + String(original_entry.name)
		check(not entry.is_empty(), "地标 ID 存在 " + label)
		if entry.is_empty():
			continue
		var contract := true
		for field in ["id", "name", "style", "x", "z", "w", "d", "rot", "front"]:
			contract = contract and entry.get(field) == original_entry.get(field)
		check(contract, "名称、用途和入口位置未改 " + label)
		var candidate := nearest_entry_spot(entry)
		check(is_finite(candidate.x), "入口有实体站位且视线无遮挡 " + label)
		if is_finite(candidate.x):
			print("ENTRANCE_STAND ", entry.id, " local=", candidate)

func check_surface_support() -> void:
	var failures: Array[String] = []
	for road in original.get("roads", []):
		var points: Array = road.get("points", [])
		for index in range(0, points.size(), 11):
			var point: Array = points[index]
			var at := Vector3(float(point[0]), 0.10, float(point[1]))
			var hit := support_at(at)
			supported_samples += 1
			if hit.is_empty() or float(hit.position.y)-game.town_bridge.ORIGIN.y < -0.20 or hit.normal.y < 0.7:
				if failures.is_empty():
					var backface_query := PhysicsRayQueryParameters3D.create(game.town_bridge.ORIGIN+at+Vector3(0,0.30,0),game.town_bridge.ORIGIN+at-Vector3(0,1.0,0),1)
					backface_query.exclude = [game.player.get_rid()]
					backface_query.hit_back_faces = true
					print("FLOOR_DIAGNOSTIC two_sided_ray=",game.get_world_3d().direct_space_state.intersect_ray(backface_query))
				failures.append(String(road.id)+":"+str(index)+" "+str(at))
	check(failures.is_empty(), "道路中心抽样有连续地面 (%d 点，缺失 %s)" % [supported_samples, str(failures)])
	for bridge in original.get("bridges", []):
		var a: Array = bridge["from"]
		var b: Array = bridge["to"]
		var valid := true
		for step in range(9):
			var alpha := float(step)/8.0
			var at := Vector3(lerpf(float(a[0]),float(b[0]),alpha),0.10,lerpf(float(a[1]),float(b[1]),alpha))
			valid = valid and not support_at(at).is_empty()
		check(valid, "桥梁桥面连续 " + String(bridge.get("id", bridge.get("name", "桥"))))
	# A point in the open river between bridge spans must not have the old town-wide
	# invisible floor. Banks/railings may block a player, but water is not pavement.
	var river: Dictionary = original.get("river", {})
	var river_points: Array = river.get("points", [])
	var open_water_checked := false
	for index in range(1, river_points.size()-1):
		var point: Array = river_points[index]
		var at := Vector3(float(point[0]),0.10,float(point[1]))
		var near_bridge := false
		for bridge in original.get("bridges", []):
			var a: Array = bridge["from"]
			var b: Array = bridge["to"]
			var nearest := Geometry2D.get_closest_point_to_segment(Vector2(at.x,at.z),Vector2(a[0],a[1]),Vector2(b[0],b[1]))
			if nearest.distance_to(Vector2(at.x,at.z)) < float(bridge.width)+3.0:
				near_bridge = true
		if near_bridge:
			continue
		open_water_checked = true
		check(support_at(at).is_empty(), "河面不再被隐藏的整块地板覆盖 " + str(at))
		break
	check(open_water_checked, "已取得桥外河面碰撞样本")
	var walls_solid:=true
	for wall in original.get("walls",[]):
		var a=Vector3(wall.a[0],float(wall.get("h",2.0))*.5,wall.a[wall.a.size()-1])
		var b=Vector3(wall.b[0],a.y,wall.b[wall.b.size()-1])
		var center=(a+b)*.5
		var normal=(b-a).normalized().cross(Vector3.UP)*.5
		var query=PhysicsRayQueryParameters3D.create(game.town_bridge.ORIGIN+center-normal,game.town_bridge.ORIGIN+center+normal,1)
		query.exclude=[game.player.get_rid()]
		walls_solid=walls_solid and not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	check(walls_solid,"19段围墙都有与可见墙体相符的实体碰撞")

func check_open_frontages() -> void:
	var annexes := 0
	for entry in game.town_bridge.layout.get("buildings", []):
		if entry.get("kind", "") == "annex":
			annexes += 1
	check(annexes == 12, "新增12处低矮附房已进入游戏地图")
	var recesses: Array = game.town_bridge.renewal.manifest.get("shop_recesses", [])
	check(recesses.size() == 2, "两处原有店铺使用真实门洞")
	for recess in recesses:
		var building: Dictionary = {}
		for entry in original.get("buildings", []):
			if entry.get("seed") == recess.seed:
				building = entry
		if building.is_empty():
			check(false, "开门店面对应原有建筑")
			continue
		var yaw := float(building.get("rot", 0.0))
		var outward := Vector3(sin(yaw), 0, cos(yaw))
		var front := Vector3(float(building.x), 0.08, float(building.z)) + outward*float(building.d)*0.5
		var inside := front - outward*0.35
		var label := str(recess.seed)
		check(collider_clear(inside) and not support_at(inside).is_empty(), "门洞内有正常站位及实体地面 " + label)
		check(not collider_clear(front-outward*1.28), "可见柜台阻止玩家穿过店内陈列 " + label)
		var ray := PhysicsRayQueryParameters3D.create(
			game.town_bridge.ORIGIN+front+Vector3(0,1.5,0),
			game.town_bridge.ORIGIN+front-outward*(float(recess.depth)+0.2)+Vector3(0,1.5,0), 1)
		ray.exclude = [game.player.get_rid()]
		check(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "店面后墙封闭，不能通往空壳内部 " + label)

func check_road_crown() -> void:
	var samples := 0
	var supported := true
	var bounded := true
	var drains := true
	for road in original.get("roads", []):
		if road.get("id") != "r_main":continue
		var points: Array = road.points
		for index in range(points.size()-1):
			var point := Vector2(float(points[index][0]),float(points[index][1]))
			if not (point.x>148.0 and point.x<171.0 and point.y>123.0 and point.y<129.0):continue
			var next := Vector2(float(points[index+1][0]),float(points[index+1][1]))
			var offset := (next-point).normalized().orthogonal()*1.65
			var center := support_at(Vector3(point.x,0.1,point.y))
			var left := support_at(Vector3(point.x+offset.x,0.1,point.y+offset.y))
			var right := support_at(Vector3(point.x-offset.x,0.1,point.y-offset.y))
			samples += 1
			if center.is_empty() or left.is_empty() or right.is_empty():
				supported = false
				continue
			var crown: float = center.position.y-game.town_bridge.ORIGIN.y
			bounded = bounded and crown>0.004 and crown<0.025 and center.normal.y>0.98
			drains = drains and center.position.y-(left.position.y+right.position.y)*0.5>0.005
	check(samples>2 and supported,"样板排水路面中心与两侧都有实体支撑 (%d段)" % samples)
	check(bounded,"实际路冠抬高受限在2.5厘米以内，无台阶尖峰")
	check(drains,"实际碰撞路面从中心向两侧降低")

func find_weather():
	for property in game.town_bridge.get_property_list():
		if String(property.name) in ["weather", "street_weather", "environment_controller"]:
			return game.town_bridge.get(String(property.name))
	return null

func check_weather() -> void:
	environment_controller = find_weather()
	check(environment_controller != null, "街道接入独立时间天气控制器")
	if environment_controller == null:
		return
	var weather = environment_controller
	check(weather.active, "出门启用户外环境")
	game.director.room_minutes = 720.0
	weather.restore({"version":1,"wetness":0.0,"last_clock":720.0,"animation_time":0.0})
	weather.refresh(0.0)
	var noon_daylight: float = weather.daylight
	check(noon_daylight > 0.8 and weather.rain_amount < 0.05, "中午为明亮无雨时段")
	check(weather.wetness < 0.05, "恢复干燥状态不会立即变成湿路")
	game.director.room_minutes = 1390.0
	weather.refresh(0.0)
	check(weather.daylight < noon_daylight*0.4 and weather.rain_amount > 0.3, "夜间天空与降雨随游戏钟变化")
	var shop: Dictionary = game.town_bridge._landmark("01")
	check(weather.roof_height_at(Vector2(float(shop.x),float(shop.z))) >= float(shop.height), "雨滴在洗衣楼屋顶上方截断")
	var clipped := true
	var rain_instances: MultiMesh = weather.rain_node.multimesh
	for index in range(rain_instances.instance_count):
		var at := rain_instances.get_instance_transform(index).origin
		var floor_height := rain_instances.get_instance_custom_data(index).r*64.0
		if floor_height+0.02 < weather.roof_height_at(Vector2(at.x,at.z)):
			clipped = false
			break
	check(clipped,"每个可见雨滴的最低高度覆盖其实际屋檐位置")
	var snapshot: Dictionary = weather.capture().duplicate(true)
	weather.restore({"version":1,"wetness":0.0,"last_clock":1390.0,"animation_time":0.0})
	weather.restore(snapshot)
	check(is_equal_approx(float(weather.capture().get("wetness",-1)),float(snapshot.get("wetness",-2))), "天气存档恢复积水湿度")
	var phase: float = weather.animation_time
	game.state = "paused"
	weather.refresh(0.25)
	check(is_equal_approx(phase,weather.animation_time), "暂停冻结雨滴与水波时间")
	game.state = "prologue"
	weather.refresh(0.25)
	check(weather.animation_time > phase, "恢复后天气动画继续")
	var full_save: Dictionary = preload("res://scripts/case_save.gd").capture(game)
	check(preload("res://scripts/case_save.gd").valid(full_save), "新街道状态仍可生成有效现场存档")
	var has_weather := false
	for field in ["town_environment", "town_weather", "weather"]:
		if full_save.has(field):
			has_weather = full_save[field] is Dictionary
	check(has_weather, "常规存档包含街道天气数据")
	game.town_bridge.leave()
	check(not weather.active, "回室内停用户外控制器")
	var indoor: Environment = game.env_node.environment
	var energy: float = indoor.ambient_light_energy
	game.director.room_minutes = 720.0
	weather.refresh(1.0)
	check(game.env_node.environment==indoor and is_equal_approx(indoor.ambient_light_energy, energy), "室内不受日间户外光照持续改写")
	# Legacy schema-v2 files did not contain weather. They must still restore to a
	# safe playable street, rather than requiring newly introduced save fields.
	for field in ["town_environment", "town_weather", "weather"]:
		full_save.erase(field)
	check(preload("res://scripts/case_save.gd").restore(game,full_save), "旧存档缺少天气字段仍能恢复街道")
	check(game.town_bridge.active and game.player.can_move, "旧存档恢复后角色可行动")
	game._clear_sub()
	game.audio_system.stop_voice()
	game.player.lock_look = true
	game.set_process(false)
	game.safety.set_physics_process(false)

func walk_to(at: Vector3, tolerance := 0.13) -> bool:
	var previous: Vector3 = game.player.global_position
	var stable := 0
	var start := Time.get_ticks_msec()
	for frame in range(2400):
		var delta: Vector3 = at-game.player.global_position
		delta.y = 0
		if delta.length() <= tolerance:
			held_key(KEY_W,false)
			await physics_frame
			return true
		game.player.rotation.y = atan2(-delta.x,-delta.z)
		game.player.pitch = 0
		game.player.cam.rotation.x = 0
		held_key(KEY_W,true)
		await physics_frame
		var current: Vector3 = game.player.global_position
		walked_metres += Vector2(current.x-previous.x,current.z-previous.z).length()
		minimum_y = minf(minimum_y,current.y-game.town_bridge.ORIGIN.y)
		walk_frames += 1
		stable = stable+1 if current.distance_to(previous)<0.001 else 0
		previous = current
		if stable > 70 or Time.get_ticks_msec()-start > 20000 or minimum_y < -0.5:
			break
	held_key(KEY_W,false)
	print("STREET_WALK_BLOCKED position=",game.player.global_position-game.town_bridge.ORIGIN," target=",at-game.town_bridge.ORIGIN)
	return false

func physical_route(id: String) -> bool:
	# AStar is a test driver, not gameplay. Every point is reached by the existing
	# player's W input + move_and_slide; positions are never assigned in this walk.
	var base: Vector3 = game.town_bridge.ORIGIN+Vector3(125,0,80)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0,0,70,65)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var entry: Dictionary = game.town_bridge._landmark(id)
	var front: Array = entry.front
	var goal := Vector2(float(front[0]),float(front[1]))
	var best := INF
	var last := Vector2i.ZERO
	for x in range(70):
		for z in range(65):
			var at := Vector3(125+x,0.08,80+z)
			var blocked := not collider_clear(at) or support_at(at).is_empty()
			grid.set_point_solid(Vector2i(x,z),blocked)
			var distance := Vector2(at.x,at.z).distance_squared_to(goal)
			if not blocked and distance<best and line_clear(at+Vector3(0,1.66,0),Vector3(goal.x,1.05,goal.y)):
				best = distance
				last = Vector2i(x,z)
	var local: Vector3 = game.player.global_position-base
	var first := Vector2i(roundi(local.x),roundi(local.z))
	if not grid.is_in_boundsv(first) or best > 3.0*3.0:
		return false
	grid.set_point_solid(first,false)
	var path := grid.get_id_path(first,last)
	if path.is_empty():
		return false
	for index in range(1,path.size()):
		if not await walk_to(base+Vector3(path[index].x,0.08,path[index].y)):
			return false
	var target: Vector3 = game.town_bridge.ORIGIN+Vector3(goal.x,1.05,goal.y)
	var direction: Vector3 = target-game.player.eye()
	game.player.rotation.y = atan2(-direction.x,-direction.z)
	game.player.pitch = atan2(direction.y,Vector2(direction.x,direction.z).length())
	game.player.cam.rotation = Vector3(game.player.pitch,0,0)
	for frame in range(3):
		await physics_frame
	game._update_interaction()
	return game.prompt != null and String(game.prompt.get("id","")) == id

func run() -> void:
	create_timer(240).timeout.connect(func(): held_key(KEY_W,false);check(false,"街道验收超时");quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	original = read_json(SOURCE)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._hide_menu()
	game._start_prologue(false)
	game.town_bridge.enter()
	game._clear_sub()
	game.audio_system.stop_voice()
	game.set_process(false)
	game.safety.set_physics_process(false)
	game.player.lock_look = true
	for frame in range(5):
		await physics_frame
	check_landmarks()
	check_surface_support()
	check_open_frontages()
	check_road_crown()
	check_weather()
	for frame in range(5):
		await physics_frame
	check(await physical_route("01"), "真实 W 输入从出租公寓走到洗衣店并瞄准入口")
	check(await physical_route("02"), "真实 W 输入从洗衣店走回出租公寓并瞄准入口")
	check(is_finite(minimum_y) and minimum_y > -0.20, "完整往返过程没有掉入道路下方 (最低 %.3f 米)" % minimum_y)
	check(walked_metres > 30, "街道往返由角色物理执行 (%.1f 米 / %d 物理帧)" % [walked_metres,walk_frames])
	# A real key press checks that newly placed eaves/street props did not leave the
	# spawn with no standing room or prevent returning to the standing capsule.
	held_key(KEY_CTRL,true)
	for frame in range(20): await physics_frame
	check(game.player.crouching,"门前可蹲下")
	held_key(KEY_CTRL,false)
	for frame in range(20): await physics_frame
	check(not game.player.crouching,"门前可从蹲下恢复站立")
	var feet: float = game.player.global_position.y
	held_key(KEY_SPACE,true)
	for frame in range(5): await physics_frame
	held_key(KEY_SPACE,false)
	var jumped: bool = game.player.global_position.y > feet+0.10
	for frame in range(85): await physics_frame
	check(jumped and game.player.is_on_floor(),"门前跳跃并重新落在实体路面")
	var result := {"passed":passed,"failed":failed,"errors":errors,"walked_metres":walked_metres,"physical_frames":walk_frames,"minimum_y":minimum_y,"road_support_samples":supported_samples,"method":"engine collision queries; actual keyboard movement; screenshot poses are a separate review"}
	result["movement_timing"] = movement_timing()
	var file := FileAccess.open(OUT+"street_test_result.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"\t"));file.close()
	print("STREET_RENEWAL_RESULT ",JSON.stringify(result))
	held_key(KEY_W,false)
	held_key(KEY_CTRL,false)
	held_key(KEY_SPACE,false)
	game.field_kit.generation += 1
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failed == 0 else 1)
