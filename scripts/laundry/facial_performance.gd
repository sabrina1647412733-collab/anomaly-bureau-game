extends Node
## Conservative audio-envelope mouth shapes, blinks and authored emotional accents.
var actor
var game
var visual:MeshInstance3D
var voice_player:Node
var take:Dictionary={}
var speaking:=false
var mouth:=0.
var concern:=0.
var relief:=0.
var blink:=0.
var nod:=0.
var tilt:=0.
var elapsed:=0.
var blink_time:=0.
var next_blink:=3.4
var paused:=false
var saved_speed:=1.

func setup(owner_actor) -> void:
	actor=owner_actor
	var file="res://assets/models/chars/performance/"+actor.who+"_face.res"
	if not ResourceLoader.exists(file):return
	visual=actor.model.find_children("*","MeshInstance3D",true,false)[0]
	var original=visual.get_active_material(0)
	visual.mesh=load(file);visual.set_surface_override_material(0,original)
	var inside=StandardMaterial3D.new();inside.albedo_color=Color(.105,.025,.022)
	inside.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;inside.cull_mode=BaseMaterial3D.CULL_DISABLED
	visual.set_surface_override_material(1,inside)
	var sk:Skeleton3D=actor.model.find_child("Skeleton3D",true,false)
	var modifier=preload("res://scripts/laundry/speech_head_modifier.gd").new();modifier.driver=self;sk.add_child(modifier)
	var node=actor.get_parent()
	while node!=null:
		if node.has_method("_open_pause"):game=node;break
		node=node.get_parent()
	next_blink+=float(abs(actor.who.hash())%13)*.17

func begin_voice(player:Node,profile:Dictionary) -> void:
	voice_player=player;take=profile;speaking=true

func end_voice() -> void:
	speaking=false;voice_player=null
	mouth=0;apply_shapes()

func envelope_at(time:float) -> float:
	var values:Array=take.get("envelope",[])
	var at=time*float(take.get("hz",50))
	var index=int(at)
	if index<0 or index>=values.size():return 0
	return lerpf(float(values[index]),float(values[mini(index+1,values.size()-1)]),at-index)

func update_pose(delta:float,time:float,playing:bool) -> void:
	elapsed+=delta
	var level=envelope_at(time) if playing else 0.
	mouth=move_toward(mouth,level*.48,delta*(8. if level>mouth else 11.))
	var mood:String=take.get("mood","neutral") if playing else "neutral"
	concern=move_toward(concern,.65 if mood in ["concern","guarded"] else 0.,delta*1.8)
	relief=move_toward(relief,.55 if mood=="relief" else 0.,delta*1.6)
	nod=lerpf(nod,sin(elapsed*2.5)*.018*level,clampf(delta*7,0,1))
	tilt=lerpf(tilt,(-.012 if mood=="concern" else .009 if mood=="relief" else 0.)*level,clampf(delta*3,0,1))
	blink_time+=delta
	if blink_time>next_blink:
		var phase=(blink_time-next_blink)/.18
		blink=sin(clampf(phase,0,1)*PI)
		if phase>=1:blink_time=0;blink=0;next_blink=3.6+fmod(elapsed*1.73,2.4)
	else:blink=0
	apply_shapes()

func apply_shapes() -> void:
	if visual==null:return
	for pair in [[0,mouth],[1,blink],[2,concern],[3,relief]]:visual.set_blend_shape_value(pair[0],pair[1])

func reset_pose() -> void:
	end_voice();mouth=0;concern=0;relief=0;nod=0;tilt=0;blink=0;apply_shapes()

func _process(delta:float) -> void:
	if visual==null:return
	var stop:bool=game!=null and game.state in ["paused","menu"]
	if stop and not paused:saved_speed=actor.ap.speed_scale;actor.ap.speed_scale=0;paused=true
	elif not stop and paused:actor.ap.speed_scale=saved_speed;paused=false
	if stop:return
	var playing:bool=speaking and is_instance_valid(voice_player) and voice_player.playing
	var time:float=voice_player.get_playback_position() if playing else 0.
	update_pose(delta,time,playing)
