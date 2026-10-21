extends CanvasLayer
## 独立深度缓冲避免第一人称手臂切入桌面/墙面；近墙时收低持物。
var player
var viewport: SubViewport
var camera: Camera3D
var rig
var picture: TextureRect
func setup(p, font: Font) -> void:
	player = p
	layer = 5
	p.add_child(self)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(1600,900)
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	camera = Camera3D.new()
	camera.near = .01
	camera.current = true
	viewport.add_child(camera)
	var hand_light := OmniLight3D.new()
	hand_light.name = "HeldCharacterLight"
	hand_light.position = Vector3(0.15, 0.15, 0.25)
	hand_light.light_color = Color(0.84, 0.88, 0.96)
	hand_light.light_energy = 2.2
	hand_light.omni_range = 3.0
	hand_light.shadow_enabled = false
	camera.add_child(hand_light)
	rig = preload("res://scripts/held_item.gd").new()
	rig.setup(camera,font)
	picture = TextureRect.new()
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.texture = viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
func _process(delta: float) -> void:
	if rig == null: return
	camera.fov = player.cam.fov
	picture.visible = rig.visible
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if rig.visible else SubViewport.UPDATE_DISABLED
	if not rig.visible or not player.is_inside_tree(): return
	var eye: Vector3 = player.cam.global_position
	var query := PhysicsRayQueryParameters3D.create(eye,eye-player.cam.global_basis.z*.85)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	var lower := 0.0
	if not hit.is_empty(): lower = -.22 * (1.0-clampf(eye.distance_to(hit["position"])/.85,0,1))
	rig.position.y = move_toward(rig.position.y,lower,delta*1.5)
