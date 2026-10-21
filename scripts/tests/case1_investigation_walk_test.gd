extends SceneTree
var game
var lc
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("[PASS] ",label)
	else: failed+=1; print("[FAIL] ",label," pos=",game.player.global_position)
func sweep(start: Vector3,end: Vector3) -> Vector3:
	game.player.global_position=start
	game.player.velocity=Vector3.ZERO
	await physics_frame
	var delta := (end-start)/60.0
	for i in range(60): game.player.move_and_collide(delta)
	return game.player.global_position
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_laundry_case()
	game.set_process(false)
	game.player.set_physics_process(false)
	lc=game.laundry
	await physics_frame
	var p: Vector3 = await sweep(Vector3(-1.7,12.78,4.35),Vector3(1.0,12.78,4.35))
	check(p.x>.6,"502可实际穿过维修通道进503")
	p = await sweep(Vector3(-2.1,9.88,6.1),Vector3(-2.1,9.88,4.8))
	check(p.z>5.3,"402关闭时有实体门")
	lc.buildings.f4.k.doors["402"].rotation.y=1.25
	p = await sweep(Vector3(-2.1,9.88,6.1),Vector3(-2.1,9.88,4.8))
	check(p.z<5.2,"402开门后门板与碰撞一起转动")
	lc.buildings.f5.doors["503"].rotation.y=-1.35
	p = await sweep(Vector3(1.7,12.78,6.1),Vector3(1.7,12.78,4.8))
	check(p.z<5.2,"503内部解除插销后走廊捷径可走")
	lc.campaign.power_page()
	lc.campaign.close_page()
	p = await sweep(Vector3(2.4,3.58,7.1),Vector3(4.2,3.58,7.1))
	check(p.x>3.65,"配电控制盘门洞可进入室内")
	p = await sweep(Vector3(0,3.58,9.0),Vector3(0,3.58,10.35))
	check(p.z>10.2,"二楼店门可到廊桥前平台")
	await sweep(Vector3(1.8,3.58,9.55),Vector3(2.8,3.58,9.55))
	await sweep(Vector3(2.8,3.58,9.55),Vector3(2.8,3.58,9.82))
	p = await sweep(Vector3(2.8,3.58,9.82),Vector3(3.55,3.58,9.82))
	check(p.x>3.3,"从店内东南侧可进入廊桥")
	p = await sweep(Vector3(3.55,3.58,10.0),Vector3(13.8,3.58,10.0))
	check(p.x>13.3,"廊桥可步行进入邮政存档间")
	p = await sweep(Vector3(13.9,3.58,10),Vector3(18.3,3.58,10))
	check(p.x>18.0,"邮政室有到挂号件的通路")
	p = await sweep(Vector3(-1.7,7.0,6.95),Vector3(-1.7,7.0,5.55))
	check(p.z<6.35,"303卧室入口无衣柜堵门")
	p = await sweep(Vector3(1.7,7.0,6.3),Vector3(1.7,7.0,4.65))
	check(p.z<5.4,"304儿童房可进入")
	game._discard_laundry()
	game.queue_free()
	await process_frame
	print("RESULT: %d passed / %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
