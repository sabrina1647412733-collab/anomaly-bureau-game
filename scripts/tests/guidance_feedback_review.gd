extends SceneTree
const OUT="res://_预览/20261022_引导反馈/"
var game
var story
func _initialize():call_deferred("run")
func shot(name:String):
 for i in range(15):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+name+".png")
func view(eye:Vector3,target:Vector3):
 game.player.lock_look=true
 game.player.global_position=eye-Vector3(0,1.66,0);game.player.cam.global_position=eye;game.player.cam.look_at(target);game.field_kit.rig.visible=false
func clean():
 game.audio_system.stop_voice();game._clear_sub();game.feedback.reset();game.director.toast.visible=false
 if story.modal.visible:story.close_page()
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT));root.size=Vector2i(1600,900)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame
 game._hide_menu();game._start_prologue(false);game.field_kit.letter_accepted=true
 game.start_laundry_case();game.set_process(false);game.player.set_physics_process(false);game.hud_fade.modulate.a=0
 story=game.laundry.campaign;clean()
 view(Vector3(-.55,1.66,6.2),Vector3(-.7,1.3,9))
 await shot("01_单一主目标与入口提示")
 story.mark("signed");story.mark("rules_seen")
 view(Vector3(.5,5.16,4.4),Vector3(2.33,4.24,4.1))
 game.laundry.interact("l_m9");story.close_page();game._clear_sub()
 await shot("02_拾取独立反馈")
 story.mark("seven_seen");clean()
 view(Vector3(0,5.16,8.8),Vector3(0,4.4,2.6))
 await shot("03_明确等待与拨时")
 var key=InputEventKey.new();key.physical_keycode=KEY_H;key.pressed=true;story.guidance._input(key);key=null
 await shot("04_H展开调查提示")
 clean();story.progress.night=3
 for id in ["machine_key","roof_copy","roof_patch"]:game.laundry.clues[id]=true
 view(Vector3(3.65,5.05,7.05),Vector3(4.5,4.8,6.95))
 story.power_action(1);story.close_page();game._clear_sub()
 await shot("05_配电隔离黄灯")
 story.power_action(2);story.close_page();game._clear_sub()
 await shot("06_排水泵绿灯与操作反馈")
 clean();story.progress.night=1;game.laundry.clues.sign=true;story.mark("back_key")
 story.end_shift()
 await shot("07_第一夜交班总结")
 clean();story.progress.night=2;story.progress.rest_pending=false
 story.end_shift()
 await shot("08_第二夜交班总结")
 clean();story.progress.night=1;story.progress.rest_pending=false;game.state="play"
 view(Vector3(.65,5.21,4.1),Vector3(2.35,4.2,4.1));game._update_interaction()
 await shot("09_准星只选择九号机")
 game._open_pause()
 await shot("10_暂停脱困与保存退出")
 game._on_to_menu()
 await shot("11_主菜单自动存档入口")
 game.field_kit.generation+=1;game._discard_laundry();game.queue_free();await process_frame;await process_frame;quit()
