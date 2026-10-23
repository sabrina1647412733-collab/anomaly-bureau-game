extends Node3D
## Local neighbours: swept collision, authored short steps, existing story state.
const BASE := "res://assets/models/chars/street_residents/"
const REPLIES := preload("res://scripts/town/street_resident_dialogue.gd")
const DEFINITIONS := [
	{"id":"resident_shopkeeper","label":"电料店店主","model":"electrical_shopkeeper.glb","seed":551335,"side":1.4,"front":.42},
	{"id":"resident_woman","label":"附近住户","model":"female_resident.glb","seed":579349,"side":1.5,"front":.42},
]

class HeadLook extends SkeletonModifier3D:
	var driver: Node3D
	var head := -1
	func _process_modification() -> void:
		if not is_instance_valid(driver):return
		var sk := get_skeleton()
		if sk == null:return
		if head < 0:head=sk.find_bone("mixamorig_Head")
		if head < 0 or absf(driver.head_yaw)<.0001:return
		var world_basis := sk.global_basis*sk.get_bone_global_pose(head).basis
		var axis := world_basis.orthonormalized().inverse()*Vector3.UP
		sk.set_bone_pose_rotation(head,sk.get_bone_pose_rotation(head)*Quaternion(axis.normalized(),driver.head_yaw))

class Resident extends CharacterBody3D:
	var definition: Dictionary
	var animator: AnimationPlayer
	var skeleton: Skeleton3D
	var collider: CharacterBody3D
	var body_shape: CollisionShape3D
	var look: HeadLook
	var idle := ""
	var runtime: Dictionary = {}
	var head_yaw := 0.0
	var home_yaw := 0.0
	var home := Vector3.ZERO
	var tangent := Vector3.RIGHT
	var grounded := false
	var ready_model := false
	var route_clear := false
	var reply_cooldown := 0.0
	var activity := "idle"
	var phase := 0.0
	var wait_left := 7.0
	var route_index := 0
	var target_index := 1
	var turn_from := 0.0
	var turn_to := 0.0
	var after_turn := "idle"
	var walk_from := Vector3.ZERO
	var clip := ""
	var trips := 0
	var blocked_time := 0.0
	var last_context := ""
	var footsteps: AudioStreamPlayer3D
	var foot_index := 0

var town
var game
var actors: Array[Resident] = []
var active := false
var grounding_pending := false
var behaviour_enabled := true
var pending_restore: Dictionary = {}
var foot_streams: Array[AudioStream] = []

func setup(owner_town) -> void:
	town=owner_town;game=town.game;name="StreetResidents";town.add_child(self)
	for i in range(4):foot_streams.append(load("res://assets/audio/finish/step_tile%d.wav"%i) as AudioStream)
	var reports: Variant=JSON.parse_string(FileAccess.get_file_as_string(BASE+"preparation_manifest.json"))
	for definition in DEFINITIONS:
		var building: Dictionary={}
		for entry in town.layout.get("buildings",[]):
			if int(entry.get("seed",-1))==int(definition.seed):building=entry;break
		if building.is_empty():continue
		var packed:=load(BASE+String(definition.model)) as PackedScene
		if packed==null:push_error("街坊模型缺失："+String(definition.model));continue
		var actor:=Resident.new()
		actor.name=String(definition.id);actor.definition=definition;actor.collider=actor
		actor.collision_layer=0;actor.collision_mask=1
		actor.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING;actor.safe_margin=.005
		add_child(actor)
		actor.home_yaw=float(building.get("rot",0.0))
		actor.tangent=Vector3(cos(actor.home_yaw),0,-sin(actor.home_yaw))
		var outward:=Vector3(sin(actor.home_yaw),0,cos(actor.home_yaw))
		actor.home=Vector3(float(building.fx),.03,float(building.fz))+outward*float(definition.front)+actor.tangent*float(definition.side)
		actor.position=actor.home;actor.rotation.y=actor.home_yaw
		if reports is Array:
			for report in reports:
				if String(report.get("file","")).replace("\\","/").get_file()==String(definition.model):actor.runtime=report.get("runtime",{}).duplicate(true)
		var model:=packed.instantiate();actor.add_child(model)
		actor.animator=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
		actor.skeleton=_find_skeleton(model)
		if actor.animator!=null and actor.skeleton!=null:
			for library_name in actor.animator.get_animation_library_list():
				var library:=actor.animator.get_animation_library(library_name).duplicate(true)
				actor.animator.remove_animation_library(library_name);actor.animator.add_animation_library(library_name,library)
			for clip in actor.animator.get_animation_list():
				if String(clip).get_file().to_lower()=="idle":actor.idle=String(clip)
			if actor.idle!="":
				actor.animator.get_animation(actor.idle).loop_mode=Animation.LOOP_LINEAR
				for key in ["walk_clip","life_clip","turn_left_clip","turn_right_clip"]:
					var clip:=String(actor.runtime.get(key,""))
					if actor.animator.has_animation(clip):actor.animator.get_animation(clip).loop_mode=Animation.LOOP_NONE
				actor.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				actor.ready_model=true
				_play(actor,actor.idle,0.0);actor.animator.advance(0.0);actor.animator.speed_scale=0.0
		if not actor.ready_model:push_error("街坊缺少完整骨架/Idle："+String(definition.id))
		actor.look=HeadLook.new();actor.look.driver=actor
		if actor.skeleton!=null:actor.skeleton.add_child(actor.look)
		actor.body_shape=CollisionShape3D.new()
		var capsule:=CapsuleShape3D.new();capsule.radius=.24;capsule.height=1.62
		actor.body_shape.shape=capsule;actor.body_shape.position.y=.85;actor.add_child(actor.body_shape)
		actor.footsteps=AudioStreamPlayer3D.new();actor.footsteps.name="Footfalls"
		actor.footsteps.bus="WorldSFX";actor.footsteps.volume_db=-24.0
		actor.footsteps.unit_size=1.0;actor.footsteps.max_distance=7.0
		actor.add_child(actor.footsteps);actor.footsteps.position.y=.08
		actor.visible=false;actor.wait_left=7.0+actors.size()*2.5;actors.append(actor)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:return node
	for child in node.get_children():
		var found:=_find_skeleton(child)
		if found!=null:return found
	return null

func _play(actor: Resident,wanted: String,blend:=.18) -> void:
	if not actor.animator.has_animation(wanted):wanted=actor.idle
	if wanted==actor.clip:return
	actor.clip=wanted;actor.animator.play(wanted,blend)

func reset() -> void:
	pending_restore.clear()
	for actor in actors:
		actor.position=actor.home;actor.rotation.y=actor.home_yaw;actor.activity="idle"
		actor.phase=0.0;actor.wait_left=7.0+actors.find(actor)*2.5;actor.route_index=0;actor.target_index=1
		actor.trips=0;actor.blocked_time=0.0;actor.last_context="";actor.reply_cooldown=0.0;actor.velocity=Vector3.ZERO
		if actor.ready_model:_play(actor,actor.idle,0.0);actor.animator.seek(0.0,true)

func activate() -> void:
	deactivate();active=true;grounding_pending=true

func deactivate() -> void:
	active=false;grounding_pending=false
	for actor in actors:
		actor.visible=false;actor.collision_layer=0;actor.velocity=Vector3.ZERO
		actor.head_yaw=0.0;actor.look.active=false
		actor.footsteps.stop()
		if actor.animator!=null:actor.animator.speed_scale=0.0

func _can_act() -> bool:
	return active and town.active and game.state=="prologue" and game.prologue_stage=="town" and not game.bag_open and not game.phone_open and not game.nb_open and game.choice==null and not game.sub_pause

func _exclusions() -> Array[RID]:
	var result: Array[RID]=[game.player.get_rid()]
	for actor in actors:result.append(actor.get_rid())
	return result

func _support(at: Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(at+Vector3(0,.45,0),at-Vector3(0,.65,0),1,_exclusions())
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.dot(Vector3.UP)<.9 or absf(hit.position.y-town.global_position.y)>.25:return {}
	return hit

func _point(actor: Resident,index: int) -> Vector3:
	return town.global_position+actor.home-actor.tangent*float(actor.runtime.get("stride_m",.72))*index

func _route_is_safe(actor: Resident) -> bool:
	var stride:=float(actor.runtime.get("stride_m",0.0))
	if stride<.2 or stride>.8:return false
	for key in ["walk_clip","life_clip","turn_left_clip","turn_right_clip"]:
		if not actor.animator.has_animation(String(actor.runtime.get(key,""))):return false
	var previous_y: float=actor.global_position.y
	for i in range(13):
		var at:=_point(actor,0).lerp(_point(actor,1),float(i)/12.0)
		var support:=_support(at)
		if support.is_empty() or absf(float(support.position.y)+.004-previous_y)>.025:return false
		at.y=support.position.y+.004;previous_y=at.y
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=actor.body_shape.shape;query.collision_mask=1;query.exclude=_exclusions()
		query.transform=Transform3D(Basis.IDENTITY,at+Vector3(0,.85,0));query.margin=.015
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	return true

func _physics_process(delta: float) -> void:
	if not active:return
	if grounding_pending:
		grounding_pending=false
		for actor in actors:
			var support:=_support(actor.global_position)
			actor.grounded=not support.is_empty()
			if actor.grounded:actor.global_position.y=support.position.y+.004
			actor.visible=actor.ready_model and actor.grounded;actor.collision_layer=1 if actor.visible else 0
			actor.look.active=actor.visible;actor.route_clear=actor.visible and _route_is_safe(actor)
		if not pending_restore.is_empty():_apply_restore(pending_restore);pending_restore.clear()
	var running:=_can_act()
	for actor in actors:
		if actor.animator==null:continue
		actor.animator.speed_scale=1.0 if running and actor.visible else 0.0
		actor.footsteps.stream_paused=not running or not actor.visible
		if not running or not actor.visible:continue
		actor.reply_cooldown=maxf(0.0,actor.reply_cooldown-delta)
		if (behaviour_enabled and actor.route_clear) or actor.activity=="listen":_step(actor,delta)
		else:actor.animator.advance(delta)

## Matches the piecewise smoothstep used to author planted-foot compensation.
static func curve_value(curve: Array,progress: float) -> float:
	if curve.is_empty():return clampf(progress,0.0,1.0)
	for i in range(1,curve.size()):
		if progress<=float(curve[i][0]):
			var a: Array=curve[i-1];var b: Array=curve[i]
			var t:=clampf((progress-float(a[0]))/maxf(.0001,float(b[0])-float(a[0])),0.0,1.0)
			return lerpf(float(a[1]),float(b[1]),t*t*(3.0-2.0*t))
	return float(curve[-1][1])

func _turn(actor: Resident,target_yaw: float,next: String) -> void:
	actor.activity="turn";actor.phase=0.0;actor.turn_from=actor.rotation.y
	actor.turn_to=actor.rotation.y+angle_difference(actor.rotation.y,target_yaw)
	actor.after_turn=next;actor.head_yaw=0.0
	var key: String="turn_positive_clip" if actor.turn_to>actor.turn_from else "turn_negative_clip"
	_play(actor,String(actor.runtime.get(key,"")),.10);actor.animator.seek(0.0,true)

func _idle(actor: Resident,seconds: float) -> void:
	actor.activity="idle";actor.phase=0.0;actor.wait_left=seconds;_play(actor,actor.idle)

func _life_clip(actor: Resident) -> String:
	var dry: bool=town.weather!=null and town.weather.rain_amount<.08
	if (actor.trips%2==1 or (String(actor.definition.id)=="resident_woman" and dry)) and actor.animator.has_animation("LookAround"):return "LookAround"
	return String(actor.runtime.get("life_clip",actor.idle))

func _player_near_route(actor: Resident) -> bool:
	var player_at: Vector3=game.player.global_position
	var a:=_point(actor,0);var b:=_point(actor,1)
	var t:=clampf((player_at-a).dot(b-a)/maxf(.0001,(b-a).length_squared()),0.0,1.0)
	var nearest:=a.lerp(b,t)
	return Vector2(player_at.x,player_at.z).distance_to(Vector2(nearest.x,nearest.z))<.90

func _step(actor: Resident,delta: float) -> void:
	match actor.activity:
		"idle":
			actor.animator.advance(delta);actor.wait_left-=delta
			if actor.wait_left<=0.0:
				actor.activity="care";actor.phase=0.0;_play(actor,_life_clip(actor))
		"care":
			actor.phase+=delta;actor.animator.advance(delta)
			if actor.phase>=actor.animator.get_animation(actor.clip).length:
				if _player_near_route(actor):_idle(actor,3.0)
				else:
					actor.target_index=1-actor.route_index
					_turn(actor,actor.home_yaw+(-PI*.5 if actor.target_index==1 else PI*.5),"walk")
		"turn":
			var previous_phase:=actor.phase
			actor.phase+=delta
			var duration:=float(actor.runtime.get("turn_seconds",1.8))
			var curve: Array=actor.runtime.get("turn_yaw_curve",[[0,0],[1,1]])
			actor.rotation.y=lerpf(actor.turn_from,actor.turn_to,curve_value(curve,actor.phase/duration))
			actor.animator.advance(delta)
			_landings(actor,previous_phase,actor.phase,duration,[.28,.61,.95])
			if actor.phase>=duration:
				actor.rotation.y=actor.turn_to
				if actor.after_turn=="walk":
					actor.activity="walk";actor.phase=0.0;actor.walk_from=actor.global_position
					_play(actor,String(actor.runtime.get("walk_clip","")),.10);actor.animator.seek(0.0,true)
				else:_idle(actor,6.0+(actor.trips%3)*1.3)
		"walk":_walk(actor,delta)
		"yield":
			actor.animator.advance(delta);actor.wait_left-=delta
			if actor.wait_left<=0.0 and not _player_near_route(actor):
				actor.activity="walk";_play(actor,String(actor.runtime.get("walk_clip","")),.18);actor.animator.seek(actor.phase,true)
		"listen":
			actor.animator.advance(delta)
			if game.sub=="" or String(game.hud_sub_title.text)!=String(actor.definition.label):_idle(actor,3.0)
		_:_idle(actor,6.0)

func _walk(actor: Resident,delta: float) -> void:
	var clip:=String(actor.runtime.get("walk_clip",""))
	var duration: float=actor.animator.get_animation(clip).length
	var next_phase:=minf(duration,actor.phase+delta)
	var curve: Array=actor.runtime.get("walk_distance_curve",[])
	var target:=actor.walk_from.lerp(_point(actor,actor.target_index),curve_value(curve,next_phase/duration))
	target.y=actor.global_position.y
	var motion:=target-actor.global_position
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=actor.body_shape.shape;query.collision_mask=1;query.exclude=[actor.get_rid()]
	query.transform=Transform3D(Basis.IDENTITY,actor.global_position+Vector3(0,.85,0))
	query.motion=motion.normalized()*maxf(.32,motion.length());query.margin=.035
	var sweep:=get_world_3d().direct_space_state.cast_motion(query)
	if (sweep.size()>0 and sweep[0]<.99) or _support(target).is_empty():
		actor.activity="yield";actor.wait_left=.5;actor.blocked_time+=delta
		actor.velocity=Vector3.ZERO;_play(actor,actor.idle);return
	var previous:=actor.global_position
	actor.velocity=motion/maxf(.0001,delta);actor.move_and_slide()
	var support:=_support(actor.global_position)
	if not support.is_empty():actor.global_position.y=support.position.y+.004
	var travelled:=Vector2(actor.global_position.x-previous.x,actor.global_position.z-previous.z).length()
	if motion.length()>.0001 and travelled<motion.length()*.8:
		actor.activity="yield";actor.wait_left=.5;actor.velocity=Vector3.ZERO;_play(actor,actor.idle);return
	_landings(actor,actor.phase,next_phase,duration,[.30,.63,.96])
	actor.phase=next_phase;actor.animator.advance(delta)
	if actor.phase>=duration:
		actor.route_index=actor.target_index;actor.trips+=1;actor.velocity=Vector3.ZERO
		_turn(actor,actor.home_yaw,"idle")

func _landings(actor: Resident,from: float,to: float,duration: float,marks: Array) -> void:
	for mark in marks:
		if from<float(mark)*duration and to>=float(mark)*duration:
			actor.foot_index=(actor.foot_index+1)%foot_streams.size()
			actor.footsteps.stream=foot_streams[actor.foot_index]
			actor.footsteps.play()

func _process(delta: float) -> void:
	if not _can_act():return
	for actor in actors:
		if not actor.visible:continue
		var to_player: Vector3=game.player.global_position-actor.global_position;to_player.y=0.0
		var target:=0.0
		if actor.activity not in ["turn","walk"] and to_player.length()>.1 and to_player.length()<3.5:
			var angle:=angle_difference(actor.rotation.y,atan2(to_player.x,to_player.z))
			if absf(angle)<PI*.45:target=clampf(angle,-.25,.25)
		actor.head_yaw=lerpf(actor.head_yaw,target,minf(1.0,delta*3.0))

func interaction_candidates() -> Array:
	var result: Array=[]
	if not _can_act() or game.sub!="" or not game.sub_queue.is_empty():return result
	if game.audio_system!=null and game.audio_system.is_busy():return result
	for actor in actors:
		if actor.visible and actor.grounded and actor.activity in ["idle","care"] and actor.reply_cooldown<=0.0:
			var reply: Dictionary=REPLIES.response(game,String(actor.definition.id))
			result.append({"kind":"town","id":String(actor.definition.id),"text":String(reply.get("prompt","打招呼")),"pos":actor.global_position+Vector3(0,1.35,0),"reach":2.8,"radius":.42})
	return result

func interact(id: String) -> bool:
	for actor in actors:
		if id!=String(actor.definition.id):continue
		var selected: Variant=game.focus.select_target()
		if selected==null or selected.get("id","")!=id:return true
		var reply: Dictionary=REPLIES.response(game,id)
		actor.last_context=String(reply.context);actor.reply_cooldown=4.0
		actor.activity="listen";actor.velocity=Vector3.ZERO;_play(actor,actor.idle)
		game._say_seq(String(reply.label),String(reply.text),2.2,false)
		return true
	return false

func capture() -> Dictionary:
	if not pending_restore.is_empty():return pending_restore.duplicate(true)
	var data: Dictionary={"version":1,"actors":{}}
	for actor in actors:
		data.actors[String(actor.definition.id)]={"position":[actor.position.x,actor.position.y,actor.position.z],"yaw":actor.rotation.y,"activity":actor.activity,"phase":actor.phase,"wait_left":actor.wait_left,"route_index":actor.route_index,"target_index":actor.target_index,"turn_from":actor.turn_from,"turn_to":actor.turn_to,"after_turn":actor.after_turn,"clip":actor.clip,"clip_time":actor.animator.current_animation_position if actor.ready_model else 0.0,"trips":actor.trips,"last_context":actor.last_context}
	return data

func restore(data: Variant) -> void:
	pending_restore.clear()
	if data is Dictionary and _finite(data.get("version"),0.0)==1.0 and data.get("actors") is Dictionary:pending_restore=data.duplicate(true)
	if active:grounding_pending=true

func _apply_restore(data: Dictionary) -> void:
	for actor in actors:
		var row: Variant=data.get("actors",{}).get(String(actor.definition.id),{})
		if not row is Dictionary:continue
		var p: Variant=row.get("position",[])
		if not p is Array or p.size()!=3:continue
		var valid:=true
		for key in ["activity","clip","after_turn","last_context"]:
			if row.has(key) and not row[key] is String:valid=false
		for key in ["phase","wait_left","route_index","target_index","turn_from","turn_to","yaw","trips","clip_time"]:
			if row.has(key) and not ((row[key] is int or row[key] is float) and is_finite(float(row[key]))):valid=false
		for value in p:
			if not (value is float or value is int) or not is_finite(float(value)):valid=false
		if not valid:continue
		var local:=Vector3(float(p[0]),float(p[1]),float(p[2]));var relative:=local-actor.home
		var along:=relative.dot(actor.tangent)
		if along<-.82 or along>.04 or (relative-actor.tangent*along).length()>.12:continue
		var support:=_support(town.global_position+local)
		if support.is_empty():continue
		var state:=String(row.get("activity","idle"))
		if state not in ["idle","care","turn","walk","yield","listen"]:continue
		var phase:=_finite(row.get("phase"),-1.0)
		var route_index:=clampi(int(_finite(row.get("route_index"),0.0)),0,1)
		var target_index:=clampi(int(_finite(row.get("target_index"),1.0)),0,1)
		var from:=_finite(row.get("turn_from"),actor.home_yaw)
		var to:=_finite(row.get("turn_to"),actor.home_yaw)
		var yaw:=_finite(row.get("yaw"),actor.home_yaw)
		if maxf(absf(from),maxf(absf(to),absf(yaw)))>TAU*4.0:continue
		var expected_clip:=actor.idle
		if state=="care":expected_clip=String(actor.runtime.get("life_clip",actor.idle))
		if state=="care" and row.get("clip")=="LookAround" and actor.animator.has_animation("LookAround"):expected_clip="LookAround"
		elif state=="walk":expected_clip=String(actor.runtime.get("walk_clip",actor.idle))
		elif state=="turn":expected_clip=String(actor.runtime.get("turn_positive_clip" if to>from else "turn_negative_clip",actor.idle))
		var walk_length: float=actor.animator.get_animation(String(actor.runtime.get("walk_clip",actor.idle))).length
		var duration: float=walk_length if state=="yield" else actor.animator.get_animation(expected_clip).length
		if phase<0.0 or (state in ["walk","yield","turn","care"] and phase>duration+.03):continue
		if state in ["walk","yield"]:
			var expected:=_point(actor,route_index).lerp(_point(actor,target_index),curve_value(actor.runtime.get("walk_distance_curve",[]),phase/walk_length))
			if Vector2(expected.x,expected.z).distance_to(Vector2(local.x+town.global_position.x,local.z+town.global_position.z))>.035:continue
		if state=="turn" and absf(absf(to-from)-PI*.5)>.02:continue
		if state=="turn":
			var expected_yaw:=lerpf(from,to,curve_value(actor.runtime.get("turn_yaw_curve",[]),phase/duration))
			if absf(angle_difference(expected_yaw,yaw))>.035:continue
		actor.position=local;actor.global_position.y=support.position.y+.004
		actor.rotation.y=actor.home_yaw+angle_difference(actor.home_yaw,_finite(row.get("yaw"),actor.home_yaw))
		actor.activity=state
		actor.phase=phase
		actor.wait_left=clampf(_finite(row.get("wait_left"),6.0),0.0,12.0)
		actor.route_index=clampi(int(row.get("route_index",0)),0,1);actor.target_index=clampi(int(row.get("target_index",1)),0,1)
		actor.turn_from=_finite(row.get("turn_from"),actor.home_yaw);actor.turn_to=_finite(row.get("turn_to"),actor.home_yaw)
		actor.after_turn="walk" if row.get("after_turn")=="walk" else "idle"
		actor.walk_from=_point(actor,actor.route_index)
		actor.trips=maxi(0,int(row.get("trips",0)));actor.last_context=String(row.get("last_context",""))
		_play(actor,expected_clip,0.0)
		var time:=phase if state in ["walk","turn","care"] else _finite(row.get("clip_time"),0.0)
		actor.animator.seek(clampf(time,0.0,actor.animator.get_animation(actor.clip).length),true)

static func _finite(value: Variant,fallback: float) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback
