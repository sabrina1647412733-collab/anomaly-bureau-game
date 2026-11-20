extends SceneTree
const SAVE:=preload("res://scripts/case_save.gd")
var game
var story
var duty
var passed:=0
var errors:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if ok:passed+=1;print("PASS ",message)
	else:errors.append(message);push_error(message)
func freeze()->void:
	game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false)
	story=game.laundry.campaign;duty=story.duty;story.set_process(false);duty.set_process(false)
	story.guidance.set_process(false);story.cinematic.set_process(false)
	game._clear_sub();game.audio_system.stop_voice();game.state="play"
func run()->void:
	create_timer(90).timeout.connect(func():quit(2))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false);game.field_kit.letter_accepted=true
	game.start_laundry_case();freeze()
	check(story.current_goal().id=="lb_booth","新夜先领取工作单")
	check(duty.event_blocked(),"未巡检不跳关键事件")
	duty.order_page();check(story.heading.text.contains("巡检"),"工作单有具体工作")
	duty.take_order();check(duty.received() and story.flag("signed"),"签收幂等落旗标")
	story.mark("rules_seen");check(story.current_goal().id=="l_m3","须知后到实体三号机")
	duty.interact("l_m3");check(duty.glass.visible and story.modal.visible,"打开独立擦拭操作")
	duty.glass.complete();check(not story.flag("glass_checked"),"未擦净不能凭按钮完成")
	for index in range(12):
		if duty.glass.active_cell(index):duty.glass.stroke(duty.glass.cell_point(index),duty.glass.cell_point(index))
	var partial:float=duty.glass.coverage()
	check(partial>0 and partial<.8,"擦拭需要覆盖玻璃")
	var snapshot=SAVE.capture(game)
	check(not snapshot.is_empty(),"操作中可保存正常现场")
	story.close_page();check(not duty.glass.visible,"关闭操作归还视图")
	check(SAVE.restore(game,JSON.parse_string(JSON.stringify(snapshot))),"部分擦拭存档可恢复")
	freeze()
	check(is_equal_approx(duty.glass.coverage(),partial),"读档保留已擦区域")
	check(game.state=="play" and not story.modal.visible,"读档不恢复半开操作UI")
	duty.interact("l_m3")
	for i in range(64):
		if duty.glass.active_cell(i):duty.glass.stroke(duty.glass.cell_point(i),duty.glass.cell_point(i))
	check(is_equal_approx(duty.glass.coverage(),1.0),"擦拭覆盖完成")
	duty.glass.retry();check(not story.flag("glass_checked"),"错误判断不解锁任务")
	duty.glass.complete();check(story.flag("glass_checked") and not duty.glass.visible,"确认内侧手印才完成巡检")
	story.close_page()
	game.laundry.clues["slip"]=true;story.mark("seven_seen")
	check(story.current_goal().id=="l_m9","拾取单据后仍需物理核对")
	story.mark("examined_slip");check(story.current_goal().id=="c1_terminal","工作完成可到柜台值守")
	duty.begin_wait(21*60);check(duty.waiting,"柜台不需要持有时钟")
	var before:float=game.laundry.t
	duty._process(.6);check(is_equal_approx(game.laundry.t,before),"过渡未完成不提前写时间")
	game._open_pause();duty._process(8)
	check(duty.waiting and is_equal_approx(duty.wait_elapsed,.6),"暂停冻结值守过渡")
	var paused=SAVE.capture(game)
	check(not paused.is_empty() and is_equal_approx(float(paused.laundry.t),before),"值守中存档使用已确认时间")
	game._on_resume();story.close_page();duty._process(2)
	check(not duty.waiting and is_equal_approx(game.laundry.t,before),"取消值守不跳时间")
	duty.begin_wait(21*60);duty._process(1.7)
	check(game.laundry.fired.has("bc1") and not game.laundry.fired.has("bc2"),"一次值守只到第一个关键事件")
	game._clear_sub();game.audio_system.stop_voice()
	check(story.current_goal().id=="c1_broadcast","广播后先留记录")
	game.laundry.t=40*60;story.timeline()
	check(not game.laundry.fired.has("bc2"),"未抄录第一遍不能补播第二遍")
	duty.broadcast_page();story.invoke(0)
	check(story.flag("duty_broadcast1"),"原句抄录保留")
	story.timeline();game._clear_sub();game.audio_system.stop_voice()
	check(game.laundry.fired.has("bc2"),"抄录后可恢复第二遍事件")
	duty.broadcast_page();story.invoke(1);check(not story.flag("duty_broadcast2"),"广播错误判断可复查")
	duty.broadcast_page();story.invoke(0);check(story.flag("duty_broadcast2"),"广播差异核对完成")
	story.close_page();story.mark("met_lady");game.laundry.fired["oldlady"]=true
	duty.bag_page();story.invoke(1);check(not story.flag("duty_bag_logged"),"未取原衣不允许冒记交还")
	duty.bag_page();story.invoke(0);check(story.flag("duty_bag_logged"),"来客五件与未取原衣分开登记")
	game.laundry.fired["beat14"]=true;duty.interact("c1_towel")
	check(story.flag("duty_towel_read"),"停电后检查新出现的实物")
	story.close_page();var saved:Dictionary=story.capture()
	story.restore(JSON.parse_string(JSON.stringify(saved)))
	check(duty.required_work_done(),"新旗标完整往返保存")
	story.progress.night=2
	check(story.current_goal().id=="lb_booth","第二夜单独领当班任务")
	duty.take_order();check(story.current_goal().id=="l_locked_402","第二夜工作单接回原身份调查")
	story.progress.night=3
	check(story.current_goal().id=="lb_booth","第三夜领取安全检修单")
	duty.take_order();check(story.current_goal().id=="c1_keybox","第三夜接回原检修证据链")
	var legacy={"night":2,"flags":{"signed":true},"rest_pending":false,"power":0}
	story.restore(legacy)
	check(duty.received() and duty.required_work_done(),"旧第二夜档不强加第一夜新杂务")
	check(not story.flag("recognized") and game.laundry.selected_ending=="","任务不提前授予结局")
	print("SHIFT_WORK_RESULT ",JSON.stringify({"passed":passed,"failed":errors.size(),"errors":errors}))
	game._discard_laundry();game.queue_free();await process_frame;await process_frame
	quit(0 if errors.is_empty() else 1)
