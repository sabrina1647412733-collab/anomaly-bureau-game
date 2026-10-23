extends Node3D
## 独立第一人称网格与持物过渡；第三人称仍使用许砚原角色。
const SHAPE := preload("res://scripts/charbody.gd")
var item_id := ""
var content: Node3D
var font: Font
var motion := 0.0
var use_xuyan_arms := false
var switch_tween: Tween
var switching := false
var lift_tween: Tween
var frozen := false
var paused_tweens: Array[Tween] = []

func setup(camera: Camera3D, f: Font) -> void:
	font = f
	camera.add_child(self)
	name = "HeldItemRig"
	set_item("")

func material(color: Color, roughness := .7, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.emission_enabled = glow
	m.emission = color
	m.emission_energy_multiplier = .35 if glow else 0.
	return m

func block(pos: Vector3, extent: Vector3, mat: Material, bevel := .008) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var minimum := minf(extent.x, minf(extent.y, extent.z))
	mesh.mesh = SHAPE.bev_box(extent, clampf(bevel, .0008, maxf(.0008, minimum * .5 - .002)))
	# 极薄屏幕用精确厚度，避免倒角工具的最小厚度把屏幕文字埋住。
	if extent.z < .008:
		var thin := BoxMesh.new()
		thin.size = extent
		mesh.mesh = thin
	mesh.material_override = mat
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content.add_child(mesh)
	return mesh

func segment(a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius * .86
	shape.bottom_radius = radius
	shape.height = a.distance_to(b)
	shape.radial_segments = 14
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = (a + b) * .5
	content.add_child(mesh)
	mesh.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func text(value: String, pos: Vector3, scale_px: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = value
	label.font = font
	label.font_size = 48
	label.pixel_size = scale_px
	label.modulate = color
	label.outline_size = 0
	label.position = pos
	if value == "23:40": label.set_meta("clock_label",true)
	content.add_child(label)

func update_time(minutes: float) -> void:
	for node in content.get_children():
		if node is Label3D and node.has_meta("clock_label"):
			var value := int(minutes) % 1440
			node.text = "%02d:%02d" % [value/60,value%60]

func set_item(id: String) -> void:
	if switch_tween!=null:switch_tween.kill()
	if lift_tween!=null:lift_tween.kill()
	switching=false
	item_id = id
	var model_arms := get_node_or_null("XuYanActualArms")
	if model_arms != null:
		model_arms.visible = id != ""
	if content != null:
		remove_child(content)
		content.queue_free()
	content = Node3D.new()
	add_child(content)
	if id != "":
		var hands := preload("res://scripts/first_person_hands.gd").new()
		content.add_child(hands)
		hands.build(id)
	if id == "phone":
		var p := Vector3(.205, -.17, -.515)
		block(p, Vector3(.090, .184, .014), material(Color("101a1e"), .3), .009)
		block(p + Vector3(0, 0, .008), Vector3(.079, .162, .002), material(Color("1c5349"), .35, true), .004)
		text("23:40", p + Vector3(0, .034, .010), .00040, Color("e8f2de"))
		text("微语  电话\n钱包  相册", p + Vector3(0, -.026, .010), .00017, Color("dcebd7"))
		block(p + Vector3(0, .071, .010), Vector3(.025, .004, .001), material(Color("102720")), .001)
	elif id == "envelope":
		block(Vector3(.075, -.19, -.60), Vector3(.30, .205, .004), material(Color("e2d4b3")), .002)
		text("诡异事务局\n\n入职通知书\n\n许砚  收", Vector3(.065, -.181, -.595), .00037, Color("302e29"))
	elif id == "photo":
		block(Vector3(.075,-.19,-.60),Vector3(.30,.205,.004),material(Color("d4c4a0")),.002)
		var image_mat=material(Color.WHITE,.85)
		image_mat.albedo_texture=load("res://assets/ui/inventory/materials/family_photo_v1.png")
		var picture=MeshInstance3D.new();var plane=QuadMesh.new();plane.size=Vector2(.278,.182);picture.mesh=plane;picture.position=Vector3(.075,-.19,-.596);picture.material_override=image_mat;content.add_child(picture)
	elif id == "weird_clock":
		block(Vector3(.19,-.20,-.57),Vector3(.19,.25,.065),material(Color("9f844a")),.012)
		block(Vector3(.19,-.18,-.534),Vector3(.16,.17,.005),material(Color("dfd8b5")),.001)
		text("XII\n\n  ◷  \n\nVI",Vector3(.19,-.176,-.529),.00024,Color("25332e"))
		block(Vector3(.19,-.34,-.57),Vector3(.23,.025,.09),material(Color("393b2f")),.005)
	elif id in ["sweater","sandal","roof_copy"]:
		var prop := "shoe" if id == "sandal" else "sweater"
		preload("res://scripts/case1_prop.gd").place(content,prop,Vector3(.10,-.34,-.62),.21 if prop=="shoe" else .34,.25 if prop=="shoe" else 0.0)
	elif id in ["slip","registry","marriage","cert","homework","return_card","discharge","testimony","pipe_map","notice","waterline","back_water","accident","sign"]:
		block(Vector3(.075,-.19,-.60),Vector3(.30,.205,.004),material(Color("dfd1ae")),.002)
		var docs=preload("res://scripts/laundry_campaign.gd").DOCS
		var label:String=String(docs[id][0])+"\n\n"+String(docs[id][1]).split("\n\n")[0] if docs.has(id) else "案卷00184\n\n调查记录"
		text(wrap_caption(label,1080.),Vector3(.075,-.18,-.594),.00023,Color("26332e"))
	elif id.ends_with("key"):
		segment(Vector3(.22,-.17,-.53),Vector3(.22,-.26,-.53),.007,material(Color("a38c58")))
		block(Vector3(.23,-.25,-.53),Vector3(.03,.025,.01),material(Color("a38c58")),.002)
	elif id != "":
		block(Vector3(.22, -.17, -.53), Vector3(.10, .14, .022), material(Color("b7ad90")), .007)
		text("随身物", Vector3(.22, -.17, -.514), .00028, Color("222f2d"))
	if id!="":
		content.position.y=-.24
		lift_tween=create_tween()
		lift_tween.tween_property(content,"position:y",0.,.24).set_trans(Tween.TRANS_SINE)

func transition_to(id: String) -> void:
	if id==item_id and not switching:return
	if switch_tween!=null:switch_tween.kill()
	if lift_tween!=null:lift_tween.kill()
	if content==null or item_id=="":set_item(id);return
	switching=true
	switch_tween=create_tween()
	switch_tween.tween_property(content,"position:y",-.36,.14).set_trans(Tween.TRANS_SINE)
	switch_tween.tween_callback(func():set_item(id))

func freeze(on: bool) -> void:
	if frozen==on:return
	frozen=on
	if on:
		paused_tweens.clear()
		for tween in [switch_tween,lift_tween]:
			if tween!=null and tween.is_valid() and tween.is_running():
				tween.pause()
				paused_tweens.append(tween)
	else:
		for tween in paused_tweens:
			if tween!=null and tween.is_valid():tween.play()
		paused_tweens.clear()

func wrap_caption(value: String,max_width: float) -> String:
	var output:PackedStringArray=[]
	for original in value.split("\n"):
		var line=""
		for character in original:
			if font.get_string_size(line+character,HORIZONTAL_ALIGNMENT_LEFT,-1,48).x>max_width:
				output.append(line);line=""
			line+=character
		output.append(line)
	return "\n".join(output.slice(0,11))

func _process(delta: float) -> void:
	if frozen:return
	motion += delta
	rotation.z = sin(motion * 1.4) * .006
