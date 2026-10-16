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
        return "无阻挡（可走通 %.1f 米）" % a.distance_to(b)
    return "被挡在 %.2f 米处" % a.distance_to(hit["position"])
func _process(_d: float) -> bool:
    f += 1
    if f == 40:
        print("[D] 值班室（门在 x=-11.0, z 7.6~9.6）:")
        for zz in [7.8, 8.6, 9.4]:
            print("   z=%.1f 从门口往里  → %s" % [zz, _ray(Vector3(-10.9, 1.0, zz), Vector3(-17.0, 1.0, zz))])
        print("[D] 广播台（门在 x=-11.5, z 37.6~39.6）:")
        for zz in [37.8, 38.6, 39.4]:
            print("   z=%.1f 从门口往里  → %s" % [zz, _ray(Vector3(-11.4, 1.0, zz), Vector3(-17.0, 1.0, zz))])
        print("[D] 信号室（门在 x=-14.2）:")
        print("   z=28.3 从门口往里  → %s" % _ray(Vector3(-14.1, 1.0, 28.3), Vector3(-17.5, 1.0, 28.3)))
        print("[D] 检修笼（门在 x=-16.3）:")
        print("   z=-36.0 从门口往里 → %s" % _ray(Vector3(-16.2, 1.0, -36.0), Vector3(-17.8, 1.0, -36.0)))
        return true
    return false
