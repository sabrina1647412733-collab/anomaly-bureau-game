extends Node
## Password-gated, same-project inspection. Scene changes run in a separate data
## scope; normal progress is captured before entry and restored on exit.
const Storage := preload("res://scripts/storage_paths.gd")
const Save := preload("res://scripts/case_save.gd")
const Archive := preload("res://scripts/archive.gd")
const USERNAME := "sabrina"
const SALT := "52c1396724ab331abe6d30eaeab868d4b3fbbd7f6b5ffc7d"
const PASSWORD_HASH := "852129a780a7e45f93689dbfaad79e72a1fb7c03456dcec87b3264b4c9e3d4ba"
var game
var active := false
var authenticated := false
var busy := false
var login_open := false
var prior_state := "menu"
var prior_controls := {}
var snapshot:Dictionary={}
var prior_paths:Dictionary={}
var prior_fallback:Dictionary={}
var review_dir := ""
var locations:Array[Dictionary]=[]
var current_id := ""
var family := ""
var last_anchor := Vector3.ZERO
var history:Array[String]=[]
var bookmark:Dictionary={}
var camera:Camera3D
var flight := true
var speed := 5.
var pitch := 0.
var light:OmniLight3D
var case2_world
var frozen_nodes:Array[Dictionary]=[]
var hidden_layers:Array[Dictionary]=[]
var frozen_audio:Array[Dictionary]=[]
var layer:CanvasLayer
var ui:Control
var dim:ColorRect
var login:PanelContainer
var panel:PanelContainer
var account:LineEdit
var password:LineEdit
var login_status:Label
var status:Label
var badge:Label
var search:LineEdit
var list:VBoxContainer
var flight_button:Button
var minute_control:HSlider
var rain_control:HSlider
var wet_control:HSlider
var failures := 0
var retry_at := 0
var minute := 720.
var rainfall := 0.
var wetness := 0.
var show_badge := true
var capturing := false
var footing_delay := 0.

func setup(g)->void:
	game=g
	review_dir=Storage.root_dir().get_base_dir().path_join("_开发者数据")
	_build_catalog()
	_build_ui()
	var entry:Button=game.menu._ghost_btn("开发者巡查  ·  F6",open_login)
	entry.name="DeveloperReviewButton";entry.position=Vector2(500,750);entry.custom_minimum_size=Vector2(370,48)
	entry.add_theme_font_size_override("font_size",18);entry.add_theme_color_override("font_color",Color("dbc08b"))
	game.menu.center.add_child(entry)
	if OS.get_cmdline_user_args().has("--developer-review"):call_deferred("open_login")

func _label(text:String,size:=18)->Label:
	var node:=Label.new();node.text=text;node.add_theme_font_size_override("font_size",size)
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return node

func _button(parent:Node,text:String,callback:Callable)->Button:
	var b:=Button.new();b.text=text;b.custom_minimum_size.y=42;b.pressed.connect(callback);parent.add_child(b)
	return b

func _box(parent:Node,extent:Vector2)->PanelContainer:
	var box:=PanelContainer.new();box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left=-extent.x*.5;box.offset_right=extent.x*.5;box.offset_top=-extent.y*.5;box.offset_bottom=extent.y*.5
	box.add_theme_stylebox_override("panel",game.menu._panel_style());parent.add_child(box)
	return box

func _build_ui()->void:
	layer=CanvasLayer.new();layer.layer=90;add_child(layer)
	ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
	var theme:=Theme.new();theme.default_font=game.font;theme.default_font_size=18;ui.theme=theme
	dim=ColorRect.new();dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,.015,.02,.84);dim.mouse_filter=Control.MOUSE_FILTER_STOP;ui.add_child(dim);dim.hide()
	login=_box(ui,Vector2(550,410));var col:=VBoxContainer.new();col.add_theme_constant_override("separation",14);login.add_child(col)
	col.add_child(_label("开发者巡查 · 身份验证",27));col.add_child(_label("输入账号与密码。巡查数据与正式进度分开保存。",16))
	account=LineEdit.new();account.placeholder_text="账号";account.text=USERNAME;account.custom_minimum_size.y=45;col.add_child(account)
	password=LineEdit.new();password.secret=true;password.placeholder_text="密码";password.custom_minimum_size.y=45;col.add_child(password)
	password.text_submitted.connect(func(_value):submit_login())
	login_status=_label("",16);login_status.custom_minimum_size.y=30;col.add_child(login_status)
	var buttons:=HBoxContainer.new();col.add_child(buttons)
	_button(buttons,"登录巡查",submit_login).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_button(buttons,"取消",cancel_login).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	login.hide()
	panel=_box(ui,Vector2(1260,760));var columns:=HBoxContainer.new();columns.add_theme_constant_override("separation",26);panel.add_child(columns)
	var left:=VBoxContainer.new();left.custom_minimum_size.x=565;left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(left)
	left.add_child(_label("场景巡查 / 地点",28));search=LineEdit.new();search.placeholder_text="搜索地点、楼层或建筑名字";left.add_child(search);search.text_changed.connect(func(_value):_refresh_list())
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(550,580);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;left.add_child(scroll)
	list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",5);scroll.add_child(list)
	var right:=VBoxContainer.new();right.custom_minimum_size.x=550;right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.add_theme_constant_override("separation",12);columns.add_child(right)
	right.add_child(_label("查看与移动",27));right.add_child(_label("F6 面板 · F7 飞行/行走 · F8 安全站位\n飞行：WASD / 鼠标，E上升、Q下降，Shift加速。\nF9截图 · F10隐藏/显示巡查标识",16))
	flight_button=_button(right,"切换为正常行走",toggle_flight)
	var row:=HBoxContainer.new();right.add_child(row)
	_button(row,"上个地点",go_back).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_button(row,"安全站位",recover).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row=HBoxContainer.new();right.add_child(row)
	_button(row,"保存当前视角",save_bookmark).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_button(row,"恢复上次视角",restore_bookmark).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row=HBoxContainer.new();right.add_child(row)
	_button(row,"重载当前区域",reload_area).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_button(row,"截图到F盘/游戏目录",take_screenshot).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var inspect_light:=CheckBox.new();inspect_light.text="检查补光（只影响巡查）";right.add_child(inspect_light);inspect_light.toggled.connect(func(on):if light!=null:light.visible=on)
	right.add_child(_label("室外时间与天气（固定，不推进剧情）",19))
	minute_control=HSlider.new();minute_control.min_value=0;minute_control.max_value=1439;minute_control.step=10;minute_control.value=minute;right.add_child(minute_control);minute_control.value_changed.connect(func(value):minute=value;_weather())
	row=HBoxContainer.new();right.add_child(row)
	for entry in [["白天",720.],["黄昏",1080.],["夜晚",1380.]]:
		var value:float=entry[1];_button(row,entry[0],func():minute_control.value=value).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	right.add_child(_label("雨量",16));rain_control=HSlider.new();rain_control.max_value=1;rain_control.step=.05;right.add_child(rain_control);rain_control.value_changed.connect(func(value):rainfall=value;_weather())
	right.add_child(_label("地面湿度",16));wet_control=HSlider.new();wet_control.max_value=1;wet_control.step=.05;right.add_child(wet_control);wet_control.value_changed.connect(func(value):wetness=value;_weather())
	status=_label("选择地点，直接查看当前工程已接入的场景。",16);status.size_flags_vertical=Control.SIZE_EXPAND_FILL;right.add_child(status)
	_button(right,"退出巡查，恢复原进度",end_session)
	panel.hide()
	badge=_label("",17);badge.position=Vector2(28,24);badge.size=Vector2(1250,85);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;badge.add_theme_color_override("font_color",Color("efd59c"));badge.add_theme_color_override("font_shadow_color",Color.BLACK);badge.add_theme_constant_override("shadow_offset_y",2);ui.add_child(badge);badge.hide()
	_refresh_list()

func _build_catalog()->void:
	locations=[{"id":"room","name":"出租屋 / 主角房间","family":"room","pos":Vector3(-.35,12.1,323.05)}]
	for place in game.town_bridge.layout.get("landmarks",[]):
		var front:Vector2=Vector2(place.front[0],place.front[1]);var direction:Vector2=(front-Vector2(place.x,place.z)).normalized()
		if direction.length()<.01:direction=Vector2(0,1)
		var at:Vector2=front+direction*2.2
		locations.append({"id":"town_"+String(place.id),"name":"回潮镇 / "+String(place.name),"family":"town","pos":game.town_bridge.ORIGIN+Vector3(at.x,.1,at.y),"focus":game.town_bridge.ORIGIN+Vector3(place.x,2.5,place.z)})
	for row in [["c1_1","第一案 / 1F门厅与传达室",Vector3(-.55,.08,-7.6)],["c1_2","第一案 / 2F洗衣店",Vector3(.1,3.55,8.5)],["c1_seven","第一案 / 七号洗衣机近景",Vector3(0,3.55,4.35)],["c1_counter","第一案 / 柜台与长椅",Vector3(1.4,3.55,7.6)],["c1_3","第一案 / 3F住户层",Vector3(-.4,6.95,5.3)],["c1_4","第一案 / 4F老周住户层",Vector3(-.4,9.85,5.3)],["c1_5","第一案 / 5F维修住户层",Vector3(-.4,12.75,5.3)],["c1_roof","第一案 / 屋顶与水箱",Vector3(-.2,15.65,6.0)],["c1_b1","第一案 / B1检修步道",Vector3(2.7,-2.88,-.8)]]:
		locations.append({"id":row[0],"name":row[1],"family":"case1","pos":row[2]})
	for row in [[1,"值守室与总表"],[8,"何伯家与厨房"],[16,"储物间与居住痕迹"],[17,"异常走廊（巡查临时显示）"]]:
		locations.append({"id":"c2_"+str(row[0]),"name":"第二案 / %dF %s"%[row[0],row[1]],"family":"case2","floor":row[0]})

func _refresh_list()->void:
	if list==null:return
	for node in list.get_children():list.remove_child(node);node.queue_free()
	var filter:=search.text.strip_edges() if search!=null else ""
	for entry in locations:
		if not filter.is_empty() and not String(entry.name).to_lower().contains(filter.to_lower()):continue
		var id:=String(entry.id);var b:=_button(list,entry.name,func():visit(id));b.alignment=HORIZONTAL_ALIGNMENT_LEFT

func verify_credentials(user:String,value:String)->bool:
	return user==USERNAME and (SALT+":"+user+":"+value).sha256_text()==PASSWORD_HASH

func open_login()->void:
	if busy:return
	if active:_toggle_panel();return
	if login_open:return
	var normal:String=game._pre_pause_state if game.state=="paused" else game.state
	if normal not in ["menu","play","prologue","case_end"] or game.phone_open or game.bag_open or game.nb_open:
		game.feedback.notify("先收起当前界面","关闭手机、阅读或对话后，再按F6进入巡查。")
		return
	prior_state=game.state
	prior_controls={"move":game.player.can_move,"capture":game.player.allow_capture,"frozen":game.player.physics_frozen,"mouse":Input.mouse_mode}
	game.state="developer_login";game.player.can_move=false;game.player.allow_capture=false;game.player.physics_frozen=true
	login_open=true;login_status.text="";password.text="";dim.show();login.show();password.grab_focus();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func cancel_login()->void:
	if not login_open:return
	password.text="";login.hide();dim.hide();login_open=false;game.state=prior_state
	game.player.can_move=prior_controls.move;game.player.allow_capture=prior_controls.capture;game.player.physics_frozen=prior_controls.frozen;Input.mouse_mode=prior_controls.mouse

func submit_login()->void:
	if not login_open:return
	if Time.get_ticks_msec()<retry_at:login_status.text="请稍等几秒再试。";return
	var ok:=verify_credentials(account.text.strip_edges(),password.text);password.text=""
	if not ok:
		failures+=1;login_status.text="账号或密码不正确。"
		if failures>=5:retry_at=Time.get_ticks_msec()+5000;failures=0
		return
	authenticated=true;failures=0;login.hide();login_open=false;game.state=prior_state
	_begin_session()

func _scope(on:bool)->void:
	if on:
		prior_paths={"root":Storage.cached_root,"archive":Archive.PATH,"export":Archive.EXPORT_PATH,"progress":Save.PROGRESS_PATH,"auto":game.exit_save.PATH,"slots":game.SLOT_PATHS.duplicate()}
		DirAccess.make_dir_recursive_absolute(review_dir)
		Storage.cached_root=review_dir;Storage.inspection_active=true
		Archive.PATH=Storage.file("archive.json");Archive.EXPORT_PATH=Storage.file("archive_export.json");Save.PROGRESS_PATH=Storage.file("laundry_archive.json");game.exit_save.PATH=Storage.file("autosave.json")
		game.SLOT_PATHS=[Storage.file("save_1.json"),Storage.file("save_2.json"),Storage.file("save_3.json")]
		var ignore:=FileAccess.open(review_dir.path_join(".gdignore"),FileAccess.WRITE);if ignore!=null:ignore.close()
	else:
		Storage.cached_root=prior_paths.root;Archive.PATH=prior_paths.archive;Archive.EXPORT_PATH=prior_paths.export;Save.PROGRESS_PATH=prior_paths.progress;game.exit_save.PATH=prior_paths.auto;game.SLOT_PATHS=prior_paths.slots.duplicate();Storage.inspection_active=false

func _begin_session()->void:
	if not authenticated or active:return
	snapshot=game.exit_save.snapshot() if prior_state!="menu" else {}
	if prior_state!="menu" and snapshot.is_empty():
		authenticated=false;game.state=prior_state;game.player.physics_frozen=prior_controls.frozen;game.player.can_move=prior_controls.move;game.player.allow_capture=prior_controls.capture
		game.feedback.notify("当前进度暂不能进入巡查","先结束眼前的演出或返回主菜单。")
		Input.mouse_mode=prior_controls.mouse;dim.hide()
		return
	prior_fallback=game.exit_save.fallback.duplicate(true);_scope(true);active=true
	game.set_process(false);game.exit_save.set_process(false);game.safety.set_physics_process(false)
	game.case2_controller.reset();game._discard_laundry();game._start_prologue(false);game._clear_sub();game.archive_tracking=false
	game.phone_ui.incoming=false;game.audio_system.stop_voice();game.audio_system.ring.stop()
	game.state="developer_review";game.menu.hide_all();game.menu.hide();game.hud_fade.modulate.a=0.
	camera=Camera3D.new();camera.name="DeveloperReviewCamera";camera.near=.04;camera.far=450;camera.fov=74;game.add_child(camera)
	light=OmniLight3D.new();light.light_energy=1.8;light.omni_range=12;light.visible=false;camera.add_child(light)
	_hide_layers();_mute_audio();_load_bookmark();panel.show();badge.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if bookmark.has("location"):restore_bookmark()
	else:visit("room")

func _hide_layers()->void:
	for node in game.find_children("*","CanvasLayer",true,false):
		if node==layer:continue
		var found:=false;for item in hidden_layers:if item.node==node:found=true
		if not found:hidden_layers.append({"node":node,"visible":node.visible})
		node.visible=false

func _mute_audio()->void:
	for node in game.find_children("*","",true,false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			var found:=false;for item in frozen_audio:if item.node==node:found=true
			if not found:frozen_audio.append({"node":node,"paused":node.stream_paused})
			node.stream_paused=true

func _freeze(node:Node)->void:
	if node==null:return
	for item in frozen_nodes:if item.node==node:return
	frozen_nodes.append({"node":node,"mode":node.process_mode});node.process_mode=Node.PROCESS_MODE_DISABLED

func _clear_area()->void:
	if game.town_bridge.active:game.town_bridge.leave()
	game.town_bridge.weather.inspection_override.clear()
	if is_instance_valid(case2_world):case2_world.set_active(false);case2_world.queue_free();case2_world=null
	game._discard_laundry()
	for node in game.prologue_roots.values():node.visible=false
	family=""

func visit(id:String,remember:=true)->bool:
	if not authenticated or not active or busy:return false
	var entry:Dictionary={}
	for item in locations:if item.id==id:entry=item;break
	if entry.is_empty():return false
	busy=true;game.player.physics_frozen=true;status.text="正在载入："+String(entry.name)
	var previous:=current_id
	if family!=entry.family:
		_clear_area()
		match String(entry.family):
			"room":game._start_prologue(false)
			"town":game.town_bridge.enter()
			"case1":game.start_laundry_case();_freeze(game.laundry.campaign)
			"case2":
				game._hide_station_world();game._apply_laundry_environment(true)
				case2_world=load("res://scripts/case2/case2_world.gd").new();game.add_child(case2_world);case2_world.setup(game);case2_world.set_anomaly_open(true)
		family=String(entry.family)
	game.state="developer_review";game._clear_sub();game.menu.hide_all();game.menu.hide();game.hud_fade.modulate.a=0.
	game.case2_controller.continuation.hide();_hide_layers();_mute_audio()
	await get_tree().physics_frame;await get_tree().physics_frame
	var wanted:Vector3=case2_world.get_floor_spawn(int(entry.floor)) if family=="case2" else entry.pos
	var focus:Vector3=entry.get("focus",wanted+Vector3(0,1.66,-5))
	if family=="case2":
		var views:Dictionary={1:[Vector3(-3.2,.05,-1),Vector3(-5.5,1.2,-3.6)],8:[Vector3(-2.5,21.05,-1.2),Vector3(-5.3,22,-3.5)],16:[Vector3(-2.55,45.05,-1.2),Vector3(-5.1,45.7,-4.6)],17:[Vector3(.7,48.05,3.3),Vector3(-.6,49.1,-5.4)]}
		wanted=case2_world.to_global(views[int(entry.floor)][0]);focus=case2_world.to_global(views[int(entry.floor)][1])
	elif family=="room":focus=Vector3(1.4,13,323.5)
	var feet:=safe_feet(wanted)
	if not feet.is_finite():
		status.text="该地点未找到安全落脚点，保留原位置。";busy=false;return false
	last_anchor=feet;game.player.global_position=feet;game.player.velocity=Vector3.ZERO;game.player.cam_mode=0;game.player.body.visible=false;game.player.pitch=0.;game.player.cam.rotation=Vector3.ZERO
	var direction:Vector3=focus-(feet+Vector3(0,1.66,0))
	game.player.rotation.y=atan2(-direction.x,-direction.z);game.player.pitch=atan2(direction.y,Vector2(direction.x,direction.z).length());game.player.cam.rotation.x=game.player.pitch
	camera.global_transform=game.player.cam.global_transform;pitch=camera.rotation.x
	current_id=id;if remember and previous!="" and previous!=id:history.append(previous)
	_weather();busy=false;_apply_movement();status.text=String(entry.name)+"\n巡查期间剧情与正式进度不推进。"
	return true

func safe_feet(wanted:Vector3)->Vector3:
	var offsets:Array[Vector2]=[Vector2.ZERO]
	for radius in [.5,1.,1.5,2.5]:
		for i in range(12):offsets.append(Vector2(cos(i*TAU/12),sin(i*TAU/12))*float(radius))
	var space=game.get_world_3d().direct_space_state
	for offset in offsets:
		var at:=wanted+Vector3(offset.x,0,offset.y)
		var ray:=PhysicsRayQueryParameters3D.create(at+Vector3(0,.35,0),at-Vector3(0,.7,0),1,[game.player.get_rid()])
		var hit:Dictionary=space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y<.65:continue
		var feet:Vector3=hit.position+Vector3(0,.035,0)
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=game.player.cap;query.transform=Transform3D(Basis.IDENTITY,feet+Vector3(0,.87,0));query.collision_mask=1;query.exclude=[game.player.get_rid()]
		if space.intersect_shape(query,1).is_empty():return feet
	return Vector3(INF,INF,INF)

func _apply_movement()->void:
	if not active:return
	game.player.can_move=not panel.visible and not flight;game.player.allow_capture=game.player.can_move;game.player.physics_frozen=flight or panel.visible;game.player.dragging=false
	camera.current=flight;game.player.cam.current=not flight
	flight_button.text="切换为正常行走  [ F7 ]" if flight else "切换为自由飞行  [ F7 ]"
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if panel.visible else Input.MOUSE_MODE_CAPTURED
	dim.visible=panel.visible

func _toggle_panel()->void:
	if not active:return
	panel.visible=not panel.visible;_apply_movement()

func toggle_flight()->void:
	if not active or busy:return
	if not flight:
		camera.global_transform=game.player.cam.global_transform;pitch=camera.rotation.x;flight=true
	else:
		var feet:=safe_feet(camera.global_position-Vector3(0,1.66,0))
		if not feet.is_finite():feet=last_anchor;status.text="当前位置不能站立，已回到本地点的安全站位。"
		game.player.global_position=feet;game.player.velocity=Vector3.ZERO;game.player.rotation.y=camera.rotation.y;game.player.pitch=clampf(camera.rotation.x,-1.4,1.4);game.player.cam.rotation=Vector3(game.player.pitch,0,0);flight=false
	_apply_movement()

func recover()->void:
	if not active or busy:return
	game.player.global_position=last_anchor;game.player.velocity=Vector3.ZERO;camera.global_transform=game.player.cam.global_transform;_apply_movement()

func go_back()->void:
	if not active or history.is_empty() or busy:return
	visit(history.pop_back(),false)

func reload_area()->void:
	if not active or busy or current_id.is_empty():return
	var id:=current_id
	var saved_view:Transform3D=camera.global_transform if flight else game.player.cam.global_transform
	var was_flying:=flight
	var root_node:Node=game.town_bridge if family=="town" else (game.laundry.world if family=="case1" else case2_world)
	if is_instance_valid(root_node):
		var paths:Dictionary={}
		for node in root_node.find_children("*","Node3D",true,false):
			if String(node.scene_file_path).ends_with(".glb"):paths[node.scene_file_path]=true
		for path in paths:
			# Replace the cache owner, not the contents of resources still referenced
			# by the old rendered scene (CACHE_MODE_REPLACE invalidates materials).
			var fresh:PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
			if fresh!=null:fresh.take_over_path(path)
	var reload_town:=family=="town"
	_clear_area()
	if reload_town:
		var old=game.town_bridge
		old.map_layer.queue_free();old.queue_free()
		game.town_bridge=preload("res://scripts/town/town_bridge.gd").new();game.town_bridge.setup(game,game.font)
	if await visit(id,false):
		if was_flying:
			camera.global_transform=saved_view;pitch=camera.rotation.x
		else:
			var feet:=safe_feet(saved_view.origin-Vector3(0,1.66,0))
			game.player.global_position=feet if feet.is_finite() else last_anchor
			game.player.rotation.y=saved_view.basis.get_euler().y;game.player.pitch=saved_view.basis.get_euler().x;game.player.cam.rotation.x=game.player.pitch
		_apply_movement()

func _weather()->void:
	if not active:return
	game.director.room_minutes=minute;game.clock_min=minute
	if family=="town":
		game.town_bridge.weather.inspection_override={"minute":minute,"rain":rainfall,"wetness":wetness}
		game.town_bridge.weather.refresh(0.)

func save_bookmark()->void:
	if not authenticated or not active or busy or current_id.is_empty():return
	var view:Camera3D=camera if flight else game.player.cam
	var p:Vector3=view.global_position;var r:Vector3=view.global_rotation
	bookmark={"version":1,"location":current_id,"eye":[p.x,p.y,p.z],"rotation":[r.x,r.y,r.z],"minute":minute,"rain":rainfall,"wetness":wetness}
	var file:=FileAccess.open(review_dir.path_join("巡查记录.json"),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(bookmark,"\t"));file.close();status.text="已保存巡查地点和视角。"
	else:status.text="巡查视角保存失败，请检查游戏目录是否可写。"

func _load_bookmark()->void:
	var path:=review_dir.path_join("巡查记录.json")
	if not FileAccess.file_exists(path):return
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("version",0))!=1 or not data.get("location") is String:return
	for key in ["eye","rotation"]:
		if not data.get(key) is Array or data[key].size()!=3:return
		for value in data[key]:if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)):return
	for key in ["minute","rain","wetness"]:
		if typeof(data.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(data[key])):return
	bookmark=data

func restore_bookmark()->void:
	if not active or busy:return
	if bookmark.is_empty():status.text="暂无保存的巡查视角。";return
	if not await visit(String(bookmark.location),false):return
	minute_control.value=clampf(float(bookmark.minute),0,1439);rain_control.value=clampf(float(bookmark.rain),0,1);wet_control.value=clampf(float(bookmark.wetness),0,1)
	var p:Array=bookmark.eye;var r:Array=bookmark.rotation;camera.global_position=Vector3(p[0],p[1],p[2]);camera.global_rotation=Vector3(r[0],r[1],r[2]);pitch=r[0];flight=true;_apply_movement()

func take_screenshot()->void:
	if not authenticated or not active or busy:return
	if DisplayServer.get_name()=="headless":status.text="后台无画面模式不能截图。";return
	var was_open:=panel.visible;capturing=true;busy=true;panel.hide();badge.hide();dim.hide()
	await get_tree().process_frame
	RenderingServer.force_draw(false,1./60.)
	var folder:=review_dir.path_join("截图");DirAccess.make_dir_recursive_absolute(folder)
	var stamp:=Time.get_datetime_string_from_system().replace(":","-")
	var path:=folder.path_join(stamp+"_"+current_id+"_"+str(Time.get_ticks_msec())+".png")
	var err:int=game.get_viewport().get_texture().get_image().save_png(path)
	panel.visible=was_open;capturing=false;busy=false;badge.visible=show_badge;status.text="截图已保存："+path if err==OK else "截图保存失败。";_apply_movement()

func end_session()->bool:
	if not active or busy:return false
	save_bookmark();busy=true;_clear_area()
	for item in frozen_nodes:if is_instance_valid(item.node):item.node.process_mode=item.mode
	frozen_nodes.clear()
	for item in hidden_layers:if is_instance_valid(item.node):item.node.visible=item.visible
	hidden_layers.clear()
	for item in frozen_audio:if is_instance_valid(item.node):item.node.stream_paused=item.paused
	frozen_audio.clear();camera.queue_free();camera=null;light=null;panel.hide();badge.hide();dim.hide()
	_scope(false);active=false;authenticated=false;family="";current_id="";history.clear()
	game.exit_save.fallback=prior_fallback.duplicate(true);game.exit_save.set_process(true);game.safety.set_physics_process(true);game.set_process(true)
	var restored:=true
	if not snapshot.is_empty():restored=Save.restore(game,snapshot)
	else:game._show_menu()
	if restored and prior_state=="paused":game._open_pause()
	game.player.cam.current=true;game.safety.reset_zone();busy=false
	if not restored:game._show_menu();game.feedback.notify("原进度恢复失败","请从原来的正式存档继续，巡查未覆盖存档。")
	return restored

func _process(delta:float)->void:
	var area:Vector2=game.get_viewport().get_visible_rect().size
	panel.pivot_offset=Vector2(630,380);panel.scale=Vector2.ONE*minf(1.,minf((area.x-30)/1260.,(area.y-30)/760.))
	login.pivot_offset=Vector2(275,205);login.scale=Vector2.ONE*minf(1.,minf((area.x-30)/550.,(area.y-30)/410.))
	if not active:return
	badge.visible=show_badge and not panel.visible and not capturing
	var current_name:=current_id
	for entry in locations:if entry.id==current_id:current_name=entry.name;break
	badge.text="开发者巡查  ·  sabrina  ·  "+current_name+"  ·  "+("自由飞行" if flight else "正常行走")+"\nF6 面板  /  F7 切换移动  /  F8 安全站位  /  F9 截图  /  F10 标识    时间 %02d:%02d"%[int(minute)/60,int(minute)%60]
	if busy or panel.visible:return
	if flight:
		var movement:=Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W):movement.z-=1
		if Input.is_physical_key_pressed(KEY_S):movement.z+=1
		if Input.is_physical_key_pressed(KEY_A):movement.x-=1
		if Input.is_physical_key_pressed(KEY_D):movement.x+=1
		var vertical:=float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q))
		var direction:Vector3=camera.global_basis*movement+Vector3.UP*vertical
		camera.global_position+=direction.limit_length(1)*speed*(3. if Input.is_physical_key_pressed(KEY_SHIFT) else 1.)*delta
		game.player.global_position=camera.global_position-Vector3(0,1.66,0)
	else:
		camera.global_transform=game.player.cam.global_transform
		var p:Vector3=game.player.global_position
		footing_delay+=delta
		if footing_delay>.3 and game.player.is_on_floor():
			footing_delay=0.
			var supported:=safe_feet(p)
			if supported.is_finite() and supported.distance_to(p)<.15:last_anchor=supported
		if not p.is_finite() or p.y<last_anchor.y-6.:recover()

func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F6:
			if login_open:cancel_login()
			else:open_login()
			get_viewport().set_input_as_handled();return
		if login_open and event.physical_keycode==KEY_ESCAPE:cancel_login();get_viewport().set_input_as_handled();return
		if login_open and event.physical_keycode==KEY_TAB:
			if password.has_focus():account.grab_focus()
			else:password.grab_focus()
			get_viewport().set_input_as_handled();return
		if not active:return
		match event.physical_keycode:
			KEY_ESCAPE:_toggle_panel()
			KEY_F7:toggle_flight()
			KEY_F8:recover()
			KEY_F9:take_screenshot()
			KEY_F10:show_badge=not show_badge
			_:return
		get_viewport().set_input_as_handled()
	elif active and flight and not panel.visible and event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		camera.rotation.y-=event.relative.x*game.player.mouse_sens;pitch=clampf(pitch-event.relative.y*game.player.mouse_sens,-1.45,1.45);camera.rotation.x=pitch;get_viewport().set_input_as_handled()
