extends SceneTree
## 报出角色模型关键尺寸：总高 / 头高 / 最宽 / 腿跨度 / 肩线与髋线高度（用于和 2D 参考图对表）
var game

func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    _run()

func _run() -> void:
    for i in range(40):
        await process_frame
    game._on_start()
    for i in range(25):
        await process_frame
    game.player.cam_mode = 1
    game.player.global_position = Vector3(0, 0, 0)
    game.player.rotation.y = 0
    for i in range(10):
        await process_frame
    _report("玩家（夜班调度员）", game.player.body, game.player.parts)
    for np in game.npcs:
        np["node"].visible = true
        np["node"].rotation.y = 0
    for i in range(6):
        await process_frame
    _report("NPC 林岚", game.npcs[0]["node"], {})
    quit()

func _box_of(n: Node) -> AABB:
    var ab := AABB()
    var first := true
    var stack := [n]
    while stack.size() > 0:
        var nd = stack.pop_back()
        if nd is MeshInstance3D and nd.mesh != null:
            var b: AABB = nd.global_transform * nd.mesh.get_aabb()
            ab = b if first else ab.merge(b)
            first = false
        for c in nd.get_children():
            stack.append(c)
    return ab

func _report(label: String, root: Node3D, parts: Dictionary) -> void:
    var full := _box_of(root)
    var H := full.size.y
    var top := full.position.y + H
    var head := AABB()
    var legs := AABB()
    var arms := AABB()
    var first := true
    if parts.size() > 0:
        head = _box_of(parts["head"])
        legs = _box_of(parts["hipL"]).merge(_box_of(parts["hipR"]))         .merge(_box_of(parts["kneeL"])).merge(_box_of(parts["kneeR"]))         .merge(_box_of(parts["footL"])).merge(_box_of(parts["footR"]))
        arms = _box_of(parts["shoulderL"]).merge(_box_of(parts["shoulderR"]))         .merge(_box_of(parts["elbowL"])).merge(_box_of(parts["elbowR"]))
        first = false
    else:
        var stack := [root]
        while stack.size() > 0:
            var nd = stack.pop_back()
            if nd is MeshInstance3D and nd.mesh != null:
                var nm: String = nd.name
                var b: AABB = nd.global_transform * nd.mesh.get_aabb()
                var is_head := nm.begins_with("head") or nm.begins_with("hair") or nm.begins_with("cap") or nm.begins_with("eye") or nm.begins_with("visor")
                var is_leg := nm.begins_with("leg") or nm.begins_with("shoe")
                if is_head:
                    head = b if first else head.merge(b)
                    first = false
                elif is_leg:
                    legs = b if legs.size == Vector3.ZERO else legs.merge(b)
                else:
                    arms = b if arms.size == Vector3.ZERO else arms.merge(b)
            for c in nd.get_children():
                stack.append(c)
    print("=== %s" % label)
    print("   总高 %.3f m     最宽 %.3f m（宽/高 %.3f）" % [H, full.size.x, full.size.x / H])
    print("   头  y %.3f..%.3f  高 %.3f  头身比 %.2f（头高占身高 %.1f%%）  头宽 %.3f"
          % [head.position.y, head.position.y + head.size.y, head.size.y, H / head.size.y,
             head.size.y * 100.0 / H, head.size.x])
    print("   肩线 %.0f%% 距顶（%s）   腿组跨度 %.3f（宽/高 %.3f）"
          % [(top - (arms.position.y + arms.size.y)) * 100.0 / H,
             "肩" + ("%.2f" % (arms.position.y + arms.size.y)), legs.size.x, legs.size.x / H])
    print("   腿/脚 y %.3f..%.3f   脚底距地 %.3f m" % [legs.position.y, legs.position.y + legs.size.y, legs.position.y])
