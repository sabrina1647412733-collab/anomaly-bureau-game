extends Node3D
## 角色验证专用场景（不依赖主场景，避免与场景会话冲突）
## 用法：godot --path . res://scenes/char_lab.tscn

const Art := preload("res://scripts/laundry/laundry_art.gd")

@export var model_path := "res://assets/models/chars/ZhouXiulan_Fix.glb"
@export var target_height := 1.55
@export var anim_index := 0

var world: Node3D
var cam: Camera3D
var model: Node3D
var ap: AnimationPlayer
var anims: Array = []

func _ready() -> void:
	_env()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	_build_stage()
	_load_model()
	_make_camera()
	# 打印信息
	print("[LAB] model=", model_path)
	if ap:
		anims = ap.get_animation_list()
		print("[LAB] animations=", anims)
		if anims.size() > anim_index:
			ap.play(anims[anim_index])
	print("[LAB] ready")

func _env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.085, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.44, 0.50)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.35
	we.environment = env
	add_child(we)

func _build_stage() -> void:
	var a = Art.new(world)
	# 简单舞台：一个 6x6 地板 + 背景墙
	a.quad_xz(-3, -3, 3, 3, 0.0, a.pbr("terrazzo_tiles", 0.4, Color(0.86, 0.85, 0.82)))
	a.box(Vector3(0, 1.6, -3.1), Vector3(6.4, 3.2, 0.2),
		a.pbr("painted_plaster_wall", 0.35, Color(0.72, 0.70, 0.66)), true)
	# 光：主光 + 补光 + 轮廓光
	var key := OmniLight3D.new()
	key.position = Vector3(-1.6, 2.6, 2.4)
	key.light_color = Color(1.0, 0.93, 0.85)
	key.light_energy = 5.5
	key.omni_range = 9.0
	key.shadow_enabled = true
	world.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(2.2, 1.8, 1.6)
	fill.light_color = Color(0.62, 0.72, 1.0)
	fill.light_energy = 2.4
	fill.omni_range = 7.0
	world.add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.4, 2.4, -2.6)
	rim.light_color = Color(0.80, 0.86, 1.0)
	rim.light_energy = 3.2
	rim.omni_range = 6.0
	world.add_child(rim)
	# 参考标尺：1.55m 高的细柱
	var ruler := a.plain(Color(0.30, 0.34, 0.40), 0.8)
	a.box(Vector3(0.95, 0.775, -0.6), Vector3(0.02, 1.55, 0.02), ruler)

func _load_model() -> void:
	var ps = load(model_path)
	if ps == null:
		push_error("cannot load " + model_path)
		return
	model = ps.instantiate()
	world.add_child(model)
	# 缩放到目标身高
	var bb := _aabb(model)
	if bb.size.y > 0.01:
		var sc: float = target_height / bb.size.y
		model.scale = Vector3(sc, sc, sc)
	# 重新算
	bb = _aabb(model)
	model.position.y -= bb.position.y
	model.position.x = 0
	model.position.z = 0
	bb = _aabb(model)
	print("[LAB] model bbox=", bb.position, " size=", bb.size)
	print("[LAB] model origin=", model.position, " scale=", model.scale)
	ap = _find_ap(model)

func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r = _find_ap(c)
		if r:
			return r
	return null

func _make_camera() -> void:
	cam = Camera3D.new()
	cam.name = "Cam"
	cam.fov = 42.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.15, 3.4), Vector3(0, 0.85, 0), Vector3.UP)
	cam.current = true
