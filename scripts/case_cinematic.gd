extends Node
## Short in-engine observations. Always returns the same player camera/position.
var game
var story
var camera: Camera3D
var active := false
var event_id := ""
var elapsed := 0.0
var duration := 5.0
var start_eye := Vector3.ZERO
var end_eye := Vector3.ZERO
var target := Vector3.ZERO
var previous_camera: Camera3D
var return_state := "play"
var was_frozen := false
var overlay: Control
var caption: Label
var skipped := false
var prior_seven := true
var hud_was_visible := true
const SCENES := {
	"letter":[Vector3(.32,12.82,320.55),Vector3(.20,12.70,320.4),Vector3(0,12.04,319.22),3.3,"门缝下传来很轻的摩擦声。没有脚步离开的声音。"],
	"seven":[Vector3(.3,4.8,4.2),Vector3(.15,4.65,3.8),Vector3(0,4.0,2.65),4.5,"滚筒停了，水声却没有停。"],
	"count":[Vector3(.2,4.7,7.35),Vector3(.35,4.65,7.0),Vector3(1.42,4.12,6.25),5.0,"五件衣服。她的手停在了空处。"],
	"basement":[Vector3(2.55,-1.35,-5.5),Vector3(2.62,-1.5,-5.25),Vector3(3.65,-2.7,-6.1),5.5,"水位退下，竖井边露出一只蓝布鞋。"],
}
func setup(g,campaign) -> void:
	game=g;story=campaign
	camera=Camera3D.new();camera.name="CaseEventCamera";camera.fov=62;camera.near=.05;add_child(camera)
	var layer=CanvasLayer.new();layer.layer=29;add_child(layer)
	overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(overlay)
	for top in [true,false]:
		var bar=ColorRect.new();bar.color=Color(.005,.008,.008,.94);bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE);bar.offset_bottom=55 if top else 0;bar.offset_top=0 if top else -55;overlay.add_child(bar)
	caption=game.phone_ui.lab(overlay,"",Vector2(260,730),Vector2(1080,70),25,Color("e4decc"));caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	game.phone_ui.lab(overlay,"空格  跳过观察   ·   ESC  暂停",Vector2(1160,18),Vector2(420,30),17,Color("b7b4a3"))
	overlay.visible=false

func play(id: String) -> bool:
	if active or not SCENES.has(id):return false
	if id=="letter":
		if game.state!="prologue" or game.case_mode=="laundry":return false
	elif game.state!="play" or game.case_mode!="laundry":return false
	var data: Array=SCENES[id];event_id=id;duration=data[3];elapsed=0;skipped=false
	start_eye=data[0];end_eye=data[1];target=data[2];caption.text=data[4]
	return_state=game.state;previous_camera=game.get_viewport().get_camera_3d();was_frozen=game.player.physics_frozen
	hud_was_visible=game.hud.visible;game.hud.visible=false
	if story!=null:
		story.chapter.visible=false;story.guidance.hint.visible=false;story.guidance.marker.visible=false
	game.state="case_cinematic";game.player.can_move=false;game.player.allow_capture=false;game.player.physics_frozen=true;game.player.velocity=Vector3.ZERO
	game._clear_sub();game.audio_system.stop_voice()
	if id=="seven":
		prior_seven=bool(story.lc.spinning.get(7,true));story.lc.spinning[7]=false
	camera.global_position=start_eye;camera.look_at(target);camera.current=true
	overlay.visible=true;active=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.audio_system.spatial_sfx("washer_latch" if id=="seven" else ("ladder" if id=="basement" else "paper"),target,-14)
	if id=="count":
		caption.text="一件……两件……三件……四件……五件……还差一件。"
		game.audio_system.speak_dialogue("lady_count",target,story.lc.lady)
		var voice:AudioStream=game.audio_system.spatial_voice.stream
		if voice!=null:duration=maxf(duration,voice.get_length()+.5)
	return true

func finish(skip := false) -> void:
	if not active:return
	skipped=skip;active=false;overlay.visible=false
	if event_id=="seven" and story!=null:story.lc.spinning[7]=prior_seven
	game.audio_system.stop_voice()
	if is_instance_valid(previous_camera):previous_camera.current=true
	else:game.player.cam.current=true
	game.state=return_state;game.player.physics_frozen=was_frozen;game.player.can_move=true;game.player.allow_capture=true;game.player.velocity=Vector3.ZERO
	game.hud.visible=hud_was_visible
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if story!=null:
		story.mark("shot_"+event_id);story.update_objective()
	else:game.director.sent["shot_letter"]=true

func cancel() -> void:
	if not active:return
	var original:String=game.state
	finish(true)
	if original=="menu":game.state=original

func _input(event: InputEvent) -> void:
	if not active or game.state!="case_cinematic":return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_SPACE:finish(true)
		elif event.physical_keycode==KEY_ESCAPE:game._open_pause()
		else:return
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if active:
		if game.state=="menu":cancel();return
		if game.state!="case_cinematic":return
		game.hud.visible=false
		elapsed+=delta
		var weight=smoothstep(0.,1.,minf(elapsed/duration,1.))
		camera.global_position=start_eye.lerp(end_eye,weight);camera.look_at(target)
		if elapsed>=duration:finish()
		return
	if story==null:
		if game.is_processing() and game.state=="prologue" and game.prologue_stage=="room" and game.case_mode!="laundry" and game.prologue_letter_ready and not game.envelope_taken and not game.field_kit.letter_accepted and not game.phone_open and not game.bag_open and not game.audio_system.is_busy() and game.sub=="" and not game.director.sent.has("shot_letter"):play("letter")
		return
	# Do not interrupt a paused simulation, phone, dialogue or another floor's exploration.
	if not game.is_processing() or game.case_mode!="laundry" or game.state!="play" or game.phone_open or game.bag_open or game.nb_open or game.sub!="" or not game.sub_queue.is_empty() or game.audio_system.is_busy():return
	var p: Vector3=game.player.global_position
	if story.flag("drained") and not story.flag("shot_basement") and p.y<0 and p.z>-7:play("basement")
	elif story.lc.fired.has("count") and not story.flag("shot_count") and p.y>3.4 and p.y<4.0 and p.z<9.8 and story.lc.lady!=null:play("count")
	elif story.lc.fired.has("bc2") and not story.lc.fired.has("oldlady") and not story.flag("shot_seven") and p.y>3.4 and p.y<4.0 and p.z<9.8:play("seven")
