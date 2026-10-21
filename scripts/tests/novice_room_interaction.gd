extends SceneTree
var game
var passed:=0
var failed:=0
func _initialize() -> void: run()
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("[PASS] ",label)
	else: failed+=1; print("[FAIL] ",label," prompt=",game.prompt)
func key(code: Key) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	root.push_input(event)
func point(foot: Vector3,target: Vector3) -> void:
	game.player.global_position=foot
	game.player.rotation=Vector3.ZERO
	game.player.cam.position=Vector3(0,1.66,0)
	game.player.cam.look_at(target)
	game._update_prologue_interaction()
func click(at: Vector2) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=at
	motion.global_position=at
	root.push_input(motion,true)
	var event:=InputEventMouseButton.new()
	event.position=at
	event.global_position=at
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	root.push_input(event,true)
	event=event.duplicate()
	event.pressed=false
	root.push_input(event,true)
func run() -> void:
	await process_frame
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._hide_menu()
	game._start_prologue(false)
	game.set_process(false)
	game.player.set_physics_process(false)
	game._ring_phone()
	point(Vector3(1.6,12.05,323.3),game.get_meta("phone_world_body").global_position+Vector3(0,.1,0))
	check(game.prompt!=null and game.prompt.id=="phone","靠近真实书桌能瞄准手机")
	key(KEY_E)
	await process_frame
	check(game.phone_open,"通过实际E事件拿起手机")
	click(Vector2(800,483))
	await process_frame
	check(game.prologue_call_done,"通过实际接听按钮接到催租电话")
	key(KEY_B)
	await create_timer(1.1).timeout
	game._clear_sub()
	point(Vector3(0,12.05,320.45),game.prologue_envelope.global_position+Vector3(0,.08,0))
	check(game.prompt!=null and String(game.prompt.id).begins_with("envelope"),"站在门内能瞄准第一封信，不被房门抢交互")
	key(KEY_E)
	await process_frame
	check(game.field_kit.letter_ui.visible,"通过实际E事件读取门下信封")
	game.field_kit.refuse_button.pressed.emit()
	await create_timer(3.6).timeout
	game._clear_sub()
	point(Vector3(1.6,12.05,323.85),game.prologue_envelope.global_position+Vector3(0,.08,0))
	check(game.prompt!=null and String(game.prompt.id).begins_with("envelope"),"站在桌旁能瞄准第二封信")
	key(KEY_E)
	await process_frame
	check(game.choice=="env_choice_forced" and game.field_kit.letter_ui.visible,"第二次用E拾取后显示仅同意")
	game.field_kit.accept_button.pressed.emit()
	await create_timer(.9).timeout
	game._clear_sub()
	point(Vector3(1.6,12.05,323.85),game.wclock.root.global_position+Vector3(0,.30,0))
	check(game.prompt!=null and game.prompt.id=="wclock","时钟交互点跟随真实桌面模型")
	key(KEY_E)
	await process_frame
	check(game.director.modal.visible and game.bag_has("weird_clock"),"通过E拿起时钟并打开事件拨时")
	key(KEY_B)
	await process_frame
	check(not game.director.modal.visible and game.field_kit.held_id=="" and not game.wclock.visible,"实际B事件将时钟收入背包")
	game.field_kit.generation+=1
	game.queue_free()
	await process_frame
	await process_frame
	print("结果：通过 %d / 失败 %d"%[passed,failed])
	quit(0 if failed==0 else 1)
