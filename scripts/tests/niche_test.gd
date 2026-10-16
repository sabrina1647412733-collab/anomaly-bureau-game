extends SceneTree
var game
var f := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _ray(a: Vector3, b: Vector3) -> String:
    var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
    var q := PhysicsRayQueryParameters3D.create(a, b)
    var hit: Dictionary = space.intersect_ray(q)
    if hit.is_empty():
        return "通（%.1f 米无阻挡）" % a.distance_to(b)
    return "挡在 %.2f 米" % a.distance_to(hit["position"])
func _process(_d: float) -> bool:
    f += 1
    if f == 40:
        print("[N] 检修环线：从轨行区朝 +X 走进去")
        for zz in [-62.5, -61.0, -59.7, -58.5, -57.0]:
            print("   z=%.1f → %s" % [zz, _ray(Vector3(6.0, -0.4, zz), Vector3(11.6, -0.4, zz))])
        print("[N] 龛内竖直空间（地板到顶）")
        print("   站到工作台前 x=10.2 z=-60.6 → 脚下 %s" % _ray(Vector3(10.2, 0.6, -60.6), Vector3(10.2, -3.0, -60.6)))
        print("[N] 门洞净高：从 y=-1.1 往上打")
        print("   x=8.5 z=-59.7 → %s" % _ray(Vector3(8.5, -1.1, -59.7), Vector3(8.5, -1.1, -59.7) + Vector3(0, 3.0, 0)))
        print("[N] 门洞两侧应被墙挡住")
        print("   x=8.5 z=-63.0 → %s" % _ray(Vector3(8.5, -0.4, -63.0), Vector3(12.0, -0.4, -63.0)))
        return true
    return false
