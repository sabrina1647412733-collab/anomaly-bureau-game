extends Node
## Work orders wrap the existing investigation. They do not supply hidden answers.
const ORDERS := [
	["巡检与未取衣登记","①阅读2F工作须知，擦净三号机外侧玻璃。\n②检查九号烘干机，核对纸上的日期、机号、取衣状态。\n③七号机若上锁，只记录，不强开。\n④值守时抄录广播，为来客核对衣物。\n\n完成条件：工作记录有依据；无法处理的异常如实申请续查。"],
	["查明未取衣的收件人","昨夜的洗衣单与旧招牌已留档，不能仅凭来客一句话把衣服交走。\n\n先带洗衣单去4F402找修表师傅，再核对住户证件、照片背面与医院挂号件。\n\n完成条件：有材料核实姓名；听取口述，取回检修线索，提交续查。"],
	["安全检修与原衣交还","按管线图先查看5F检修盒和屋顶维修记录。\n涉水前先隔离浸水回路，再接独立泵，最后到B1开阀。\n用实物、日期与口述核对事故，再找到未取原衣。\n\n完成条件：安全排水，结论有据，原衣交还本人；未确认的去向不能写成死亡。"]
]
var story
var game
var glass
var print_mesh:MeshInstance3D
var clipboard:Label3D
var waiting := false
var wait_elapsed := 0.0
var wait_target := 0.0
var wait_from := 0.0

func setup(owner_story) -> void:
	story=owner_story;game=story.game
	glass=preload("res://scripts/shift_glass.gd").new()
	story.modal.add_child(glass);glass.setup(self)
	_build_props()

func received() -> bool:
	return story.flag("duty_received_%d"%story.night_number())

func take_order() -> void:
	if received():story.close_page();return
	story.mark("signed");story.mark("duty_received_%d"%story.night_number())
	game.note("物","第%d夜当班单 · %s"%[story.night_number(),ORDERS[story.night_number()-1][0]],ORDERS[story.night_number()-1][1])
	game.audio_system.sfx("paper",-13)
	story.close_page();story.update_objective()
	game.feedback.notify("当班单已签收","按 H 查看现场下一步；2F柜台可查进度、提交记录和继续值守。")

func order_page() -> void:
	var index=story.night_number()-1
	var buttons:Array=[["返回现场",story.close_page]] if received() else [["签收当班工作单",take_order],["先收起",story.close_page]]
	story.show_page("第%d夜 / %s"%[index+1,ORDERS[index][0]],ORDERS[index][1]+("\n\n交接簿最后日期停在2004-11-07。上一班姓名空白，“已交接”的章却已经盖好。" if index==0 else "\n\n上一夜材料保留，无需重做已经完成的检查。"),buttons)

func goal_override(base:Dictionary) -> Dictionary:
	if bool(story.progress.rest_pending):return {}
	if not received():return story.goal("lb_booth","到1F传达室签收今晚的工作单。","夜班工作单写明要求；签收后上楼执行。")
	if story.night_number()==1 and not story.flag("recognized"):
		if not story.flag("rules_seen"):return {}
		if not story.flag("glass_checked"):return story.goal("l_m3","巡检：擦净三号机外侧玻璃，确认印痕。","对准三号机门按 E，再拖动抹布；擦不掉的部分要如实记录。")
		if story.lc.has_clue("slip") and not story.flag("examined_slip"):return story.goal("l_m9","登记未取衣：核对纸单的日期、机号和状态。","打开纸单，逐项检查，不能只凭一眼登记。")
		if story.flag("seven_seen"):
			if story.lc.fired.has("bc1") and not story.flag("duty_broadcast1"):return story.goal("c1_broadcast","巡检记录：抄下第一遍广播。","广播的原句留在记事本，下一遍再核对。")
			if story.lc.fired.has("bc2") and not story.flag("duty_broadcast2"):return story.goal("c1_broadcast","两遍广播有出入，核对改动的字。","把记事本里的第一遍与现在的广播对照，再登记。")
		if story.flag("met_lady") and not story.flag("duty_bag_logged"):return story.goal("c1_bag_check","核对来客布袋：确认现有衣物数与未取单。","不把没找到的衣服登记成已交还。")
		if story.lc.fired.has("beat14") and not story.flag("duty_towel_read"):return story.goal("c1_towel","停电后多了一条毛巾，检查绣字。","比对旧洗衣单的名字，先留记录。")
	if base.get("mode","")=="wait":
		return story.goal("c1_terminal","阶段工作已完成：到2F柜台继续值守，或自由复查。","柜台可以值守至下一已知时点，不需要诡异时钟；新线索仍须亲自处理。")
	return {}

func required_work_done() -> bool:
	return story.night_number()!=1 or (story.flag("glass_checked") and story.flag("examined_slip") and story.flag("duty_broadcast1") and story.flag("duty_broadcast2") and story.flag("duty_bag_logged") and story.flag("duty_towel_read"))

func open_counter() -> void:
	if bool(story.progress.rest_pending):story.submit_shift();return
	if not received():order_page();return
	var base:Dictionary=story.investigation_goal()
	var extra=goal_override(base)
	if base.get("mode","")=="wait" and (extra.is_empty() or extra.id=="c1_terminal"):
		var next:Array=story.next_event()
		var pending:Dictionary=story.pending_event()
		if not pending.is_empty() and next[1]==pending.label:
			var target=maxf(story.lc.t,float(pending.at)*60)
			var routine=String(pending.id) in ["bc1","bc2","handover","handover_items","dawn4"]
			var description="下一例行检查：%s"%game.director.hhmm(1420+target/60) if routine else "下一项：整理已留底的记录，继续在柜台值守。"
			var button="继续值守至 %s"%game.director.hhmm(1420+target/60) if routine else "继续值守，有新动静时结束"
			story.show_page("阶段记录已交 / 继续值守","当前：%s\n%s\n\n你可以继续值守，也可以先复查现场。值守只到下一项现场变化，不会替你取证。"%[game.director.hhmm(game.director.now()),description],[[button,func():begin_wait(target)],["查看当班工作单",order_page],["先去复查",story.close_page]])
			return
		story.show_page("现场仍在变化",String(next[1])+"\n\n先听完现场对白或等来客坐稳，再继续值守。")
		return
	if base.id=="c1_terminal" and base.get("mode","")!="wait" and required_work_done():
		story.submit_shift();return
	var current:Dictionary=story.current_goal()
	story.show_page("当班工作 / 尚有现场事项",ORDERS[story.night_number()-1][0]+"\n\n下一项："+String(current.text)+"\n"+String(current.why)+"\n\n查到的材料已经保留；不要把未知填成已完成。",[["返回现场处理",story.close_page],["重读当班工作单",order_page]])

func begin_wait(target:float) -> void:
	var next:Array=story.next_event()
	var pending:Dictionary=story.pending_event()
	if pending.is_empty() or next[1]!=pending.label:return
	# Revalidate the target; stale UI callbacks cannot skip a newly pending event.
	wait_target=maxf(story.lc.t,float(pending.at)*60)
	if not is_equal_approx(target,wait_target):open_counter();return
	wait_from=story.lc.t;wait_elapsed=0
	story.show_page("继续值守","",[["取消值守，返回现场",story.close_page]])
	waiting=true
	refresh_wait()

func refresh_wait() -> void:
	var shown=lerpf(wait_from,wait_target,clampf(wait_elapsed/1.6,0,1))
	story.body.text="柜台 · 灯下的巡检单\n\n%s → %s\n\n已完成的工作留档。等待下一项现场变化……\nEsc 可取消；完成前不写入目标时间。"%[game.director.hhmm(1420+shown/60),game.director.hhmm(1420+wait_target/60)]

func close_activity() -> void:
	waiting=false
	if glass!=null:glass.close()

func _process(delta:float) -> void:
	if clipboard!=null:
		var text="夜班工作单\n第%d夜 · 留存联"%story.night_number()
		if clipboard.text!=text:clipboard.text=text
	if not waiting:return
	if game.state=="paused":return
	if game.state!="case_reader" or not story.modal.visible:waiting=false;return
	wait_elapsed+=delta;refresh_wait()
	if wait_elapsed<1.6:return
	var target=wait_target
	waiting=false;story.close_page()
	story.lc.t=maxf(story.lc.t,target)
	game.clock_min=game.director.now()
	story.lc._timeline();story.update_objective()

func interact(id:String) -> bool:
	match id:
		"lb_booth":order_page() if not received() else open_counter()
		"c1_terminal":open_counter()
		"l_m3":
			if not received():story.blocked("l_m3","尚未接班","当班工作单还没有签收。","先到1F传达室签收工作单，或在2F柜台领取留存联。")
			elif story.flag("glass_checked"):story.show_page("三号机 / 已巡检","外侧已经擦净，手印留在玻璃内侧。巡检结果已保留，无需反复擦拭。")
			else:
				story.show_page("三号机 / 外侧清洁","")
				story.modal.get_child(1).visible=false
				glass.open()
		"c1_broadcast":broadcast_page()
		"c1_bag_check":bag_page()
		"c1_towel":
			if story.lc.fired.has("beat14"):
				story.mark("duty_towel_read")
				story.show_page("停电后的毛巾","湿了就得擦。纸泡开，就认不出字了。\n\n背面旧绣字：秀兰。\n与留存洗衣单上的周秀兰相互对应，已经写入巡检记录。")
			else:story.show_page("长椅","毛巾还没有出现。先完成眼前的巡检。")
		_:return false
	return true

func broadcast_page() -> void:
	if not story.lc.fired.has("bc1"):
		story.show_page("广播巡检","广播尚未响起。先做当班工作，阶段完成可到柜台继续值守。")
	elif not story.flag("duty_broadcast1"):
		story.show_page("第一遍 / 广播抄录","00:01\n夜间请勿使用七号机。\n\n按原句抄录，不先猜测原因。",[["抄录到巡检单",func():story.mark("duty_broadcast1");story.close_page()]])
	elif story.lc.fired.has("bc2") and not story.flag("duty_broadcast2"):
		story.show_page("第二遍 / 与原句核对","记事本 00:01：夜间请勿使用七号机。\n广播 00:20：夜间勿使用七号机。\n\n差异是什么？",[["少了“请”字，记录原句差异",func():story.mark("duty_broadcast2");story.show_page("广播差异已登记","不是机器故障提示。第二遍少了一个“请”字。\n\n巡检单已留底，接下来到柜台继续值守，准备为来客登记未取衣。")],["七号机可以启用了",func():story.show_page("重新核对","两遍都写了“勿使用”。缺的是哪个字？\n第一遍在记事本里，没有丢失。",[["重新对照",broadcast_page],["收起",story.close_page]])]])
	else:story.show_page("广播记录","00:01　夜间请勿使用七号机。\n00:20　夜间勿使用七号机。\n\n两遍原句与差异已经保留。")

func bag_page() -> void:
	if not story.lc.fired.has("oldlady"):
		story.show_page("取衣登记","来客尚未到店。先做巡检。")
	elif not story.flag("met_lady"):
		story.show_page("先问清需求","先与长椅上的来客交谈，再查看她的布袋。")
	else:
		story.show_page("核对布袋 / 未取衣登记","袋口露出五件叠衣。她的手停在空出来的位置。\n\n留存单：七号机，童装一套，未取。\n七号机：上锁，原衣尚未取出。\n\n怎样填写当前交接状态？",[["现有五件；未取原衣另记待查",func():story.mark("duty_bag_logged");story.close_page();game.feedback.notify("取衣需求已登记","五件已在布袋；未取的一件仍待核实。可到柜台继续值守。")],["六件已齐，写成已经交还",func():story.show_page("数量对不上","原衣还在锁住的七号机里，不能填“已交还”。\n先按袋中实物与未取单重新登记。",[["重新核对",bag_page],["收起",story.close_page]])]])

func spots() -> Array:
	return [{"id":"c1_bag_check","pos":Vector3(1.42,4.15,6.25),"r":2.2,"label":"核对布袋与未取衣登记"}]

func event_blocked() -> bool:
	if story.night_number()!=1 or story.flag("recognized"):return false
	var event:Dictionary=story.pending_event()
	match String(event.get("id","")):
		"bc1":return not (received() and story.flag("glass_checked") and story.flag("examined_slip"))
		"bc2":return not story.flag("duty_broadcast1")
		"oldlady":return not story.flag("duty_broadcast2")
		"beat13":return not story.flag("duty_bag_logged")
		"count":return not story.flag("duty_towel_read")
	return false

func restore_legacy(data:Dictionary) -> void:
	close_activity()
	# A legacy mid-shift save has no work-order flags. Preserve its accomplished
	# investigation rather than forcing new chores into an already submitted shift.
	var flags:Dictionary=data.get("flags",{})
	if not flags.has("duty_version") and (story.flag("signed") or story.night_number()>1):
		for n in range(1,story.night_number()+1):story.mark("duty_received_%d"%n)
		if story.night_number()>1 or story.flag("back_key") or bool(story.progress.rest_pending):
			for id in ["glass_checked","examined_slip","duty_broadcast1","duty_broadcast2","duty_bag_logged","duty_towel_read"]:story.mark(id)
	story.mark("duty_version")
	sync_glass()

func _build_props() -> void:
	var a=story.lc.art
	# Small paper at the existing counter, with no new movement blocker.
	a.bev(Vector3(-2.34,4.605,7.93),Vector3(.285,.014,.31),a.plain(Color("655748")),.003)
	a.box(Vector3(-2.336,4.614,7.93),Vector3(.254,.004,.275),a.plain(Color("cec5aa")),false)
	a.box(Vector3(-2.449,4.62,7.93),Vector3(.023,.012,.102),a.plain(Color("70716b"),.67,.43),false)
	clipboard=a.label("",Vector3(-2.402,4.625,7.93),.0125,Color("3c463b"),PI/2,44)
	clipboard.rotate_object_local(Vector3.RIGHT,-PI/2)
	clipboard.no_depth_test=false
	clipboard.alpha_cut=Label3D.ALPHA_CUT_DISCARD
	for i in range(4):
		a.box(Vector3(-2.355+i*.032,4.618,7.93),Vector3(.002,.001,.188),a.plain(Color("8d8c78"),.95),false)
	var mat=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture=preload("res://scripts/shift_surface.gd").palm();mat.roughness=.6
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	var mesh=QuadMesh.new();mesh.size=Vector2(.38,.38)
	print_mesh=MeshInstance3D.new();print_mesh.name="Machine3InsidePrint";print_mesh.mesh=mesh;print_mesh.material_override=mat
	story.lc.world.add_child(print_mesh);print_mesh.position=Vector3(-2.374,3.938,4.99);print_mesh.rotation.y=PI/2
	sync_glass()

func sync_glass() -> void:
	if print_mesh!=null:print_mesh.visible=story.flag("glass_checked") or (glass!=null and glass.coverage()>=.8)
