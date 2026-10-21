extends SceneTree
## 验证交接包 §8 列的「场景侧接口」在接进 0017 框架后是否仍然可用
##   --headless --path . -s res://scripts/tests/handover_api_test.gd
var game
var fails: Array = []
var oks: Array = []

func _ok(m: String) -> void:
	oks.append(m); print("  [ OK ] ", m)

func _fail(m: String) -> void:
	fails.append(m); print("  [FAIL] ", m)

func _check(c: bool, m: String) -> void:
	if c: _ok(m)
	else: _fail(m)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("")
	print("========== 交接包 §8 接口自检 ==========")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10):
		await process_frame
	game.start_laundry_case()
	for i in range(10):
		await process_frame

	var bld: Dictionary = game.laundry.buildings
	# §8 列的 8 个 key 全在
	var keys := ["f4", "f5", "roof", "b1", "stairs_up", "alley", "mail_office", "power_room"]
	var miss := []
	for k in keys:
		if not bld.has(k):
			miss.append(k)
	_check(miss.is_empty(), "§8 八个 buildings key 全在（缺 %s）" % str(miss))

	# B1 蓄水池接口
	var b1 = bld.get("b1")
	_check(b1 != null, "b1 可取到")
	if b1 != null:
		_check("rise_water" in b1, "b1.rise_water() 存在")
		_check("start_rising" in b1, "b1.start_rising() 存在")
		_check("stop_rising" in b1, "b1.stop_rising() 存在")
		_check("fire_out" in b1, "b1.fire_out() 存在")
		_check("water_base_y" in b1, "b1.water_base_y 可读")
		var y0: float = b1.water_base_y
		b1.rise_water(30.0)
		_check(b1.water_base_y > y0, "rise_water(30) 真的涨了水（%.4f → %.4f）" % [y0, b1.water_base_y])

	# 配电房接口
	var pr = bld.get("power_room")
	_check(pr != null, "power_room 可取到")
	if pr != null:
		_check("set_breaker" in pr, "pr.set_breaker() 存在")
		_check("breaker_on" in pr, "pr.breaker_on 可读")
		pr.set_breaker(true)
		_check(pr.breaker_on, "set_breaker(true) 生效")

	# 各层灯字典
	var f4 = bld.get("f4")
	_check(f4 != null and "lights" in f4, "f4.lights 存在")
	if f4 != null and "lights" in f4:
		_check(f4.lights.has("corridor") or f4.lights.has("radio"),
			"4F 灯字典有内容（%s）" % str(f4.lights.keys()))
	var f5 = bld.get("f5")
	_check(f5 != null and "lights" in f5, "f5.lights 存在")

	# 交互点坐标（交接包说在 _night/交互点清单_4F5F屋顶B1.md）
	_check(game.spots.size() >= 20, "洗衣店交互点 %d 个" % game.spots.size())
	# 抽查几个交接包里点名过的坐标
	var ids := {}
	for sp in game.spots:
		ids[str(sp["id"])] = sp
	var off: Vector3 = game.laundry.world.position
	var want := {
		"l_m7": Vector3(0.00, 4.25, 2.75),
		"l_keyring": Vector3(-2.90, 5.05, -0.62),
		"lb_board": Vector3(-3.00, 1.75, 12.0),
	}
	for id in want.keys():
		if ids.has(id):
			var got: Vector3 = ids[id]["pos"] - off
			var exp: Vector3 = want[id]
			var d: float = got.distance_to(exp)
			_check(d < 0.01, "%s 坐标与清单一致（差 %.3f m）" % [id, d])
		else:
			_fail("缺交互点 " + id)

	print("")
	print("========== 结果 ==========")
	print("通过 %d / 失败 %d" % [oks.size(), fails.size()])
	for f in fails:
		print("  - ", f)
	quit(0 if fails.is_empty() else 1)
