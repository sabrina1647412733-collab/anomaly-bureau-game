extends Node
## The second dispatch shares the existing player, bag, phone, clock and saves.
## Campaign owns story flags; this controller owns scene transitions/lifecycle.
var game
var campaign
var world
var companion
var active := false
var in_residence := false
var clock_minutes := 2640.0
var continuation: Button
var last_goal := ""
var changing_scene := false
var navigation

func setup(g) -> void:
	game=g
	var layer:=CanvasLayer.new();layer.layer=35;add_child(layer)
	var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(root)
	continuation=game.phone_ui.btn(root,"次日 · 接续派遣  [ E ]",Vector2(590,790),Vector2(420,58),continue_action,Color("3c6156"))
	continuation.visible=false
	navigation=preload("res://scripts/case2_navigation.gd").new();add_child(navigation);navigation.setup(self)

func ensure_campaign() -> bool:
	if is_instance_valid(campaign):return true
	var path:="res://scripts/case2/case2_campaign.gd"
	if not ResourceLoader.exists(path):return false
	campaign=load(path).new();add_child(campaign);campaign.setup(game,world)
	campaign.dialogue.speaker_resolver=dialogue_speaker
	campaign.request_departure.connect(enter_residence)
	campaign.exit_requested.connect(return_to_town)
	campaign.completed.connect(game.finish_case2)
	return true

func dialogue_speaker(who:String)->Dictionary:
	if who=="阿七" and not in_residence and is_instance_valid(companion):
		return {"at":companion.global_position+Vector3(0,1.3,0),"actor":companion}
	if in_residence and is_instance_valid(world) and world.has_method("get_speaker"):
		return world.get_speaker(who)
	return {"at":Vector3.INF,"actor":null}

func ensure_world() -> bool:
	if is_instance_valid(world):return true
	var path:="res://scripts/case2/case2_world.gd"
	if not ResourceLoader.exists(path):return false
	world=load(path).new();game.add_child(world);world.setup(game)
	return true

func begin() -> void:
	if active or changing_scene:return
	if not ensure_campaign():
		game.feedback.notify("第二案资源尚未就绪","请先完成工程资源导入，再接续派遣。")
		return
	game.series.case1_complete=true
	game._discard_laundry()
	game._hide_menu();game._start_prologue(false)
	game._clear_sub();game.audio_system.stop_voice();game.audio_system.ring.stop()
	game.phone_ui.incoming=false;game.phone_ui.call_active=false
	game.prologue_call_done=true;game.prologue_letter_ready=false;game.envelope_taken=true
	game.field_kit.letter_accepted=true;game.field_kit.phone_owned=true
	for item in [["phone","手机"],["weird_clock","诡异时钟"],["permcard","录名权限卡"]]:
		if not game.bag_has(item[0]):game.bag_add(item[0],item[1])
	active=true;in_residence=false;clock_minutes=2640.0
	game.series.case2_started=true;game.series.chapter="00201"
	game.director.room_minutes=clock_minutes;game.clock_min=clock_minutes
	game.state="prologue";game._show_prologue_stage("room")
	game.hud_end.text="";game.hud_end_title.text="";game.hud_fade.modulate.a=0.
	if game.case_end_backdrop!=null:game.case_end_backdrop.visible=false
	continuation.visible=false
	make_companion()
	campaign.begin()
	game.field_kit.sync_world();game.safety.reset_zone()
	update_goal()

func make_companion() -> void:
	if is_instance_valid(companion):companion.queue_free()
	companion=preload("res://scripts/laundry/char_actor.gd").make(game,"aqi",Vector3(-.85,12.1,320.05),0.)
	if companion!=null:
		companion.name="Case2_Aqi"
		companion.face_point(Vector3(-.35,12.1,323.05))

func room_spots() -> Array[Dictionary]:
	if not active or in_residence:return []
	var points:Array[Dictionary]=[]
	if is_instance_valid(companion):points.append({"id":"c2_aqi","pos":companion.global_position+Vector3(0,1.12,0),"r":2.5,"label":"与门边的阿七交谈"})
	for point in game.prologue_spots:
		if point.id=="door" and point.stage=="room":points.append({"id":"door","pos":point.pos,"r":point.r,"label":"开门前往回潮镇"})
	return points

func street_target() -> String:
	if not active or campaign==null:return "01"
	if bool(game.series.get("case2_complete",false)):return "04"
	return "10" if campaign.flag("orphanage_done") else "07"

func interact(id: String) -> bool:
	if not active:return false
	if id=="01" and game.prologue_stage=="town":
		game.feedback.notify("第一案夜班已归档","当前派遣是00201。"+("可在回潮镇自由走动，下一份派遣尚未开始。" if campaign.flag("case_complete") else String(campaign.current_goal().text)))
		return true
	if id=="door" and game.prologue_stage=="room":
		if not campaign.flag("coop_done"):
			game.feedback.blocked("c2_cooperation","先听阿七说完","她正等在门边。","先确认一起调查，再带着归还的地址出门。",game.player.global_position)
			return true
		game._leave_room_to_town()
		return true
	if id=="07" and game.prologue_stage=="town":return campaign.interact("c2_orphanage")
	if id=="10" and game.prologue_stage=="town":
		if campaign.flag("case_complete"):
			game.feedback.notify("槐安住宅处置完成","00201已归档，后续派遣来自老公交站。当前没有新的出镇任务。")
			return true
		return campaign.interact("c2_depart")
	if id.begins_with("c2_"):return campaign.interact(id)
	return false

func enter_residence() -> void:
	if not active or changing_scene:return
	changing_scene=true
	if not ensure_world():changing_scene=false;return
	if campaign.modal.visible:campaign.close_page()
	campaign.dialogue.cancel();game._clear_sub();game.audio_system.stop_voice()
	if game.town_bridge.active:game.town_bridge.leave()
	for root in game.prologue_roots.values():root.visible=false
	if is_instance_valid(companion):companion.visible=false
	game.case_mode="case2";game.prologue_stage="";game.state="play"
	game._apply_laundry_environment(true)
	world.set_active(true)
	campaign.bind_world(world)
	game.spots=campaign.spots()
	in_residence=true
	game.player.global_position=world.get_floor_spawn(1)
	game.player.velocity=Vector3.ZERO;game.player.rotation.y=PI
	game.player.pitch=0;game.player.cam.rotation=Vector3.ZERO
	game.player.physics_frozen=false;game.player.can_move=true;game.player.allow_capture=true
	game.player.cam.current=true;game.hud_fade.modulate.a=0.
	game.clock_min=clock_minutes;game.safety.reset_zone()
	changing_scene=false
	campaign.on_arrival();update_goal()

func return_to_town() -> void:
	if not active or not in_residence:return
	if campaign.modal.visible:campaign.close_page()
	campaign.dialogue.cancel();game.audio_system.stop_voice();game._clear_sub()
	world.set_active(false)
	in_residence=false;game.case_mode="";game.state="prologue"
	game.town_bridge.enter()
	var place:Dictionary=game.town_bridge._landmark("10")
	game.player.global_position=game.town_bridge.ORIGIN+Vector3(float(place.front[0])+1.6,.12,float(place.front[1]))
	game.director.room_minutes=clock_minutes;game.safety.reset_zone();update_goal()

func update_goal() -> void:
	if not active or not is_instance_valid(campaign):return
	var goal:Dictionary=campaign.current_goal()
	var text:=String(goal.get("text","继续调查"))
	if campaign.flag("case_complete") and not in_residence:text="第二案已归档，可在回潮镇走动。末班4路派遣已收入手机，下一案尚未开始。"
	if game.case_mode=="case2":
		if game.case_objective!=text:game.set_case_objective(text)
	elif game.state=="prologue" and game.prologue_objective!=text:game._prologue_set_objective(text)
	last_goal=text

func recovery_anchor() -> Vector3:
	if not is_instance_valid(world):return Vector3(1200,.08,0)
	var level:=clampi(int(round((game.player.global_position.y-world.global_position.y)/3.0))+1,1,17)
	if level==17 and not campaign.flag("seventeen_open"):level=16
	return world.get_floor_spawn(level)

func step(delta: float) -> void:
	var can_continue:bool=game.state=="case_end" and game.case_mode=="laundry" and game.laundry!=null and game.laundry.selected_ending=="A" and not active
	var can_return:bool=active and is_instance_valid(campaign) and campaign.flag("case_complete") and game.state=="case_end"
	continuation.visible=can_continue or can_return
	continuation.text="返回回潮镇  [ E ]" if can_return else "次日 · 接续派遣  [ E ]"
	if not active or not is_instance_valid(campaign):return
	var map_open:bool=game.town_bridge!=null and game.town_bridge.town_map.big_open
	if game.state in ["play","prologue"] and not map_open and not game.phone_open and not game.bag_open and not game.nb_open and game.choice==null and not game.sub_pause and game.sub=="" and game.sub_queue.is_empty() and not game.audio_system.is_busy():
		clock_minutes+=delta*game.director.RATE/60.
	game.clock_min=clock_minutes
	campaign.step(delta)
	if game.state in ["play","prologue"]:update_goal()
	if is_instance_valid(companion):companion.visible=not in_residence and game.prologue_stage=="room" and game.state!="menu"

func capture() -> Dictionary:
	return {"version":1,"active":active,"in_residence":in_residence,"clock_minutes":clock_minutes,"campaign":campaign.capture() if is_instance_valid(campaign) else {}}

func restore(data: Dictionary) -> bool:
	if int(data.get("version",0))!=1 or not data.get("campaign") is Dictionary:return false
	var value=data.get("clock_minutes",2640.)
	if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)):return false
	active=bool(data.get("active",true));in_residence=bool(data.get("in_residence",false));clock_minutes=float(value)
	if not ensure_campaign():return false
	if in_residence:
		if not ensure_world():return false
		campaign.bind_world(world);world.set_active(true)
		for root in game.prologue_roots.values():root.visible=false
		game.case_mode="case2";game.prologue_stage="";game._apply_laundry_environment(true)
	else:
		game.case_mode=""
		make_companion()
	if not campaign.restore(data.campaign):return false
	if in_residence:game.spots=campaign.spots()
	game.director.room_minutes=clock_minutes;game.clock_min=clock_minutes
	return true

func reset() -> void:
	active=false;in_residence=false;changing_scene=false;last_goal=""
	if is_instance_valid(campaign):campaign.cancel();campaign.queue_free()
	if is_instance_valid(world):world.queue_free()
	if is_instance_valid(companion):companion.queue_free()
	campaign=null;world=null;companion=null
	if continuation!=null:continuation.visible=false

func _input(event: InputEvent) -> void:
	if continuation!=null and continuation.visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E:
		continue_action();get_viewport().set_input_as_handled()

func continue_action()->void:
	if active and is_instance_valid(campaign) and campaign.flag("case_complete"):
		return_to_town()
		game.hud_end.text="";game.hud_end_title.text="";game.hud_fade.modulate.a=0.
		if game.case_end_backdrop!=null:game.case_end_backdrop.visible=false
	else:begin()
