extends SceneTree
var game
var lc
var story
var passed := 0
var failed := 0
var deadline := 0

func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("[PASS] ",message)
	else: failed += 1; print("[FAIL] ",message)

func _initialize() -> void:
	deadline = Time.get_ticks_msec()+90000
	call_deferred("run")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()>deadline:
		print("[FAIL] test timeout")
		quit(1)
	return false

func drain_dialogue() -> void:
	while story!=null and story.dialogue!=null and story.dialogue.panel.visible:
		story.dialogue.advance()

func close() -> void:
	drain_dialogue()
	game.audio_system.stop_voice()
	if story.modal.visible: story.close_page()
	game._clear_sub()

func act(id: String) -> void:
	close()
	if id=="c1_lady" and lc.night != null and lc.night.lady_state=="walk":lc.night._npc_step(6.1)
	lc.interact(id)
	drain_dialogue()

func clock_to(minutes: float) -> void:
	close()
	lc.t = minutes*60.0
	lc._timeline()
	game._clear_sub()

func rest_to_next() -> void:
	close()
	game._leave_laundry_to_town()
	game._step_laundry_to_town(game.LEAVE_FADE*2.0+.1)
	check(game.prologue_stage=="town" and game.case_mode=="","交班后到回潮镇街道")
	game.town_bridge.interact("02")
	check(game.prologue_stage=="room","从出租公寓入口回住处")
	game._prologue_act("case_rest")
	check(story.modal.visible and story.heading.text.contains("出租屋"),"床边可打开休息页")
	story.invoke(0)
	drain_dialogue()
	check(not bool(story.progress.rest_pending),"休息后进入下一夜，不连续驻守")
	game._prologue_act("door")
	game._step_exit_to_town(game.LEAVE_FADE*2.0+.1)
	game.town_bridge.interact("01")
	game._step_exit_to_laundry(game.LEAVE_FADE*2.0+.1)
	check(game.case_mode=="laundry" and game.state=="play","下一夜从街道重新进入洗衣店")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._hide_menu()
	game._start_prologue(false)
	# 自动化入口跳过可跳过的开场表演，沿真实接入接口进入。
	game.prologue_call_done = true
	game.prologue_letter_ready = true
	game.prologue_letter_read = true
	game.phone_ui.incoming = false
	game.bag_add("phone","手机","测试持有")
	game.field_kit.phone_owned = true
	game.bag_add("envelope","入职通知书","测试已读")
	game.field_kit.letter_accepted = true
	game._enter_laundry_from_room()
	game.set_process(false)
	game.player.set_physics_process(false)
	lc = game.laundry
	story = lc.campaign
	check(lc != null and story != null,"三夜导演已接入现有工程")
	check(story.night_number()==1,"新游戏第一夜")
	check(not lc.cast.aqi.visible and not lc.cast.xiulan.visible,"第一夜无提前出场的阿七和童年替身")
	check(lc.pick_ending()=="A","只有固定认领结局")
	lc.choose_final("B")
	check(lc.selected_ending=="","旧抹平入口失效")
	lc.choose_final("C")
	check(lc.selected_ending=="","旧顶替入口失效")
	act("lb_booth")
	act("l_price")
	act("l_m7")
	check(story.flag("signed"),"签入交接簿")
	act("l_m9")
	check(lc.has_clue("slip") and game.bag_has("slip"),"未取洗衣单入包可重读")
	clock_to(240)
	check(lc.lady!=null and not lc.final_open and game.choice==null,"03:40仍自由调查，无结局选择菜单")
	act("c1_lady")
	check(story.flag("back_key"),"老妇人交外门钥匙")
	act("l_m7")
	check(not lc.has_clue("sweater"),"外门钥匙不能开七号机")
	act("l_backdoor")
	act("l_sign")
	act("c1_terminal")
	story.invoke(0)
	drain_dialogue()
	check(bool(story.progress.rest_pending),"第一夜登记续查")
	check(int(story.progress.earnings)==800 and int(story.progress.rent_due)==1360,"首夜800工资与1360余租")
	check(not game.bag_has("permcard") and lc.selected_ending=="","首夜不升权、不结案")
	act("c1_terminal")
	check(int(story.progress.earnings)==800,"重复交班不重复发工资")
	rest_to_next()
	check(story.night_number()==2 and lc.t<60,"第二夜重置时间保留线索")
	check(lc.has_clue("slip"),"跨夜保留洗衣单")
	act("l_locked_402")
	story.invoke(0)
	drain_dialogue()
	check(story.flag("zhou_open") and game.bag_has("mail_key"),"两短一长和洗衣单打开老周对话")
	act("c1_drawer")
	act("c1_photo")
	act("c1_cert")
	act("c1_homework")
	act("c1_stones")
	check(lc.has_clue("marriage") and lc.has_clue("photo") and lc.has_clue("cert"),"303、304身份材料齐备")
	act("lb_box503")
	act("c1_mail_letter")
	check(lc.has_clue("return_card") and lc.has_clue("discharge"),"信箱退件卡引到医院挂号件")
	act("l_locked_402")
	check(lc.has_clue("testimony") and lc.has_clue("pipe_map"),"医院材料换取口述与管线图")
	act("c1_tools")
	act("l_locked_503")
	check(not story.flag("503_open"),"信箱钥匙不打开503房门")
	# 第二夜允许提前找到原衣，但不能提前结案。
	act("c1_keybox")
	act("l_m7")
	check(lc.has_clue("sweater"),"允许第二夜提前取到原衣")
	story.claim()
	check(lc.selected_ending=="","提前取原衣不跳过第三夜核实")
	clock_to(240)
	act("c1_lady")
	check(story.flag("name_told"),"向周秀兰说出小满姓名")
	act("c1_terminal")
	story.invoke(0)
	drain_dialogue()
	check(int(story.progress.earnings)==1600 and int(story.progress.rent_due)==560,"第二夜工资独立结算")
	close()
	game.player.cam_mode=2
	var saved: Dictionary = JSON.parse_string(JSON.stringify(preload("res://scripts/case_save.gd").capture(game)))
	check(preload("res://scripts/case_save.gd").valid(saved),"跨夜现场可保存")
	check(int(saved.laundry.campaign.night)==2 and saved.laundry.campaign.rest_pending,"存档包括夜次和待休息状态")
	rest_to_next()
	check(story.night_number()==3,"第三夜到岗")
	act("c1_roof_copy")
	act("c1_roof_patch")
	act("c1_lady")
	check(lc.selected_ending=="","复制品不能代替原衣结案")
	story.power_action(2)
	check(int(story.progress.power)==0,"未隔离先送泵只跳闸，不死亡")
	story.power_action(1)
	story.power_action(2)
	check(int(story.progress.power)==2,"隔离再接独立泵")
	act("c1_sandal")
	check(not lc.has_clue("sandal"),"危险水域取证前必须排水放梯")
	act("c1_valve")
	act("c1_notice")
	act("c1_waterline")
	act("c1_ladder")
	act("c1_sandal")
	check(lc.has_clue("sandal"),"排水后放梯取到童鞋")
	act("l_boiler")
	act("c1_accident")
	check(lc.has_clue("accident"),"口述与现场相互核实")
	check(story.ready_to_claim(),"第三夜证据齐备才可认领")
	clock_to(10000)
	check(not lc.ended and lc.t<=260*60,"超过时限保留调查，不进坏结局")
	act("c1_lady")
	story.invoke(0)
	drain_dialogue()
	check(lc.selected_ending=="A" and story.flag("recognized"),"交还第六件自动完成唯一认领")
	check(not game.bag_has("sweater") and game.bag_has("sweater_record"),"原衣交还后不重复持有，保留证据记录")
	story.invoke(0)
	drain_dialogue()
	for minute in [255,256,258,260,261,262]: clock_to(minute)
	check(game.state=="case_end" and lc.ended,"三夜到第一案正式结束")
	check(lc.fired.has("aqi_line") and lc.cast.aqi.visible,"录名之后阿七正面出现")
	check(game.hud_end.text.contains("去向未明"),"结案保留小满去向未明")
	check(int(story.progress.earnings)==2400 and int(story.progress.rent_due)==0 and int(story.progress.spare)==240,"三夜2400，欠租清零，余240新收入")
	check(game.bag_has("address") and game.bag_has("permcard"),"福利院地址与录名卡入包")
	var completed_save: Dictionary = JSON.parse_string(JSON.stringify(preload("res://scripts/case_save.gd").capture(game)))
	# 恢复第二夜待休息存档，确认第三夜结果不会污染旧现场。
	check(preload("res://scripts/case_save.gd").restore(game,saved),"恢复第二夜现场")
	lc = game.laundry; story = lc.campaign
	check(story.night_number()==2 and lc.selected_ending=="" and int(story.progress.earnings)==1600,"读档还原夜次、工资和未结案状态")
	check(lc.has_clue("sweater") and not lc.f2.sweater.visible,"提前拾取的原衣读档不重现")
	check(game.player.cam_mode==2,"读档保留第二人称视角")
	check(preload("res://scripts/case_save.gd").restore(game,completed_save),"结案现场可通过JSON读档恢复")
	lc=game.laundry; story=lc.campaign
	check(game.state=="case_end" and int(story.progress.earnings)==2400,"结案读档不重复发工资或重开调查")
	game._discard_laundry()
	game.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d passed / %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
