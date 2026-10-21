extends Node3D
## 摄像机空间的袖口、手掌与分节手指；不修改角色 GLB。
const SHAPE := preload("res://scripts/charbody.gd")
var item_id := ""
var content: Node3D
var font: Font
var motion := 0.0
var use_xuyan_arms := false

func setup(camera: Camera3D, f: Font) -> void:
	font = f
	camera.add_child(self)
	name = "HeldItemRig"
	set_item("")

func material(color: Color, roughness := .7, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = false
	m.emission = color
	m.emission_energy_multiplier = .65 if glow else .12
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
	elif id == "weird_clock":
		block(Vector3(.19,-.20,-.57),Vector3(.19,.25,.065),material(Color("9f844a")),.012)
		block(Vector3(.19,-.18,-.534),Vector3(.16,.17,.005),material(Color("dfd8b5")),.001)
		text("XII\n\n  ◷  \n\nVI",Vector3(.19,-.176,-.529),.00024,Color("25332e"))
		block(Vector3(.19,-.34,-.57),Vector3(.23,.025,.09),material(Color("393b2f")),.005)
	elif id in ["sweater","sandal","roof_copy"]:
		var prop := "shoe" if id == "sandal" else "sweater"
		preload("res://scripts/case1_prop.gd").place(content,prop,Vector3(.10,-.34,-.62),.21 if prop=="shoe" else .34,.25 if prop=="shoe" else 0.0)
	elif id in ["slip","registry","photo","marriage","cert","homework","return_card","discharge","testimony","pipe_map","notice","waterline","back_water","accident","sign"]:
		block(Vector3(.10,-.19,-.60),Vector3(.28,.20,.004),material(Color("dfd1ae")),.002)
		text("案卷 00184\n\n调查记录",Vector3(.10,-.18,-.594),.00036,Color("26332e"))
	elif id.ends_with("key"):
		segment(Vector3(.22,-.17,-.53),Vector3(.22,-.26,-.53),.007,material(Color("a38c58")))
		block(Vector3(.23,-.25,-.53),Vector3(.03,.025,.01),material(Color("a38c58")),.002)
	elif id != "":
		block(Vector3(.22, -.17, -.53), Vector3(.10, .14, .022), material(Color("b7ad90")), .007)
		text("随身物", Vector3(.22, -.17, -.514), .00028, Color("222f2d"))
	position.y = -.15
	create_tween().tween_property(self, "position:y", 0.0, .24).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	motion += delta
	rotation.z = sin(motion * 1.4) * .006
