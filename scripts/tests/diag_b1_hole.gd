extends SceneTree
## 诊断：列出 1F→B1 洞口附近 (2.65, y, -7.40) 所有碰撞体，找出到底是谁挡的。
##   --headless -s res://scripts/tests/diag_b1_hole.gd

func _initialize() -> void:
	var scene = load("res://scenes/laundry.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var p0 := Vector3(2.65, 1.20, -7.40)
	var p1 := Vector3(2.65, -2.60, -7.40)
	var q := PhysicsRayQueryParameters3D.create(p0, p1)
	q.collide_with_areas = false
	var hit := root.world_3d.direct_space_state.intersect_ray(q)
	print("--- 射线命中 ---")
	if hit.is_empty():
		print("无命中（洞口是通的）")
	else:
		print("命中位置: ", hit["position"])
		print("命中体:   ", hit["collider"])
		var c = hit["collider"]
		if c is Node:
			print("节点路径: ", c.get_path())
			print("父节点:   ", c.get_parent().get_path() if c.get_parent() != null else "null")

	print("--- 枚举所有覆盖该点的碰撞形状 ---")
	var target := Vector3(2.65, -0.30, -7.40)
	_dump(root, target)
	print("--- 直接查 World/Collision 上的全部形状 ---")
	var col := root.get_node_or_null("Laundry/World/Collision")
	if col == null:
		col = root.get_node_or_null("Laundry/World/Collision")
	if col != null:
		var n := 0
		for cs in col.get_children():
			if cs is CollisionShape3D:
				var c2: CollisionShape3D = cs
				if c2.shape is BoxShape3D:
					var bx: BoxShape3D = c2.shape
					var gx2: Transform3D = c2.global_transform
					var l2: Vector3 = gx2.affine_inverse() * target
					var h2: Vector3 = bx.size * 0.5
					if absf(l2.x) <= h2.x + 0.001 and absf(l2.y) <= h2.y + 0.001 and absf(l2.z) <= h2.z + 0.001:
						print("  HIT shape idx=", n, " size=", bx.size,
							" center=", gx2.origin, " local=", l2)
				n += 1
		print("  共 ", n, " 个碰撞形状")
	quit()

func _dump(n: Node, target: Vector3) -> void:
	if n is CollisionShape3D:
		var cs: CollisionShape3D = n
		var owner_body := cs.get_parent()
		var gx: Transform3D = cs.global_transform
		if cs.shape is BoxShape3D:
			var box: BoxShape3D = cs.shape
			var local: Vector3 = gx.affine_inverse() * target
			var half := box.size * 0.5
			if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
				print("  覆盖: shape=", box.size, " 世界中心=", gx.origin,
					" body=", owner_body.get_path() if owner_body != null else "null")
		elif cs.shape is CapsuleShape3D or cs.shape is CylinderShape3D or cs.shape is SphereShape3D:
			var rad := 0.0
			if cs.shape is CapsuleShape3D:
				rad = cs.shape.radius
			elif cs.shape is SphereShape3D:
				rad = cs.shape.radius
			elif cs.shape is CylinderShape3D:
				rad = cs.shape.radius
			if gx.origin.distance_to(target) < rad + 1.0:
				print("  近: ", cs.shape.get_class(), " 中心=", gx.origin,
					" body=", owner_body.get_path() if owner_body != null else "null")
	for c in n.get_children():
		_dump(c, target)
