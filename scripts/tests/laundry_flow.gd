extends SceneTree
## 第一夜流程自检：把时间快进到 04:00，检查事件是否都触发、记事本是否记上。
var scene
var n := 0

func _initialize() -> void:
	scene = load("res://scenes/laundry.tscn").instantiate()
	root.add_child(scene)

func _process(_d: float) -> bool:
	n += 1
	if n == 4:
		var night = scene.get_node("FirstNight")
		# 快进：每次喂 60 秒游戏时间，共喂 300 次 = 5 小时
		for i in range(300):
			night._process(3.75)
		print("[FLOW] clamp=", night._hhmm(23 * 60 + 40 + 300.0 * 3.75 * 16.0 / 60.0))
		print("[FLOW] fired=", night.fired.keys())
		print("[FLOW] 人=", night.entries["人"].size(), " 物=", night.entries["物"].size(),
			" 话=", night.entries["话"].size(), " 疑=", night.entries["疑"].size())
		print("[FLOW] npc=", night.npc != null, " drums=", night.drums.size())
		var t: float = night.t_night
		print("[FLOW] t_night=", int(t), " 分钟=", int(t / 60.0))
		quit()
	return false
