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
        return "通（%.1f 米）" % a.distance_to(b)
    return "挡在 %.2f 米" % a.distance_to(hit["position"])
func _process(_d: float) -> bool:
    f += 1
    if f == 40:
        print("[P] 三辊闸（闸在 x=-10.5 / -7.1 / -3.7，z≈43）：南北通行")
        for xx in [-10.5, -9.0, -7.1, -5.4, -3.7, -2.0]:
            print("   x=%.1f 从 z=41 走到 z=45 → %s" % [xx, _ray(Vector3(xx, 0.45, 41.0), Vector3(xx, 0.45, 45.0))])
        print("[P] 长椅（x -15.1~-13.9, z 15.2~19.2）绕行：")
        print("   沿站台走 x=-13.0 → %s" % _ray(Vector3(-13.0, 0.4, 14.0), Vector3(-13.0, 0.4, 20.5)))
        print("[P] 售货机（x -17.85~-17.05, z 20.5~22.7）正面站人：")
        print("   x=-16.4 → %s" % _ray(Vector3(-16.4, 0.4, 21.6), Vector3(-16.4, 0.4, 21.61)))
        print("[P] 垃圾桶（x=-17.2, z=-34.0）:")
        print("   x=-16.6 → %s" % _ray(Vector3(-16.6, 0.4, -34.0), Vector3(-17.9, 0.4, -34.0)))
        return true
    return false
