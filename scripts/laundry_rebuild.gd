extends RefCounted
## 经引擎通行验证的模块化楼体。剧情接口与静态建筑分离。
const BASE := "res://assets/models/laundry_rebuild/"
var case_ref: WeakRef
var lc:
	get:return case_ref.get_ref()
var a
var roots := {}
var service_cover: Node3D
const POINTS := {
	"lb_booth":Vector3(-1.8,1.22,7.855),
	"l_m9":Vector3(2.35,4.2,4.1),"l_m7":Vector3(0,4.25,2.75),
	"l_backdoor":Vector3(-1.65,4.5,1.9),"l_sign":Vector3(-2.1,4.1,-.2),
	"l_registry":Vector3(-2.6,4.1,.36),"l_boiler":Vector3(-.55,4.4,.6),
	"l_clipping":Vector3(-2.88,4.42,.48),"l_photowall":Vector3(-2.85,4.8,.9),
	"l_keyring":Vector3(-.45,4.85,.6),"l_raincoat":Vector3(-.3,4.5,.1),
	"c1_valve":Vector3(2.7,-2.15,.52),"c1_notice":Vector3(3.04,-1.7,-6.9),
	"c1_waterline":Vector3(2.95,-1.65,-.5),"c1_accident":Vector3(2.58,-1.6,-3.8),
	"c1_sandal":Vector3(3.65,-2.7,-6.1),"c1_ladder":Vector3(2.58,-1.6,-6.1),
	"c1_mail_letter":Vector3(13.8,4.9,12),"c1_roof_patch":Vector3(-.1,16.1,.9),
	"c1_roof_copy":Vector3(-1.2,17.1,5.2),"c1_power":Vector3(4.3,4.85,6.95),
	"c1_cert":Vector3(2.7,7.6,4.05),"c1_keybox":Vector3(2.8,13.45,4.6)
}
func _init(case_world) -> void:
	case_ref=weakref(case_world); a=case_world.art
func build() -> void:
	for floor in ["B1","F1","F2","F3","F4","F5","ROOF","BRIDGE"]:
		var model: Node3D=load("res://assets/models/laundry_finish/"+floor+"_finish.glb").instantiate()
		model.name="Building_"+floor; lc.world.add_child(model); roots[floor]=model
		var collision: Node3D=load(BASE+floor+"_collision.glb").instantiate()
		collision.name="Collision_"+floor;lc.world.add_child(collision)
		convex_ramps(collision)
		finish(model,floor)
	# 天窗可站立；使用检修梯时由禁用物理的攀爬过渡穿过。
	a.col(Vector3(-1.7,15.57,3.5),Vector3(1.2,.05,1.2))
	# The 1F service opening needs a walkable lid. Approaching its interaction
	# point must not make the player fall into the shaft before pressing E.
	a.col(Vector3(2.65,-.025,-8.1),Vector3(.95,.06,1.25))
	service_cover=a.push_group(Vector3(2.65,.015,-8.1))
	a.bev(Vector3.ZERO,Vector3(.93,.035,1.20),a.pbr("metal_grate_rusty",2,Color("748175"),.82,.6,.2),.005)
	for z in [-.51,.51]:a.box(Vector3(0,.023,z),Vector3(.83,.025,.035),a.plain(Color("596b5f"),.65,.4))
	a.pop_group()
	lc.f2=preload("res://scripts/laundry/floor2_laundry.gd").new(a)
	lc.f2._materials()
	for i in range(6):
		lc.f2.drums[i+1]=lc.f2._machine_glb(Vector3(-2.8,3.96,3.15+i*.92),PI/2)
	for item in [[8,2.6],[9,4.1],[10,5.6],[11,8.6]]:
		lc.f2.drums[item[0]]=lc.f2._machine_glb(Vector3(2.8,3.96,item[1]),-PI/2)
	lc.f2._machine_seven()
	lc.f2.doors["back"]=door("后房门",Vector3(-2.1,3.5,1.9),.9,2.05,0)
	lc.f2.mirror_surface=a.box(Vector3(3.065,5.05,5.5),Vector3(.012,1.2,.8),a.plain(Color("657e80")),false)
	lc.b2={"keyring":a.box(Vector3(-.45,4.85,.6),Vector3(.08,.05,.05),a.plain(Color("9a864e")),false)}
	var doors4={"402":door("402",Vector3(-2.55,9.8,5.4),.9,2.05,0)}
	var doors5={"503":door("503",Vector3(1.25,12.7,5.4),.9,2.05,0)}
	var water=find_mesh(roots.B1,"水面")
	if water==null:water=a.box(Vector3(4,-1.9,1.5),Vector3(2,.015,3),a.glass(Color(.13,.23,.24,.7)),false)
	lc.buildings={"f4":{"k":{"doors":doors4}},"f5":{"doors":doors5},"roof":roots.ROOF,
		"b1":{"water":water,"water_base_y":water.position.y,"sandal_model":null},
		"power_room":{"door":door("配电门",Vector3(3.2,3.5,6.5),.9,2.05,-PI/2)}}
	lc.buildings.power_room.door.rotation.y=-PI/2-1.5
	for item in [["303",Vector3(-1.7,6.9,6.4)],["304",Vector3(1.1,6.9,5.6)],["403",Vector3(-.45,9.8,5.4)],["502",Vector3(-2.15,12.7,5.4)],["302",Vector3(-2.5,6.9,2.2)]]:
		var open_door=door(item[0],item[1],.9,2.05,1.5)
	door("401",Vector3(1.65,9.8,5.4),.9,2.05,0)
	# 有实体、可辨识的调查对象，避免凭空的交互点。
	a.label("得利自助洗衣店",Vector3(1.55,6.0,9.92),.12,Color("dfd0a1"),PI)
	# Put the signing surface on the public side of the booth glass, not inside its frame.
	a.bev(Vector3(-1.8,1.22,7.872),Vector3(.48,.58,.025),a.plain(Color("514a37")),.008)
	a.box(Vector3(-1.8,1.22,7.855),Vector3(.42,.52,.008),a.plain(Color("cdc4a9")),false)
	var handover=a.label("夜班交接簿\n\n到岗请签名\n上一班：____",Vector3(-1.8,1.22,7.847),.035,Color("302e25"),PI)
	handover.no_depth_test=false;handover.double_sided=false
	a.label("交班终端",Vector3(-2.1,4.8,8.35),.055,Color("d8ceae"),PI/2)
	a.label("9",Vector3(2.32,4.52,4.1),.05,Color("dfd2b6"),-PI/2)
	a.label("配电房 →",Vector3(2.0,5.4,8.03),.06,Color("e4d6b7"),0)
	a.label("秀 兰 干 洗",Vector3(-2.1,4.1,-.2),.09,Color("bcb99c"),0)
	# 剪报和照片各有自己的实体与瞄准位置，不再挤在同一个点。
	a.box(Vector3(-2.96,4.42,.48),Vector3(.018,.24,.18),a.plain(Color("d3c4a2")),false)
	for line in range(4):
		a.box(Vector3(-2.945,4.49-float(line)*.045,.48),Vector3(.008,.008,.13),a.plain(Color("665f51")),false)
	a.box(Vector3(4.65,4.7,6.95),Vector3(.4,.7,.18),a.plain(Color("354b46")),false)
	for floor in [1,2,3,4,5]:
		var y: float=[0,3.5,6.9,9.8,12.7][floor-1]
		a.label("%dF  ↑ 下一层  /  ↓ 门厅"%floor,Vector3(.36,y+1.5,10.3),.065,Color("d9cfae"),PI/2)
		for z in [4.4,8.6,13.7]:
			var light=a.omni(Vector3(.0 if z<10 else 1.55,y+2.25,z),Color("e8d8b1") if floor in [1,4] else Color("d5e1db"),1.20 if floor==2 else .85,5.5,z==8.6)
			light.light_size=.30;light.shadow_bias=.035;light.shadow_normal_bias=.32
	preload("res://scripts/laundry_finish.gd").new(lc).build()
	for pos in [Vector3(2.6,-.7,-6),Vector3(2.6,-.7,-1),Vector3(16,6,9)]:a.omni(pos,Color("b3c8c4"),.85,7,false)
func finish(node: Node, floor: String) -> void:
	if node is MeshInstance3D:
		var text=String(node.name)
		if floor=="B1" and text.contains("检修台"):
			node.visible=false;return
		if text in ["F2后房门","F2配电门","F4_402门","F5_503门","F3_302门","F3_303门","F3_304门","F4_403门","F4_401门","F5_502门"] or (floor=="F2" and (text.contains("洗衣机") or text.contains("烘干机") or text.contains("七号机"))):
			node.visible=false
		else:
			var mat: Material
			if text.contains("地面") or text.contains("地板") or text.contains("踏步") or text.contains("平台") or text.contains("通道") or text.contains("池底"):
				var surface=a.pbr("terrazzo_tiles",1.0,Color("c3ba9f"),.82,0,.3) if floor=="F2" else a.pbr("concrete_floor",.6,Color("a3aaa0"))
				var fm=ShaderMaterial.new();fm.shader=preload("res://shaders/building_floor.gdshader")
				fm.set_shader_parameter("floor_tex",surface.albedo_texture)
				fm.set_shader_parameter("rough_tex",surface.roughness_texture)
				fm.set_shader_parameter("scale_uv",1.0 if floor=="F2" else .6)
				fm.set_shader_parameter("tint",Color.WHITE if floor=="F2" else Color("a3aaa0"))
				mat=fm
			elif text.contains("玻璃"):
				mat=a.glass(Color(.25,.35,.36,.35))
			elif text.contains("天花") or text.contains("顶板") or text.contains("顶棚"):
				mat=a.pbr("painted_plaster_wall",.45,Color("b4b0a0"),1,0,.12)
			elif text.contains("墙") or text.contains("隔") or text.contains("壁") or text.contains("井体") or text.contains("井筒"):
				mat=preload("res://scripts/laundry_finish.gd").new(lc).wall(floor)
			elif text.contains("长椅"):mat=a.plain(Color("516d69"),.72)
			elif text.contains("CRT"):mat=a.plain(Color("363e35"),.7)
			elif text.contains("电视"):mat=a.plain(Color("434d43"),.75)
			elif text.contains("水箱"):mat=a.pbr("metal_plate",.6,Color("8a9286"),.85,.35,.18)
			elif text.contains("纸箱") or text.contains("退信"):mat=a.pbr("rough_linen",2,Color("a5956c"),1,0,.08)
			elif text.contains("信箱") or text.contains("邮筒") or text.contains("玩具机"):mat=a.plain(Color("52685d"),.7,.15)
			elif text.contains("绳"):mat=a.plain(Color("7c7457"))
			elif text.contains("童装") or text.contains("水痕"):mat=a.pbr("rough_linen",3,Color("455e60"),1,0,.2)
			elif text.contains("水面") or text.contains("积水"):mat=a.glass(Color(.16,.22,.21,.7))
			elif text.contains("床") or text.contains("柜") or text.contains("桌"):mat=a.pbr("oak_wood_planks",.8,Color("817868"))
			elif text.contains("管") or text.contains("铁") or text.contains("梯"):mat=a.pbr("rusty_metal",.8,Color("938b79"),1,1)
			else:mat=a.plain(Color("89958a"),.9)
			node.material_override=mat
	for child in node.get_children():finish(child,floor)
func find_mesh(node: Node, word: String) -> MeshInstance3D:
	if node is MeshInstance3D and String(node.name).contains(word):return node
	for child in node.get_children():
		var found=find_mesh(child,word)
		if found!=null:return found
	return null
func convex_ramps(node: Node) -> void:
	if node is CollisionShape3D and String(node.get_parent().name).contains("_Ramp") and node.shape is ConcavePolygonShape3D:
		var shape=ConvexPolygonShape3D.new();shape.points=node.shape.get_faces();node.shape=shape
	for child in node.get_children():convex_ramps(child)
func door(id: String, at: Vector3, width: float, height: float, yaw: float) -> Node3D:
	var hinge=Node3D.new();hinge.name="Door_"+id;lc.world.add_child(hinge);hinge.position=at;hinge.rotation.y=yaw
	var model=load("res://assets/models/laundry_finish/door_finish.glb").instantiate()
	hinge.add_child(model);model.scale=Vector3(width/.9,height/2.05,1)
	preload("res://scripts/laundry_finish.gd").new(lc).dress(model)
	var body=StaticBody3D.new();var col=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(width,height,.045)
	col.shape=shape;col.position=Vector3(width/2,height/2,0);body.add_child(col);hinge.add_child(body)
	return hinge
