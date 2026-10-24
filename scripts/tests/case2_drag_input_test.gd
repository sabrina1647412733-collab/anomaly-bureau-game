extends SceneTree
## Actual viewport mouse drag, not a direct call to place_card().
var game
var story
var passed := 0
var failed := 0
var mouse_at := Vector2.ZERO

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	if ok: passed += 1; print("[PASS] ",text)
	else: failed += 1; print("[FAIL] ",text)

func move_mouse(at: Vector2,held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at-mouse_at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	mouse_at = at
	await process_frame
	await process_frame

func mouse_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = mouse_at
	event.global_position = mouse_at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func node_for(meta: String,id: String) -> Control:
	for node in story.investigation.board.get_children():
		if node.get_meta(meta,"") == id: return node
	return null

func drag(card: String,slot: String) -> void:
	var source := node_for("c2_card",card)
	var target := node_for("c2_slot",slot)
	if source == null or target == null:
		check(false,"Missing card/slot "+card+"/"+slot)
		return
	var begin := source.get_global_rect().get_center()
	var end := target.get_global_rect().get_center()
	await move_mouse(begin)
	await mouse_button(true)
	await move_mouse(begin+Vector2(0,20),true)
	await move_mouse(begin.lerp(end,.5),true)
	await move_mouse(end,true)
	await mouse_button(false)
	await process_frame

func run() -> void:
	root.size = Vector2i(1600,900)
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
	story.open_workbench("corridor")
	await process_frame
	await drag("linen","06")
	check(story.investigation.order_index == 0,"Wrong mouse delivery returns the object")
	await drag("medicine","09")
	check(story.investigation.order_index == 1,"Drag medicine to ninth floor")
	await drag("porridge","08")
	check(story.investigation.order_index == 2,"Drag porridge to eighth floor")
	await drag("linen","06")
	check(story.flag("corridor_complete"),"Third physical drop completes delivery")
	story.open_workbench("archive")
	await process_frame
	await drag("wage","living")
	check(story.investigation.placements.is_empty(),"Wrong archive drop does not delete evidence")
	for row in [["wage","identity"],["schedule","work"],["lived","living"],["he","relations"],["nine","relations"]]:
		await drag(row[0],row[1])
		check(story.investigation.placements.has(row[0]),"Mouse archived "+str(row))
	check(story.investigation.placements.size() == 5,"Independent witnesses share a category without overwriting")
	story.cancel()
	for node in game.find_children("*","AudioStreamPlayer",true,false): node.stop(); node.stream = null
	for node in game.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(.2).timeout
	print("CASE2_DRAG_RESULT passed=%d failed=%d" % [passed,failed])
	quit(1 if failed > 0 else 0)
