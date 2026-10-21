extends SceneTree
var game
var story
var guide
var passed:=0
var failed:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("[PASS] ",label)
 else:failed+=1;print("[FAIL] ",label)
func clear():
 game.audio_system.stop_voice();game._clear_sub()
 if story.modal.visible:story.close_page()
func walk_goal(id:String,start:Vector3,label:String):
 clear();game.player.global_position=start;game.player.velocity=Vector3.ZERO
 var goal=story.goal(id,"测试路线","检查实际门洞")
 var point=guide.point_for(id);var arrived=false;var stuck=0;var route={};var blocker=""
 for i in range(2600):
  await physics_frame
  if game.player.cam.global_position.distance_to(point.pos)<float(point.r)-.12:arrived=true;break
  route=guide.route_for(goal,game.player.global_position)
  var direction:Vector3=route.pos-game.player.global_position;direction.y=0
  var before:Vector3=game.player.global_position
  game.player.velocity.x=direction.normalized().x*2;game.player.velocity.z=direction.normalized().z*2
  game.player.velocity.y=-.5 if game.player.is_on_floor() else game.player.velocity.y-22.0/60
  game.player.move_and_slide()
  if game.player.get_slide_collision_count()>0:blocker=str(game.player.get_slide_collision(0).get_collider().name)
  stuck=stuck+1 if game.player.global_position.distance_to(before)<.002 else 0
  if stuck>90:break
 if not arrived:print("NAV_DIAG ",id," ",game.player.global_position," ",route," ",blocker)
 check(arrived,label)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame
 game._hide_menu();game._start_prologue(false);game.field_kit.letter_accepted=true;game.field_kit.phone_owned=true
 game.bag_add("phone","手机");game.bag_add("weird_clock","时钟")
 game.start_laundry_case();game.set_process(false);game.player.set_physics_process(false)
 story=game.laundry.campaign;guide=story.guidance;guide.set_process(false);game.feedback.set_process(false);clear()
 game.player.cam_mode=0;game.player.cam.position=Vector3(0,1.66,0)
 game.feedback.reset();game._show_sub("周秀兰","请你再等一会。",2,false)
 game.bag_add("guide_test","测试文件")
 check(game.sub=="请你再等一会。" and not game.sub_pause,"拾取反馈不替换剧情字幕、不强制停住玩家")
 game.state="case_read";game.feedback.step(30)
 check(not game.feedback.panel.visible and game.feedback.pending.size()==1,"阅读时保留操作反馈，回到现场才显示")
 game.state="play";clear();game.feedback.step(.1)
 check(game.feedback.panel.visible and game.feedback.title.text.contains("测试文件"),"现场显示独立的物品获得卡片")
 var hold:float=game.feedback.remaining
 game._open_phone();game.feedback.step(30)
 check(not game.feedback.panel.visible and game.feedback.remaining==hold,"查看手机期间反馈不提前消失")
 game._close_phone();game.feedback.reset()
 check(story.current_goal().text.contains("1/4") and story.current_goal().text.contains("E"),"第一夜从明确签到动作开始")
 for id in ["lb_booth","l_price","l_m9","l_m7"]:
  clear();game.laundry.interact(id)
 clear()
 check(not story.physical.slip.visible and game.bag_has("slip"),"未取单拾取后实体消失且文件保留")
 check(story.current_goal().mode=="wait" and story.current_goal().text.contains("00:01"),"调查完成明确等待第一遍广播")
 var previous:Dictionary=story.current_goal()
 game.laundry.fired.bc1=true
 check(story.current_goal().id==previous.id and story.current_goal().key!=previous.key,"同一广播位置的不同阶段有独立目标记录")
 check(not story.current_goal().text.contains("六件"),"来客清点前不提前揭示缺少第六件")
 game.laundry.fired.oldlady=true;game.laundry._spawn_lady(false)
 clear();story.lady_talk()
 check(not story.dialogue.panel.visible and not story.flag("met_lady"),"来客走路时先观察，不在入座前强制交谈")
 check(story.current_goal().mode=="arrival" and float(story.next_event()[0])==1420+game.laundry.t/60,"人物入座期间不提示跳时")
 game.laundry.night._npc_step(6.1);game.laundry.night.lady_state="sit";clear()
 story.lady_talk()
 while story.dialogue.panel.visible:story.dialogue.advance()
 clear()
 check(story.flag("met_lady") and story.current_goal().mode=="wait","交谈结束后才切到继续观察阶段")
 var evt=InputEventKey.new();evt.physical_keycode=KEY_H;evt.pressed=true
 guide._input(evt)
 evt=null
 check(story.modal.visible and story.heading.text=="当前调查提示" and story.body.text.contains("怎么走"),"H可展开当前操作、原因和路线")
 clear()
 var test_goal:Dictionary=story.goal("l_m9","检查九号机","观察纸条")
 var route=guide.route_for(test_goal,Vector3(0,3.5,5))
 guide.last_key="";guide.track_progress(0,test_goal,route,Vector3(0,3.5,5))
 guide.track_progress(46,test_goal,route,Vector3(0,3.5,5))
 check(guide.idle_seconds>=45,"停滞45秒才展开额外路线帮助")
 var count:int=game.phone_ui.messages.get("派遣科",[]).size()
 guide.track_progress(45,test_goal,route,Vector3(0,3.5,5));guide.track_progress(100,test_goal,route,Vector3(0,3.5,5))
 check(game.phone_ui.messages.get("派遣科",[]).size()==count+1,"停滞90秒补发一次提示，不重复刷短信")
 guide.track_progress(1,test_goal,route,Vector3(1.1,3.5,4.5))
 check(guide.idle_seconds==0,"靠近当前目的地会重置停滞计时")
 story.progress.night=3;game.spots=game.laundry.spots()
 game.laundry.back_open=true;game.laundry.f2.doors.back.rotation.y=1.5
 game.laundry.buildings.f4.k.doors["402"].rotation.y=1.5
 await walk_goal("l_price",Vector3(-.55,.06,9),"按引导真实走完1F到2F工作须知路线")
 await walk_goal("c1_mail_letter",Vector3(1.3,3.55,6.8),"引导经店内门口和廊桥进入邮政间")
 await walk_goal("c1_power",Vector3(1.3,3.55,6.25),"引导绕过长椅再进入配电房")
 await walk_goal("c1_cert",Vector3(0,6.95,9.2),"引导先过304门洞再找书桌")
 await walk_goal("c1_keybox",Vector3(0,12.75,8),"503反锁时引导经502维修通道进入")
 await walk_goal("l_sign",Vector3(0,3.55,4.5),"后房调查先经实际门洞，不指向隔墙")
 await walk_goal("l_locked_402",Vector3(1.55,12.75,9.4),"目标在楼下时引导沿折返楼梯下降")
 clear();story.progress.power=0;story.sync_power_feedback()
 check(story.power_caption.text.contains("未隔离") and not story.pump.playing,"初始电路显示红灯状态，泵未运行")
 story.power_action(2)
 check(story.progress.power==0 and story.power_caption.text.contains("未隔离"),"错误送电后显示跳闸并恢复可重试状态")
 story.power_action(1)
 check(story.power_caption.text.contains("已隔离") and not story.pump.playing,"隔离后黄灯亮，未提前启动水泵")
 story.power_action(2)
 check(story.pump.playing and story.power_caption.text.contains("泵已通电"),"接通后绿灯与真实水泵声音同步")
 clear();game.laundry.interact("c1_valve")
 check(story.flag("drained") and story.power_caption.text.contains("排水完成"),"开阀后控制盘反馈排水完成")
 clear();story.progress.night=1
 check(story.shift_summary().contains("今晚已确认") and story.shift_summary().contains("下一班先做") and story.shift_summary().contains("402"),"第一夜交班说明已确认、待核实与明晚首个行动")
 story.progress.night=2
 check(story.shift_summary().contains("去向仍待查") and story.shift_summary().contains("502"),"第二夜总结保留孩子去向未明，并引到502")
 story.progress.power=1;story.sync_power_feedback();clear()
 var saved=preload("res://scripts/case_save.gd").capture(game)
 check(preload("res://scripts/case_save.gd").restore(game,saved),"新增反馈不影响现有现场存档")
 story=game.laundry.campaign
 check(story.power_caption.text.contains("已隔离") and not story.pump.playing,"读档恢复电路指示与水泵声音状态")
 game.field_kit.generation+=1;game._discard_laundry();game.queue_free()
 await process_frame;await process_frame
 print("RESULT: %d passed / %d failed"%[passed,failed]);quit(0 if failed==0 else 1)
