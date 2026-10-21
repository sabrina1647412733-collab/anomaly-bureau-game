extends SceneTree
var game
var passed := 0
var failed := 0
func _initialize() -> void: run()
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("[PASS] ",label)
	else: failed+=1; print("[FAIL] ",label)
func key(code: Key) -> void:
	var event:=InputEventKey.new()
	event.pressed=true
	event.physical_keycode=code
	root.push_input(event)
func run() -> void:
	await process_frame
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._hide_menu()
	game._start_prologue(false)
	game.player.set_physics_process(false)
	var kit=game.field_kit
	var director=game.director
	game._ring_phone()
	kit.pickup_phone()
	check(game.phone_ui.caller=="房东" and game.phone_ui.page=="incoming","开场来电是房东")
	check(game.phone_ui.call_text.contains("房租") and game.phone_ui.call_text.contains("2160"),"来电内容为催租")
	game.phone_ui.answer_requested.emit()
	check(game.prologue_call_done and not game.audio_system.ring.playing,"接听真正停止铃声")
	await create_timer(1.1).timeout
	check(game.phone_ui.messages.has("派遣科"),"催租后收到招聘消息")
	check(is_instance_valid(game.phone_ui.message_banner),"通话页也能看见新消息提示")
	var job:=String(game.phone_ui.messages["派遣科"][0])
	check(job.contains("800") and job.contains("23:40") and job.contains("04:00") and job.contains("工作"),"招聘消息说明去处、时间、工作和报酬")
	check(game.prologue_letter_ready and game.prologue_envelope.visible,"不必乱点两个物品也会收到门下信封")
	game._close_phone()
	kit.stow()
	game._clear_sub()
	var before: float=director.now()
	director.step(60.0)
	check(is_equal_approx(director.now()-before,10.0),"现实1分钟等于游戏10分钟")
	game._update_hud()
	check(game.hud_clock.visible and game.hud_clock.text.count(":")==2,"出租屋右上角显示24小时制时分秒")
	game._pick_envelope()
	game._refuse_envelope()
	await create_timer(3.6).timeout
	check(game.prologue_envelope.position.is_equal_approx(kit.desk_letter_position) and absf(game.prologue_envelope.position.y-.006-kit.desk_top)<.003,"第二封信贴合实测桌面")
	check(game.prologue_envelope.visible and game.prologue_envelope.get_child_count()>0,"第二封信有实际模型及封面文字")
	game._pick_envelope()
	check(not kit.refuse_button.visible,"第二封只有同意")
	game._accept_envelope()
	await create_timer(.9).timeout
	check(game.clock_appeared and game.wclock.visible,"黄铜时钟在书桌出现")
	kit.pickup_clock()
	check(game.bag_has("weird_clock") and not game.wclock.visible,"时钟可收进背包且世界模型消失")
	check(director.modal.visible,"从时钟实物打开拨时界面")
	director.close_clock(true)
	key(KEY_B)
	await process_frame
	check(kit.inventory.visible and kit.grid.columns==6 and kit.grid.get_child_count()==24,"实际B键打开6×4方格背包")
	check(kit.grid.get_child(0).size.is_equal_approx(Vector2(92,92)),"背包格子实际为正方形")
	kit.select("weird_clock")
	kit.take_selected()
	check(kit.held_id=="weird_clock" and kit.rig.item_id=="weird_clock","时钟可取出手持")
	key(KEY_T)
	await process_frame
	check(director.modal.visible,"实际T键可随时打开时钟")
	director.close_clock(true)
	var snapshot:Dictionary=preload("res://scripts/case_save.gd").capture(game)
	check(snapshot["director"]["messages"].has("派遣科"),"存档包含任务消息")
	check(preload("res://scripts/case_save.gd").restore(game,snapshot),"新时间与消息存档能恢复")
	check(game.bag_has("weird_clock") and game.phone_ui.messages.has("派遣科"),"读档保留时钟和招聘消息")
	check(not game.wclock.visible,"已收纳的时钟读档后不会在书桌重生")
	var old_snapshot:=snapshot.duplicate(true)
	old_snapshot.erase("director")
	check(preload("res://scripts/case_save.gd").restore(game,old_snapshot) and game.phone_ui.messages.has("派遣科"),"旧存档也补齐工作说明消息")
	game.start_laundry_case()
	game._clear_sub()
	game.set_process(false)
	check(game.laundry.RATE==10.0,"洗衣店时间倍率也是10倍")
	game.laundry.t=0
	game.case_obj_done.clear()
	game._update_case_objective()
	check(game.case_objective.contains("2F") and game.case_objective.contains("夜班"),"一楼明确提示到二楼夜班报到")
	director.open_clock()
	director.next_event()
	check(game.laundry.fired.has("bc1") and is_equal_approx(game.laundry.t,21*60),"拨到下一事件实际触发00:01广播")
	game._clear_sub()
	director.step(0)
	check(game.phone_ui.messages["派遣科"].size()>=3,"事件发生后手机收到任务提醒")
	director.open_clock()
	director.advance(1000)
	check(is_equal_approx(game.laundry.t,40*60) and not game.laundry.fired.has("oldlady"),"大幅拨时停在下一关键事件，不跳过剧情")
	game._clear_sub()
	director.step(0)
	var count: int=game.phone_ui.messages["派遣科"].size()
	director.step(0)
	check(game.phone_ui.messages["派遣科"].size()==count,"同一任务消息不会每帧重复")
	var previous_yaw: float = game.player.rotation.y
	game.player.allow_capture=false
	game.player.dragging=true
	var motion:=InputEventMouseMotion.new()
	motion.relative=Vector2(80,0)
	game.player._input(motion)
	check(is_equal_approx(game.player.rotation.y,previous_yaw) and not game.player.dragging,"拖动界面时不会带着背后视角转动")
	game.laundry.t=240*60
	game.laundry._timeline()
	director.open_clock()
	check(not director.modal.visible and game.choice=="case_final","必须回应她后才能继续拨到交班")
	game.field_kit.generation+=1
	game._discard_laundry()
	game.queue_free()
	await process_frame
	await process_frame
	print("结果：通过 %d / 失败 %d"%[passed,failed])
	quit(0 if failed==0 else 1)
