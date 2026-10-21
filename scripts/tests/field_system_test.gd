extends SceneTree
var game
var passed := 0
var failed := 0

func check(ok: bool, title: String) -> void:
	if ok: passed += 1; print("[PASS] ", title)
	else: failed += 1; print("[FAIL] ", title)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game.field_kit._input(event)

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._hide_menu()
	game._start_prologue(false)
	var kit = game.field_kit
	kit.pickup_phone()
	check(kit.phone_owned and game.phone_open, "拾起手机打开锁屏")
	check(not game.get_meta("phone_world_body").visible and not game.get_meta("phone_screen").visible, "拾取后场景手机和屏幕都消失")
	for page in ["home", "chat", "wallet", "album", "calls", "notes", "map", "clock", "settings"]:
		game.phone_ui._goto(page)
		check(game.phone_ui.page == page and game.phone_ui.screen.get_child_count() > 0, "手机应用可打开：" + page)
	key(KEY_B)
	check(not game.phone_open and kit.held_id == "" and game.bag_has("phone"), "B 从手机界面收进背包")
	key(KEY_B)
	check(kit.inventory.visible, "空手 B 打开背包")
	kit.select("phone")
	kit.take_selected()
	check(not kit.inventory.visible and kit.held_id == "phone" and kit.rig.item_id == "phone", "背包取出手机，手臂持物模型同步")
	kit.stow()
	game._prologue_drop_letter()
	check(game.prologue_envelope.visible, "信封在门下出现")
	game._pick_envelope()
	check(kit.letter_ui.visible and kit.letter_decision, "拾信后显示独立可读通知书")
	check(kit.letter_body.text.contains("活到交班即转正") and kit.letter_body.get_theme_font_size("font_size") >= 22, "信件正文清晰且保留原稿五条须知")
	check(kit.refuse_button.visible and kit.accept_button.visible, "第一次有同意和拒绝")
	game._refuse_envelope()
	check(game.choice == null and not game.bag_has("envelope") and not kit.letter_ui.visible, "拒绝关闭信件，未收进背包")
	check(is_instance_valid(kit.discarded) and kit.discarded.visible, "拒绝后垃圾桶有丢弃的信封")
	await create_timer(3.6).timeout
	check(game.prologue_envelope.visible and game.prologue_envelope.position.is_equal_approx(kit.desk_letter_position), "灯亮后信封按桌面实测尺寸摆放，不埋进活页本")
	check(game.choice == null, "桌上信封要再次拾取，不自动弹选项")
	game._pick_envelope()
	check(kit.accept_button.visible and not kit.refuse_button.visible and game.choice == "env_choice_forced", "第二次只有同意")
	game._accept_envelope()
	check(kit.letter_accepted and game.bag_has("envelope") and kit.held_id == "", "同意后通知书自动收入背包")
	kit.open_inventory(true)
	kit.select("envelope")
	kit.take_selected()
	check(kit.held_id == "envelope" and kit.rig.item_id == "envelope", "通知书可从背包取出手持")
	kit.show_letter(false)
	check(not kit.accept_button.visible and not kit.refuse_button.visible and kit.close_letter_button.visible, "重读通知书没有重复入职选项")
	kit.close_letter()
	kit.stow()
	game._ring_phone()
	check(game.audio_system.ring.playing and game.phone_ui.incoming, "来电有真实铃声音源")
	kit.pickup_phone()
	kit.answer_phone()
	check(game.prologue_call_done and not game.audio_system.ring.playing and game.audio_system.voice.playing, "接听停止铃声并播放中文配音")
	game.audio_system._process(.1)
	check(not game.phone_ui.incoming and not game.audio_system.ring.playing, "接听后的下一帧不会重新响铃")
	game._close_phone()
	kit.stow()
	var snapshot: Dictionary = preload("res://scripts/case_save.gd").capture(game)
	check(snapshot["field_items"]["phone_owned"] and snapshot["field_items"]["letter_accepted"], "存档包含持物所有权")
	check(preload("res://scripts/case_save.gd").restore(game, snapshot), "存档恢复随身系统")
	check(not game.get_meta("phone_world_body").visible and game.bag_has("envelope"), "读档不复活场景手机，保留通知书")
	game._close_phone()
	game.start_laundry_case()
	game.set_process(false)
	for i in range(5): await physics_frame
	var space = game.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(2.43,.1,-8.15), Vector3(2.43,-2.7,-8.15))
	query.exclude = [game.player.get_rid()]
	check(space.intersect_ray(query).is_empty(), "服务梯顶棚开口与 1F 洞口对齐")
	query = PhysicsRayQueryParameters3D.create(Vector3(1.55,4.4,9.8), Vector3(1.55,4.4,10.6))
	query.exclude = [game.player.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		var owner_node = hit["collider"].shape_owner_get_owner(hit["collider"].shape_find_owner(hit["shape"]))
		print("[ENTRY HIT] ", hit["position"], " ", owner_node.global_position, " ", owner_node.shape)
		if owner_node.shape is BoxShape3D: print("[ENTRY SIZE] ", owner_node.shape.size)
	check(hit.is_empty(), "洗衣店入口不再有封门碰撞")
	game.laundry.routes.climb(true)
	await create_timer(3.1).timeout
	check(game.player.global_position.y < -2.8 and game.state == "play", "铁梯能下到 B1 并恢复操作")
	var capsule := PhysicsShapeQueryParameters3D.new()
	capsule.shape = game.player.cap
	capsule.transform = Transform3D(Basis.IDENTITY, game.player.global_position + Vector3(0,.91,0))
	capsule.margin = .001
	capsule.exclude = [game.player.get_rid()]
	var overlaps: Array = space.intersect_shape(capsule)
	for overlap in overlaps:
		var node = overlap["collider"].shape_owner_get_owner(overlap["collider"].shape_find_owner(overlap["shape"]))
		print("[B1 HIT] ", node.global_position, " ", node.shape)
		if node.shape is BoxShape3D: print("[B1 SIZE] ", node.shape.size)
	check(overlaps.is_empty(), "B1 落脚点有完整胶囊体空间")
	game.laundry.routes.climb(false)
	await create_timer(3.1).timeout
	check(game.player.global_position.y > -.05 and game.player.can_move, "铁梯可返回 1F，不是单向传送")
	for id in ["night_music", "phone_ring", "knock", "paper", "door", "phone_voice", "broadcast_1", "lady_ask"]:
		check(game.audio_system.stream(id) != null, "音频资源可加载：" + id)
	game.field_kit.generation += 1
	game._discard_laundry()
	game.queue_free()
	await process_frame
	await process_frame
	print("结果：通过 %d / 失败 %d" % [passed, failed])
	quit(0 if failed == 0 else 1)
