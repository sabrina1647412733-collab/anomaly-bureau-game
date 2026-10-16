extends SceneTree
## 边界完整性：新区域四面都要封住，不能掉虚空
var game
var f := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _ray(a: Vector3, b: Vector3) -> String:
    var st: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
    var q := PhysicsRayQueryParameters3D.create(a, b)
    var h: Dictionary = st.intersect_ray(q)
    return "挡在 %.1f" % a.distance_to(h["position"]) if not h.is_empty() else "通！漏了 "
func _process(_d: float) -> bool:
    f += 1
    match f:
        40:
            print("[X] 岔区北墙：", _ray(Vector3(10.0, -0.4, -118.0), Vector3(10.0, -0.4, -130.0)))
            print("[X] 岔区东墙：", _ray(Vector3(16.0, -0.4, -100.0), Vector3(26.0, -0.4, -100.0)))
            print("[X] 侧线南端：", _ray(Vector3(15.5, -0.4, 100.0), Vector3(15.5, -0.4, 118.0)))
            print("[X] 检修环线南墙：", _ray(Vector3(10.0, -0.4, -59.0), Vector3(10.0, -0.4, -52.0)))
            print("[X] 死角封墙（8.5,-56.1）：", _ray(Vector3(8.5, -0.4, -58.0), Vector3(8.5, -0.4, -54.0)))
            print("[X] 环线东墙：", _ray(Vector3(11.6, -0.4, -60.0), Vector3(16.5, -0.4, -60.0)))
            print("[X] 岔区地面到 y=-8：", _ray(Vector3(12.0, 1.0, -80.0), Vector3(12.0, -8.0, -80.0)))
            print("[X] 侧线地面到 y=-8：", _ray(Vector3(15.0, 1.0, 30.0), Vector3(15.0, -8.0, 30.0)))
            print("[X] 主线隧道地面：", _ray(Vector3(4.0, 1.0, -150.0), Vector3(4.0, -8.0, -150.0)))
            return true
    return false
