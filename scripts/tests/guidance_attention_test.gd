extends SceneTree
## Real campaign UI/session checks; no route driving or player-save writes.
var game
var story
var guide
var goal: Dictionary
var route: Dictionary
var position := Vector3(0,.06,9)
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("[PASS] ",label)
	else:
		failed += 1
		print("[FAIL] ",label)

func message_count() -> int:
	return game.phone_ui.messages.get("派遣科",[]).size()

func clear_attention() -> void:
	game.audio_system.stop_voice()
	game._clear_sub()
	game.choice = null
	game.dialog.clear()
	game.phone_open = false
	game.bag_open = false
	game.nb_open = false
	story.dialogue.cancel()
	if story.modal.visible:
		story.close_page()
	game.state = "play"

func blocked(label: String) -> void:
	var elapsed: float = guide.idle_seconds
	var messages := message_count()
	guide.track_progress(120,goal,route,position)
	guide._process(120)
	check(is_equal_approx(guide.idle_seconds,elapsed) and message_count()==messages,label+"不累计卡关时间、不发提醒")
	check(not guide.hint.visible and not guide.marker.visible,label+"不叠加现场导航")

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._hide_menu()
	game._start_prologue(false)
	game.field_kit.letter_accepted=true
	game.field_kit.phone_owned=true
	game.start_laundry_case()
	game.set_process(false)
	game.player.set_physics_process(false)
	story=game.laundry.campaign
	guide=story.guidance
	guide.set_process(false)
	game.director.set_process(false)
	clear_attention()
	game.player.global_position=position
	var before := message_count()
	for index in range(5):
		guide.sync_goal(story.goal("l_price","重复提示测试"+str(index),"当前HUD已有目标"))
	check(message_count()==before,"连续完成动作目标不再逐物件推送短信")
	var goal_ids := 0
	for id in game.director.sent:
		if String(id).begins_with("goal_"):
			goal_ids+=1
	check(goal_ids==0,"目标同步不再写入goal_短信标记")
	game.director.accepted()
	check(game.director.sent.has("accepted") and game.director.sent.has("job") and game.director.sent.has("rules"),"导演的重要入职、派遣与须知短信保留")
	var important_count := message_count()
	game.director.accepted()
	check(message_count()==important_count,"导演重要短信仍保持一次性")
	clear_attention()
	goal=story.current_goal()
	route=guide.route_for(goal,position)
	check(goal.mode=="act" and not route.is_empty(),"真实第一夜目标仍有可用路线")
	guide.track_progress(0,goal,route,position)
	guide.track_progress(17.25,goal,route,position)
	check(is_equal_approx(guide.idle_seconds,17.25),"正常站定仍累计实际调查时间")
	story.show_page("阅读计时验证","玩家正在看信件")
	blocked("案卷阅读")
	clear_attention()
	game._show_sub("许砚","这里只是静默字幕。",2,false)
	game.audio_system.stop_voice()
	check(not game.sub_pause and not game.audio_system.is_busy(),"建立没有语音也不暂停移动的单条字幕")
	blocked("单条静默字幕")
	clear_attention()
	game.sub_pause=true
	blocked("暂停字幕标志")
	clear_attention()
	game.sub_queue.append({"who":"许砚","text":"尚未显示的一句"})
	blocked("待显示字幕队列")
	clear_attention()
	game.choice={"text":"选择中"}
	blocked("选择界面")
	clear_attention()
	game.dialog.append({"text":"旧对话队列"})
	blocked("旧对话会话")
	clear_attention()
	story.dialogue.play([["周秀兰","先听完这句话。"]])
	blocked("现场对话")
	game.state="play"
	story.dialogue.panel.visible=false
	blocked("仍active但面板暂时隐藏的对话")
	clear_attention()
	for property in ["phone_open","bag_open","nb_open"]:
		game.set(property,true)
		blocked(property)
		clear_attention()
	game.audio_system.speak_dialogue("zhou_intro")
	check(game.audio_system.is_busy(),"Dummy音频驱动下仍可检查真实语音会话状态")
	blocked("语音会话")
	clear_attention()
	check(is_equal_approx(guide.idle_seconds,17.25),"长时间阅读和对话后保留原实际停滞时长")
	guide._process(0)
	check(guide.hint.visible,"回到现场后导航自动恢复")
	guide.idle_seconds=0
	guide.track_progress(44.9,goal,route,position)
	guide._process(0)
	check(not guide.hint.text.ends_with(" · "+String(route.text)),"45秒之前不展开额外路线")
	guide.track_progress(.2,goal,route,position)
	guide._process(0)
	check(guide.hint.text.ends_with(" · "+String(route.text)),"实际停滞45秒仍展开路线")
	before=message_count()
	guide.track_progress(44.8,goal,route,position)
	check(message_count()==before,"未达90秒不发卡关短信")
	guide.track_progress(.2,goal,route,position)
	guide.track_progress(200,goal,route,position)
	check(message_count()==before+1,"90秒卡关仅补一条短信，继续停滞不重复")
	var closer := position.move_toward(route.pos,1.1)
	guide.track_progress(1,goal,route,closer)
	check(guide.idle_seconds==0,"向目标推进仍重置停滞计时")
	var event := InputEventKey.new()
	event.physical_keycode=KEY_H
	event.pressed=true
	guide._input(event)
	check(story.modal.visible and story.heading.text=="当前调查提示" and story.body.text.contains("怎么走"),"H仍立即展开目标、原因和路线")
	clear_attention()
	game.field_kit.generation+=1
	game._discard_laundry()
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d passed / %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
