extends Node
## 场景内逐句配音；字幕为辅助，不用案卷阅读页代替人物表演。
var game
var panel: Panel
var speaker: Label
var caption: Label
var next_button: Button
var lines: Array=[]
var cursor := -1
var remaining := 0.0
var done: Callable
var return_state := "play"
var source_position := Vector3.INF
var active := false
var actor
func setup(g) -> void:
	game=g
	var layer=CanvasLayer.new();layer.layer=32;add_child(layer)
	var root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(root)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel=game.phone_ui.box(root,Vector2(260,650),Vector2(1080,205),Color(.035,.07,.075,.94),12)
	speaker=game.phone_ui.lab(panel,"",Vector2(28,18),Vector2(860,34),23,Color("dbc08a"))
	caption=game.phone_ui.lab(panel,"",Vector2(28,64),Vector2(850,115),25)
	next_button=game.phone_ui.btn(panel,"继续\nE / 空格",Vector2(910,70),Vector2(145,96),advance)
	panel.visible=false
func play(sequence: Array, callback: Callable=Callable(), at:=Vector3.INF, speaker_actor=null) -> void:
	if active:finish(false)
	return_state=game.state
	if game.phone_open:game._close_phone()
	game._clear_sub();game.audio_system.stop_voice()
	lines=sequence;cursor=-1;done=callback;source_position=at;actor=speaker_actor
	game.state="case_dialogue";game.player.can_move=false;game.player.allow_capture=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;active=true;panel.visible=true
	advance()
func advance() -> void:
	if not active or game.state!="case_dialogue":return
	game.audio_system.stop_voice()
	cursor+=1
	if cursor>=lines.size():finish(true);return
	var item: Array=lines[cursor]
	speaker.text=item[0];caption.text=item[1]
	if item.size()>2:
		var npc:bool=item[0] not in ["许砚","广播"]
		game.audio_system.speak_dialogue(item[2],source_position if npc else Vector3.INF,actor if npc else null)
		remaining=float(game.audio_system.voice_profiles.get(item[2],{}).get("gap",.55))
	else:remaining=maxf(2.0,float(String(item[1]).length())*.13)
func finish(run_callback:=true) -> void:
	if not active:return
	active=false;panel.visible=false;game.audio_system.stop_voice()
	game.state=return_state;game.player.can_move=true;game.player.allow_capture=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var callback=done;done=Callable()
	if run_callback and callback.is_valid():callback.call()
func cancel() -> void:
	# Leaving the scene must not complete a pending conversation.
	active=false;panel.visible=false;done=Callable();lines=[];remaining=0;actor=null
	game.audio_system.stop_voice()
func _process(delta: float) -> void:
	if not active:return
	if game.state=="menu":cancel();return
	panel.visible=game.state=="case_dialogue"
	if game.state!="case_dialogue":return
	if game.audio_system.is_busy():return
	remaining-=delta
	if remaining<=0:advance()
func _input(event: InputEvent) -> void:
	if not active or game.state!="case_dialogue":return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			game._open_pause()
		elif event.physical_keycode in [KEY_E,KEY_SPACE,KEY_ENTER]:
			advance()
		else:return
		get_viewport().set_input_as_handled()
