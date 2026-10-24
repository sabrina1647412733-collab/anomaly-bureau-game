extends SceneTree
## Independent space test: actual player-size CharacterBody3D sweeps the full routes.
## Initial placement is only the front door, then every checkpoint is reached on foot.
var world
var player: CharacterBody3D
var checks: Array[Dictionary] = []
var report := "F:/诡异事务局/验收/20261024_24小时开发/case2_world/whitebox_walk.json"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_cmdline_user_args().has("--finish"):
		report = report.replace("whitebox_walk.json", "finish_walk.json")
	world = load("res://scripts/case2/case2_world.gd").new()
	root.add_child(world)
	world.setup(null)
	player = CharacterBody3D.new()
	player.name = "WalkProbe_PlayerCapsule"
	player.floor_snap_length = .35
	player.floor_max_angle = deg_to_rad(46)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .34
	capsule.height = 1.72
	collision.shape = capsule
	collision.position.y = .86
	player.add_child(collision)
	root.add_child(player)
	player.global_position = world.get_floor_spawn(1)
	await physics_frame
	for id in ["c2_register", "c2_master_meter", "c2_pipe_map", "c2_dispatch", "c2_intercom", "c2_hebo", "c2_lift_1", "c2_porridge", "c2_calendar", "c2_note", "c2_storage", "c2_wage", "c2_recorder", "c2_schedule", "c2_luggage", "c2_hospital", "c2_plaque"]:
		if not await walk(id):
			finish()
			return
	# Gate must block access to the unknown seventeenth corridor until evidence opens it.
	world.set_anomaly_open(true)
	await physics_frame
	for id in ["c2_corridor", "c2_delivery", "c2_sun", "c2_valves", "c2_rest_corner", "c2_doorplate", "c2_exit"]:
		if not await walk(id):
			finish()
			return
	finish()

func walk(id: String) -> bool:
	var points: Array[Vector3] = world.get_route(id, player.global_position)
	var stuck := 0
	var contacts: Array[String] = []
	for target in points:
		var reached := false
		for frame in range(1200):
			await physics_frame
			var difference := target - player.global_position
			difference.y = 0
			if difference.length() < .065 and absf(target.y - player.global_position.y) < .3:
				reached = true
				break
			var direction := difference.normalized()
			player.velocity.x = direction.x * minf(4.0, difference.length() * 30.0)
			player.velocity.z = direction.z * minf(4.0, difference.length() * 30.0)
			player.velocity.y = -.5 if player.is_on_floor() else player.velocity.y - 22.0 / 60.0
			var previous := player.global_position
			player.move_and_slide()
			for j in player.get_slide_collision_count():
				var c := player.get_slide_collision(j)
				if c.get_normal().y < .65 and not contacts.has(str(c.get_collider().name)):
					contacts.append(str(c.get_collider().name))
			stuck = stuck + 1 if player.global_position.distance_to(previous) < .001 else 0
			if stuck > 45 or player.global_position.y < -2:
				break
		if not reached:
			checks.append({"id":id, "ok":false, "position":str(player.global_position), "target":str(target), "contacts":contacts})
			print("CASE2_WALK_FAIL ", checks.back())
			return false
	var anchor: Vector3 = world.get_anchor(id)
	var visible: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0,1.55,0), anchor, 1, [player.get_rid()]))
	var sight_ok: bool = visible.is_empty() or visible.position.distance_to(anchor) < .14
	if not visible.is_empty() and visible.collider.has_meta("case2_actor"):
		var who := String(visible.collider.get_meta("case2_actor"))
		sight_ok = (id=="c2_hebo" and who=="hebo") or (id=="c2_sun" and who=="sun") or (id=="c2_aqi" and who=="aqi")
	checks.append({"id":id,"ok":sight_ok,"pos":str(player.global_position),"anchor_distance":player.global_position.distance_to(anchor),"sight_clear":sight_ok,"hit":str(visible.get("collider", "none"))})
	print("CASE2_WALK ", id, " ", sight_ok, " ", player.global_position)
	return sight_ok

func finish() -> void:
	var failures := 0
	for row in checks:
		if not row.ok:
			failures += 1
	var file := FileAccess.open(report, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"kind":"Actual move_and_slide route, not art QA", "checks":checks, "failures":failures}, "\t"))
	print("CASE2_WORLD_RESULT ", checks.size(), " checks / ", failures, " failures")
	quit(1 if failures > 0 else 0)
