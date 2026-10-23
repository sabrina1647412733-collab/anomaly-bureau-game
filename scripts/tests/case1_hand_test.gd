extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if ok: passed+=1; print("[PASS] ",message)
	else: failed+=1; print("[FAIL] ",message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	var kit = game.field_kit
	for id in ["phone","envelope","weird_clock","sweater","sandal"]:
		kit.equip(id)
		await process_frame
		var hands: Node3D = kit.rig.content.get_node_or_null("XuYanGripHands")
		check(hands != null,id+"采用近景专用握持手")
		if hands == null: continue
		var meshes: Array[MeshInstance3D] = []
		preload("res://scripts/case1_prop.gd").collect(hands,meshes)
		var normals_ok := true
		var bounds_ok := true
		for visual in meshes:
			var box: AABB = hands.global_transform.affine_inverse()*visual.global_transform*visual.get_aabb()
			if box.size.length()>1.0 or not box.position.is_finite(): bounds_ok=false
			for i in visual.mesh.get_surface_count():
				var arrays: Array = visual.mesh.surface_get_arrays(i)
				if arrays[Mesh.ARRAY_NORMAL]==null or arrays[Mesh.ARRAY_NORMAL].size()!=arrays[Mesh.ARRAY_VERTEX].size(): normals_ok=false
		check(normals_ok,id+"有完整平滑法线")
		check(bounds_ok,id+"网格有限且无异常拉伸")
		check(meshes.size()>=2,id+"采用独立Blender手部与袖筒网格")
		var pose:String=hands.pose
		check(pose in ["phone","paper","photo","clock","cloth","shoe","key"],id+"使用对应持物姿势")
	kit.rig.set_item("")
	await process_frame
	check(kit.rig.content.get_child_count()==0,"收起物品后手部与物品一同消失")
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d passed / %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
