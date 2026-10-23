extends SceneTree
## Acceptance driver: actual keyboard movement, centre focus and UI actions.
## No evidence injection, time assignment or scene-position teleportation.
var game
var story
var route_steps := 0
var errors: Array[String] = []
var finished := false
var door_at := Vector3(0,13.1,319.05)
const OUT := "res://_预览/20261023_正常路线/"
var report_dir := OUT
var clock_stops: Array[Dictionary] = []
var route_goals: Array[Dictionary] = []
var route_started := 0
func _initialize() -> void:call_deferred("run")
func held_key(code: Key,on: bool) -> void:
	var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=on;Input.parse_input_event(event)
func key(code: Key) -> void:
	held_key(code,true);held_key(code,false)
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(report_dir+name+".png")
func fail(message: String) -> void:
	errors.append(message);push_error(message)
func clear_ui() -> void:
	for i in range(100):
		if game.state=="case_cinematic":key(KEY_SPACE)
		elif game.state=="case_dialogue":key(KEY_E)
		elif game.sub!="" or not game.sub_queue.is_empty():key(KEY_ENTER)
		elif game.laundry!=null and game.laundry.campaign.modal.visible:
			story=game.laundry.campaign
			var work=story.workbench
			if work.visible:
				match work.item_id:
					"photo":
						if not work.flipped:key(KEY_1);await create_timer(.5).timeout
						key(KEY_2)
					"slip":for code in [KEY_1,KEY_2,KEY_3]:key(code)
					"discharge":key(KEY_2)
					"accident":
						for code in [KEY_1,KEY_2,KEY_3]:key(code)
						key(KEY_4)
					_:key(KEY_2);key(KEY_3)
				await create_timer(.1).timeout
				await shot("检查_"+work.item_id+"_"+str(route_steps))
				key(KEY_ESCAPE)
			else:key(KEY_1)
		elif game.audio_system.is_busy() or (game.laundry!=null and game.laundry.blackout_active):await create_timer(.15).timeout
		else:break
		await create_timer(.04).timeout
	await process_frame
func look(at: Vector3) -> void:
	var d=at-game.player.eye()
	game.player.rotation.y=atan2(-d.x,-d.z)
	game.player.pitch=atan2(d.y,Vector2(d.x,d.z).length())
	game.player.cam.rotation=Vector3(game.player.pitch,0,0)
func walk(at: Vector3,tolerance := .20) -> bool:
	var start=Time.get_ticks_msec();var stable=0;var old:Vector3=game.player.global_position
	for i in range(3000):
		if game.state not in ["play","prologue"]:
			held_key(KEY_W,false);await clear_ui()
		if not game.player.can_move:
			await physics_frame
			if Time.get_ticks_msec()-start>40000:break
			continue
		var d:Vector3=at-game.player.global_position;d.y=0
		if d.length()<tolerance:
			held_key(KEY_W,false);await physics_frame;return true
		game.player.rotation.y=atan2(-d.x,-d.z);game.player.pitch=0;game.player.cam.rotation.x=0
		held_key(KEY_W,true)
		await physics_frame
		stable=stable+1 if game.player.global_position.distance_to(old)<.001 else 0
		old=game.player.global_position
		if stable>60 or Time.get_ticks_msec()-start>40000:break
	held_key(KEY_W,false)
	var colliders:Array=[]
	for i in game.player.get_slide_collision_count():colliders.append(str(game.player.get_slide_collision(i).get_collider().name))
	print("WALK_BLOCKED at=",game.player.global_position," target=",at," state=",game.state," moving=",game.player.can_move," frozen=",game.player.physics_frozen," physics=",game.player.is_physics_processing()," colliders=",colliders," keyW=",Input.is_physical_key_pressed(KEY_W))
	return false
func press_target(id: String,at: Vector3) -> bool:
	held_key(KEY_W,false)
	for i in range(5):
		if id=="c1_lady":at=game.laundry.lady.global_position+Vector3(0,1.05,0)
		look(at)
		await physics_frame
	game._update_interaction()
	if game.prompt==null or game.prompt.get("id","")!=id:
		print("FOCUS_FAILED expected=",id," actual=",game.prompt," position=",game.player.global_position," at=",at)
		await shot("阻塞_"+id)
		return false
	key(KEY_E);route_steps+=1;await process_frame
	await clear_ui()
	return true
func laundry_target(id: String) -> bool:
	story=game.laundry.campaign
	for attempt in range(40):
		var point:Dictionary=story.guidance.point_for(id)
		if point.is_empty():fail("找不到交互点 "+id);return false
		var goal={"id":id};var route:Dictionary=story.guidance.route_for(goal,game.player.global_position)
		if route.is_empty():return false
		var at:Vector3=point.pos
		if id=="c1_lady":at=game.laundry.lady.global_position+Vector3(0,1.05,0)
		if route.final:
			await walk(at,1.48)
			return await press_target(id,at)
		var arrived=await walk(route.pos,.18)
		if not arrived:return false
		if route.text.contains("按 E"):
			var service_id="l_service_down" if route.text.contains("下到 B1") else "l_service_up"
			var service:Dictionary=story.guidance.point_for(service_id)
			if not await press_target(service_id,service.pos):return false
			for i in range(400):
				await process_frame
				if game.state!="case_climb":break
	return false
func town_to(id: String) -> bool:
	var place=game.town_bridge._landmark(id);var front:Array=place.front
	var target:Vector3=game.town_bridge.ORIGIN+Vector3(front[0],1.1,front[1])
	if not await street_walk(target):return false
	if not await press_target(id,target):return false
	for i in range(400):
		await process_frame
		if game.state in ["play","prologue"]:break
	await clear_ui()
	return true
func street_walk(target: Vector3) -> bool:
	# Test-side path planning only. The normal player controller performs every step.
	var origin:Vector3=game.town_bridge.ORIGIN+Vector3(125,0,80)
	var grid=AStarGrid2D.new();grid.region=Rect2i(0,0,70,65);grid.cell_size=Vector2.ONE;grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	var query=PhysicsShapeQueryParameters3D.new();var shape=CapsuleShape3D.new();shape.radius=.40;shape.height=1.72;query.shape=shape;query.collision_mask=1;query.exclude=[game.player.get_rid()]
	var space=game.get_world_3d().direct_space_state
	var best=INF;var end=Vector2i.ZERO
	for x in range(70):
		for z in range(65):
			var p=origin+Vector3(x,.95,z);query.transform=Transform3D(Basis.IDENTITY,p)
			var blocked=not space.intersect_shape(query,1).is_empty()
			grid.set_point_solid(Vector2i(x,z),blocked)
			var distance=Vector2(p.x-target.x,p.z-target.z).length_squared()
			if not blocked and distance<best:best=distance;end=Vector2i(x,z)
	var p:Vector3=game.player.global_position-origin
	var begin=Vector2i(roundi(p.x),roundi(p.z));grid.set_point_solid(begin,false)
	var path=grid.get_id_path(begin,end)
	if path.is_empty():return false
	for i in range(1,path.size()):
		if not await walk(origin+Vector3(path[i].x,.1,path[i].y),.10):return false
	return true
func run() -> void:
	create_timer(1000).timeout.connect(func():fail("正常路线超时");quit(2))
	root.size=Vector2i(1600,900);Engine.max_fps=90
	route_started=Time.get_ticks_msec()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--route-report="):report_dir=argument.trim_prefix("--route-report=").replace("\\","/").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(report_dir)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	if OS.get_cmdline_user_args().has("--resume-review") and FileAccess.file_exists(report_dir+"checkpoint.json"):
		var data=JSON.parse_string(FileAccess.get_file_as_string(report_dir+"checkpoint.json"))
		if data is Dictionary and preload("res://scripts/case_save.gd").restore(game,data):
			game.player.lock_look=true
			await run_nights();return
	game._on_new_game();game.player.lock_look=true
	for i in range(1600):
		await process_frame
		if game.state=="prologue":break
	await clear_ui();await shot("01_新游戏")
	await walk(Vector3(.7,12.1,322.8),.25)
	await walk(Vector3(1.6,12.1,323.3),.25)
	if not await press_target("phone",game.get_meta("phone_world_body").global_position+Vector3(0,.08,0)):fail("手机无法取得");await finish();return
	game.phone_ui.answer_requested.emit();await create_timer(.25).timeout
	key(KEY_B);await create_timer(1.2).timeout;await clear_ui()
	check_sequence()
	await walk(Vector3(.3,12.1,321.3),.25)
	await walk(Vector3(0,12.1,320.45),.25)
	if not await press_target("envelope",game.prologue_envelope.global_position+Vector3(0,.08,0)):fail("门下信封无法取得");await finish();return
	game.field_kit.accept_button.pressed.emit();await create_timer(1.2).timeout;await clear_ui()
	await walk(Vector3(.9,12.1,322.5),.25);await walk(Vector3(1.6,12.1,323.85),.25)
	if not await press_target("wclock",game.wclock.root.global_position+Vector3(0,.3,0)):fail("时钟无法取得");await finish();return
	key(KEY_B);await process_frame
	await walk(Vector3(.3,12.1,321.3),.25);await walk(Vector3(0,12.1,320.45),.25)
	door_at=Vector3(0,13.1,319.05)
	for point in game.prologue_spots:
		if point.id=="door":door_at=point.pos
	if not await press_target("door",door_at):fail("房门无法出门");await finish();return
	for i in range(600):
		await process_frame
		if game.prologue_stage=="town" and game.state=="prologue":break
	await clear_ui()
	await shot("02_街道路线")
	if not await town_to("01"):fail("街道至洗衣店路线被阻挡");await finish();return
	await run_nights()
func run_nights() -> void:
	for turn in range(700):
		await clear_ui()
		if game.state=="case_end":finished=true;break
		story=game.laundry.campaign
		var snapshot:Dictionary=preload("res://scripts/case_save.gd").capture(game)
		if not snapshot.is_empty():
			var checkpoint=FileAccess.open(report_dir+"checkpoint.json",FileAccess.WRITE);checkpoint.store_string(JSON.stringify(snapshot));checkpoint.close()
		var goal:Dictionary=story.current_goal()
		var goal_record={"night":story.night_number(),"id":goal.id,"mode":goal.mode,"text":goal.text}
		if route_goals.is_empty() or route_goals.back()!=goal_record:route_goals.append(goal_record)
		print("PLAYER_ROUTE night=",story.night_number()," goal=",goal.id," ",goal.text," pos=",game.player.global_position)
		if bool(story.progress.rest_pending):
			if not await laundry_target("lb_exit"):fail("交班出口不可达");break
			for i in range(600):
				await process_frame
				if game.prologue_stage=="town" and game.state=="prologue":break
			if not await town_to("02"):fail("街道回出租屋被阻挡");break
			await walk(Vector3(-1.7,12.1,320.8),.3)
			if not await press_target("case_rest",story.REST_POINT):fail("无法在床边休息");break
			await walk(Vector3(0,12.1,320.45),.25)
			if not await press_target("door",door_at):fail("续夜无法出门");break
			for i in range(600):
				await process_frame
				if game.prologue_stage=="town" and game.state=="prologue":break
			if not await town_to("01"):fail("续夜街道入口不可达");break
		elif goal.mode=="arrival":await create_timer(.25).timeout
		elif goal.mode=="wait":
			key(KEY_T);await process_frame
			print("CLOCK_REVIEW now=",game.director.now()," next=",game.director.next_mark()," modal=",game.director.modal.visible," voice=",game.audio_system.is_busy())
			if game.director.modal.visible:
				var before:float=game.director.now();var target:Array=game.director.next_mark()
				game.director.next_event()
				clock_stops.append({"night":story.night_number(),"from":before,"to":game.director.now(),"label":target[1]})
			await create_timer(.1).timeout
		else:
			if not await laundry_target(goal.id):fail("正常路线无法完成目标 "+goal.id);break
			await shot("第%d夜_%s_%d"%[story.night_number(),goal.id,turn])
	await finish()
func check_sequence() -> void:
	if game.phone_ui.messages.has("派遣科"):fail("接受信封前提前收到事务局消息")
func finish() -> void:
	held_key(KEY_W,false)
	await shot("结案" if finished else "路线中断")
	var messages:Dictionary=game.phone_ui.messages
	var pacing={"clock_stops":clock_stops,"goals":route_goals,"dispatch_messages":messages.get("派遣科",[]).size(),"automated_seconds":(Time.get_ticks_msec()-route_started)/1000.0,"reading_and_voice_skipped":true}
	var data={"finished":finished,"errors":errors,"interactions":route_steps,"position":str(game.player.global_position),"state":game.state,"pacing":pacing}
	var file=FileAccess.open(report_dir+"route_result.json",FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()
	print("NORMAL_ROUTE_RESULT ",JSON.stringify(data))
	game.field_kit.generation+=1;game._discard_laundry();game.queue_free();await process_frame;await process_frame
	quit(0 if finished and errors.is_empty() else 1)
