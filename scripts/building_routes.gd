extends RefCounted
var case_ref: WeakRef
var lc:
	get:
		return case_ref.get_ref()
var climbing := false

func setup(case_world) -> void:
	case_ref = weakref(case_world)
	# 新楼体已包含连续斜坡碰撞，不再叠加旧楼梯。

func ramp(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
	var body := StaticBody3D.new()
	body.name = "WalkableStairRamp"
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([Vector3(x0,y0,z0), Vector3(x1,y0,z0), Vector3(x0,y1,z1), Vector3(x1,y1,z1), Vector3(x0,y0-.15,z0), Vector3(x1,y0-.15,z0), Vector3(x0,y1-.15,z1), Vector3(x1,y1-.15,z1)])
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	lc.world.add_child(body)

func spots() -> Array:
	return [{"id":"l_service_down", "pos":Vector3(2.65,.42,-8.1), "r":2.5, "label":"沿铁梯下到 B1"},
		{"id":"l_service_up", "pos":Vector3(2.55,-1.6,-8.1), "r":2.4, "label":"沿铁梯回到 1F"},
		{"id":"l_locked_402","pos":Vector3(-2.1,11.0,5.5),"r":2.0,"label":"敲402的门"},
		{"id":"l_locked_401","pos":Vector3(2.1,11.0,5.5),"r":2.0,"label":"试试401的门锁"},
		{"id":"l_locked_503","pos":Vector3(1.7,13.9,5.5),"r":2.0,"label":"听503门里的声音"}]

func climb(down: bool) -> void:
	if climbing:
		return
	climbing = true
	var g = lc.game
	var p = g.player
	g.state = "case_climb"
	p.can_move = false
	p.set_physics_process(false)
	p.velocity = Vector3.ZERO
	if lc.rebuilt.service_cover!=null:lc.rebuilt.service_cover.visible=false
	g.audio_system.sfx("ladder", -5)
	var tween: Tween = g.create_tween()
	var enter := Vector3(2.65, .08, -8.1) if down else Vector3(2.55, -2.82, -8.1)
	var leave := Vector3(2.55, -2.82, -8.1) if down else Vector3(2.65, .08, -8.1)
	tween.tween_property(p, "global_position", enter, .55)
	tween.tween_property(p, "global_position", leave, 1.8).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): g.audio_system.sfx("ladder", -6))
	tween.tween_property(p, "global_position", Vector3(2.55, leave.y, -8.1 if down else -7.05), .55)
	await tween.finished
	if lc.rebuilt.service_cover!=null:lc.rebuilt.service_cover.visible=true
	p.velocity = Vector3.ZERO
	p.set_physics_process(true)
	p.can_move = true
	p.allow_capture = true
	g.safe_pos = p.global_position
	g.state = "play"
	climbing = false
