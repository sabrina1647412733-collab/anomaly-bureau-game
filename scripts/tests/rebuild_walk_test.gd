extends SceneTree
var game
var world: Node3D
var body: CharacterBody3D
var results := {"routes":[]}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.start_laundry_case();game.set_process(false);game.player.set_physics_process(false)
	body=game.player;world=game.laundry.world
	game.laundry.f2.doors.back.rotation.y=1.5
	game.laundry.buildings.f4.k.doors["402"].rotation.y=1.5
	game.laundry.buildings.f5.doors["503"].rotation.y=-1.5
	await physics_frame
	await route("门厅入口",[Vector3(-0.55,0.06,-9),Vector3(-0.55,0.06,-4)])
	await route("门厅到梯口",[Vector3(-0.55,0.06,-4),Vector3(-0.55,0.06,6.5),Vector3(0.89,0.06,10.55)])
	await route("2F店门到长椅",[Vector3(2.21,3.55,10.5),Vector3(1.55,3.55,9.4),Vector3(1.32,3.55,6.25)])
	await route("配电房绕椅进入",[Vector3(1.32,3.55,8.7),Vector3(1.32,3.55,7.8),Vector3(2.6,3.55,7.8),Vector3(2.6,3.55,6.95),Vector3(4.1,3.55,6.95)])
	await route("后房门进入",[Vector3(-1.65,3.55,2.6),Vector3(-1.65,3.55,0.6)])
	await route("店内到廊桥出口",[Vector3(1.8,3.55,9.5),Vector3(2.8,3.55,9.5),Vector3(3.6,3.55,9.5)])
	await route("廊桥到邮政间",[Vector3(3.6,3.55,9.5),Vector3(8.5,3.55,9.5),Vector3(14.6,3.55,9.5)])
	await route("303门",[Vector3(-1.25,6.95,7.2),Vector3(-1.25,6.95,5.6)])
	await route("304门",[Vector3(1.55,6.95,6.0),Vector3(1.55,6.95,4.5)])
	await route("402开门",[Vector3(-2.1,9.85,6.2),Vector3(-2.1,9.85,4.85)])
	await route("502维修通道至503",[Vector3(-1.7,12.75,4.35),Vector3(1.7,12.75,4.35)])
	await route("B1步道到阀门",[Vector3(2.58,-2.83,-8.1),Vector3(2.58,-2.83,-6.1),Vector3(2.58,-2.83,-0.2),Vector3(2.7,-2.83,0.12)])
	await route("屋顶到水箱",[Vector3(1.55,15.65,11.4),Vector3(0.6,15.65,6.6),Vector3(-0.1,15.65,2.6),Vector3(-0.1,15.65,0.9)])
	await route("1F至2F",[Vector3(0.89,0.05,10.55),Vector3(0.89,0.05,13.7),Vector3(2.21,1.8,13.7),Vector3(2.21,3.55,10.6),Vector3(1.55,3.55,9.6)])
	await route("2F至3F",[Vector3(0.89,3.55,10.55),Vector3(0.89,3.55,13.7),Vector3(2.21,5.25,13.7),Vector3(2.21,6.95,10.6),Vector3(1.55,6.95,9.6)])
	await route("3F至4F",[Vector3(0.89,6.95,10.55),Vector3(0.89,6.95,13.7),Vector3(2.21,8.4,13.7),Vector3(2.21,9.850000000000001,10.6),Vector3(1.55,9.850000000000001,9.6)])
	await route("4F至5F",[Vector3(0.89,9.850000000000001,10.55),Vector3(0.89,9.850000000000001,13.7),Vector3(2.21,11.3,13.7),Vector3(2.21,12.750000000000002,10.6),Vector3(1.55,12.750000000000002,9.6)])
	await route("5F至屋顶",[Vector3(0.89,12.75,10.55),Vector3(0.89,12.75,13.7),Vector3(2.21,14.2,13.7),Vector3(2.21,15.65,10.6),Vector3(1.55,15.65,9.6)])
	for floor in [[0,3.5],[3.5,6.9],[6.9,9.8],[9.8,12.7],[12.7,15.6]]:
		var low:float=floor[0];var high:float=floor[1];var mid:float=(low+high)/2
		await route("%.1f至%.1f下楼"%[high,low],[Vector3(2.21,high+.05,10.55),Vector3(2.21,mid,13.7),Vector3(.89,mid,13.7),Vector3(.89,low+.05,10.55),Vector3(1.55,low+.05,9.6)])
	var failed=0
	for row in results.routes:
		if not row.ok:failed+=1
	var file=FileAccess.open("res://_预览/rebuild_walk.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(results,"\t"))
	print("RESULT: %d passed / %d failed"%[results.routes.size()-failed,failed])
	game._discard_laundry();game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failed==0 else 1)
func route(label: String, points: Array) -> void:
	body.global_position=points[0]; body.velocity=Vector3.ZERO
	for i in range(12):
		await physics_frame
		body.velocity=Vector3(0,-1,0); body.move_and_slide()
	var ok=true; var collision_name=""; var reached=0; var side_collisions: Array=[]
	for target in points.slice(1):
		var previous=body.global_position; var stuck=0; var arrived=false
		for i in range(600):
			await physics_frame
			var difference: Vector3=target-body.global_position; difference.y=0
			if difference.length()<.07: arrived=true; break
			var direction=difference.normalized()
			body.velocity.x=direction.x*2; body.velocity.z=direction.z*2
			body.velocity.y=-.5 if body.is_on_floor() else body.velocity.y-22.0/60.0
			body.move_and_slide()
			for c in range(body.get_slide_collision_count()):
				var contact=body.get_slide_collision(c)
				if contact.get_normal().y<.65 and not side_collisions.has(str(contact.get_collider().name)): side_collisions.append(str(contact.get_collider().name))
			if body.get_slide_collision_count()>0:
				collision_name=str(body.get_slide_collision(body.get_slide_collision_count()-1).get_collider().name)
			if body.global_position.distance_to(previous)<.002: stuck+=1
			else: stuck=0
			previous=body.global_position
			if stuck>40 or body.global_position.y<target.y-3: break
		if not arrived: ok=false; break
		reached+=1
	results.routes.append({"name":label,"ok":ok,"position":str(body.global_position),"last_collision":collision_name,"side_collisions":side_collisions,"reached":reached})
	print("ROUTE ",label," ",ok," ",body.global_position," ",collision_name)
