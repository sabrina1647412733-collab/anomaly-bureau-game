extends SceneTree
## 第一夜闭环测试：钥匙 → 后房门 → 7 号机毛衣 → 认领
var scene
var n := 0
var step := 0

func _initialize() -> void:
	scene = load("res://scenes/laundry.tscn").instantiate()
	root.add_child(scene)

func _process(_d: float) -> bool:
	n += 1
	if n < 4:
		return false
	if step == 0:
		var night = scene.get_node("FirstNight")
		print("[T] 初始 has_key=", night.has_back_key, " open=", night.back_open)
		night._use("backdoor", {"t": ""})
		print("[T] 没钥匙推门 → open=", night.back_open)
		night._use("keyring", {"t": ""})
		print("[T] 拿钥匙 → has_key=", night.has_back_key)
		night._use("m7", {"t": ""})
		print("[T] 门没开时摸 7 号机 → 毛衣可见=", night.f2.sweater.visible)
		night._use("backdoor", {"t": ""})
		print("[T] 开锁 → open=", night.back_open)
		night._use("m7", {"t": ""})
		print("[T] 开锁后拿毛衣 → 毛衣可见=", night.f2.sweater.visible, " claim=", night.fired.has("claim"))
		step = 1
	if step == 1:
		var night = scene.get_node("FirstNight")
		night._anim_doors(0.6)
		print("[T] 门旋转角=", "%.2f" % night.f2.doors["back"].rotation.y)
		print("[T] 记事本 物=", night.entries["物"].size(), " 话=", night.entries["话"].size(),
			" 疑=", night.entries["疑"].size())
		quit()
	return false
