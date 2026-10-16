extends SceneTree
## 检查过场机位是否真能看见列车（从机位对每节车厢中心打射线）
var game
var f := 0
var s0 := 0.0
var s1 := 0.0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _see(a: Vector3, b: Vector3) -> bool:
    var st: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
    var q := PhysicsRayQueryParameters3D.create(a, b)
    return st.intersect_ray(q).is_empty()
func _process(_d: float) -> bool:
    f += 1
    match f:
        20:
            game._on_start()
            game.round = 3
            game.train.set_divert(true)
            s0 = game.train.s_at_z(-160.0)
            s1 = game.train.s_at_z(-62.0) + game.train.last_front_offset()
        40:
            var k := 0.0
            while k <= 1.001:
                game.train.place(lerpf(s0, s1, k))
                var cam := Vector3(16.6, 3.40, -78.0).lerp(Vector3(16.2, 3.40, -84.0), k)
                var line := ""
                for c in game.train.cars:
                    line += "1" if _see(cam, c.global_position + Vector3(0, 0.6, 0)) else "0"
                print("  k=%.2f 机位(%s) 看得见车厢: %s" % [k, cam, line])
                k += 0.1
            return true
    return false
