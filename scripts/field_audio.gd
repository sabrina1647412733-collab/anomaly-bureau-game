extends Node
## 分区环境声、事件配乐、空间音源与对白避让。来源见 assets/audio/finish/SOURCES.md。
const BASE := "res://assets/audio/field/"
var game
var music: AudioStreamPlayer
var atmosphere: AudioStreamPlayer
var voice: AudioStreamPlayer
var ring: AudioStreamPlayer3D
var current_zone := ""
var sources := {}
var played := {}
var voice_context := ""
var spatial_voice: AudioStreamPlayer3D
var music_alt: AudioStreamPlayer
var music_id := ""
var blend := 1.0
var machine_sources := {}
var step_index := 0
var last_step := 0
var performance_actor
var voice_profiles:Dictionary={}
const PERFORMANCE := "res://assets/audio/performance/"
const FINISH := "res://assets/audio/finish/"
const LOOPS := ["room_theme","memory_theme","depth_theme","suspense_theme","washer_loop","rain_inside","rain_outside"]

func _exit_tree() -> void:
	# Release active decoder/playback references before the game world disappears.
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop();child.stream=null
	sources.clear();machine_sources.clear()

func stop_voice() -> void:
	if is_instance_valid(performance_actor) and performance_actor.performance!=null:performance_actor.performance.end_voice()
	performance_actor=null
	voice.stop()
	if spatial_voice!=null:spatial_voice.stop()
	voice_context = ""

func is_busy() -> bool:
	return voice.playing or (spatial_voice!=null and spatial_voice.playing)

func speak_dialogue(id: String, at:=Vector3.INF, actor=null) -> void:
	stop_voice()
	var path=PERFORMANCE+id+".wav"
	var authored=ResourceLoader.exists(path)
	if not authored:path="res://assets/audio/dialogue/"+id+".wav"
	if not ResourceLoader.exists(path):path=BASE+id+".wav"
	var clip: AudioStream=load(path)
	voice_context="dialogue"
	var player_node:Node
	if at.is_finite():
		spatial_voice.pitch_scale=1. if authored else (1.04 if id=="lady_job" else (.9 if id.begins_with("lady_") else .97))
		spatial_voice.global_position=at;spatial_voice.stream=clip;spatial_voice.play()
		player_node=spatial_voice
	else:
		voice.pitch_scale=1.;voice.stream=clip;voice.volume_db=-3;voice.play();player_node=voice
	if is_instance_valid(actor) and actor.performance!=null:
		performance_actor=actor;actor.performance.begin_voice(player_node,voice_profiles.get(id,{}))

func setup(g) -> void:
	game = g
	var profiles=JSON.parse_string(FileAccess.get_file_as_string(PERFORMANCE+"performance.json"))
	if profiles is Dictionary:voice_profiles=profiles
	for bus in ["Voice", "Ambience"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	music = player("night_music", "Music", -15, true)
	music_alt=player("room_theme","Music",-80,true)
	atmosphere = player("rain_inside", "Ambience", -25, true)
	voice = player("phone_voice", "Voice", -80)
	spatial_voice=AudioStreamPlayer3D.new();spatial_voice.bus="Voice"
	spatial_voice.max_distance=12;spatial_voice.unit_size=3;spatial_voice.volume_db=0
	add_child(spatial_voice)
	ring = AudioStreamPlayer3D.new()
	ring.stream = stream("phone_ring", true)
	ring.bus = "SFX"
	ring.max_distance = 22.0
	ring.unit_size = 4.0
	ring.volume_db = -5
	add_child(ring)

func stream(id: String, loop := false) -> AudioStream:
	if id=="stow":id="cloth"
	var key := id + str(loop)
	if sources.has(key):
		return sources[key]
	var path=FINISH+id+(".ogg" if id in LOOPS else (".mp3" if id=="lightless_dawn" else ".wav"))
	if not ResourceLoader.exists(path):path=BASE+id+".wav"
	var sound = load(path)
	if sound is AudioStreamWAV and loop:
		sound = sound.duplicate()
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_end = int(round(sound.get_length()*sound.mix_rate))
	if loop and (sound is AudioStreamOggVorbis or sound is AudioStreamMP3):
		sound=sound.duplicate();sound.loop=true
	sources[key] = sound
	return sound

func player(id: String, bus: String, volume: float, loop := false) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream(id, loop)
	p.bus = bus
	p.volume_db = volume
	add_child(p)
	return p

func sfx(id: String, volume := -8.0) -> void:
	if id in ["door","knock"] and game!=null:
		spatial_sfx(id,nearest_door(),volume);return
	var p := player(id, "SFX", volume)
	p.add_to_group("case_one_shot")
	var playing=get_tree().get_nodes_in_group("case_one_shot")
	if playing.size()>16:playing[0].queue_free()
	p.finished.connect(p.queue_free)
	p.play()

func nearest_door()->Vector3:
	var at:Vector3=game.player.global_position+Vector3(0,1.,0)
	var distance=INF
	if game.case_mode=="laundry" and game.laundry!=null:
		var lc=game.laundry
		for node in [lc.f2.doors.back,lc.buildings.f4.k.doors["402"],lc.buildings.f5.doors["503"],lc.buildings.power_room.door]:
			var p:Vector3=node.global_position+node.global_basis*Vector3(.45,1.,0)
			if p.distance_to(game.player.global_position)<distance:distance=p.distance_to(game.player.global_position);at=p
	else:
		for point in game.prologue_spots:
			if point.id=="door" and point.stage==game.prologue_stage:return point.pos
	return at

func speak(id: String) -> void:
	stop_voice()
	voice_context = "story"
	voice.stream = stream(id)
	voice.volume_db = -3.0
	voice.play()

func start_ring() -> void:
	if not ring.playing and not game.phone_ui.quiet:
		ring.play()

func line(who: String, text: String) -> void:
	var id := ""
	if text.contains("夜间请勿使用七号机"):
		id = "broadcast_1"
	elif text.contains("夜间勿使用七号机"):
		id = "broadcast_2"
	elif text.contains("是不是洗好了") and who == "她":
		id = "lady_ask"
	elif text.contains("一件……两件") and who == "她":
		id = "lady_count"
	elif who == "她" and text.contains("纸") and text.contains("擦"):
		id = "lady_wipe"
	elif text.contains("你现在能看见我了"):
		id = "aqi_voice"
	elif text.contains("您已录名"):
		id = "recorded"
	if id != "" and not played.has(id):
		played[id] = true
		if who == "她" and game.laundry != null and game.laundry.lady != null:
			speak_dialogue(id,game.laundry.lady.global_position+Vector3(0,1.15,0),game.laundry.lady)
		elif id=="aqi_voice" and game.laundry!=null and is_instance_valid(game.laundry.cast.aqi):
			var actor=game.laundry.cast.aqi
			speak_dialogue(id,actor.global_position+Vector3(0,1.2,0),actor)
		else: speak(id)

func music_target() -> String:
	if game.case_mode != "laundry":return "room_theme"
	var lc=game.laundry
	if lc==null:return "room_theme"
	if lc.selected_ending!="" or lc.fired.has("dawn4"):return "memory_theme"
	if lc.campaign!=null and lc.campaign.flag("recognized"):return "memory_theme"
	if game.player.global_position.y<-.4:return "depth_theme"
	if lc.fired.has("count") or (lc.night!=null and lc.night.lady_state=="walk"):return "suspense_theme"
	return "lightless_dawn"

func change_music(id:String)->void:
	if id==music_id:return
	# Swap roles and fade out the previous playing cue; no restart on each frame.
	var old=music;music=music_alt;music_alt=old
	music_id=id;music.stream=stream(id,true);music.volume_db=-80;music.play();blend=0.

func footstep(running:bool)->void:
	if Time.get_ticks_msec()-last_step<90:return
	last_step=Time.get_ticks_msec();step_index=(step_index+1)%4
	var surface="wood"
	if game.prologue_stage in ["town","street"]:surface="tile"
	if game.case_mode=="laundry":
		var y=game.player.global_position.y
		surface="metal" if y<0 or y>15 else ("wood" if y>6.7 else "tile")
	sfx("step_"+surface+str(step_index),-16. if running else -23.)

func spatial_sfx(id:String,at:Vector3,volume:=-12.0)->void:
	var p=AudioStreamPlayer3D.new();p.stream=stream(id);p.bus="SFX";p.volume_db=volume
	p.max_distance=14;p.unit_size=2.;add_child(p);p.global_position=at
	p.add_to_group("case_one_shot");p.finished.connect(p.queue_free);p.play()

func sync_machines(active:bool)->void:
	var lc=game.laundry
	if not active or lc==null or not is_instance_valid(lc.world):
		for source in machine_sources.values():
			if is_instance_valid(source):source.stop()
		return
	for number in lc.f2.drums:
		var source=machine_sources.get(number)
		if not is_instance_valid(source):
			source=AudioStreamPlayer3D.new();source.stream=stream("washer_loop",true)
			source.bus="Ambience";source.volume_db=-25;source.max_distance=7;source.unit_size=1.2
			add_child(source);source.set_meta("case_world",lc.world.get_instance_id());machine_sources[number]=source
		source.global_position=lc.f2.drums[number].global_position
		var should_play=bool(lc.spinning.get(number,false))
		if should_play and not source.playing:source.play(fmod(float(number)*.71,source.stream.get_length()))
		elif not should_play:source.stop()

func _process(delta: float) -> void:
	if game == null:return
	var active:bool=game.state!="menu"
	var paused:bool=game.state=="paused"
	var zone="laundry" if game.case_mode=="laundry" else ("town" if game.prologue_stage in ["town","street"] else "room")
	if game.case_mode=="laundry" and game.player.global_position.y>15:zone="roof"
	if zone!=current_zone:
		current_zone=zone;atmosphere.stream=stream("rain_outside" if zone in ["town","roof"] else "rain_inside",true)
		atmosphere.volume_db=-27 if zone=="laundry" else (-20 if zone in ["town","roof"] else -25)
		if active:atmosphere.play()
	if active:
		change_music(music_target())
		if not music.playing:music.play()
		if not atmosphere.playing:atmosphere.play()
		if game.phone_ui.incoming and not game.phone_ui.quiet:start_ring()
		else:ring.stop()
	else:
		music.stop();music_alt.stop();atmosphere.stop();ring.stop();stop_voice()
	if game.field_kit!=null and game.field_kit.phone_owned:ring.global_position=game.player.global_position+Vector3(0,1.3,0)
	else:
		var body=game.get_meta("phone_world_body",null)
		if is_instance_valid(body):ring.global_position=body.global_position
	if not paused:
		blend=minf(1.,blend+delta/2.4)
		var target=-29. if music_id=="lightless_dawn" else -24.
		if is_busy():target-=10.
		music.volume_db=lerpf(-65.,target,sin(blend*PI*.5))
		music_alt.volume_db=move_toward(music_alt.volume_db,-75.,delta*24.)
		if blend>=1.:music_alt.stop()
	sync_machines(active and game.case_mode=="laundry")
	for p in get_children():
		if p is AudioStreamPlayer or p is AudioStreamPlayer3D:p.stream_paused=paused
