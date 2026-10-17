extends SceneTree
## 校验走路起伏：站着不动应该 0，走起来 body.position.y 在 ±1.2cm 之间
var game
func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()
func _run() -> void:
	for i in range(40):
		await process_frame
	game._on_start()
	for i in range(10):
		await process_frame
	game.player.cam_mode = 1
	var p = game.player
	for i in range(8):
		p._update_body(0.05, 0.0)
	var still: float = p.body.position.y
	var lo := 9.0
	var hi := -9.0
	for i in range(60):
		p._update_body(0.05, 3.2)
		lo = minf(lo, p.body.position.y)
		hi = maxf(hi, p.body.position.y)
	print("[BOB] 静止 y=%.4f   行走 y %.4f ~ %.4f" % [still, lo, hi])
	quit()