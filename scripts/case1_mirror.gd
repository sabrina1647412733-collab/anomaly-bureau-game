extends Node
## 低分辨率平面反射。反射专用角色不在正常相机中显示。
const REFLECTION_LAYER := 1 << 19
var lc
var viewport: SubViewport
var camera: Camera3D
var ghost
var accumulator := 0.0
var surface: MeshInstance3D
var material: ShaderMaterial

func setup(case_world) -> void:
	lc = case_world
	surface = lc.f2.mirror_surface
	if surface == null: return
	viewport = SubViewport.new()
	viewport.size = Vector2i(400,600)
	viewport.world_3d = lc.world.get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	camera = Camera3D.new()
	camera.near = .05
	camera.cull_mask = 1 | REFLECTION_LAYER
	viewport.add_child(camera)
	camera.current = true
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded; uniform sampler2D reflection_tex : filter_linear; void fragment(){ALBEDO=texture(reflection_tex,vec2(1.0-UV.x,UV.y)).rgb*vec3(.86,.90,.93); }"
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("reflection_tex",viewport.get_texture())
	surface.material_override = material
	surface.layers = 1<<18 # 不把镜面再次渲染进自己的视口。
	lc.game.player.cam.cull_mask &= ~REFLECTION_LAYER
	# 七号机作为异常，不进入镜面；主相机照常看见。
	if lc.f2.drums.has(7): _layers(lc.f2.drums[7],1<<17)
	if lc.f2.sweater != null: _layers(lc.f2.sweater,1<<17)

func _layers(node: Node, value: int) -> void:
	if node is VisualInstance3D: node.layers = value
	for child in node.get_children(): _layers(child,value)

func _process(delta: float) -> void:
	if lc == null or surface == null: return
	accumulator += delta
	if accumulator < .10: return
	accumulator = 0
	if lc.game.case_mode != "laundry" or lc.game.state=="menu":
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	var eye: Vector3 = lc.game.player.cam.global_position
	var center := Vector3(3.10,5.05,5.50)
	if eye.distance_to(center)>7:
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	var mirrored := eye
	mirrored.x=2*center.x-eye.x
	camera.global_position=mirrored
	if mirrored.distance_to(center)>.1: camera.look_at(center,Vector3.UP)
	camera.fov=clampf(rad_to_deg(2*atan(.9/maxf(absf(eye.x-center.x),.3))),20,110)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	if lc.t>=220*60 and not lc.fired.has("aqi_line"):
		lc.cast.aqi.visible=true
		_layers(lc.cast.aqi,REFLECTION_LAYER)
	elif lc.fired.has("aqi_line"):
		_layers(lc.cast.aqi,1)
	if lc.claimed and ghost==null:
		ghost = preload("res://scripts/laundry/char_actor.gd").make(lc.world,"zhou",Vector3(0,3.5,6),0,0)
		_layers(ghost,REFLECTION_LAYER)
		var bag := preload("res://scripts/case1_prop.gd").place(ghost,"bag",Vector3(0,.9,.22),.4,0)
		if bag!=null: _layers(bag,REFLECTION_LAYER)
	if ghost!=null:
		ghost.global_position=lc.game.player.global_position+lc.game.player.global_basis.x*.65
		ghost.rotation.y=lc.game.player.rotation.y+PI
