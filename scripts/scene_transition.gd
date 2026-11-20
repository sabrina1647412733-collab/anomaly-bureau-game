extends Node
## Threaded resource reads; scene-tree construction stays on the main thread.
## The room/street/laundry instances are reused. No second gameplay project.
var game
var busy:=false
var overlay:Control
var label:Label
var error_actions:HBoxContainer
var warmed:Dictionary={}
var warming:Dictionary={}
var retained:Dictionary={}
var last_error:=""
var kind:=""
var from_laundry:=false
var origin:Dictionary={}
var samples:Array[Dictionary]=[]
var generation:=0
var activated:=false

func setup(owner_game)->void:
	game=owner_game
	var layer=CanvasLayer.new();layer.layer=95;add_child(layer)
	overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(overlay)
	var shade=ColorRect.new();shade.color=Color("090f10");shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(shade)
	var stack=VBoxContainer.new();stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	stack.offset_left=-430;stack.offset_right=430;stack.offset_top=-80;stack.offset_bottom=160;stack.add_theme_constant_override("separation",22);overlay.add_child(stack)
	label=Label.new();label.add_theme_font_override("font",game.font);label.add_theme_font_size_override("font_size",25)
	label.modulate=Color("c9c2af");label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;stack.add_child(label)
	error_actions=HBoxContainer.new();error_actions.alignment=BoxContainer.ALIGNMENT_CENTER;error_actions.add_theme_constant_override("separation",20);stack.add_child(error_actions)
	for row in [["重新准备",retry],["返回原处",return_to_origin]]:
		var button=Button.new();button.text=row[0];button.custom_minimum_size=Vector2(220,50);button.add_theme_font_override("font",game.font)
		preload("res://scripts/field_ui_style.gd").button(button);error_actions.add_child(button);button.pressed.connect(row[1])
	overlay.visible=false

func stage(text:String)->void:
	label.text=("走进老街" if kind=="town" else "推开洗衣楼的门")+"\n\n"+text

func resources_for(destination:String)->Array[String]:
	var paths:Array[String]=[]
	var texture_sets:Array=[]
	if destination=="town":
		texture_sets=preload("res://scripts/town/street_world.gd").TEXTURES.values()
		paths.append(game.town_bridge.MODULES[2])
		for manifest in ["res://assets/town/renewal/street_manifest.json","res://assets/town/renewal/hero_props/hero_props_manifest.json"]:
			var data=JSON.parse_string(FileAccess.get_file_as_string(manifest))
			if data is Dictionary:
				for path in data.get("chunks",[]):paths.append(String(path))
		for definition in preload("res://scripts/town/street_residents.gd").DEFINITIONS:
			paths.append("res://assets/models/chars/street_residents/"+String(definition.model))
	else:
		texture_sets=["concrete_floor","terrazzo_tiles","painted_plaster_wall","damaged_plaster","long_white_tiles","oak_wood_planks","rough_linen","painted_concrete","metal_plate","metal_grate_rusty","wood_planks_dirt","rusty_metal"]
		for floor in preload("res://scripts/laundry_rebuild.gd").FLOORS:
			paths.append("res://assets/models/laundry_finish/"+floor+"_finish.glb")
			paths.append("res://assets/models/laundry_rebuild/"+floor+"_collision.glb")
		# Shared close-up props, actors and evidence. Keep loaded resources alive
		# until instances own them; load() in existing builders then hits the cache.
		for folder in ["res://assets/models/laundry_finish/","res://assets/models/laundry_backroom/","res://assets/models/case1_props/"]:
			for file in DirAccess.get_files_at(folder):
				var source=String(file).trim_suffix(".remap")
				if source.ends_with(".glb") and not paths.has(folder+source):paths.append(folder+source)
		paths.append("res://assets/models/laundry_detail/shop_detail.glb")
		for actor in ["laozhou","aqi","xiulan","zhou"]:
			paths.append(preload("res://scripts/laundry/char_actor.gd").file_of(actor))
			if actor!="xiulan":paths.append("res://assets/models/chars/finish/"+actor+"_clips.res")
	# Runtime PBR replacements live outside the GLBs. Warm them individually,
	# avoiding a large synchronous texture upload on the first visible street frame.
	for folder in texture_sets:
		for map in ["albedo.jpg","normal.jpg","rough.jpg","ao.jpg"]:
			var path="res://assets/textures/"+String(folder)+"/"+map
			if not paths.has(path) and ResourceLoader.exists(path):paths.append(path)
	return paths

func warm(destination:String)->bool:
	var instantiated:bool=game.town_bridge.imported if destination=="town" else (game.laundry!=null and game.laundry.campaign!=null)
	if warmed.get(destination,false) and (retained.has(destination) or instantiated):return true
	if warming.get(destination,false):
		while warming.get(destination,false):await get_tree().process_frame
		return warmed.get(destination,false)
	warming[destination]=true
	var resources:Array[Resource]=[]
	var paths=resources_for(destination)
	for i in paths.size():
		var path=paths[i]
		if not ResourceLoader.exists(path):
			last_error="缺少资源："+path;warming[destination]=false;return false
		if ResourceLoader.has_cached(path):
			resources.append(load(path));continue
		var err=ResourceLoader.load_threaded_request(path)
		if err!=OK:
			last_error="资源读取未开始："+path;warming[destination]=false;return false
		var status=ResourceLoader.load_threaded_get_status(path)
		var started=Time.get_ticks_msec()
		while status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if busy and kind==destination:stage("读取资源 · %d / %d"%[i+1,paths.size()])
			await get_tree().process_frame
			status=ResourceLoader.load_threaded_get_status(path)
			if Time.get_ticks_msec()-started>45000:
				last_error="资源读取超时，可重试："+path;warming[destination]=false;return false
		if status!=ResourceLoader.THREAD_LOAD_LOADED:
			last_error="无法读取资源："+path;warming[destination]=false;return false
		resources.append(ResourceLoader.load_threaded_get(path))
	retained[destination]=resources
	warming[destination]=false;warmed[destination]=true
	return true

func begin(destination:String,leaving_laundry:=false)->void:
	if busy:return
	busy=true;kind=destination;from_laundry=leaving_laundry
	origin={"state":game.state,"mode":game.case_mode,"stage":game.prologue_stage,"position":game.player.global_position,"yaw":game.player.rotation.y,"pitch":game.player.pitch}
	activated=false
	error_actions.visible=false;overlay.visible=true
	game.state="prologue_transition";game.player.can_move=false;game.player.allow_capture=false
	game.player.physics_frozen=true;game.player.velocity=Vector3.ZERO;game.player.dragging=false
	stage("准备现场")
	generation+=1;call_deferred("run",generation)

func run(token:int)->void:
	var started=Time.get_ticks_usec()
	await get_tree().process_frame
	if not await warm(kind):
		show_error();return
	if token!=generation:return
	if kind=="town":
		await game.town_bridge.prepare_async(stage)
		if from_laundry:
			game.director.room_minutes=maxf(game.director.room_minutes,game.laundry.START_MIN+game.laundry.t/60)
			game.laundry.world.visible=false;game.case_mode="";game._apply_laundry_environment(false)
		game.town_bridge.enter(from_laundry)
	else:
		if game.laundry==null:
			stage("组装洗衣楼")
			var prepared=preload("res://scripts/laundry_case.gd").new(game)
			await prepared.prepare_async(stage)
			game.laundry=prepared
			game._laundry_prepared=true
		game._enter_laundry_from_room()
	activated=true
	game.state="prologue_transition";game.player.can_move=false;game.player.allow_capture=false
	stage("确认入口与碰撞")
	game.player.physics_frozen=false
	game.player.set_physics_process(true)
	# Let the existing controller settle at the actual entrance before revealing it.
	for i in range(18):
		await get_tree().physics_frame
		if token!=generation:return
		if game.player.is_on_floor():break
	game.player.physics_frozen=true
	if not game.player.is_on_floor():
		# No invisible fall or control handoff on an unverified floor.
		last_error="入口尚未落稳。请重试准备现场。";show_error();return
	stage("现场就绪")
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	samples.append({"destination":kind,"seconds":(Time.get_ticks_usec()-started)/1e6,"resources":resources_for(kind).size(),"grounded":game.player.is_on_floor()})
	print("SCENE_READY ",JSON.stringify(samples.back()))
	overlay.visible=false;busy=false
	game._exit_to_town=false;game._exit_to_laundry=false;game._exit_laundry_to_town=false
	game.state="play" if kind=="laundry" else "prologue"
	game.player.physics_frozen=false;game.player.can_move=true;game.player.allow_capture=true
	game.player.set_physics_process(true);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	game.safe_pos=game.player.global_position
	game._fade_to(0,.18)
	retained.erase(kind)
	if kind=="town" and game.laundry==null:call_deferred("warm","laundry")

func show_error()->void:
	label.text="现场准备未完成\n\n"+last_error+"\n\n进度保留，尚未交还移动控制。"
	error_actions.visible=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func retry()->void:
	if not busy or not error_actions.visible:return
	error_actions.visible=false;generation+=1;call_deferred("run",generation)

func return_to_origin()->void:
	if not busy or not error_actions.visible:return
	if activated:
		if game.town_bridge.active:game.town_bridge.leave()
		if game.laundry!=null:game.laundry.world.visible=false
		game.case_mode=origin.mode
		if origin.mode=="laundry":
			game.laundry.world.visible=true;game.spots=game.laundry.spots();game._apply_laundry_environment(true)
		elif origin.stage=="town":game._apply_laundry_environment(false);game.town_bridge.enter()
		else:game._apply_laundry_environment(false);game._show_prologue_stage("room")
	game.player.global_position=origin.position;game.player.rotation.y=origin.yaw;game.player.pitch=origin.pitch;game.state=origin.state
	game.safe_pos=game.player.global_position
	game._exit_to_town=false;game._exit_to_laundry=false;game._exit_laundry_to_town=false
	busy=false;overlay.visible=false;generation+=1
	game.player.physics_frozen=false;game.player.can_move=true;game.player.allow_capture=true;game.player.velocity=Vector3.ZERO
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
