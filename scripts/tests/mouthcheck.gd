extends SceneTree
## 校验 NPC 说话时嘴的开合：说话中应该明显张嘴（scale.y 上去），停下后回到 1.0
var game
func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()
func _run() -> void:
	for i in range(40):
		await process_frame
	game._on_start()
	for i in range(15):
		await process_frame
	var np: Dictionary = game.npcs[0]
	np["node"].visible = true
	for i in range(20):
		await process_frame
	var base: float = np["mouth"].scale.y
	game.dialog_npc = np
	game.hud_sub.visible = true
	var mx := 0.0
	var mn := 9.0
	for i in range(60):
		await process_frame
		mx = maxf(mx, np["mouth"].scale.y)
		mn = minf(mn, np["mouth"].scale.y)
	game.dialog_npc = null
	for i in range(40):
		await process_frame
	print("[MOUTH] 静息=%.3f  说话中 %.3f~%.3f  停下后=%.3f" % [base, mn, mx, np["mouth"].scale.y])
	quit()