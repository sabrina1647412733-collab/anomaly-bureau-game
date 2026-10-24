extends SceneTree
## Real Godot framebuffer and layout/input checks. No generated graphics or postprocessing.
var game
var out:=""
var failed:=0
var passed:=0
var shots:Array[String]=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if ok:passed+=1
	else:failed+=1;push_error("VISUAL "+label)
func shot(label:String):
	game.director.sync_toast(0);game.feedback.step(0)
	for extent in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		root.size=extent
		for i in 5:await process_frame
		RenderingServer.force_draw(false)
		var filename:String=label+"_%dx%d.png"%[extent.x,extent.y]
		check(root.get_texture().get_image().save_png(out.path_join(filename))==OK,"保存实机图")
		shots.append(filename)
		if game.bag_open:
			check(root.get_visible_rect().encloses(game.field_kit.inventory.panel.get_global_rect()),"背包在可视范围内")
			check(game.field_kit.inventory.panel.get_global_rect().encloses(game.field_kit.take_button.get_global_rect()),"取出按钮不被长文本推出")
		if game.phone_ui.visible:check(root.get_visible_rect().encloses(game.phone_ui.panel.get_global_rect()),"手机在可视范围内")
		if game.menu.slots_panel.visible:check(root.get_visible_rect().encloses(game.menu.slots_panel.get_global_rect()),"存档页在可视范围内")
func view(eye:Vector3,at:Vector3):
	game.player.global_position=eye-Vector3(0,1.6,0);game.player.cam_mode=0;game.player.body.visible=false
	game.player.cam.global_position=eye;game.player.cam.look_at(at);game.player.velocity=Vector3.ZERO
	game.field_kit.rig.visible=false;game._clear_sub();game.feedback.reset();game.hud_fade.modulate.a=0
func key(code:Key):
	for down in [true,false]:
		var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;root.push_input(e)
func run():
	create_timer(120).timeout.connect(func():quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-dir="):out=arg.trim_prefix("--review-dir=")
	if not OS.get_cmdline_user_args().has("--verify") or not out.begins_with("F:") or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,720);Engine.max_fps=60
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false);game.field_kit.letter_accepted=true;game.start_laundry_case()
	game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false);game.player.lock_look=true
	game.audio_system.stop_voice();game.director.set_process(false)
	var story=game.laundry.campaign;story.guidance.set_process(false)
	view(Vector3(0,5.15,4.4),Vector3(0,4.25,2.75));game._update_interaction();game._update_hud()
	await shot("01_调查")
	check(game.prompt!=null and game.prompt.id=="l_m7","只选中准星指向的七号机")
	for id in ["slip","marriage","photo","cert","discharge","pipe_map","tool_key","sweater","sandal"]:game.bag_add(id,story.DOCS[id][0],story.DOCS[id][1])
	game.field_kit.open_inventory(true);game.field_kit.select("photo");await shot("03_背包")
	key(KEY_RIGHT);check(game.field_kit.selected_id=="cert","真实键盘可选择下一物品")
	key(KEY_TAB);check(game.field_kit.inventory.category=="钥匙","真实键盘可切分类")
	key(KEY_ESCAPE);check(not game.bag_open,"键盘关闭背包")
	game.phone_ui.incoming=true;game._open_phone();await shot("04_来电")
	game.phone_ui.incoming=false;game.phone_ui.call_active=true;game.phone_ui._goto("in_call");await shot("04_通话")
	if game.phone_ui.screen.has_node("CallTranscript"):
		check(game.phone_ui.screen.get_global_rect().encloses(game.phone_ui.screen.get_node("CallTranscript").get_global_rect()),"通话字幕区域完全在屏内")
		var normal_text:String=game.phone_ui.call_text
		game.phone_ui.call_text=normal_text.repeat(12);game.phone_ui._goto("in_call");await shot("04_长通话字幕测试")
		check(game.phone_ui.screen.get_node("CallTranscript").get_v_scroll_bar().max_value>245,"手机长字幕实际滚动")
		game.phone_ui.call_text=normal_text
	game.phone_ui.call_active=false;game.phone_ui.active_chat="派遣科";game.phone_ui.messages["派遣科"]=[game.director.JOB];game.phone_ui._goto("conversation");await shot("04_聊天")
	game._close_phone()
	game._open_pause();await shot("05_暂停")
	game.game_save(0)
	game.exit_save.write_snapshot(game.exit_save.PATH,game.exit_save.snapshot())
	game.menu.set_slots(game.slots_info(),"save");game.menu.show_slots("save");await shot("05_存读档")
	game.menu.slot_btns[0].pressed.emit()
	if game.menu.get("slot_confirm")!=null and game.menu.slot_confirm.visible:
		await shot("05_覆盖确认");game.menu.slot_confirm.hide()
	game._on_resume()
	game.laundry._spawn_lady(false);game.laundry.night._do_sit();game.laundry.night.lady_state="sit"
	view(Vector3(.05,4.85,7.1),Vector3(1.7,4.3,6.65))
	story.speak([["周秀兰","洗过了。得等他穿。","lady_wait"]],Callable(),game.laundry.lady)
	await shot("02_对白");story.dialogue.finish(false)
	var long_text:String=story.DOCS.testimony[1].repeat(3)
	story.speak([["许砚",long_text]])
	await shot("02_长文本排版测试");story.dialogue.finish(false)
	game._clear_sub();game.case_bag=[];game.field_kit.open_inventory(true);await shot("03_空背包");game.field_kit.open_inventory(false)
	var file=FileAccess.open(out.path_join("visual_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"shots":shots,"kind":"Godot native framebuffer; synthetic UI-state fixtures, not a human story playthrough","renderer":RenderingServer.get_current_rendering_method()},"\t"));file.close()
	game.audio_system.stop_voice();game.queue_free();await process_frame;await process_frame
	print("UI_VISUAL_RESULT ",passed," passed ",failed," failed");quit(0 if failed==0 else 1)
