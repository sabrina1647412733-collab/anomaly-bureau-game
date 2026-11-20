extends SceneTree
var game
var story
var output:=""
var count:=0
func _initialize()->void:call_deferred("run")
func shot(label:String)->void:
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output.path_join(label+".png"))!=OK:quit(2);return
	count+=1
func run()->void:
	if DisplayServer.get_name()=="headless":quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	if not output.begins_with("F:") or not OS.get_cmdline_user_args().has("--verify"):quit(2);return
	DirAccess.make_dir_recursive_absolute(output);Engine.max_fps=60;root.size=Vector2i(1600,900)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false);game.field_kit.letter_accepted=true;game.start_laundry_case()
	game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false);game.player.lock_look=true
	game._clear_sub();game.hud_fade.modulate.a=0;game.audio_system.stop_voice();game.director.toast.visible=false
	story=game.laundry.campaign;story.guidance.set_process(false);story.cinematic.set_process(false)
	story.duty.order_page();await shot("01_当班工作单")
	story.duty.take_order();story.mark("rules_seen");story.duty.interact("l_m3")
	await shot("02_擦拭前")
	for i in range(64):
		if story.duty.glass.active_cell(i):story.duty.glass.stroke(story.duty.glass.cell_point(i),story.duty.glass.cell_point(i))
	await shot("03_擦拭后内侧手印")
	story.duty.glass.complete();story.close_page()
	game.player.global_position=Vector3(-1.10,3.5,4.99);game.player.cam.global_position=Vector3(-1.1,4.5,4.99);game.player.cam.look_at(Vector3(-2.41,3.96,4.99))
	game.field_kit.rig.visible=false;await shot("04_三号机实物")
	game.laundry.clues["slip"]=true;story.mark("examined_slip");story.mark("seven_seen")
	story.duty.open_counter();await shot("05_柜台继续值守")
	game.laundry.fired["bc1"]=true;game.laundry.fired["bc2"]=true;story.mark("duty_broadcast1")
	story.duty.broadcast_page();await shot("06_两遍广播核对")
	for extent in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=extent;story.duty.interact("l_m3");story.progress.flags.erase("glass_checked");story.duty.interact("l_m3")
		await shot("07_擦拭布局_%d"%extent.y)
		story.close_page()
	var file=FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"shots":count,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"kind":"actual Godot framebuffer on isolated non-input desktop, Dummy audio"},"\t"))
	game._discard_laundry();game.queue_free();await process_frame;await process_frame;quit()
