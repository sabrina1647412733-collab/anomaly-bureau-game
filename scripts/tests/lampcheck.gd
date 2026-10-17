extends SceneTree
## 校验环线隧道那盏坏灯的节奏：大部分时间亮、偶尔掉下去
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
	var lit := 0
	var n := 0
	var pat := ""
	var bright := 0.0
	for i in range(160):
		game._update_tunnel_lamp(0.25)
		var e: float = game.tun_lamp_mat.emission_energy_multiplier
		bright += e
		n += 1
		if e > 0.5:
			lit += 1
		if i % 8 == 0:
			pat += ("亮" if e > 0.5 else "灭")
	print("[LAMP] 采样 %d 帧：亮帧 %d (%.0f%%)  平均发光 %.2f  抽样节奏 %s" % [n, lit, 100.0 * float(lit) / float(n), bright / float(n), pat])
	quit()