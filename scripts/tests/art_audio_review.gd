extends SceneTree
var game
var story
var out:String
func _initialize():
 call_deferred("run")
func view(eye:Vector3,target:Vector3):
 game.player.lock_look=true;game.player.global_position=eye-Vector3(0,1.66,0)
 game.player.cam.global_position=eye;game.player.cam.look_at(target);game.player.cam.fov=70
func shot(name:String):
 for i in range(12):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+name+".png")
func run():
 create_timer(100).timeout.connect(func():push_error("art review timeout");quit(2))
 var group="before/" if OS.get_cmdline_user_args().has("--baseline") else ("after_OpenGL/" if OS.get_cmdline_args().has("gl_compatibility") else "after/")
 out="res://_预览/20261022_美术声音/"+group
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));root.size=Vector2i(1600,900)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game._hide_menu();game._start_prologue(false);game.field_kit.letter_accepted=true;game.start_laundry_case()
 game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false)
 game.hud_fade.modulate.a=0;game._clear_sub();game.audio_system.stop_voice()
 story=game.laundry.campaign;story.guidance.set_process(false);story.guidance.hint.visible=false;game.director.toast.visible=false
 for info in [
 ["01_二楼店堂",Vector3(.1,5.05,8.5),Vector3(.0,4.45,3.0)],
 ["02_七号机",Vector3(.0,4.75,4.0),Vector3(.0,4.05,2.65)],
 ["03_柜台长椅",Vector3(-.4,4.95,8.2),Vector3(1.8,4.25,6.25)],
 ["04_一楼门厅",Vector3(-.4,1.7,-5.8),Vector3(-.5,1.3,8.3)],
 ["05_303卧室",Vector3(-1,8.2,5.4),Vector3(-2.4,7.6,3.4)],
 ["06_402老周",Vector3(-1.8,11.25,4.8),Vector3(-1.72,10.9,2.92)],
 ["07_503检修盒",Vector3(1.25,14.1,5.0),Vector3(2.8,13.45,4.6)],
 ["08_屋顶",Vector3(-.2,17.0,8.3),Vector3(-1.2,16.8,5.2)],
 ["09_B1",Vector3(2.5,-1.2,-5.0),Vector3(3.2,-1.7,-1.0)]]:
  view(info[1],info[2]);await shot(info[0])
 game.laundry._spawn_lady(false);game.laundry.night._do_sit();game.laundry.night.lady_state="sit"
 await create_timer(.9).timeout
 game.laundry.lady._apply_seat_offset_instant()
 game.laundry.lady.ap.play("SitIdle",0);game.laundry.lady.ap.seek(2.,true);game.laundry.lady.ap.advance(0);game.laundry.lady.ap.pause()
 view(Vector3(.0,4.75,6.6),Vector3(1.8,4.4,6.25));await shot("10_周秀兰坐姿")
 view(Vector3(1.8,4.35,8.5),Vector3(1.8,4.15,6.25));await shot("10b_坐姿侧面")
 for t in [0.,1.,2.,3.]:
  game.laundry.lady.ap.seek(t,true);game.laundry.lady.ap.advance(0)
  view(Vector3(.55,4.65,6.9),Vector3(1.8,4.25,6.25));await shot("10c_坐姿帧"+str(int(t)))
 game.laundry.world.visible=false;game.case_mode="";game._start_prologue(false);game._clear_sub()
 view(Vector3(-1.2,13.6,322.6),Vector3(1.5,12.95,323.5));await shot("11_出租屋")
 for id in ["phone","envelope","weird_clock","sweater","sandal"]:
  game.field_kit.rig.set_item(id);await shot("12_手持_"+id)
 game.field_kit.rig.set_item("")
 game.menu.visible=true;game.menu._show_settings(true);await shot("13_混音设置")
 game.menu.sett.visible=false;game.menu.credits_panel.visible=true;await shot("14_鸣谢")
 game.menu.hide_all();game.town_bridge.enter();game.player.set_physics_process(false)
 game.player.global_position=game.town_bridge.ORIGIN+Vector3(145.88,.12,124.8);game.player.cam_mode=0
 view(game.player.global_position+Vector3(0,1.66,0),game.town_bridge.ORIGIN+Vector3(145.88,1.4,115))
 await shot("15_街道洗衣店入口")
 game.field_kit.generation+=1;game._discard_laundry();game.queue_free();await process_frame;await process_frame;quit()
