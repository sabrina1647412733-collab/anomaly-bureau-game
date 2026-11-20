extends RefCounted
## Existing rear-room shell, with evidence anchors on the actual Blender props.
## The key root remains compatible with LaundryCase restore/visibility handling.
const BASE := "res://assets/models/laundry_backroom/"
var keyring: Node3D
var root: Node3D
var manifest: Dictionary

func build(lc) -> void:
	var a = lc.art
	manifest = JSON.parse_string(FileAccess.get_file_as_string(BASE + "manifest.json"))
	root = load(BASE + "backroom.glb").instantiate()
	root.name = "BackroomEvidence"
	lc.world.add_child(root)
	_dress(root, a)
	var photograph := MeshInstance3D.new()
	photograph.name = "MountedFamilyPhoto"
	var photo_mesh := QuadMesh.new()
	photo_mesh.size = Vector2(.41, .31)
	photograph.mesh = photo_mesh
	var photo_material := StandardMaterial3D.new()
	photo_material.albedo_texture = load("res://assets/ui/inventory/materials/family_photo_v1.png")
	photo_material.roughness = .8
	photograph.material_override = photo_material
	photograph.position = Vector3(-3.114, 5.07, 1.09)
	photograph.rotation.y = PI / 2
	root.add_child(photograph)
	keyring = load(BASE + "boiler_keys.glb").instantiate()
	keyring.name = "BoilerSpareKeys"
	lc.world.add_child(keyring)
	var at: Array = manifest.points.l_keyring
	keyring.position = Vector3(at[0], at[1], at[2])
	_dress(keyring, a)
	for entry in manifest.collisions:
		var c: Array = entry.center
		var s: Array = entry.size
		var body := StaticBody3D.new()
		body.name = "Rear_" + String(entry.id)
		lc.world.add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(s[0], s[1], s[2])
		shape.shape = box
		shape.position = Vector3(c[0], c[1], c[2])
		body.add_child(shape)
	# Every label is attached to a physical face, with depth testing enabled.
	_label(a, "秀 兰 干 洗", Vector3(-1.72, 4.74, -.601), .065, 0)
	_label(a, "2004 · 老顾客簿", Vector3(-2.80, 4.332, .45), .012, 0, -PI / 2, Color("403c2e"))
	_label(a, "11 / 08　旧报剪存", Vector3(-3.121, 4.94, .12), .017, PI / 2, 0, Color("403c2e"))
	_label(a, "检修留存", Vector3(-.48, 4.08, .052), .012, 0, 0, Color("403c2e"))
	var light = a.omni(Vector3(-1.62, 5.94, .55), Color("e9d7b3"), 1.05, 3.3, true)
	light.name = "BackroomTaskLight"
	light.light_size = .16
	light.shadow_bias = .025
	light.shadow_normal_bias = .22
	a.bev(Vector3(-1.62, 6.35, .55), Vector3(.20, .06, .20), a.plain(Color("424d42")), .012)
	a.bev(Vector3(-1.62, 6.30, .55), Vector3(.13, .07, .13), a.emit(Color("d4c5a1"), .6), .025)
	# Conduit reaches the existing crossbeam instead of leaving the lamp floating.
	a.cyl(Vector3(-1.62, 6.42, .55), .009, .10, a.plain(Color("4b5145")), 8)

func _label(a, text: String, at: Vector3, size: float, yaw: float, pitch := 0.0, color := Color("c5b68b")) -> void:
	var label: Label3D = a.label(text, at, size, color, yaw)
	label.rotation.x = pitch
	label.no_depth_test = false
	label.double_sided = false

func _dress(node: Node, a) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var source: Material = node.get_active_material(surface)
			if source == null:continue
			match String(source.resource_name):
				"Rear_Oak":node.set_surface_override_material(surface, a.pbr("oak_wood_planks", 2.0, Color("77674b"), .9, 0, .18))
				"Rear_PaintedSteel":node.set_surface_override_material(surface, a.pbr("painted_concrete", 1.8, Color("748275"), .78, .15, .12))
				"Rear_Raincoat":node.set_surface_override_material(surface, a.pbr("rough_linen", 5.0, Color("8f8239"), .74, 0, .1))
	for child in node.get_children():_dress(child, a)
