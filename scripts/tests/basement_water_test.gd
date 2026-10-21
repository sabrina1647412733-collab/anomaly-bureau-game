extends SceneTree
## 蓄水池涨水自检：验证「每 30 秒涨 1 cm」以及到顶保护。
var scene
var b1

func _initialize() -> void:
	scene = load("res://scenes/laundry.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	b1 = scene.buildings.get("b1")
	if b1 == null:
		print("[FAIL] 找不到 B1 实例")
		quit(1)
		return

	print("========== 蓄水池涨水自检 ==========")
	var ok := 0
	var fail := 0

	# 初始水位
	var y0: float = b1.water_base_y
	print("  初始水位 y = %.4f" % y0)

	# 模拟 30 秒 → 应涨 1 cm
	b1.rise_water(30.0)
	var y1: float = b1.water_base_y
	var d1: float = y1 - y0
	if absf(d1 - 0.01) < 0.0005:
		print("  [ OK ] 30 秒涨了 %.4f m（应为 0.01）" % d1)
		ok += 1
	else:
		print("  [FAIL] 30 秒涨了 %.4f m（应为 0.01）" % d1)
		fail += 1

	# 模拟 5 分钟（300 秒）→ 应涨 0.10 m
	var y2: float = b1.water_base_y
	b1.rise_water(300.0)
	var d2: float = b1.water_base_y - y2
	if absf(d2 - 0.10) < 0.005:
		print("  [ OK ] 300 秒涨了 %.4f m（应为 0.10）" % d2)
		ok += 1
	else:
		print("  [FAIL] 300 秒涨了 %.4f m（应为 0.10）" % d2)
		fail += 1

	# 一直涨到顶，检查不会溢出
	for i in range(40):
		b1.rise_water(300.0)
	var ytop: float = b1.water_base_y
	if ytop <= -2.97:
		print("  [ OK ] 涨到上限后停住（y = %.3f，池口 = -3.0）" % ytop)
		ok += 1
	else:
		print("  [FAIL] 水位超出池口（y = %.3f）" % ytop)
		fail += 1

	# 水面节点确实跟着动
	if b1.water != null:
		if absf(b1.water.position.y - b1.water_base_y) < 0.0001:
			print("  [ OK ] 水面节点位置同步（y = %.3f）" % b1.water.position.y)
			ok += 1
		else:
			print("  [FAIL] 水面节点不同步")
			fail += 1
	else:
		print("  [FAIL] 水面节点为空")
		fail += 1

	# 自动模式开关
	b1.start_rising()
	if b1.water_rising == true:
		print("  [ OK ] start_rising() 打开自动上涨")
		ok += 1
	else:
		print("  [FAIL] start_rising() 无效")
		fail += 1
	b1.stop_rising()
	if b1.water_rising == false:
		print("  [ OK ] stop_rising() 关闭自动上涨")
		ok += 1
	else:
		print("  [FAIL] stop_rising() 无效")
		fail += 1

	print("--------------------------------")
	print("通过 %d / 失败 %d" % [ok, fail])
	quit(0 if fail == 0 else 1)
