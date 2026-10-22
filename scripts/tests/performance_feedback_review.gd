extends SceneTree
## Actual game render, including seated skinning; opt-in visual review only.
var game
const OUT := "res://_预览/20261022_面部表演/"
func _initialize():call_deferred("run")
func shot(name:String):
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	create_timer(45).timeout.connect(func():quit(2))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false);game.field_kit.letter_accepted=true;game.start_laundry_case()
	game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false)
	game.player.lock_look=true;game.player.cam_mode=0;game.player.body.visible=false
	game.audio_system.stop_voice();game._clear_sub();game.feedback.reset();game.feedback.set_process(false)
	game.director.toast.visible=false;game.laundry.campaign.guidance.set_process(false)
	game.player.global_position=Vector3(1.7,12.75,7.25)
	game.player.cam.global_position=Vector3(1.7,14.25,7.25);game.player.cam.look_at(Vector3(1.7,13.8,5.5))
	game.laundry.interact("l_locked_503");game.feedback.step(.01)
	await shot("blocked_503")
	game.player.flash.visible=false
	game.feedback.reset();game.laundry._spawn_lady(false);game.laundry.night._do_sit();game.laundry.night.lady_state="sit"
	await create_timer(.75).timeout
	for actor in [game.laundry.lady,game.laundry.cast.laozhou,game.laundry.cast.aqi]:
		actor.visible=true;actor.performance.set_process(false)
		if actor==game.laundry.cast.aqi:
			game.laundry._show_aqi_on_bench()
			await create_timer(.6).timeout
		elif actor!=game.laundry.lady:actor.play("Idle",0)
		actor.ap.seek(0,true);actor.ap.advance(0);actor.ap.pause()
		var sk:Skeleton3D=actor.model.find_child("Skeleton3D",true,false)
		var head:Vector3=sk.global_transform*sk.get_bone_global_pose(sk.find_bone("mixamorig_Head")).origin
		game.player.cam.global_position=head+actor.global_basis*Vector3(0,.02,.65)
		game.player.cam.look_at(head+Vector3(0,.025,0));game.player.cam.fov=42
		var face=actor.performance
		for frame in [0,1,2,3]:
			face.reset_pose()
			if frame==1:face.mouth=.38;face.relief=.45
			elif frame==2:face.blink=.98
			elif frame==3:face.concern=.6;face.mouth=.18
			face.apply_shapes()
			await shot(actor.who+"_live_"+str(frame))
	game.queue_free();await process_frame;quit()
