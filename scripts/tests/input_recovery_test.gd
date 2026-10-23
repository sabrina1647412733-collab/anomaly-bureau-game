extends SceneTree
## Real viewport input: held items, dialogue pause and seated recovery.
var game
var passed := 0
var failed := 0
var callbacks := 0
static var TEMP := preload("res://scripts/storage_paths.gd").file("verify_input_recovery.json")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("[PASS] ", label)
	else:
		failed += 1
		print("[FAIL] ", label)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = false
	root.push_input(event)

func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture-review") or DisplayServer.get_name()=="headless":return
	await process_frame
	await process_frame
	var folder := "res://_预览/20261022_交互修复"
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder+"/"+name+".png")

func run() -> void:
	create_timer(70).timeout.connect(func(): quit(2))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._hide_menu()
	game._start_prologue(false)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.safety.set_physics_process(false)
	game.field_kit.phone_owned = true
	game.field_kit.letter_accepted = true
	game.bag_add("phone", "手机")
	game.field_kit.equip("phone")
	game.player.flash.visible = false
	key(KEY_F)
	check(game.phone_open, "F通过真实输入打开手持手机")
	check(not game.player.flash.visible, "查看物品不同时切换手电筒")
	var view: int = game.player.cam_mode
	key(KEY_V)
	check(game.player.cam_mode == view, "查看手机时V不切换世界视角")
	key(KEY_ESCAPE)
	check(not game.phone_open, "Esc关闭手机并返回现场")
	game.field_kit.stow()
	key(KEY_F)
	check(game.player.flash.visible, "空手F仍可切换手电筒")
	game.start_laundry_case()
	game._clear_sub()
	var dialogue = game.laundry.campaign.dialogue
	dialogue.play([["许砚", "第一句"], ["许砚", "第二句"]], func(): callbacks += 1)
	dialogue.remaining=100
	game.director.step(0)
	check(not game.director.toast.visible, "现场对话隐藏任务短信横幅")
	key(KEY_ESCAPE)
	check(game.state == "paused" and dialogue.cursor == 0, "对话Esc暂停且不跳句")
	# Also exercise callbacks, not only a keyboard path blocked by the menu.
	if game.state != "paused": game._open_pause()
	var notice_time: float=game.director.toast_time
	game.director.step(30)
	check(not game.director.toast.visible and game.director.toast_time==notice_time, "暂停隐藏横幅并保留剩余阅读时间")
	var cursor: int = dialogue.cursor
	dialogue.advance()
	key(KEY_E)
	var space := InputEventKey.new()
	space.pressed=true;space.physical_keycode=KEY_SPACE
	dialogue._input(space)
	check(dialogue.cursor == cursor and callbacks == 0, "暂停期间按键和继续按钮均不推进对白")
	await process_frame
	check(not dialogue.panel.visible, "暂停时隐藏高层对白面板")
	var paused_save: Dictionary = preload("res://scripts/case_save.gd").capture(game)
	check(paused_save.get("state")=="play", "对话暂停菜单可生成手动存档快照")
	await capture("dialogue_paused")
	game._on_resume()
	game.director.step(0)
	await process_frame
	check(game.state == "case_dialogue" and dialogue.panel.visible and not game.player.can_move, "继续游戏恢复原句且保留对话控制")
	await capture("dialogue_resumed")
	var saved: Dictionary = preload("res://scripts/case_save.gd").capture(game)
	check(not saved.is_empty() and saved.get("state") == "play" and callbacks == 0, "对白现场可保存且不提前提交剧情回调")
	key(KEY_E)
	key(KEY_E)
	check(callbacks == 1 and game.state == "play", "恢复后正常推进且剧情回调仅执行一次")
	game.director.step(0)
	check(game.director.toast.visible and game.phone_ui.unread.get("派遣科",0)>0, "对话后恢复任务横幅且保留未读消息")
	dialogue.play([["许砚", "返回菜单前的对白"]], func(): callbacks += 10)
	game._open_pause()
	game._on_to_menu()
	game.director.step(0)
	dialogue._process(99)
	check(game.state == "menu" and not dialogue.panel.visible and callbacks == 1, "返回主菜单取消对白且不触发未完成剧情")
	view = game.player.cam_mode
	key(KEY_V)
	check(game.player.cam_mode == view, "主菜单按V不改变现场视角")
	game._hide_menu()
	game.state = "play"
	game.player.sit_at(Vector3(1.5, 3.5, 7.2), 0)
	game.safety.reset_zone()
	game.safety.recover()
	check(not game.player.sitting and not game.player.cap_node.disabled, "坐姿脱困重新启用人物碰撞")
	check(game.player.can_move and game.player.allow_capture, "脱困后同时恢复移动与鼠标控制")
	if DisplayServer.get_name()!="headless":
		check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED, "窗口模式下脱困实际重新捕获鼠标")
	game.player.global_position = game.safety.anchor()
	game.player.velocity = Vector3(0, -4, 0)
	game._open_pause()
	var pos: Vector3 = game.player.global_position
	var velocity: Vector3 = game.player.velocity
	game.player._physics_process(.1)
	check(game.player.global_position == pos and game.player.velocity == velocity, "暂停时人物下落与物理位置真正冻结")
	game._on_resume()
	game.player.velocity = Vector3.ZERO
	game.player.set_physics_process(true)
	for frame in range(45): await physics_frame
	check(game.player.is_on_floor() and game.player.global_position.y > -.2, "脱困恢复后实际落地而非再次穿地")
	dialogue.play([["许砚", "保存时不提交的对白"]], func(): callbacks += 100)
	game._open_pause()
	var snapshot: Dictionary=preload("res://scripts/case_save.gd").capture(game)
	check(game.exit_save.write_snapshot(TEMP,snapshot), "对话暂停快照能原子写入独立测试文件")
	var restored: bool=preload("res://scripts/case_save.gd").restore(game,game.exit_save.read_snapshot(TEMP))
	check(restored and game.state=="play" and not game.player.physics_frozen and callbacks==1, "读档重建现场恢复物理且不提交中断对白")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	print("INPUT_RECOVERY_RESULT PASS=", passed, " FAIL=", failed)
	game.queue_free()
	await process_frame
	call_deferred("quit", 1 if failed else 0)
