extends SceneTree
## 沿岔道路径摆放列车，用车厢包围盒做碰撞查询：检查是否穿墙 / 掉出隧道
var game
var f := 0
var s0 := 0.0
var s1 := 0.0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _query(car: Node3D) -> int:
    var bs := BoxShape3D.new()
    bs.size = Vector3(2.86, 3.5, 19.2)
    var q := PhysicsShapeQueryParameters3D.new()
    q.shape = bs
    var xf := car.global_transform
    xf.origin += xf.basis * Vector3(0.0, 0.63, -9.55)
    q.transform = xf
    var st: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
    var rs := st.intersect_shape(q, 4)
    for r in rs:
        var co = r["collider"]
        var si := int(r["shape"])
        var csl := []
        for ch in co.get_children():
            if ch is CollisionShape3D:
                csl.append(ch)
        if si < csl.size():
            var sh = csl[si].shape
            print("      [", co.name, "] pos=", csl[si].position, " size=", sh.size if sh is BoxShape3D else sh.get_class())
        else:
            print("      [", co.name, "] shape#", si, " 无 CollisionShape")
    return rs.size()
func _process(_d: float) -> bool:
    f += 1
    match f:
        20:
            game._on_start()
            game.round = 3
            game.train.set_divert(true)
            s0 = game.train.s_at_z(-70.0)
            s1 = game.train.s_at_z(-62.0) + game.train.last_front_offset()
            print("[C] 路径 s %.0f → %.0f" % [s0, s1])
        40:
            var bad := 0
            var s := s0
            while s <= s1:
                game.train.place(s)
                var hit := 0
                for c in game.train.cars:
                    hit += _query(c)
                if hit > 0:
                    bad += 1
                    if bad <= 8:
                        print("  穿模 s=%.0f 头 z=%.0f 碰撞 %d" % [s, game.train.cars[0].position.z, hit])
                s += 1.0
            print("[C] 扫描完成：穿模位置 ", bad, " 处（0 = 全程无碰撞）")
            return true
    return false
