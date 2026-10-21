extends Node
## 原创合成音效与本地中文合成配音，统一总线与配音压低配乐。
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

func stop_voice() -> void:
	voice.stop()
	if spatial_voice!=null:spatial_voice.stop()
	voice_context = ""

func is_busy() -> bool:
	return voice.playing or (spatial_voice!=null and spatial_voice.playing)

func speak_dialogue(id: String, at:=Vector3.INF) -> void:
	stop_voice()
	var clip: AudioStream=load("res://assets/audio/dialogue/"+id+".wav")
	voice_context="dialogue"
	if at.is_finite():
		spatial_voice.pitch_scale=1.04 if id=="lady_job" else (.9 if id.begins_with("lady_") else .97)
		spatial_voice.global_position=at;spatial_voice.stream=clip;spatial_voice.play()
	else:
		voice.stream=clip;voice.volume_db=-3;voice.play()

func setup(g) -> void:
	game = g
	for bus in ["Voice", "Ambience"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	music = player("night_music", "Music", -15, true)
	atmosphere = player("room_rain", "Ambience", -12, true)
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
	var key := id + str(loop)
	if sources.has(key):
		return sources[key]
	var sound = load(BASE + id + ".wav")
	if sound is AudioStreamWAV and loop:
		sound = sound.duplicate()
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_end = sound.data.size() / 2
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
	var p := player(id, "SFX", volume)
	p.finished.connect(p.queue_free)
	p.play()

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
			speak_dialogue(id,game.laundry.lady.global_position+Vector3(0,1.15,0))
		else: speak(id)

func _process(delta: float) -> void:
	if game == null:
		return
	var active: bool = game.state != "menu"
	var zone: String = "laundry" if game.case_mode == "laundry" else "room"
	if zone != current_zone:
		current_zone = zone
		atmosphere.stream = stream("laundry_hum" if zone == "laundry" else "room_rain", true)
		if active:
			atmosphere.play()
	if active and not music.playing:
		music.play()
	if active and not atmosphere.playing:
		atmosphere.play()
	if not active:
		music.stop()
		atmosphere.stop()
		ring.stop()
		stop_voice()
	elif game.phone_ui.incoming:
		if game.phone_ui.quiet:
			ring.stop()
		elif not ring.playing:
			start_ring()
	if game.field_kit != null and game.field_kit.phone_owned:
		ring.global_position = game.player.global_position + Vector3(0, 1.3, 0)
	else:
		var body = game.get_meta("phone_world_body", null)
		if is_instance_valid(body):
			ring.global_position = body.global_position
	music.volume_db = move_toward(music.volume_db, -25.0 if is_busy() else -15.0, delta * 18.0)
	var paused: bool = game.state == "paused"
	music.stream_paused = paused
	atmosphere.stream_paused = paused
	ring.stream_paused = paused
	voice.stream_paused = paused
	spatial_voice.stream_paused=paused
