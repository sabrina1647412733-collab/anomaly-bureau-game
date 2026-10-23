extends SceneTree
## Targeted scene/state regression, not a normal-speed human playthrough.
## Always run headless with Dummy audio and isolated F-drive verification data.
const SAVE := preload("res://scripts/case_save.gd")
const OUT := "res://_预览/20261024_调查节奏/"
const FIRST_IDS := ["bc1","bc2","oldlady","beat13","beat14","count","ask"]
const FIRST_AT := [21.0,40.0,90.0,170.0,171.0,210.0,240.0]
const END_IDS := ["handover","handover_items","recorded","dawn4","aqi_line","case_end"]
const END_AT := [255.0,256.0,258.0,260.0,261.0,262.0]
var game
var lc
var story
var passed := 0
var failed := 0
var errors: Array[String] = []

func _initialize() -> void:call_deferred("run")

func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;errors.append(label);push_error("FAIL "+label)

func clear_ui() -> void:
	if story!=null:
		if story.cinematic.active:story.cinematic.cancel()
		if story.dialogue.active:story.dialogue.finish(false)
		if story.modal.visible:story.close_page()
	if game.director.modal.visible:game.director.close_clock(false)
	game.audio_system.stop_voice()
	game._clear_sub()
	game.phone_open=false;game.bag_open=false;game.nb_open=false;game.choice=null
	game.state="play"
	if lc!=null and lc.night!=null:lc.night.lady_state="sit"

func freeze_drivers() -> void:
	game.set_process(false)
	game.player.set_physics_process(false)
	game.safety.set_physics_process(false)
	game.exit_save.set_process(false)
	story.guidance.set_process(false)
	story.cinematic.set_process(false)
	story.dialogue.set_process(false)
	game.field_kit.letter_camera.set_process(false)

func reset_shift(night: int) -> void:
	clear_ui()
	game.case_mode="laundry"
	story.progress={"night":night,"rest_pending":false,"paid":0,"rent_due":2160,"earnings":0,"spare":0,"flags":{},"power":0,"knocks":0}
	for key in ["signed","rules_seen","seven_seen"]:story.mark(key)
	lc.clues={"slip":true}
	lc.fired.clear();lc.t=0.0;lc.ended=false;lc.selected_ending="";lc.final_open=false
	game.field_kit.letter_accepted=true
	game.director.room_minutes=1420.0
	game.state="play"

func event_ids() -> Array:
	var ids: Array=[]
	for event in story.timed_events():ids.append(String(event.id))
	return ids

func check_table(ids: Array,at: Array,label: String) -> void:
	var events: Array=story.timed_events()
	check(event_ids()==ids,label+" 事件顺序")
	var good:=events.size()==at.size()
	for i in mini(events.size(),at.size()):
		good=good and is_equal_approx(float(events[i].at),float(at[i])) and not String(events[i].label).is_empty()
	check(good,label+" 原定时刻及标签")

func legacy_cinematic_check(night: int,recognized: bool) -> void:
	reset_shift(night)
	lc.fired={"bc2":true,"count":true}
	if recognized:story.mark("recognized")
	game.player.global_position=Vector3(.2,3.55,6.5)
	# Auto-observation requires a processing game; only call this driver directly,
	# with no intervening frame that could advance the unrelated main loop.
	game.set_process(true)
	story.cinematic._process(0.0)
	game.set_process(false)
	check(not story.cinematic.active,"旧档第%d夜的bc2/count不补演旧镜头%s"%[night,"（已认领）" if recognized else ""])
	if story.cinematic.active:story.cinematic.cancel()

func run() -> void:
	check(DisplayServer.get_name()=="headless","回归使用无窗口显示驱动")
	check(AudioServer.get_driver_name()=="Dummy","回归不打开声音设备")
	if DisplayServer.get_name()!="headless" or AudioServer.get_driver_name()!="Dummy":
		finish();return
	create_timer(110.0).timeout.connect(func():push_error("Investigation pacing timeout");quit(2))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game._hide_menu();game._start_prologue(false)
	game.field_kit.letter_accepted=true
	game.phone_ui.incoming=false;game.phone_ui.quiet=true
	game.start_laundry_case();lc=game.laundry;story=lc.campaign
	freeze_drivers();clear_ui()
	await physics_frame
	reset_shift(1)
	check_table(FIRST_IDS,FIRST_AT,"第一夜保留完整调查事件")
	for night in [2,3]:
		reset_shift(night)
		check_table(["oldlady"],[90.0],"第%d夜只保留有新人物信息的定时来客"%night)
	reset_shift(3);story.mark("recognized")
	check_table(END_IDS,END_AT,"已认领使用唯一尾声表")
	reset_shift(3);lc.selected_ending="A"
	check_table(END_IDS,END_AT,"旧档selected_ending也能进入尾声表")

	reset_shift(1)
	lc.t=20.99*60.0
	check(is_equal_approx(float(story.next_event()[0]),1441.0),"阈值前0.01游戏分钟不会跳过尚未触发的第一遍广播")
	lc.t=21.10*60.0
	check(is_equal_approx(float(story.next_event()[0]),1420.0+lc.t/60.0),"过期未播事件返回当前时刻而非倒退或越过")
	story.timeline()
	check(lc.fired.has("bc1") and not lc.fired.has("bc2"),"跨过阈值仍先补第一遍广播")
	clear_ui();reset_shift(1);lc.t=100.0*60.0
	story.timeline()
	check(lc.fired.size()==1 and lc.fired.has("bc1"),"迟到一次只触发最早一项，不叠播广播与来客")
	var before: Dictionary=lc.fired.duplicate(true)
	story.timeline()
	check(lc.fired==before,"当前字幕尚未结束不会继续补发第二项")
	clear_ui();story.timeline()
	check(lc.fired.size()==2 and lc.fired.has("bc2") and not lc.fired.has("oldlady"),"字幕结束后下一次只补第二遍广播")
	clear_ui();story.timeline()
	check(lc.fired.size()==3 and lc.fired.has("oldlady") and lc.lady!=null,"广播记录后才生成来客")

	clear_ui();lc.t=210.0*60.0
	before=lc.fired.duplicate(true)
	game.sub="仍在阅读当前现场字幕";game.sub_pause=false
	story.timeline()
	check(lc.fired==before,"普通非模态字幕期间也不继续触发下一事件")
	check(is_equal_approx(float(story.next_event()[0]),1420.0+lc.t/60.0),"普通字幕期间时钟保持当前事件")
	game._clear_sub();game.sub_queue=[{"who":"旁白","text":"下一句","hold":2.0,"pause":false}]
	story.timeline();check(lc.fired==before,"字幕队列未播完不触发下一事件")
	game._clear_sub();game.audio_system.speak_dialogue("xu_missing")
	check(game.audio_system.is_busy(),"Dummy下加载真实对白流用于会话门控")
	story.timeline();check(lc.fired==before,"语音期间不触发下一事件")
	game.audio_system.stop_voice()
	lc.night.lady_state="walk"
	story.timeline();check(lc.fired==before,"人物入座行走尚未结束不触发下一事件")
	lc.night.lady_state="sit"
	story.cinematic.active=true
	story.timeline();check(lc.fired==before,"短演出期间不追赶时间事件")
	story.cinematic.active=false
	lc.blackout_active=true
	story.timeline();check(lc.fired==before,"停电尚在演出时不追加擦拭和数衣事件")
	lc.blackout_active=false
	reset_shift(1);story.progress.flags.erase("signed");lc.t=200.0*60.0
	story.timeline()
	check(lc.t<=20.0*60.0 and lc.fired.is_empty(),"首夜报到未完成仍保留新手调查门控")

	for night in [2,3]:
		reset_shift(night);lc.t=260.0*60.0
		story.timeline();clear_ui();story.timeline()
		check(lc.fired.has("oldlady") and not lc.fired.has("bc1") and not lc.fired.has("bc2") and not lc.fired.has("beat13") and not lc.fired.has("beat14") and not lc.fired.has("count") and not lc.fired.has("ask"),"第%d夜迟到不补发第一夜旧广播和旧紧张事件"%night)
	legacy_cinematic_check(2,false)
	legacy_cinematic_check(3,false)
	legacy_cinematic_check(3,true)

	reset_shift(3);story.mark("recognized");lc.selected_ending="A";lc.t=255.0*60.0
	story.timeline()
	check(lc.fired.has("handover") and lc.fired.size()==1,"提前认领跳至交班仅触发尾声，不回补旧调查段")
	check(not game.sub.contains("还差一件") and not game.sub.contains("是不是洗好了") and game.sub_queue.is_empty(),"交还第六件后不再出现缺衣或催衣台词")
	clear_ui();lc.t=256.0*60.0;story.timeline()
	check(lc.fired.has("handover_items") and int(story.progress.earnings)==2400 and int(story.progress.spare)==240,"最后一夜工资仍按原唯一结案账目发放")
	var wages: int=game.case_bag.filter(func(item):return item.get("id","")=="wage_3").size()
	clear_ui();story.timeline()
	check(int(story.progress.earnings)==2400 and game.case_bag.filter(func(item):return item.get("id","")=="wage_3").size()==wages,"重复追赶不重复领取最后工资")

	reset_shift(1)
	var director=game.director
	director.send_once("pacing_review_toast","派遣科","测试调查消息，只供后台回归。")
	var remaining: float=director.toast_time
	game.sub="当前现场字幕";director.sync_toast(2.0)
	check(not director.toast.visible and is_equal_approx(director.toast_time,remaining),"普通字幕期间通知暂缓并保留剩余阅读时间")
	game._clear_sub();game.audio_system.speak_dialogue("xu_missing");director.sync_toast(2.0)
	check(not director.toast.visible and is_equal_approx(director.toast_time,remaining),"语音期间不弹任务通知")
	game.audio_system.stop_voice();director.sync_toast(.5)
	check(director.toast.visible and director.toast_time<remaining,"现场空档后继续显示已入箱通知")
	check(game.phone_ui.messages.get("派遣科",[]).has("测试调查消息，只供后台回归。"),"暂缓通知不丢失手机消息")
	for id in ["bc1","bc1_n2","bc1_n3"]:director.sent.erase(id)
	lc.t=21.0*60.0;director.step(0.0)
	check(not director.sent.has("bc1"),"共用导演不再另发一份广播目标短信")

	reset_shift(2)
	story.progress.paid=1;story.progress.earnings=800;story.progress.rent_due=1360
	for key in ["zhou_open","examined_photo","name_told"]:story.mark(key)
	for key in ["sign","marriage","photo","cert","return_card","discharge","testimony","pipe_map","tool_key"]:lc.clues[key]=true
	lc.fired.oldlady=true;lc.t=100.0*60.0
	check(story.current_goal().id=="c1_terminal" and story.current_goal().mode=="act","第二夜材料和姓名已齐立即引导柜台，不空等03:40")
	story.terminal()
	check(story.modal.visible and story.actions.size()>0 and not story.heading.text.contains("现场继续观察"),"第二夜可在03:40前打开续查提交页")
	story.invoke(0)
	check(bool(story.progress.rest_pending) and is_equal_approx(lc.t,260.0*60.0),"提前提交仍统一等待04:00交班，未提前结束夜次")
	check(int(story.progress.paid)==2 and int(story.progress.earnings)==1600 and int(story.progress.rent_due)==560,"第二夜工资及欠租沿用原账目")
	clear_ui();story.terminal()
	check(int(story.progress.earnings)==1600 and int(story.progress.paid)==2,"重复查看交班页不刷工资")
	clear_ui()
	var saved: Dictionary=SAVE.capture(game)
	check(SAVE.valid(saved) and int(saved.schema_version)==2,"节奏调整继续使用既有现场存档schema2")
	check(SAVE.restore(game,saved),"交班状态仍可保存恢复")
	lc=game.laundry;story=lc.campaign;freeze_drivers();clear_ui()
	check(story.night_number()==2 and bool(story.progress.rest_pending) and int(story.progress.earnings)==1600 and lc.has_clue("discharge"),"恢复后保留第二夜、交班、工资和医院证据")
	game.case_mode="";game.state="prologue";game.prologue_stage="room"
	game.prologue_objective="本夜结束，回出租公寓床边休息。"
	director=game.director;director.room_minutes=1680.0;director.open_clock()
	check(director.event_label.text.contains("休息"),"交班后在室外取钟提示休息，不重复催首次报到")
	var objective: String=game.prologue_objective
	director.next_event()
	check(director.modal.visible and is_equal_approx(director.room_minutes,1680.0) and game.prologue_objective==objective,"无可推进事件不关闭时钟或覆盖回家目标")
	director.close_clock(false)
	story.begin_next_night()
	check(story.night_number()==3 and not bool(story.progress.rest_pending) and lc.t==0.0 and lc.has_clue("discharge"),"休息正常进入第三夜并保留证据")
	check(lc.fired.is_empty() and lc.selected_ending=="" and int(story.progress.earnings)==1600,"下一夜清时间事件而不重复工资或提前结案")
	check_table(["oldlady"],[90.0],"下一夜自动使用精简事件表")
	director.open_clock();director.advance(1.0)
	check(game.prologue_objective.contains("续查") and not game.prologue_objective.contains("带通知书"),"第三夜拨时不覆盖成首夜任务话术")

	reset_shift(3)
	for key in story.REQUIRED:lc.clues[key]=true
	story.mark("drained")
	lc.t=260.0*60.0
	var late_time: float=lc.t
	story.resolve_claim()
	check(lc.selected_ending=="A" and story.flag("recognized") and lc.t>=late_time,"04:00才完成认领不会倒退到03:54")
	clear_ui();story.start_epilogue()
	check(lc.t>=late_time,"晚完成后进入尾声不会倒退到03:55")
	clear_ui()
	var recognized_only: Dictionary=SAVE.capture(game)
	recognized_only.laundry.selected_ending=""
	recognized_only.laundry.claimed=false
	recognized_only.laundry.ended=false
	recognized_only.laundry.t=261.0*60.0
	recognized_only.laundry.fired={"handover":true,"handover_items":true,"recorded":true,"dawn4":true}
	recognized_only.laundry.campaign.rest_pending=false
	recognized_only.laundry.campaign.paid=3
	recognized_only.laundry.campaign.earnings=2400
	recognized_only.laundry.campaign.rent_due=0
	recognized_only.laundry.campaign.spare=240
	recognized_only.clock=1681.0
	recognized_only.director.room_minutes=1681.0
	check(SAVE.restore(game,recognized_only),"只保存recognized的旧状态仍可恢复")
	lc=game.laundry;story=lc.campaign;freeze_drivers();clear_ui()
	check(lc.selected_ending=="A" and lc.claimed and lc.t>=261.0*60.0,"已认领旧档正规化唯一A且不夹回04:00")
	story.timeline()
	check(lc.fired.has("aqi_line") and lc.t>=261.0*60.0,"已认领旧档能够推进04:01阿七尾声")
	clear_ui();lc.t=262.0*60.0;story.timeline()
	check(lc.ended and game.state=="case_end" and lc.selected_ending=="A","已认领旧档最终到达同一唯一结案")
	game.field_kit.generation+=1
	game._discard_laundry();story=null;lc=null;game.queue_free()
	await process_frame;await process_frame
	finish()

func finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var report := {"passed":passed,"failed":failed,"errors":errors,"method":"headless Dummy targeted actual-scene state regression with isolated verification storage; not human pacing/visual/audio acceptance"}
	var file:=FileAccess.open(OUT+"pacing_review_result.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()
	print("INVESTIGATION_PACING_RESULT ",JSON.stringify(report))
	quit(1 if failed else 0)
