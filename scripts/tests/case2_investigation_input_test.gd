extends SceneTree
## Real viewport input delivery to modal controls; no actors are teleported or clues injected here.
var game
var story
var passed := 0
var failed := 0
var deadline := 0

func check(ok: bool, text: String) -> void:
	if ok: passed += 1; print("[PASS] ",text)
	else: failed += 1; print("[FAIL] ",text)

func _initialize() -> void:
	deadline = Time.get_ticks_msec()+90000
	call_deferred("run")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > deadline: quit(1)
	return false

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func open(id: String) -> void:
	if story.dialogue.active: story.dialogue.cancel()
	game.state = "play"
	story.show_page("Input check","")
	story.investigation.open(id)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._hide_menu()
	game._start_prologue(false)
	game.set_process(false)
	game.exit_save.set_process(false)
	game.player.set_physics_process(false)
	story = preload("res://scripts/case2/case2_campaign.gd").new()
	game.add_child(story)
	story.setup(game)
	story.begin()
	# Capture completions without claiming these UI-only operations form a world route.
	var done: Array[String] = []
	story.progress_changed.connect(func():
		for flag_name in ["register_matched","meter_recorded","lived","wage_matched","corridor_complete","leak_isolated"]:
			if story.flag(flag_name) and not done.has(flag_name): done.append(flag_name))
	open("registration")
	await key(KEY_6)
	check(not story.flag("register_matched"),"Unseen table cannot be solved using a key")
	for code in [KEY_1,KEY_2,KEY_3,KEY_6]: await key(code)
	check(story.flag("register_matched"),"All table cards and discrepancy can be operated with real key events")
	check(story.modal.visible and game.state == "case2_read","Investigation owns the shared reader state")
	open("meter")
	for code in [KEY_1,KEY_4,KEY_5,KEY_8,KEY_9]: await key(code)
	check(story.flag("meter_recorded"),"Moving needle, two notes and branch use ordinary input")
	open("living")
	for code in [KEY_1,KEY_2,KEY_3,KEY_4]: await key(code)
	check(story.flag("lived"),"Life traces are independently inspectable")
	open("handwriting")
	await key(KEY_3)
	check(not story.flag("wage_matched"),"Keyboard cannot bypass turning a paper")
	for code in [KEY_F,KEY_3]: await key(code)
	check(story.flag("wage_matched"),"Flip and handwriting comparison work through input")
	open("corridor")
	await key(KEY_3)
	await key(KEY_E)
	check(story.investigation.order_index == 0,"Wrong delivery has no irreversible effect")
	for code in [KEY_1,KEY_Q,KEY_2,KEY_W,KEY_3,KEY_E]: await key(code)
	check(story.flag("corridor_complete"),"Delivery cards and doors have keyboard equivalents")
	open("isolation")
	await key(KEY_1)
	for _i in range(18): await key(KEY_RIGHT)
	await key(KEY_ENTER)
	check(not story.flag("leak_isolated") and is_zero_approx(story.investigation.valve_value),"Wrong main-valve turn safely resets through input")
	await key(KEY_3)
	for _i in range(18): await key(KEY_RIGHT)
	await key(KEY_ENTER)
	check(story.flag("leak_isolated"),"Branch selection and deliberate valve turn work using keys")
	open("archive")
	var original_children: Array = story.investigation.board.get_children()
	await key(KEY_1)
	check(story.investigation.board.get_children() == original_children,"Selecting a card keeps the drag source alive")
	await key(KEY_E)
	check(story.investigation.placements.is_empty(),"Incorrect evidence category preserves original card")
	for code in [KEY_1,KEY_Q,KEY_2,KEY_W,KEY_3,KEY_E,KEY_4,KEY_R,KEY_5,KEY_R]: await key(code)
	check(story.investigation.placements.size() == 5,"Four category slots accept both independent witnesses")
	# Geometry checks verify the scaled panels remain inside supported sizes.
	for dimensions in [Vector2i(1600,900),Vector2i(1280,720),Vector2i(1024,768)]:
		root.size = dimensions
		await process_frame
		story.investigation.fit()
		var rect: Rect2 = story.investigation.panel.get_global_rect()
		check(rect.position.x >= -1 and rect.position.y >= -1,"Modal top-left fits "+str(dimensions))
		check(rect.end.x <= story.investigation.get_viewport_rect().size.x+1 and rect.end.y <= story.investigation.get_viewport_rect().size.y+1,"Modal bottom-right fits "+str(dimensions))
	await key(KEY_ESCAPE)
	check(not story.modal.visible and game.state == "play" and game.player.can_move,"Esc closes and restores movement")
	var snapshot: Dictionary = story.capture()
	story.show_page("Canceled approval","", [["Do not finish",func(): story.mark("should_not_run")]])
	story.cancel()
	check(not story.flag("should_not_run") and not story.modal.visible,"Cancel discards unconfirmed reader actions")
	check(snapshot.flags == story.progress.flags,"Cancel does not alter established evidence")
	for node in game.find_children("*","AudioStreamPlayer",true,false):
		node.stop()
		node.stream = null
	for node in game.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	print("CASE2_INPUT_RESULT passed=%d failed=%d" % [passed,failed])
	quit(1 if failed > 0 else 0)
