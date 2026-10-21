extends SceneTree
var game
var passed := 0
var failed := 0
func _initialize() -> void: run()
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("[PASS] ",label)
	else:
		failed+=1; print("[FAIL] ",label," foot=",game.player.global_position)
		for i in range(game.player.get_slide_collision_count()):
			var hit = game.player.get_slide_collision(i)
			var body = hit.get_collider()
			if body is CollisionObject3D:
				var shape = hit.get_collider_shape()
				if not shape is CollisionShape3D: continue
				print(" HIT ",shape.global_position," ",shape.shape," normal=",hit.get_normal())
				if shape.shape is BoxShape3D: print(" SIZE ",shape.shape.size)
func drive(axis: int,target: float,count := 240) -> void:
	for i in range(count):
		await physics_frame
		var difference: float = target-game.player.global_position[axis]
		if absf(difference)<.04: return
		var velocity := Vector3(0,-1.5,0)
		velocity[axis] = clampf(difference*5,-2.8,2.8)
		game.player.velocity = velocity
		game.player.move_and_slide()
func run() -> void:
	await process_frame
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_laundry_case()
	game.set_process(false)
	game.player.set_physics_process(false)
	for i in range(3): await physics_frame
	for base in [6.9,9.8,12.7]:
		game.player.global_position=Vector3(.91,base+.08,9.85)
		await drive(2,13.55)
		check(game.player.global_position.y>base+1.30,"%s 西跑到中间平台"%base)
		await drive(0,2.19)
		check(absf(game.player.global_position.x-2.19)<.1,"%s 中间平台可转身"%base)
		await drive(2,10.4)
		check(game.player.global_position.y>base+2.8 and game.player.global_position.z<11.0,"%s 上到下一层"%base)
		await drive(2,9.3)
		check(game.player.global_position.z<9.5,"%s 进入走廊/屋顶"%base)
		game.player.global_position=Vector3(2.19,base+2.98,10.6)
		await drive(2,13.55)
		check(game.player.global_position.y<base+1.65 and game.player.global_position.z>13.2,"%s 东跑可下楼"%base)
		await drive(0,.91)
		await drive(2,9.7)
		check(game.player.global_position.y<base+.3 and game.player.global_position.z<10.1,"%s 返回本层"%base)
	game.player.global_position=Vector3(-1.7,6.98,7.0)
	await drive(2,5.0)
	check(game.player.global_position.z<5.2,"303门口无衣柜阻挡，可真正进入卧室")
	game.player.global_position=Vector3(0,9.88,6.2)
	await drive(2,5.0)
	check(game.player.global_position.z<5.3,"403门洞可供完整角色通过")
	for y in [8.0,10.9,13.8]:
		var eye:=Vector3(0,y,8)
		for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK,Vector3.UP,Vector3.DOWN]:
			var ray:=PhysicsRayQueryParameters3D.create(eye,eye+direction*25)
			ray.exclude=[game.player.get_rid()]
			check(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"%s 楼层封闭面 %s"%[y,direction])
	game.field_kit.generation+=1
	game._discard_laundry()
	game.queue_free()
	await process_frame
	await process_frame
	print("结果：通过 %d / 失败 %d"%[passed,failed])
	quit(0 if failed==0 else 1)
