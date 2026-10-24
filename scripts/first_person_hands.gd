extends Node3D
## Independent Blender-authored anatomical view models; XuYan's full body is untouched.
const BASE := "res://assets/models/view_hands/"
const PAPERS := ["envelope","slip","registry","marriage","cert","homework","return_card","discharge","testimony","pipe_map","notice","waterline","back_water","accident","sign"]
var pose := ""
func build(id: String) -> void:
	name="XuYanGripHands"
	pose="paper" if id in PAPERS else ("photo" if id=="photo" else ("clock" if id=="weird_clock" else ("cloth" if id in ["sweater","roof_copy","sandal"] else ("key" if id.ends_with("key") else "phone"))))
	if id.begins_with("c2_"):pose="paper"
	if id=="sandal":pose="shoe"
	var model: Node3D=load(BASE+pose+".glb").instantiate()
	add_child(model)
	_dress(model)
func _dress(node: Node) -> void:
	if node is MeshInstance3D:
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in node.mesh.get_surface_count():
			var source=node.get_active_material(i)
			if source is StandardMaterial3D:
				var m: StandardMaterial3D=source.duplicate()
				if m.resource_name.contains("canvas"):
					m.albedo_texture=load("res://assets/textures/poly_wool_herringbone/albedo.jpg")
					m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_scale=Vector3(7,7,7)
					m.albedo_color=Color("555852")
				elif m.resource_name.contains("skin"):
					m.albedo_color=Color("b58d74");m.roughness=.66
				node.set_surface_override_material(i,m)
	for child in node.get_children():_dress(child)
