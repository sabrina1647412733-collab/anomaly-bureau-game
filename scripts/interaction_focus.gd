extends Node
## 由屏幕中心射线选一个目标；距离只限制触及范围，不负责自动选邻近物件。
var game
var dot: Control
var selected := false

class AimDot extends Control:
	var active := false
	var blocked := false
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 4.5, Color(0,0,0,.65))
		draw_circle(Vector2.ZERO, 2.1, Color("e39d7c") if blocked else (Color("edc687") if active else Color(.9,.94,.91,.85)))
		if active: draw_arc(Vector2.ZERO, 8, 0, TAU, 32, Color("edc687"), 1.3, true)

func setup(g) -> void:
	game=g
	var layer=CanvasLayer.new();layer.layer=7;add_child(layer)
	dot=AimDot.new();dot.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(dot)

func available() -> bool:
	if game.town_bridge!=null and game.town_bridge.active and game.town_bridge.town_map.big_open:return false
	return game.state in ["play","prologue"] and not game.bag_open and not game.phone_open and not game.nb_open and game.choice==null

func _process(_delta: float) -> void:
	dot.visible=available()
	dot.position=game.get_viewport().get_visible_rect().size*.5
	dot.active=game.prompt!=null and available()
	dot.blocked=float(Time.get_ticks_msec())*.001<game.feedback.denied_until
	dot.queue_redraw()

func radius_for(id: String) -> float:
	if id in ["c2_aqi","c2_guard","c2_he_door","c2_sun","c2_exit","c2_elevator","c2_intercom"]:return .52
	if id in ["c1_lady","lb_exit","door","l_backdoor","l_locked_402","l_locked_503","case_rest"]:return .48
	if id in ["phone","envelope","envelope2","wclock","c1_cert","c1_homework","c1_sandal","c1_shoe_room","c1_stones"]:return .15
	if id.begins_with("l_m"):return .35
	return .24

func aim_score(at: Vector3, reach: float, radius: float, origin: Vector3, direction: Vector3, occlusion:=true) -> float:
	if game.player.eye().distance_to(at)>reach:return -INF
	var t:float=(at-origin).dot(direction)
	if t<=0:return -INF
	var miss:float=(origin+direction*t).distance_to(at)
	if miss>radius:return -INF
	if occlusion:
		var query=PhysicsRayQueryParameters3D.create(origin,origin+direction*maxf(.01,t-radius-.12),1,[game.player.get_rid()])
		var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():return -INF
	return 1.0-miss/radius-t*.002

func select_target() -> Variant:
	if not available():return null
	if game.player.sitting:return {"kind":"stand","text":"站起来"}
	var cam:Camera3D=game.player.cam
	var center:Vector2=game.get_viewport().get_visible_rect().size*.5
	var origin=cam.project_ray_origin(center);var direction=cam.project_ray_normal(center)
	var candidates:Array=[]
	if game.state=="prologue" and game.prologue_stage=="town":
		var bridge=game.town_bridge
		for entry in bridge.layout.get("landmarks",[]):
			var front:Array=entry.get("front",[entry.get("x",0),entry.get("z",0)])
			var id=String(entry.get("id",""))
			var at:Vector3=bridge.ORIGIN+Vector3(float(front[0]),1.1,float(front[1]))
			candidates.append({"kind":"town","id":id,"text":"进入得利洗衣店" if id=="01" else ("回出租屋" if id=="02" else "查看"+String(entry.get("name","地点"))),"pos":at,"reach":3.3,"radius":.7})
		if bridge.residents != null:candidates.append_array(bridge.residents.interaction_candidates())
	elif game.state=="prologue" and game.case2_controller!=null and game.case2_controller.active:
		for point in game.case2_controller.room_spots():
			candidates.append({"kind":"spot","id":point.id,"text":point.label,"spot":point,"pos":point.pos,"reach":point.r,"radius":radius_for(point.id)})
	elif game.state=="prologue":
		for point in game.prologue_spots:
			if point.stage!=game.prologue_stage:continue
			var id=String(point.id)
			if id=="phone" and game.field_kit.phone_owned:continue
			if id=="wclock" and (not game.clock_appeared or game.bag_has("weird_clock")):continue
			if id.begins_with("envelope") and (not game.prologue_letter_ready or game.envelope_taken):continue
			# 两个信封入口共享同一实物，只保留当前出现的位置。
			if id=="envelope2":continue
			var at:Vector3=point.pos
			if id=="envelope":at=game.prologue_envelope.global_position+Vector3(0,.08,0)
			elif id=="phone":at=game.get_meta("phone_world_body").global_position+Vector3(0,.08,0)
			elif id=="wclock" and game.wclock!=null:at=game.wclock.root.global_position+Vector3(0,.3,0)
			candidates.append({"kind":"prologue","id":id,"text":game._prologue_label(point),"pos":at,"reach":point.r,"radius":radius_for(id)})
	elif game.case_mode=="case2" and game.case2_controller!=null and game.case2_controller.campaign!=null:
		for point in game.case2_controller.campaign.spots():
			if not point.get("enabled",true):continue
			var id:=String(point.id)
			candidates.append({"kind":"spot","id":id,"text":point.get("label",point.get("text","检查")),"spot":point,"pos":point.pos,"reach":point.r,"radius":radius_for(id)})
	elif game.case_mode=="laundry":
		for point in game.spots:
			var id=String(point.id)
			if id=="c1_lady" and (game.laundry.lady==null or not game.laundry.lady.visible):continue
			if id=="c1_towel" and not game.laundry.fired.has("beat14"):continue
			var at:Vector3=point.pos
			if id=="c1_lady":at=game.laundry.lady.global_position+Vector3(0,1.05,0)
			candidates.append({"kind":"spot","id":id,"text":point.label,"spot":point,"pos":at,"reach":point.r,"radius":radius_for(id)})
	var best:Variant=null;var score:float=-INF
	for item in candidates:
		var value=aim_score(item.pos,float(item.reach),float(item.radius),origin,direction)
		if value>score:score=value;best=item
	return best
