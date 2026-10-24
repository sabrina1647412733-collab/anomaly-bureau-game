extends SceneTree
const Storage:=preload("res://scripts/storage_paths.gd")
const Save:=preload("res://scripts/case_save.gd")
const Archive:=preload("res://scripts/archive.gd")
var game
var dev
var passed:=0
var failed:=0
var errors:Array[String]=[]
var stations:Array[Dictionary]=[]
var out:="F:/诡异事务局/验收/20261024_开发者巡查/"
func _initialize()->void:call_deferred("run")
func check(ok:bool,text:String)->void:
	if ok:passed+=1;print("PASS ",text)
	else:failed+=1;errors.append(text);push_error("FAIL "+text)
func hash_files(folder:String)->Dictionary:
	var result:Dictionary={}
	for name in ["save_1.json","save_2.json","save_3.json","autosave.json","archive.json","laundry_archive.json"]:
		var path:=folder.path_join(name)
		result[name]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result
func key(code:Key)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;Input.parse_input_event(event)
	await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=false;Input.parse_input_event(event)
	await process_frame
func wait_loaded()->void:
	for i in range(600):
		await process_frame
		if not dev.busy:return
	check(false,"巡查载入没有挂起")
func authenticate()->void:
	dev.open_login();dev.account.text="sabrina";dev.password.text=OS.get_environment("DEV_REVIEW_TEST_PASSWORD");dev.submit_login();await wait_loaded()
func run()->void:
	create_timer(180).timeout.connect(func():push_error("developer review timeout");quit(2))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	dev=game.developer_review
	var original_root:String=Storage.root_dir()
	# Existing legitimate records, in an isolated test profile, make the
	# no-overwrite check stronger than merely checking absent files stay absent.
	game._start_prologue(false);game._clear_sub();var seed:Dictionary=Save.capture(game)
	game.exit_save.write_snapshot(original_root.path_join("save_1.json"),seed)
	game.exit_save.write_snapshot(original_root.path_join("autosave.json"),seed)
	Archive.note_play("0017")
	var archive_file:=FileAccess.open(original_root.path_join("laundry_archive.json"),FileAccess.WRITE);archive_file.store_string(JSON.stringify({"case_id":"00184","endings":[]}));archive_file.close()
	game._show_menu()
	var originals:Dictionary=hash_files(original_root)
	check(not dev.authenticated and not dev.active,"默认未登录巡查")
	check(not await dev.visit("c2_17"),"未登录不能直接跳转")
	await key(KEY_F6);check(dev.login_open and dev.password.secret,"F6打开密码隐藏的登录框")
	dev.account.text="sabrina";dev.password.text="wrong";dev.submit_login()
	check(not dev.authenticated and not dev.active and dev.password.text.is_empty(),"错误密码不进入模式且立即清空输入")
	check(Storage.root_dir()==original_root,"错误登录不切换存档目录")
	dev.cancel_login();check(game.state=="menu" and not dev.login_open,"取消登录恢复主菜单")
	await authenticate()
	check(dev.active and dev.authenticated and Storage.inspection_active,"正确凭据进入巡查")
	check(Storage.root_dir()!=original_root and game.exit_save.PATH.begins_with(dev.review_dir),"巡查自动存档路径独立")
	check(Archive.PATH.begins_with(dev.review_dir) and Save.PROGRESS_PATH.begins_with(dev.review_dir),"长期档案与结局记录切到独立目录")
	check(not game.game_save(0) and not game.exit_save.save_now(),"巡查禁写手动与剧情自动存档")
	check(dev.locations.size()==24,"目录包含出租屋、十地标、第一案九机位及第二案四楼层")
	for entry in dev.locations:
		var ok:bool=await dev.visit(entry.id)
		await physics_frame
		stations.append({"id":entry.id,"ok":ok,"feet":str(game.player.global_position)})
		check(ok and game.player.global_position.is_finite(),"安全跳转 "+String(entry.name))
	check(game.case2_controller.active==false,"巡查第二案不启动正式派遣状态机")
	check(game.case_mode!="case2","巡查不冒充正式第二案状态")
	check(dev.case2_world.anomaly_open,"十七楼仅在巡查临时展示")
	dev.toggle_flight();check(not dev.flight and game.player.can_move==false,"面板打开时行走仍冻结")
	await key(KEY_F6);check(not dev.panel.visible and game.player.can_move,"关闭面板启用真实行走")
	var before:Vector3=game.player.global_position;await key(KEY_W);await physics_frame
	check(game.player.global_position.is_finite(),"实际角色控制仍正常")
	await key(KEY_F7);check(dev.flight and game.player.physics_frozen and dev.camera.current,"F7切自由飞行并冻结角色重力")
	dev.camera.global_position+=Vector3(2,3,1);dev.save_bookmark()
	check(FileAccess.file_exists(dev.review_dir.path_join("巡查记录.json")),"巡查视角保存在独立目录")
	await key(KEY_F8);check(dev.camera.global_position.distance_to(game.player.cam.global_position)<.2,"F8回安全站位")
	await dev.visit("town_01");dev.minute_control.value=1080;dev.rain_control.value=.8;dev.wet_control.value=.7;await process_frame
	check(is_equal_approx(game.town_bridge.weather.rain_amount,.8) and is_equal_approx(game.town_bridge.weather.wetness,.7),"巡查可独立指定雨量与路面湿度")
	var clock:float=game.director.now();await create_timer(.2).timeout
	check(is_equal_approx(game.director.now(),clock),"巡查时间固定且不推进剧情")
	dev.save_bookmark();await dev.visit("c1_2");dev.restore_bookmark();await wait_loaded()
	check(dev.current_id=="town_01" and dev.flight,"保存视角可以跨区域恢复")
	var view_before_reload:Transform3D=dev.camera.global_transform
	dev.reload_area();await wait_loaded();check(dev.current_id=="town_01" and game.town_bridge.active,"当前街道可以重新组装")
	check(dev.camera.global_position.distance_to(view_before_reload.origin)<.01,"重载后保留刚才的检查视角")
	await dev.visit("c2_8");dev.reload_area();await wait_loaded();check(dev.current_id=="c2_8" and is_instance_valid(dev.case2_world),"第二案区域可以重载")
	check(dev.end_session(),"退出巡查恢复主菜单")
	await process_frame;await physics_frame
	check(not Storage.inspection_active and Storage.root_dir()==original_root,"退出恢复正式数据路径")
	check(hash_files(original_root)==originals,"整轮巡查未改写正式存档或档案")
	game._start_prologue(false);game._hide_menu();game._clear_sub();game.director.room_minutes=1431.25
	game.field_kit.phone_owned=true;game.bag_add("phone","手机");game.field_kit.sync_world()
	var before_room:Dictionary=game.exit_save.snapshot()
	await authenticate();await dev.visit("c2_16");check(dev.end_session(),"正常游戏进入巡查后可退出")
	await process_frame;await physics_frame
	check(game.state=="prologue" and game.prologue_stage=="room","恢复原出租屋流程")
	print("RETURN_STATE_CLOCK actual=",game.director.room_minutes," captured=",dev.snapshot.director.room_minutes," bag=",game.case_bag==dev.snapshot.bag)
	check(game.case_bag==dev.snapshot.bag,"恢复进入巡查前的背包")
	check(absf(game.director.room_minutes-float(dev.snapshot.director.room_minutes))<.1,"恢复进入巡查前时钟，正常返回帧继续计时")
	check(game.player.global_position.distance_to(Vector3(before_room.position[0],before_room.position[1],before_room.position[2]))<.2,"恢复进入前玩家位置")
	game.start_laundry_case();game._clear_sub();game.laundry.campaign.cinematic.cancel();game.laundry.campaign.dialogue.cancel();game.state="play"
	var progress:Dictionary=game.laundry.campaign.capture()
	await authenticate();await dev.visit("room");check(dev.end_session(),"第一案现场进入巡查后能恢复")
	await process_frame;await physics_frame
	check(game.case_mode=="laundry" and game.laundry.campaign.capture()==progress,"第一案调查证据和夜次未被巡查更改")
	game._open_pause();await authenticate();await dev.visit("room");check(dev.end_session(),"暂停菜单进入巡查可退出")
	check(game.state=="paused" and game.player.physics_frozen,"返回暂停前界面，不意外继续游戏")
	game._on_resume();game.case2_controller.begin();game.case2_controller.campaign.dialogue.cancel();game._clear_sub();game.state="prologue"
	var before_case2:Dictionary=game.case2_controller.campaign.capture()
	await authenticate();await dev.visit("c1_2");check(dev.end_session(),"第二案接续现场进入巡查可恢复")
	await process_frame
	check(game.case2_controller.active and game.case2_controller.campaign.capture()==before_case2,"第二案证据与合作状态不受巡查影响")
	# Residential return-state fixture must include the legitimate arrival
	# prerequisites; bypassing the dispatch would create an invalid save.
	for prerequisite in ["coop_done","orphanage_done","departed"]:game.case2_controller.campaign.mark(prerequisite)
	game.case2_controller.enter_residence();game.case2_controller.campaign.dialogue.finish(true);game._clear_sub()
	game.player.global_position=game.case2_controller.world.get_floor_spawn(8);await physics_frame
	var residence:Dictionary=game.exit_save.snapshot()
	check(game.case2_controller.campaign._valid_dependencies(residence.case2.campaign.flags),"住宅返回测试使用合法的抵达前置记录")
	await authenticate();await dev.visit("c1_3");check(dev.end_session(),"第二案住宅内部进入巡查可退出")
	await process_frame;await physics_frame
	check(game.case_mode=="case2" and game.case2_controller.in_residence,"恢复住宅内部而非错误返回公寓")
	check(game.case2_controller.campaign.capture()==residence.case2.campaign,"住宅调查记录原样恢复")
	check(game.player.global_position.distance_to(Vector3(residence.position[0],residence.position[1],residence.position[2]))<.2,"恢复第二案原楼层与站位")
	check(Storage.root_dir()==original_root and not dev.authenticated,"结束后退出登录")
	game.audio_system.stop_voice();game.case2_controller.reset();game._discard_laundry();game.queue_free();await process_frame;await process_frame;await create_timer(.2).timeout
	var file:=FileAccess.open(out+"result.json",FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"failed":failed,"errors":errors,"locations":stations,"method":"UI login, scene/capsule jumps, isolated storage and return-state integration; not a complete story playthrough"},"\t"));file.close()
	print("DEVELOPER_REVIEW_RESULT ",passed," passed ",failed," failed");quit(0 if failed==0 else 1)
