extends RefCounted
## Retain supplied street geometry, colours, building identities and functions.
var cache={}
func apply(node:Node)->void:
	if node is MeshInstance3D and node.mesh!=null:
		var text=String(node.name).to_lower()
		var texture=""
		if text.begins_with("wall_"):texture="grey_plaster_02" if "brick" not in text else "brick_wall_04"
		elif text in ["road","ground","paving"]:texture="asphalt_04" if text=="road" else "concrete_floor"
		elif text=="wood" or text.begins_with("door_wood"):texture="wood_planks_dirt"
		elif text in ["metal","metal_rust"]:texture="metal_plate"
		if texture!="":
			for i in node.mesh.get_surface_count():
				var original=node.get_active_material(i)
				if not original is StandardMaterial3D:continue
				var key=str(original.get_instance_id())+text
				if not cache.has(key):
					var material=original.duplicate()
					material.albedo_texture=load("res://assets/textures/"+texture+"/albedo.jpg")
					material.normal_enabled=true;material.normal_texture=load("res://assets/textures/"+texture+"/normal.jpg")
					material.normal_scale=.18;material.roughness_texture=load("res://assets/textures/"+texture+"/rough.jpg")
					material.roughness=.48 if text=="road" else .85
					material.uv1_triplanar=true;material.uv1_world_triplanar=true;material.uv1_scale=Vector3.ONE*.65
					cache[key]=material
				node.set_surface_override_material(i,cache[key])
	for c in node.get_children():apply(c)
func lights(town)->void:
	for id in ["02","03"]:
		var entry:Dictionary=town._landmark(id)
		if entry.is_empty():continue
		var front:Array=entry.get("front",[entry.x,entry.z])
		var light=OmniLight3D.new();town.add_child(light)
		light.position=Vector3(front[0],2.4,front[1]);light.light_color=Color("d6ae73")
		light.light_energy=.7;light.omni_range=5.5
