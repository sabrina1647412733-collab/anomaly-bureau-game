extends RefCounted
## Refinement on the approved shell. Furniture stays outside tested walking corridors.
var a
var lc
const BASE="res://assets/models/laundry_finish/"
func _init(case_world):
	lc=case_world;a=lc.art
func prop(id:String,at:Vector3,yaw:=0.0)->Node3D:
	var n:Node3D=load(BASE+id+"_finish.glb").instantiate();a.root.add_child(n);n.position=at;n.rotation.y=yaw
	dress(n);return n
func dress(node:Node)->void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var m=node.get_active_material(i)
			if m is StandardMaterial3D:
				var id=String(m.resource_name)
				if id.contains("木"):node.set_surface_override_material(i,a.pbr("oak_wood_planks",1.6,Color("9c8a6b"),.9,0,.2))
				elif id.contains("绿漆"):node.set_surface_override_material(i,a.pbr("painted_concrete",.85,Color("687d70"),.85,.08,.12))
	for c in node.get_children():dress(c)
func wall(floor:String)->ShaderMaterial:
	var key="finish_wall_"+floor
	if a.mats.has(key):return a.mats[key]
	var m=ShaderMaterial.new();m.shader=preload("res://shaders/aged_wall.gdshader")
	var y={"B1":-3.,"F1":0.,"F2":3.5,"F3":6.9,"F4":9.8,"F5":12.7,"ROOF":15.6,"BRIDGE":3.5}
	m.set_shader_parameter("floor_y",y.get(floor,0.))
	if floor=="B1":m.set_shader_parameter("lower_color",Color("35423d"));m.set_shader_parameter("upper_color",Color("74796a"))
	elif floor in ["F3","F4","F5"]:m.set_shader_parameter("lower_color",Color("656d58"));m.set_shader_parameter("upper_color",Color("b2ad93"))
	a.mats[key]=m;return m
func plaque(text:String,p:Vector3,size:Vector2,yaw:=0.,font_size:=.042)->void:
	a.push_group(p,yaw)
	a.bev(Vector3.ZERO,Vector3(size.x,size.y,.025),a.plain(Color("263c38"),.78),.005)
	var label=a.label(text,Vector3(0,0,.016),font_size,Color("d6cdab"),0)
	label.no_depth_test=false;label.double_sided=false
	a.pop_group()
func build()->void:
	prop("bench",Vector3(1.93,3.5,6.65))
	var steel=a.pbr("metal_plate",1.4,Color("737b73"),.78,.55,.22)
	var oak=a.pbr("oak_wood_planks",1.8,Color("87775b"),.9,0,.22)
	var cream=a.plain(Color("b4b1a0"),.86)
	var dark=a.plain(Color("273c35"),.84)
	# Cabinet front details, folding worktop, detergent and folded linen.
	for z in [7.76,8.42,9.08]:
		a.bev(Vector3(-2.025,3.98,z),Vector3(.025,.76,.6),oak,.008)
		a.box(Vector3(-2.004,4.09,z-.22),Vector3(.03,.12,.018),steel)
	a.bev(Vector3(-2.38,4.57,8.4),Vector3(.7,.055,2.12),cream,.012)
	for i in range(3):
		a.bev(Vector3(-.7,4.27+i*.035,9.28),Vector3(.42,.032,.3),a.pbr("rough_linen",2,Color("8b9a89"),1,0,.25),.008)
	for i in range(3):
		a.cyl(Vector3(-2.4,4.69,7.65+i*.14),.044,.2,a.plain(Color("596b62"),.5),16)
		a.cyl(Vector3(-2.4,4.8,7.65+i*.14),.027,.025,cream,16)
	# The drawer target used to be unsupported in space; it now belongs to a real chest.
	a.bev(Vector3(-.83,7.33,3.15),Vector3(.56,.86,.64),oak,.012,true)
	for y in [7.08,7.34,7.6]:
		a.bev(Vector3(-.83,y,3.482),Vector3(.50,.23,.025),oak,.006)
		a.box(Vector3(-.83,y,3.507),Vector3(.12,.018,.035),steel)
	# A supported document corner on 304's existing desk, away from the doorway.
	a.bev(Vector3(2.83,7.57,4.27),Vector3(.56,.055,1.04),oak,.008)
	# Bed fabrics, pillows and wardrobe structure replace solid wooden blocks visually.
	a.bev(Vector3(-2.175,7.49,3.75),Vector3(1.78,.095,1.42),a.pbr("rough_linen",2.4,Color("9a9a7f"),1,0,.28),.035,true)
	a.bev(Vector3(-2.77,7.58,3.75),Vector3(.44,.13,1.15),a.pbr("rough_linen",2.6,Color("bab49b"),1,0,.22),.045)
	for z in [3.23,3.51,3.79,4.07,4.35]:
		a.box(Vector3(-1.76,7.543,z),Vector3(.55,.008,.012),a.plain(Color("58665e")))
	for z in [5.,5.58]:
		a.bev(Vector3(-2.528,7.9,z),Vector3(.025,1.87,.55),oak,.008)
		a.box(Vector3(-2.503,7.85,z),Vector3(.035,.12,.016),steel)
	# Doors, room labels and light housings make the levels legible without adding barriers.
	for floor in range(1,6):
		var y:float=[0.,3.5,6.9,9.8,12.7][floor-1]
		for z in [4.4,8.6,13.7]:
			var x=0. if z<10 else 1.55
			a.bev(Vector3(x,y+2.36,z),Vector3(.18,.075,.78),steel,.012)
			a.bev(Vector3(x,y+2.315,z),Vector3(.12,.025,.68),a.emit(Color("c7d7c9"),.85),.008)
		plaque(str(floor)+"F",Vector3(.35,y+1.9,10.35),Vector2(.38,.22),PI/2,.058)
	for item in [["303",Vector3(-1.25,9.13,6.4)],["304",Vector3(1.55,9.13,5.4)],["402",Vector3(-2.1,12.03,5.4)],["403",Vector3(0,12.03,5.4)],["503",Vector3(1.7,14.93,5.4)]]:
		plaque(item[0],item[1],Vector2(.34,.16),0,.045)
	plaque("工作须知\n先记录 · 后交班",Vector3(-1.85,5.1,9.88),Vector2(.86,.52),PI,.05)
	plaque("夜 班 工 作 须 知\n\n记录广播　保管未取件\n勿强开七号机　按时交班",Vector3(-2.2,5.4,2.08),Vector2(1.05,.72),0,.045)
	plaque("七号机\n夜间请勿使用",Vector3(0,4.85,1.94),Vector2(.9,.46),0,.055)
	a.bev(Vector3(-2.23,4.75,8.35),Vector3(.3,.32,.37),dark,.018)
	a.bev(Vector3(-2.071,4.79,8.35),Vector3(.012,.19,.28),a.emit(Color("6d9180"),.18),.009)
	a.bev(Vector3(-1.99,4.605,8.35),Vector3(.25,.035,.31),steel,.006)
	a.bev(Vector3(-2.99,5.55,8.85),Vector3(.15,.28,.32),dark,.015)
	for z in range(6):a.box(Vector3(-2.906,5.55,8.73+z*.045),Vector3(.012,.22,.008),steel)
	# Service floor wear and pipe fasteners; overhead details leave capsule routes clear.
	for p in [Vector3(2.72,-1.1,-6.1),Vector3(2.72,-1.1,-3.6),Vector3(2.72,-1.1,-1.1)]:
		a.box(p,Vector3(.15,.035,.16),steel)
	var workbench=prop("workbench",Vector3(-1.6,-3,-8.125),0)
	workbench.scale=Vector3(2.1/.64,1.,.65/.76)
	for i in range(5):
		a.box(Vector3(-1.9+i*.17,16.06,1),Vector3(.1,.015,.4),a.plain(Color("363c35")))
	# 304 bed, 503 damp bedding, and 402 household details retain their old footprints.
	for item in [[Vector3(1.45,7.39,2.8),Vector3(1.82,.09,.92),"949d88"],[Vector3(2,13.17,2.85),Vector3(1.72,.08,1.22),"667f78"]]:
		a.bev(item[0],item[1],a.pbr("rough_linen",2.1,Color(item[2]),1,0,.2),.035,true)
	for item in [[Vector3(.78,7.47,2.8),Vector3(.4,.12,.72)],[Vector3(1.36,13.25,2.85),Vector3(.4,.11,.95)]]:
		a.bev(item[0],item[1],a.pbr("rough_linen",2.5,Color("aba891"),1,0,.2),.035)
	# The old TV cube gets a recessed screen, bezel, controls and warm wood feet.
	for p in [Vector3(-1.26,.92,8.792),Vector3(-2.6,10.67,2.72)]:
		a.bev(p,Vector3(.41,.29,.035),a.plain(Color("172322"),.55),.025)
		a.bev(p+Vector3(-.025,0,.022),Vector3(.30,.22,.015),a.emit(Color("5e7773"),.13),.025)
		for y in [-.07,.05]:a.cyl(p+Vector3(.17,y,.025),.018,.02,cream,16,"z")
	# Seven miniature machines are not seven blank cubes.
	for i in range(7):
		var z=2.6+i*.34
		a.cyl(Vector3(2.782,12.87,z),.095,.025,steel,24,"x")
		a.cyl(Vector3(2.763,12.87,z),.070,.012,dark,24,"x")
		a.box(Vector3(2.76,13.005,z),Vector3(.012,.03,.17),cream)
	# Label and seal each stored parcel; the route across the bridge is unchanged.
	for z in [5.9,6.15,6.4,6.65]:
		a.bev(Vector3(14.9,4.86,z),Vector3(.6,.022,.21),a.plain(Color("a59979")),.004)
		a.box(Vector3(14.9,4.876,z),Vector3(.025,.006,.20),cream)
