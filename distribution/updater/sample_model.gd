extends SceneTree
## Isolated real-resource sample; never writes to the source project.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3: quit(1); return
	if not ProjectSettings.load_resource_pack(args[0], true): quit(1); return
	var resource: PackedScene = load("res://assets/models/case1_props/shoe.glb")
	if resource == null: quit(1); return
	var instance := resource.instantiate()
	# A visible geometry-only change to an existing shoe prop, preserving textures.
	instance.scale *= Vector3(1.02, 1.0, 1.0)
	instance.set_meta("distribution_model_sample", "shoe_width_102_percent")
	var packed := PackedScene.new()
	if packed.pack(instance) != OK: quit(1); return
	if ResourceSaver.save(packed, args[1]) != OK: quit(1); return
	var report := FileAccess.open(args[2], FileAccess.WRITE)
	report.store_string(JSON.stringify({"source":"assets/models/case1_props/shoe.glb", "scale":str(instance.scale), "textures_reused":true}))
	report.close(); instance.free(); quit()
