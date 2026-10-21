extends Node
## 本案随身物：拾取、B 收纳、背包取出、持物查看、可读信件。
const LETTER := "入职通知书\n\n许砚先生：\n\n  经核，您符合本局派遣条件。现录用为\n  异常事件处置岗（临时）。编制：派遣科。\n  权限：未入册。\n\n  须知（五条，不多不少）：\n  一、本岗位接触的现场，与日常经验不符。\n  二、到场后先观察，不要干预。\n  三、如遇无法解释的声音、影像、气味，\n      请记录，不要回应。\n  四、工作期间请勿告诉任何人您在何处工作。\n  五、第一个月为试用期。活到交班即转正。\n\n  首次派遣：得利自助洗衣店（老街 27 号）\n  报到时间：今日 23:40 — 次日 04:00\n  联络方式：店内广播\n\n                        诡异事务局 · 派遣科\n\n背面铅笔字：你已经来过一次了。"
var game
var ui
var held_id := ""
var phone_owned := false
var letter_accepted := false
var letter_ui: Control
var letter_body: Label
var accept_button: Button
var refuse_button: Button
var close_letter_button: Button
var inventory: Control
var grid: GridContainer
var detail: Label
var take_button: Button
var selected_id := ""
var rig
var viewmodel
var discarded: Node3D
var return_state := "prologue"
var letter_decision := false
var generation := 0
var desk_top := .805
var desk_letter_position := Vector3(2.55,.8125,2.0)
var desk_clock_position := Vector3(2.68,12.805,324.42)

func setup(g) -> void:
	game = g
	ui = game.phone_ui
	var layer := CanvasLayer.new()
	layer.layer = 22
	add_child(layer)
	inventory = Control.new()
	inventory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(inventory)
	shade(inventory)
	var panel: Panel = ui.box(inventory, Vector2(200, 100), Vector2(1200, 700), Color("101e22"), 16)
	ui.lab(panel, "随 身 背 包", Vector2(38, 28), Vector2(900, 55), 30)
	ui.lab(panel, "物品放进包里以后，会从场景中移除。选择物品可再次拿到手中。", Vector2(40, 87), Vector2(1100, 40), 16, Color("a7bcb6"))
	var sc := ScrollContainer.new()
	sc.position = Vector2(38, 155)
	sc.size = Vector2(610, 425)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	detail = ui.lab(panel, "背包还是空的。", Vector2(700, 172), Vector2(450, 330), 22)
	take_button = ui.btn(panel, "取出并手持   [ E ]", Vector2(700, 510), Vector2(450, 58), take_selected)
	ui.btn(panel, "关闭背包  [ B / ESC ]", Vector2(830, 615), Vector2(320, 48), func(): open_inventory(false))
	ui.lab(panel, "手持物品：B 收纳  ·  空手：B 打开背包  ·  E 查看手中物品", Vector2(40, 627), Vector2(780, 30), 14, Color("a7bcb6"))
	inventory.visible = false
	_build_letter()
	viewmodel = preload("res://scripts/viewmodel_view.gd").new()
	viewmodel.setup(game.player,game.font)
	rig = viewmodel.rig
	measure_desk()
	decorate_envelope()
	ui.stow_requested.connect(stow)
	ui.answer_requested.connect(answer_phone)
	ui.tap.connect(func(): game.audio_system.sfx("ui_tap", -18))

func measure_desk() -> void:
	var desk = game.get_meta("room_desk",null)
	if not is_instance_valid(desk): return
	var bounds := AABB()
	var first := true
	for node in desk.find_children("*","MeshInstance3D",true,false):
		var box: AABB = node.global_transform * node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first: return
	var origin: Vector3 = game.prologue_envelope.get_parent().global_position
	desk_top = bounds.end.y-origin.y
	desk_letter_position = Vector3(bounds.get_center().x,bounds.end.y+.0075,bounds.end.z-.16)-origin
	desk_clock_position = Vector3(bounds.end.x-.25,bounds.end.y,bounds.end.z-.20)

func decorate_envelope() -> void:
	var envelope = game.prologue_envelope
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e6d8b3")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	envelope.material_override = material
	var ink := Label3D.new()
	ink.font = game.font
	ink.text = "派遣科 · 急件\n许砚 收"
	ink.font_size = 42
	ink.pixel_size = .0009
	ink.position = Vector3(0,.008,0)
	ink.rotation.x = -PI*.5
	ink.modulate = Color("4a3026")
	ink.outline_size = 0
	envelope.add_child(ink)

func shade(parent: Control) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.005, .012, .018, .76)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(dim)

func _build_letter() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 31
	add_child(layer)
	letter_ui = Control.new()
	letter_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(letter_ui)
	shade(letter_ui)
	var paper: Panel = ui.box(letter_ui, Vector2(365, 45), Vector2(870, 810), Color("e9dfc8"), 2)
	ui.lab(paper, "异 常 事 件 处 置 岗（临 时）", Vector2(52, 34), Vector2(770, 53), 29, Color("202b28"))
	ui.lab(paper, "入职通知书   /   请本人阅读", Vector2(54, 89), Vector2(760, 30), 14, Color("687265"))
	var sc := ScrollContainer.new()
	sc.position = Vector2(54, 137)
	sc.size = Vector2(762, 540)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	paper.add_child(sc)
	letter_body = Label.new()
	letter_body.custom_minimum_size = Vector2(730, 0)
	letter_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	letter_body.add_theme_font_override("font", game.font)
	letter_body.add_theme_font_size_override("font_size", 22)
	letter_body.add_theme_color_override("font_color", Color("202b28"))
	letter_body.add_theme_constant_override("line_spacing", 5)
	letter_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	letter_body.text = LETTER
	sc.add_child(letter_body)
	accept_button = ui.btn(paper, "同意入职  [ E ]", Vector2(456, 711), Vector2(360, 54), game._accept_envelope)
	refuse_button = ui.btn(paper, "拒绝 · 扔进垃圾桶  [ R ]", Vector2(54, 711), Vector2(382, 54), game._refuse_envelope, Color("5e4c41"))
	close_letter_button = ui.btn(paper, "收起通知书  [ ESC ]", Vector2(456, 711), Vector2(360, 54), close_letter)
	letter_ui.visible = false
	game.prologue_paper = letter_ui
	game.prologue_paper_text = letter_body

func equip(id: String) -> void:
	held_id = id
	rig.set_item(id)
	game.audio_system.sfx("paper" if id == "envelope" else "stow")

func pickup_phone() -> void:
	if not phone_owned:
		phone_owned = true
		game.bag_add("phone", "手机", "有聊天、电话、钱包、相册和其他应用。B 收纳，背包里可再次取出。")
		sync_world()
	equip("phone")
	game._open_phone()

func sync_world() -> void:
	for key in ["phone_world_body", "phone_screen"]:
		var node = game.get_meta(key, null)
		if is_instance_valid(node):
			node.visible = not phone_owned
	if game.prologue_envelope != null:
		game.prologue_envelope.visible = game.prologue_letter_ready and not game.envelope_taken and not letter_accepted
		if game.envelope_refused > 0:
			# 原位置与活页本重叠，信封埋在本子里面。桌前缘留出专用空位。
			game.prologue_envelope.position = desk_letter_position
		else:
			game.prologue_envelope.position = Vector3(0, .018, -2.78)
	if game.wclock != null:
		game.wclock.visible = game.clock_appeared and not game.bag_has("weird_clock") and game.case_mode != "laundry"

func stow() -> void:
	if letter_decision:
		return
	if game.phone_open:
		game._close_phone()
	if letter_ui.visible:
		close_letter()
	if held_id != "" and not game.bag_has(held_id):
		return
	held_id = ""
	rig.set_item("")
	game.audio_system.sfx("stow")
	sync_world()
	game._say_seq("旁白", "收进背包了。空手时按 B，可以再取出来。", 1.2, false)

func open_inventory(on: bool) -> void:
	game.bag_open = on
	inventory.visible = on
	if on:
		refresh_inventory()
	game.player.can_move = not on
	game.player.allow_capture = not on
	game.player.dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED

func refresh_inventory() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var slots := maxi(24,int(ceil(game.case_bag.size()/6.0))*6)
	for index in range(slots):
		var item: Dictionary = game.case_bag[index] if index < game.case_bag.size() else {}
		var id := String(item.get("id",""))
		var button: Button = ui.btn(grid,"",Vector2.ZERO,Vector2(92,92),func(): select(id))
		button.custom_minimum_size = Vector2(92,92)
		button.set_meta("item_id",id)
		button.disabled = id == ""
		button.add_theme_stylebox_override("normal",ui.style(Color("1b2b2d"),2,Color("687a70")))
		button.add_theme_stylebox_override("disabled",ui.style(Color("122023"),2,Color("344744")))
		if id != "":
			var icon := preload("res://scripts/inventory_icon.gd").new()
			icon.item_id = id
			icon.position = Vector2(15,3)
			icon.size = Vector2(62,58)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(icon)
			var name_label: Label = ui.lab(button,String(item["name"]),Vector2(3,65),Vector2(86,23),12)
			name_label.clip_text = true
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.tooltip_text = String(item["name"])
	if game.case_bag.is_empty():
		detail.text = "背包还是空的。\n\n在场景中找到物品后，按 E 拾取。"
		take_button.disabled = true
	else:
		select(selected_id if game.bag_has(selected_id) else String(game.case_bag[0]["id"]))

func select(id: String) -> void:
	selected_id = id
	for cell in grid.get_children():
		if cell.get_meta("item_id","") != "": cell.add_theme_stylebox_override("normal",ui.style(Color("365248") if cell.get_meta("item_id") == id else Color("1b2b2d"),2,Color("c7b37e") if cell.get_meta("item_id") == id else Color("687a70")))
	for item in game.case_bag:
		if item["id"] == id:
			var body: String = "诡异事务局送来的入职通知书。\n\n取出后按 E，可阅读完整正文与五条须知。" if id == "envelope" else String(item["desc"])
			detail.text = String(item["name"]) + "\n\n" + body + "\n\n取出后 E 查看，B 收回。"
			take_button.disabled = false

func take_selected() -> void:
	if not game.bag_has(selected_id):
		return
	open_inventory(false)
	equip(selected_id)

func show_letter(decision: bool) -> void:
	if game.phone_open:
		game._close_phone()
	return_state = "play" if game.case_mode == "laundry" else "prologue"
	letter_decision = decision
	letter_ui.visible = true
	accept_button.visible = decision
	refuse_button.visible = decision and game.envelope_refused == 0
	close_letter_button.visible = not decision
	game.state = "prologue_choice" if decision else "prologue_ui"
	game.player.can_move = false
	game.player.allow_capture = false
	game.player.dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	accept_button.grab_focus() if decision else close_letter_button.grab_focus()

func close_letter() -> void:
	if letter_decision:
		return
	letter_ui.visible = false
	game.state = return_state
	game.player.can_move = true
	game.player.allow_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func accept_letter() -> void:
	letter_decision = false
	letter_ui.visible = false
	letter_accepted = true
	game.envelope_taken = true
	game.prologue_letter_read = true
	game.choice = null
	game.choice_text = ""
	game.state = "prologue"
	game.player.can_move = true
	game.player.allow_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game.bag_add("envelope", "入职通知书", LETTER)
	held_id = ""
	rig.set_item("")
	game.audio_system.sfx("stow")
	sync_world()
	game._spawn_weird_clock_after_letter()
	game.director.accepted()
	game._prologue_set_objective("23:40去得利洗衣店值夜班，报酬800元。拿上桌上的时钟，从房门出发。")

func refuse_letter() -> void:
	generation += 1
	var run := generation
	letter_decision = false
	letter_ui.visible = false
	held_id = ""
	rig.set_item("")
	game.envelope_refused += 1
	game.envelope_taken = false
	game.choice = null
	game.choice_text = ""
	game.state = "prologue"
	game.player.can_move = true
	game.player.allow_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game.prologue_envelope.visible = false
	if discarded == null:
		discarded = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.20, .018, .14)
		discarded.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("d1c5a9")
		discarded.material_override = material
		game.prologue_envelope.get_parent().add_child(discarded)
		discarded.position = Vector3(.55, .43, 2.55)
	game.audio_system.sfx("paper")
	game._say_seq("旁白", "你把信封揉了一下，扔进垃圾桶。", 2.0, false)
	await get_tree().create_timer(1.4).timeout
	if run != generation:
		return
	game._set_prologue_room_lights(false)
	await get_tree().create_timer(2.0).timeout
	if run != generation:
		return
	game._set_prologue_room_lights(true)
	if is_instance_valid(discarded):
		discarded.visible = false
	sync_world()
	game._prologue_set_objective("桌上又出现了那只信封。走近，按 E 拾取。")
	game.audio_system.sfx("knock", -13)

func answer_phone() -> void:
	game.prologue_call_done = true
	game.phone_ui.incoming = false
	game.audio_system.ring.stop()
	game.audio_system.speak("phone_voice")
	game.note("话","房东催租",game.phone_ui.call_text)
	game._say_seq("房东",game.phone_ui.call_text,6.0,false)
	game._prologue_set_objective("房租欠了两个月，余额只剩31.40元。看看刚来的招聘消息。")
	game.director.after_rent_call()

func pickup_clock() -> void:
	if not game.clock_appeared: return
	game.bag_add("weird_clock","诡异时钟","黄铜座钟。T 随时拨时：+10分钟、+30分钟，或到下一事件。现实1分钟=游戏10分钟。")
	equip("weird_clock")
	sync_world()
	game.director.open_clock()

func reset() -> void:
	generation += 1
	held_id = ""
	phone_owned = false
	letter_accepted = false
	letter_decision = false
	letter_ui.visible = false
	inventory.visible = false
	rig.set_item("")
	game.audio_system.ring.stop()
	game.audio_system.voice.stop()
	game.audio_system.played.clear()
	game.phone_ui.incoming = false
	if game.director != null: game.director.reset()
	if is_instance_valid(discarded):
		discarded.visible = false
	sync_world()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_B and game.state in ["prologue", "play", "prologue_ui"]:
		if inventory.visible:
			open_inventory(false)
		elif held_id != "" or game.phone_open or letter_ui.visible:
			stow()
		else:
			open_inventory(true)
		get_viewport().set_input_as_handled()
	elif inventory.visible and key in [KEY_ESCAPE, KEY_E, KEY_ENTER]:
		if key == KEY_ESCAPE:
			open_inventory(false)
		else:
			take_selected()
		get_viewport().set_input_as_handled()
	elif letter_ui.visible and not letter_decision and key == KEY_ESCAPE:
		close_letter()
		get_viewport().set_input_as_handled()
	elif key in [KEY_E,KEY_F] and held_id != "" and not game.phone_open and (game.prompt == null or key == KEY_F) and game.choice == null and game.state in ["prologue", "play"]:
		if held_id == "phone":
			game._open_phone()
		elif held_id == "envelope":
			show_letter(false)
		elif held_id == "weird_clock":
			game.director.open_clock()
		elif game.laundry != null and game.laundry.campaign != null and game.laundry.campaign.inspect_item(held_id):
			pass
		else:
			open_inventory(true)
			select(held_id)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if rig == null:
		return
	game.player.show_view_arm = false
	game.player.view_arm.visible = false
	ui.set_time(game.clock_min)
	rig.update_time(game.clock_min)
	rig.visible = game.player.cam_mode == 0 and game.state in ["prologue", "play", "prologue_ui", "prologue_choice"] and not inventory.visible and not game.phone_open and not letter_ui.visible
