extends SceneTree
## Offline stills: existing case props + original procedural paper/phone/clock/key models.
const OUT := "res://assets/ui/inventory/"
const SHAPE := preload("res://scripts/charbody.gd")
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
func _initialize():call_deferred("run")
func mat(color:Color,metal:=0.0,rough:=.6)->StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metal;m.roughness=rough;return m
func box(parent:Node3D,extent:Vector3,at:Vector3,m:Material,bevel:=.003)->MeshInstance3D:
	var visual=MeshInstance3D.new()
	if minf(extent.x,minf(extent.y,extent.z))<.006:
		var shape=BoxMesh.new();shape.size=extent;visual.mesh=shape
	else:visual.mesh=SHAPE.bev_box(extent,minf(bevel,minf(extent.x,minf(extent.y,extent.z))*.5-.002))
	visual.position=at;visual.material_override=m;parent.add_child(visual);return visual
func image(parent:Node3D,name:String,extent:Vector2,at:Vector3)->void:
	var visual=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=extent;visual.mesh=quad
	var material=mat(Color.WHITE,0,.86)
	material.albedo_texture=load(OUT+"materials/"+("family_photo_v1" if name=="photo" else name)+".png")
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override=material;visual.position=at;parent.add_child(visual)
func cylinder(parent:Node3D,radius:float,height:float,at:Vector3,m:Material,front:=false)->void:
	var visual=MeshInstance3D.new();var shape=CylinderMesh.new()
	shape.top_radius=radius;shape.bottom_radius=radius;shape.height=height;shape.radial_segments=64
	visual.mesh=shape;visual.material_override=m;visual.position=at
	if front:visual.rotation.x=PI*.5
	parent.add_child(visual)
func build(id:String)->Node3D:
	var holder=Node3D.new();world.add_child(holder)
	var brass=mat(Color("a58a50"),.68,.31)
	var paper=mat(Color("cbb78e"),0,.88)
	if id in ["sweater","shoe"]:
		preload("res://scripts/case1_prop.gd").place(holder,id,Vector3.ZERO,1.)
	elif id=="phone":
		box(holder,Vector3(.091,.183,.012),Vector3.ZERO,mat(Color("141b1d"),.65,.32),.005)
		box(holder,Vector3(.085,.175,.013),Vector3.ZERO,mat(Color("070d10"),.12,.24),.004)
		image(holder,"phone_screen",Vector2(.076,.150),Vector3(0,0,.007))
		box(holder,Vector3(.020,.002,.001),Vector3(0,.081,.007),mat(Color("63716b")),.0001)
		box(holder,Vector3(.002,.023,.003),Vector3(.046,.033,0),brass,.0001)
		holder.rotation_degrees.z=-12
	elif id=="weird_clock":
		var wood=mat(Color("35342a"),.1,.45)
		box(holder,Vector3(.237,.027,.105),Vector3(0,-.142,0),wood,.005)
		box(holder,Vector3(.205,.038,.086),Vector3(0,-.110,0),brass,.004)
		box(holder,Vector3(.184,.184,.075),Vector3(0,-.011,0),wood,.006)
		cylinder(holder,.093,.075,Vector3(0,.068,0),wood,true)
		cylinder(holder,.088,.012,Vector3(0,.037,.045),brass,true)
		image(holder,"clock_face",Vector2(.165,.165),Vector3(0,.037,.053))
		cylinder(holder,.008,.015,Vector3(0,.173,0),brass)
		for x in [-.07,.07]:cylinder(holder,.009,.020,Vector3(x,-.166,0),brass)
	elif id.contains("key"):
		var ring=MeshInstance3D.new();var torus=TorusMesh.new()
		torus.inner_radius=.012;torus.outer_radius=.021;ring.mesh=torus;ring.rotation.x=PI*.5;ring.position.y=.044;ring.material_override=brass;holder.add_child(ring)
		cylinder(holder,.004,.084,Vector3(0,-.013,0),brass)
		for y in [-.044,-.026]:box(holder,Vector3(.025,.008,.008),Vector3(.009,y,0),brass,.001)
		var tag=Node3D.new();holder.add_child(tag);tag.position=Vector3(.043,-.005,-.006);tag.rotation_degrees.z=-18
		box(tag,Vector3(.044,.062,.003),Vector3.ZERO,paper,.001)
		image(tag,id,Vector2(.044,.062),Vector3(0,0,.002))
		holder.rotation_degrees.z=-24
	else:
		var extent=Vector2(.27,.18) if id=="envelope" else (Vector2(.25,.205) if id=="photo" else Vector2(.20,.27))
		box(holder,Vector3(extent.x,extent.y,.003),Vector3.ZERO,paper,.001)
		image(holder,id,extent,Vector3(0,0,.002))
		holder.rotation_degrees=Vector3(-5,-8,-7)
	return holder
func run():
	create_timer(65).timeout.connect(func():quit(2))
	viewport=SubViewport.new();viewport.size=Vector2i(640,640);viewport.own_world_3d=true
	viewport.transparent_bg=true;viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	world=Node3D.new();viewport.add_child(world)
	var env=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("d9e0da");env.environment.ambient_light_energy=.35
	world.add_child(env)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-28,-34,-8)
	light.light_color=Color("fff0d7");light.light_energy=.8;light.shadow_enabled=false;world.add_child(light)
	var fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-15,142,0)
	fill.light_color=Color("9dadbb");fill.light_energy=.35;world.add_child(fill)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.001;world.add_child(camera);camera.current=true
	for id in ["phone","envelope","weird_clock","sweater","shoe","photo","document","registered","pipe_map","badge","permcard","key","back_key","drawer_key","mail_key","tool_key","machine_key"]:
		var specimen=build(id);await process_frame
		var meshes:Array[MeshInstance3D]=[];preload("res://scripts/case1_prop.gd").collect(specimen,meshes)
		var bounds=AABB();var first=true
		for mesh in meshes:
			var b=mesh.global_transform*mesh.get_aabb();bounds=b if first else bounds.merge(b);first=false
		var center=bounds.get_center();var extent=maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
		var direction=Vector3(.32,.18,2.8) if id not in ["sweater","shoe"] else Vector3(1.2,.9,2.8)
		camera.position=center+direction.normalized()*extent*3
		camera.look_at(center);camera.size=extent*1.22
		for i in 4:await process_frame
		RenderingServer.force_draw(false)
		var error=viewport.get_texture().get_image().save_png(OUT+id+".png")
		print("ITEM_ART ",id," error=",error)
		specimen.free()
	viewport.queue_free();await process_frame;quit()
