extends SceneTree
var game
var passed:=0
var failed:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func bone(actor,name:String)->Vector3:
	var sk:Skeleton3D=actor.model.find_child("Skeleton3D",true,false)
	return actor.global_transform.affine_inverse()*sk.global_transform*sk.get_bone_global_pose(sk.find_bone("mixamorig_"+name)).origin
func pose(actor,clip:String,time:float):
	actor.ap.play(clip,0);actor.ap.seek(time,true);actor.ap.advance(0);actor.ap.pause()
func run():
	create_timer(80).timeout.connect(func():quit(2))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false);game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false)
	var audio=game.audio_system
	check(audio.music_target()=="room_theme","出租屋使用低强度独立配乐")
	for id in ["rain_inside","rain_outside","washer_loop","room_theme","depth_theme","suspense_theme","memory_theme","lightless_dawn"]:
		var sound=audio.stream(id,true)
		check(sound!=null and sound.get_length()>8,"循环音频完整："+id)
		check(sound.loop,"循环属性实际启用："+id)
	var wav:AudioStreamWAV=audio.stream("pump_motor",true)
	check(wav.loop_end==int(round(wav.get_length()*wav.mix_rate)),"WAV循环使用采样帧长度，兼容立体声与压缩导入")
	check(FileAccess.get_file_as_string("res://assets/audio/finish/credits.txt").contains("Kevin MacLeod"),"游戏内可读取配乐作者与许可")
	game.field_kit.letter_accepted=true;game.start_laundry_case();var lc=game.laundry
	check(audio.music_target()=="lightless_dawn","调查现场使用已署名配乐")
	game.player.global_position.y=-2.;check(audio.music_target()=="depth_theme","进入地下自动切换低频氛围")
	game.player.global_position.y=3.5;lc.fired.count=true
	check(audio.music_target()=="suspense_theme","数衣事件进入紧张配乐")
	lc.campaign.mark("recognized");check(audio.music_target()=="memory_theme","原衣认领后进入收束配乐")
	audio.change_music("room_theme");audio._process(.2);var cursor=audio.music.get_playback_position()
	audio.speak_dialogue("lady_wait",Vector3(0,4.5,4))
	await physics_frame;await process_frame
	game.state="paused";audio._process(.2)
	await physics_frame;await process_frame
	check(audio.music.stream_paused and audio.atmosphere.stream_paused and audio.spatial_voice.stream_paused,"暂停同时停住配乐、环境声和角色对白")
	check(audio.music.get_playback_position()>=cursor,"暂停不会重新从头播放音乐")
	game.state="play";audio._process(.2);check(not audio.music.stream_paused,"恢复后声音继续播放")
	audio.blend=1.;audio._process(1.)
	check(audio.music.volume_db<=-30.,"人物讲话时配乐主动降低")
	audio.stop_voice();audio._process(1.)
	check(audio.music.volume_db>=-29.,"对白结束后配乐恢复正常层级")
	lc.spinning={7:true};audio.sync_machines(true)
	check(audio.machine_sources[7].playing and not audio.machine_sources[1].playing,"只有实际运转的机器发出空间声音")
	lc.spinning[7]=false;audio.sync_machines(true);check(not audio.machine_sources[7].playing,"停机后机体声音同步停止")
	for actor in [lc.cast.laozhou,lc.cast.aqi]:
		pose(actor,"Idle",0)
		var torso=bone(actor,"Hips")
		check(bone(actor,"LeftHand").z>torso.z-.18 and bone(actor,"RightHand").z>torso.z-.18,actor.who+"站姿双臂不后折")
	lc._spawn_lady(false);lc.night._do_sit();lc.night.lady_state="sit"
	await create_timer(.8).timeout
	var lady=lc.lady;lady._apply_seat_offset_instant()
	for t in [0.,1.,2.,3.]:
		pose(lady,"SitIdle",t)
		var hip=bone(lady,"Hips");var left=bone(lady,"LeftFoot");var right=bone(lady,"RightFoot")
		check(hip.y>.52 and hip.y<.75,"坐姿骨盆在座面上方："+str(t))
		check(minf(left.y,right.y)>.06 and maxf(left.y,right.y)<.17,"坐姿脚踝高度稳定："+str(t))
		check(bone(lady,"LeftHand").z>hip.z and bone(lady,"RightHand").z>hip.z,"坐姿双手位于身体前侧："+str(t))
	lc._show_aqi_on_bench();await create_timer(.8).timeout
	var aqi=lc.cast.aqi;aqi._apply_seat_offset_instant();pose(aqi,"SitIdle",0)
	var seat:Vector3=aqi.global_transform*bone(aqi,"Hips")
	check(seat.x>1.75 and seat.x<2.2,"阿七尾声坐在实体长椅上，没有沿用旧的悬空位置")
	game.field_kit.generation+=1;game._discard_laundry();game.queue_free();await process_frame;await process_frame
	print("FINISH_AUDIO_RESULT PASS=%d FAIL=%d"%[passed,failed])
	# Let the coroutine release its local AudioStream references before engine shutdown.
	call_deferred("quit",0 if failed==0 else 1)
