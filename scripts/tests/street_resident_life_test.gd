extends SceneTree
## Headless full-scene acceptance. Unit probes below do not replace player routes.
const OUT := "F:/诡异事务局/验收/20261023_NPC生活化/"
var out_dir := OUT
const SAVE = preload("res://scripts/case_save.gd")
var game
var town
var people
var passed := 0
var failed := 0
var errors: Array[String] = []
var states: Dictionary = {}
var min_y := INF
var max_move := 0.0
var prior: Dictionary = {}
var samples := 0
var body_overlaps := 0
var scanning := false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report-dir="):
			out_dir=argument.trim_prefix("--report-dir=").replace("\\","/").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("run")
func check(ok: bool,text: String) -> void:
	if ok:passed+=1;print("PASS ",text)
	else:failed+=1;errors.append(text);push_error("FAIL "+text)
func frames(n: int) -> void:
	for i in range(n):await physics_frame
	await process_frame
func wait_for(test: Callable,seconds: float) -> bool:
	var elapsed:=0.0
	while elapsed<seconds:
		if test.call():return true
		await physics_frame;elapsed+=1.0/60.0
	return false
func observe() -> void:
	if not scanning or not is_instance_valid(people):return
	for actor in people.actors:
		var id: String=actor.definition.id
		states[id][actor.activity]=true
		min_y=minf(min_y,actor.global_position.y)
		if prior.has(id):max_move=maxf(max_move,actor.global_position.distance_to(prior[id]))
		prior[id]=actor.global_position;samples+=1
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=actor.body_shape.shape;query.transform=Transform3D(Basis.IDENTITY,actor.global_position+Vector3(0,.85,0))
		query.collision_mask=1;query.exclude=[actor.get_rid(),game.player.get_rid()]
		if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():body_overlaps+=1

func run() -> void:
	create_timer(180.0,true,false,true).timeout.connect(func():push_error("life integration timeout");quit(2))
	Engine.physics_ticks_per_second=120;Engine.time_scale=2.0
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false);town=game.town_bridge;town.enter()
	game._clear_sub();game.audio_system.stop_voice();game.set_process(false)
	game.player.set_physics_process(false);game.safety.set_physics_process(false);game.exit_save.set_process(false);town.weather.set_process(false)
	people=town.residents
	await frames(4)
	check(DisplayServer.get_name()=="headless" and AudioServer.get_driver_name()=="Dummy","无窗口、无声驱动")
	check(people.actors.size()==2,"两位用户人物且无额外复制")
	for actor in people.actors:
		states[String(actor.definition.id)]={}
		check(actor.route_clear,String(actor.definition.id)+" 全短线13点有支撑且胶囊不穿已有物件")
		check(actor.animator.has_animation("ShortWalk") and actor.animator.has_animation("TurnStepLeft") and actor.animator.has_animation("TurnStepRight"),String(actor.definition.id)+" 小步与换步资源就绪")
		check(actor.runtime.walk_distance_curve.size()>=8,String(actor.definition.id)+" 起停位移曲线已接入")
	physics_frame.connect(observe);scanning=true
	var cycled: bool=await wait_for(func():return people.actors[0].trips>=2 and people.actors[1].trips>=2,65.0)
	scanning=false
	check(cycled,"两位自然完成驻足、生活动作、转身、走动和返回")
	for actor in people.actors:
		var seen: Dictionary=states[String(actor.definition.id)]
		check(seen.has("care") and seen.has("turn") and seen.has("walk"),String(actor.definition.id)+" 生活动作和移动均实际运行")
	check(samples>500 and min_y>-.02 and max_move<.04,"连续物理样本无坠落或位置突跳")
	check(body_overlaps==0,"完整往返人物胶囊没有穿建筑或既有道具")
	var actor=people.actors[0]
	check(await wait_for(func():return actor.activity=="walk" and actor.phase>.20 and actor.phase<1.8,25.0),"进入真实步行中段")
	game.state="paused";await frames(2)
	var paused: Vector3=actor.position;var phase: float=actor.phase;var clip_phase: float=actor.animator.current_animation_position
	await frames(15)
	check(paused.distance_to(actor.position)<.00001 and is_equal_approx(phase,actor.phase) and is_equal_approx(clip_phase,actor.animator.current_animation_position),"暂停固定身体、步态相位及动画")
	check(actor.footsteps.stream_paused and actor.footsteps.bus=="WorldSFX","空间脚步声随暂停停止，沿用环境音效总线")
	game.state="prologue";await frames(2)
	check(actor.phase>phase,"恢复后从暂停的步态继续")
	var direction: Vector3=-actor.tangent if actor.target_index==1 else actor.tangent
	game.player.global_position=actor.global_position+direction*.60
	var stayed: Vector3=actor.global_position
	check(await wait_for(func():return actor.activity=="yield",2.0),"玩家挡到短线时人物停让")
	await frames(25)
	check(actor.global_position.distance_to(stayed)<.04,"停让不持续推挤玩家或穿过去")
	game.player.global_position=town.ORIGIN+Vector3(165,.1,102)
	check(await wait_for(func():return actor.activity=="walk",3.0),"玩家离开后继续剩余步伐")
	var snapshot: Dictionary=game.exit_save.snapshot()
	var before_pos: Vector3=actor.position;var before_phase: float=actor.phase
	check(snapshot.has("town_residents") and SAVE.valid(snapshot),"步行中存档包含可选居民现场")
	check(SAVE.restore(game,snapshot),"步行中的整场景存档可恢复")
	game.player.set_physics_process(false);await frames(3)
	game.state="paused";await frames(2)
	check(actor.position.distance_to(before_pos)<.06 and absf(actor.phase-before_phase)<.10,"读档保留步行位置与相位")
	game.state="prologue"
	var corrupt: Dictionary=snapshot.duplicate(true);corrupt.town_residents=[]
	check(SAVE.restore(game,corrupt),"损坏可选居民容器不破坏主线读档")
	game.player.set_physics_process(false);await frames(2)
	people.restore({"version":1,"actors":"bad"});await frames(2)
	check(people.pending_restore.is_empty(),"损坏actors字段被拒绝")
	people.restore({"version":[],"actors":{}});await frames(2)
	check(people.pending_restore.is_empty(),"损坏居民版本字段被拒绝")
	var bad: Dictionary=snapshot.town_residents.duplicate(true)
	bad.actors.resident_shopkeeper.phase=999.0
	people.reset();people.restore(bad);await frames(2)
	check(actor.position.distance_to(actor.home)<.06 and actor.activity=="idle","不一致步行相位安全回到默认站位")
	# A fresh scene has never built the street: retain indoor saves lazily.
	var ambient: Dictionary=snapshot.town_residents.duplicate(true)
	town.leave()
	var fresh=load("res://scenes/main.tscn").instantiate();root.add_child(fresh);await process_frame
	fresh._hide_menu();fresh._start_prologue(false);fresh.set_process(false);fresh.player.set_physics_process(false);fresh.safety.set_physics_process(false)
	check(fresh.town_bridge.residents==null,"新进程等价场景尚未建街道")
	var room: Dictionary=SAVE.capture(fresh);room["town_residents"]=ambient
	check(SAVE.restore(fresh,room),"室内存档可载入尚未生成的居民状态")
	check(fresh.town_bridge.capture_residents()==ambient,"街道未创建时居民现场仍可再次保存")
	fresh.town_bridge.enter();fresh._clear_sub();await frames(3)
	check(fresh.town_bridge.residents!=null and fresh.town_bridge.residents.actors[0].trips==int(ambient.actors.resident_shopkeeper.trips),"首次出门交付暂存人物状态")
	fresh.queue_free();await process_frame
	town.leave();await frames(2)
	for resident in people.actors:check(resident.collision_layer==0 and resident.animator.speed_scale==0.0 and not resident.footsteps.playing,"离街关闭人物实体、动作和脚步声 "+String(resident.definition.id))
	var result: Dictionary={"passed":passed,"failed":failed,"errors":errors,"samples":samples,"minimum_y":min_y,"max_move_per_tick":max_move,"body_overlaps":body_overlaps,"states":states,"method":"real imported scene, CharacterBody swept movement and state/save probes; no visible gameplay or audible review"}
	var file:=FileAccess.open(out_dir+"life_test_result.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
	print("LIFE_RESULT ",JSON.stringify(result));game.queue_free();await process_frame;quit(1 if failed else 0)
