extends SceneTree
var game
var story
var passed := 0
var failed := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("[PASS] ",label)
	else:failed+=1;print("[FAIL] ",label)
func key(code: Key) -> void:
	var e=InputEventKey.new();e.pressed=true;e.physical_keycode=code;root.push_input(e)
	e=InputEventKey.new();e.pressed=false;e.physical_keycode=code;root.push_input(e)
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	for i in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var folder="res://_预览/20261023_第一案精修/"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):folder=argument.trim_prefix("--capture-dir=").replace("\\","/").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var saved=root.get_texture().get_image().save_png(folder+name+".png")
	if saved!=OK:failed+=1;push_error("截图保存失败："+folder+name)
func run() -> void:
	create_timer(95).timeout.connect(func():quit(2))
	root.size=Vector2i(1600,900)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false);game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false)
	game.field_kit.phone_owned=true;game.field_kit.letter_accepted=true
	var rig=game.field_kit.rig
	for id in ["phone","envelope","photo","weird_clock","sweater","sandal","machine_key"]:
		rig.set_item(id)
		await process_frame
		var hands=rig.content.get_node("XuYanGripHands")
		var meshes:Array[MeshInstance3D]=[]
		preload("res://scripts/case1_prop.gd").collect(hands,meshes)
		check(meshes.size()>=2,id+"独立手部模型已加载")
		var has_left=false;var all_ok=true;var count=0
		for m in meshes:
			has_left=has_left or String(m.name).contains("Left")
			var bounds:AABB=hands.global_transform.affine_inverse()*m.global_transform*m.get_aabb()
			all_ok=all_ok and bounds.position.is_finite() and bounds.size.length()<1.
			for i in m.mesh.get_surface_count():count+=m.mesh.surface_get_array_len(i)
		check(all_ok,id+"无异常拉伸或非有限坐标")
		check(has_left==(id in ["envelope","photo","sweater"]),id+"单/双手分类正确")
		check(count>5000,id+"采用连续细分拓扑")
		await create_timer(.30).timeout
		await capture("持物_"+id)
	rig.set_item("phone");rig.transition_to("envelope");await create_timer(.06).timeout;rig.transition_to("photo")
	await create_timer(.48).timeout
	check(rig.item_id=="photo" and not rig.switching,"快速切换只完成最后一件，不跳回旧物品")
	rig.transition_to("phone");rig.set_item("");await create_timer(.3).timeout
	check(rig.content.get_child_count()==0,"收纳取消未完成过渡，手部和物件不会再现")
	rig.set_item("phone");await create_timer(.06).timeout;game._open_pause();await process_frame
	var held_y:float=rig.content.position.y
	await create_timer(.10).timeout
	check(is_equal_approx(held_y,rig.content.position.y),"暂停保持拿起动作位置")
	game._on_resume();await create_timer(.35).timeout
	check(is_zero_approx(rig.content.position.y),"恢复后拿起动作正常结束")
	for i in range(3):rig.freeze(false);await process_frame
	check(not rig.frozen,"完成过渡后重复同步不会重播已完成Tween")
	rig.set_item("")
	game.prologue_letter_ready=true;game.envelope_taken=false;game.field_kit.letter_accepted=false;game.field_kit.sync_world()
	check(game.field_kit.letter_camera.play("letter"),"出租屋信封镜头使用现有场景")
	await capture("演出_信封")
	check(game.exit_save.snapshot().state=="prologue","信封演出中退出恢复到出租屋")
	key(KEY_SPACE);await process_frame
	check(game.state=="prologue" and game.player.cam.current,"跳过信封归还原相机")
	game.field_kit.letter_accepted=true;game.field_kit.sync_world()
	game.start_laundry_case();story=game.laundry.campaign;game._clear_sub();game.audio_system.stop_voice()
	story.progress.night=3;game.spots=game.laundry.spots()
	var guide=story.guidance
	var route:Dictionary=guide.route_for({"id":"c1_cert"},Vector3(-2.1,6.9,4.8))
	check(not route.final and route.pos.x<0 and route.pos.z>5.5,"303到304先通过当前房门，不指向隔墙")
	route=guide.route_for({"id":"c1_mail_letter"},Vector3(2.,6.9,4.7))
	check(not route.final and route.pos.z<6.2 and route.pos.x>1,"儿童房换楼层先从304门退出")
	route=guide.route_for({"id":"c1_valve"},Vector3(2.1,.05,9.4))
	check(route.pos.x<0 and route.pos.z<-7,"去B1检修口先走门厅中央，绕开废电梯")
	route=guide.route_for({"id":"c1_unlock503"},Vector3(1.7,12.75,6.5))
	check(route.pos.x<0,"503反锁时解除插销仍须从502维修通道进入")
	game.player.global_position=Vector3(2.65,.16,-8.1);game.player.velocity=Vector3.ZERO
	for i in range(20):
		await physics_frame
		game.player.velocity=Vector3(0,-1,0);game.player.move_and_slide()
	check(game.player.global_position.y>-.03,"走到检修口盖板不会在按E之前坠井")
	check(game.laundry.rebuilt.service_cover.visible,"检修口有可见实体盖板")
	var light_before:bool=game.player.flash.visible
	key(KEY_L);check(game.player.flash.visible!=light_before,"L独立切换手电，不占用持物查看")
	key(KEY_L)
	game.player.global_position=Vector3(.1,3.55,8.5);game.player.cam.global_position=Vector3(.1,5.05,8.5);game.player.cam.look_at(Vector3(0,4.45,3));game.player.lock_look=true
	game.hud_fade.modulate.a=0;game.director.toast.visible=false
	await capture("店堂_同机位")
	story.doc("slip")
	check(story.workbench.visible and game.state=="case_reader","洗衣单进入实物检查，沿用阅读状态")
	for field in ["date","machine","status"]:story.workbench.examine(field)
	check(story.flag("examined_slip"),"逐字段记录洗衣单")
	await capture("检查_洗衣单")
	story.close_page();story.doc("photo")
	story.workbench.examine("inscription")
	check(not story.flag("examined_photo"),"未翻面时不能记录照片题字")
	key(KEY_1);await process_frame
	await create_timer(.5).timeout
	check(story.workbench.flipped,"数字键实际翻动照片")
	await capture("检查_照片背面")
	key(KEY_2);await process_frame
	check(story.flag("examined_photo"),"翻面后实际按键记录题字")
	story.close_page();story.doc("discharge")
	story.workbench.choose_parcel("27—303—1107")
	check(not game.bag_has("discharge"),"错编号没有进入背包")
	story.workbench.choose_parcel("27—503—1107")
	check(game.bag_has("discharge") and story.flag("examined_discharge"),"核对正确才取到出院小结")
	story.close_page();story.doc("sweater");story.workbench.flip();story.workbench.examine("stitch");story.workbench.examine("condition")
	check(story.flag("examined_sweater"),"衣物翻转、袖口及干湿核对")
	await capture("检查_原衣")
	var snapshot:Dictionary=game.exit_save.snapshot()
	check(preload("res://scripts/case_save.gd").valid(snapshot) and snapshot.state=="play","实物检查中退出获得有效安全存档")
	check(snapshot.laundry.campaign.flags.examined_sweater,"检查结果随存档保存")
	story.close_page()
	var cine=story.cinematic
	var old_eye:Vector3=game.player.global_position
	var old_mode:int=game.player.cam_mode
	check(cine.play("seven"),"七号机实机观察可启动")
	check(not game.laundry.spinning[7],"七号机观察期间滚筒停下")
	check(game.exit_save.snapshot().laundry.spinning[7],"演出中退出不把暂时停机写成永久停机")
	check(game.get_viewport().get_camera_3d()==cine.camera and game.player.physics_frozen,"观察镜头接管并冻结移动")
	await capture("演出_七号机")
	game._open_pause();var previous:float=cine.elapsed;await create_timer(.1).timeout
	check(is_equal_approx(previous,cine.elapsed),"暂停冻结实机演出")
	game._on_resume()
	check(game.player.physics_frozen and game.state=="case_cinematic","恢复演出仍保持身体冻结")
	key(KEY_SPACE);await process_frame
	check(not cine.active and game.state=="play" and not game.player.physics_frozen,"空格跳过后恢复玩家控制")
	check(game.laundry.spinning[7],"演出结束恢复七号机原有状态")
	check(game.player.global_position==old_eye and game.player.cam_mode==old_mode,"跳过保留原位置和视角模式")
	check(game.get_viewport().get_camera_3d()==game.player.cam and not game.audio_system.is_busy(),"跳过归还相机并停止语音")
	check(story.flag("shot_seven"),"已跳过演出记入进度，不反复触发")
	game.laundry._spawn_lady(false);game.laundry.night._do_sit();game.laundry.night.lady_state="count"
	check(cine.play("count"),"数衣演出启动")
	check(game.audio_system.is_busy(),"数衣镜头播放已有普通话语音")
	await capture("演出_数衣")
	cine.finish(true)
	check(not game.audio_system.is_busy(),"跳过数衣立即停止语音")
	check(cine.play("basement"),"退水后地下镜头使用现场竖井")
	await capture("演出_地下")
	cine.finish(true)
	game._discard_laundry();game.field_kit.generation+=1;game.queue_free();await process_frame;await process_frame
	await create_timer(.10).timeout
	print("RESULT: %d passed / %d failed"%[passed,failed]);call_deferred("quit",0 if failed==0 else 1)
