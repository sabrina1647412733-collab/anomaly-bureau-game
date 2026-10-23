extends SceneTree
var game
var passed := 0
var failed := 0
static var TEMP=preload("res://scripts/storage_paths.gd").file("verify_focus_autosave.json")
func _initialize() -> void:call_deferred("run")
func check(value: bool, text: String) -> void:
	if value:passed+=1;print("PASS ",text)
	else:failed+=1;push_error("FAIL "+text)
func view(feet: Vector3, at: Vector3) -> void:
	game.player.global_position=feet;game.player.cam.global_position=feet+Vector3(0,1.66,0)
	game.player.cam.look_at(at);game.player.velocity=Vector3.ZERO
func expect(id: String, feet: Vector3, at: Vector3) -> void:
	view(feet,at)
	var result=game.focus.select_target()
	check(result!=null and result.get("id","")==id,"准星选中 "+id+" 实际="+str(result))
func reachable(point: Dictionary) -> bool:
	var target:Vector3=point.pos
	var floor_y:float=-2.95
	for level in [0.0,3.5,6.9,9.8,12.7,15.6]:
		if target.y>level:floor_y=level+.05
	for radius in [.75,1.2,1.75]:
		for index in range(24):
			var angle:float=TAU*float(index)/24
			var feet=Vector3(target.x+cos(angle)*radius,floor_y,target.z+sin(angle)*radius)
			if not game.safety.supported(feet):continue
			var query=PhysicsShapeQueryParameters3D.new();query.shape=game.player.cap
			query.transform=Transform3D(Basis.IDENTITY,feet+Vector3(0,.9,0));query.collision_mask=1;query.exclude=[game.player.get_rid()]
			if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
			view(feet,target)
			var selected=game.focus.select_target()
			if selected!=null and selected.get("id")==point.id:return true
	return false
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false);game.player.set_physics_process(false);game.safety.set_physics_process(false)
	game.set_process(false);game.exit_save.set_process(false)
	check(not auto_accept_quit,"窗口关闭已交给保存流程处理")
	game.phone_ui.call_active=true;game.prologue_call_done=true
	var rent=game.exit_save.snapshot()
	check(not rent.room.prologue_call_done,"通话中退出会重新提供来电，投信流程不丢失")
	game.phone_ui.call_active=false;game.prologue_call_done=false
	view(Vector3(-.35,12.1,323.05),Vector3(0,13.5,325.3))
	var origin=Vector3(0,14,323);var direction=Vector3.FORWARD
	check(game.focus.aim_score(origin+direction*1.3,2.4,.2,origin,direction,false)>0,"射线正对目标")
	check(game.focus.aim_score(origin+direction*1.3+Vector3(.4,0,0),2.4,.2,origin,direction,false)==-INF,"靠近但偏离准星不触发")
	check(game.focus.aim_score(origin-direction,2.4,.2,origin,direction,false)==-INF,"背后目标不触发")
	game.prologue_letter_ready=true;game.envelope_taken=false;game.field_kit.sync_world()
	var letter:Vector3=game.prologue_envelope.global_position+Vector3(0,.08,0)
	expect("envelope",Vector3(letter.x,12.1,letter.z+1),letter)
	game.field_kit.letter_accepted=true
	check(game.exit_save.snapshot().clock_appeared,"接受信封后立即退出也能恢复时钟")
	game.start_laundry_case();game._clear_sub()
	await physics_frame;await process_frame
	game.player.set_physics_process(false)
	expect("lb_booth",Vector3(-1.8,.06,6.35),game.laundry.rebuilt.POINTS.lb_booth)
	expect("l_m9",Vector3(.65,3.55,4.1),Vector3(2.35,4.2,4.1))
	expect("l_m7",Vector3(0,3.55,4.35),Vector3(0,4.25,2.75))
	expect("l_price",Vector3(-1,3.55,3),Vector3(-2.2,5.4,2.1))
	game.laundry.campaign.progress.night=3;game.spots=game.laundry.spots()
	game.laundry.back_open=true;game.laundry.f2.doors.back.rotation.y=-1.7
	await physics_frame
	for point in game.spots:
		if point.id in ["c1_drawer","c1_photo","c1_cert","c1_tools","c1_mail_letter","c1_keybox","c1_power","c1_valve","c1_notice","c1_waterline","c1_ladder","c1_sandal","c1_accident","c1_roof_copy","c1_roof_patch","l_sign","l_registry","l_boiler","l_clipping","l_photowall"]:
			check(reachable(point),"实体站位可瞄准 "+String(point.id))
	game.bag_open=true;check(game.focus.select_target()==null,"背包打开不交互");game.bag_open=false
	game.phone_open=true;check(game.focus.select_target()==null,"手机打开不交互");game.phone_open=false
	game.state="case_reader";check(game.focus.select_target()==null,"阅读时不交互");game.state="play"
	# 单独放一堵真实碰撞墙验证射线遮挡。
	var wall=StaticBody3D.new();var col=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2,2,.2);col.shape=box;wall.add_child(col);game.add_child(wall)
	wall.position=Vector3(0,1,-7);await physics_frame
	view(Vector3(0,.06,-5),Vector3(0,1,-8))
	var eye:Vector3=game.player.cam.global_position;var ray:Vector3=(Vector3(0,1,-8)-eye).normalized()
	check(game.focus.aim_score(Vector3(0,1,-8),4,.2,eye,ray)==-INF,"墙后物件不能隔墙触发")
	wall.queue_free();await physics_frame
	game.player.global_position=Vector3(-.55,.08,-8.8);game.safety.reset_zone()
	check(game.safety.supported(game.safety.anchor()),"洗衣楼入口有实际地面")
	game.safety.last_good=Vector3(1.55,3.55,9.5)
	game.player.global_position=Vector3(80,-60,80);game.player.velocity=Vector3(0,-50,0)
	game.safety.tick(.8)
	check(game.player.global_position.distance_to(Vector3(1.55,3.55,9.5))<.1,"虚空自动返回安全点")
	check(game.player.velocity==Vector3.ZERO,"脱困清除下坠速度")
	game.player.global_position=Vector3(80,-60,80);game.safety.tick(.8)
	check(game.player.global_position.distance_to(game.safety.anchor())<.1,"连续坠落回入口，打断循环")
	var before=game.laundry.campaign.progress.duplicate(true);var bag=game.case_bag.duplicate(true);var clock=game.laundry.t
	game._open_pause();game.safety.recover()
	check(game.state=="play" and not game.menu.visible,"暂停菜单脱困后恢复游玩")
	check(before==game.laundry.campaign.progress and bag==game.case_bag and clock==game.laundry.t,"脱困不改变任务物品时间")
	check(game.safety.in_bounds(Vector3(13.8,3.55,12)),"邮政存档间属于安全区域")
	check(game.safety.in_bounds(Vector3(.89,5.2,13.7)),"折返梯平台不会误救援")
	check(not game.safety.in_bounds(Vector3(NAN,0,0)),"非法坐标不能成为安全位置")
	var data=game.exit_save.snapshot()
	check(preload("res://scripts/case_save.gd").valid(data),"正常游戏可生成自动存档")
	game._open_pause();var paused=game.exit_save.snapshot()
	check(paused.state=="play" and game.state=="paused","暂停退出保存正确的恢复状态")
	game._on_resume()
	game.laundry.campaign.show_page("测试阅读","文本")
	var reading=game.exit_save.snapshot();check(reading.state=="play" and game.state=="case_reader","阅读中退出恢复到现场")
	game.laundry.campaign.close_page()
	game.laundry.campaign.dialogue.play([["许砚","测试对白"]])
	var talking=game.exit_save.snapshot();check(talking.state=="play" and game.state=="case_dialogue","对白中退出不误提交回调")
	game.laundry.campaign.dialogue.finish(false)
	game.player.global_position=Vector3(0,-99,0);data=game.exit_save.snapshot()
	check(float(data.position[1])> -4,"坠落时存档使用安全位置")
	check(game.exit_save.write_snapshot(TEMP,data),"自动档原子写入独立测试文件")
	var loaded=game.exit_save.read_snapshot(TEMP)
	check(loaded==JSON.parse_string(JSON.stringify(data)),"自动档读回进度完整")
	check(preload("res://scripts/case_save.gd").restore(game,loaded),"自动档可重建场景继续游戏")
	check(game.state=="play" and game.case_mode=="laundry","自动档恢复后允许继续现场调查")
	var file=FileAccess.open(TEMP,FileAccess.WRITE);file.store_string("broken");file.close()
	check(game.exit_save.read_snapshot(TEMP).is_empty(),"损坏自动档不被载入")
	check(not game.exit_save.write_snapshot(TEMP,{}),"无效数据不覆盖有效档")
	check(game.exit_save.test_mode and not game.exit_save.save_now(),"验收模式不写玩家自动存档")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	file=null
	print("FOCUS_SAFETY_SAVE_RESULT PASS=",passed," FAIL=",failed)
	game.queue_free();await process_frame;quit(1 if failed else 0)
