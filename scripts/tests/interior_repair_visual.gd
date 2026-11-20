extends SceneTree
var out:=""
var game
var folder="after/"
func _initialize():call_deferred("run")
func view(eye:Vector3,target:Vector3):
	game.player.global_position=eye-Vector3(0,1.66,0);game.player.cam_mode=0;game.player.body.visible=false
	game.player.cam.global_position=eye;game.player.cam.look_at(target);game.player.velocity=Vector3.ZERO
	game.field_kit.rig.visible=false;game._clear_sub();game.feedback.reset();game.hud_fade.modulate.a=0
func shot(id:String,eye:Vector3,target:Vector3):
	view(eye,target)
	for i in 16:await process_frame
	RenderingServer.force_draw(false)
	if root.get_texture().get_image().save_png(out+folder+id+".png")!=OK:quit(2)
func run():
	if DisplayServer.get_name()=="headless":quit(2);return
	create_timer(120).timeout.connect(func():quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-dir="):out=arg.trim_prefix("--review-dir=").replace("\\","/").trim_suffix("/")+"/"
		if arg.begins_with("--capture-label="):folder=arg.trim_prefix("--capture-label=").validate_filename()+"/"
	if not out.begins_with("F:") or not OS.get_cmdline_user_args().has("--verify"):quit(2);return
	DirAccess.make_dir_recursive_absolute(out+folder)
	root.size=Vector2i(1600,900);Engine.max_fps=60
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false);game.field_kit.letter_accepted=true;game.start_laundry_case()
	game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false);game.player.lock_look=true
	game.audio_system.stop_voice();game.director.set_process(false)
	game.laundry.campaign.guidance.set_process(false);game.laundry.campaign.guidance.hint.visible=false
	game.director.toast.visible=false;game.laundry.f2.doors.back.rotation.y=1.25
	await shot("01_1F楼梯入口",Vector3(.89,1.68,10.62),Vector3(.89,2.50,13.65))
	await shot("02_1F半层转身",Vector3(1.45,3.43,13.72),Vector3(2.21,3.52,11.5))
	await shot("03_3F下层踏步",Vector3(.89,9.35,12.45),Vector3(.90,10.0,13.85))
	await shot("04_3F半层回望",Vector3(1.55,10.03,13.74),Vector3(2.21,10.15,11.3))
	await shot("05_后房入口",Vector3(-1.65,5.16,1.48),Vector3(-1.68,4.71,-.35))
	await shot("06_后房东墙",Vector3(-1.48,5.16,.95),Vector3(-.35,4.65,.2))
	await shot("07_后房西墙",Vector3(-1.45,5.16,.75),Vector3(-2.95,4.72,.70))
	game.laundry.world.visible=false;game.case_mode="";game._start_prologue(false)
	game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false)
	await shot("08_出租屋书架",Vector3(-1.35,13.66,323.90),Vector3(-3.5,13.0,324.15))
	await shot("09_书架上层",Vector3(-2.45,13.75,324.85),Vector3(-3.48,13.60,324.15))
	var f=FileAccess.open(out+folder+"capture.json",FileAccess.WRITE);f.store_string(JSON.stringify({"kind":"actual Godot framebuffer, private non-input desktop, Dummy audio","renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":"1600x900","shots":9},"\t"));f.close()
	game.queue_free();await process_frame;await process_frame;quit()
