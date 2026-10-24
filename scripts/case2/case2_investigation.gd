extends Control
## 现场检查：实物热点、并列笔记、管线阀位、送物与档案拖放。
## 操作没有倒计时；错误只要求复查，不写入分支结局。
class EvidenceCard extends Panel:
	var owner_board
	var evidence_id := ""
	var title := ""
	func _get_drag_data(_at: Vector2):
		owner_board.select_card(evidence_id)
		var preview := Label.new()
		preview.text = title
		preview.add_theme_font_override("font",owner_board.story.game.font)
		preview.add_theme_font_size_override("font_size",23)
		set_drag_preview(preview)
		return {"c2_card":evidence_id}
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			owner_board.select_card(evidence_id)

class EvidenceSlot extends Panel:
	var owner_board
	var slot_id := ""
	func _can_drop_data(_at: Vector2, data) -> bool:
		return typeof(data) == TYPE_DICTIONARY and data.has("c2_card")
	func _drop_data(_at: Vector2, data) -> void:
		owner_board.place_card(String(data.c2_card),slot_id)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			owner_board.place_card(owner_board.selected_card,slot_id)

const TITLES := {"address":"归还地址 / 门牌比对","registration":"三份账 / 同栋逐栏核对","meter":"同一块表 / 两种读数","meal":"一顿没有被记住的饭","living":"布帘后 / 谁在这里生活","handwriting":"便条与工资单 / 笔迹核对","corridor":"把她的一趟送完","isolation":"管线操作 / 先保护现实住户","source_valve":"核定后 / 关闭异常源阀","archive":"00201 / 分栏核定材料"}
var story
var panel: Panel
var title: Label
var instructions: Label
var status: Label
var notes: RichTextLabel
var board: Control
var item_id := ""
var checked: Dictionary = {}
var placements: Dictionary = {}
var selected_card := ""
var selected_branch := ""
var valve_value := 0.0
var flipped := false
var completed_here := false
var pointer_phase := 0.0
var order_index := 0
var board_nodes: Array[Control] = []
var action_buttons: Array[Button] = []
var slider: HSlider

func setup(campaign) -> void:
	story = campaign
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ui = story.game.phone_ui
	panel = ui.box(self,Vector2(72,55),Vector2(1456,790),Color("1c211f"),5)
	ui.lab(panel,"现 场 调 查   /   00201",Vector2(30,21),Vector2(1000,30),17,Color("bea77d"))
	title = ui.lab(panel,"",Vector2(30,62),Vector2(1360,48),30)
	instructions = ui.lab(panel,"",Vector2(32,118),Vector2(1360,58),19,Color("c5c5b3"))
	board = Control.new()
	board.position = Vector2(30,188)
	board.size = Vector2(960,465)
	board.draw.connect(_draw_board)
	panel.add_child(board)
	var rule := VSeparator.new()
	rule.position = Vector2(1007,189)
	rule.size = Vector2(2,464)
	panel.add_child(rule)
	notes = RichTextLabel.new()
	notes.position = Vector2(1033,190)
	notes.size = Vector2(390,465)
	notes.add_theme_font_override("normal_font",story.game.font)
	notes.add_theme_font_size_override("normal_font_size",20)
	notes.add_theme_color_override("default_color",Color("ddd6c6"))
	notes.add_theme_constant_override("line_separation",7)
	panel.add_child(notes)
	status = ui.lab(panel,"",Vector2(32,678),Vector2(1100,78),19,Color("c8ba8e"))
	ui.btn(panel,"收起  ESC",Vector2(1190,697),Vector2(230,52),story.close_page)
	visible = false
	set_process(false)
	get_viewport().size_changed.connect(fit)

func fit() -> void:
	var area := get_viewport_rect().size
	var factor := minf(area.x/1600.0,area.y/900.0)
	panel.scale = Vector2.ONE*factor
	panel.position = (area-panel.size*factor)*0.5

func open(id: String) -> void:
	item_id = id
	checked.clear()
	placements.clear()
	selected_card = ""
	selected_branch = ""
	valve_value = 0.0
	flipped = false
	completed_here = false
	order_index = 0
	pointer_phase = 0.0
	visible = true
	story.reader_panel.visible = false
	set_process(id == "meter")
	title.text = String(TITLES.get(id,"现场检查"))
	status.text = ""
	_refresh()
	fit()

func close() -> void:
	visible = false
	set_process(false)
	if story != null and story.reader_panel != null: story.reader_panel.visible = true

func _clear_board() -> void:
	for node in board_nodes:
		if is_instance_valid(node):
			board.remove_child(node)
			node.queue_free()
	board_nodes.clear()
	action_buttons.clear()
	slider = null

func _label(text: String, at: Vector2, dimensions: Vector2, font_size := 20, color := Color("d8d1bd")) -> Label:
	var label: Label = story.game.phone_ui.lab(board,text,at,dimensions,font_size,color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_nodes.append(label)
	return label

func _hotspot(text: String, rect: Rect2, callback: Callable, active := false) -> Button:
	var button: Button = story.game.phone_ui.btn(board,text,rect.position,rect.size,callback,Color("596951") if active else Color("303e36"))
	button.add_theme_font_size_override("font_size",19)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_buttons.append(button)
	board_nodes.append(button)
	return button

func _card(id: String, text: String, rect: Rect2) -> void:
	var card := EvidenceCard.new()
	card.owner_board = self
	card.evidence_id = id
	card.set_meta("c2_card",id)
	card.title = text
	card.position = rect.position
	card.size = rect.size
	card.add_theme_stylebox_override("panel",story.game.phone_ui.style(Color("d5c9ac") if selected_card == id else Color("a99f88"),3,Color("e0c899") if selected_card == id else Color("6e6b5b")))
	board.add_child(card)
	var label := Label.new()
	label.text = text
	label.position = Vector2(12,10)
	label.size = rect.size-Vector2(24,20)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font",story.game.font)
	label.add_theme_font_size_override("font_size",19)
	label.modulate = Color("2b3029")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(label)
	board_nodes.append(card)

func _slot(id: String, text: String, rect: Rect2) -> void:
	var slot := EvidenceSlot.new()
	slot.owner_board = self
	slot.slot_id = id
	slot.set_meta("c2_slot",id)
	slot.position = rect.position
	slot.size = rect.size
	slot.add_theme_stylebox_override("panel",story.game.phone_ui.style(Color("25332f"),3,Color("8d9274")))
	board.add_child(slot)
	var label := Label.new()
	label.text = text
	label.position = Vector2(12,10)
	label.size = rect.size-Vector2(24,20)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font",story.game.font)
	label.add_theme_font_size_override("font_size",20)
	label.modulate = Color("d9d0b7")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(label)
	board_nodes.append(slot)

func _refresh() -> void:
	_clear_board()
	match item_id:
		"address":
			instructions.text = "把归还纸页放在旧门牌旁。逐项确认同一地点，再拍照留存；不补写未知门牌号。"
			_label("归还纸页\n\n向阳福利院旧址\n\n第一份归还的来历",Vector2(50,28),Vector2(350,280),25)
			_label("现场旧门牌\n\n向阳福利院\n旧围墙 / 门外",Vector2(535,28),Vector2(360,280),25)
			for i in range(3):
				var key: String = ["name","place","photo"][i]
				var label: String = ["核对机构名","核对围墙与旧入口","拍下门牌留存"][i]
				_hotspot(("✓ " if checked.has(key) else "")+label,Rect2(45+i*305,342,285,68),func(): examine(key),checked.has(key))
			notes.text = "已归还的是地址线索。\n\n旧合影空位没有补齐，门牌也不会突然解释许砚的全部童年。\n\n阿七等你确认，不替你作答。"
		"registration":
			instructions.text = "先打开三份材料核对同一楼栋，再在下方账目条中标出不一致的一行。"
			var labels := ["建筑登记\n十六层 / 同栋","电梯维保\n最高16F / 同栋","水费分摊\n17F共用户 / 无签收"]
			for i in range(3):
				var index: int = i
				_hotspot(("✓ " if checked.has(str(index)) else "翻开  ")+labels[index],Rect2(12+i*315,22,297,180),func(): examine(str(index)),checked.has(str(index)))
			_label("标出需要核定的差异：",Vector2(15,237),Vector2(900,35))
			for i in range(3):
				var index: int = i
				_hotspot(["建筑登记层数","维保最高楼层","新增分摊户"][index],Rect2(12+i*315,300,297,72),func(): choose_discrepancy(index))
			notes.text = "何伯没有给新增户姓名。\n\n只记录材料确实写出的差异。拍到墙上女人的照片，也不能直接替她填名。"
		"meter":
			instructions.text = "点中正在走的表针并记录变化；把阿七原话记在另一栏，最后在图中选出多出来的上行支路。"
			for i in range(3):
				var index: int = i
				_hotspot("指针 %d" % (i+1),Rect2(20+i*125,205,115,42),func(): observe_needle(index),checked.has("needle") and i == 0)
			_hotspot("记下许砚看到的变化",Rect2(430,20,495,65),func(): record_view("xuyan"),checked.has("xuyan"))
			_hotspot("逐字保留阿七口述",Rect2(430,102,495,65),func(): record_view("aqi"),checked.has("aqi"))
			_label("管线：总表 → 公共附属管 → 三处出口\n点选出口，再按“标记支路”。",Vector2(20,276),Vector2(900,56))
			for i in range(3):
				var key: String = ["homes","leak","extra"][i]
				_hotspot(["1F—16F分户","墙根漏水段","未编号上行"][i],Rect2(20+i*280,352,258,62),func(): select_branch(key),selected_branch == key)
			_hotspot("标记支路",Rect2(865,350,82,66),submit_pipe)
			notes.text = "许砚\n"+("004172→004173；11月12日→11月11日。" if checked.has("xuyan") else "尚未留下数字与日期。")+"\n\n阿七\n"+("未分配住户用量，摊入已登记户。" if checked.has("aqi") else "她看不到数字，只能口述附注。")+"\n\n她的照片对许砚仍是表数。转述是记录，不是共享超能力。"
		"meal":
			instructions.text = "检查锅、用过的碗和日历；把现场的普通生活和何伯的记忆对照。"
			_hotspot("揭开锅盖\n温粥仍有热气",Rect2(42,65,285,245),func(): examine("pot"),checked.has("pot"))
			_hotspot("检查碗边\n用过的米粒痕",Rect2(360,155,225,155),func(): examine("bowl"),checked.has("bowl"))
			_hotspot("翻开照护日历\n连续的煮粥与送药记号",Rect2(620,50,285,290),func(): examine("calendar"),checked.has("calendar"))
			notes.text = "何伯说今天没吃饭。\n\n物件表明饭做过、碗用过、照护连续发生。\n\n关系正在消失，不是要玩家赶在倒计时结束前阅读。检查完成后先征求借便条的同意。"
		"living":
			instructions.text = "在布帘后的窄床与物品上检查长期使用的痕迹，再读管理条款。"
			for i in range(4):
				var key: String = ["bed","cup","kettle","rule"][i]
				_hotspot(["掀开床单一角\n磨痕与补线","翻看缺口杯底\n个人留用","检查热水壶\n茶垢与常用位置","读管理条款\n附属用房不作住所"][i],Rect2(25+(i%2)*470,30+(i/2)*200,440,170),func(): examine(key),checked.has(key))
			notes.text = "一张床不能凭空给出姓名。\n\n工资单只写工作地址，也不能独自证实居住。\n\n留下互相支持的生活事实，不把“没有产权”写成“没有资格被记得”。"
		"handwriting":
			instructions.text = "上方保留何伯便条的连笔样本。翻工资单到署名面，再点击与便条同形的笔迹片段。"
			_label("借来的便条：何师傅，药放门边了。\n注意“何”的长横与“药”字末点连笔。",Vector2(26,8),Vector2(920,65),22)
			_hotspot("翻回账目面" if flipped else "翻到署名面",Rect2(25,105,260,55),flip_document)
			for i in range(3):
				var index: int = i
				_hotspot("比对留存件 %s" % ["A","B","C"][i] if flipped else "工资账目\n日期与金额不能证明同一笔迹",Rect2(20+i*310,230,290,172),func(): compare_signature(index))
			notes.text = "核对的是可见笔迹，不是凭三个人名猜答案。\n\nA：末笔分离。\nB：长横与末点连成同一走势。\nC：横向短笔、末点上挑。\n\n匹配后才将完整署名写入案卷。"
		"corridor":
			instructions.text = "按排班：09F药 → 08F粥 → 06F床单。可拖放，或1—3选物、Q/W/E依次选门；不用抢时间。"
			var names := {"medicine":"药袋\n09F送药","porridge":"温粥盒\n08F送粥","linen":"脏床单桶\n06F换洗"}
			for i in range(3):
				var key: String = ["medicine","porridge","linen"][i]
				if not placements.has(key): _card(key,names[key],Rect2(20+i*310,25,290,95))
				var floor_id: String = ["09","08","06"][i]
				_slot(floor_id,floor_id+"F门后\n“放门口就行。”\n"+("✓ 已完成" if placements.values().has(floor_id) else "仍在等这一趟"),Rect2(20+i*310,210,290,200))
			notes.text = "排班留在右侧，随时可复查。\n\n送物进度：%d / 3。\n\n门里的人都认识她做的事，却没有一户问她要回哪里。错误物件会放回，不会删证据。" % order_index
		"isolation","source_valve":
			instructions.text = "先选管段，再转阀到90°并执行。键盘：1—4选管，←/→转阀，回车执行。错段可安全复位。"
			_label("市政来水",Vector2(25,6),Vector2(220,32),20)
			for i in range(4):
				var key: String = ["main","homes","leak","extra"][i]
				_hotspot(["总进水","现实1—16F","墙根漏水段","未编号上行"][i],Rect2(20+i*232,225,216,70),func(): select_branch(key),selected_branch == key)
			_label("阀位  0°开启 ───────── 90°关闭",Vector2(40,340),Vector2(600,35))
			slider = HSlider.new()
			slider.position = Vector2(40,390)
			slider.size = Vector2(650,35)
			slider.min_value = 0.0
			slider.max_value = 90.0
			slider.step = 1.0
			slider.value = valve_value
			slider.value_changed.connect(func(value): valve_value = value)
			board.add_child(slider)
			board_nodes.append(slider)
			_hotspot("执行阀位",Rect2(735,365,200,66),apply_valve)
			notes.text = "管线记录\n\n"+("核定通过，旧牌已挂回。\n现在关闭异常支管源阀，保留现实分户供水。" if item_id == "source_valve" else "先隔离墙根漏水段。\n主进水和现实分户供水保持开启；异常上行支路要等材料核定。")+"\n\n阿七附注：关联事项同步注销。\n\n直接关掉全部用水，不是本案允许的处置。"
		"archive":
			instructions.text = "把原件拖入对应栏，或1—5选件、Q/W/E/R选栏；两位独立证词均须归入“关系”。"
			var ids := ["wage","schedule","lived","he","nine"]
			var names := ["署名工资单","照护排班单","个人生活物证","何伯亲历证词","九楼独立证词"]
			for i in range(ids.size()):
				var key: String = ids[i]
				if not placements.has(key): _card(key,names[i],Rect2(14+i*187,20,174,100))
			var slot_names := {"identity":"孙素琴 / 署名","work":"工作","living":"居住事实","relations":"关系证人 / 两位"}
			for i in range(4):
				var key: String = ["identity","work","living","relations"][i]
				var text: String = slot_names[key]
				for card_id in placements:
					if placements[card_id] == key: text += "\n✓ "+str({"wage":"署名工资单","schedule":"排班单","lived":"生活物证","he":"何伯","nine":"九楼住户"}.get(card_id,card_id))
				_slot(key,text,Rect2(14+i*234,210,220,215))
			notes.text = "工资单：姓名与工作。\n排班：照护范围。\n生活物证：曾长期生活。\n两位证人：独立亲历关系。\n\n请核定后再挂旧牌、关闭异常源阀。材料原件不会因放错而消失。"
	board.queue_redraw()

func _draw_board() -> void:
	board.draw_rect(Rect2(Vector2.ZERO,board.size),Color("151c19"),true)
	if item_id in ["registration","address","handwriting"]:
		board.draw_rect(Rect2(15,12,935,430),Color("c0b28e",0.08),false,2)
	if item_id == "meter":
		for i in range(3):
			var center := Vector2(75+i*125,125)
			board.draw_circle(center,47,Color("b8b39c"))
			board.draw_circle(center,39,Color("27362f"))
			var angle := pointer_phase*1.9 if i == 0 else -.7+float(i)*.9
			board.draw_line(center,center+Vector2(sin(angle),-cos(angle))*32,Color("d89378") if i == 0 else Color("b2b79c"),3,true)
			board.draw_circle(center,4,Color("d6cfb0"))
	if item_id in ["isolation","source_valve"]:
		var junction := Vector2(470,118)
		board.draw_line(Vector2(80,45),Vector2(80,118),Color("879d91"),12,true)
		board.draw_line(Vector2(80,118),Vector2(825,118),Color("879d91"),12,true)
		for i in range(4):
			var center := Vector2(128+i*232,225)
			board.draw_line(Vector2(center.x,118),Vector2(center.x,220),Color("c2a776") if ["main","homes","leak","extra"][i] == selected_branch else Color("789587"),8,true)
		board.draw_circle(junction,13,Color("ced3c2"))
	if item_id == "handwriting":
		_draw_handwriting(Vector2(515,85),1,1.0)
		if flipped:
			for i in range(3): _draw_handwriting(Vector2(60+i*310,193),i,.65)

func _draw_handwriting(offset: Vector2, sample: int, size_factor: float) -> void:
	var shapes := [[Vector2(0,0),Vector2(40,-7),Vector2(80,0),Vector2(110,-8),Vector2(130,0)],[Vector2(0,0),Vector2(44,-6),Vector2(90,1),Vector2(110,18),Vector2(145,4),Vector2(190,8)],[Vector2(0,0),Vector2(30,0),Vector2(45,-8),Vector2(68,-5),Vector2(80,-23)]]
	var shape: Array = shapes[sample]
	for i in range(shape.size()-1): board.draw_line(offset+shape[i]*size_factor,offset+shape[i+1]*size_factor,Color("d1bb86"),3,true)

func examine(key: String) -> void:
	if completed_here: return
	checked[key] = true
	story.game.audio_system.sfx("paper_turn",-20)
	match item_id:
		"address":
			if checked.size() >= 3: _complete("门牌与归还地址一致；照片留存。新的派遣已收入背包。")
		"meal":
			if checked.has("pot") and checked.has("bowl") and checked.has("calendar"): _complete("温粥、使用痕迹和连续照护记号吻合。先征得同意，再借便条。")
		"living":
			if checked.size() >= 4: _complete("个人用品与床铺表明有人长期生活；姓名仍需署名单据核对。")
	_refresh()

func choose_discrepancy(index: int) -> bool:
	if completed_here: return true
	if checked.size() < 3: return _wrong("还没核对完三份同栋材料；先逐一翻开，避免把不同表当同一栋。")
	if index != 2: return _wrong("登记与维保都指向十六层。差异发生在新增分摊户，不要改写正常的建筑材料。")
	_complete("已记录：同栋登记和电梯最高16F，水费账却多出无签收的17F共用户。")
	return true

func observe_needle(index: int) -> bool:
	if index != 0: return _wrong("这一根没有走。观察三只表针，找出正在连续转动的红针。")
	checked.needle = true
	status.text = "红针前进一格；004172→004173，日期11月12日→11月11日。把这项变化留在你的记录栏。"
	return true

func record_view(who: String) -> bool:
	if who == "xuyan" and not checked.has("needle"): return _wrong("先观察正在走的表针，再记录实际看到的数字与日期变化。")
	if who not in ["xuyan","aqi"]: return false
	checked[who] = true
	story.game.audio_system.sfx("paper",-20)
	_refresh()
	return true

func select_branch(id: String) -> void:
	selected_branch = id
	_refresh()

func submit_pipe() -> bool:
	if not checked.has("xuyan") or not checked.has("aqi"): return _wrong("并列页还缺一人的记录。文字转述要保留，不能拿一张照片替代。")
	if selected_branch != "extra": return _wrong("图中现实分户和漏水点都已有出处。要标记的是公共附属管之后未编号的上行分支。")
	_complete("两人的记录已并列；总表额外上行支路标明。去8F确认与谁有关的生活正在消失。")
	return true

func flip_document() -> void:
	flipped = not flipped
	story.game.audio_system.sfx("paper_turn",-18)
	_refresh()

func compare_signature(index: int) -> bool:
	if not flipped: return _wrong("账目正面只有日期与金额，先翻到笔迹留存面。")
	if index != 1: return _wrong("连笔走势不一致。对照便条长横连到末点的转折，原件没有被取走，可以再比。")
	_complete("B件笔迹与便条一致。翻出的完整署名：孙素琴。工资单证明工作；居住仍须生活物证与证人。")
	return true

func select_card(id: String) -> void:
	selected_card = id
	status.text = "已拿起这张原件。拖到对应位置，或点击目的栏；放错可重新核对。"
	# Do not recreate a drag source during mouse-down/_get_drag_data.
	# Godot needs the original Control alive until the drag has reached its slot.
	for node in board_nodes:
		if node is EvidenceCard:
			node.add_theme_stylebox_override("panel",story.game.phone_ui.style(Color("d5c9ac") if node.evidence_id == id else Color("a99f88"),3,Color("e0c899") if node.evidence_id == id else Color("6e6b5b")))

func place_card(id: String, slot: String) -> bool:
	if completed_here: return true
	if id.is_empty(): return _wrong("先点选或拖起一件物品，再放到门口或归档栏。")
	if item_id == "corridor":
		var order := [["medicine","09"],["porridge","08"],["linen","06"]]
		if order_index >= order.size(): return true
		if id != order[order_index][0] or slot != order[order_index][1]: return _wrong("排班先09F送药，再08F送粥，最后06F床单。这次物件已放回，不会丢失。")
		placements[id] = slot
		order_index += 1
		selected_card = ""
		story.game.audio_system.sfx("cloth",-19)
		if order_index == 3: _complete("送完了这一趟。每一段关系都指向她，走廊却没有哪一扇门肯让她休息。")
		_refresh()
		return true
	if item_id == "archive":
		var expected := {"wage":"identity","schedule":"work","lived":"living","he":"relations","nine":"relations"}
		if not expected.has(id) or expected[id] != slot: return _wrong("这一栏和原件所能证明的事实不符。姓名、工作、生活和关系证词分别核对；材料已放回。")
		placements[id] = slot
		selected_card = ""
		story.game.audio_system.sfx("paper",-20)
		if placements.size() == expected.size(): _complete("署名、工作、居住事实与两位独立证词齐全，派遣科核定通过。")
		_refresh()
		return true
	return false

func set_valve_value(value: float) -> void:
	valve_value = clampf(value,0.0,90.0)
	if slider != null: slider.value = valve_value

func apply_valve() -> bool:
	if completed_here: return true
	if valve_value < 89.0: return _wrong("阀位尚未转到关闭位置。拖动阀位至90°，再执行；这不是按一下便完成的总闸。")
	var expected := "leak" if item_id == "isolation" else "extra"
	if selected_branch != expected:
		set_valve_value(0.0)
		return _wrong("该段承担正常供水或尚未获准注销，已安全复位。先按图核对这一步应该隔离哪一段。")
	if item_id == "source_valve" and (not story.flag("archive_approved") or not story.flag("plaque_hung")):
		return _wrong("核定与门牌行动还未完成；不可先关闭异常源头。")
	_complete("墙根漏水已隔离，现实十六层供水保留。继续准备身份与关系材料。" if item_id == "isolation" else "异常源阀关闭。现实供水、住户记忆与已核定材料全部保留。")
	return true

func _wrong(text: String) -> bool:
	status.text = text
	story.game.audio_system.sfx("device_blocked",-23)
	return false

func _complete(text: String) -> void:
	if completed_here: return
	completed_here = true
	status.text = "✓ "+text
	story.game.audio_system.sfx("ui_tap",-17)
	story.investigation_complete(item_id)

func _process(delta: float) -> void:
	pointer_phase += delta
	board.queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or not story.modal.visible or story.game.state != "case2_read": return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if item_id in ["corridor","archive"] and key >= KEY_1 and key <= KEY_5:
			var ids: Array = ["medicine","porridge","linen"] if item_id == "corridor" else ["wage","schedule","lived","he","nine"]
			var index := key-KEY_1
			if index < ids.size() and not placements.has(ids[index]): select_card(String(ids[index]))
		elif item_id in ["corridor","archive"] and key in [KEY_Q,KEY_W,KEY_E,KEY_R]:
			var targets: Array = ["09","08","06"] if item_id == "corridor" else ["identity","work","living","relations"]
			var index: int = [KEY_Q,KEY_W,KEY_E,KEY_R].find(key)
			if index < targets.size(): place_card(selected_card,String(targets[index]))
		elif item_id in ["isolation","source_valve"] and key in [KEY_LEFT,KEY_RIGHT]:
			set_valve_value(valve_value+5.0*(1.0 if key == KEY_RIGHT else -1.0))
		elif item_id in ["isolation","source_valve"] and key in [KEY_ENTER,KEY_SPACE]:
			apply_valve()
		elif key == KEY_F and item_id == "handwriting":
			flip_document()
		elif key >= KEY_1 and key <= KEY_9:
			var index := key-KEY_1
			if index < action_buttons.size(): action_buttons[index].pressed.emit()
		else: return
		get_viewport().set_input_as_handled()
