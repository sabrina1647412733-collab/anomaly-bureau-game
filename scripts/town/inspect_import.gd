extends SceneTree

func _initialize() -> void:
	for name in ["character", "idle", "walk", "run", "inspect"]:
		var packed: PackedScene = load("res://assets/town/xuyan/%s.glb" % name)
		var scene: Node = packed.instantiate()
		root.add_child(scene)
		print("CHAR ", name)
		_walk(scene, "")
		scene.free()
	quit()

func _walk(node: Node, prefix: String) -> void:
	if node is Skeleton3D:
		var sk: Skeleton3D = node
		print(prefix, node.name, " Skeleton bones=", sk.get_bone_count())
		for i in range(sk.get_bone_count()):
			var bn := sk.get_bone_name(i)
			if bn.contains("Arm") or bn.contains("Hand") or bn.contains("Head"):
				print(prefix, "  BONE ", i, " ", bn)
	elif node is MeshInstance3D:
		var mi: MeshInstance3D = node
		print(prefix, node.name, " Mesh surfaces=", mi.mesh.get_surface_count(), " skeleton=", mi.skeleton)
		if mi.mesh.get_surface_count() > 0:
			var arr: Array = mi.mesh.surface_get_arrays(0)
			print(prefix, "  vertices=", arr[Mesh.ARRAY_VERTEX].size(), " indices=", arr[Mesh.ARRAY_INDEX].size(), " bone data=", arr[Mesh.ARRAY_BONES].size()); if mi.skin != null: for bind in range(mini(20,mi.skin.get_bind_count())): print(prefix, "  BIND ",bind," bone=",mi.skin.get_bind_bone(bind)," name=",mi.skin.get_bind_name(bind))
	elif node is AnimationPlayer:
		var ap: AnimationPlayer = node
		print(prefix, node.name, " AnimPlayer root=", ap.root_node, " list=", ap.get_animation_list())
		for an in ap.get_animation_list():
			var anim: Animation = ap.get_animation(an)
			print(prefix, "  ", an, " len=", anim.length, " tracks=", anim.get_track_count(), " first=", anim.track_get_path(0) if anim.get_track_count() else "")
	else:
		print(prefix, node.name, " ", node.get_class())
	for child in node.get_children():
		_walk(child, prefix + "  ")

