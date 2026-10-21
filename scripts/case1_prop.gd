extends RefCounted
const BASE := "res://assets/models/case1_props/"

static func place(parent: Node3D, id: String, at: Vector3, width: float, yaw := 0.0) -> Node3D:
	var path := BASE+id+".glb"
	if not ResourceLoader.exists(path): return null
	var scene: PackedScene = load(path)
	if scene == null: return null
	var holder := Node3D.new()
	holder.name = "CaseProp_"+id
	holder.set_meta("dynamic",true)
	parent.add_child(holder)
	var model: Node3D = scene.instantiate()
	holder.add_child(model)
	var meshes: Array[MeshInstance3D] = []
	collect(model,meshes)
	var box := AABB()
	var first := true
	for mesh in meshes:
		var bounds := model.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		box = bounds if first else box.merge(bounds)
		first = false
	var factor := width/maxf(box.size.x,.001)
	model.scale *= factor
	model.position -= Vector3(box.get_center().x,box.position.y,box.get_center().z)*factor
	holder.position = at
	holder.rotation.y = yaw
	return holder

static func collect(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): collect(child,result)
