extends RefCounted
## Scene-bound close-up props. Geometry and collider coordinates share one export.
const BASE := "res://assets/town/renewal/hero_props/"
const NATIVE_MATERIALS := ["wicker", "enamel", "enamel_flower", "linen"]
var manifest: Dictionary = {}
var holder: Node3D
var town

func setup(owner_town) -> void:
	town = owner_town
	manifest = JSON.parse_string(FileAccess.get_file_as_string(BASE+"hero_props_manifest.json"))
	holder = Node3D.new()
	holder.name = "StreetHeroProps"
	town.add_child(holder)
	for path in manifest.get("chunks", []):
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("主街近景道具缺失："+str(path))
			continue
		var chunk := packed.instantiate()
		holder.add_child(chunk)
		apply_materials(chunk)
	for prop in manifest.get("props", []):
		var at := Vector3(float(prop.at[0]), float(prop.at[1]), float(prop.at[2]))
		var size := Vector3(float(prop.size[0]), float(prop.size[1]), float(prop.size[2]))
		town._box(at, size, float(prop.get("yaw", 0.0)))

func apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(index)
			if material == null:
				continue
			var kind := String(material.resource_name).get_slice(".", 0)
			if kind in NATIVE_MATERIALS and material is StandardMaterial3D:
				var native := material.duplicate() as StandardMaterial3D
				native.vertex_color_use_as_albedo = true
				node.set_surface_override_material(index, native)
			else:
				node.set_surface_override_material(index, town.renewal._material(kind))
		node.visibility_range_begin = 0.0
		node.visibility_range_end = 48.0
		node.visibility_range_end_margin = 5.0
	for child in node.get_children():
		apply_materials(child)
