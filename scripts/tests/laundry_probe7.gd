extends SceneTree
## 排查 7 号机毛衣的落点
var scene
var n := 0

func _initialize() -> void:
	scene = load("res://scenes/laundry.tscn").instantiate()
	root.add_child(scene)

func _process(_d: float) -> bool:
	n += 1
	if n < 4:
		return false
	var w: Node3D = scene.get_node("World")
	print("[D] World 子节点:")
	for c in w.get_children():
		print("   ", c.name, " ", c.get_class(), " pos=", c.position)
	# 找所有名字带 sweater / 材质是深蓝的
	var found := 0
	for m in w.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		var p: Vector3 = mi.global_position
		if p.z > 2.1 and p.z < 2.9 and absf(p.x) < 1.0 and p.y > 3.8 and p.y < 4.4:
			var mm = mi.material_override
			print("[D] 7 号机附近 mesh: ", mi.name, " pos=", p, " mat=", mm)
			found += 1
			if found > 12:
				break
	print("[D] 共找到 ", found)
	quit()
	return false
