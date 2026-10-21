extends SceneTree
var game
var passed := 0
var failed := 0
func _initialize() -> void:
	_run()
func check(ok: bool, msg: String) -> void:
	if ok: passed += 1; print("[PASS] ",msg)
	else: failed += 1; print("[FAIL] ",msg," foot=",game.player.global_position)
func walk(start: Vector3, velocity: Vector3, count: int) -> Vector3:
	game.player.global_position = start
	for i in range(count):
		await physics_frame
		game.player.velocity = velocity
		game.player.move_and_slide()
	return game.player.global_position
func _run() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_laundry_case()
	game.set_process(false)
	game.player.set_physics_process(false)
	for i in range(3): await physics_frame
	var p: Vector3 = await walk(Vector3(0,3.55,9.5), Vector3(0,-1,2.5),45)
	check(p.z > 10.5, "胶囊体可穿过洗衣店门口到楼梯平台")
	p = await walk(Vector3(.91,3.78,11.1),Vector3(0,-6,3.2),115)
	check(p.z > 15.8 and p.y < .4, "胶囊体从 2F 左侧梯段下到 1F")
	p = await walk(Vector3(.91,.12,16.3),Vector3(0,-1,-3.2),350)
	check(p.z < 11.3 and p.y > 3.2, "胶囊体从 1F 回到 2F")
	p = await walk(Vector3(2.19,3.56,10.62),Vector3(0,-1,3.2),350)
	check(p.z > 15.9 and p.y > 6.5, "胶囊体从 2F 右侧梯段到 3F")
	p = await walk(Vector3(2.19,6.96,16.6),Vector3(0,-1,-3.2),350)
	check(p.z < 11.2 and p.y < 3.9, "胶囊体从 3F 返回 2F")
	p = await walk(Vector3(2.2,6.96,16.7),Vector3(-2.8,-1,0),100)
	check(p.x < -.2, "3F 平台可进入侧向回廊")
	p = await walk(Vector3(-.3,6.96,16.7),Vector3(0,-1,-3.2),145)
	check(p.z < 10.0 and p.y > 6.7, "3F 回廊与住户走廊连通")
	game._discard_laundry()
	game.queue_free()
	await process_frame
	await process_frame
	print("结果：通过 %d / 失败 %d" % [passed, failed])
	quit(0 if failed == 0 else 1)
