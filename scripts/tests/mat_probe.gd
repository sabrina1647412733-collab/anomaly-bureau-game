extends SceneTree
var n := 0
func _initialize() -> void:
	var packed = load("res://assets/models/chars/old_lady.glb")
	var inst = packed.instantiate()
	get_root().add_child(inst)
	var cnt := 0
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		print("[P] ", m.name, " surfaces=", m.mesh.get_surface_count() if m.mesh else -1,
			" override=", m.material_override)
		for i in range(m.mesh.get_surface_count() if m.mesh else 0):
			var mat = m.get_active_material(i)
			if mat is StandardMaterial3D:
				print("    surf", i, " albedo=", mat.albedo_color, " rough=", mat.roughness)
			else:
				print("    surf", i, " mat=", mat)
		cnt += 1
		if cnt > 12: break
	print("[P] total meshes=", cnt)
	quit()
func _process(_d: float) -> bool:
	n += 1
	return n > 3
