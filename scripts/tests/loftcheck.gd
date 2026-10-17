extends SceneTree
## 放样体自检：面数 / AABB / 法线是否朝外。失败时退出码 1。
const CharBody := preload("res://scripts/charbody.gd")

func _initialize() -> void:
	var prof := [
		Vector3(-0.020, 0.176, 0.112),
		Vector3(0.020, 0.166, 0.108),
		Vector3(0.080, 0.162, 0.106),
		Vector3(0.160, 0.172, 0.111),
		Vector3(0.260, 0.192, 0.120),
		Vector3(0.340, 0.207, 0.128),
		Vector3(0.400, 0.212, 0.131),
		Vector3(0.430, 0.200, 0.124),
		Vector3(0.440, 0.185, 0.115),
	]
	var m := CharBody.loft(prof, 16)
	var arr := m.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var bad := 0
	var zero := 0
	for i in range(verts.size()):
		var v := verts[i]
		var n := norms[i]
		if Vector2(v.x, v.z).length() > 0.05:
			if n.length() < 0.5:
				zero += 1
			elif Vector2(n.x, n.z).dot(Vector2(v.x, v.z)) <= 0.0:
				bad += 1
	print("[LOFT] faces=", m.get_faces().size() / 3, " verts=", verts.size(),
		" aabb=", m.get_aabb(), " outward_bad=", bad, " zero_normals=", zero)
	quit(0 if bad == 0 and zero == 0 else 1)