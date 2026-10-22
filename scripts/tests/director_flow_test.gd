extends SceneTree
## 手机、任务先后关系、时钟门控、现场配音与新动作的回归。
var game
var passed:=0
var failed:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("[PASS] ",label)
 else:failed+=1;print("[FAIL] ",label)
func clear():
 game.audio_system.stop_voice();game._clear_sub()
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame
 game.set_process(false);game.player.set_physics_process(false)
 game._hide_menu();game._start_prologue(false)
 var kit=game.field_kit;var phone=game.phone_ui;var director=game.director
 game._ring_phone();kit.pickup_phone()
 check(phone.caller=="房东" and phone.call_text.contains("2160"),"开场来电为房东催租")
 kit.answer_phone();phone._goto("in_call")
 await process_frame
 await process_frame
 check(phone.call_active and game.audio_system.voice.playing and not game.audio_system.ring.playing,"接听停铃并播放催租配音")
 check(game.sub=="" and game.hud_sub.text=="","通话不在手机屏幕外重复字幕")
 check(phone.screen.clip_contents,"手机应用内容裁剪到屏幕")
 var captions_ok=true
 for node in phone.screen.get_children():
  if node is Label and node.text==phone.call_text:captions_ok=node.position.x>=0 and node.position.y+node.size.y<=phone.screen.size.y and node.position.x+node.size.x<=phone.screen.size.x
 check(captions_ok,"通话文字边界位于手机屏幕内")
 check(not phone.messages.has("派遣科"),"未接受通知书前事务局不联系")
 game._close_phone()
 check(not game.audio_system.is_busy() and not phone.call_active,"关手机立即终止通话声音")
 await create_timer(1.1).timeout
 check(game.prologue_letter_ready and game.prologue_envelope.visible,"挂断后敲门并出现门下信封")
 check(not phone.messages.has("派遣科"),"门下信封未接受时仍无事务局消息")
 kit.stow();clear()
 var before:float=director.now();director.step(60)
 check(is_equal_approx(director.now()-before,10),"现实一分钟等于游戏十分钟")
 game._pick_envelope();game._refuse_envelope()
 await create_timer(3.6).timeout
 check(game.prologue_envelope.visible and game.prologue_envelope.position.is_equal_approx(kit.desk_letter_position),"拒绝后的第二封有桌面实体")
 game._pick_envelope()
 check(not kit.refuse_button.visible,"第二封只有同意")
 game._accept_envelope()
 check(kit.letter_accepted and game.bag_has("envelope"),"同意后收入背包")
 check(phone.messages.has("派遣科") and phone.messages["派遣科"][0].contains("恭喜入职"),"先收到入职恭喜，再收到派遣任务")
 check(phone.messages["派遣科"].size()==3 and phone.messages["派遣科"][1].contains("800") and phone.messages["派遣科"][2].contains("交接簿"),"随后发送工作时间报酬及注意事项")
 await create_timer(.9).timeout
 kit.pickup_clock();director.close_clock(true);clear()
 check(game.bag_has("weird_clock") and not game.wclock.visible,"时钟可入包且世界实物消失")
 kit.open_inventory(true)
 check(kit.grid.columns==6 and kit.grid.get_child_count()==24,"背包为六乘四方格")
 kit.open_inventory(false);clear()
 var save=preload("res://scripts/case_save.gd").capture(game)
 check(preload("res://scripts/case_save.gd").restore(game,save),"时间消息与入职状态可读档")
 var old=save.duplicate(true);old.field_items.letter_accepted=false
 old.bag=old.bag.filter(func(item):return item.id!="envelope")
 check(preload("res://scripts/case_save.gd").restore(game,old) and not phone.messages.has("派遣科"),"旧档未接受入职时清除过早派遣消息")
 preload("res://scripts/case_save.gd").restore(game,save)
 game.start_laundry_case();game.set_process(false);game.player.set_physics_process(false);clear()
 var lc=game.laundry;var story=lc.campaign
 check(story.current_goal().id=="lb_booth","进入洗衣楼首目标明确为一楼签到")
 lc.t=200*60;lc._timeline()
 check(lc.t<=20*60 and not lc.fired.has("oldlady"),"未完成新手调查不会错过来客")
 for id in ["lb_booth","l_price","l_m9","l_m7"]:
  if story.modal.visible:story.close_page()
  clear();lc.interact(id)
 if story.modal.visible:story.close_page()
 clear();lc.t=0
 check(story.current_goal().id=="c1_broadcast","签单调查后提示留店听广播")
 director.open_clock();director.next_event()
 check(lc.fired.has("bc1") and is_equal_approx(lc.t,21*60),"跳时停在第一遍广播")
 check(game.audio_system.is_busy() and is_equal_approx(float(story.next_event()[0]),1420+lc.t/60),"对白未听完时禁止连续跳过事件")
 var time_before:float=lc.t;lc.step(60)
 check(is_equal_approx(lc.t,time_before),"播放配音时现场时间暂停")
 clear();director.open_clock();director.advance(1000)
 check(lc.fired.has("bc2") and is_equal_approx(lc.t,40*60) and not lc.fired.has("oldlady"),"大幅跳时也只到下一事件")
 clear();director.open_clock();director.next_event()
 check(lc.lady!=null and lc.t==90*60,"来客按时间出现")
 lc.night._do_sit();lc.night.lady_state="sit";clear()
 story.lady_talk()
 check(game.state=="case_dialogue" and story.dialogue.panel.visible and not game.player.can_move,"人物交谈有独立逐句对话并冻结移动")
 check(game.audio_system.spatial_voice.playing or game.audio_system.voice.playing,"人物对白有真实声音流")
 while story.dialogue.panel.visible:story.dialogue.advance()
 check(story.flag("met_lady") and game.state=="play" and game.player.can_move,"听完对话才更新任务并恢复操作")
 clear();lc.t=210*60;lc._timeline()
 check(lc.lady.current=="SitIdle","数衣服维持坐姿，避免切换站立动作穿椅")
 var actor=game.player.body.get_node("XuYan3D")
 for clip in ["jump_start","jump_loop","jump_land","crouch_down","crouch_idle","crouch_walk","crouch_up"]:
  var animation=actor.animator.get_animation("town/"+clip)
  check(animation!=null and animation.get_track_count()==actor.skeleton.get_bone_count()*3,"完整映射原骨架坐标轴修正动作："+clip)
  check(animation.loop_mode==(Animation.LOOP_LINEAR if clip in ["jump_loop","crouch_idle","crouch_walk"] else Animation.LOOP_NONE),"动作循环属性："+clip)
  animation=null
 clear();game.player.global_position=Vector3(0,3.52,7)
 var ceiling=StaticBody3D.new();lc.world.add_child(ceiling)
 var col=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2,.12,2);col.shape=box;ceiling.add_child(col);ceiling.position=Vector3(0,5.12,7)
 await physics_frame
 check(not game.player.can_stand(),"低顶下禁止强制站起穿模")
 ceiling.queue_free();await physics_frame;await physics_frame
 check(game.player.can_stand(),"离开低顶可正常站起")
 check(game.player.SPEED_CROUCH==.58 and game.player.EYE_CROUCH==1.2,"蹲行速度与动作及视线高度匹配")
 box=null;col=null;ceiling=null;actor=null
 kit.generation+=1;game._discard_laundry();game.queue_free()
 await process_frame;await process_frame
 print("RESULT: %d passed / %d failed"%[passed,failed]);quit(0 if failed==0 else 1)
