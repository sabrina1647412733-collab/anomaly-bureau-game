extends SceneTree
## 悬空审计（正式版）：逐层检查「物体底部是否贴着该层地板」
## ---------------------------------------------------------------------------
## 为什么需要它：把洗衣店接进 0017 框架时，曾经因为 world 节点被挪到 (2000,0,0)
## 而 laundry_kit.model() 的贴地算法用的是**世界**包围盒 →
## B1 的锅炉、4F 的工具箱全部飘到 1F 门厅半空。截图不一定看得出来，
## 必须用数据查（和交接包 §13「画了洞口≠洞口能过」同一个道理）。
##
##   --headless --path . -s res://scripts/tests/laundry_float_audit.gd

## 楼层链（和 laundry_kit.gd 保持一致）
const FLOORS := [
	{"name": "B1", "y": -3.0},
	{"name": "1F", "y": 0.0},
	{"name": "2F", "y": 3.5},
	{"name": "3F", "y": 6.9},
	{"name": "4F", "y": 9.8},
	{"name": "5F", "y": 12.7},
	{"name": "屋顶", "y": 15.6},
]
const TOL := 0.35          # 允许离地的余量（踢脚线、地毯、地台都算正常）
const MIN_SIZE := 0.15     # 太薄的片（告示、画框、水面）不参与判定

var fails: Array = []
var oks: Array = []

func _ok(m: String) -> void:
	oks.append(m); print("  [ OK ] ", m)

func _fail(m: String) -> void:
	fails.append(m); print("  [FAIL] ", m)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("")
	print("========== 洗衣店悬空审计 ==========")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(8):
		await process_frame
	game.start_laundry_case()
	for i in range(8):
		await process_frame

	var w: Node3D = game.laundry.world
	print("  world.global_position = ", w.global_position, "（必须是原点，见 laundry_case.enter）")
	_check(is_zero_approx(w.global_position.length()), "洗衣店在原点（否则贴地算法全错）")

	# 收集所有实体网格
	var meshes: Array = []
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var bb: AABB = m.global_transform * m.get_aabb()
		if bb.size.y < MIN_SIZE:
			continue
		meshes.append(bb)
	print("  参与审计的实体网格 %d 个" % meshes.size())

	# 逐层：该层「地板 y … 地板+层高」区间内的物体，底部应该贴着地板
	for fl in FLOORS:
		var fy: float = float(fl["y"])
		var fname: String = String(fl["name"])
		var total := 0
		var bad := []
		for bb in meshes:
			var b: AABB = bb
			var bottom: float = b.position.y
			var center_y: float = b.get_center().y
			# 归到「最近的那一层」：物体中心落在该层区间里
			var lo: float = fy - 0.2
			var hi: float = fy + 3.4
			if center_y < lo or center_y > hi:
				continue
			total += 1
			# 底部离本层地板的高度
			var lift: float = bottom - fy
			# 低于地板 = 穿地；高于 TOL = 飘
			if lift > TOL:
				# 排除「本来就该悬空的」：灯罩、吊牌、晾衣绳上的衣服（尺寸小且扁）
				var is_flat := b.size.y < 0.30
				var is_small := b.size.x * b.size.z < 0.25
				if is_flat and is_small:
					continue
				bad.append("y=%.2f 尺寸=(%.1f,%.1f,%.1f)" % [lift, b.size.x, b.size.y, b.size.z])
			elif lift < -0.5:
				bad.append("穿地 %.2f" % lift)
		if total == 0:
			continue
		if bad.is_empty():
			_ok("%s（%d 个物体）全部贴地" % [fname, total])
		else:
			_fail("%s（%d 个物体）有 %d 个悬空/穿地：%s" % [
				fname, total, bad.size(), ", ".join(bad.slice(0, 4))])

	print("")
	print("========== 结果 ==========")
	print("通过 %d / 失败 %d" % [oks.size(), fails.size()])
	for f in fails:
		print("  - ", f)
	quit(0 if fails.is_empty() else 1)

func _check(c: bool, m: String) -> void:
	if c: _ok(m)
	else: _fail(m)
