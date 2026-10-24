extends SceneTree
## Shared-system acceptance, separate from the normal-input story route.
const SAVE := preload("res://scripts/case_save.gd")
var game
var passed:=0
var failed:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if ok:passed+=1;print("PASS ",message)
	else:failed+=1;failures.append(message);push_error("FAIL "+message)
func run()->void:
	create_timer(100).timeout.connect(func():push_error("integration timeout");quit(2))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.exit_save.set_process(false);game.safety.set_physics_process(false)
	game._on_new_game();game._start_prologue(false);game._clear_sub()
	var old:Dictionary=SAVE.capture(game)
	old.erase("series");old.erase("case2")
	check(SAVE.valid(old),"schema2第一案旧存档仍然接受")
	game.case2_controller.begin();game._clear_sub()
	var c=game.case2_controller;var story=c.campaign
	check(c.active and game.series.chapter=="00201","在现有游戏中接续第二案")
	check(game.laundry==null and game.case_mode=="","首案场景释放，次日公寓共享原玩家")
	check(not game.phone_ui.incoming and game.prologue_call_done,"次日不会重播催租投信")
	check(game.bag_has("phone") and game.bag_has("weird_clock"),"手机与时钟可继续取用")
	check(c.room_spots().size()==2,"公寓提供阿七与真实门口交互")
	var clock:float=c.clock_minutes
	game.state="prologue";c.step(6.)
	check(is_equal_approx(c.clock_minutes,clock+1.),"现实6秒推进游戏1分钟")
	game.director.step(6.)
	check(is_equal_approx(c.clock_minutes,clock+1.) and is_equal_approx(game.director.now(),c.clock_minutes),"全局director共用一个第二案时钟")
	game.bag_open=true;c.step(6.);game.bag_open=false
	check(is_equal_approx(c.clock_minutes,clock+1.),"打开背包暂停第二案时间")
	var room:Dictionary=SAVE.capture(game)
	check(room.case_id=="00201" and SAVE.valid(room),"次日公寓可保存第二案")
	check(SAVE.restore(game,room),"次日公寓读档")
	await process_frame
	c=game.case2_controller;story=c.campaign
	check(c.active and not c.in_residence and c.campaign.progress.phase=="cooperation","恢复合作前状态，不越过剧情")
	story.mark("coop_done");story.mark("orphanage_done");story.mark("departed")
	c.enter_residence();story.dialogue.finish(true);game._clear_sub();await physics_frame
	check(game.case_mode=="case2" and c.in_residence and c.world.visible,"道口派遣进入独立槐安住宅")
	check(game.safety.current_zone()=="case2","防跌落系统识别第二案")
	check(game.safety.in_bounds(game.player.global_position),"住宅出生点在安全范围")
	var saved:Dictionary=SAVE.capture(game)
	check(SAVE.valid(saved) and saved.mode=="case2","住宅可保存")
	check(SAVE.restore(game,saved),"住宅读档重建真实世界与剧情状态")
	await process_frame;await physics_frame
	c=game.case2_controller;story=c.campaign
	check(c.in_residence and game.case_mode=="case2" and story.flag("arrived"),"住宅读档保留抵达记录")
	story.show_page("保存中断检查","不应跳过取证。",[])
	var reader:Dictionary=game.exit_save.snapshot()
	check(SAVE.valid(reader) and reader.state=="play","读调查材料时退出保存为现场，不固化模态")
	story.close_page()
	story.speak("arrival")
	var talking:Dictionary=game.exit_save.snapshot()
	check(SAVE.valid(talking) and talking.state=="play","对白中退出可恢复现场")
	story.dialogue.cancel();game.state="play"
	var broken:Dictionary=saved.duplicate(true);broken.case2.clock_minutes=NAN
	check(not SAVE.valid(broken),"拒绝非有限第二案时钟")
	c.return_to_town();game._clear_sub()
	check(game.town_bridge.active and not c.in_residence and not c.world.visible,"返回原街道而非替代项目")
	check(c.street_target()=="10","目标名称指向派遣道口")
	game.town_bridge.toggle_map();var before:float=c.clock_minutes;c.step(6.)
	check(not game.player.can_move and not game.player.allow_capture and is_equal_approx(before,c.clock_minutes),"大地图阻止人物移动和时间推进")
	game.town_bridge.toggle_map()
	check(game.player.can_move and game.player.allow_capture,"关闭大地图恢复移动")
	check(game.town_bridge.town_map.target_name()=="铁路道口","地图按地标数据读取目标名")
	var street:Dictionary=SAVE.capture(game)
	check(SAVE.valid(street) and SAVE.restore(game,street),"第二案途中街道可保存再继续")
	await process_frame
	check(game.town_bridge.active and game.case2_controller.active,"街道存档保留第二案")
	check(SAVE.restore(game,old),"可以从第二案切回第一案旧存档")
	await process_frame
	check(not game.case2_controller.active and game.case_mode=="" and game.prologue_stage=="room","旧档不残留第二案空间与会话")
	game.audio_system.stop_voice();game.queue_free();await process_frame;await process_frame;await create_timer(.2).timeout
	var output:="F:/诡异事务局/验收/20261024_24小时开发/case2_integration.json"
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"failed":failed,"failures":failures,"method":"shared-system fixtures, not normal story-route play"},"\t"));file.close()
	print("CASE2_INTEGRATION ",passed," passed ",failed," failed")
	quit(0 if failed==0 else 1)
