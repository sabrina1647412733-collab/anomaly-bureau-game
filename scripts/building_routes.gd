extends RefCounted
var case_ref: WeakRef
var lc:
	get:
		return case_ref.get_ref()
var climbing := false

func setup(case_world) -> void:
	case_ref = weakref(case_world)
	# 光滑的碰撞斜坡覆盖踏步前沿，避免胶囊体被竖直台阶卡住。
	ramp(.38, 1.44, 16.40, 11.0, .015, 3.70)
	ramp(1.66, 2.72, 10.60, 15.25, 3.515, 6.915)
	lc.art.col(Vector3(2.19,6.81,15.625), Vector3(1.06,.20,.75))
	for pair in [[6.9, 9.8], [9.8, 12.7], [12.7, 15.6]]:
		var y0: float = pair[0]
		var y1: float = pair[1]
		var mid := (y0+y1)*.5
		ramp(.38,1.44,9.95,12.55,y0+.015,mid+.015)
		lc.art.col(Vector3(.91,mid-.085,12.725),Vector3(1.06,.20,.35))
		ramp(1.66,2.72,13.35,11.15,mid+.015,y1+.015)
		lc.art.col(Vector3(2.19,y1-.085,10.975),Vector3(1.06,.20,.35))
	# 2F→3F 到达南侧，而 3F 住宅入口在北侧，补出井外回廊。
	var concrete = lc.art.plain(Color(.34,.34,.30), .9)
	lc.art.box(Vector3(1.55,-.12,16.55), Vector3(2.50,.24,1.10), concrete, true)
	lc.art.box(Vector3(-.25,6.78,13.20), Vector3(1.10,.24,6.40), concrete, true)
	lc.art.box(Vector3(1.0,6.78,16.70), Vector3(3.60,.24,.90), concrete, true)
	var kit = preload("res://scripts/laundry/laundry_kit.gd").new(lc.art)
	kit.railing(Vector3(-.78,6.9,10.3), Vector3(-.78,6.9,17.1))
	kit.railing(Vector3(-.78,6.9,17.1), Vector3(2.8,6.9,17.1))
	lc.art.col(Vector3(-.82,7.4,13.7),Vector3(.08,1.0,6.8))
	lc.art.col(Vector3(1.0,7.4,17.18),Vector3(3.6,1.0,.08))
	lc.art.label("3F  住户走廊 ←", Vector3(.2,8.15,16.4), .09, Color("d5ccb0"), 0)
	lc.art.label("楼梯  ↓  1F 门厅 / B1", Vector3(-.8, 5.1, 10.03), .08, Color("c6ccb3"), PI)
	lc.art.label("E  下到地下室", Vector3(2.1, .7, -6.15), .07, Color("ddce91"), 0)

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
	return [{"id":"l_service_down", "pos":Vector3(2.45,.42,-6.70), "r":2.5, "label":"沿铁梯下到 B1"},
		{"id":"l_service_up", "pos":Vector3(2.15,-1.6,-6.85), "r":2.4, "label":"沿铁梯回到 1F"},
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
	g.audio_system.sfx("ladder", -5)
	var tween: Tween = g.create_tween()
	var enter := Vector3(2.65, .08, -6.9) if down else Vector3(2.65, -2.94, -6.9)
	var leave := Vector3(2.65, -2.94, -6.9) if down else Vector3(2.65, .08, -6.9)
	tween.tween_property(p, "global_position", enter, .55)
	tween.tween_property(p, "global_position", leave, 1.8).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): g.audio_system.sfx("ladder", -6))
	tween.tween_property(p, "global_position", Vector3(1.7, leave.y, -6.9), .55)
	await tween.finished
	p.velocity = Vector3.ZERO
	p.set_physics_process(true)
	p.can_move = true
	p.allow_capture = true
	g.safe_pos = p.global_position
	g.state = "play"
	climbing = false
