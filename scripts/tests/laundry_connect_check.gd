extends SceneTree
## 连通性自检：用物理射线验证「每一处楼梯口 / 洞口真的能走过去」。
## headless 可跑（不需要渲染）。
##   Godot_..._console.exe --path . --headless -s res://scripts/tests/laundry_connect_check.gd

var scene
var fails: Array = []
var oks: Array = []

func _initialize() -> void:
	scene = load("res://scenes/laundry_upper.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	_check()
	print("")
	print("========== 连通性自检 ==========")
	for s in oks:
		print("[ OK ] ", s)
	for s in fails:
		print("[FAIL] ", s)
	print("--------------------------------")
	print("通过 %d / 失败 %d" % [oks.size(), fails.size()])
	quit(0 if fails.is_empty() else 1)

## 从 a 到 b 打一条射线，撞到东西就说明被挡住了。
## 排除：起点/终点附近 0.25 m 内的碰撞（避免自己和地面）。
func _ray(a: Vector3, b: Vector3, label: String, tol := 0.25) -> void:
	var from := a
	var to := b
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var hit := root.world_3d.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		oks.append(label)
		return
	var d: float = from.distance_to(hit["position"])
	if d <= tol:
		oks.append(label)
	else:
		fails.append("%s 被挡住（距起点 %.2f m，位置 %s）" % [label, d, str(hit["position"])])

func _check() -> void:
	# ── ① 1F → B1 洞口不在这里验：laundry_upper.tscn 不含 1F，
	#     那条由 laundry_connect_check_formal.gd 在正式场景里单独验。

	# ── ② 3F → 4F：楼梯口 x 0.30…2.80 在 3F 走廊南墙 z=10.1
	#     从 3F 走廊里 (1.55, 7.5, 9.6) 往南穿洞口到 (1.55, 7.5, 10.6)
	_ray(Vector3(1.55, 7.40, 9.60), Vector3(1.55, 7.40, 10.80), "② 3F→4F 楼梯口（穿南墙）")

	# ── ③ 4F → 5F：4F 走廊南墙 z=10.1
	_ray(Vector3(1.55, 10.30, 9.60), Vector3(1.55, 10.30, 10.80), "③ 4F→5F 楼梯口（穿南墙）")

	# ── ④ 5F → 屋顶：5F 走廊南墙 z=10.1
	_ray(Vector3(1.55, 13.20, 9.60), Vector3(1.55, 13.20, 10.80), "④ 5F→屋顶 楼梯口（穿南墙）")

	# ── ⑤ 上层走廊本身能走：4F 走廊北端走到南端
	_ray(Vector3(0.0, 10.40, 5.80), Vector3(0.0, 10.40, 9.90), "⑤ 4F 走廊可通行")

	# ── ⑥ 4F 三个房门真的通（402 / 403 / 401）
	_ray(Vector3(-2.10, 10.40, 5.95), Vector3(-2.10, 10.40, 4.95), "⑥a 402 房门可进")
	_ray(Vector3(0.00, 10.40, 5.95), Vector3(0.00, 10.40, 4.95), "⑥b 403 房门可进")
	_ray(Vector3(2.10, 10.40, 5.95), Vector3(2.10, 10.40, 4.95), "⑥c 401 房门可进")

	# ── ⑦ 5F 两个房门真的通（502 / 503）
	_ray(Vector3(-1.70, 13.30, 5.95), Vector3(-1.70, 13.30, 4.95), "⑦a 502 房门可进")
	_ray(Vector3(1.70, 13.30, 5.95), Vector3(1.70, 13.30, 4.95), "⑦b 503 房门可进")
