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
var inventory
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
var letter_camera

func setup(g) -> void:
	game = g
	ui = game.phone_ui
	var layer := CanvasLayer.new()
	layer.layer = 22
	add_child(layer)
	inventory = preload("res://scripts/inventory_view.gd").new()
	layer.add_child(inventory)
	inventory.setup(game.font)
	grid = inventory.grid
	detail = inventory.detail
	take_button = inventory.take_button
	inventory.item_selected.connect(func(id): selected_id = id; game.audio_system.sfx("ui_tap", -24))
	inventory.take_requested.connect(take_selected)
	inventory.close_requested.connect(func(): open_inventory(false))
	_build_letter()
	viewmodel = preload("res://scripts/viewmodel_view.gd").new()
	viewmodel.setup(game.player,game.font)
	rig = viewmodel.rig
	letter_camera=preload("res://scripts/case_cinematic.gd").new()
	add_child(letter_camera);letter_camera.setup(game,null)
	measure_desk()
	decorate_envelope()
	ui.stow_requested.connect(stow)
	ui.answer_requested.connect(answer_phone)
	ui.hangup_requested.connect(end_phone_call)
	game.audio_system.voice.finished.connect(func():
		if ui.call_active: ui.end_call())
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
	rig.transition_to(id)
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
	var previous := held_id
	held_id = ""
	rig.set_item("")
	game.audio_system.sfx("stow")
	sync_world()
	if previous != "":game.feedback.notify("物品已收纳","空手按 B 打开背包，可再次取出。")

func open_inventory(on: bool) -> void:
	game.bag_open = on
	inventory.visible = on
	if on:
		inventory.category = "道具"
		inventory.fit_panel()
		refresh_inventory()
	game.player.can_move = not on
	game.player.allow_capture = not on
	game.player.dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED

func refresh_inventory() -> void:
	inventory.refresh(game.case_bag, selected_id)
	selected_id = inventory.selected_id

func select(id: String) -> void:
	inventory.select_item(id)
	selected_id = inventory.selected_id

func take_selected() -> void:
	if not game.bag_has(selected_id):
		return
	open_inventory(false)
	equip(selected_id)
	game.feedback.notify("已取出物品","E / F 查看当前持物，B 收回背包。")

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
	game.audio_system.voice_context = "phone"
	game.phone_ui.call_active = true
	game.note("话","房东催租",game.phone_ui.call_text)
	game._clear_sub()
	game._prologue_set_objective("接听房东电话；挂断后留意房门外的声音。")

func end_phone_call() -> void:
	if game.audio_system.voice_context == "phone": game.audio_system.stop_voice()
	game._clear_sub()
	game.director.after_rent_call()

func pickup_clock() -> void:
	if not game.clock_appeared: return
	game.bag_add("weird_clock","诡异时钟","黄铜座钟。T 随时拨时：+10分钟、+30分钟，或到下一事件。现实1分钟=游戏10分钟。")
	equip("weird_clock")
	sync_world()
	game.director.open_clock()

func reset() -> void:
	if letter_camera!=null:letter_camera.cancel()
	if game.feedback != null:game.feedback.reset()
	generation += 1
	held_id = ""
	phone_owned = false
	letter_accepted = false
	letter_decision = false
	letter_ui.visible = false
	inventory.visible = false
	rig.set_item("")
	game.audio_system.ring.stop()
	game.audio_system.stop_voice()
	game.audio_system.played.clear()
	game.phone_ui.incoming = false
	game.phone_ui.call_active = false
	if game.director != null: game.director.reset()
	if is_instance_valid(discarded):
		discarded.visible = false
	sync_world()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key==KEY_E and game.choice==null and game.state in ["prologue","play"] and game.focus!=null:
		game._update_interaction()
	if key == KEY_B and game.state in ["prologue", "play", "prologue_ui"]:
		if inventory.visible:
			open_inventory(false)
		elif held_id != "" or game.phone_open or letter_ui.visible:
			stow()
		else:
			open_inventory(true)
		get_viewport().set_input_as_handled()
	elif inventory.visible and key in [KEY_ESCAPE, KEY_E, KEY_ENTER, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_TAB]:
		match key:
			KEY_ESCAPE: open_inventory(false)
			KEY_LEFT: inventory.move_selection(-1)
			KEY_RIGHT: inventory.move_selection(1)
			KEY_UP: inventory.move_selection(-6)
			KEY_DOWN: inventory.move_selection(6)
			KEY_TAB: inventory.cycle_category()
			_: take_selected()
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
		elif game.case2_controller!=null and game.case2_controller.active and game.case2_controller.campaign.inspect_item(held_id):
			pass
		elif game.laundry != null and game.laundry.campaign != null and game.laundry.campaign.inspect_item(held_id):
			pass
		else:
			open_inventory(true)
			select(held_id)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if rig == null:
		return
	rig.freeze(game.state=="paused")
	game.player.show_view_arm = false
	game.player.view_arm.visible = false
	ui.set_time(game.clock_min)
	rig.update_time(game.clock_min)
	rig.visible = game.player.cam_mode == 0 and game.state in ["prologue", "play", "prologue_ui", "prologue_choice"] and not inventory.visible and not game.phone_open and not letter_ui.visible
