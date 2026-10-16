extends SceneTree
var game
var f := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _cast(x: float, z: float, from_y := 2.0) -> void:
    var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
    var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, -30.0, z))
    var hit: Dictionary = space.intersect_ray(q)
    if hit.is_empty():
        print("   (%s, %s) → 命中: 无  ←  就是这里会掉虚空" % [x, z])
    else:
        print("   (%s, %s) → 命中 y=%.2f  物体=%s" % [x, z, hit["position"].y, hit["collider"].get_parent().name])
func _process(_d: float) -> bool:
    f += 1
    if f == 40:
        print("[W] 地板射线检测（从空中往下打）:")
        _cast(10.8, -60.5, 1.2)  # 检修环线中心
        _cast(9.2, -62.0, 1.2)   # 检修环线里侧
        _cast(-4.0, 0.0)         # 站台
        _cast(4.0, -30.0)        # 轨行区
        _cast(-16.5, 8.0)        # 值班室
        _cast(-16.5, 42.5)       # 广播台
        _cast(-16.5, 26.2)       # 信号室
        _cast(0.8, -53.0)        # 陈默站的地方
        print("[W] 门数量=", game.doors.size())
        for d in game.doors:
            print("   ", d["name"], " 开=", d["open"], " needs_power=", d["needs_power"])
    elif f == 50:
        game._toggle_door(game.doors[2])
        print("[W] 开值班室门后 open=", game.doors[2]["open"], " 目标位置=", game.doors[2]["node"].position)
        game.power = true
        game._toggle_door(game.doors[1])
        print("[W] 合闸后开检修笼门 open=", game.doors[1]["open"])
        game._toggle_bag(true)
        print("[W] 背包可见=", game.bag.visible, " 选中=", game.bag_sel)
    elif f == 70:
        print("[W] 门动画后位置 值班室=", game.doors[2]["node"].position, " 检修笼=", game.doors[1]["node"].position)
        game.bag.move(2)
        game._toggle_bag(false)
        print("[W] 关背包后 可见=", game.bag.visible)
        return true
    return false
