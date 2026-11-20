extends Control
## A resumable physical task: drag the cloth across the OUTSIDE of the glass.
const CENTER := Vector2(490,450)
const RADIUS := 205.0
const SURFACE:=preload("res://scripts/shift_surface.gd")
class Smears extends Control:
	var work
	func _draw()->void:work.draw_smears(self)
var duty
var dragging := false
var last := Vector2.ZERO
var cursor := Vector2.ZERO
var status: Label
var answer: Button
var wrong: Button
var sound_left := 0.0
var viewport:SubViewport
var smears:Control

func setup(owner_duty) -> void:
	duty=owner_duty
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ui=duty.game.phone_ui
	var title=ui.lab(self,"03 / 机门外侧清洁",Vector2(105,65),Vector2(850,60),32)
	title.modulate=Color("e7dfcc")
	ui.lab(self,"夜班巡检 · 不拆机，不启用七号机",Vector2(108,123),Vector2(1000,35),20,Color("b0ac9f"))
	ui.lab(self,"按住鼠标左键，来回擦拭玻璃。\n擦净后，判断印痕在哪一侧。\n\n键盘：按住空格，自动移动抹布。\nEsc 收起；已经擦过的区域会保留。",Vector2(865,230),Vector2(590,180),24,Color("e7dfcc"))
	status=ui.lab(self,"",Vector2(865,440),Vector2(590,95),24,Color("c5a878"))
	answer=ui.btn(self,"1  ·  外侧擦净，印痕仍在内侧",Vector2(865,555),Vector2(590,62),complete)
	wrong=ui.btn(self,"2  ·  印痕已经擦掉，可以启用",Vector2(865,635),Vector2(590,62),retry)
	ui.btn(self,"Esc  ·  暂时收起",Vector2(865,735),Vector2(590,58),func():duty.story.close_page())
	_build_view()
	visible=false
	resized.connect(queue_redraw)

func fit() -> void:
	var extent=get_viewport_rect().size
	var k=minf(extent.x/1600.0,extent.y/900.0)
	scale=Vector2.ONE*k
	position=(extent-Vector2(1600,900)*k)*.5

func open() -> void:
	visible=true;dragging=false;fit();refresh();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS

func close() -> void:
	visible=false;dragging=false
	if viewport!=null:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED

func cell_point(index:int) -> Vector2:
	return CENTER+Vector2((index%8-3.5)*50,(index/8-3.5)*50)

func active_cell(index:int) -> bool:
	return cell_point(index).distance_to(CENTER)<RADIUS-12

func coverage() -> float:
	var total=0;var clean=0
	for i in range(64):
		if not active_cell(i):continue
		total+=1
		if duty.story.flag("glass_cell_%d"%i):clean+=1
	return float(clean)/maxi(1,total)

func refresh() -> void:
	var clean=coverage()>=.8
	status.text="外侧已擦净。\n那只手印……一点也没淡。" if clean else "外侧清洁 %d%%\n有一块印痕擦不掉。"%roundi(coverage()*100)
	answer.disabled=not clean;wrong.disabled=not clean
	queue_redraw()
	if smears!=null:smears.queue_redraw()

func stroke(at:Vector2,previous:Vector2) -> void:
	if not visible or duty.game.state!="case_reader":return
	var changed=false
	for i in range(64):
		if active_cell(i) and Geometry2D.get_closest_point_to_segment(cell_point(i),previous,at).distance_to(cell_point(i))<46:
			var id="glass_cell_%d"%i
			if not duty.story.flag(id):duty.story.mark(id);changed=true
	if changed:
		if sound_left<=0:duty.game.audio_system.sfx("cloth",-24);sound_left=.35
		refresh();duty.sync_glass()

func complete() -> void:
	if coverage()<.8:return
	duty.story.mark("glass_checked")
	duty.game.note("物","三号机巡检","外侧已擦净，内侧手印仍在。不能靠清洁消除，已登记异常。")
	duty.story.show_page("清洁完成，异常待查","抹布是湿的，玻璃外侧已经干净。\n手印仍在滚筒那一面，指尖朝着店里。\n\n你在巡检单上写：外侧清洁完成，内侧印痕未消除，不擅自启动。\n\n下一项：取出九号烘干机里的纸，按日期、机号与未取状态核对。")

func retry() -> void:
	if coverage()<.8:return
	status.text="外侧已经擦净，手印仍清楚。\n不能填“已消除”，再看玻璃内侧。"
	duty.game.audio_system.sfx("ui_tap",-16)

func _input(event:InputEvent) -> void:
	if not visible or duty.game.state!="case_reader":return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		cursor=get_global_transform_with_canvas().affine_inverse()*event.position
		dragging=event.pressed and cursor.distance_to(CENTER)<RADIUS+30
		last=cursor
		if dragging:stroke(cursor,cursor);get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		cursor=get_global_transform_with_canvas().affine_inverse()*event.position;stroke(cursor,last);last=cursor
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:complete()
			KEY_2:retry()
			KEY_ESCAPE:duty.story.close_page()
			_:return
		get_viewport().set_input_as_handled()

func _process(delta:float) -> void:
	sound_left=maxf(0,sound_left-delta)
	if not visible or duty.game.state!="case_reader":return
	fit()
	if Input.is_physical_key_pressed(KEY_SPACE):
		# The same stroke/coverage logic as the mouse, with no instant-complete key.
		var t=Time.get_ticks_msec()/1000.0
		cursor=CENTER+Vector2(sin(t*3)*185,sin(t*.73)*180)
		stroke(cursor,cursor);queue_redraw()
	smears.queue_redraw()

func _build_view()->void:
	var container=SubViewportContainer.new();container.position=Vector2(100,180);container.size=Vector2(780,540)
	container.mouse_filter=Control.MOUSE_FILTER_IGNORE;container.stretch=true;add_child(container)
	viewport=SubViewport.new();viewport.size=Vector2i(780,540);viewport.own_world_3d=true
	viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;container.add_child(viewport)
	var environment=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("101818")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("aac6be");env.ambient_light_energy=.6;environment.environment=env;viewport.add_child(environment)
	var machine=load("res://assets/models/laundry_finish/washer_finish.glb").instantiate();viewport.add_child(machine)
	var camera=Camera3D.new();camera.position=Vector3(0,.438,1.30);camera.fov=36;viewport.add_child(camera);camera.look_at(Vector3(0,.438,.42));camera.current=true
	for row in [[Vector3(-.7,1.2,1.1),Color("c2d6d0"),1.3],[Vector3(.8,.4,.9),Color("e4c89b"),.65]]:
		var light=OmniLight3D.new();light.position=row[0];light.light_color=row[1];light.light_energy=row[2];light.omni_range=3;viewport.add_child(light)
	var print_mesh=MeshInstance3D.new();var mesh=QuadMesh.new();mesh.size=Vector2(.37,.37);print_mesh.mesh=mesh
	var mat=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_texture=SURFACE.palm();mat.roughness=.43;print_mesh.material_override=mat
	print_mesh.position=Vector3(0,.438,.426);viewport.add_child(print_mesh)
	smears=Smears.new();smears.work=self;smears.mouse_filter=Control.MOUSE_FILTER_IGNORE;smears.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(smears)

func _draw() -> void:
	if duty==null:return
	draw_style_box(preload("res://scripts/field_ui_style.gd").box(Color("151b1b")),Rect2(65,40,1470,800))

func draw_smears(canvas:Control)->void:
	# A fixed smear layout: no per-frame random noise or texture flashing.
	for i in range(64):
		if not active_cell(i) or duty.story.flag("glass_cell_%d"%i):continue
		var p=cell_point(i)+Vector2(sin(i*2.7)*6,cos(i*1.9)*6)
		canvas.draw_texture_rect(SURFACE.dirt(),Rect2(p-Vector2(48,48),Vector2(96,96)),false,Color(1,1,1,.7))
	if dragging or Input.is_physical_key_pressed(KEY_SPACE):
		canvas.draw_style_box(preload("res://scripts/field_ui_style.gd").box(Color("6e8582"),Color("aab6a7"),5),Rect2(cursor-Vector2(32,22),Vector2(64,44)))
		for i in range(4):canvas.draw_line(cursor+Vector2(-26,-16+i*9),cursor+Vector2(26,-14+i*9),Color(.7,.76,.71,.3),1,true)
