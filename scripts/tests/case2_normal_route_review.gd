extends "res://scripts/tests/normal_route_review.gd"
## First-case completion is a fixture boundary, not injected case2 progress.
## Begin uses the shipping continuation controller. Everything afterwards uses
## W movement, centre focus/E, real investigation keys and the actual lift UI.
var residence
var case2_inputs: Array[Dictionary] = []
var street_grid: AStarGrid2D
var street_open: Dictionary = {}
var street_candidates: Dictionary = {}
var last_modal_id := ""
var investigation_visits: Dictionary = {}
var current_floor := 1
const STREET_MINIMUM := Vector2i(-15,-15)
const STREET_SIZE := Vector2i(331,271)

func run() -> void:
	create_timer(1500).timeout.connect(func(): fail("第二案正常输入路线超时"); quit(2))
	root.size = Vector2i(1600,900)
	Engine.max_fps = 90
	route_started = Time.get_ticks_msec()
	report_dir = "F:/诡异事务局/验收/20261024_第二案正常路线/"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--route-report="): report_dir = argument.trim_prefix("--route-report=").replace("\\","/").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(report_dir)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if OS.get_cmdline_user_args().has("--resume-review") and FileAccess.file_exists(report_dir+"checkpoint.json"):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(report_dir+"checkpoint.json"))
		if saved is Dictionary and preload("res://scripts/case_save.gd").restore(game,saved):
			story = game.case2_controller.campaign
			residence = game.case2_controller.world
			game.player.lock_look = true
			if game.case2_controller.in_residence:
				await run_residence()
				return
	# Explicit integration fixture: public continuation action after a separately
	# tested first-case conclusion; do not alter campaign flags/bag/time here.
	game.case2_controller.begin()
	game.player.lock_look = true
	story = game.case2_controller.campaign
	if story == null: fail("第二案正规续案入口失败"); await finish(); return
	await clear_ui()
	await shot("01_次日出租屋")
	var companion_position: Vector3 = game.case2_controller.companion.global_position+Vector3(0,1.12,0)
	if not await walk(Vector3(0,12.1,320.7),.25): fail("出租屋门边路线"); await finish(); return
	if not await press_target("c2_aqi",companion_position): fail("临-07无法正常交谈"); await finish(); return
	print("CASE2_DIALOGUE_FIXTURE active=",story.dialogue.active," cursor=",story.dialogue.cursor," state=",game.state)
	await clear_ui()
	print("CASE2_DIALOGUE_AFTER active=",story.dialogue.active," cursor=",story.dialogue.cursor," state=",game.state)
	if not story.flag("coop_done"): fail("合作对话没有完成"); await finish(); return
	for point in game.prologue_spots:
		if point.id == "door": door_at = point.pos
	if not await press_target("door",door_at): fail("合作后房门无法出门"); await finish(); return
	for _i in range(600):
		await process_frame
		if game.prologue_stage == "town" and game.state == "prologue": break
	await clear_ui()
	await shot("02_前往福利院")
	if not await town_to("07"): fail("公寓到福利院真实街道路线阻断"); await finish(); return
	if not story.flag("orphanage_done"): fail("福利院门牌核对未完成"); await finish(); return
	if not await town_to("10"): fail("福利院至铁路道口路线阻断"); await finish(); return
	for _i in range(600):
		await process_frame
		if game.case_mode == "case2" and game.state in ["play","case_dialogue"]: break
	await clear_ui()
	residence = game.case2_controller.world
	if residence == null or not story.flag("arrived"): fail("道口派遣没有到达槐安住宅"); await finish(); return
	await shot("03_槐安住宅值守处")
	await run_residence()

func press_target(id: String,at: Vector3) -> bool:
	held_key(KEY_W,false)
	for _i in range(5):
		look(at)
		await physics_frame
	game._update_interaction()
	if game.prompt == null or game.prompt.get("id","") != id:
		print("CASE2_FOCUS_FAILED expected=",id," actual=",game.prompt," position=",game.player.global_position," at=",at)
		return false
	await input_key(KEY_E)
	route_steps += 1
	await physics_frame
	await process_frame
	await clear_ui()
	await clear_ui()
	return true

func clear_ui() -> void:
	if story == null: return
	for _i in range(160):
		if game.state == "case_dialogue":
			await input_key(KEY_E)
		elif game.sub != "" or not game.sub_queue.is_empty():
			await input_key(KEY_ENTER)
		elif story.modal.visible:
			if story.investigation.visible:
				var work = story.investigation
				var id: String = work.item_id
				investigation_visits[id] = int(investigation_visits.get(id,0))+1
				case2_inputs.append({"station":id,"position":str(game.player.global_position),"game_minute":game.director.now()})
				await operate_station(id)
				await shot("调查_%02d_%s" % [route_steps,id])
				# Some completed examinations immediately hand the screen to a
				# spoken conversation; Esc there means pause, not close-reader.
				if story.modal.visible and work.visible and game.state == "case2_read":
					await input_key(KEY_ESCAPE)
			elif story.heading.text.begins_with("电梯"):
				break
			else:
				await input_key(KEY_1)
		elif game.audio_system.is_busy():
			await create_timer(.12).timeout
		else: break
		await process_frame
	await process_frame

func input_key(code: int) -> void:
	held_key(code,true)
	await process_frame
	held_key(code,false)
	await process_frame

func operate_station(id: String) -> void:
	var codes: Array = []
	match id:
		"address": codes = [KEY_1,KEY_2,KEY_3]
		"registration": codes = [KEY_1,KEY_2,KEY_3,KEY_6]
		"meter": codes = [KEY_1,KEY_4,KEY_5,KEY_8,KEY_9]
		"meal": codes = [KEY_1,KEY_2,KEY_3]
		"living": codes = [KEY_1,KEY_2,KEY_3,KEY_4]
		"handwriting": codes = [KEY_F,KEY_3]
		"corridor": codes = [KEY_1,KEY_Q,KEY_2,KEY_W,KEY_3,KEY_E]
		"archive": codes = [KEY_1,KEY_Q,KEY_2,KEY_W,KEY_3,KEY_E,KEY_4,KEY_R,KEY_5,KEY_R]
		"isolation","source_valve":
			codes = [KEY_3 if id == "isolation" else KEY_4]
			for _i in range(18): codes.append(KEY_RIGHT)
			codes.append(KEY_ENTER)
		_: fail("未知操作面板 "+id); return
	for code in codes:
		await input_key(code)

func run_residence() -> void:
	for turn in range(100):
		await clear_ui()
		if story.flag("case_complete"):
			finished = true
			break
		var goal: Dictionary = story.current_goal()
		route_goals.append({"turn":turn,"id":goal.id,"text":goal.text,"position":str(game.player.global_position)})
		print("CASE2_PLAYER_ROUTE turn=",turn," goal=",goal.id," ",goal.text," pos=",game.player.global_position)
		var data: Dictionary = preload("res://scripts/case_save.gd").capture(game)
		if not data.is_empty():
			var checkpoint := FileAccess.open(report_dir+"checkpoint.json",FileAccess.WRITE)
			checkpoint.store_string(JSON.stringify(data))
			checkpoint.close()
		if not await residence_target(String(goal.id)):
			fail("第二案正常路线无法完成 "+String(goal.id))
			break
		await shot("室内_%02d_%s" % [turn,goal.id])
	await finish()

func residence_target(id: String) -> bool:
	if not residence.manifest.anchors.has(id): fail("缺少实体锚点 "+id); return false
	var target_floor: int = int(residence.manifest.anchors[id].floor)
	current_floor = clampi(roundi((game.player.global_position.y-residence.global_position.y)/3.0)+1,1,17)
	if current_floor != target_floor:
		var lift_id := "c2_lift_%d" % current_floor
		if residence.manifest.anchors.has(lift_id):
			if not await walk_fixed_route(lift_id): return false
			if not await press_target(lift_id,residence.get_anchor(lift_id)): return false
			var floor_options: Array = [1,8,16]
			if story.flag("seventeen_open"): floor_options.append(17)
			var index: int = floor_options.find(target_floor)
			if index < 0: fail("目标楼层未开放 "+str(target_floor)); return false
			key(KEY_1+index)
			await process_frame
			await clear_ui()
			current_floor = target_floor
	if not await walk_fixed_route(id): return false
	return await press_target(id,residence.get_anchor(id))

func walk_fixed_route(id: String) -> bool:
	# Freeze one legal route. Replanning at each stair midpoint would round the
	# current floor up and send the character back to a landing.
	var route: Array = residence.get_route(id,game.player.global_position)
	if route.is_empty(): return false
	for point in route:
		if not await walk(point,.15): return false
	return true

func _band(a: Vector2,b: Vector2,width: float) -> void:
	var low := Vector2i(floori(minf(a.x,b.x)-width),floori(minf(a.y,b.y)-width))
	var high := Vector2i(ceili(maxf(a.x,b.x)+width),ceili(maxf(a.y,b.y)+width))
	for x in range(low.x,high.x+1):
		for z in range(low.y,high.y+1):
			var id := Vector2i(x,z)
			if Rect2i(STREET_MINIMUM,STREET_SIZE).has_point(id) and Vector2(id).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(id),a,b)) <= width:
				street_candidates[id] = true

func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]),float(a[1]))

func build_street_grid() -> void:
	var town = game.town_bridge
	for road in town.layout.roads:
		for i in range(road.points.size()-1): _band(_v2(road.points[i]),_v2(road.points[i+1]),float(road.width)*.5+.25)
	for bridge in town.layout.bridges: _band(_v2(bridge["from"]),_v2(bridge["to"]),float(bridge.width)*.5)
	for place in town.layout.landmarks:
		var front := _v2(place.front)
		var closest := front
		var best := INF
		for road in town.layout.roads:
			for i in range(road.points.size()-1):
				var foot := Geometry2D.get_closest_point_to_segment(front,_v2(road.points[i]),_v2(road.points[i+1]))
				if front.distance_squared_to(foot) < best: best = front.distance_squared_to(foot); closest = foot
		_band(front,closest,1.4)
		_band(front,front,3.2)
	street_grid = AStarGrid2D.new()
	street_grid.region = Rect2i(STREET_MINIMUM,STREET_SIZE)
	street_grid.cell_size = Vector2.ONE
	street_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	street_grid.update()
	street_grid.fill_solid_region(street_grid.region,true)
	var shape := CapsuleShape3D.new()
	shape.radius = .4
	shape.height = 1.72
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [game.player.get_rid()]
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 1
	ray.exclude = [game.player.get_rid()]
	var space = game.get_world_3d().direct_space_state
	for id in street_candidates:
		var at: Vector3 = town.ORIGIN+Vector3(id.x,.92,id.y)
		query.transform = Transform3D(Basis.IDENTITY,at)
		if not space.intersect_shape(query,1).is_empty(): continue
		ray.from = town.ORIGIN+Vector3(id.x,.4,id.y)
		ray.to = town.ORIGIN+Vector3(id.x,-.65,id.y)
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y < .7 or hit.position.y-town.ORIGIN.y < -.18: continue
		street_open[id] = true
		street_grid.set_point_solid(id,false)
	print("CASE2_STREET_GRAPH open=",street_open.size())

func _nearest_street(at: Vector2,radius: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(floori(at.x-radius),ceili(at.x+radius)+1):
		for z in range(floori(at.y-radius),ceili(at.y+radius)+1):
			var id := Vector2i(x,z)
			if street_open.has(id) and Vector2(id).distance_to(at) <= radius: result.append(id)
	result.sort_custom(func(a,b): return Vector2(a).distance_squared_to(at) < Vector2(b).distance_squared_to(at))
	return result

func street_walk(target: Vector3) -> bool:
	if street_grid == null: build_street_grid()
	var local: Vector3 = game.player.global_position-game.town_bridge.ORIGIN
	var local_target: Vector3 = target-game.town_bridge.ORIGIN
	var starts: Array[Vector2i] = _nearest_street(Vector2(local.x,local.z),6.0)
	var goals: Array[Vector2i] = _nearest_street(Vector2(local_target.x,local_target.z),3.1)
	if starts.is_empty() or goals.is_empty(): return false
	var route: Array[Vector2i] = []
	for goal in goals:
		var candidate: Array[Vector2i] = street_grid.get_id_path(starts[0],goal)
		if not candidate.is_empty(): route = candidate; break
	if route.is_empty(): return false
	print("CASE2_STREET_WALK from=",starts[0]," to=",route.back()," nodes=",route.size())
	held_key(KEY_SHIFT,true)
	for i in range(route.size()):
		if not await walk(game.town_bridge.ORIGIN+Vector3(route[i].x,.1,route[i].y),.16):
			held_key(KEY_SHIFT,false)
			return false
	held_key(KEY_SHIFT,false)
	return true

func finish() -> void:
	held_key(KEY_W,false)
	held_key(KEY_SHIFT,false)
	await shot("第二案结案" if finished else "第二案路线中断")
	var result := {"kind":"normal input route from case1-complete continuation fixture; first case tested separately","finished":finished,"errors":errors,"interactions":route_steps,"goals":route_goals,"investigation_inputs":case2_inputs,"station_visits":investigation_visits,"position":str(game.player.global_position),"state":game.state,"automated_seconds":(Time.get_ticks_msec()-route_started)/1000.0,"reading_voice_skipped":true,"summary":story.summary() if story != null else {}}
	var file := FileAccess.open(report_dir+"route_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("CASE2_NORMAL_ROUTE_RESULT ",JSON.stringify(result))
	if story != null: story.cancel()
	for node in game.find_children("*","AudioStreamPlayer",true,false): node.stop(); node.stream = null
	for node in game.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(.2).timeout
	quit(0 if finished and errors.is_empty() else 1)
