class_name LaundryPlayer
extends CharacterBody3D
## 第一人称走位。只做这一案要用的四件事：走、看、蹲着贴边走（廊桥用）、不穿墙。

const SPEED := 2.35
const RUN_SPD := 3.55
const ACC := 14.0
const GRAV := 18.0
const EYE := 1.62

var active := true
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var _bob_t := 0.0

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.30
	cap.height = 1.72
	cs.shape = cap
	cs.position = Vector3(0, 0.86, 0)
	add_child(cs)

	cam = Camera3D.new()
	cam.name = "Eye"
	cam.fov = 72.0
	cam.near = 0.05
	cam.position = Vector3(0, EYE, 0)
	add_child(cam)
	cam.current = true
	yaw = rotation.y

func _unhandled_input(e: InputEvent) -> void:
	if not active:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.0022
		pitch = clampf(pitch - e.relative.y * 0.0022, -1.35, 1.35)
		rotation.y = yaw
		cam.rotation.x = pitch

func _physics_process(dt: float) -> void:
	if not active:
		velocity = Vector3.ZERO
		return
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	var spd := RUN_SPD if Input.is_physical_key_pressed(KEY_SHIFT) else SPEED
	var b := Basis(Vector3.UP, yaw)
	var want: Vector3 = (b * dir).normalized() * spd
	velocity.x = lerpf(velocity.x, want.x, clampf(ACC * dt, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, want.z, clampf(ACC * dt, 0.0, 1.0))
	if not is_on_floor():
		velocity.y -= GRAV * dt
	else:
		velocity.y = -0.5
	move_and_slide()

	# 轻微的步伐晃动：出租屋那边也是靠这个读"人在走"
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar > 0.4 and is_on_floor():
		_bob_t += dt * planar * 2.4
		cam.position.y = EYE + sin(_bob_t) * 0.012
	else:
		cam.position.y = lerpf(cam.position.y, EYE, 0.12)

## 视线命中测试：给交互用
func look_dir() -> Vector3:
	return -cam.global_transform.basis.z
