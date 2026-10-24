extends Node
## 案件只保存取证与行动；钟始终由原director/controller提供。
signal progress_changed
signal request_departure
signal exit_requested
signal completed(summary: Dictionary)

const DATA := preload("res://scripts/case2/case2_dialogue_data.gd")
const REQUIRED_FLAGS := ["register_matched","meter_recorded","meal_examined","note_borrowed","lived","wage_matched","schedule_seen","he_confirmed","corridor_complete","hospital_seen","assist_history","memory_shared","leak_isolated","witness9","archive_approved","plaque_hung","source_closed","joint_signed","name_returned"]
var game
var world
var dialogue
var investigation
var progress: Dictionary = {"version":1,"active":false,"phase":"offered","flags":{},"evidence":{},"steps":0,"completed":false}
var modal: Control
var reader_panel: Panel
var heading: Label
var body: RichTextLabel
var action_box: VBoxContainer
var actions: Array = []
var return_state := "play"
var last_goal_key := ""
var idle := 0.0
var idle_hint_stage := 0

func setup(g, w = null) -> void:
	game = g
	world = w
	_build_reader()
	dialogue = preload("res://scripts/spoken_dialogue.gd").new()
	add_child(dialogue)
	dialogue.setup(game)
	investigation = preload("res://scripts/case2/case2_investigation.gd").new()
	modal.add_child(investigation)
	investigation.setup(self)
	get_viewport().size_changed.connect(_fit_reader)

func begin() -> void:
	if bool(progress.active): return
	progress.active = true
	progress.phase = "cooperation"
	_changed()

func bind_world(w) -> void:
	world = w
	_sync_world()

func flag(id: String) -> bool:
	return bool(progress.flags.get(id, false))

func has_evidence(id: String) -> bool:
	return bool(progress.evidence.get(id, false))

func mark(id: String) -> void:
	if flag(id): return
	progress.flags[id] = true
	progress.steps = int(progress.steps) + 1
	_changed()

func _changed() -> void:
	idle = 0.0
	idle_hint_stage = 0
	_sync_world()
	_update_phase()
	update_objective()
	progress_changed.emit()

func _update_phase() -> void:
	if flag("case_complete"): progress.phase = "complete"
	elif flag("source_closed"): progress.phase = "joint_archive"
	elif flag("archive_approved"): progress.phase = "settlement"
	elif flag("seventeen_open"): progress.phase = "seventeenth"
	elif flag("arrived"): progress.phase = "residence"
	elif flag("orphanage_done"): progress.phase = "departure"
	elif flag("coop_done"): progress.phase = "orphanage"
	else: progress.phase = "cooperation"

func _sync_world() -> void:
	var opened := flag("meter_recorded") and flag("lived") and flag("he_confirmed")
	if opened: progress.flags["seventeen_open"] = true
	if not is_instance_valid(world): return
	if world.has_method("set_anomaly_open"): world.set_anomaly_open(opened)
	if world.has_method("set_resolved"): world.set_resolved(flag("source_closed"))
	if world.has_method("sync_campaign"): world.sync_campaign(progress)

func spots() -> Array:
	if not is_instance_valid(world): return []
	if world.has_method("get_spots"): return world.get_spots()
	return []

func on_arrival() -> void:
	mark("arrived")
	if not flag("arrival_talk"):
		speak("arrival", func(): mark("arrival_talk"))
	else: update_objective()

func _build_reader() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 35
	add_child(layer)
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(modal)
	game.field_kit.shade(modal)
	reader_panel = game.phone_ui.box(modal, Vector2(200,70), Vector2(1200,760), Color("1b1c19"), 4)
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 30
	stack.offset_top = 28
	stack.offset_right = -30
	stack.offset_bottom = -24
	stack.add_theme_constant_override("separation",14)
	reader_panel.add_child(stack)
	var subtitle := Label.new()
	subtitle.text = "案卷 00201  /  十七楼的水表  /  阅读期间时间暂停"
	subtitle.add_theme_font_override("font",game.font)
	subtitle.add_theme_font_size_override("font_size",18)
	subtitle.modulate = Color("bca77c")
	stack.add_child(subtitle)
	heading = Label.new()
	heading.add_theme_font_override("font",game.font)
	heading.add_theme_font_size_override("font_size",30)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(heading)
	body = RichTextLabel.new()
	body.add_theme_font_override("normal_font",game.font)
	body.add_theme_font_size_override("normal_font_size",23)
	body.add_theme_color_override("default_color",Color("ddd5c3"))
	body.add_theme_constant_override("line_separation",9)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.bbcode_enabled = false
	stack.add_child(body)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation",8)
	stack.add_child(action_box)
	modal.visible = false

func show_page(title: String, text: String, buttons: Array = []) -> void:
	if investigation != null: investigation.close()
	if not modal.visible:
		return_state = game.state if game.state in ["play","prologue"] else "play"
		if game.phone_open: game._close_phone()
		if game.bag_open: game.field_kit.open_inventory(false)
		game._clear_sub()
	game.audio_system.stop_voice()
	game.state = "case2_read"
	game.player.can_move = false
	game.player.allow_capture = false
	game.player.dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modal.visible = true
	reader_panel.visible = true
	heading.text = title
	body.text = text
	body.scroll_to_line(0)
	actions = buttons.duplicate()
	for child in action_box.get_children():
		action_box.remove_child(child)
		child.queue_free()
	if actions.is_empty(): actions = [["收起，继续调查",close_page]]
	for i in range(actions.size()):
		var button := Button.new()
		button.text = "%d  ·  %s" % [i+1,actions[i][0]]
		button.custom_minimum_size = Vector2(0,47)
		button.add_theme_font_override("font",game.font)
		button.add_theme_font_size_override("font_size",20)
		button.add_theme_stylebox_override("normal",game.phone_ui.style(Color("304c45"),5,Color("6e806c")))
		button.pressed.connect(func(): invoke(i))
		action_box.add_child(button)
	_fit_reader()

func invoke(index: int) -> void:
	if index >= 0 and index < actions.size():
		var callback: Callable = actions[index][1]
		callback.call()

func _fit_reader() -> void:
	var area := get_viewport().get_visible_rect().size
	var factor := minf(area.x/1600.0,area.y/900.0)
	reader_panel.scale = Vector2.ONE*factor
	reader_panel.position = (area-reader_panel.size*factor)*0.5

func close_page() -> void:
	if investigation != null: investigation.close()
	modal.visible = false
	reader_panel.visible = true
	game.audio_system.stop_voice()
	game.state = return_state if return_state in ["play","prologue"] else "play"
	game.player.can_move = true
	game.player.allow_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	update_objective()

func speak(id: String, callback: Callable = Callable()) -> void:
	if modal.visible: close_page()
	var sequence: Array = DATA.lines(id)
	if sequence.is_empty():
		if callback.is_valid(): callback.call()
		return
	# Each line has its own generated clip. Never reuse a different character's
	# old dialogue as a substitute, or tell the audio player to load a missing file.
	for i in range(sequence.size()):
		var voice_id := "c2_%s_%02d" % [id,i]
		if ResourceLoader.exists("res://assets/audio/case2/"+voice_id+".wav"):
			sequence[i].append(voice_id)
	dialogue.play(sequence,callback)

func doc(id: String, show := true) -> void:
	if not DATA.DOCS.has(id): return
	var data: Array = DATA.DOCS[id]
	if not has_evidence(id):
		progress.evidence[id] = true
		game.bag_add(id,String(data[0]),String(data[1]),"物")
		game.note("物",String(data[0]),String(data[1]))
		game.audio_system.sfx("paper",-16)
	if show: show_page(String(data[0]),String(data[1]))

func inspect_item(id: String) -> bool:
	if not DATA.DOCS.has(id) or not has_evidence(id): return false
	doc(id)
	return true

func open_workbench(id: String) -> void:
	show_page("现场调查", "")
	investigation.open(id)

func blocked(id: String, reason: String, next_step: String, cue := "device_blocked") -> void:
	var at: Vector3 = game.player.global_position + Vector3(0,0.7,0)
	if is_instance_valid(world) and world.has_method("get_anchor"): at = world.get_anchor(id)
	game.feedback.blocked(id,"现场暂未就绪",reason,next_step,at,cue)
	idle = 0.0

func interact(id: String) -> bool:
	if not id.begins_with("c2_"): return false
	if not bool(progress.active): return false
	idle = 0.0
	match id:
		"c2_aqi":
			if not flag("coop_done"): speak("invitation",func():
				mark("coop_done")
				game.director.send_once("c2_coop","阿七","七，工牌上就剩这个。归还的地址先去门外核对；别替我编姓。"))
			elif flag("source_closed") and not flag("joint_signed"): _joint_archive()
			elif flag("joint_signed") and not flag("name_returned"): _return_name()
			elif flag("corridor_complete") and not flag("assist_history"): speak("four_times",func():
				mark("assist_history")
				doc("c2_assist_history",false))
			elif flag("assist_history") and not flag("memory_shared"): speak("memory",func():
				mark("memory_shared")
				doc("c2_shared_memory",false)
				game.director.send_once("c2_memory","阿七","三十一块四，缺角的桌子，放平的手机。我记着；你也替我记住那盏站台灯。"))
			elif not flag("orphanage_done"): show_page("合作记录","阿七在门边等你。沿街道去向阳福利院旧址，核对归还地址与旧门牌。")
			else: show_page("互相保管的记录",String(DATA.DOCS["c2_shared_memory"][1]) if flag("memory_shared") else "你看到表数，我看到文字。两边都记下来，不替对方猜。")
		"c2_orphanage":
			if not flag("coop_done"): blocked(id,"还未与门外的人确认同行。","先回出租屋门边与临-07交谈。")
			elif flag("orphanage_done"): doc("c2_address_photo")
			else: open_workbench("address")
		"c2_depart":
			if not flag("orphanage_done"): blocked(id,"还给你的地址尚未核对。","先去向阳福利院旧址比对门牌，再沿铁路道口出镇。")
			else:
				mark("departed")
				request_departure.emit()
		"c2_exit":
			cancel()
			exit_requested.emit()
		"c2_register": open_workbench("registration")
		"c2_master_meter":
			if not flag("register_matched"): blocked(id,"尚不清楚异常记在哪份账上。","先核对值守室三份同楼栋材料。")
			elif not flag("meter_talk"): speak("meter",func():
				mark("meter_talk")
				open_workbench("meter"))
			else: open_workbench("meter")
		"c2_hebo": _talk_he()
		"c2_he_door":
			if not flag("meter_recorded"): blocked(id,"何伯还未带你查看他的生活。","先在一楼完成总表的并列记录。")
			else: show_page("何伯的门口","何伯同意你检查锅、碗和门背日历。发现可核对的便条时，先询问再暂借。")
		"c2_porridge","c2_calendar":
			if not flag("meter_recorded"): blocked(id,"何伯还在核对水费，尚未带你查看他的生活。","先在一楼把两人的水表记录并列，标出额外支路。")
			elif flag("meal_examined"): doc("c2_calendar")
			else: open_workbench("meal")
		"c2_note":
			if not flag("meal_examined"): blocked(id,"便条属于何伯，不能未经询问取走。","先检查锅、碗与照护日历，并请何伯暂借便条。")
			else:
				mark("note_borrowed")
				doc("c2_note")
		"c2_storage","c2_bed":
			if not flag("meter_recorded"): blocked(id,"先确认哪一段生活记录正在消失。","到一楼总表记录两人的不同读数。")
			elif flag("lived"): doc("c2_lived")
			else: open_workbench("living")
		"c2_wage":
			if not flag("note_borrowed"): blocked(id,"工资单叠在旧件中，尚无可比对的署名依据。","借何伯门背的便条，再到十六楼比对笔迹。")
			else: open_workbench("handwriting")
		"c2_schedule":
			mark("schedule_seen")
			doc("c2_schedule")
		"c2_corridor","c2_delivery":
			if not flag("seventeen_open"): blocked(id,"十六楼上方仍是封闭的维修门。","核对额外支路、生活痕迹，并请何伯确认；这三件事齐全才会出现新的入口。")
			elif not flag("sun_met"): speak("sun_first",func(): mark("sun_met"))
			elif not flag("schedule_seen"): blocked(id,"门后的请求重叠，不能靠乱试分出顺序。","回十六楼找布帘旁的照护排班单，记录她平常走的顺序。")
			else: open_workbench("corridor")
		"c2_sun":
			if flag("source_closed"): show_page("床头灯","桶已经放下。她不会再回来继续接住户的请求。")
			elif flag("plaque_hung"): show_page("等待最后的水停下","旧牌已挂好，核定已经完成。按管线图关闭异常支管源阀。")
			else: interact("c2_corridor")
		"c2_luggage","c2_hospital":
			if not flag("corridor_complete"): blocked(id,"旧夹层被排班单背板卡住，还不能确认它为何留下。","先看十七楼送物顺序，再回十六楼检查未收完的行李。")
			elif flag("hospital_seen"): doc("c2_hospital")
			else:
				show_page("夹层里的退件","行李只收了一半。住院单日期与门背便条最后一天相同，姓名与工资单署名一致。\n\n这张退件还不能独自解释她后来去了哪里。联系何伯，把日期和亲历经过再核对一次。",[["联系何伯核对",func(): speak("hospital_confirm",func():
					mark("hospital_seen")
					doc("c2_hospital",false))],["先收起，稍后再核对",close_page]])
		"c2_recorder": show_page("录音机的普通留言","何师傅，药放门边了。明早您别空着肚子吃。\n\n留言的日期与照护日历一致。声音证明一次照护，完整姓名仍须核对署名。")
		"c2_pipe_map": show_page("共用管线图","市政进水→总表→现实1—16F分户。\n公共附属管另有墙根漏水段与未编号上行支路。\n\n先隔离实际漏水段；异常源阀必须等身份、生活与关系材料核定，再按图关闭。")
		"c2_intercom":
			if not flag("wage_matched"): blocked(id,"只能问“以前那个人”，住户无法确认同一对象。","先将便条与工资单笔迹核对，取得可确认的署名。")
			elif not flag("lived"): blocked(id,"只问工作不能证实她曾住在楼里。","先核对十六楼布帘后的个人生活用品。")
			elif flag("witness9"): doc("c2_witness9")
			else: speak("witness9",func():
				mark("witness9")
				doc("c2_witness9",false))
		"c2_valves": _valve_interact()
		"c2_dispatch": _dispatch_interact()
		"c2_plaque":
			if not flag("archive_approved"): blocked(id,"不能先挂姓名来代替核验。","先向派遣终端提交署名、生活物证和两位独立证词。")
			elif flag("plaque_hung"): show_page("旧门牌已挂回","旧牌说明孙素琴曾在十六楼生活；十七楼只是被挤出来的关系。接下来关闭异常源阀。")
			else:
				mark("plaque_taken")
				game.bag_add("c2_old_plaque","16F附属用房旧牌","旧牌背后留着布帘钉孔。核定之后，将它挂在十七楼复现的休息处，保留她曾生活的事实。","物")
				show_page("旧门牌取下了","牌背面的布帘钉孔仍在。带到十七楼走廊尽头的休息处，挂在布帘旁。")
		"c2_rest_corner","c2_doorplate":
			if not flag("plaque_taken"): blocked(id,"床边没有可对应的旧门牌。","核定证据后去十六楼取旧牌，再挂到这里。")
			elif not flag("plaque_hung"):
				mark("plaque_hung")
				_remove_item("c2_old_plaque")
				game.audio_system.sfx("ui_tap",-15)
				speak("settle")
			else: show_page("终于能休息的地方","旧牌留在布帘旁。事实已核定，再到十七楼管线柜关闭异常源阀。")
		"c2_lift_1","c2_lift_8","c2_lift_16","c2_lift_17","c2_lift": _lift_page()
		_: return false
	update_objective()
	return true

func _talk_he() -> void:
	if flag("he_confirmed"):
		if flag("source_closed") and not flag("note_returned"):
			mark("note_returned")
			_remove_item("c2_note")
			show_page("相框里的便条","何伯取回便条，装进相框。他仍记得孙素琴，也知道她不会再来送药。\n\n证据复印记录保留在案卷中，关系没有随水路一起消失。")
		else: doc("c2_he_testimony")
	elif flag("lived") and flag("meal_examined") and flag("note_borrowed"):
		speak("he_confirm",func():
			mark("he_confirmed")
			doc("c2_he_testimony",false)
			_sync_world())
	elif flag("meal_examined"):
		speak("meal",func():
			mark("note_borrowed")
			doc("c2_note",false))
	else: speak("arrival",func(): mark("arrival_talk"))

func _valve_interact() -> void:
	if flag("source_closed"):
		show_page("异常支路已关闭","现实十六层供水保留，关联生活记录没有注销。接下来请阿七一起签处置回执。")
	elif flag("plaque_hung"): open_workbench("source_valve")
	elif not flag("memory_shared"):
		blocked("c2_valves","控制盘附注与表盘分属两人的感知，不能独自推断。","完成十七楼送物调查后，与阿七核对四次派遣，并互相保管一段记忆。")
	elif not flag("valve_warned"):
		speak("valve_warning",func():
			mark("valve_warned")
			open_workbench("isolation"))
	elif flag("leak_isolated"): doc("c2_pipeline")
	else: open_workbench("isolation")

func _dispatch_interact() -> void:
	if flag("joint_signed"):
		if not flag("name_returned"): _return_name()
		else: doc("c2_joint_receipt")
	elif flag("source_closed"): _joint_archive()
	elif flag("archive_approved"): doc("c2_residence_record")
	elif not _archive_ready():
		var missing: Array[String] = []
		for row in [["wage_matched","署名工资单与笔迹"],["lived","十六楼个人生活物证"],["schedule_seen","照护排班"],["he_confirmed","何伯亲历证词"],["witness9","九楼独立住户证词"],["hospital_seen","退回住院单与经历"],["leak_isolated","保护住户的漏水隔离"]]:
			if not flag(String(row[0])): missing.append(String(row[1]))
		show_page("本案材料仍需补查","核定前不改总档。尚缺：\n• "+"\n• ".join(missing)+"\n\n按H可查看眼前一步。原件可以重读，错误分类可放回重排。")
	else: open_workbench("archive")

func _archive_ready() -> bool:
	for key in ["wage_matched","lived","schedule_seen","he_confirmed","witness9","hospital_seen","leak_isolated"]:
		if not flag(key): return false
	return true

func _joint_archive() -> void:
	if not flag("source_closed"): return
	if not flag("assist_history") or not flag("memory_shared"):
		blocked("c2_aqi","共同处置附件未核对。","和阿七补齐口述与现场协作记录。")
		return
	speak("joint",func():
		mark("joint_signed")
		doc("c2_joint_receipt",false)
		game.director.send_once("c2_joint_receipt","派遣科","00201共同处置材料已复核。许砚：掌册。临-07：正式协助留档，权限仍未录名。工资依本案结算单核发，金额待核。"))

func _return_name() -> void:
	if not flag("joint_signed") or flag("name_returned"): return
	speak("name",func():
		mark("name_returned")
		doc("c2_returned_name",false)
		mark("case_complete")
		progress.completed = true
		game.director.send_once("c2_bus_teaser","派遣科","00212，末班4路。请于末班发车前到回潮镇老公交站。本条仅为下一份派遣，不要求现在继续夜班。")
		completed.emit(summary()))

func _lift_page() -> void:
	if not is_instance_valid(world): return
	var options: Array = []
	for floor_number in [1,8,16,17]:
		if floor_number == 17 and not flag("seventeen_open"): continue
		var floor_value: int = floor_number
		options.append(["前往 %dF" % floor_value,func(): _take_lift(floor_value)])
	options.append(["不乘坐，沿实体楼梯调查",close_page])
	show_page("电梯 · 申报最高16F" if not flag("seventeen_open") else "电梯 · 16F与关门键间多出一行","1F 值守与总表  /  8F 何伯  /  16F 公共储物间\n"+("17F 关系走廊，楼梯上半层也可到达。" if flag("seventeen_open") else "电梯没有跳过证据的按钮。高层可乘梯，沿途实体楼梯始终可返回。"),options)

func _take_lift(floor_number: int) -> void:
	if floor_number == 17 and not flag("seventeen_open"):
		blocked("c2_lift_17","没有十七楼按钮。","先核对支路与储物间关系。")
		return
	if not is_instance_valid(world) or not world.has_method("get_floor_spawn"): return
	close_page()
	game.audio_system.sfx("door",-18)
	game.player.global_position = world.get_floor_spawn(floor_number)
	game.player.velocity = Vector3.ZERO
	if game.player.has_method("reset_physics_interpolation"): game.player.reset_physics_interpolation()
	game.feedback.notify("%dF · 电梯到达" % floor_number,"走出轿厢继续调查；按H查看当前目标。")

func investigation_complete(id: String) -> void:
	match id:
		"address":
			mark("orphanage_done")
			doc("c2_address_photo",false)
			doc("c2_dispatch_order",false)
			game.director.send_once("c2_order","派遣科",String(DATA.DOCS["c2_dispatch_order"][1]))
			close_page()
			speak("address")
		"registration":
			mark("register_matched")
			doc("c2_registration",false)
		"meter":
			mark("meter_recorded")
			doc("c2_meter_record",false)
			game.director.send_once("c2_meter_transcript","阿七","你看到数字，我看到规则。未分配住户用量，摊入已登记户。文字转述永久留在聊天里；照片对你仍是数字。")
		"meal":
			mark("meal_examined")
			doc("c2_calendar",false)
			close_page()
			speak("meal",func():
				mark("note_borrowed")
				doc("c2_note",false))
		"living":
			mark("lived")
			doc("c2_lived",false)
		"handwriting":
			mark("wage_matched")
			doc("c2_wage",false)
		"corridor":
			mark("corridor_complete")
			game.note("物","十七楼送物顺序","药袋→粥盒→脏床单，和十六楼排班吻合；每家都让她放门口，没有人叫她回自己的家。")
			game.director.send_once("c2_corridor_followup","阿七","先停一停，去十六楼看那份收拾到一半的行李。记录不会因你认真阅读而被拿走。")
		"isolation":
			mark("leak_isolated")
			doc("c2_pipeline",false)
			game.audio_system.sfx("valve_turn",-13)
		"archive":
			if not _archive_ready(): return
			mark("archive_approved")
			doc("c2_residence_record",false)
			game.director.send_once("c2_approved","派遣科","核定通过：孙素琴曾在此工作、生活并照护住户。允许按图关闭异常源阀；保留现实供水与关联记录。先挂回旧门牌。")
		"source_valve":
			if not flag("plaque_hung") or not flag("archive_approved"): return
			mark("source_closed")
			game.audio_system.sfx("valve_turn",-13)
			game.audio_system.sfx("water_recede",-18)
			game.note("物","第十七层停止供水","异常源阀关闭，总表日期不再倒退。十六层现实供水保留。孙素琴休息，住户仍记得她。")
			_sync_world()
	update_objective()

func _remove_item(id: String) -> void:
	for i in range(game.case_bag.size()-1,-1,-1):
		if String(game.case_bag[i].get("id","")) == id: game.case_bag.remove_at(i)
	if game.field_kit.held_id == id: game.field_kit.stow()

func _goal(id: String, text: String, why: String) -> Dictionary:
	return {"id":id,"text":text,"why":why,"mode":"act","key":"00201_"+id+"_"+text.sha256_text().left(10)}

func current_goal() -> Dictionary:
	if not flag("coop_done"): return _goal("c2_aqi","开门，与等在楼道的临-07确认同行。","上一案以后，她有一件事想当面核实。")
	if not flag("orphanage_done"): return _goal("c2_orphanage","去向阳福利院旧址门外，比对归还地址与旧门牌。","地址指向许砚自己的经历；不必进入未开放的院内。")
	if not flag("arrived"): return _goal("c2_depart","沿铁路道口出镇，前往槐安住宅。","新派遣00201：核定十六层住宅多出的一户用水。")
	if flag("case_complete"): return _goal("c2_exit","第二案已归档，可从一楼返回回潮镇。","许砚掌册；临-07留下正式协助记录。下一案仅收到派遣。")
	if flag("joint_signed"): return _goal("c2_aqi","与阿七打开归还密封页。","处置已记录；归还事项需要由许砚亲自查看。")
	if flag("source_closed"): return _goal("c2_aqi","与阿七一起签处置回执，列入协作附件。","她的口述规则、照片与撤离记录应当进入正式档案。")
	if flag("plaque_hung"): return _goal("c2_valves","到十七楼管线柜，沿图关闭异常源阀。","证据已经核定，现实供水和共同生活记录均应保留。")
	if flag("archive_approved"):
		if not flag("plaque_taken"): return _goal("c2_plaque","去十六楼布帘旁取下旧门牌。","核定说明她曾经住过；把旧牌带到她终于能休息的地方。")
		return _goal("c2_rest_corner","把旧门牌挂到十七楼尽头的布帘旁。","十七楼复现关系，不是新增合法产权；记录她曾经的一户。")
	if not flag("register_matched"): return _goal("c2_register","在一楼值守桌核对建筑登记、维保表与水费账。","先找到材料间的具体差异，不能直接给新增户填姓名。")
	if not flag("meter_recorded"): return _goal("c2_master_meter","检查一楼总表，留下两人的并列记录并标出额外支路。","许砚能看见数字，阿七能看见附注；用文字互相说明。")
	if not flag("meal_examined"): return _goal("c2_porridge","去八楼何伯门口，检查温粥、碗与照护日历。","总表跳字后，何伯忘记了一顿饭。确认失去的是什么。")
	if not flag("note_borrowed"): return _goal("c2_note","经何伯同意，暂借门背便条。","它没有完整署名，留待与别的材料核对。")
	if not flag("lived"): return _goal("c2_storage","去十六楼公共储物间，核对布帘后的生活物证。","没有住所登记，也可能确实有人一直生活。")
	if not flag("wage_matched"): return _goal("c2_wage","比对便条和早期工资单的笔迹，确认署名。","床铺证明生活，署名单据证明姓名与工作；不能混为一件事。")
	if not flag("schedule_seen"): return _goal("c2_schedule","查看十六楼布帘旁的照护排班单。","她平日的送物顺序能够解释多出来的走廊。")
	if not flag("he_confirmed"): return _goal("c2_hebo","回一楼，请何伯确认储物间与照护者的关系。","实物之外还需要住户的亲历确认。")
	if not flag("sun_met") or not flag("corridor_complete"): return _goal("c2_corridor","上十七楼，观察并按排班送完这一趟物件。","16F上半层出现入口；药、饭与床单都来自不同住户的要求。")
	if not flag("hospital_seen"): return _goal("c2_luggage","回十六楼检查夹层中未收完的行李与退回住院单。","她并不是凭空困在走廊，便条最后一天还有未完成的事。")
	if not flag("assist_history"): return _goal("c2_aqi","与阿七核对她四次未署名的派遣记录。","许砚只能读结论；经过需要由她自愿讲述。")
	if not flag("memory_shared"): return _goal("c2_aqi","和阿七互相保管一件确定经历过的小事。","脚步声被分到门后，先确认你们仍记得彼此。")
	if not flag("leak_isolated"): return _goal("c2_valves","到十七楼管线柜，先隔离漏水段，保留现实供水。","直接注销支路会连生活记录一起删除；不要用关总闸代替调查。")
	if not flag("witness9"): return _goal("c2_intercom","用一楼对讲机联系九楼，取得第二条独立关系证词。","何伯转述不能算两个人；用署名和生活细节核实同一对象。")
	return _goal("c2_dispatch","在一楼派遣终端，将署名、工作、生活与证词分类归档。","由派遣科核定后再处置，许砚不能自行修改总档。")

func objective() -> String:
	return String(current_goal().text)

func update_objective() -> void:
	if game == null or not bool(progress.active): return
	var goal: Dictionary = current_goal()
	if String(goal.key) == last_goal_key: return
	last_goal_key = String(goal.key)
	game.set_case_objective(String(goal.text))

func can_advance_time() -> bool:
	return bool(progress.active) and not bool(progress.completed) and not modal.visible and not dialogue.active

func clock_can_advance() -> bool:
	return can_advance_time()

func next_event() -> Array:
	var now: float = game.director.now() if game != null else 1200.0
	return [now, "先完成调查："+String(current_goal().text)]

func advance_to(_target_game_minutes: float) -> bool:
	# 本案所有恶化都依调查与现场动作推进；拨时不能替玩家取证或注销关系。
	if game != null: game.feedback.notify("当前事件需要现场调查",String(current_goal().text))
	return false

func step(delta: float) -> void:
	if not bool(progress.active) or bool(progress.completed): return
	if game.state not in ["play","prologue"] or game.phone_open or game.bag_open or game.nb_open or game.sub_pause or not game.sub.is_empty() or game.audio_system.is_busy(): return
	idle += delta
	if idle >= 45.0 and idle_hint_stage == 0:
		idle_hint_stage = 1
		game.feedback.notify("调查提示 · H随时查看",String(current_goal().why))
	if idle >= 90.0 and idle_hint_stage == 1:
		idle_hint_stage = 2
		game.director.send_once("c2_idle_"+String(current_goal().key),"阿七",String(current_goal().text)+" "+String(current_goal().why))

func show_help() -> void:
	var goal := current_goal()
	game.feedback.notify("00201 · 当前调查",String(goal.text)+"\n"+String(goal.why))
	idle = 0.0

func capture() -> Dictionary:
	return progress.duplicate(true)

func restore(data: Dictionary) -> bool:
	if int(data.get("version",0)) != 1: return false
	if typeof(data.get("flags")) != TYPE_DICTIONARY or typeof(data.get("evidence")) != TYPE_DICTIONARY: return false
	for container in [data.flags,data.evidence]:
		for key in container:
			if typeof(key) != TYPE_STRING or typeof(container[key]) != TYPE_BOOL: return false
	if typeof(data.get("active",false)) != TYPE_BOOL or typeof(data.get("completed",false)) != TYPE_BOOL: return false
	var step_value = data.get("steps",0)
	if typeof(step_value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(step_value)): return false
	if not _valid_dependencies(data.flags): return false
	for evidence_id in data.evidence:
		if not DATA.DOCS.has(evidence_id): return false
	var restored := {"version":1,"active":bool(data.get("active",false)),"phase":String(data.get("phase","offered")),"flags":data.flags.duplicate(true),"evidence":data.evidence.duplicate(true),"steps":maxi(0,int(data.get("steps",0))),"completed":bool(data.get("completed",false))}
	if bool(restored.completed) and not bool(restored.flags.get("case_complete",false)): return false
	cancel()
	progress = restored
	last_goal_key = ""
	_sync_world()
	_update_phase()
	update_objective()
	return true

func _valid_dependencies(flags: Dictionary) -> bool:
	var dependencies := {
		"orphanage_done":["coop_done"],"departed":["orphanage_done"],"arrived":["departed"],
		"register_matched":["arrived"],"meter_talk":["register_matched"],"meter_recorded":["register_matched"],
		"meal_examined":["meter_recorded"],"note_borrowed":["meal_examined"],"lived":["meter_recorded"],
		"wage_matched":["note_borrowed"],"he_confirmed":["lived","meal_examined","note_borrowed"],
		"seventeen_open":["meter_recorded","lived","he_confirmed"],"sun_met":["seventeen_open"],
		"corridor_complete":["sun_met","schedule_seen"],"hospital_seen":["corridor_complete"],
		"assist_history":["corridor_complete"],"memory_shared":["assist_history"],
		"valve_warned":["memory_shared"],"leak_isolated":["valve_warned","memory_shared"],
		"witness9":["wage_matched","lived"],"archive_approved":["wage_matched","lived","schedule_seen","he_confirmed","witness9","hospital_seen","leak_isolated"],
		"plaque_taken":["archive_approved"],"plaque_hung":["plaque_taken","archive_approved"],
		"source_closed":["plaque_hung","archive_approved"],"joint_signed":["source_closed","assist_history","memory_shared"],
		"name_returned":["joint_signed"],"case_complete":["name_returned"],"note_returned":["source_closed"],
	}
	for key in dependencies:
		if not bool(flags.get(key,false)): continue
		for prerequisite in dependencies[key]:
			if not bool(flags.get(prerequisite,false)): return false
	return true

func cancel() -> void:
	if dialogue != null: dialogue.cancel()
	if investigation != null: investigation.close()
	if modal != null: modal.visible = false
	actions.clear()
	if game != null: game.audio_system.stop_voice()

func summary() -> Dictionary:
	return {"case_id":"00201","title":DATA.TITLE,"ending":"A","completed":flag("case_complete"),"authority":"掌册","cooperator":"临-07","cooperator_recorded":false,"cooperator_assistance_record":flag("joint_signed"),"returned_name":"沈知远","player_display_name":"许砚","salary_amount":null,"salary_status":"依本案结算单待核","next_case":"00212","residents_remember":flag("source_closed"),"evidence_count":progress.evidence.size()}

func _input(event: InputEvent) -> void:
	if not bool(progress.active) or not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode
	if modal.visible and game.state == "case2_read":
		if key == KEY_ESCAPE:
			close_page()
		elif investigation != null and investigation.visible:
			return
		elif key >= KEY_1 and key <= KEY_9: invoke(key-KEY_1)
		elif key in [KEY_E,KEY_ENTER,KEY_SPACE]: invoke(0)
		else: return
		get_viewport().set_input_as_handled()
	elif key == KEY_H and game.state in ["play","prologue"] and not game.phone_open and not game.bag_open:
		show_help()
		get_viewport().set_input_as_handled()
