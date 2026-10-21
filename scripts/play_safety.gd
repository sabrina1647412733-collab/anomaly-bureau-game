extends Node
## 只记实际落地且四周有地面的安全点；连续脱困失败时回本场景入口。
var game
var zone := ""
var last_good := Vector3.ZERO
var stable := 0.0
var fall_time := 0.0
var last_rescue := -100.0
var rescue_count := 0

func setup(g) -> void:game=g
func current_zone() -> String:
	return "laundry" if game.case_mode=="laundry" else String(game.prologue_stage)
func anchor() -> Vector3:
	match current_zone():
		"laundry":return Vector3(-.55,.08,-8.8)
		"room":return Vector3(-.35,12.12,323.05)
		"town":return game.town_bridge.ORIGIN+Vector3(143.7,.12,126.5)
		"store":return Vector3(0,.12,502.25)
	return Vector3(0,.12,326.4)
func in_bounds(p: Vector3) -> bool:
	if not p.is_finite():return false
	match current_zone():
		"laundry":
			var main:bool=p.x>-5.7 and p.x<6.0 and p.z>-11 and p.z<15.1 and p.y>-4.4 and p.y<20
			var post:bool=p.x>=3.2 and p.x<22 and p.z>6.5 and p.z<14 and p.y>2.4 and p.y<7.5
			return main or post
		"room":return p.x>-4 and p.x<4 and p.z>318 and p.z<327 and p.y>10.5 and p.y<18
		"town":
			var q:Vector3=p-game.town_bridge.ORIGIN
			return q.x>-14 and q.x<314 and q.z>-14 and q.z<254 and q.y>-3 and q.y<25
	return p.y>-5
func supported(p: Vector3) -> bool:
	if not in_bounds(p):return false
	for offset in [Vector3.ZERO,Vector3(.42,0,0),Vector3(-.42,0,0),Vector3(0,0,.42),Vector3(0,0,-.42)]:
		var query=PhysicsRayQueryParameters3D.create(p+offset+Vector3(0,.16,0),p+offset-Vector3(0,.36,0),1,[game.player.get_rid()])
		if game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():return false
	return true
func reset_zone() -> void:
	zone=current_zone();last_good=anchor();stable=0;fall_time=0;rescue_count=0
func tick(delta: float) -> void:
	if game.state not in ["play","prologue"]:return
	if zone!=current_zone():reset_zone()
	var p:Vector3=game.player.global_position
	if not in_bounds(p):fall_time+=delta
	elif game.player.velocity.y< -9:fall_time+=delta
	else:fall_time=0
	if fall_time>.65:
		recover(false);return
	if game.player.is_on_floor() and absf(game.player.velocity.y)<.1 and supported(p):
		stable+=delta
		if stable>=.5:last_good=p+Vector3(0,.04,0);game.safe_pos=last_good
	else:stable=0
func _physics_process(delta: float) -> void:tick(delta)
func save_position() -> Vector3:
	if zone!=current_zone():reset_zone()
	var p:Vector3=game.player.global_position
	return p if supported(p) else last_good
func recover(manual:=true) -> void:
	if game.state=="paused":game._on_resume()
	if game.state not in ["play","prologue"]:return
	if zone!=current_zone():reset_zone()
	if game.phone_open:game._close_phone()
	if game.bag_open:game.field_kit.open_inventory(false)
	if game.nb_open:game._toggle_notebook()
	var now=float(Time.get_ticks_msec())*.001
	rescue_count=rescue_count+1 if now-last_rescue<12 else 1
	last_rescue=now
	# 手动修正也覆盖穿进家具的情形，直接回入口；自动优先回稳定落脚点。
	var target=anchor() if manual or rescue_count>=2 else last_good
	if not supported(target):target=anchor()
	game.player.global_position=target;game.player.velocity=Vector3.ZERO
	game.player.sitting=false;game.player.can_move=true;game.player.allow_capture=true
	game.player.pitch=0;game.player.cam.rotation.x=0
	game.safe_pos=target;last_good=target;fall_time=0;stable=0
	game.player._update_camera(0,0,false)
	game.feedback.notify("位置已修正","已回到安全位置，任务、物品和时间保持不变。连续异常会回到场景入口。")
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F8:
		recover();get_viewport().set_input_as_handled()
