extends SceneTree
## Real imported scene/physics/lifecycle checks; no screenshots or audio device.
const OUT := "F:/诡异事务局/验收/20261023_NPC后台接入/"
const SAVE = preload("res://scripts/case_save.gd")
var game
var town
var residents
var passed := 0
var failed := 0
var errors: Array[String] = []
var placements: Array = []

func _initialize() -> void:call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;errors.append(label);push_error("FAIL "+label)

func view(feet: Vector3, at: Vector3) -> void:
	game.player.global_position = feet
	game.player.cam.global_position = feet+Vector3(0,1.66,0)
	game.player.cam.look_at(at)
	game.player.velocity = Vector3.ZERO

func clear_player(feet: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = game.player.cap
	query.transform = Transform3D(Basis.IDENTITY, feet+Vector3(0,.9,0))
	query.collision_mask = 1
	query.exclude = [game.player.get_rid()]
	return game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func stand_for(actor) -> Vector3:
	var away := Vector3(sin(actor.home_yaw),0,cos(actor.home_yaw))
	return actor.global_position + away*1.45+Vector3(0,.035,0)

func run() -> void:
	create_timer(100.0).timeout.connect(func():push_error("NPC integration timeout");quit(2))
	check(DisplayServer.get_name()=="headless", "验收无窗口运行")
	check(AudioServer.get_driver_name()=="Dummy", "验收仅使用无声驱动")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._hide_menu()
	game._start_prologue(false)
	game.town_bridge.enter()
	game._clear_sub()
	game.audio_system.stop_voice()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.safety.set_physics_process(false)
	game.exit_save.set_process(false)
	town = game.town_bridge
	town.weather.set_process(false)
	residents = town.residents
	await physics_frame
	await process_frame
	await physics_frame
	check(residents.actors.size()==2, "仅接入两位用户街坊，无旧派生角色")
	check(game.laundry==null, "首次街道测试尚未创建洗衣店剧情")
	var original_objective: String = game.prologue_objective
	var original_bag: Array = game.case_bag.duplicate(true)
	for actor in residents.actors:
		game._clear_sub()
		var id: String = actor.definition.id
		check(actor.ready_model and actor.visible and actor.grounded, id+" 完整骨架、Idle和地面有效")
		check(actor.animator.has_animation("Walking") and actor.animator.has_animation("Running"), id+" 保留用户原走跑动作")
		check(actor.animator.get_animation(actor.idle).length>=3.9, id+" 使用独立呼吸站姿")
		var rib: int = actor.skeleton.find_bone("mixamorig_Spine2")
		actor.animator.speed_scale=1.0
		actor.animator.advance(.2)
		var pose: Quaternion = actor.skeleton.get_bone_pose_rotation(rib)
		actor.animator.advance(1.1)
		var moved: Quaternion = actor.skeleton.get_bone_pose_rotation(rib)
		var difference := Vector4(pose.x,pose.y,pose.z,pose.w).distance_to(Vector4(moved.x,moved.y,moved.z,moved.w))
		check(difference>.00001, id+" Idle实际驱动骨骼 delta="+str(difference))
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = actor.collider.get_child(0).shape
		query.transform = Transform3D(Basis.IDENTITY, actor.global_position+Vector3(0,.85,0))
		query.collision_mask = 1
		query.exclude = [actor.collider.get_rid(),game.player.get_rid()]
		var hits: Array = game.get_world_3d().direct_space_state.intersect_shape(query,8)
		check(hits.is_empty(), id+" 身体胶囊不穿建筑或门前道具 hits="+str(hits.size()))
		var feet := stand_for(actor)
		check(clear_player(feet), id+" 正前方有真实玩家站位")
		var floor_ray := PhysicsRayQueryParameters3D.create(feet+Vector3(0,.25,0),feet-Vector3(0,.35,0),1,[game.player.get_rid(),actor.collider.get_rid()])
		check(not game.get_world_3d().direct_space_state.intersect_ray(floor_ray).is_empty(), id+" 问路站位有地面")
		var target: Vector3 = actor.global_position+Vector3(0,1.35,0)
		view(feet,target)
		var selected: Variant = game.focus.select_target()
		check(selected!=null and selected.get("id","")==id, id+" 正常站位准星可选中")
		game._clear_sub()
		residents.interact(id)
		check(game.sub==String(actor.definition.line), id+" 问路提示真实入口与二楼报到")
		check(game.state=="prologue" and game.player.can_move and not game.sub_pause, id+" 问路不创建独立模态会话")
		check(game.case_bag==original_bag and game.prologue_objective==original_objective, id+" 不改主线任务或背包")
		game._clear_sub()
		game._say_seq("旁白","关键剧情字幕",2.2,false)
		actor.reply_cooldown=0.0
		residents.interact(id)
		check(game.sub=="关键剧情字幕", id+" 不覆盖已有剧情字幕")
		game._clear_sub()
		var tangent := Vector3(cos(actor.home_yaw),0,-sin(actor.home_yaw))
		view(feet,target+tangent*3.0)
		residents.interact(id)
		check(game.sub=="", id+" 偏离准星不响应旧提示")
		view(feet,target)
		game.phone_open=true
		check(game.focus.select_target()==null, id+" 手机打开不选人")
		game.phone_open=false
		game.bag_open=true
		check(game.focus.select_target()==null, id+" 背包打开不选人")
		game.bag_open=false
		placements.append({"id":id,"local_position":[actor.position.x,actor.position.y,actor.position.z],"forward_yaw":actor.home_yaw,"grounded":actor.grounded})
	var first_actor = residents.actors[0]
	view(stand_for(first_actor),first_actor.global_position+Vector3(0,1.35,0))
	first_actor.reply_cooldown=0.0
	residents.interact(first_actor.definition.id)
	var data: Dictionary = game.exit_save.snapshot()
	check(SAVE.valid(data) and data.state=="prologue" and data.stage=="town", "无洗衣店对象时街坊回答中仍可保存")
	check(SAVE.restore(game,data), "首次街道问路存档可正常恢复")
	game.player.set_physics_process(false)
	await physics_frame;await process_frame
	check(town.residents==residents and residents.actors.size()==2, "读档不重复生成街坊")
	game._clear_sub()
	await process_frame
	game.state="paused"
	await process_frame
	var paused_at: float = first_actor.animator.current_animation_position
	var head_at: float = first_actor.head_yaw
	await create_timer(.12).timeout
	check(is_equal_approx(paused_at,first_actor.animator.current_animation_position) and is_equal_approx(head_at,first_actor.head_yaw), "暂停时动画与注意力停止")
	game.state="prologue"
	await process_frame
	await create_timer(.12).timeout
	check(not is_equal_approx(paused_at,first_actor.animator.current_animation_position), "继续游戏后站姿恢复播放")
	town.leave()
	check(residents.interaction_candidates().is_empty(), "离开街道不留下可选人物")
	for actor in residents.actors:
		check(not actor.visible and actor.collider.collision_layer==0 and actor.animator.speed_scale==0.0, String(actor.definition.id)+" 离街隐藏并关闭碰撞动画")
	town.enter(true)
	game._clear_sub()
	await physics_frame;await process_frame
	check(residents.actors.size()==2 and residents.interaction_candidates().size()==2, "返回街道恢复原两个人物")
	game.start_laundry_case()
	game._clear_sub()
	game.player.set_physics_process(false)
	game.laundry.campaign.progress.night=2
	game.laundry.clues["sweater"]=true
	game.laundry.t=80.0
	town.enter(true)
	game.case_mode=""
	game._clear_sub()
	await physics_frame;await process_frame
	var night_data: Dictionary = game.exit_save.snapshot()
	check(SAVE.valid(night_data) and night_data.has("laundry"), "已有夜班的街道存档保留调查现场")
	check(SAVE.restore(game,night_data), "已有夜班的街道存档恢复成功")
	check(game.prologue_stage=="town" and game.state=="prologue" and game.laundry.campaign.progress.night==2 and game.laundry.has_clue("sweater") and game.laundry.t>=80.0, "恢复街道保留第二夜、线索与时钟")
	game._show_menu()
	await process_frame
	for actor in residents.actors:
		check(actor.animator.speed_scale==0.0, String(actor.definition.id)+" 回菜单停止播放")
	game._start_prologue(false)
	await physics_frame
	check(not residents.active and residents.interaction_candidates().is_empty(), "重开新游戏不残留街坊候选")
	var report := {"passed":passed,"failed":failed,"errors":errors,"placements":placements,"display":DisplayServer.get_name(),"audio":AudioServer.get_driver_name(),"limitations":"Headless imported scene, physics and state checks; offline model QA is separate. No game-view visual acceptance or audible voice review."}
	var file := FileAccess.open(OUT+"street_residents_test.json",FileAccess.WRITE)
	if file != null:file.store_string(JSON.stringify(report,"\t"));file.close()
	print("NPC INTEGRATION: ",passed," passed, ",failed," failed")
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
