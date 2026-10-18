extends SceneTree
var game
func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()
func _count(n: Node, acc: Dictionary) -> void:
	if n is MeshInstance3D and n.visible:
		acc.mesh += 1
		var mi: MeshInstance3D = n
		if mi.mesh != null:
			acc.tris += mi.mesh.get_faces().size() / 3
		if mi.material_override != null:
			acc.mats[mi.material_override] = true
	if n is Label3D:
		acc.labels += 1
	if n is OmniLight3D:
		acc.lights += 1
	for c in n.get_children():
		_count(c, acc)
func _run() -> void:
	for i in range(30): await process_frame
	for stage in ["room", "street"]:
		var acc := {"mesh":0, "tris":0, "labels":0, "lights":0, "mats":{}}
		_count(game.prologue_roots[stage], acc)
		print("[MODEL] ", stage, " mesh=", acc.mesh, " tris=", acc.tris, " labels=", acc.labels, " lights=", acc.lights, " unique_mats=", acc.mats.size())
	var total := {"mesh":0, "tris":0, "labels":0, "lights":0, "mats":{}}
	_count(game.prologue_roots["room"], total)
	_count(game.prologue_roots["street"], total)
	print("[MODEL] prologue_total mesh=", total.mesh, " tris=", total.tris, " labels=", total.labels, " lights=", total.lights, " unique_mats=", total.mats.size())
	quit()
