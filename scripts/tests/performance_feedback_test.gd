extends SceneTree
var game
var story
var passed:=0
var failed:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if ok:passed+=1;print("[PASS] ",label)
	else:failed+=1;push_error("FAIL "+label)
func clear():
	game.audio_system.stop_voice();game._clear_sub()
	if story.modal.visible:story.close_page()
	game.feedback.reset()
func act(id:String):
	clear();game.laundry.interact(id)
func denied(id:String,text:String):
	check(game.feedback.last_denied.get("id")==id and game.feedback.last_denied.get("detail","").contains(text),id+" 给出原因和下一步")
	check(game.state=="play" and not story.modal.visible,id+" 失败反馈不强制打开阅读页")
func run():
	create_timer(100).timeout.connect(func():quit(2))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false)
	game.field_kit.letter_accepted=true;game.start_laundry_case()
	game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false)
	game.feedback.set_process(false);story=game.laundry.campaign;clear()
	act("l_backdoor");denied("l_backdoor","03:40")
	check(not game.laundry.back_open,"无钥匙不改变后房门状态")
	var count=game.audio_system.get_child_count()
	game.laundry.interact("l_backdoor")
	check(game.audio_system.get_child_count()==count,"重复按交互不会叠加失败音效")
	clear();game._show_sub("旁白","正在观察的句子",2.,false)
	game.laundry.interact("c1_drawer")
	check(game.sub=="正在观察的句子","失败反馈不覆盖现有剧情字幕")
	clear();game.field_kit.held_id="mail_key"
	game.laundry.interact("l_m7");denied("l_m7","用途不符")
	check(not game.laundry.has_clue("sweater"),"错误钥匙不提前取得原衣")
	for pair in [["c1_drawer","402"],["lb_box503","信箱"],["c1_keybox","403"],["l_locked_503","502"],["l_locked_401","无需进入401"],["lb_elev","楼梯"],["c1_tools","402"],["c1_valve","隔离"],["c1_ladder","排水"],["c1_sandal","检修梯"]]:
		act(pair[0]);denied(pair[0],pair[1])
	clear();story.climb_skylight(true);denied("skylight","管线图")
	check(not game.feedback.current.is_empty(),"失败原因立即进入独立反馈卡")
	clear();story.power_action(2)
	check(story.progress.power==0 and game.feedback.last_denied.get("id")=="power_order","不安全送电跳闸并明确指出顺序")
	clear();story.power_action(1);story.power_action(2);story.power_action(2)
	check(story.progress.power==2,"已运转的泵重复送电不会错误复位")
	act("c1_valve");var water:float=game.laundry.buildings.b1.water.position.y
	act("c1_valve");story.power_action(1)
	check(story.progress.power==3 and story.flag("drained") and game.laundry.buildings.b1.water.position.y==water,"完成排水后重复阀门或电盘保持安全状态")
	clear();game.laundry._claim("machine_key");game.bag_add("machine_key","七号机专用钥匙")
	game.field_kit.held_id="mail_key";game.laundry.interact("l_m7")
	check(game.laundry.has_clue("sweater"),"正确钥匙在包内时自动使用，无需强制手持")
	clear();var profiles:Dictionary=game.audio_system.voice_profiles
	check(profiles.size()==30,"30句配音有停顿与表演数据")
	for id in profiles:
		var profile:Dictionary=profiles[id];var clip:AudioStream=load("res://assets/audio/performance/"+id+".wav")
		check(clip!=null and absf(clip.get_length()-float(profile.seconds))<.03 and profile.envelope.size()>0,"配音和音量包络时长匹配："+id)
	game.laundry._spawn_lady(false)
	for actor in [game.laundry.lady,game.laundry.cast.laozhou,game.laundry.cast.aqi]:
		var face=actor.performance;face.set_process(false)
		check(face!=null and face.visual.mesh.get_blend_shape_count()==4,"四种独立面部形变："+actor.who)
		var mesh:Mesh=face.visual.mesh;var base:Array=mesh.surface_get_arrays(0)
		var blend:Array=mesh.surface_get_blend_shape_arrays(0)[0]
		var stable=true;var weights=true
		for i in range(0,base[Mesh.ARRAY_VERTEX].size(),31):
			if base[Mesh.ARRAY_VERTEX][i].y<1.0 and base[Mesh.ARRAY_VERTEX][i]!=blend[Mesh.ARRAY_VERTEX][i]:stable=false
			var sum=0.
			for j in 4:sum+=base[Mesh.ARRAY_WEIGHTS][i*4+j]
			if absf(sum-1.)>.003:weights=false
		check(stable and weights,"面部形变保持下身和归一化蒙皮："+actor.who)
		face.begin_voice(game.audio_system.spatial_voice,profiles.lady_thankyou)
		var values:Array=profiles.lady_thankyou.envelope;var peak=0
		for i in values.size():
			if values[i]>values[peak]:peak=i
		face.update_pose(.2,float(peak)/50.,true)
		check(face.mouth>0 and face.mouth<=.5 and face.relief>0,"响度驱动克制口型与释然表情："+actor.who)
		face.update_pose(.2,0,false)
		check(face.mouth==0,"音频停顿时闭口："+actor.who)
		face.update_pose(.2,float(peak)/50.,true);face.end_voice()
		check(face.mouth==0 and not face.speaking,"打断声音立即释放说话状态："+actor.who)
		actor.ap.pause();face.nod=.02;face.tilt=0
		var sk:Skeleton3D=actor.model.find_child("Skeleton3D",true,false)
		var head:int=sk.find_bone("mixamorig_Head")
		var base_rotation:Quaternion=sk.get_bone_pose_rotation(head)
		for frame in 12:await process_frame
		check(base_rotation.angle_to(sk.get_bone_pose_rotation(head))<.08,"头部叠加姿态不逐帧累积旋转："+actor.who)
		face.reset_pose();actor.ap.play()
	var lady=game.laundry.lady
	game.audio_system.speak_dialogue("lady_thankyou",lady.global_position,lady)
	check(lady.performance.speaking and game.audio_system.performance_actor==lady,"现场角色与实际声音播放器绑定")
	game._open_pause();var before:float=lady.performance.elapsed
	lady.performance._process(.5)
	check(lady.performance.elapsed==before and lady.ap.speed_scale==0,"暂停同时冻结面部与角色动作")
	game._on_resume();lady.performance._process(.01)
	check(lady.ap.speed_scale>0,"恢复后角色动画继续")
	game.audio_system.stop_voice()
	check(not lady.performance.speaking and lady.performance.mouth==0,"停止声音不留下张嘴状态")
	clear();story.speak([["周秀兰","齐了。终于齐了。","lady_complete"],["许砚","许砚。","xu_myname"]],Callable(),lady)
	check(story.dialogue.remaining<1. and lady.performance.speaking,"句间使用独立停顿，不再按字数额外等待数秒")
	story.dialogue.advance()
	check(not lady.performance.speaking and game.audio_system.performance_actor==null,"主角答话时NPC不继续对口型")
	story.dialogue.finish(false)
	print("PERFORMANCE_FEEDBACK_RESULT PASS=",passed," FAIL=",failed)
	game.queue_free();await process_frame;call_deferred("quit",1 if failed else 0)
