extends Control
## Physical examination inside the existing reader; ownership and saves stay in campaign.
const SUPPORTED := ["slip","photo","discharge","roof_copy","sweater","sandal","accident"]
var story
var item_id := ""
var flipped := false
var checked := {}
var panel: Panel
var title: Label
var hint: Label
var result: Label
var choices: VBoxContainer
var viewport: SubViewport
var prop: Node3D
var front: Node3D
var back: Node3D
var rotation_tween: Tween
var buttons: Array[Button] = []
var compare_values := [0,0,0]

func setup(campaign) -> void:
	story=campaign
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel=story.game.phone_ui.box(self,Vector2(100,65),Vector2(1400,770),Color("1b1c19"),4)
	var ui=story.game.phone_ui
	ui.lab(panel,"现 场 检 查   /   00184",Vector2(32,24),Vector2(900,30),18,Color("bea77d"))
	title=ui.lab(panel,"",Vector2(32,65),Vector2(1200,46),30)
	hint=ui.lab(panel,"",Vector2(880,138),Vector2(470,105),20,Color("d0c6b2"))
	result=ui.lab(panel,"",Vector2(880,510),Vector2(470,130),20,Color("c4b689"))
	choices=VBoxContainer.new();choices.position=Vector2(880,260);choices.size=Vector2(470,240);choices.add_theme_constant_override("separation",12);panel.add_child(choices)
	var container=SubViewportContainer.new();container.position=Vector2(24,125);container.size=Vector2(825,560);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(container)
	viewport=SubViewport.new();viewport.size=Vector2i(825,560);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.msaa_3d=Viewport.MSAA_2X;container.add_child(viewport)
	var camera=Camera3D.new();camera.position=Vector3(0,0,1.1);camera.fov=43;camera.current=true;viewport.add_child(camera)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_CLEAR_COLOR;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.6;viewport.add_child(env)
	var lamp=OmniLight3D.new();lamp.position=Vector3(-.25,.65,.7);lamp.omni_range=3;lamp.light_energy=1.3;lamp.light_color=Color("ffe7c0");viewport.add_child(lamp)
	ui.btn(panel,"收起  ·  ESC",Vector2(1120,685),Vector2(230,50),story.close_page)
	ui.lab(panel,"点击右侧检查点  ·  证据与已完成检查会保留  ·  检查期间时间暂停",Vector2(34,704),Vector2(1010,35),17,Color("999789"))
	visible=false

func fit() -> void:
	var area=get_viewport_rect().size
	var factor=minf(area.x/1600.,area.y/900.)
	panel.scale=Vector2.ONE*factor;panel.position=(area-panel.size*factor)*.5

func open(id: String) -> void:
	item_id=id;flipped=false;checked={};compare_values=[0,0,0]
	visible=true;fit();story.modal.get_child(1).visible=false
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	title.text=story.DOCS[id][0]
	result.text=""
	for child in viewport.get_children():
		if child==prop:viewport.remove_child(child);child.queue_free()
	prop=Node3D.new();viewport.add_child(prop)
	if id in ["sweater","roof_copy","sandal"]:
		var object_id="shoe" if id=="sandal" else "sweater"
		preload("res://scripts/case1_prop.gd").place(prop,object_id,Vector3(0,-.18,0),.62 if id!="sandal" else .43,0)
		if id=="roof_copy":story.damp_garment(prop)
	else:_paper(id)
	_refresh()

func close() -> void:
	visible=false
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if rotation_tween!=null:rotation_tween.kill()
	story.modal.get_child(1).visible=true

func _paper(id: String) -> void:
	var mesh=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(.78,.52,.004);mesh.mesh=box
	var m=StandardMaterial3D.new();m.albedo_color=Color("d4c39b");m.roughness=.95;mesh.material_override=m;prop.add_child(mesh)
	front=Node3D.new();back=Node3D.new();prop.add_child(front);prop.add_child(back);back.rotation.y=PI
	if id=="photo":
		var picture=MeshInstance3D.new();var plane=QuadMesh.new();plane.size=Vector2(.70,.44);picture.mesh=plane;picture.position.z=.004
		var photo=StandardMaterial3D.new();photo.albedo_texture=load("res://assets/ui/inventory/materials/family_photo_v1.png");photo.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;picture.material_override=photo;front.add_child(picture)
	else:
		var label="秀兰干洗 · 留存联\n\n2004-11-07\n顾客  周秀兰\n七号机  ·  童装一套\n\n状态：未取"
		if id=="discharge":label="挂号件  27—503—1107\n\n出院小结\n患者  周小满  /  男  /  6岁\n出院日期  2004-11-06\n\n收件家属  周秀兰"
		elif id=="accident":label="事故复核 · 暂不下结论\n\n口述 → 管线 → 水痕 → 通知\n\n可证实的事才写入案卷。\n\n人的去向与物品的位置\n不能混为一谈。"
		_label(front,label,Vector3(0,0,.006))
	_label(back,"小满六岁，出院回来补拍。\n\n墨水已经渗进纸里。\n\n这句话证明拍照时的生活，\n不能证明事故后的去向。" if id=="photo" else "旧件留存  /  请核对正面字段\n\n未核实的内容，不填入结论。",Vector3(0,0,.006))

func _label(parent: Node3D,value: String,at: Vector3) -> void:
	var label=Label3D.new();label.font=story.game.font;label.text=value;label.position=at;label.font_size=64;label.pixel_size=.00052;label.modulate=Color("3b3529");label.outline_size=0;label.double_sided=false;parent.add_child(label)

func _button(value: String,callback: Callable) -> void:
	var button=Button.new();button.text="%d  ·  %s"%[buttons.size()+1,value];button.custom_minimum_size=Vector2(460,54);button.add_theme_font_override("font",story.game.font);button.add_theme_font_size_override("font_size",19);button.add_theme_stylebox_override("normal",story.game.phone_ui.style(Color("32382e"),3,Color("67694f")));button.pressed.connect(callback);choices.add_child(button);buttons.append(button)

func _refresh() -> void:
	for child in choices.get_children():choices.remove_child(child);child.queue_free()
	buttons.clear()
	match item_id:
		"photo":
			hint.text="照片正面有刮痕。先翻到背面，再记录留下的题字。"
			_button("翻回正面" if flipped else "翻到照片背面",flip)
			_button("记录背面题字",func(): examine("inscription"))
			buttons[-1].disabled=not flipped
		"slip":
			hint.text="把洗衣单上的日期、机号和状态逐项核对。"
			for key in ["date","machine","status"]:
				var labels={"date":"日期  /  2004-11-07","machine":"机号  /  七号机","status":"状态  /  未取"}
				_button(("✓  " if checked.has(key) else "检查  ")+labels[key],func(): examine(key))
		"discharge":
			hint.text="退件卡的转存号是 27—503—1107。先核对封套，取错可放回。"
			for number in ["27—503—1106","27—503—1107","27—303—1107"]:_button("取出  "+number,func(): choose_parcel(number))
		"sweater","roof_copy","sandal":
			hint.text="转动物件，检查能与其他证据对上的细节。"
			_button("转到背面" if not flipped else "转回正面",flip)
			_button("检查补线" if item_id=="sandal" else "检查袖口两道白条",func(): examine("stitch"))
			_button("与304另一只鞋核对" if item_id=="sandal" else "触摸并核对干湿",func(): examine("condition"))
		"accident":
			hint.text="逐项选取有物证支持的结论。判断错误可以复查，已取证据不会丢失。"
			var names=["周秀兰的遭遇","事故经过","周小满的去向"]
			var opts=[["尚未选择","被困后房，倒灌造成死亡","只有火灾，与水无关"],["尚未选择","管线、水痕与口述互相印证","屋顶七件衣服代表七个孩子"],["尚未选择","事故后去向未明，继续保留待查","找到童鞋，说明已确认死亡"]]
			for i in range(3):_button(names[i]+"："+opts[i][compare_values[i]],func(): set_conclusion(i,(compare_values[i]+1)%3))
			_button("提交复核",submit_conclusions)

func flip() -> void:
	flipped=not flipped
	if rotation_tween!=null:rotation_tween.kill()
	rotation_tween=create_tween();rotation_tween.tween_property(prop,"rotation:y",PI if flipped else 0.,.42).set_trans(Tween.TRANS_SINE)
	story.game.audio_system.sfx("paper_turn" if item_id not in ["sweater","sandal","roof_copy"] else "cloth",-13)
	_refresh()

func examine(key: String) -> void:
	if item_id=="photo" and not flipped:return
	checked[key]=true
	story.game.audio_system.sfx("paper",-16)
	if item_id=="photo":_complete("题字已记录：小满六岁，出院回来补拍。下一步到304找完整姓名。")
	elif item_id=="slip" and checked.size()>=3:_complete("日期、七号机与“未取”已相互对应。这是一单没有完成的衣服。")
	elif item_id in ["sweater","roof_copy","sandal"] and checked.size()>=2:
		_complete("补线位置与304留下的另一只鞋对应；孩子的去向仍不能下结论。" if item_id=="sandal" else ("原衣袖口两道白条，触感干燥。屋顶复制品始终湿着。" if item_id=="sweater" else "七件衣服共用一张单号，袖口相同，却全部潮湿。重复的是物，不是七个孩子。"))
	else:result.text="已记录一处特征。继续检查剩余字段。"
	_refresh()

func choose_parcel(number: String) -> void:
	if number!="27—503—1107":
		result.text="编号不符，已放回原位。对照退件卡的中段503与末段1107，再选一次。"
		story.game.audio_system.sfx("device_blocked",-19)
		return
	story.doc("discharge",false)
	_complete("封套编号相符。出院日11月6日早于洗衣日11月7日，姓名与接种证对应。")

func set_conclusion(index: int,value: int) -> void:
	compare_values[index]=value;_refresh()

func submit_conclusions() -> bool:
	if compare_values!=[1,1,1]:
		result.text="还有结论缺少依据。请对照老周口述、停水通知和旧水痕；找到童鞋不等于确认孩子死亡。"
		story.game.audio_system.sfx("device_blocked",-18)
		return false
	story.doc("accident",false)
	_complete("复核通过：周秀兰的遭遇已核实。周小满事故后去向未明，保留待查。")
	return true

func _complete(message: String) -> void:
	story.mark("examined_"+item_id)
	result.text="✓  "+message
	story.game.note("物",title.text+" · 检查",message)
	story.game.audio_system.sfx("ui_tap",-14)

func _input(event: InputEvent) -> void:
	if not visible or not story.modal.visible or story.game.state!="case_reader":return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int=event.physical_keycode
		if code>=KEY_1 and code<=KEY_9:
			var index=code-KEY_1
			if index<buttons.size() and not buttons[index].disabled:buttons[index].pressed.emit()
		elif code==KEY_F and item_id in ["photo","sweater","roof_copy","sandal"]:flip()
		else:return
		get_viewport().set_input_as_handled()
