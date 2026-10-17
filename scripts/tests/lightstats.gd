extends SceneTree
var game
func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()
func _run() -> void:
	for i in range(30):
		await process_frame
	var ls = game.builder.lights
	var small := 0; var tiny := 0; var big := 0
	var e_hist := {}; var r_hist := {}
	for l in ls:
		var e: float = l.light_energy; var r: float = l.omni_range
		if e < 1.0: tiny += 1
		elif e < 2.0: small += 1
		else: big += 1
		var ek := "%.1f" % e; e_hist[ek] = int(e_hist.get(ek, 0)) + 1
		var rk := "%d" % int(r); r_hist[rk] = int(r_hist.get(rk, 0)) + 1
	print("[LIGHT] total=", ls.size(), " tiny<1=", tiny, " small1-2=", small, " big2+=", big)
	print("[LIGHT] energy=", e_hist)
	print("[LIGHT] range=", r_hist)
	print("[LIGHT] train_lamps=", game.train.lamps.size(), " flash_shadow=", game.player.flash.shadow_enabled)
	quit()