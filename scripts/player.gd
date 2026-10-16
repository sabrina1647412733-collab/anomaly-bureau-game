extends CharacterBody3D
## 第一/第三人称控制器：走 / 跑 / 跳 / 蹲 / 坐 + 低模角色

const SPEED_WALK := 3.2
const SPEED_RUN := 6.0
const SPEED_CROUCH := 1.5
const ACCEL := 12.0
const AIR_ACCEL := 3.0
const JUMP_SPEED := 5.6
const GRAV := 22.0
const KEY_TURN := 1.9
const EYE := 1.66
const EYE_CROUCH := 1.02
const EYE_SIT := 1.30
const COYOTE := 0.12
const PITCH_MAX := 1.45
const TP_DIST := 3.3
const TP_UP := 0.55

var mouse_sens := 0.0022
var cam: Camera3D
var flash: SpotLight3D
var cap: CapsuleShape3D
var cap_node: CollisionShape3D
var pitch := 0.0
var can_move := true
var allow_capture := true
var cam_mode := 0          # 0 第一人称 / 1 第三人称
var crouching := false
var crouch_k := 0.0
var sitting := false
var air_time := 0.0
var coyote := 0.0
var jump_locked := false
var dip := 0.0
var head_bob := 0.0
var bob_amp := 0.0
var step_phase := 0.0
var walk_phase := 0.0
var body: Node3D
var view_arm: Node3D
var parts := {}
signal footstep(running)
signal landed(hard)

func _ready() -> void:
	cap_node = CollisionShape3D.new()
	cap = CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.72
	cap_node.shape = cap
	cap_node.position = Vector3(0, 0.86, 0)
	add_child(cap_node)

	cam = Camera3D.new()
	cam.position = Vector3(0, EYE, 0)
	cam.fov = 74.0
	cam.near = 0.05
	cam.far = 420.0
	add_child(cam)
	flash = SpotLight3D.new()
	flash.light_color = Color(0.85, 0.90, 1.0)
	flash.light_energy = 3.2
	flash.spot_range = 26.0
	flash.spot_angle = 33.0
	flash.spot_angle_attenuation = 1.1
	flash.spot_attenuation = 1.4
	flash.shadow_enabled = true
	flash.position = Vector3(0.20, -0.05, 0.0)
	cam.add_child(flash)

	_build_body()
	_build_viewarm()
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.35
	slide_on_ceiling = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ---------------------------------------------------------------- 角色模型
func _mesh_box(size: Vector3, col: Color, off: Vector3, emis := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emis
	mi.material_override = m
	mi.position = off
	return mi

func _mesh_cyl(size: Vector3, col: Color, off: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = size.x * 0.5
	cm.bottom_radius = size.x * 0.5
	cm.height = size.y
	cm.radial_segments = 10
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.80
	mi.material_override = m
	mi.position = off
	return mi

func _joint(nm: String, parent: Node3D, joint: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = joint
	parent.add_child(n)
	parts[nm] = n
	return n

func _build_body() -> void:
	# 配色取自选定的 A 方向概念图：藏青制服 + 琥珀反光背心 + 深灰长裤
	var coat := Color(0.14, 0.14, 0.24)
	var dark := Color(0.24, 0.24, 0.24)
	var vest := Color(0.80, 0.52, 0.14)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)

	var hip := _joint("hip", body, Vector3(0, 0.86, 0))
	var skin := Color(0.90, 0.71, 0.60)
	hip.add_child(_mesh_box(Vector3(0.36, 0.20, 0.24), dark, Vector3(0, 0.0125, 0)))
	var torso := _joint("torso", body, Vector3(0, 0.94, 0))
	torso.add_child(_mesh_box(Vector3(0.42, 0.50, 0.26), coat, Vector3(0, 0.25, 0)))
	torso.add_child(_mesh_box(Vector3(0.44, 0.44, 0.275), vest, Vector3(0, 0.22, 0), 0.55))   # 反光背心（A 里是从胸到胯的长背心）
	torso.add_child(_mesh_box(Vector3(0.45, 0.045, 0.285), Color(0.89, 0.80, 0.33), Vector3(0, 0.36, 0), 0.9))
	torso.add_child(_mesh_box(Vector3(0.45, 0.045, 0.285), Color(0.89, 0.80, 0.33), Vector3(0, 0.13, 0), 0.9))
	torso.add_child(_mesh_box(Vector3(0.44, 0.045, 0.27), dark, Vector3(0, 0.01, 0)))          # 腰带
	torso.add_child(_mesh_box(Vector3(0.10, 0.14, 0.02), vest, Vector3(0.11, 0.34, -0.15), 0.9))  # 工牌
	torso.add_child(_mesh_box(Vector3(0.38, 0.02, 0.02), dark, Vector3(0, 0.44, -0.13)))        # 挂绳
	torso.add_child(_mesh_box(Vector3(0.12, 0.14, 0.07), Color(0.30, 0.26, 0.20), Vector3(-0.15, 0.06, 0.15)))  # 工具腰包
	var head := _joint("head", body, Vector3(0, 1.44, 0))
	head.add_child(_mesh_box(Vector3(0.205, 0.20, 0.205), skin, Vector3(0, 0.105, 0)))
	head.add_child(_mesh_box(Vector3(0.215, 0.055, 0.215), Color(0.10, 0.09, 0.10), Vector3(0, 0.038, 0.007)))
	for ex in [-0.055, 0.055]:
		head.add_child(_mesh_box(Vector3(0.042, 0.024, 0.02), Color(0.06, 0.06, 0.07), Vector3(ex, 0.118, -0.098)))
	head.add_child(_mesh_box(Vector3(0.225, 0.075, 0.225), dark, Vector3(0, 0.235, 0)))            # 帽子
	head.add_child(_mesh_box(Vector3(0.245, 0.028, 0.095), dark, Vector3(0, 0.208, -0.122)))        # 帽檐
	head.add_child(_mesh_box(Vector3(0.058, 0.028, 0.02), vest, Vector3(0, 0.185, -0.108), 0.6))   # 帽徽
	for sgn in [-1.0, 1.0]:
		var sfx := "L" if sgn < 0 else "R"
		var sh := _joint("shoulder" + sfx, body, Vector3(sgn * 0.25, 1.40, 0))
		sh.add_child(_mesh_cyl(Vector3(0.125, 0.44, 0.125), coat, Vector3(0, -0.22, 0)))        # 上臂（圆管）
		var el := _joint("elbow" + sfx, sh, Vector3(0, -0.42, 0))
		el.add_child(_mesh_cyl(Vector3(0.115, 0.34, 0.115), coat, Vector3(0, -0.17, 0)))        # 小臂
		el.add_child(_mesh_box(Vector3(0.095, 0.11, 0.10), skin, Vector3(0, -0.38, 0)))          # 手
		var hp := _joint("hip" + sfx, body, Vector3(sgn * 0.11, 0.84, 0))
		hp.add_child(_mesh_cyl(Vector3(0.175, 0.40, 0.175), dark, Vector3(0, -0.20, 0)))        # 大腿
		var kn := _joint("knee" + sfx, hp, Vector3(0, -0.40, 0))
		kn.add_child(_mesh_cyl(Vector3(0.155, 0.36, 0.155), dark, Vector3(0, -0.18, 0)))        # 小腿
		var ft := _joint("foot" + sfx, kn, Vector3(0, -0.36, 0))
		ft.add_child(_mesh_box(Vector3(0.15, 0.08, 0.28), Color(0.08, 0.09, 0.11), Vector3(0, -0.04, -0.05)))
	body.visible = false

func _build_viewarm() -> void:
	view_arm = Node3D.new()
	view_arm.name = "ViewArm"
	view_arm.position = Vector3(0.26, -0.26, -0.42)
	cam.add_child(view_arm)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.14, 0.24)
	mat.emission_enabled = true
	mat.emission = Color(0.14, 0.14, 0.24)
	mat.emission_energy_multiplier = 0.18
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.17, 0.18, 0.21)
	gmat.roughness = 0.85
	gmat.emission_enabled = true
	gmat.emission = Color(0.17, 0.18, 0.21)
	gmat.emission_energy_multiplier = 0.10
	var fore := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.052
	fm.bottom_radius = 0.062
	fm.height = 0.40
	fm.radial_segments = 10
	fore.mesh = fm
	fore.position = Vector3(0.02, -0.05, -0.22)
	fore.rotation.x = PI * 0.5
	fore.material_override = mat
	view_arm.add_child(fore)
	var hand := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.048
	hm.bottom_radius = 0.054
	hm.height = 0.16
	hm.radial_segments = 8
	hand.mesh = hm
	hand.position = Vector3(0.016, -0.062, -0.49)
	hand.rotation.x = PI * 0.5
	hand.material_override = gmat
	view_arm.add_child(hand)
	for fx in [-0.026, 0.0, 0.026]:
		var fg := MeshInstance3D.new()
		var ff := BoxMesh.new()
		ff.size = Vector3(0.021, 0.032, 0.075)
		fg.mesh = ff
		fg.position = Vector3(0.016 + fx, -0.062, -0.60)
		fg.material_override = gmat
		view_arm.add_child(fg)
	var cuff := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.15, 0.15, 0.08)
	cuff.mesh = cb
	cuff.position = Vector3(0.02, -0.05, -0.02)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.80, 0.52, 0.14)
	cm.emission_enabled = true
	cm.emission = Color(0.80, 0.52, 0.14)
	cm.emission_energy_multiplier = 0.30
	cuff.material_override = cm
	view_arm.add_child(cuff)

func toggle_cam() -> void:
	cam_mode = 1 - cam_mode
	body.visible = (cam_mode == 1)
	if view_arm != null:
		view_arm.visible = (cam_mode == 0 and not sitting)

func sit_at(pos: Vector3, yaw: float) -> void:
	sitting = true
	can_move = false
	cap_node.disabled = true
	if view_arm != null:
		view_arm.visible = false          # 坐着时关掉碰撞，免得被椅子顶起来
	global_position = pos
	rotation.y = yaw
	velocity = Vector3.ZERO

func stand_up() -> void:
	sitting = false
	can_move = true
	cap_node.disabled = false
	global_position += Vector3(0, 0.12, 0)
	if view_arm != null:
		view_arm.visible = (cam_mode == 0)

func eye_height() -> float:
	var h := lerpf(EYE, EYE_CROUCH, crouch_k)
	if sitting:
		h = EYE_SIT
	return h

func eye() -> Vector3:
	if cam_mode == 1:
		return global_position + Vector3(0, eye_height() - 0.08, 0)   # 第三人称仍用角色眼睛做交互判定
	return cam.global_position

func forward() -> Vector3:
	if cam_mode == 1:
		return -cam.global_transform.basis.z
	return -cam.global_transform.basis.z

func look(delta_rot: Vector2) -> void:
	rotate_y(-delta_rot.x * mouse_sens)
	pitch = clamp(pitch - delta_rot.y * mouse_sens, -PITCH_MAX, PITCH_MAX)
	if cam_mode == 0:
		cam.rotation.x = pitch
		if view_arm != null:
			view_arm.visible = not sitting
			view_arm.position = Vector3(0.26 + sin(head_bob) * 0.014 * bob_amp, -0.26 + cos(head_bob * 2.0) * 0.012 * bob_amp - dip * 0.6, -0.42)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or dragging:
			look(event.relative)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed and allow_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F:
			flash.visible = not flash.visible
		elif event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

var dragging := false

func _physics_process(delta: float) -> void:
	# 键盘转头
	var turn := 0.0
	var tilt := 0.0
	if can_move:
		if Input.is_physical_key_pressed(KEY_LEFT): turn += 1.0
		if Input.is_physical_key_pressed(KEY_RIGHT): turn -= 1.0
		if Input.is_physical_key_pressed(KEY_UP): tilt -= 1.0
		if Input.is_physical_key_pressed(KEY_DOWN): tilt += 1.0
		if Input.is_physical_key_pressed(KEY_Q): turn += 1.0
		if Input.is_physical_key_pressed(KEY_R): turn -= 1.0
	if turn != 0.0:
		rotate_y(turn * KEY_TURN * delta)
	if tilt != 0.0:
		pitch = clamp(pitch + tilt * KEY_TURN * 0.7 * delta, -PITCH_MAX, PITCH_MAX)
		if cam_mode == 0:
			cam.rotation.x = pitch
		if view_arm != null:
			view_arm.visible = not sitting
			view_arm.position = Vector3(0.26 + sin(head_bob) * 0.014 * bob_amp, -0.26 + cos(head_bob * 2.0) * 0.012 * bob_amp - dip * 0.6, -0.42)

	# 蹲下（按住 Ctrl 或 C）
	var want_crouch := false
	if can_move and not sitting:
		want_crouch = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C)
	crouching = want_crouch
	crouch_k = lerpf(crouch_k, 1.0 if crouching else 0.0, clampf(delta * 9.0, 0.0, 1.0))
	cap.height = lerpf(1.72, 1.10, crouch_k)
	cap_node.position.y = cap.height * 0.5

	if sitting and (Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_D)):
		stand_up()                       # 坐着时按方向键自动起身
	var target := Vector2.ZERO
	if can_move and not sitting:
		if Input.is_physical_key_pressed(KEY_W): target.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S): target.y += 1.0
		if Input.is_physical_key_pressed(KEY_A): target.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D): target.x += 1.0
	var running := Input.is_physical_key_pressed(KEY_SHIFT) and not crouching
	var speed := SPEED_RUN if running else (SPEED_CROUCH if crouching else SPEED_WALK)
	var wish := global_transform.basis * Vector3(target.x, 0.0, target.y)
	wish.y = 0.0
	if wish.length() > 0.001:
		wish = wish.normalized() * speed
	var acc := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, wish.x, acc * delta * 4.0)
	velocity.z = move_toward(velocity.z, wish.z, acc * delta * 4.0)

	if is_on_floor():
		air_time = 0.0
		coyote = COYOTE
	else:
		air_time += delta
		coyote = max(0.0, coyote - delta)
		velocity.y -= GRAV * delta

	if can_move and not sitting and Input.is_physical_key_pressed(KEY_SPACE):
		if coyote > 0.0 and not jump_locked:
			velocity.y = JUMP_SPEED
			coyote = 0.0
			jump_locked = true
	else:
		jump_locked = false

	var was_falling := velocity.y
	if sitting:
		velocity = Vector3.ZERO
	move_and_slide()
	if is_on_floor() and was_falling < -0.5:
		landed.emit(was_falling < -7.0)

	var planar := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and planar > 0.4:
		step_phase += delta * (planar * 1.9)
		if step_phase > PI:
			step_phase -= PI
			footstep.emit(running)
		bob_amp = lerp(bob_amp, 1.0, delta * 6.0)
	else:
		bob_amp = lerp(bob_amp, 0.0, delta * 6.0)
	head_bob += delta * planar * 2.0
	dip = lerp(dip, 0.0, delta * 7.0)
	_update_camera(delta, planar, running)
	_update_body(delta, planar)

func _update_camera(delta: float, planar: float, running: bool) -> void:
	var eh := eye_height()
	if cam_mode == 0:
		cam.position = Vector3(0, eh + sin(head_bob * 2.0) * 0.028 * bob_amp - dip, 0)
		cam.rotation = Vector3(pitch, 0.0, 0.0)
		# 跑动/蹲下时轻微侧倾
		cam.rotation.z = lerp(cam.rotation.z, sin(step_phase) * 0.012 * bob_amp * (1.6 if running else 1.0), delta * 8.0)
	else:
		var back := Vector3(0, TP_UP, TP_DIST)
		back = back.rotated(Vector3.RIGHT, pitch)
		var want_local := Vector3(0, eh - 0.10, 0) + back
		var from := global_transform * Vector3(0, eh - 0.10, 0)
		var to := global_transform * want_local
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			to = hit["position"] + (from - hit["position"]).normalized() * 0.28
		cam.global_position = to
		if cam.global_position.distance_to(from) > 0.06: cam.look_at(from + Vector3(0, 0.05, 0), Vector3.UP)

func _update_body(delta: float, planar: float) -> void:
	if body == null:
		return
	if sitting:
		# 坐姿：髋抬到「大腿底面正好落在座面上」（长椅座面顶 0.49、椅子 0.465），
		# 大腿略下倾 11.8°、小腿竖直，脚掌正好踩到地面（以前髋陷进座面、脚还悬空）。
		# 第一人称坐姿必须藏掉自己的头：相机会正好落在头部方块内部，不藏就是穿模。
		body.visible = true
		parts["head"].visible = (cam_mode == 1)
		parts["hip"].position = Vector3(0, 0.575, 0)
		parts["torso"].position = Vector3(0, 0.655, 0)
		parts["head"].position = Vector3(0, 1.155, 0)
		for sgn in ["L", "R"]:
			parts["shoulder" + sgn].position = Vector3((-0.25 if sgn == "L" else 0.25), 1.115, 0)
			parts["shoulder" + sgn].rotation = Vector3(0.35, 0, 0)
			parts["hip" + sgn].position = Vector3((-0.11 if sgn == "L" else 0.11), 0.575, 0)
			parts["hip" + sgn].rotation = Vector3(1.279, 0, 0)
			parts["knee" + sgn].rotation = Vector3(-1.279, 0, 0)
			parts["elbow" + sgn].rotation = Vector3(0.45, 0, 0)
		return
	body.visible = (cam_mode == 1)
	parts["head"].visible = true
	var k := crouch_k
	parts["hip"].position = Vector3(0, 0.86 - 0.36 * k, 0)
	parts["torso"].position = Vector3(0, 0.94 - 0.36 * k, 0)
	parts["head"].position = Vector3(0, 1.44 - 0.36 * k, 0)
	var sw := sin(walk_phase) * clampf(planar / SPEED_WALK, 0.0, 1.4) * 0.62
	walk_phase += delta * (planar * 2.7 + 0.6)
	for sgn in ["L", "R"]:
		var dir := 1.0 if sgn == "L" else -1.0
		parts["shoulder" + sgn].position = Vector3(dir * 0.27, 1.40 - 0.36 * k, 0)
		parts["shoulder" + sgn].rotation = Vector3(-sw * dir * 0.75 - 0.12 * k, 0, 0)
		parts["elbow" + sgn].rotation = Vector3(-0.25 - 0.35 * absf(sw) - 0.5 * k, 0, 0)
		parts["hip" + sgn].position = Vector3(dir * 0.11, 0.84 - 0.34 * k, 0)
		parts["hip" + sgn].rotation = Vector3(sw * dir - 0.85 * k, 0, 0)
		parts["knee" + sgn].rotation = Vector3(maxf(0.0, -sw * dir) + 1.45 * k, 0, 0)
