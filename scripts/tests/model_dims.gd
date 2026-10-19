extends SceneTree
func _aabb_rec(n: Node, xf: Transform3D) -> AABB:
    var out := AABB()
    var has := false
    if n is MeshInstance3D and n.mesh != null:
        out = xf * n.get_aabb()
        has = true
    for c in n.get_children():
        var cx: Transform3D = xf
        if c is Node3D:
            cx = xf * c.transform
        var cb := _aabb_rec(c, cx)
        if cb.size != Vector3.ZERO:
            if not has:
                out = cb
                has = true
            else:
                out = out.merge(cb)
    return out
func _initialize() -> void:
    var list := ["wooden_table_02/wooden_table_02_1k.gltf","painted_wooden_chair_01/painted_wooden_chair_01_1k.gltf","painted_wooden_cabinet/painted_wooden_cabinet_1k.gltf","wooden_bookshelf_worn/wooden_bookshelf_worn_1k.gltf","binder_notebook/binder_notebook_1k.gltf","vintage_telephone_wall_clock/vintage_telephone_wall_clock_1k.gltf","desk_lamp_arm_01/desk_lamp_arm_01_1k.gltf","alarm_clock_01/alarm_clock_01_1k.gltf","cardboard_box_01/cardboard_box_01_1k.gltf","potted_plant_01/potted_plant_01_1k.gltf","Television_01/Television_01_1k.gltf","ClassicNightstand_01/ClassicNightstand_01_1k.gltf"]
    for p in list:
        var full: String = "res://assets/models/" + String(p)
        if not ResourceLoader.exists(full):
            print("[MISS] ", full)
            continue
        var inst: Node3D = load(full).instantiate()
        root.add_child(inst)
        var b := _aabb_rec(inst, inst.transform)
        print("[DIM] ", p, "  size=", b.size, "  min=", b.position)
        inst.queue_free()
    quit()

